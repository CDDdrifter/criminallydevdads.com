/**
 * PostgREST uses slightly different wordings across versions; try to recover the bad column name for retry/strip.
 */
export function unknownColumnFromPostgrestMessage(msg: string): string | null {
  const m1 = msg.match(/column\s+"?([a-zA-Z0-9_]+)"?\s+of\s+relation/i);
  if (m1?.[1]) {
    return m1[1];
  }
  const m2 = msg.match(/Could not find the ['"]([a-zA-Z0-9_]+)['"] column/i);
  if (m2?.[1]) {
    return m2[1];
  }
  const m3 = msg.match(/['"]([a-zA-Z0-9_]+)['"] column.*does not exist/i);
  if (m3?.[1]) {
    return m3[1];
  }
  return null;
}
