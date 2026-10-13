# UP — אימות פנים חי + התאמת תמונות פרופיל

> סטטוס: **שלב 1 הושלם** (face-svc) · שלבים 2–4 טרם מומשו · נכתב: 13.10.2026 · בסיס קוד: `61d781f`
> מחליף/מרחיב את אימות התמונה הקיים (`domain/verification.js`, 9.9.26)

## החלטות (13.10.2026)

| נושא | החלטה |
|---|---|
| תמונות פרופיל | **גלריה + התאמת פנים** — מותר להעלות מהגלריה, כל תמונה נבדקת מול הפנים מהאימות החי |
| מנוע | **אצלנו בשרת** (Hetzner), מודלים בקוד פתוח, שום תמונה לא יוצאת לצד שלישי |
| צילום אימות | **מצלמה חיה בתוך האפליקציה בלבד** — אין בחירת קובץ בשום מסלול |

---

## 1. מה קיים היום ומה חסר

| | היום | אחרי |
|---|---|---|
| סלפי אימות | `image_picker` + `ImageSource.camera` | מצלמה חיה בתוך האפליקציה (`camera` plugin), בלי input של קובץ |
| הוכחת "חי" | תנוחת יד אקראית, אדם מאשר ידנית | רצף תנועות ראש אקראי, **השרת** בודק אוטומטית |
| תמונות פרופיל | גלריה, אף אחד לא בודק שזה אתה | כל תמונה חייבת להכיל את הפנים המאומתות |
| החלטה | ידנית תמיד | אוטומטית; רק מקרים גבוליים מגיעים לתור הידני הקיים |

### למה לא מספיק `ImageSource.camera`

בווב, `image_picker` עם camera הוא `<input type=file capture>`. בחלק מהדפדפנים (דסקטופ, חלק מאנדרואיד) זה פותח בוחר קבצים, כלומר אפשר להעלות כל תמונה. הפתרון: preview של וידאו חי (`getUserMedia`) בתוך האפליקציה, וצילום frame ממנו. אין כפתור "בחר קובץ" בשום מצב.

---

## 2. ארכיטקטורה

```
Flutter (web/android)                Node (up.service)                 face-svc (Python, 127.0.0.1:8091)
─────────────────────                ─────────────────                 ─────────────────────────────────
camera preview חי     ──frames──▶   /me/verification/frames  ──▶     POST /analyze  (YuNet + SFace)
                                     מחליט: approved/review/reject ◀── faces[]: box, score, 5 landmarks,
גלריה                 ──photo───▶   /media/photo              ──▶                yaw, blur, embedding
                                     cosine מול התבנית
```

### 2.1 face-svc — שירות צד (Python)

- **למה שירות נפרד:** שרת ה-Node בלי dependencies, וזה מכוון. ראייה ממוחשבת ב-Node דורשת bindings נייטיב כבדים. שירות Python קטן, שמאזין רק ל-localhost, שומר על ה-Node נקי.
- סטאק: `opencv-python-headless` + `numpy` + `http.server` (או FastAPI אם נוח יותר).
- מודלים מ-OpenCV Zoo, ב-**רישיונות שמתירים שימוש מסחרי**:
  - זיהוי פנים: `face_detection_yunet_2023mar.onnx` (MIT)
  - זיהוי זהות: `face_recognition_sface_2021dec.onnx` (Apache-2.0), embedding של 128 ממדים
  - ⚠️ **לא InsightFace/buffalo** — המודלים המאומנים שלהם לשימוש לא-מסחרי בלבד, וזה מוצר שנמכר.
- ביצועים צפויים על CX23 (2 vCPU): כ-50–150ms לתמונה, כ-200MB RAM.
- `provision.sh`: מוריד את המודלים עם sha256 נעול, יוצר venv, systemd unit `up-face.service`, ומאזין ל-`127.0.0.1:8091` בלבד.
- השירות **stateless**: לא שומר כלום לדיסק ולא כותב תמונות או embeddings ללוג.

