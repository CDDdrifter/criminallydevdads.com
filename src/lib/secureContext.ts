/**
 * Browsers (especially iPhone Safari) require a secure context (HTTPS or localhost)
 * for gamepad, audio, WebGL, and other APIs inside embedded games.
 */

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);

export function isLocalDevHost(hostname: string): boolean {
  return LOCAL_HOSTS.has(hostname);
}

export function isSecureBrowsingContext(): boolean {
  if (typeof window === 'undefined') {
    return true;
  }
  if (window.isSecureContext) {
    return true;
  }
  return isLocalDevHost(window.location.hostname);
}

/** Redirect plain HTTP visitors to HTTPS (skipped on localhost). */
export function redirectHttpToHttps(): void {
  if (typeof window === 'undefined') {
    return;
  }
  const { protocol, hostname, href } = window.location;
  if (protocol !== 'http:' || isLocalDevHost(hostname)) {
    return;
  }
  window.location.replace(`https:${href.slice(protocol.length)}`);
}

/** Upgrade http:// asset URLs when the hub is served over HTTPS. */
export function enforceHttpsAssetUrl(url: string): string {
  if (typeof window === 'undefined' || window.location.protocol !== 'https:') {
    return url;
  }
  if (/^http:\/\//i.test(url)) {
    return url.replace(/^http:/i, 'https:');
  }
  return url;
}

export function secureContextGameMessage(): { summary: string; detail: string } {
  const host = typeof window !== 'undefined' ? window.location.hostname : 'this site';
  return {
    summary: 'Secure connection required (HTTPS)',
    detail:
      `Games need HTTPS to run on iPhone and most browsers. Open https://${host} instead of http://. ` +
      'GitHub Pages and criminallydevdads.com support HTTPS automatically once the redirect loads.',
  };
}
