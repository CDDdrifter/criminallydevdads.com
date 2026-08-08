import type { CSSProperties } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

type Props = {
  label?: string;
  className?: string;
  style?: CSSProperties;
};

/** Opens the Stripe tip / support URL from Admin → Site copy. */
export function SupportTipButton({ label, className, style }: Props) {
  const { settings } = useSiteSettings();
  const href = settings.stripe_tip_url.trim();
  const text =
    label?.trim() ||
    settings.support_tip_label.trim() ||
    'Support the Devs';

  if (!href) {
    return null;
  }

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={className ?? 'btn-support'}
      style={style}
    >
      {text}
    </a>
  );
}
