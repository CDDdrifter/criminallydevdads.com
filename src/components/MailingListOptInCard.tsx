import { useCallback, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { updateMyProfile } from '../lib/communityData';
import { FormPrivacyNote } from './FormPrivacyNote';

type Props = {
  /** Show extra welcome copy for brand-new accounts. */
  variant?: 'default' | 'welcome';
};

/**
 * Persistent newsletter opt-in/out — saves immediately on toggle (no separate Save click).
 */
export function MailingListOptInCard({ variant = 'default' }: Props) {
  const auth = useAuth();
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const optedIn = auth.profile?.mailing_list_opt_in === true;

  const onToggle = useCallback(
    (next: boolean) => {
      if (!auth.user?.id) return;
      setSaving(true);
      setMessage(null);
      void updateMyProfile(auth.user.id, { mailing_list_opt_in: next }).then(async (r) => {
        setSaving(false);
        if (r.ok) {
          setMessage(next ? 'You are on the update list. Thanks!' : 'You are off the mailing list.');
          await auth.refreshProfile();
        } else {
          setMessage(r.error);
        }
      });
    },
    [auth],
  );

  if (!auth.isSignedIn || !auth.profile) return null;

  return (
    <section
      className="admin-panel mailing-opt-in-card"
      style={{
        marginTop: variant === 'welcome' ? 0 : 20,
        borderColor: optedIn ? 'rgba(62, 207, 142, 0.45)' : 'rgba(115, 248, 255, 0.35)',
      }}
      aria-labelledby="mailing-opt-in-heading"
    >
      <h2 id="mailing-opt-in-heading" className="page-section-title" style={{ fontSize: '0.95rem', marginBottom: 8 }}>
        {variant === 'welcome' ? 'Stay in the loop' : 'Newsletter & updates'}
      </h2>
      <p className="admin-muted" style={{ lineHeight: 1.55, marginBottom: 14 }}>
        {variant === 'welcome'
          ? 'Your account is ready. Tap below if you want occasional emails when we ship new games or site news — you can change this anytime.'
          : 'Get occasional emails about new games and site news. Only site owners send these; unsubscribe anytime.'}
      </p>
      <div className="admin-row" style={{ gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
        <button
          type="button"
          className={optedIn ? '' : 'user-auth-nav__google'}
          disabled={saving}
          onClick={() => onToggle(!optedIn)}
        >
          {saving ? 'Saving…' : optedIn ? 'Unsubscribe from updates' : 'Subscribe to updates'}
        </button>
        <span className="admin-muted" style={{ fontSize: '0.85rem' }}>
          {optedIn ? 'Currently subscribed' : 'Not subscribed'}
        </span>
      </div>
      {message ? (
        <p className="admin-muted" style={{ marginTop: 10, lineHeight: 1.5 }} role="status">
          {message}
        </p>
      ) : null}
      <FormPrivacyNote context="newsletter updates" />
    </section>
  );
}
