/**
 * Admin allowlist — stored in cms/admin-config.json (no database required).
 * Add your Google email or domain to grant /admin access after sign-in.
 */
import { fetchStaticJson } from './staticCms';

export type AdminConfig = {
  admin_emails: string[];
  admin_domains: string[];
};

const DEFAULT_CONFIG: AdminConfig = {
  admin_emails: [],
  admin_domains: ['criminallydevdads.com'],
};

let cached: AdminConfig | null = null;

export async function loadAdminConfig(): Promise<AdminConfig> {
  if (cached) {
    return cached;
  }
  const raw = await fetchStaticJson<Partial<AdminConfig>>('cms/admin-config.json');
  cached = {
    admin_emails: Array.isArray(raw?.admin_emails)
      ? raw.admin_emails.map((e) => String(e).trim().toLowerCase()).filter(Boolean)
      : DEFAULT_CONFIG.admin_emails,
    admin_domains: Array.isArray(raw?.admin_domains)
      ? raw.admin_domains.map((d) => String(d).trim().toLowerCase()).filter(Boolean)
      : DEFAULT_CONFIG.admin_domains,
  };
  return cached;
}

export async function isAdminEmail(email: string | null | undefined): Promise<boolean> {
  if (!email) {
    return false;
  }
  const normalized = email.trim().toLowerCase();
  const config = await loadAdminConfig();
  if (config.admin_emails.includes(normalized)) {
    return true;
  }
  const domain = normalized.split('@')[1];
  if (domain && config.admin_domains.includes(domain)) {
    return true;
  }
  return false;
}
