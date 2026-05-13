/**
 * SiteParticles — canvas-based particle layer painted behind / above content.
 *
 * Implemented with a single 2D canvas pinned to the viewport (`position:
 * fixed; inset: 0`). Particles are stored in a flat typed-array-ish object
 * pool so we never allocate during animation.
 *
 * Honours `prefers-reduced-motion` when `respect_reduce_motion` is on so we
 * don't trigger vestibular issues for sensitive users.
 */
import { useEffect, useRef } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

type Particle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  rot: number;
  rotVel: number;
  /** Per-particle phase (for fireflies / shimmer). */
  phase: number;
};

function rand(min: number, max: number) {
  return min + Math.random() * (max - min);
}

function reseed(p: Particle, cfg: { speed_min: number; speed_max: number; size_min_px: number; size_max_px: number; direction: string }, w: number, h: number, edge?: 'top' | 'bottom' | 'left' | 'right') {
  // Spawn anywhere — `edge` lets us respawn just off-screen on the leading edge
  // (e.g. snow respawns at the top after falling off the bottom).
  if (edge === 'top') { p.x = Math.random() * w; p.y = -10; }
  else if (edge === 'bottom') { p.x = Math.random() * w; p.y = h + 10; }
  else if (edge === 'left') { p.x = -10; p.y = Math.random() * h; }
  else if (edge === 'right') { p.x = w + 10; p.y = Math.random() * h; }
  else { p.x = Math.random() * w; p.y = Math.random() * h; }
  const speed = rand(cfg.speed_min, cfg.speed_max);
  if (cfg.direction === 'down') { p.vx = (Math.random() - 0.5) * 0.4; p.vy = speed; }
  else if (cfg.direction === 'up') { p.vx = (Math.random() - 0.5) * 0.4; p.vy = -speed; }
  else if (cfg.direction === 'left') { p.vx = -speed; p.vy = (Math.random() - 0.5) * 0.4; }
  else if (cfg.direction === 'right') { p.vx = speed; p.vy = (Math.random() - 0.5) * 0.4; }
  else { const a = Math.random() * Math.PI * 2; p.vx = Math.cos(a) * speed; p.vy = Math.sin(a) * speed; }
  p.size = rand(cfg.size_min_px, cfg.size_max_px);
  p.rot = Math.random() * Math.PI * 2;
  p.rotVel = (Math.random() - 0.5) * 0.04;
  p.phase = Math.random() * Math.PI * 2;
}

export function SiteParticles() {
  const { settings } = useSiteSettings();
  const cfg = settings.particles;
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (!cfg.enabled) return undefined;
    if (cfg.respect_reduce_motion && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;

    const canvas = canvasRef.current;
    if (!canvas) return undefined;
    const ctx = canvas.getContext('2d');
    if (!ctx) return undefined;

    let w = window.innerWidth;
    let h = window.innerHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = w * dpr; canvas.height = h * dpr;
    canvas.style.width = `${w}px`; canvas.style.height = `${h}px`;
    ctx.scale(dpr, dpr);

    const particles: Particle[] = Array.from({ length: cfg.count }, () => {
      const p: Particle = { x: 0, y: 0, vx: 0, vy: 0, size: 0, rot: 0, rotVel: 0, phase: 0 };
      reseed(p, cfg, w, h);
      return p;
    });

    const onResize = () => {
      w = window.innerWidth; h = window.innerHeight;
      canvas.width = w * dpr; canvas.height = h * dpr;
      canvas.style.width = `${w}px`; canvas.style.height = `${h}px`;
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.scale(dpr, dpr);
    };
    window.addEventListener('resize', onResize);

    // Matrix rain — render glyphs instead of dots.
    const matrixGlyphs = '0123456789ABCDEFｱｲｳｴｵｶｷｸｹｺ';

    const tick = () => {
      ctx.clearRect(0, 0, w, h);
      ctx.globalAlpha = cfg.opacity;

      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.rot += p.rotVel;
        p.phase += 0.05;

        // Respawn when off-screen on the leading edge.
        if (cfg.direction === 'down' && p.y > h + 20) reseed(p, cfg, w, h, 'top');
        else if (cfg.direction === 'up' && p.y < -20) reseed(p, cfg, w, h, 'bottom');
        else if (cfg.direction === 'left' && p.x < -20) reseed(p, cfg, w, h, 'right');
        else if (cfg.direction === 'right' && p.x > w + 20) reseed(p, cfg, w, h, 'left');
        else if (p.x < -40 || p.x > w + 40 || p.y < -40 || p.y > h + 40) reseed(p, cfg, w, h);

        ctx.fillStyle = cfg.color;
        ctx.strokeStyle = cfg.color;

        switch (cfg.kind) {
          case 'snow':
          case 'dots':
          case 'stars':
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2);
            ctx.fill();
            break;
          case 'sparks':
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(p.x - p.vx * 4, p.y - p.vy * 4);
            ctx.lineWidth = p.size / 3;
            ctx.stroke();
            break;
          case 'ash': {
            ctx.save();
            ctx.translate(p.x, p.y);
            ctx.rotate(p.rot);
            ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
            ctx.restore();
            break;
          }
          case 'rain':
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(p.x, p.y + p.size * 3);
            ctx.lineWidth = 1;
            ctx.stroke();
            break;
          case 'bubbles':
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2);
            ctx.stroke();
            break;
          case 'fireflies': {
            const blink = 0.5 + 0.5 * Math.sin(p.phase);
            ctx.globalAlpha = cfg.opacity * blink;
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = cfg.opacity;
            break;
          }
          case 'leaves': {
            ctx.save();
            ctx.translate(p.x, p.y);
            ctx.rotate(p.rot);
            ctx.beginPath();
            ctx.ellipse(0, 0, p.size, p.size / 2, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
            break;
          }
          case 'matrix': {
            ctx.font = `${p.size * 1.5}px monospace`;
            ctx.fillText(matrixGlyphs[Math.floor(p.phase * 7) % matrixGlyphs.length] ?? '0', p.x, p.y);
            break;
          }
        }
      }
      rafRef.current = window.requestAnimationFrame(tick);
    };
    rafRef.current = window.requestAnimationFrame(tick);

    return () => {
      window.removeEventListener('resize', onResize);
      if (rafRef.current != null) window.cancelAnimationFrame(rafRef.current);
    };
  }, [
    cfg.enabled,
    cfg.kind,
    cfg.count,
    cfg.color,
    cfg.speed_min,
    cfg.speed_max,
    cfg.size_min_px,
    cfg.size_max_px,
    cfg.direction,
    cfg.opacity,
    cfg.respect_reduce_motion,
  ]);

  if (!cfg.enabled) return null;
  return (
    <canvas
      ref={canvasRef}
      aria-hidden
      style={{
        position: 'fixed',
        inset: 0,
        width: '100vw',
        height: '100vh',
        pointerEvents: 'none',
        zIndex: cfg.z_index === 'above' ? 50 : -1,
      }}
    />
  );
}
