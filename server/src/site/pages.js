import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * The public site: the landing page at `/`, the business page at
 * `/business`, and what search engines ask for around them.
 *
 * Plain server-rendered HTML on purpose. The app is a Flutter canvas, which a
 * crawler sees as an empty page — everything someone should find when they
 * search for UP has to exist here as real text.
 */

const here = dirname(fileURLToPath(import.meta.url));
const ASSETS = join(here, 'assets');

const TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.woff2': 'font/woff2',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const assetCache = new Map();

/** A file from `site/assets`, by bare name only — no paths, no climbing out. */
export function siteAsset(name) {
  if (!/^[A-Za-z0-9._-]+$/.test(name) || name.startsWith('.')) return null;
  if (assetCache.has(name)) return assetCache.get(name);
  const file = name === 'qrcode.js' ? join(here, '..', 'static', 'qrcode.js') : join(ASSETS, name);
  const dot = name.lastIndexOf('.');
  const type = TYPES[name.slice(dot)];
  if (!type || !existsSync(file)) return null;
  const asset = { body: readFileSync(file), type };
  assetCache.set(name, asset);
  return asset;
}

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const ICONS = {
  pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg>',
  face: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><circle cx="9" cy="10" r=".6" fill="currentColor"/><circle cx="15" cy="10" r=".6" fill="currentColor"/><path d="M9 15c1.6 1.3 4.4 1.3 6 0"/></svg>',
  heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M12 20s-7.5-4.6-9.2-9.3C1.6 7.3 3.9 4 7.3 4c2 0 3.4 1.1 4.7 2.8C13.3 5.1 14.7 4 16.7 4c3.4 0 5.7 3.3 4.5 6.7C19.5 15.4 12 20 12 20z"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6l8-3z"/><path d="M8.5 12l2.5 2.5 4.5-5"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v.01M17 21h4v-4M14 18v3"/></svg>',
  eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><path d="M4 4l16 16" stroke-linecap="round"/></svg>',
  radar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="2"/><path d="M16.2 7.8a6 6 0 0 1 0 8.4M7.8 16.2a6 6 0 0 1 0-8.4M19 5a10 10 0 0 1 0 14M5 19A10 10 0 0 1 5 5"/></svg>',
  phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M11 18.5h2" stroke-linecap="round"/></svg>',
  spark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M12 3l2.2 5.8L20 11l-5.8 2.2L12 19l-2.2-5.8L4 11l5.8-2.2z"/></svg>',
  users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c1.9.7 3.1 2.4 3.5 5.2"/></svg>',
  chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
};

/** One feature card. */
const card = (icon, title, text, mint = false) => `
      <article class="card">
        <div class="icon${mint ? ' m' : ''}" aria-hidden="true">${ICONS[icon]}</div>
        <h3>${title}</h3>
        <p>${text}</p>
      </article>`;

const FAQ = [
  [
    'מה זה UP?',
    'UP היא אפליקציית הכרויות שמראה לך רק אנשים שנמצאים איתך באותו מקום — באותו בר, פאב, מועדון או אירוע — ממש עכשיו. נכנסים ל-Live, רואים מי כאן, שולחים UP, וכשזה הדדי נפתח Match וצ׳אט.',
  ],
  [
    'במה UP שונה מטינדר, באמבל ואפליקציות היכרויות אחרות?',
    'באפליקציות הרגילות מחליקים על אנשים שנמצאים קילומטרים ממך ואולי בכלל לא פעילים. ב-UP כל מי שמופיע נמצא בחדר איתך באותו רגע, עבר אימות פנים חי, והתמונות שלו נבדקות מול הפנים האמיתיות. המטרה היא להיפגש עכשיו, לא להתכתב שבועות.',
  ],
  [
    'צריך להוריד אפליקציה?',
    'לא חייבים. UP עובדת ישר מהדפדפן — גם באייפון וגם באנדרואיד — ואפשר להוסיף אותה למסך הבית בלחיצה כדי שתיפתח כמו אפליקציה רגילה. למכשירי אנדרואיד יש גם גרסה להתקנה.',
  ],
  [
    'איך UP יודעת שאני באמת נמצא בבר?',
    'בכל מקום שמצטרף ל-UP תלויה מדבקת QR. סורקים אותה, והטלפון מאשר שהמיקום שלך בתוך רדיוס המקום. רק אז נכנסים לחדר — לשעה. מי שלא נמצא שם פיזית לא יכול להיכנס, גם אם קיבל צילום של הקוד.',
  ],
  [
    'האם UP שומרת את המיקום שלי?',
    'לא. המיקום משמש רק לבדיקה ברגע הכניסה ונזרק מיד — הוא לא נשמר במסד הנתונים ולא מוצג לאף אחד. העיקרון שלנו: UP יודעת שאתה בחדר, לא איפה אתה.',
  ],
  [
    'מה זה אימות פנים ולמה הוא חשוב?',
    'לפני שנכנסים ל-Live עושים אימות חי במצלמה — כמה סיבובי ראש קצרים. כל תמונת פרופיל נבדקת מול הפנים המאומתות, ותמונה שלא תואמת לא מוצגת. ככה הפרופילים ב-UP הם אנשים אמיתיים שנראים כמו בתמונות.',
  ],
  [
    'כמה UP אפשר לשלוח?',
    'בכל מקום אפשר לשלוח עד 4 UP חדשים בלילה (המונה מתאפס ב-06:00). להחזיר UP למי ששלח לך — תמיד בחינם. המגבלה שומרת על כוונה אמיתית ומונעת ספאם.',
  ],
  [
    'מה קורה כשאני עוזב את המקום?',
    'הכניסה לחדר תקפה לשעה. חמש דקות לפני הסוף תקבלו תזכורת, ומי שעדיין שם סורק שוב וממשיך. מי שהלך — פשוט נעלם מהחדר. אין פרופיל שנשאר "באוויר".',
  ],
  [
    'אפשר להשתמש ב-UP גם בלי בר?',
    'כן. במצב "באזור שלי" רואים אנשים שנמצאים ב-Live ברדיוס של כחצי קילומטר ממך — בלי לסרוק QR.',
  ],
  [
    'UP מתאימה רק לדייטים?',
    'לא רק. בוחרים מטרה בכל כניסה: "דייט" או "להכיר אנשים". סינון לפי העדפת מגדר פועל רק במצב דייט.',
  ],
  [
    'מה אם מישהו מטריד אותי?',
    'בכל פרופיל אפשר להסתיר עד סוף הערב, לחסום או לדווח. מי שחסמת לא יראה אותך יותר, ואפשר לנהל את רשימת החסומים בהגדרות.',
  ],
  [
    'יש לי בר / פאב / מועדון — איך מצטרפים?',
    'נרשמים בדף UP לעסקים: שם העסק, מיקום (מהטלפון כשאתם בעסק או לפי כתובת) ופרטי קשר. אחרי אישור מקבלים QR אישי להדפסה ולתלייה, ומשם האורחים שלכם נכנסים לחדר של המקום.',
  ],
];