```
POST /analyze   body: JPEG/PNG bytes   (max 8MB, נחתך ל-1280px בצד הארוך)
→ 200 {
    width, height,
    faces: [{
      box: [x, y, w, h], score,                // YuNet
      landmarks: [[x,y] × 5],                  // עין ימין, עין שמאל, אף, פה ימין, פה שמאל
      yaw: -1..1,                              // הערכה מ-landmarks, ראה 3.3
      blur: number,                            // variance of Laplacian על אזור הפנים
      embedding: base64(float32[128])          // SFace, מנורמל
    }]
  }
GET /health → { ok, models: {...sha256} }
```

ההשוואה (cosine) נעשית ב-Node, כי זו מכפלה סקלרית של 128 מספרים.

---

## 3. אימות חי (Liveness + תבנית פנים)

### 3.1 אתגר מהשרת

`POST /me/verification/challenge` מחזיר רצף צעדים אקראי. ה-TTL הוא 90 ש', ויש אתגר פתוח אחד לכל משתמש (נשאר כמו היום ב-`ChallengeStore`):

```json
{
  "id": "…",
  "steps": ["center", "left", "center", "right"],   // סדר left/right אקראי; לפעמים 5 צעדים
  "expiresAt": "…"
}
```

- הצעדים האפשריים: `center` · `left` · `right` · `up`. תמיד מתחילים ב-`center`.
- תנוחת היד הקיימת (`POSES`) נשארת **רק** למסלול הידני (ראה סעיף 6).

### 3.2 צילום בצד הלקוח

- `camera` plugin (תומך ב-web וב-Android), מצלמה קדמית.
- על המסך: מסגרת אובלית, חץ/הוראה לכל צעד ("סובב את הראש שמאלה"), וספירה לאחור של 1.5 ש'. אחריה `takePicture()` ומעבר לצעד הבא.
- **ה-frames שנשלחים לא עוברים mirror**, גם אם ה-preview משוקף. השרת מגדיר כיוון לפי התמונה הגולמית, והלקוח מתרגם את החץ בהתאם.
- דחיסה ל-720px JPEG q=0.85 לפני השליחה.
- כל ה-frames נשלחים בבקשה אחת: `POST /me/verification/frames` (multipart: `challengeId`, `frame_0..frame_n`).

### 3.3 בדיקות בשרת

לכל frame:

| בדיקה | סף | כשל |
|---|---|---|
| בדיוק פנים אחת | `score ≥ 0.9` | `no_face` / `multiple_faces` |
| גודל פנים | `box.w ≥ 25%` מרוחב התמונה | `face_too_small` |
| חדות | `blur ≥ BLUR_MIN` (לכייל בפיילוט) | `too_blurry` |
| כיוון ראש | `center: |yaw| < 0.12` · `left: yaw < -0.25` · `right: yaw > 0.25` · `up`: יחס אף-עיניים | `wrong_direction` |

הערכת yaw מ-5 נקודות: `yaw = (nose.x − eyesMid.x) / interocularDistance`.

בין ה-frames:

| בדיקה | סף |
|---|---|
| אותו אדם בכל ה-frames | cosine בין כל `center` לכל שאר ה-frames `≥ 0.45` |
| ה-frames לא זהים | cosine בין שני `center` `< 0.995` (הגנה מפני אותה תמונה שנשלחה פעמיים) |
| זמן | כל הבקשה מגיעה לפני `expiresAt` |

### 3.4 החלטה

```
כל הבדיקות עברו                          → approved (אוטומטי)
עבר זהות וזמן, נכשל רק blur/direction ב-1 frame → pending → התור הידני הקיים (עם frame ה-center בלבד)
אחרת                                      → rejected + reason → מותר לנסות שוב
```

- Rate limit: 5 ניסיונות ליום למשתמש.
- **אחרי approved:** נשמרת **תבנית** בלבד: ממוצע מנורמל של ה-embeddings של ה-`center`. ה-frames נמחקים מיד.

### 3.5 מה זה לא עוצר (כנות)

