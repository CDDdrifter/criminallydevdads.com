/**
 * Build-time flags (Vite env). Documented in docs/SITE_MANUAL.md
 */

/** When true, show "Team login" / "Admin" in the header. Default: hidden (bookmark /#/admin instead). */
export function showAdminNavLink(): boolean {
  const v = import.meta.env.VITE_SHOW_ADMIN_NAV;
  if (v === undefined || v === '') {
    return false;
  }
  return v === '1' || v.toLowerCase() === 'true' || v.toLowerCase() === 'yes';
}
