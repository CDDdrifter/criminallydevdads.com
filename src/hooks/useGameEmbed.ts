import { useEffect, useRef, useState } from 'react';
import type { GameView } from '../types';
import { probeGamePlayUrl } from '../lib/playUrlProbe';
import { resolveGameUrl } from '../lib/paths';

export function useGameEmbed(game: GameView | undefined) {
  const [probeState, setProbeState] = useState<'idle' | 'checking' | 'ready' | 'failed'>('idle');
  const [iframeSrc, setIframeSrc] = useState<string | null>(null);
  const [probeError, setProbeError] = useState<{ summary: string; detail: string } | null>(null);
  const [compatibilityNote, setCompatibilityNote] = useState<string | null>(null);
  const blobUrlRef = useRef<string | null>(null);

  useEffect(() => {
    if (!game?.isPlayable) {
      setProbeState('idle');
      setIframeSrc(null);
      setProbeError(null);
      setCompatibilityNote(null);
      return;
    }
    const url = resolveGameUrl(game.launchPath);
    let cancelled = false;

    if (blobUrlRef.current) {
      URL.revokeObjectURL(blobUrlRef.current);
      blobUrlRef.current = null;
    }

    setProbeState('checking');
    setIframeSrc(null);
    setProbeError(null);
    setCompatibilityNote(null);

    void probeGamePlayUrl(url).then((result) => {
      if (cancelled) {
        return;
      }
      if (result.ok) {
        setIframeSrc(result.iframeSrc);
        setCompatibilityNote(result.compatibilityNote ?? null);
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

  return { probeState, iframeSrc, probeError, compatibilityNote, resolvedUrl };
}