- **מצלמה וירטואלית / deepfake בזמן אמת בדסקטופ.** הדפדפן לא יכול להוכיח שה-frame הגיע מחיישן אמיתי. מקטינים את הסיכון באמצעות רצף אקראי ש-deepfake זול מתקשה לעקוב אחריו, ובאמצעות חסימת אימות מדסקטופ (בדיקת user-agent ו-`pointer: coarse`, שהן הרתעה ולא הגנה).
- **מסכה/תמונה מודפסת שמוזזת.** הזזת תמונה שטוחה לא משנה את ה-yaw בצורה עקבית, וזה עוצר את רוב המקרים. לא את כולם.
- המטרה היא כמו קודם: **להעלות את המחיר**, לא להבטיח שאי אפשר.

---

## 4. התאמת תמונות פרופיל

### 4.1 בהעלאה (`POST /media/photo`)

```
1. face-svc /analyze
2. faces.length == 0                        → 400 photo_no_face
3. max(cosine(face.embedding, template))    → לפי ספים:
     ≥ MATCH_ACCEPT (0.40)                  → נשמר, face_match = 'ok'
     ≥ MATCH_REVIEW (0.30)                  → נשמר, face_match = 'review' → תור ידני
     <  MATCH_REVIEW                        → 400 photo_face_mismatch (הקובץ לא נשמר)
```

- תמונה קבוצתית תקינה אם **אחת** מהפנים מתאימה.
- ספי SFace: OpenCV ממליצה על 0.363 ל"אותו אדם". 0.40 הוא שמרני, ולכייל בפיילוט.
- **משתמש שעוד לא אומת:** התמונה נשמרת עם `face_match = 'unverified'`, וההתאמה רצה אוטומטית ברגע שהאימות עובר. תמונה שלא מתאימה מוסתרת, ונשלחת התראה.
- תמונה ראשית (`photo_primary`) חייבת `ok`.

### 4.2 שינוי בסכמה

```sql
-- photos היום הוא JSON array של keys. מוסיפים טבלה במקום לשנות את הפורמט:
CREATE TABLE IF NOT EXISTS photo_checks (
  storage_key  TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  face_match   TEXT NOT NULL,       -- ok | review | unverified | rejected
  score        REAL,                -- cosine הגבוה ביותר
  checked_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS face_templates (
  user_id      TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  embedding    BLOB NOT NULL,       -- AES-256-GCM(float32[128]), מפתח ב-/var/lib/up/.face-key
  model        TEXT NOT NULL,       -- 'sface-2021dec' — תבנית ממודל אחר לא מושווית
  consent_at   TEXT NOT NULL,
  created_at   TEXT NOT NULL
);
```

- `verifications` נשאר כמו שהוא, ומתווספות לו עמודות: `method` (`live` | `manual`), `score`, `reason`.
- `/nearby/resolve` ו-`/media/:key` מגישים רק תמונות `ok` (או `unverified` לבעלים עצמו).

### 4.3 Backfill בפריסה

סקריפט חד-פעמי `server/scripts/backfill-face.js`: לכל משתמש עם אימות `approved` ישן (ידני), התבנית נוצרת מהתמונה הראשית שלו **אחרי** שהוא מאשר הסכמה בפעם הבאה שהוא נכנס. עד אז הוא נשאר עם התג הישן, ותמונות חדשות שהוא מעלה ממתינות.

---

## 5. פרטיות והסכמה

> מידע ביומטרי הוא **"מידע בעל רגישות מיוחדת"** לפי תיקון 13 לחוק הגנת הפרטיות (בתוקף מאוגוסט 2025). זה לא ייעוץ משפטי, וכדאי לעבור על זה עם עו"ד לפני השקה ציבורית.

