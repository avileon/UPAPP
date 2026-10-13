# UP — אימות נוכחות במקום (QR מתחלף + זיהוי יציאה)

> סטטוס: **מפרט, לא ממומש** · נכתב: 13.10.2026 · בסיס קוד: `cb806f1`
> מטרה: לוודא שמי שמופיע בחדר באמת נמצא בו פיזית, ולזהות מתי יצא.

---

## 1. הבעיה

| בעיה | היום | אחרי |
|---|---|---|
| כניסה | `venue` הוא טקסט חופשי — כל אחד מכל מקום יכול להקליד `BAR12` | מקום רשום דורש סריקת QR מתחלף + בדיקת GPS |
| יציאה | הסשן חי עד `expiresAt` (עד שעתיים) גם אם האדם הלך הביתה אחרי 10 דק' | נוכחות דועכת לפי זמן מאז האימות האחרון + בדיקות GPS + Geofence |
| אמינות בעיני המשתמש | "בחדר" = אולי | "כאן עכשיו" / "היה כאן לפני 30 דק'" + תג אימות |

עיקרון: **אין צורך בדיוק של 100%**. המטרה היא שהמידע יהיה כן לגבי טריות שלו — יציאה שלא זוהתה לא שוברת את החוויה, כי היא מוצגת כ"היה כאן לפני X".

---

## 2. סקירת הפתרון — 3 שכבות

```
שכבה 1 — כניסה:     QR מתחלף (20 ש') + GPS ברגע הסריקה      → web + android
שכבה 2 — דעיכה:      TTL גולש 90 דק' + heartbeat בכל פתיחה    → web + android
שכבה 3 — יציאה פעילה: Geofence EXIT ברקע                     → android native בלבד
שכבה 4 — (עתידי):    ביקון BLE במקום                         → android native
```

---

## 3. שכבה 1 — QR מתחלף

### 3.1 מקום רשום (Verified Venue)

מקום רשום = `venue` key קיים (אותו פורמט של `normaliseVenue`: A-Z0-9, 3–12 תווים) + סוד + מיקום.
מקום **לא רשום** ממשיך לעבוד בדיוק כמו היום (קוד שמוקלד ידנית, ללא אימות) — לא שוברים כלום.

```sql
CREATE TABLE IF NOT EXISTS venues (
  code              TEXT PRIMARY KEY,          -- normaliseVenue(), e.g. "CAFEHAIFA"
  name              TEXT NOT NULL,             -- שם תצוגה: "קפה הנמל"
  lat               REAL NOT NULL,
  lng               REAL NOT NULL,
  radius_m          INTEGER NOT NULL DEFAULT 80,
  qr_secret         TEXT NOT NULL,             -- 32 bytes random, base64. צד שרת בלבד
  display_token_hash TEXT NOT NULL,            -- hashSecret(displayToken) — המסך מזדהה בו
  active            INTEGER NOT NULL DEFAULT 1,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
```

> `qr_secret` נשמר גולמי כי צריך אותו ל-HMAC. ה-display token נשמר רק כ-hash (כמו refresh tokens).

### 3.2 יצירת הטוקן

```
window   = floor(now_ms / (QR_WINDOW_SECONDS * 1000))       // ברירת מחדל 20
token    = base32( HMAC-SHA256(qr_secret, `${code}:${window}`) ).slice(0, 10)
```

