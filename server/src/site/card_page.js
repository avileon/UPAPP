/**
 * The page someone sees after a tap or a scan: `/c/<token>`.
 *
 * Server-rendered and tiny, because it is very often the first thing of UP a
 * person ever loads — on mobile data, in a bar, from a browser that has never
 * heard of the app. No Flutter, no script needed to read it.
 *
 * Shows a first name and the main photo, nothing else. No age, no phone, no
 * place: the person holding the phone is standing right there and can ask.
 */

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const shell = (title, body) => `<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<meta name="theme-color" content="#0d0a14">
<meta name="color-scheme" content="dark">
<title>${esc(title)}</title>
<meta property="og:title" content="${esc(title)}">
<meta property="og:site_name" content="AppDate">
<link rel="icon" href="/site/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/site/site.css?v=1">
<style>
  main.card-page { max-width: 420px; margin: 0 auto; padding: 28px 16px 48px; text-align: center; }
  .card-photo { position: relative; aspect-ratio: 4 / 5; border-radius: 26px; overflow: hidden;
    background: var(--surface2); box-shadow: 0 0 60px #ff3d8b33; margin-bottom: 22px; }
  .card-photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .card-photo .initial { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    font: 800 120px "Rubik", sans-serif; color: var(--pink); }
  .card-name { font-size: 40px; margin: 0 0 6px; }
  .badge { display: inline-flex; gap: 6px; align-items: center; padding: 4px 12px; border-radius: 99px;
    background: var(--mint-soft); color: var(--mint); font-weight: 600; font-size: 14px; }
  .lead { margin: 18px 0 26px; }
  .btn-up { display: block; width: 100%; padding: 18px; border-radius: 99px; background: var(--pink); color: #fff;
    font: 800 22px "Rubik", sans-serif; text-decoration: none; box-shadow: 0 0 32px #ff3d8b88; }
  .fine { font-size: 14px; margin-top: 18px; }
</style>
</head>
<body>
<header class="top"><div class="wrap"><a class="logo" href="/"><img class="logo-mark" src="/site/favicon.svg" alt="">App<span class="logo-date">Date</span></a></div></header>
<main class="card-page">
${body}
</main>
</body>
</html>`;

export function cardPage({ token, firstName, hasPhoto, verified }) {
  const name = firstName || 'מישהו';
  const photo = hasPhoto
    ? `<img src="/c/${esc(token)}/photo" alt="${esc(name)}" width="400" height="500">`
    : `<div class="initial" aria-hidden="true">${esc(name.slice(0, 1))}</div>`;
  return shell(
    `${name} נתן/ה לך את הכרטיס שלו/ה ב-AppDate`,
    `
  <div class="card-photo">${photo}</div>
  <h1 class="card-name">${esc(name)}</h1>
  ${verified ? '<span class="badge">✓ פנים מאומתות</span>' : ''}
  <p class="lead muted">${esc(name)} נתן/ה לך את הכרטיס שלו/ה. רוצה להמשיך להכיר? שלח/י UP — ותיפתח לכם שיחה.</p>
  <a class="btn-up" href="/app?card=${encodeURIComponent(token)}">תן UP ↑</a>
  <p class="fine muted">נרשמים בדקה, עם אימות פנים — בלי להוריד כלום. <a href="/">מה זה AppDate?</a></p>`,
  );
}

const GONE = {
  card_expired: 'הכרטיס הזה כבר פג תוקף.',
  card_used: 'מישהו אחר כבר ענה לכרטיס הזה.',
  card_unknown: 'הכרטיס הזה לא קיים או שבוטל.',
};

export function cardGonePage(problem) {
  return shell(
    'AppDate · כרטיס לא בתוקף',
    `
  <h1 class="card-name" style="margin-top:30px">אופס</h1>
  <p class="lead muted">${esc(GONE[problem] ?? GONE.card_unknown)} בקש/י מהבעלים לגעת שוב, או להראות לך את ה-QR מחדש.</p>
  <a class="btn-up" href="/">מה זה AppDate?</a>`,
  );
}
