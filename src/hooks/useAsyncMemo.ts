import { useEffect, useState } from 'react';

export function useAsyncMemo<T>(factory: () => Promise<T>, deps: unknown[]): T | null {
  const [value, setValue] = useState<T | null>(null);
  useEffect(() => {
    let cancelled = false;
    factory().then((v) => {
      if (!cancelled) {
        setValue(v);
      }
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return value;
}
