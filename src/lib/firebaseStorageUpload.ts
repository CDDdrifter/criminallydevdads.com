/**
 * Firebase Storage uploads for branding assets (thumbnails, videos, page images).
 * Game builds are NOT hosted here — use games/ folder in the repo.
 */
import { getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { ensureFirestore } from './firestoreData';
import { storage } from './firebase';

export const BRANDING_BUCKET_PREFIX = 'branding';

export async function firebaseUploadPublicFile(
  folder: string,
  objectPath: string,
  file: File,
  contentType: string,
): Promise<string> {
  if (!(await ensureFirestore()) || !storage) {
    throw new Error('Firebase Storage not configured. Fill in cms/firebase-config.json.');
  }
  const fullPath = `${folder}/${objectPath}`.replace(/\/+/g, '/');
  const fileRef = ref(storage, fullPath);
  await uploadBytes(fileRef, file, {
    contentType,
    cacheControl: 'public,max-age=3600',
  });
  return getDownloadURL(fileRef);
}

export function firebaseStorageReady(): boolean {
  return storage !== null;
}
