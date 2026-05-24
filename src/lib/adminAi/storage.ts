const KEY = 'cdd_admin_gemini_api_key';

export function loadGeminiApiKey(): string {
  try {
    return localStorage.getItem(KEY)?.trim() ?? '';
  } catch {
    return '';
  }
}

export function saveGeminiApiKey(key: string) {
  try {
    const t = key.trim();
    if (t) localStorage.setItem(KEY, t);
    else localStorage.removeItem(KEY);
  } catch {
    /* private mode */
  }
}
