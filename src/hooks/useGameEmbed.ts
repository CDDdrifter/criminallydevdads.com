import { useEffect, useRef, useState } from 'react';
import type { GameView } from '../types';
import { probeGamePlayUrl } from '../lib/playUrlProbe';
import { resolveGameUrl } from '../lib/paths';
import { isSecureBrowsingContext, secureContextGameMessage } from '../lib/secureContext';

function isLocalRepoGamePath(launchPath: string): boolean {
  const p = launchPath.trim();
  return p.startsWith('games/') && !/^https?:\/\//i.test(p);
}

export function useGameEmbed(game: GameView | undefined) {
  const [probeState, setProbeState] = useState<'idle' | 'checking' | 'ready' | 'failed'>('idle');
  const [iframeSrc, setIframeSrc] = useState<string | null>(null);
  const [probeError, setProbeError] = useState<{ summary: string; detail: string } | null>(null);
  const blobUrlRef = useRef<string | null>(null);

  useEffect(() => {
    if (!game?.isPlayable) {
      setProbeState('idle');
      setIframeSrc(null);
      setProbeError(null);
      return;
    }
    if (!isSecureBrowsingContext()) {
      setProbeState('failed');
      setIframeSrc(null);
      setProbeError(secureContextGameMessage());
      return;
    }
    const url = resolveGameUrl(game.launchPath);
    let cancelled = false;

    if (blobUrlRef.current) {
      URL.revokeObjectURL(blobUrlRef.current);
      blobUrlRef.current = null;
    }

    // Repo-hosted Godot builds: skip preflight fetch — show iframe immediately.
    if (isLocalRepoGamePath(game.launchPath)) {
      setIframeSrc(url);
      setProbeState('ready');
      setProbeError(null);
      return () => {
        cancelled = true;
      };
    }

    setProbeState('checking');
    setIframeSrc(null);
    setProbeError(null);
    void probeGamePlayUrl(url).then((result) => {
      if (cancelled) {
        return;
      }
      if (result.ok) {
        setIframeSrc(result.iframeSrc);
        if (result.iframeSrc.startsWith('blob:')) {
          blobUrlRef.current = result.iframeSrc;
        }
        setProbeState('ready');
      } else {
        setProbeError({ summary: result.summary, detail: result.detail });
        setProbeState('failed');
      }
    });

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
    };
  }, [game?.slug, game?.launchPath, game?.isPlayable]);

  const resolvedUrl = game ? resolveGameUrl(game.launchPath) : '';

  return { probeState, iframeSrc, probeError, resolvedUrl };
}
