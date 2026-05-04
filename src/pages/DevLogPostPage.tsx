import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { fetchDevLogBySlug } from '../lib/cmsData';
import type { DevLogPost } from '../types';

export function DevLogPostPage() {
  const { slug } = useParams<{ slug: string }>();
  const [post, setPost] = useState<DevLogPost | null | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    if (!slug) {
      setPost(null);
      return;
    }
    fetchDevLogBySlug(slug).then((p) => {
      if (!cancelled) {
        setPost(p);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [slug]);

  if (post === undefined) {
    return (
      <SiteChrome>
        <div className="empty-state">Loading…</div>
      </SiteChrome>
    );
  }

  if (!post) {
    return (
      <SiteChrome>
        <div className="empty-state">Post not found.</div>
        <p style={{ textAlign: 'center' }}>
          <Link to="/devlog">← Dev log</Link>
        </p>
      </SiteChrome>
    );
  }

  return (
    <SiteChrome
      navExtra={
        <>
          <Link to="/devlog">← Dev log</Link>
          <Link to="/">Hub</Link>
        </>
      }
    >
      <article className="admin-panel">
        <div className="game-type" style={{ marginBottom: 12 }}>
          {new Date(post.published_at).toLocaleString()}
        </div>
        <h1 className="header-title" style={{ fontSize: '2rem', textAlign: 'left' }}>
          {post.title}
        </h1>
        <div className="prose" style={{ marginTop: 24, whiteSpace: 'pre-wrap' }}>
          {post.body}
        </div>
      </article>
    </SiteChrome>
  );
}
