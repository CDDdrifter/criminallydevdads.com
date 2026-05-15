import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { trackEvent } from '../lib/analytics';
import {
  deleteComment,
  fetchComments,
  postComment,
  type CommentTargetType,
  type SiteComment,
} from '../lib/communityData';
import { supabaseConfigured } from '../lib/supabase';
import { useSiteSettings } from '../hooks/useSiteSettings';

type Props = {
  targetType: CommentTargetType;
  targetKey: string;
  title?: string;
};

export function CommentSection({ targetType, targetKey, title = 'Comments' }: Props) {
  const auth = useAuth();
  const { settings } = useSiteSettings();
  const enabled = settings.behavior?.comments_globally_enabled !== false;

  const [comments, setComments] = useState<SiteComment[]>([]);
  const [loading, setLoading] = useState(true);
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!supabaseConfigured || !enabled) {
      setComments([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const list = await fetchComments(targetType, targetKey);
    setComments(list);
    setLoading(false);
  }, [targetType, targetKey, enabled]);

  useEffect(() => {
    void reload();
  }, [reload]);

  if (!supabaseConfigured || !enabled) {
    return null;
  }

  const onSubmit = async () => {
    if (!auth.isSignedIn || !auth.user) {
      setError('Sign in with Google to comment.');
      return;
    }
    setBusy(true);
    setError(null);
    const res = await postComment(auth.user.id, targetType, targetKey, body);
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setBody('');
    void trackEvent('comment_post', {
      path: `/${targetType}/${targetKey}`,
      targetKey,
      userId: auth.user.id,
    });
    await reload();
  };

  const onDelete = async (id: string) => {
    if (!confirm('Delete this comment?')) return;
    const ok = await deleteComment(id);
    if (ok) await reload();
  };

  return (
    <section className="comment-section admin-panel" aria-label={title}>
      <h3 className="page-section-title comment-section__title">{title}</h3>
      <p className="admin-muted comment-section__hint">
        Sign in with Google to post. Comments sync to your account on every device.
      </p>

      {auth.isSignedIn ? (
        <div className="comment-section__form">
          <label htmlFor={`comment-body-${targetType}-${targetKey}`} className="sr-only">
            Write a comment
          </label>
          <textarea
            id={`comment-body-${targetType}-${targetKey}`}
            rows={4}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="Share feedback, bugs, or hype…"
            disabled={busy}
          />
          <div className="admin-row" style={{ marginTop: 10, gap: 10 }}>
            <button type="button" disabled={busy || !body.trim()} onClick={() => void onSubmit()}>
              {busy ? 'Posting…' : 'Post comment'}
            </button>
          </div>
        </div>
      ) : (
        <p className="comment-section__signin-prompt">
          <button
            type="button"
            className="user-auth-nav__google"
            onClick={() => void auth.signInWithGoogle()}
          >
            Sign in with Google
          </button>{' '}
          to join the discussion.
        </p>
      )}

      {error ? (
        <p className="comment-section__error" role="alert">
          {error}
        </p>
      ) : null}

      {loading ? (
        <p className="admin-muted">Loading comments…</p>
      ) : comments.length === 0 ? (
        <p className="admin-muted">No comments yet — be the first.</p>
      ) : (
        <ul className="comment-list">
          {comments.map((c) => {
            const canDelete = auth.user && (auth.user.id === c.user_id || auth.isAdmin);
            return (
              <li key={c.id} className="comment-item">
                <div className="comment-item__head">
                  {c.profile?.avatar_url ? (
                    <img src={c.profile.avatar_url} alt="" className="comment-item__avatar" />
                  ) : (
                    <span className="comment-item__avatar comment-item__avatar--placeholder">
                      {(c.profile?.display_name?.[0] ?? '?').toUpperCase()}
                    </span>
                  )}
                  <span className="comment-item__meta">
                    <strong>{c.profile?.display_name ?? 'Player'}</strong>
                    <time className="admin-muted" dateTime={c.created_at}>
                      {new Date(c.created_at).toLocaleString()}
                    </time>
                  </span>
                  {canDelete ? (
                    <button type="button" className="comment-item__delete" onClick={() => void onDelete(c.id)}>
                      Delete
                    </button>
                  ) : null}
                </div>
                <div className="comment-item__body prose">{c.body}</div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