const BUSINESS_FAQ = [
  [
    'מה העסק מקבל מ-UP?',
    'חדר משלו באפליקציה: מי שסורק את ה-QR שלכם נכנס לחדר של המקום, רואה מי עוד שם ויכול לשלוח UP. אורחים נשארים יותר, חוזרים, ומספרים לחברים שאצלכם "קורה משהו". בכניסה לחדר הלוגו שלכם קופץ אצל האורח עם קונפטי.',
  ],
  [
    'צריך ציוד מיוחד?',
    'לא. מדבקת QR קבועה שמדפיסים מהדף שלכם — על הבר, בשירותים, על השולחנות. בלי טאבלט, בלי חיבור לקופה.',
  ],
  [
    'איך מונעים ממישהו להיכנס לחדר מהבית?',
    'כל כניסה בודקת שהטלפון נמצא בתוך רדיוס המקום. לכן חשוב שהמיקום שתגדירו יהיה מדויק — הכי טוב לרשום את העסק כשאתם נמצאים בו.',
  ],
  [
    'כמה זמן לוקח האישור?',
    'אנחנו בודקים כל עסק ידנית כדי שלא יהיו מקומות מזויפים. בדרך כלל זה קורה תוך יום עבודה, ובינתיים כבר אפשר לראות את ה-QR שלכם בדף העסק.',
  ],
  [
    'אילו עסקים מתאימים?',
    'ברים, פאבים, מועדונים, בתי קפה, מסעדות עם אווירת ערב, אולמות ומארגני אירועים — כל מקום שאנשים מגיעים אליו כדי להיות עם אנשים.',
  ],
];

const faqHtml = (rows) =>
  rows.map(([q, a]) => `<details><summary>${esc(q)}</summary><p>${esc(a)}</p></details>`).join('\n        ');

const faqLd = (rows) => ({
  '@type': 'FAQPage',
  mainEntity: rows.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })),
});