- השרת מקבל את `window` הנוכחי **ואת הקודם** (חלון תקף בפועל: 20–40 ש').
- אותו טוקן משמש את כל מי שבחדר באותו חלון — זה תקין. הוא מוכיח "ראיתי את המסך לאחרונה", לא זהות.

### 3.3 תוכן ה-QR

```
https://up.atar.co/v/CAFEHAIFA?t=K7QX2M9PLA
```

- סריקה במצלמה הרגילה של הטלפון פותחת ישר את אפליקציית הווב → מסך "כניסה לחדר" עם הקוד והטוקן ממולאים.
- תואם את הגישה הקיימת (`lib/static.js` כבר מגיש קישור שמכיל כתובת + חדר).
- הטוקן חייב להגיע לשרת תוך החלון → הלקוח שולח `/live/start` מיד, לפני שאלות נוספות (intent/note אפשר לעדכן אחר כך, או לשמור את ה-intent האחרון כברירת מחדל).

### 3.4 מסך התצוגה במקום

- דף סטטי: `GET /display/:code?k=<displayToken>` — טאבלט/מסך ישן/טלפון ישן על מעמד.
- הדף מושך כל 5 ש': `GET /venues/:code/qr` עם כותרת `x-display-token` → `{ url, validForMs }`.
- מצייר QR בצד לקוח (ספריית `qrcode-generator` ‏vendored לתוך `server/src/static/`, בלי CDN).
- מציג פס התקדמות של החלון + שם המקום + "סרקו כדי להיכנס ל-UP".
- **הסוד לא יוצא מהשרת** — המסך מקבל רק את הטוקן הנוכחי.
- אם המסך מאבד אינטרנט: מציג "אין חיבור" במקום QR ישן (אסור להציג טוקן פג).

### 3.5 מתקפת "צילום מסך לחבר בחוץ"

| הגנה | מה היא עוצרת |
|---|---|
| חלון 20–40 ש' | צילום שנשלח ונסרק אחרי דקה |
| בדיקת GPS ברגע הצ'ק-אין | מי שקיבל צילום בזמן אמת אבל נמצא במקום אחר |
| Rate limit: 5 ניסיונות QR שגויים / 10 דק' / משתמש | ניחוש טוקנים |

שארית סיכון מקובלת: חבר שנמצא 100 מ' מחוץ למקום עם צילום חי. זה לא שווה סיבוך נוסף.

### 3.6 בדיקת מיקום בצ'ק-אין

```
distance = haversine(user, venue)
allowed  = distance <= radius_m + min(accuracy, MAX_ACCURACY_CREDIT_M)
```

- `MAX_ACCURACY_CREDIT_M = 150` — שלא יגיע "דיוק 3 ק"מ" ויעבור.
- `accuracy > 500` → לא נחשב כמיקום תקין, כאילו לא נשלח מיקום.

### 3.7 רמות אימות

| `verification` | תנאי | תג בממשק |
|---|---|---|
| `qr_gps` | QR תקף + GPS בתוך הרדיוס | ✓ מאומת במקום |
| `qr` | QR תקף, המשתמש סירב למיקום / מיקום לא מדויק | ✓ סרק במקום |
| `null` | חדר לא רשום (קוד ידני — ההתנהגות של היום) | בלי תג |

- QR תקף + GPS **מחוץ** לרדיוס → דחייה `too_far` (זה בדיוק התרחיש של צילום שהועבר).
- ניסיון להיכנס לחדר **רשום** בקוד ידני בלי טוקן → `qr_required`.

---

## 4. שכבה 2 — דעיכת נוכחות (web + android)

### 4.1 שדות חדשים בסשן (`PresenceStore`, בזיכרון)

```js
{
  ...existing,                // id, userId, startedAt, expiresAt, venue, intent, note
  verification: 'qr_gps' | 'qr' | null,
  lastVerifiedAt: number,     // ms — הצ'ק-אין, סריקה חוזרת, או heartbeat עם GPS קרוב
  farStrikes: number,         // קריאות GPS רחוקות ברצף
  endReason: null,            // נשמר רק ל-log/תגובה: 'left_venue' | 'presence_expired' | 'manual' | 'geofence_exit'
}
```

### 4.2 מצב נוכחות מחושב

```
age = now - lastVerifiedAt

age <= PRESENCE_FRESH (10 דק')        → 'here'     "כאן עכשיו"
age <= PRESENCE_TTL   (90 דק')        → 'recent'   "היה כאן לפני ~30 דק'"
age >  PRESENCE_TTL                   → stopLive(reason='presence_expired')
```

- רק לחדרים רשומים. בחדר לא רשום — ההתנהגות של היום (`expiresAt` בלבד).
- `expiresAt` הקיים (מקסימום `LIVE_MAX_DURATION`) נשאר כתקרה קשיחה.
- דקות מוצגות מעוגלות ל-5 (פרטיות — לא לחשוף זמן כניסה מדויק).

### 4.3 Heartbeat

```
POST /live/heartbeat
{ lat?, lng?, accuracy? }
```

הלקוח קורא ל-heartbeat:
- בפתיחת האפליקציה / `visibilitychange → visible`
- כל 5 דק' כל עוד האפליקציה בחזית
- **לא** ברקע (ב-PWA זה בלתי אפשרי ממילא)

לוגיקה בשרת:

| קלט | פעולה |
|---|---|
| GPS בתוך הרדיוס | `lastVerifiedAt = now`, `farStrikes = 0` |
| GPS מחוץ ל-`radius + accuracy + 50m` | `farStrikes++`; אם `farStrikes >= 2` → `stopLive('left_venue')` |
| GPS לא מדויק (> 500m) / בלי מיקום | לא משנה כלום (לא מאריך, לא מעיף) |

- שתי קריאות רחוקות ברצף (לפחות 60 ש' ביניהן) — כדי לא להעיף בגלל קפיצת GPS בתוך בניין.
- תגובה: `{ live, presence, lastVerifiedAt, endReason? }` → אם `live:false` הלקוח מציג "יצאת מ-קפה הנמל" + כפתור "אני עדיין כאן → סרוק שוב".

### 4.4 סריקה חוזרת

סריקת QR כשכבר `live` באותו חדר → `POST /live/reverify { qrToken, lat?, lng?, accuracy? }` → מעדכן `lastVerifiedAt` ו-`verification`. בלי ליצור סשן חדש ובלי לאבד tokens/intent.

### 4.5 תזכורת לפני דעיכה

ב-75 דק' מאז האימות האחרון → Web Push (התשתית כבר קיימת ב-`push.js`):
"עדיין ב-קפה הנמל? פתח את UP כדי להישאר בחדר". פתיחה → heartbeat → מתחדש.

---

## 5. שכבה 3 — Geofence באנדרואיד (נייטיב)

- `GeofencingClient` (Google Play Services), דרך plugin של Flutter (לבדוק: `native_geofence` / ערוץ פלטפורמה קטן משלנו).
- בצ'ק-אין לחדר רשום: רישום geofence עם `lat/lng/radius_m + 50`, טריגר `EXIT`, `loiteringDelay` לא רלוונטי ל-EXIT → משתמשים ב-`notificationResponsiveness = 120s`.
- ב-EXIT: `POST /live/stop { reason: 'geofence_exit' }` מתוך BroadcastReceiver/WorkManager.
- הסרת ה-geofence ב-`stopLive` מכל סיבה.
- **הרשאות:** `ACCESS_FINE_LOCATION` + `ACCESS_BACKGROUND_LOCATION`. מדיניות Google Play דורשת הצדקה + מסך הסבר לפני הבקשה. אופציונלי למשתמש — מי שמסרב נשאר בשכבה 2.
- iOS: לא רלוונטי כרגע (אין אפליקציה נייטיב ל-iOS; Safari לא תומך במיקום ברקע).

---

## 6. שכבה 4 — ביקון BLE (עתידי, לא ב-MVP)

- ESP32 (~20 ₪) במקום, משדר מזהה מתחלף (בסגנון Eddystone-EID) — אותו עיקרון כמו ה-BLE tokens הקיימים ב-`PresenceStore`.
- אנדרואיד סורק ברקע → heartbeat "ראיתי ביקון" = אימות חזק גם בתוך בניין שבו GPS חלש.
- מתאים למקומות שותפים/פרימיום. מחליף את ה-GPS כאות הנוכחות העיקרי.

---

## 7. API — סיכום שינויים

| Method | Path | Auth | שינוי |
|---|---|---|---|
| POST | `/live/start` | user | **הרחבה:** `qrToken?`, `lat?`, `lng?`, `accuracy?`. מחזיר גם `verification`, `venueName`, `presence` |
| POST | `/live/heartbeat` | user | **חדש** |
| POST | `/live/reverify` | user | **חדש** |
| POST | `/live/stop` | user | **הרחבה:** `reason?` (`manual` / `geofence_exit`) |
| POST | `/nearby/resolve` (הקיים — מחזיר גם את `venuePeers`) | user | **הרחבה:** לכל peer: `presence`, `minutesAgo` (מעוגל ל-5), `verification` |
| GET | `/rooms` | user | **הרחבה:** `name`, `verified: true` לחדרים רשומים; חדרים רשומים קודם |
| GET | `/venues/:code/qr` | `x-display-token` | **חדש** → `{ url, validForMs }` |
| GET | `/display/:code` | `?k=` | **חדש** — דף המסך |
| POST | `/admin/venues` | `x-admin-token` | **חדש** — יצירה; מחזיר `displayUrl` (הטוקן מוצג פעם אחת בלבד) |
| PATCH | `/admin/venues/:code` | `x-admin-token` | **חדש** — שם/רדיוס/מיקום/active, `rotateSecret`, `rotateDisplayToken` |

### קודי שגיאה חדשים

`qr_required` · `qr_invalid` · `qr_expired` (לא מבחינים בינו לבין invalid מול המשתמש — אותה הודעה: "הקוד התחלף, סרקו שוב") · `too_far` · `venue_inactive` · `not_live`

---

## 8. קונפיגורציה (`config.js`)

| ENV | ברירת מחדל | |
|---|---|---|
| `QR_WINDOW_SECONDS` | 20 | אורך חלון טוקן |
| `PRESENCE_FRESH_SECONDS` | 600 | "כאן עכשיו" |
| `PRESENCE_TTL_SECONDS` | 5400 | אחרי זה — יציאה אוטומטית |
| `PRESENCE_REMIND_SECONDS` | 4500 | Push "עדיין כאן?" |
| `HEARTBEAT_FAR_STRIKES` | 2 | קריאות רחוקות עד יציאה |
| `HEARTBEAT_FAR_MARGIN_M` | 50 | מרווח מעבר לרדיוס |
| `MAX_ACCURACY_CREDIT_M` | 150 | |
| `MAX_ACCEPTED_ACCURACY_M` | 500 | מעל זה = אין מיקום |
| `LIVE_MAX_DURATION` | 7200 (קיים) | לשקול להעלות ל-4 ש' בחדרים רשומים |

---

## 9. פרטיות

- **לא שומרים מיקום של משתמשים.** `lat/lng` משמשים רק לחישוב מרחק בתוך הבקשה ונזרקים. לא ב-DB, לא בזיכרון, לא בלוגים (`logRefusal` כבר לא מדפיס bodies — לשמור על זה).
- נשמר בזיכרון בלבד ולמשך הסשן: `venue`, `verification`, `lastVerifiedAt`.
- ל-peers נחשפים רק `presence` + דקות מעוגלות — לא זמן כניסה מדויק, לא מרחק.
- מיקום המקום (venue) הוא ציבורי מטבעו — זה בסדר.
- מסר שיווקי: "UP יודע שאתה בחדר, לא איפה אתה".

---

## 10. בדיקות (`server/test/`)

- [ ] טוקן של החלון הנוכחי והקודם מתקבל; שני חלונות אחורה — נדחה
- [ ] טוקן של מקום A לא עובד במקום B
- [ ] QR תקף + GPS רחוק → `too_far`
- [ ] QR תקף בלי GPS → `verification: 'qr'`
- [ ] קוד ידני לחדר רשום → `qr_required`; קוד ידני לחדר לא רשום → עובד כמו היום
- [ ] heartbeat קרוב מאריך `lastVerifiedAt`
- [ ] heartbeat רחוק פעם אחת → עדיין live; פעמיים → `left_venue`
- [ ] heartbeat לא מדויק → לא משנה כלום
- [ ] אחרי `PRESENCE_TTL` בלי אימות → נעלם מ-`venuePeers` ו-`rooms`
- [ ] `minutesAgo` מעוגל ל-5
- [ ] `/venues/:code/qr` בלי display token / עם טוקן שגוי → 401
- [ ] rate limit על QR שגוי
- [ ] אף נתיב לא כותב lat/lng ללוג (בדיקה על stdout)

---

## 11. שלבים

### שלב 1 — MVP (web + android, בלי הרשאות רקע)
- [ ] טבלת `venues` + admin endpoints
- [ ] יצירת/אימות טוקן HMAC (`domain/venueQr.js`)
- [ ] דף `/display/:code` + QR בצד לקוח
- [ ] נתיב `/v/:code?t=` בווב → מסך כניסה לחדר
- [ ] הרחבת `/live/start` + רמות אימות
- [ ] `lastVerifiedAt` + חישוב `presence` + דעיכה ב-`sweep()`
- [ ] `/live/heartbeat` + `/live/reverify`
- [ ] UI: תג אימות, "כאן עכשיו" / "לפני X דק'", מסך "יצאת מהחדר"
- [ ] בדיקות סעיף 10
- [ ] פיילוט: מקום אחד אמיתי + טלפון ישן כמסך

### שלב 2 — אנדרואיד
- [ ] Geofence EXIT + מסך הסבר להרשאת רקע
- [ ] Push "עדיין כאן?" ב-75 דק'

### שלב 3 — שותפים
- [ ] ביקון BLE
- [ ] פאנל בעל מקום (סטטיסטיקה אנונימית: כמה אנשים היו הערב)

---

## 12. החלטות פתוחות

1. **בלי GPS — לאפשר כניסה (`qr`) או לחסום?** ההמלצה: לאפשר עם תג חלש יותר; לחסום רק אם יתגלה ניצול לרעה.
2. **TTL 90 דק'** — לבדוק בפיילוט. בבר אנשים יושבים 2–3 שעות ולא פותחים את האפליקציה; ה-Push ב-75 דק' אמור לכסות את זה.
3. **`LIVE_MAX_DURATION` בחדרים רשומים** — להשאיר שעתיים או להעלות ל-4 כי יש דעיכה אמיתית?
4. **מי רושם מקומות?** כרגע רק admin. בהמשך: בעל מקום נרשם בעצמו ומאמת מיקום מהמסך.
5. **מסך תצוגה** — לספק טלפון/טאבלט ישן, או מדבקה סטטית + QR דינמי רק בחדרים "פרימיום"?
