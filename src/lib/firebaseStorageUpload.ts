/**
 * Firebase Storage uploads for branding assets (thumbnails, videos, page images).
 * Game builds are NOT hosted here — use games/ folder in the repo.
 */
import { getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { ensureFirestore } from './firestoreData';
import { auth, initFirebase, storage } from './firebase';

export const BRANDING_BUCKET_PREFIX = 'branding';

export async function firebaseUploadPublicFile(
  folder: string,
  objectPath: string,
  file: File,
  contentType: string,
): Promise<string> {
  await initFirebase();
  if (!(await ensureFirestore()) || !storage) {
    throw new Error('Firebase Storage not configured. Fill in cms/firebase-config.json.');
  }
  if (!auth?.currentUser) {
    throw new Error('Sign in with Google at /admin first — Firebase Storage requires an admin session.');
  }
  const fullPath = `${folder}/${objectPath}`.replace(/\/+/g, '/');
  const fileRef = ref(storage, fullPath);
  try {
    await uploadBytes(fileRef, file, {
      contentType,
      cacheControl: 'public,max-age=3600',
    });
    return getDownloadURL(fileRef);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (/permission|unauthorized|denied/i.test(msg)) {
      throw new Error(
        'Firebase Storage denied the upload. Sign in with an @criminallydevdads.com Google account at /admin.',
      );
    }
    throw e;
  }
}

export function firebaseStorageReady(): boolean {
  return storage !== null;
}
