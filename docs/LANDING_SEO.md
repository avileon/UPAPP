# UP — דף נחיתה, SEO והרשמת עסקים (29.10.2026)

## מבנה כתובות
| נתיב | מה |
|---|---|
| `/` | דף נחיתה (HTML אמיתי, נסרק ע"י גוגל). `/?venue=` ו-`/?chat=` עדיין פותחים את האפליקציה — מדבקות שכבר מודפסות ממשיכות לעבוד |
| `/app` | אפליקציית Flutter (noindex). PWA שהותקן לפני השינוי ופותח `/` מועבר אוטומטית ל-`/app` |
| `/business` | דף עסקים + טופס הרשמה |
| `/business/status#k=TOKEN` | דף בעל העסק: סטטוס, QR, הדפסה/PNG, מחוברים עכשיו (noindex) |
| `/robots.txt`, `/sitemap.xml`, `/manifest.json`, `/site/*`, `/icons/*` | SEO, PWA, נכסים |

## הרשמת עסק
- `POST /business/apply` — יוצר מקום `status='pending'`, `active=0`. מחזיר `ownerToken` (נשמר כ-hash בלבד) ו-`statusUrl`. 5 ניסיונות לשעה לכתובת IP, honeypot.
- `GET /business/me` (`x-business-token`) — מה שבעל העסק רואה.
- `GET /geo/search?q=` — כתובת → מיקום דרך Nominatim (OSM), בקשה לשנייה, cache.
- `/admin` → "בקשות הצטרפות": אישור (`POST /admin/venues/:code/approve`) / דחייה (`/reject`).

## SEO
- title/description/canonical/OG/Twitter, תמונת OG 1200×630, JSON-LD: Organization, WebSite, WebApplication, FAQPage, BreadcrumbList.
- תוכן מלא בעברית: איך זה עובד, יתרונות, השוואה לאפליקציות רגילות, 12 שאלות נפוצות.
- פונטים מוקטנים ל-woff2 (~65KB), בלי JS חיצוני.

## לעשות ידנית
- Google Search Console: לאמת את up.atar.co (רשומת TXT ב-Cloudflare) ולהגיש את `sitemap.xml`.
- דומיין ייעודי למותג יחזק את הדירוג בטווח הארוך.
