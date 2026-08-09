/**
 * Firebase Storage uploads for branding assets (thumbnails, videos, page images).
 * Game builds are NOT hosted here — use games/ folder in the repo.
 */
import { getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { ensureFirestore } from './firestoreData';
import { initFirebase, storage, waitForFirebaseUser } from './firebase';

export const BRANDING_BUCKET_PREFIX = 'branding';

const UPLOAD_TIMEOUT_MS = 45_000;

async function withUploadTimeout<T>(promise: Promise<T>, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${UPLOAD_TIMEOUT_MS / 1000}s. Try a smaller image.`)), UPLOAD_TIMEOUT_MS),
    ),
  ]);
}

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
  await waitForFirebaseUser();
  const fullPath = `${folder}/${objectPath}`.replace(/\/+/g, '/');
  const fileRef = ref(storage, fullPath);
  try {
    await withUploadTimeout(
      uploadBytes(fileRef, file, {
        contentType,
        cacheControl: 'public,max-age=3600',
      }),
      'Cover upload',
    );
    return await withUploadTimeout(getDownloadURL(fileRef), 'Cover upload');
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (/permission|unauthorized|denied|403/i.test(msg)) {
      throw new Error(
        'Firebase blocked the upload. Sign in at /admin with Google, then try again. If it keeps failing, deploy storage.rules from this repo (firebase deploy --only storage).',
      );
    }
    throw e;
  }
}

export function firebaseStorageReady(): boolean {
  return storage !== null;
}