- **מסך הסכמה מפורש** לפני האימות הראשון: מה נשמר (תבנית מספרית, לא תמונה), למה, לכמה זמן, ואיך מוחקים. בלי סימון מראש.
- **חלופה בלי ביומטריה:** מי שמסרב עובר למסלול הידני הקיים (תנוחה ואישור אנושי), בלי שנשמרת תבנית. בסירוב הזה תמונות הפרופיל לא נבדקות אוטומטית, ולכן מוצג תג חלש יותר. ההסכמה צריכה להיות חופשית, ולכן חייבת להיות חלופה.
- **מה נשמר:** תבנית מוצפנת בלבד. frames נמחקים מיד אחרי ההחלטה (כמו היום). embeddings של תמונות פרופיל **לא** נשמרים, אלא מחושבים בכל בדיקה.
- **מחיקה:** `DELETE /me/biometric` מוחק את התבנית ומסיר את התג. `DELETE /me` מוחק הכול (cascade).
- **מחיקה אוטומטית:** תבנית של חשבון שלא היה פעיל 12 חודשים נמחקת.
- **אין שימוש אחר:** אין חיפוש פנים בין משתמשים (1:N), רק השוואה 1:1 של אדם מול עצמו. לכתוב את זה במסמך הפרטיות.
- **לוגים:** אין scores, אין embeddings ואין keys של תמונות בלוג `[refused]`, רק את קוד השגיאה.

---

## 6. מסלול ידני (fallback)

התור הקיים `/admin/verifications` נשאר ומקבל:
- אימותים חיים גבוליים (`pending` מסעיף 3.4), עם frame ה-center ו-scores
- תמונות פרופיל `review`
- מי שסירב לביומטריה (סלפי בתנוחת יד, כמו היום)

---

## 7. API — סיכום

| Method | Path | שינוי |
|---|---|---|
| POST | `/me/biometric/consent` | **חדש** — `{ accepted: true }` |
| DELETE | `/me/biometric` | **חדש** |
| POST | `/me/verification/challenge` | **שינוי:** `{ mode: 'live' \| 'manual' }`. `live` מחזיר `steps`, ו-`manual` מחזיר `pose` (כמו היום) |
| POST | `/me/verification/frames` | **חדש** — multipart, מחזיר `{ status, reason? }` |
| POST | `/me/verification/selfie` | נשאר, למסלול `manual` בלבד |
| GET | `/me/verification` | **הרחבה:** `method`, `hasTemplate` |
| POST | `/media/photo` | **הרחבה:** בדיקת פנים; שגיאות `photo_no_face`, `photo_face_mismatch`; מחזיר `faceMatch` |
| GET | `/admin/verifications` | **הרחבה:** סוג פריט (`live_review` / `photo_review` / `manual`) + scores |

קודי שגיאה: `consent_required` · `challenge_expired` · `no_face` · `multiple_faces` · `face_too_small` · `too_blurry` · `wrong_direction` · `identity_mismatch` · `replayed_frame` · `too_many_attempts` · `photo_no_face` · `photo_face_mismatch` · `face_service_unavailable` (503, הלקוח מציג "נסה שוב בעוד דקה")

---

## 8. קונפיגורציה

| ENV | ברירת מחדל |
|---|---|
| `FACE_SVC_URL` | `http://127.0.0.1:8091` |
| `FACE_LIVE_TTL_SECONDS` | 90 |
| `FACE_MIN_SCORE` | 0.9 |
| `FACE_MIN_WIDTH_RATIO` | 0.25 |
| `FACE_YAW_CENTER` / `FACE_YAW_TURN` | 0.12 / 0.25 |
| `FACE_SAME_PERSON` | 0.45 (בין frames של אותו אימות) |
| `FACE_MATCH_ACCEPT` / `FACE_MATCH_REVIEW` | 0.40 / 0.30 |
| `FACE_ATTEMPTS_PER_DAY` | 5 |
| `FACE_TEMPLATE_KEY_FILE` | `/var/lib/up/.face-key` |
| `FACE_TEMPLATE_RETENTION_DAYS` | 365 |

---

## 9. Flutter

- `pubspec.yaml`: להוסיף `camera` (יש לו מימוש web). `image_picker` נשאר **רק** לתמונות פרופיל מהגלריה.
- `verify_screen.dart`: לכתוב מחדש כ-`LiveVerifyScreen`. Preview, overlay אובלי, הוראת צעד, ספירה לאחור, צילום, ושליחה.
- `photos_setup_screen.dart`: טיפול ב-`photo_no_face` / `photo_face_mismatch` עם הודעה ברורה ("לא זיהינו אותך בתמונה הזו") וסימון תמונות שממתינות.
- מסך הסכמה חדש (עברית/אנגלית).
- תג בפרופיל: **"פנים מאומתות"** (live) או **"מאומת ידנית"** (manual).
- הרשאת מצלמה: באנדרואיד `CAMERA` ב-manifest. בווב הדפדפן שואל, ואם המשתמש סירב מוצג מסך הסבר.

