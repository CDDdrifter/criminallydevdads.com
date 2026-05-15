import { useSiteSettings } from '../hooks/useSiteSettings';

/**
 * Full-viewport looping video behind site content when Theme Studio → Body video is enabled.
 * Placed early in the router so it sits under chrome, particles, and FX layers.
 */
export function SiteBackgroundVideo() {
  const { settings } = useSiteSettings();
  const theme = settings.theme;
  const v = theme.background.body_video;
  if (!theme.enabled || !v?.enabled || !v.url?.trim()) {
    return null;
  }
  const opacity = Math.max(0, Math.min(1, v.opacity ?? 0.45));
  const blur = Math.max(0, Math.min(32, v.blur_px ?? 0));

  return (
    <div
      className="site-bg-video-wrap"
      style={{
        opacity,
        filter: blur > 0 ? `blur(${blur}px)` : undefined,
      }}
      aria-hidden
    >
      <video className="site-bg-video" src={v.url.trim()} autoPlay muted loop playsInline />
    </div>
  );
}