export function sitePages({ publicUrl }) {
  const base = publicUrl;
  const OG = `${base}/site/og.png`;

  const org = {
    '@type': 'Organization',
    '@id': `${base}/#org`,
    name: 'UP',
    alternateName: ['UP הכרויות', 'אפליקציית UP'],
    url: `${base}/`,
    logo: `${base}/site/icon-512.png`,
  };

  const head = ({ title, description, path, ld, extra = '' }) => `<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${base}${path}">
<meta name="robots" content="index, follow, max-image-preview:large">
<meta name="theme-color" content="#0d0a14">
<meta name="color-scheme" content="dark">
<meta property="og:type" content="website">
<meta property="og:site_name" content="UP">
<meta property="og:locale" content="he_IL">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${base}${path}">
<meta property="og:image" content="${OG}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="UP — אפליקציית הכרויות במקום">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${OG}">
<link rel="icon" href="/site/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/site/icon-192.png" type="image/png" sizes="192x192">
<link rel="apple-touch-icon" href="/site/apple-touch-icon.png">
<link rel="manifest" href="/manifest.json">
<meta name="apple-mobile-web-app-title" content="UP">
<link rel="preload" href="/site/Rubik-800.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/site/IBMPlexSansHebrew-Regular.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/site/site.css?v=1">
<script type="application/ld+json">${JSON.stringify({ '@context': 'https://schema.org', '@graph': ld }).replace(/</g, '\\u003c')}</script>
${extra}</head>`;

  const header = (active) => `
<a class="skip" href="#main">דילוג לתוכן</a>
<header class="top">
  <div class="wrap">
    <a class="logo" href="/" aria-label="UP — דף הבית">UP</a>
    <nav aria-label="ראשי">
      <a class="hide-sm" href="/#how">איך זה עובד</a>
      <a class="hide-sm" href="/#features">למה UP</a>
      <a href="/business"${active === 'business' ? ' aria-current="page"' : ''}>לעסקים</a>
      <a class="btn btn-pink btn-sm" href="/app">כניסה</a>
    </nav>
  </div>
</header>`;

  const footer = `
<footer>
  <div class="wrap">
    <a class="logo" href="/" style="font-size:22px">UP</a>
    <a href="/#how">איך זה עובד</a>
    <a href="/#faq">שאלות נפוצות</a>
    <a href="/business">UP לעסקים</a>
    <a href="/business#join">רישום עסק</a>
    <a href="/app">כניסה לאפליקציה</a>
    <span class="sp">לגילאי 18 ומעלה · © ${new Date().getFullYear()} UP</span>
  </div>
</footer>`;

  // -- the landing page ---------------------------------------------------------

  const landingHtml = () => {
    const title = 'UP — אפליקציית הכרויות לאנשים שנמצאים איתך עכשיו';
    const description =
      'UP היא אפליקציית הכרויות שמחברת בין אנשים שנמצאים באותו בר, פאב או אירוע — ממש עכשיו. סורקים QR, רואים מי כאן, שולחים UP, ו-Match רק כשזה הדדי. אימות פנים חי, בלי התקנה.';
    const ld = [
      org,
      {
        '@type': 'WebSite',
        '@id': `${base}/#site`,
        name: 'UP',
        alternateName: 'UP — אפליקציית הכרויות',
        url: `${base}/`,
        inLanguage: 'he-IL',
        publisher: { '@id': `${base}/#org` },
      },
      {
        '@type': 'WebApplication',
        '@id': `${base}/#app`,
        name: 'UP',
        alternateName: ['UP אפליקציית הכרויות', 'אפליקציית UP', 'UP dating app'],
        description,
        url: `${base}/app`,
        applicationCategory: 'SocialNetworkingApplication',
        operatingSystem: 'Web, iOS, Android',
        browserRequirements: 'Requires a modern browser with camera and location',
        inLanguage: ['he', 'en'],
        image: OG,
        publisher: { '@id': `${base}/#org` },
        featureList: [
          'הכרויות לפי מיקום — רק מי שנמצא איתך באותו מקום',
          'כניסה לחדר של מקום בסריקת QR ובדיקת מיקום',
          'אימות פנים חי ובדיקת תמונות מול הפנים',
          'Match רק כשהעניין הדדי',
          'מצב "באזור שלי" בלי QR',
          'הסתרה, חסימה ודיווח',
        ],
      },
      faqLd(FAQ),
    ];

    // Home-screen icons installed before the landing page existed open "/".
    // Someone who installed the app wants the app.
    const standalone = `<script>if (matchMedia('(display-mode: standalone)').matches || navigator.standalone) location.replace('/app');</script>\n`;
    return `${head({ title, description, path: '/', ld, extra: standalone })}
<body>
${header('home')}
<main id="main">

<section class="hero">
  <div class="wrap">
    <div>
      <div class="eyebrow"><i aria-hidden="true"></i> אנשים אמיתיים. באותו מקום. עכשיו.</div>
      <h1>UP — אפליקציית ההכרויות <span class="pink glow-pink">למי שנמצא כאן</span></h1>
      <p class="lead">נכנסת לבר? סרקו את ה-QR, תראו מי עוד בחדר, ושלחו UP למי שתפס לכם את העין. כשזה הדדי — יש Match, ואפשר פשוט לגשת ולהגיד שלום.</p>
      <div class="btns">
        <a class="btn btn-pink" href="/app">להתחיל עכשיו — בחינם בדפדפן</a>
        <button class="btn btn-ghost" type="button" id="install">התקנה למסך הבית</button>
      </div>
      <div class="trust"><span>אימות פנים חי</span><span>בלי התקנה, גם באייפון</span><span>המיקום לא נשמר</span><span>18+</span></div>
      <p style="margin-top:26px"><a href="/business">יש לך בר, פאב או מועדון? קבלו QR משלכם ←</a></p>
    </div>
    <div aria-hidden="true">
      <div class="phone"><div class="screen">
        <div class="status">22:41</div>
        <div class="room">אתם ב<b>חדר של הבר</b> · 14 כאן</div>
        <div class="radar"><span></span><span></span><span></span><b>UP</b></div>
        <div class="faces">
          <div class="face new" style="background:linear-gradient(160deg,#ff8fb8,#7a2b6e)"><em>נועה, 27</em></div>
          <div class="face" style="background:linear-gradient(160deg,#79e6d0,#235a63)"><em>דניאל, 30</em></div>
          <div class="face" style="background:linear-gradient(160deg,#c3a6ff,#4b2f7a)"><em>מאיה, 25</em></div>
          <div class="face" style="background:linear-gradient(160deg,#ffc58f,#7a442b)"><em>עומר, 29</em></div>
          <div class="face new" style="background:linear-gradient(160deg,#9fd0ff,#2b4a7a)"><em>שיר, 26</em></div>
          <div class="face" style="background:linear-gradient(160deg,#ff9f9f,#7a2b3a)"><em>איתי, 31</em></div>
        </div>
        <div class="bar"><span>חדר</span><span>התאמות</span><span>פרופיל</span></div>
      </div></div>
    </div>
  </div>
</section>

<section class="block alt" id="how">
  <div class="wrap">
    <div class="section-head">
      <h2>איך UP עובדת?</h2>
      <p>שלושה צעדים, פחות מדקה. בלי להחליק על זרים שנמצאים בצד השני של העיר.</p>
    </div>
    <div class="grid g3 steps">
      <article class="card step"><h3>סורקים את ה-QR במקום</h3><p>על הבר, על השולחן או בכניסה. הטלפון מאשר שאתם באמת שם, ואתם בחדר של המקום לשעה. אפשר גם "באזור שלי" — בלי QR.</p></article>
      <article class="card step"><h3>רואים מי כאן — עכשיו</h3><p>הפנים של מי שבחדר ממלאים את המסך. נוגעים בפנים כדי לראות עוד תמונות, ומחליקים לאדם הבא.</p></article>
      <article class="card step"><h3>שולחים UP ומחכים להדדיות</h3><p>לחיצה על התמונה שולחת UP (יש 3 שניות לביטול). כשהצד השני שולח בחזרה — Match, קונפטי וצ׳אט. משם זה כבר אתם.</p></article>
    </div>
  </div>
</section>

<section class="block" id="features">
  <div class="wrap">
    <div class="section-head">
      <h2>למה דווקא UP?</h2>
      <p>בנינו את אפליקציית ההכרויות שרצינו שתהיה: כנה, מאומתת ומחוברת למקום שבו אתם נמצאים.</p>
    </div>
    <div class="grid g3">
      ${card('pin', 'רק מי שבאמת כאן', 'כל מי שמופיע בחדר סרק את ה-QR של המקום והמיקום שלו אושר. לא פרופילים מהצד השני של הארץ, לא בוטים.')}
      ${card('face', 'אימות פנים חי', 'כמה סיבובי ראש מול המצלמה, וזהו. כל תמונת פרופיל נבדקת מול הפנים המאומתות — תמונה שלא תואמת לא מוצגת.', true)}
      ${card('spark', 'Reality Verified', 'אחרי שנפגשתם, משוב פרטי וקצר: התמונות מייצגות את האדם במציאות? זה לא דירוג יופי — זו כנות.')}
      ${card('heart', 'Match רק בהדדיות', 'צ׳אט נפתח רק כששני הצדדים שלחו UP. אף אחד לא יכול להציף אתכם בהודעות.', true)}
      ${card('clock', '4 UP בלילה, לכל מקום', 'מגבלה קטנה שעושה הבדל גדול: כל UP הוא בחירה אמיתית. להחזיר UP — תמיד בחינם.')}
      ${card('shield', 'UP יודעת שאתם בחדר — לא איפה אתם', 'המיקום נבדק רק ברגע הכניסה ונמחק מיד. לא נשמר, לא מוצג, לא נמכר.', true)}
      ${card('radar', '"באזור שלי"', 'לא בבר? היכנסו ל-Live ותראו מי עוד פעיל ברדיוס של כחצי קילומטר.')}
      ${card('eye', 'שליטה מלאה', 'מסתירים מישהו עד סוף הערב, חוסמים או מדווחים — בשתי לחיצות. ה-Live זמני ונעלם כשיוצאים.', true)}
      ${card('phone', 'בלי להוריד כלום', 'עובדת מהדפדפן בכל טלפון — אייפון ואנדרואיד — ונכנסת למסך הבית כמו אפליקציה. בעברית ובאנגלית.')}
    </div>
  </div>
</section>

<section class="block alt" id="compare">
  <div class="wrap">
    <div class="section-head">
      <h2>UP מול אפליקציות היכרויות רגילות</h2>
      <p>לא עוד אפליקציית סווייפים. UP בנויה להיפגש באותו ערב.</p>
    </div>
    <div style="overflow-x:auto">
    <table class="compare">
      <thead><tr><th scope="col"></th><th scope="col">UP</th><th scope="col">אפליקציות רגילות</th></tr></thead>
      <tbody>
        <tr><th scope="row">את מי רואים</th><td>רק מי שנמצא איתך באותו מקום, עכשיו</td><td>אנשים ברדיוס של קילומטרים, גם כאלה שלא נכנסו חודשים</td></tr>
        <tr><th scope="row">אמינות הפרופיל</th><td>אימות פנים חי + בדיקת כל תמונה</td><td>תמונות מכל מקום, לפעמים בלי אימות</td></tr>
        <tr><th scope="row">מ-Match לפגישה</th><td>דקות — אתם באותו חדר</td><td>ימים של התכתבות</td></tr>
        <tr><th scope="row">מיקום</th><td>נבדק בכניסה ונמחק</td><td>לרוב נשמר ומשמש למעקב</td></tr>
        <tr><th scope="row">התקנה</th><td>לא חובה — עובד בדפדפן</td><td>הורדה מהחנות</td></tr>
      </tbody>
    </table>
    </div>
  </div>
</section>

<section class="block" id="business">
  <div class="wrap">
    <div class="band">
      <div>
        <h2>UP לעסקים: ה-QR שהופך את הבר שלכם למקום להכיר בו אנשים</h2>
        <ul>
          <li>חדר משלכם באפליקציה — רק מי שנמצא אצלכם נכנס אליו</li>
          <li>מדבקת QR קבועה להדפסה. בלי ציוד, בלי חיבור לקופה</li>
          <li>הלוגו שלכם קופץ עם קונפטי אצל כל אורח שנכנס</li>
          <li>רואים כמה אנשים מחוברים אצלכם עכשיו</li>
        </ul>
        <div class="btns"><a class="btn btn-mint" href="/business#join">רישום העסק וקבלת QR</a><a class="btn btn-ghost" href="/business">פרטים נוספים</a></div>
      </div>
      <div aria-hidden="true"><div class="sticker-mini"><div class="b">UP</div><div class="n">הבר שלכם</div>
        <svg viewBox="0 0 29 29" width="150" height="150" shape-rendering="crispEdges"><path fill="#111" d="M0 0h7v7H0zM1 1v5h5V1zM2 2h3v3H2zM22 0h7v7h-7zM23 1v5h5V1zM24 2h3v3h-3zM0 22h7v7H0zM1 23v5h5v-5zM2 24h3v3H2zM9 0h2v2H9zM13 1h3v2h-3zM9 4h4v2H9zM15 5h4v3h-4zM10 9h3v3h-3zM0 9h2v4H0zM4 10h3v2H4zM15 10h2v4h-2zM19 9h4v2h-4zM25 10h4v2h-4zM8 14h5v2H8zM20 13h3v4h-3zM2 15h4v2H2zM25 15h3v3h-3zM9 18h2v4H9zM13 17h4v2h-4zM18 19h3v3h-3zM23 20h2v2h-2zM13 21h3v3h-3zM9 24h2v4H9zM18 24h4v2h-4zM24 24h4v4h-4zM14 26h2v3h-2z"/></svg>
        <div class="c">סרקו כדי לראות מי כאן ולשלוח UP</div></div></div>
    </div>
  </div>
</section>

<section class="block alt" id="faq">
  <div class="wrap" style="max-width:860px">
    <div class="section-head"><h2>שאלות נפוצות על UP</h2></div>
    <div class="faq">
        ${faqHtml(FAQ)}
    </div>
  </div>
</section>

<section class="final">
  <div class="wrap">
    <h2>הערב הבא שלכם מתחיל ב-<span class="pink glow-pink">UP</span></h2>
    <p class="muted" style="font-size:18px">פותחים, מאמתים פנים פעם אחת, וסורקים בבר הבא.</p>
    <div class="btns"><a class="btn btn-pink" href="/app">כניסה ל-UP</a><a class="btn btn-ghost" href="/business">אני בעל עסק</a></div>
  </div>
</section>

</main>
${footer}

<div class="modal" id="install-help" role="dialog" aria-modal="true" aria-labelledby="ih-t">
  <div class="sheet">
    <h3 id="ih-t">הוספת UP למסך הבית</h3>
    <p class="muted" id="ih-ios" hidden>באייפון (Safari):</p>
    <ol id="ih-steps"></ol>
    <div class="btns"><a class="btn btn-pink" href="/app">פתיחת UP</a><button class="btn btn-ghost" type="button" id="ih-close">סגירה</button></div>
  </div>
</div>
<script>
(function () {
  var deferred = null;
  window.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); deferred = e; });
  var ua = navigator.userAgent;
  var ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var standalone = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone;
  var btn = document.getElementById('install');
  if (standalone) { btn.hidden = true; }
  var modal = document.getElementById('install-help');
  document.getElementById('ih-close').onclick = function () { modal.classList.remove('on'); };
  modal.onclick = function (e) { if (e.target === modal) modal.classList.remove('on'); };
  btn.onclick = function () {
    if (deferred) {
      deferred.prompt();
      deferred.userChoice.then(function () { deferred = null; });
      return;
    }
    var steps = ios
      ? ['פתחו את הדף ב-Safari', 'לחצו על כפתור השיתוף (ריבוע עם חץ למעלה)', 'בחרו "הוספה למסך הבית" ואשרו']
      : ['פתחו את התפריט של הדפדפן (שלוש הנקודות)', 'בחרו "התקנת אפליקציה" או "הוספה למסך הבית"', 'אשרו — UP תופיע עם שאר האפליקציות'];
    document.getElementById('ih-steps').innerHTML = steps.map(function (s) { return '<li>' + s + '</li>'; }).join('');
    modal.classList.add('on');
  };
})();
</script>
</body>
</html>`;
  };

  // -- businesses -------------------------------------------------------------------

  const businessHtml = () => {
    const title = 'UP לעסקים — QR להכרויות לבר, פאב ומועדון';
    const description =
      'הפכו את הבר, הפאב או המועדון שלכם למקום שבו מכירים אנשים. רושמים את העסק ב-UP, מקבלים מדבקת QR אישית, והאורחים רואים מי עוד נמצא אצלכם ושולחים UP.';
    const ld = [
      org,
      {
        '@type': 'WebPage',
        '@id': `${base}/business#page`,
        name: title,
        description,
        url: `${base}/business`,
        inLanguage: 'he-IL',
        isPartOf: { '@id': `${base}/#site` },
        about: { '@id': `${base}/#app` },
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'UP', item: `${base}/` },
          { '@type': 'ListItem', position: 2, name: 'UP לעסקים', item: `${base}/business` },
        ],
      },
      faqLd(BUSINESS_FAQ),
    ];
    const kinds = [
      ['bar', 'בר'], ['pub', 'פאב'], ['club', 'מועדון'], ['cafe', 'בית קפה'],
      ['restaurant', 'מסעדה'], ['events', 'אירועים / אולם'], ['other', 'אחר'],
    ];
    return `${head({ title, description, path: '/business', ld })}
<body>
${header('business')}
<main id="main">

<section class="hero">
  <div class="wrap">
    <div>
      <div class="eyebrow"><i aria-hidden="true"></i> UP לעסקים</div>
      <h1>הבר שלכם, <span class="mint">המקום שבו מכירים אנשים</span></h1>
      <p class="lead">רשמו את העסק ל-UP וקבלו QR משלכם. מי שסורק אותו נכנס לחדר של המקום, רואה מי עוד כאן ושולח UP — והערב אצלכם נהיה חברתי יותר.</p>
      <div class="btns"><a class="btn btn-mint" href="#join">רישום העסק — 2 דקות</a><a class="btn btn-ghost" href="#how-biz">איך זה עובד</a></div>
      <div class="trust"><span>בלי ציוד</span><span>QR להדפסה</span><span>אימות מיקום לכל אורח</span></div>
      <p id="has-venue" hidden style="margin-top:20px"><a href="/business/status">כבר רשמתם עסק? לדף העסק שלכם ←</a></p>
    </div>
    <div aria-hidden="true"><div class="sticker-mini" style="transform:rotate(3deg);max-width:300px"><div class="b">UP</div><div class="n">השם של העסק שלכם</div>
      <svg viewBox="0 0 29 29" width="170" height="170" shape-rendering="crispEdges"><path fill="#111" d="M0 0h7v7H0zM1 1v5h5V1zM2 2h3v3H2zM22 0h7v7h-7zM23 1v5h5V1zM24 2h3v3h-3zM0 22h7v7H0zM1 23v5h5v-5zM2 24h3v3H2zM9 0h2v2H9zM13 1h3v2h-3zM9 4h4v2H9zM15 5h4v3h-4zM10 9h3v3h-3zM0 9h2v4H0zM4 10h3v2H4zM15 10h2v4h-2zM19 9h4v2h-4zM25 10h4v2h-4zM8 14h5v2H8zM20 13h3v4h-3zM2 15h4v2H2zM25 15h3v3h-3zM9 18h2v4H9zM13 17h4v2h-4zM18 19h3v3h-3zM23 20h2v2h-2zM13 21h3v3h-3zM9 24h2v4H9zM18 24h4v2h-4zM24 24h4v4h-4zM14 26h2v3h-2z"/></svg>
      <div class="c">סרקו כדי לראות מי כאן עכשיו ולשלוח UP</div></div></div>
  </div>
</section>

<section class="block alt" id="how-biz">
  <div class="wrap">
    <div class="section-head"><h2>איך מצטרפים?</h2><p>מהרישום ועד שהאורח הראשון נכנס לחדר שלכם.</p></div>
    <div class="grid g3 steps">
      <article class="card step"><h3>נרשמים כאן</h3><p>שם העסק, המיקום ופרטי קשר. הכי מדויק — לרשום כשאתם נמצאים בעסק, בלחיצה על "אני בעסק עכשיו".</p></article>
      <article class="card step"><h3>מאשרים ומקבלים QR</h3><p>אנחנו בודקים כל עסק ידנית. מיד אחרי האישור ה-QR שלכם פעיל — מדפיסים מדבקה מהדף האישי.</p></article>
      <article class="card step"><h3>האורחים סורקים ונפגשים</h3><p>כל סריקה = שעה בחדר של המקום, עם בדיקת מיקום. אתם רואים כמה אנשים מחוברים אצלכם ברגע זה.</p></article>
    </div>
  </div>
</section>

<section class="block">
  <div class="wrap">
    <div class="section-head"><h2>מה זה נותן לעסק</h2></div>
    <div class="grid g3">
      ${card('users', 'סיבה להגיע — ולהישאר', 'אנשים מגיעים לבר כדי לפגוש אנשים. UP הופכת את זה לקל: רואים מי כאן ושוברים את הקרח בלחיצה.')}
      ${card('qr', 'מדבקה אחת, בלי ציוד', 'QR קבוע שמדפיסים ותולים. בלי טאבלט, בלי אפליקציה לעסק, בלי חיבור לקופה.', true)}
      ${card('shield', 'רק מי שאצלכם', 'כל כניסה נבדקת מול המיקום של העסק. צילום של הקוד שנשלח לחבר בבית — לא יעבוד.')}
      ${card('spark', 'המותג שלכם על המסך', 'הלוגו שלכם קופץ עם קונפטי אצל כל מי שנכנס לחדר — ונשאר בזיכרון.', true)}
      ${card('chart', 'רואים מה קורה', 'בדף העסק מופיע כמה אנשים מחוברים אצלכם עכשיו. בלי לחשוף מי — רק כמה.')}
      ${card('heart', 'קהל שחוזר', 'Match שנולד אצלכם הוא סיפור שמספרים לחברים — ומקום שחוזרים אליו.', true)}
    </div>
  </div>
</section>

<section class="block alt" id="join">
  <div class="wrap" style="max-width:720px">
    <div class="section-head"><h2>רישום עסק ל-UP</h2><p>אחרי השליחה תקבלו קישור אישי לדף העסק — שם תראו את ה-QR ואת סטטוס האישור.</p></div>

    <form class="form" id="apply" novalidate>
      <h3><span class="n">1</span> פרטי העסק</h3>
      <div class="field"><label for="f-name">שם העסק</label><input id="f-name" name="name" required maxlength="60" autocomplete="organization" placeholder="לדוגמה: הבר של רוני"></div>
      <div class="field"><label>סוג העסק</label>
        <div class="chips" role="radiogroup">
          ${kinds.map(([v, l], i) => `<label><input type="radio" name="kind" value="${v}"${i === 0 ? ' checked' : ''}><span>${l}</span></label>`).join('')}
        </div>
      </div>

      <h3><span class="n">2</span> איפה העסק</h3>
      <p class="muted" style="font-size:14px">המיקום קובע מי יכול להיכנס לחדר שלכם, אז כדאי שיהיה מדויק.</p>
      <div class="loc-choice">
        <button class="btn btn-mint" type="button" id="gps">📍 אני בעסק עכשיו</button>
        <button class="btn btn-ghost" type="button" id="by-address">חיפוש לפי כתובת</button>
      </div>
      <div class="field" id="addr-box" hidden>
        <label for="f-address">כתובת העסק</label>
        <div style="display:flex;gap:8px"><input id="f-address" maxlength="160" autocomplete="street-address" placeholder="רחוב, מספר, עיר"><button class="btn btn-ghost btn-sm" type="button" id="search" style="min-height:50px">חיפוש</button></div>
        <div class="results" id="results"></div>
      </div>
      <div class="picked" id="picked"><iframe id="map" title="מיקום העסק במפה" loading="lazy"></iframe><div class="cap" id="picked-cap"></div></div>

      <h3 style="margin-top:22px"><span class="n">3</span> איש קשר</h3>
      <div class="field"><label for="f-contact">שם מלא</label><input id="f-contact" required maxlength="60" autocomplete="name"></div>
      <div class="field"><label for="f-phone">טלפון</label><input id="f-phone" type="tel" required inputmode="tel" autocomplete="tel" dir="ltr" placeholder="050-0000000"></div>
      <div class="field"><label for="f-email">אימייל (לא חובה)</label><input id="f-email" type="email" autocomplete="email" dir="ltr"></div>
      <div class="hp" aria-hidden="true"><label>Website<input id="f-website" tabindex="-1" autocomplete="off"></label></div>
      <label class="check"><input type="checkbox" id="f-terms"> <span>אני מוסמך/ת לרשום את העסק, ומאשר/ת ש-UP תיצור איתי קשר לגבי הרישום. UP מיועדת לגילאי 18 ומעלה.</span></label>
      <div class="err" id="err" role="alert"></div>
      <button class="btn btn-pink" type="submit" id="submit" style="width:100%">שליחה וקבלת QR</button>
    </form>

    <div class="form ok-box" id="done">
      <div class="big" aria-hidden="true">🎉</div>
      <h3 style="justify-content:center">העסק נרשם!</h3>
      <p class="muted">זה הקישור האישי לדף העסק שלכם. שמרו אותו — דרכו רואים את ה-QR ואת סטטוס האישור.</p>
      <div class="linkbox"><input id="done-link" readonly><button class="btn btn-ghost btn-sm" type="button" id="copy">העתקה</button></div>
      <a class="btn btn-mint" id="done-open" href="/business/status">לדף העסק וה-QR</a>
    </div>
  </div>
</section>

<section class="block" id="faq">
  <div class="wrap" style="max-width:860px">
    <div class="section-head"><h2>שאלות של בעלי עסקים</h2></div>
    <div class="faq">
        ${faqHtml(BUSINESS_FAQ)}
    </div>
  </div>
</section>

</main>
${footer}
<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var KEY = 'up.business.token';
  var picked = null;
  try { if (localStorage.getItem(KEY)) $('has-venue').hidden = false; } catch (e) {}

  function err(t) { $('err').textContent = t || ''; }
  function pick(lat, lng, label) {
    picked = { lat: lat, lng: lng, label: label };
    var d = 0.0025;
    $('map').src = 'https://www.openstreetmap.org/export/embed.html?bbox=' +
      (lng - d) + ',' + (lat - d) + ',' + (lng + d) + ',' + (lat + d) + '&layer=mapnik&marker=' + lat + ',' + lng;
    $('picked-cap').textContent = '✓ ' + label;
    $('picked').style.display = 'block';
    err('');
  }

  $('gps').onclick = function () {
    if (!navigator.geolocation) { err('הדפדפן לא תומך במיקום — חפשו לפי כתובת.'); return; }
    var b = this; b.disabled = true; b.textContent = 'מאתר מיקום…';
    navigator.geolocation.getCurrentPosition(function (p) {
      b.disabled = false; b.textContent = '📍 עדכון המיקום';
      var acc = Math.round(p.coords.accuracy);
      if (acc > 300) { err('המיקום לא מדויק (±' + acc + ' מ\\'). נסו שוב ליד חלון, או חפשו לפי כתובת.'); }
      pick(p.coords.latitude, p.coords.longitude, 'המיקום הנוכחי שלכם (דיוק ±' + acc + ' מ\\')');
    }, function () {
      b.disabled = false; b.textContent = '📍 אני בעסק עכשיו';
      err('לא קיבלנו הרשאת מיקום. אפשר לאשר בהגדרות הדפדפן, או לחפש לפי כתובת.');
    }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
  };
  $('by-address').onclick = function () { $('addr-box').hidden = false; $('f-address').focus(); };

  function search() {
    var q = $('f-address').value.trim();
    if (q.length < 3) { err('הקלידו כתובת מלאה יותר'); return; }
    $('results').innerHTML = '<span class="muted" style="font-size:14px">מחפש…</span>';
    fetch('/geo/search?q=' + encodeURIComponent(q)).then(function (r) { return r.json(); }).then(function (j) {
      var box = $('results'); box.innerHTML = '';
      if (!j.results || !j.results.length) { box.innerHTML = '<span class="muted" style="font-size:14px">לא נמצאה כתובת. נסו לכתוב גם את העיר.</span>'; return; }
      j.results.forEach(function (r) {
        var b = document.createElement('button'); b.type = 'button'; b.textContent = r.label;
        b.onclick = function () { pick(r.lat, r.lng, r.label); box.innerHTML = ''; };
        box.appendChild(b);
      });
    }).catch(function () { $('results').innerHTML = ''; err('החיפוש לא זמין כרגע. נסו "אני בעסק עכשיו".'); });
  }
  $('search').onclick = search;
  $('f-address').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });

  var MESSAGES = {
    name_required: 'מה שם העסק?', invalid_location: 'בחרו את מיקום העסק (שלב 2).',
    contact_name_required: 'מה השם שלכם?', invalid_phone: 'מספר הטלפון לא נראה תקין.',
    invalid_email: 'כתובת האימייל לא נראית תקינה.', terms_required: 'צריך לאשר את התנאים.',
    apply_rate_limited: 'יותר מדי ניסיונות. נסו שוב בעוד שעה.'
  };

  $('apply').onsubmit = function (e) {
    e.preventDefault(); err('');
    if (!$('f-name').value.trim()) return err(MESSAGES.name_required);
    if (!picked) return err(MESSAGES.invalid_location);
    if (!$('f-contact').value.trim()) return err(MESSAGES.contact_name_required);
    if (!$('f-phone').value.trim()) return err(MESSAGES.invalid_phone);
    if (!$('f-terms').checked) return err(MESSAGES.terms_required);
    var body = {
      name: $('f-name').value, kind: (document.querySelector('input[name=kind]:checked') || {}).value,
      address: $('f-address').value || (picked.label.indexOf('המיקום הנוכחי') === 0 ? '' : picked.label),
      lat: picked.lat, lng: picked.lng,
      contactName: $('f-contact').value, contactPhone: $('f-phone').value, contactEmail: $('f-email').value,
      website: $('f-website').value, terms: true
    };
    var s = $('submit'); s.disabled = true; s.textContent = 'שולח…';
    fetch('/business/apply', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { return r.json().then(function (j) { if (!r.ok) throw new Error(j.error); return j; }); })
      .then(function (j) {
        try { localStorage.setItem(KEY, j.ownerToken); } catch (e) {}
        $('done-link').value = j.statusUrl;
        $('done-open').href = '/business/status#k=' + j.ownerToken;
        $('apply').style.display = 'none'; $('done').style.display = 'block';
        $('done').scrollIntoView({ behavior: 'smooth', block: 'center' });
      })
      .catch(function (e2) { err(MESSAGES[e2.message] || 'משהו השתבש. נסו שוב.'); })
      .finally(function () { s.disabled = false; s.textContent = 'שליחה וקבלת QR'; });
  };
  $('copy').onclick = function () {
    var i = $('done-link'); i.select();
    (navigator.clipboard ? navigator.clipboard.writeText(i.value) : Promise.reject()).then(
      function () { $('copy').textContent = 'הועתק ✓'; },
      function () { document.execCommand('copy'); $('copy').textContent = 'הועתק ✓'; });
  };
})();
</script>
</body>
</html>`;
  };

  // -- the owner's page ---------------------------------------------------------------

  const statusHtml = () => `<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>UP · דף העסק</title>
<link rel="icon" href="/site/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/site/site.css?v=1">
<style>
  .st { display:inline-block; padding:4px 12px; border-radius:99px; font-weight:600; font-size:14px; }
  .st.pending { background:#ffc44d22; color:#ffc44d; } .st.approved { background:var(--mint-soft); color:var(--mint); }
  .st.rejected { background:#ff6b6b22; color:var(--danger); }
  .qr-wrap { position:relative; background:#fff; border-radius:22px; padding:18px; max-width:340px; margin:20px auto; }
  .qr-wrap svg { display:block; width:100%; height:auto; }
  .qr-wrap.locked svg { filter: blur(6px); opacity:.45; }
  .lock { position:absolute; inset:0; display:none; align-items:center; justify-content:center; text-align:center; color:#111; font-weight:600; padding:30px; }
  .qr-wrap.locked .lock { display:flex; }
  .kpi { font: 800 44px "Rubik", sans-serif; color: var(--mint); line-height:1; }
  #sticker { display:none; }
  @media print {
    @page { size: A5; margin: 10mm; }
    body { background:#fff !important; } body > *:not(#sticker) { display:none !important; }
    #sticker { display:flex !important; position:static; flex-direction:column; align-items:center; gap:12px; text-align:center; color:#111; }
    #sticker .brand { font: 800 72px "Rubik", sans-serif; color:#ff3d8b; line-height:1; }
    #sticker .name { font-size:30px; font-weight:600; }
    #sticker svg { width: 110mm; height:auto; }
    #sticker .cta { font-size:20px; } #sticker .small { font-size:13px; color:#555; }
  }
</style>
</head>
<body>
<header class="top"><div class="wrap"><a class="logo" href="/">UP</a><nav><a href="/business">UP לעסקים</a></nav></div></header>
<main class="wrap" style="max-width:640px;padding-top:30px;padding-bottom:60px">
  <div id="loading" class="muted">טוען…</div>
  <div id="nokey" hidden class="form">
    <h2>דף העסק</h2>
    <p class="muted">הקישור לדף הזה נשלח אליכם ברישום. אם הוא לא אצלכם — <a href="/business#join">רשמו את העסק</a> או צרו איתנו קשר.</p>
  </div>
  <div id="view" hidden>
    <p class="muted" style="margin:0">דף העסק שלכם ב-UP</p>
    <h1 id="v-name" style="font-size:36px;margin-top:4px"></h1>
    <p><span class="st" id="v-status"></span> <span class="muted" id="v-addr"></span></p>

    <div class="form" style="text-align:center">
      <h3 style="justify-content:center">ה-QR של העסק</h3>
      <p class="muted" id="qr-note"></p>
      <div class="qr-wrap" id="qr"><div id="qr-svg"></div><div class="lock">ממתין לאישור — ה-QR יהיה פעיל מיד אחרי שנאשר את העסק</div></div>
      <div class="btns" style="justify-content:center" id="qr-actions">
        <button class="btn btn-pink" type="button" onclick="window.print()">🖨 הדפסת מדבקה</button>
        <button class="btn btn-ghost" type="button" id="png">הורדה כתמונה</button>
      </div>
      <p class="muted" style="font-size:13px;margin-top:14px">קוד המקום: <b dir="ltr" id="v-code"></b></p>
    </div>

    <div class="grid g2" style="margin-top:16px">
      <div class="card"><div class="kpi" id="v-live">0</div><p>מחוברים אצלכם עכשיו</p></div>
      <div class="card"><h3>טיפים לתלייה</h3><p>ליד הבר, בשירותים ועל השולחנות. בגובה העיניים ובתאורה טובה — שהמצלמה תקלוט.</p></div>
    </div>
    <p class="muted" style="font-size:13px;margin-top:20px">שמרו את הקישור לדף הזה — הוא הגישה שלכם. אל תשתפו אותו.</p>
  </div>
</main>
<div id="sticker"><div class="brand">UP</div><div class="name" id="s-name"></div><div id="s-qr"></div>
  <div class="cta">סרקו כדי לראות מי כאן עכשיו ולשלוח UP</div><div class="small">כניסה לשעה · מאומת לפי מיקום · up.atar.co</div></div>
<script src="/site/qrcode.js"></script>
<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var KEY = 'up.business.token';
  var m = location.hash.match(/k=([A-Za-z0-9_-]+)/);
  var token = m ? m[1] : null;
  try { if (token) localStorage.setItem(KEY, token); else token = localStorage.getItem(KEY); } catch (e) {}
  if (!token) { $('loading').hidden = true; $('nokey').hidden = false; return; }

  var LABELS = { pending: 'ממתין לאישור', approved: 'פעיל', rejected: 'לא אושר' };
  function load() {
    fetch('/business/me', { headers: { 'x-business-token': token } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(render)
      .catch(function () { $('loading').hidden = true; $('nokey').hidden = false; });
  }
  var drawn = false;
  function render(v) {
    $('loading').hidden = true; $('view').hidden = false;
    $('v-name').textContent = v.name; $('s-name').textContent = v.name;
    $('v-code').textContent = v.code;
    $('v-addr').textContent = v.address || '';
    var st = $('v-status'); st.textContent = LABELS[v.status] || v.status; st.className = 'st ' + v.status;
    $('v-live').textContent = v.live || 0;
    if (!drawn) {
      var q = qrcode(0, 'H'); q.addData(v.joinUrl); q.make();
      var svg = q.createSvgTag({ cellSize: 8, margin: 2, scalable: true });
      $('qr-svg').innerHTML = svg; $('s-qr').innerHTML = svg; drawn = true;
    }
    var ok = v.status === 'approved' && v.active;
    $('qr').classList.toggle('locked', !ok);
    $('qr-actions').style.display = ok ? '' : 'none';
    $('qr-note').textContent = ok
      ? 'כל סריקה מכניסה לחדר של ' + v.name + ' ל-' + v.sessionMinutes + ' דקות, אחרי בדיקת מיקום.'
      : v.status === 'rejected' ? 'הרישום לא אושר. אפשר ליצור איתנו קשר לפרטים.' : 'אנחנו בודקים את העסק. הדף יתעדכן לבד ברגע שיאושר.';
  }
  $('png').onclick = function () {
    var svg = $('qr-svg').querySelector('svg'); if (!svg) return;
    var img = new Image(); var size = 1200;
    img.onload = function () {
      var c = document.createElement('canvas'); c.width = size; c.height = size;
      var x = c.getContext('2d'); x.fillStyle = '#fff'; x.fillRect(0, 0, size, size); x.drawImage(img, 0, 0, size, size);
      var a = document.createElement('a'); a.download = 'UP-QR-' + $('v-code').textContent + '.png'; a.href = c.toDataURL('image/png'); a.click();
    };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(svg));
  };
  load(); setInterval(load, 60000);
})();
</script>
</body>
</html>`;

  // -- for crawlers and installers ------------------------------------------------------

  const robots = () => `User-agent: *
Allow: /
Disallow: /admin
Disallow: /business/status
Disallow: /app
Disallow: /media/
Disallow: /auth/
Disallow: /me/
Disallow: /live/

Sitemap: ${base}/sitemap.xml
`;

  const sitemap = () => {
    const day = new Date().toISOString().slice(0, 10);
    const url = (loc, priority) =>
      `  <url><loc>${base}${loc}</loc><lastmod>${day}</lastmod><changefreq>weekly</changefreq><priority>${priority}</priority></url>`;
    return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${url('/', '1.0')}
${url('/business', '0.8')}
</urlset>
`;
  };

  const manifest = () =>
    JSON.stringify({
      name: 'UP — הכרויות במקום',
      short_name: 'UP',
      description: 'אפליקציית הכרויות לאנשים שנמצאים איתך באותו מקום, עכשיו.',
      lang: 'he',
      dir: 'rtl',
      start_url: '/app',
      scope: '/',
      display: 'standalone',
      orientation: 'portrait',
      background_color: '#0d0a14',
      theme_color: '#0d0a14',
      icons: [
        { src: '/site/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/site/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/site/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    });

  // Rendered once: none of these change while the process runs (except the
  // year and the sitemap date, which can wait for the next restart).
  const once = (fn) => {
    let v;
    return () => (v ??= fn());
  };
  return {
    landing: once(landingHtml),
    business: once(businessHtml),
    status: once(statusHtml),
    robots: once(robots),
    sitemap: once(sitemap),
    manifest: once(manifest),
  };
}