---

## 10. בדיקות

**face-svc (pytest, עם תמונות fixture מורשות):**
- [ ] תמונה בלי פנים → `faces: []`
- [ ] שתי תמונות של אותו אדם → cosine ≥ 0.40; אנשים שונים → < 0.30
- [ ] yaw: חזית ≈ 0, סיבוב שמאלה < −0.25 (על תמונה גולמית, לא משוקפת)

**Node (`node --test`, עם face-svc מדומה):**
- [ ] רצף תקין → approved + נוצרת תבנית + ה-frames נמחקו
- [ ] כיוון שגוי ב-frame אחד → pending; בשניים → rejected
- [ ] frame של אדם אחר באמצע → `identity_mismatch`
- [ ] אותו frame פעמיים → `replayed_frame`
- [ ] אחרי TTL → `challenge_expired`
- [ ] אתגר נצרך פעם אחת בלבד
- [ ] תמונה מתאימה → `ok`; גבולית → `review`; לא מתאימה → 400 והקובץ לא נשמר
- [ ] תמונה קבוצתית עם המשתמש → `ok`
- [ ] משתמש לא מאומת → `unverified`; אחרי אימות → התאמה רצה אוטומטית
- [ ] `DELETE /me/biometric` → התבנית נמחקה והתג ירד
- [ ] face-svc למטה → 503 `face_service_unavailable`, שום דבר לא נשמר
- [ ] בלי הסכמה → `consent_required`
- [ ] embeddings/scores לא מופיעים ב-stdout

---

## 11. שלבים

### שלב 1 — שירות פנים
- [x] `face-svc/` (Python) + `/analyze` + `/health`
- [x] `provision.sh` / `update.sh`: venv, הורדת מודלים עם sha256, `up-face.service` (דרך `server/deploy/face-setup.sh`)
- [x] בדיקות pytest — 32 עוברות + CI ב-`.github/workflows/face-svc.yml`

**מדידות (13.10.2026):** תמונה 640px ≈ 85ms, 1280px ≈ 260ms (ליבה אחת). אותו אדם בשתי תמונות שונות: cosine ≈ 0.62; אנשים שונים: ≤ 0.20 — הספים 0.40/0.30 מחזיקים עם מרווח.

### שלב 2 — אימות חי
- [ ] טבלאות + הסכמה + `DELETE /me/biometric`
- [ ] אתגר `live` + `/me/verification/frames` + לוגיקת החלטה
- [ ] `LiveVerifyScreen` עם `camera`
- [ ] הרחבת התור הידני

### שלב 3 — תמונות פרופיל
- [ ] בדיקת פנים ב-`/media/photo` + `photo_checks`
- [ ] סינון הגשה ב-`/nearby/resolve` ו-`/media/:key`
- [ ] UI לשגיאות ותמונות ממתינות
- [ ] backfill למשתמשים קיימים

### שלב 4 — כיול
- [ ] פיילוט עם 10–20 אנשים: כיול `BLUR_MIN`, ספי yaw וספי התאמה
- [ ] מדידת false reject, כלומר כמה אנשים אמיתיים נדחים

---

## 12. החלטות פתוחות

1. **חובה לאמת כדי להיכנס ל-Live?** ההמלצה: כן. בלי אימות אפשר לגלוש, אבל לא להופיע לאחרים.
2. **תמונות בלי פנים** (נוף, כלב, אוכל): לאסור, או לאפשר עד תמונה אחת כזו שאינה ראשית? ההמלצה: לאפשר אחת.
3. **אימות מדסקטופ:** לחסום לגמרי, או לאפשר עם תג "ידני" בלבד?
4. **אימות חוזר תקופתי:** כל 6 חודשים, או רק כשיש דיווח או חשד?
5. **שילוב עם Reality Verified:** אם משוב אחרי Match אומר "לא דומה" פעמיים, להפעיל אימות חוזר אוטומטית?
