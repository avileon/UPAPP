/**
 * "Tonight", as a key.
 *
 * A night out runs past midnight, so the calendar date is the wrong unit: an
 * UP at 23:50 and one at 00:10 are the same evening. The night is the local
 * date of (now − resetHour), so with the default 06:00 everything from 06:00
 * one day to 05:59 the next shares a key.
 */
export function nightKey(nowMs, { timeZone = 'Asia/Jerusalem', resetHour = 6 } = {}) {
  const shifted = new Date(nowMs - resetHour * 3600_000);
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(shifted);
}
