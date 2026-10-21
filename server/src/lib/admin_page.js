import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * The operator page at /admin: venues and their QR stickers, and the review
 * queue. One self-contained HTML document — the QR library (MIT, vendored in
 * src/static) is inlined, so the page needs nothing from any CDN.
 *
 * The page holds no data until the operator types the admin key; every call
 * it makes sends that key as `x-admin-token`.
 */
let cached = null;

export function adminPage() {
  if (cached) return cached;
  const qr = readFileSync(join(here, '..', 'static', 'qrcode.js'), 'utf8');
  cached = TEMPLATE.replace('/*__QRCODE__*/', () => qr);
  return cached;
}

const TEMPLATE = String.raw`<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>UP · ניהול</title>
<style>
  :root {
    --bg: #0d0a14; --surface: #17121f; --line: #2a2236; --fg: #f4eefb;
    --muted: #a99bbd; --pink: #ff3d8b; --mint: #3dffc5; --danger: #ff5a5a;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--fg);
    font: 15px/1.5 system-ui, "Segoe UI", Arial, sans-serif; }
  main { max-width: 960px; margin: 0 auto; padding: 16px; }
  h1 { font-size: 26px; margin: 8px 0 4px; }
  h1 b { color: var(--pink); }
  h2 { font-size: 18px; margin: 28px 0 10px; }
  .card { background: var(--surface); border: 1px solid var(--line);
    border-radius: 14px; padding: 14px; margin-bottom: 12px; }
  label { display: block; font-size: 13px; color: var(--muted); margin: 8px 0 4px; }
  input { width: 100%; padding: 10px 12px; border-radius: 10px; border: 1px solid var(--line);
    background: #0f0b16; color: var(--fg); font: inherit; }
  .row { display: flex; gap: 10px; flex-wrap: wrap; align-items: end; }
  .row > * { flex: 1 1 140px; }
  button { padding: 10px 14px; border-radius: 10px; border: 0; cursor: pointer;
    font: inherit; font-weight: 700; background: var(--pink); color: #fff; }
  button.ghost { background: transparent; color: var(--fg); border: 1px solid var(--line); }
  button.mint { background: var(--mint); color: #062b20; }
  button.danger { background: transparent; color: var(--danger); border: 1px solid var(--danger); }
  button:disabled { opacity: .5; cursor: default; }
  .muted { color: var(--muted); font-size: 13px; }
  .venue { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .venue .info { flex: 1 1 220px; }
  .code { font-family: ui-monospace, monospace; letter-spacing: 2px; color: var(--mint); }
  .pill { display: inline-block; padding: 1px 8px; border-radius: 99px; font-size: 12px;
    border: 1px solid var(--line); color: var(--muted); }
  .pill.on { color: var(--mint); border-color: var(--mint); }
  .imgs { display: flex; gap: 8px; flex-wrap: wrap; margin: 8px 0; }
  .imgs img { width: 140px; height: 175px; object-fit: cover; border-radius: 10px; background: #000; }
  .imgs figure { margin: 0; text-align: center; font-size: 12px; color: var(--muted); }
  #msg { position: fixed; inset-inline: 16px; bottom: 16px; padding: 12px 16px; border-radius: 12px;
    background: var(--surface); border: 1px solid var(--line); display: none; }
  /* Print: only the sticker. */
  #sticker { display: none; }
  @media print {
    body { background: #fff; }
    main, #msg { display: none !important; }
    #sticker { display: flex !important; }
  }
  #sticker { position: fixed; inset: 0; background: #fff; color: #111; flex-direction: column;
    align-items: center; justify-content: center; gap: 14px; text-align: center; z-index: 10;
    padding: 24px; }
  .venue .logo { width: 56px; height: 56px; border-radius: 12px; overflow: hidden;
    background: #0f0b16; display: flex; align-items: center; justify-content: center;
    font-size: 11px; text-align: center; flex: 0 0 56px; }
  .venue .logo img { width: 100%; height: 100%; object-fit: contain; }
  #s-logo img { max-width: 220px; max-height: 120px; object-fit: contain; }
  #sticker .brand { font-size: 64px; font-weight: 900; color: #ff3d8b; letter-spacing: 2px; line-height: 1; }
  #sticker .name { font-size: 30px; font-weight: 800; }
  #sticker .cta { font-size: 22px; max-width: 520px; }
  #sticker .small { font-size: 15px; color: #555; }
  #sticker svg { width: min(70vw, 420px); height: auto; }
  #sticker .close { position: absolute; top: 16px; inset-inline-start: 16px; }
  @media print { #sticker .close, #sticker .noprint { display: none; } }
</style>
</head>
<body>
<main>
  <h1><b>UP</b> · ניהול</h1>
  <p class="muted">מקומות רשומים, מדבקות QR ותור אימותים.</p>

  <div class="card" id="auth">
    <label for="token">מפתח ניהול (x-admin-token)</label>
    <div class="row">
      <input id="token" type="password" autocomplete="off" placeholder="המפתח מ-/var/lib/up/.admin-token">
      <button id="save-token" style="flex:0 0 auto">כניסה</button>
    </div>
  </div>

  <section id="app" hidden>
    <h2>מקום חדש</h2>
    <div class="card">
      <div class="row">
        <div><label for="v-name">שם המקום</label><input id="v-name" placeholder="פאב הנמל"></div>
        <div><label for="v-code">קוד (לא חובה)</label><input id="v-code" placeholder="נוצר אוטומטית" dir="ltr"></div>
        <div style="flex:0 1 110px"><label for="v-radius">רדיוס (מ')</label><input id="v-radius" type="number" value="80" min="20" max="2000"></div>
      </div>
      <div class="row">
        <div><label for="v-loc">מיקום — lat,lng או קישור Google Maps</label><input id="v-loc" dir="ltr" placeholder="32.0853, 34.7818"></div>
        <button class="ghost" id="here" style="flex:0 0 auto">📍 המיקום שלי עכשיו</button>
      </div>
      <p class="muted" id="loc-note"></p>
      <button id="create">הוספה + QR</button>
    </div>

    <h2>מקומות <span class="muted" id="v-count"></span></h2>
    <div id="venues"></div>

    <h2>תור אימות פנים <span class="muted" id="q-count"></span></h2>
    <div id="queue"></div>

    <h2>תמונות פרופיל לבדיקה <span class="muted" id="p-count"></span></h2>
    <div id="photos"></div>
  </section>
</main>

<div id="sticker" role="dialog" aria-label="מדבקת QR">
  <button class="ghost close noprint" onclick="closeSticker()">✕ סגירה</button>
  <div id="s-logo"></div>
  <div class="brand">UP</div>
  <div class="name" id="s-name"></div>
  <div id="s-qr"></div>
  <div class="cta">סרקו כדי לראות מי כאן עכשיו ולשלוח UP</div>
  <div class="small">כניסה לשעה · מאומת לפי מיקום · קוד: <span id="s-code" dir="ltr"></span></div>
  <button class="noprint" onclick="window.print()">🖨 הדפסה</button>
</div>

<div id="msg"></div>

<script>/*__QRCODE__*/</script>
<script>
(function () {
  'use strict';
  var KEY = 'up.admin.token';
  var token = '';
  try { token = localStorage.getItem(KEY) || ''; } catch (e) {}
  var $ = function (id) { return document.getElementById(id); };
  $('token').value = token;

  function say(text) {
    var m = $('msg'); m.textContent = text; m.style.display = 'block';
    clearTimeout(say.t); say.t = setTimeout(function () { m.style.display = 'none'; }, 3500);
  }

  function api(method, path, body) {
    return fetch(path, {
      method: method,
      headers: { 'x-admin-token': token, 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body)
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (j) {
        if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
        return j;
      });
    });
  }

  function imageUrl(path) {
    return fetch(path, { headers: { 'x-admin-token': token } })
      .then(function (r) { if (!r.ok) throw new Error(); return r.blob(); })
      .then(function (b) { return URL.createObjectURL(b); });
  }

  function el(tag, attrs, children) {
    var n = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'text') n.textContent = attrs[k];
      else if (k === 'onclick') n.onclick = attrs[k];
      else n.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) n.appendChild(c); });
    return n;
  }

  // -- location ---------------------------------------------------------------

  function parseLocation(text) {
    var t = (text || '').trim();
    var m = t.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/) ||
            t.match(/[?&](?:q|ll|query)=(-?\d+\.\d+),\s*(-?\d+\.\d+)/) ||
            t.match(/(-?\d+\.\d+)\s*[, ]\s*(-?\d+\.\d+)/);
    if (!m) return null;
    var lat = parseFloat(m[1]), lng = parseFloat(m[2]);
    if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
    return { lat: lat, lng: lng };
  }

  $('here').onclick = function () {
    if (!navigator.geolocation) return say('הדפדפן לא תומך במיקום');
    $('loc-note').textContent = 'מאתר…';
    navigator.geolocation.getCurrentPosition(function (p) {
      $('v-loc').value = p.coords.latitude.toFixed(6) + ', ' + p.coords.longitude.toFixed(6);
      var acc = Math.round(p.coords.accuracy);
      $('loc-note').textContent = 'דיוק: ±' + acc + ' מ\'. ' + (acc > 100
        ? '⚠ דיוק נמוך — כנראה מחשב (מיקום לפי רשת). עדיף לפתוח את הדף הזה בטלפון כשאתם בתוך המקום.'
        : 'מצוין. עמדו בתוך המקום כשאתם לוחצים.');
    }, function () {
      $('loc-note').textContent = 'לא התקבל מיקום. אפשר להדביק lat,lng או קישור ממפות.';
    }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
  };

  // -- venues -----------------------------------------------------------------

  $('create').onclick = function () {
    var loc = parseLocation($('v-loc').value);
    if (!$('v-name').value.trim()) return say('חסר שם');
    if (!loc) return say('מיקום לא תקין');
    var body = { name: $('v-name').value.trim(), lat: loc.lat, lng: loc.lng,
                 radiusM: Number($('v-radius').value) || 80 };
    if ($('v-code').value.trim()) body.code = $('v-code').value.trim();
    $('create').disabled = true;
    api('POST', '/admin/venues', body).then(function (v) {
      $('v-name').value = ''; $('v-code').value = ''; $('v-loc').value = '';
      say('נוסף: ' + v.name);
      loadVenues();
      showSticker(v);
    }).catch(function (e) { say('שגיאה: ' + e.message); })
      .finally(function () { $('create').disabled = false; });
  };

  function loadVenues() {
    return api('GET', '/admin/venues').then(function (j) {
      var box = $('venues'); box.innerHTML = '';
      $('v-count').textContent = '(' + j.venues.length + ')';
      if (!j.venues.length) box.appendChild(el('p', { class: 'muted', text: 'עוד אין מקומות.' }));
      j.venues.forEach(function (v) {
        var maps = 'https://www.google.com/maps?q=' + v.lat + ',' + v.lng;
        var logoBox = el('div', { class: 'logo' });
        if (v.logo) {
          imageUrl('/admin/photos/' + v.logo).then(function (u) {
            logoBox.appendChild(el('img', { src: u, alt: 'logo' }));
          }).catch(function () {});
        } else {
          logoBox.appendChild(el('span', { class: 'muted', text: 'אין לוגו' }));
        }
        var file = el('input', { type: 'file', accept: 'image/png,image/jpeg,image/webp', hidden: 'hidden' });
        file.onchange = function () {
          if (!file.files || !file.files[0]) return;
          say('מעלה לוגו…');
          fetch('/admin/venues/' + v.code + '/logo', {
            method: 'POST',
            headers: { 'x-admin-token': token, 'content-type': file.files[0].type || 'image/png' },
            body: file.files[0]
          }).then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
            .then(function () { say('הלוגו עודכן'); loadVenues(); })
            .catch(function (e) { say('שגיאה: ' + e.message); });
        };
        box.appendChild(el('div', { class: 'card venue' }, [
          logoBox,
          file,
          el('div', { class: 'info' }, [
            el('div', {}, [el('b', { text: v.name }), document.createTextNode(' '),
              el('span', { class: 'pill' + (v.active ? ' on' : ''), text: v.active ? 'פעיל' : 'מושבת' })]),
            el('div', { class: 'muted' }, [
              el('span', { class: 'code', text: v.code }),
              document.createTextNode(' · רדיוס ' + v.radiusM + ' מ\' · ' + v.live + ' עכשיו · '),
              el('a', { href: maps, target: '_blank', rel: 'noopener', style: 'color:var(--muted)', text: 'מפה' })
            ])
          ]),
          el('button', { class: 'mint', text: 'QR להדפסה', onclick: function () { showSticker(v); } }),
          el('button', { class: 'ghost', text: v.logo ? 'החלפת לוגו' : 'העלאת לוגו', onclick: function () { file.click(); } }),
          el('button', { class: 'ghost', text: '📍 עדכן למיקום שלי', onclick: function () { moveHere(v); } }),
          el('button', { class: 'ghost', text: v.active ? 'השבתה' : 'הפעלה', onclick: function () {
            api('PATCH', '/admin/venues/' + v.code, { active: !v.active }).then(loadVenues)
              .catch(function (e) { say(e.message); });
          } }),
          el('button', { class: 'danger', text: 'מחיקה', onclick: function () {
            if (!confirm('למחוק את ' + v.name + '? המדבקה תפסיק לעבוד.')) return;
            api('DELETE', '/admin/venues/' + v.code).then(loadVenues)
              .catch(function (e) { say(e.message); });
          } })
        ]));
      });
    });
  }

  // Re-pins a place to where this device is standing. The phone is the right
  // device for it: a laptop's location is a guess from the network, often a
  // few kilometres off.
  function moveHere(v) {
    if (!navigator.geolocation) return say('הדפדפן לא תומך במיקום');
    say('מאתר…');
    navigator.geolocation.getCurrentPosition(function (p) {
      var acc = Math.round(p.coords.accuracy);
      if (acc > 100 && !confirm('הדיוק כרגע ±' + acc + ' מ\' (נמוך). לעדכן בכל זאת?')) return;
      api('PATCH', '/admin/venues/' + v.code, { lat: p.coords.latitude, lng: p.coords.longitude })
        .then(function () { say('המיקום של ' + v.name + ' עודכן (±' + acc + ' מ\')'); loadVenues(); })
        .catch(function (e) { say(e.message); });
    }, function () { say('לא התקבל מיקום'); }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
  }

  window.showSticker = function (v) {
    var q = qrcode(0, 'H');
    q.addData(v.joinUrl); q.make();
    $('s-qr').innerHTML = q.createSvgTag({ cellSize: 8, margin: 2, scalable: true });
    $('s-name').textContent = v.name;
    $('s-code').textContent = v.code;
    $('s-logo').innerHTML = '';
    if (v.logo) {
      imageUrl('/admin/photos/' + v.logo).then(function (u) {
        $('s-logo').appendChild(el('img', { src: u, alt: '' }));
      }).catch(function () {});
    }
    $('sticker').style.display = 'flex';
  };
  window.closeSticker = function () { $('sticker').style.display = 'none'; };

  // -- review queue -------------------------------------------------------------

  function loadQueue() {
    return api('GET', '/admin/verifications').then(function (j) {
      var box = $('queue'); box.innerHTML = '';
      $('q-count').textContent = '(' + j.pending.length + ')';
      if (!j.pending.length) box.appendChild(el('p', { class: 'muted', text: 'אין ממתינים.' }));
      j.pending.forEach(function (row) {
        var imgs = el('div', { class: 'imgs' });
        var card = el('div', { class: 'card' }, [
          el('div', {}, [el('b', { text: row.firstName || '(ללא שם)' }),
            document.createTextNode(' · ' + (row.method === 'live' ? 'בדיקה חיה' : 'ידני') +
              (row.score != null ? ' · ציון ' + Number(row.score).toFixed(2) : ''))]),
          el('div', { class: 'muted', text: 'תנוחה: ' + row.instruction }),
          imgs,
          el('div', { class: 'row' }, [
            el('button', { class: 'mint', text: 'אישור', onclick: function () { decide(row.id, true); } }),
            el('button', { class: 'danger', text: 'דחייה', onclick: function () { decide(row.id, false); } })
          ])
        ]);
        box.appendChild(card);
        var add = function (label, path) {
          imageUrl(path).then(function (u) {
            imgs.appendChild(el('figure', {}, [el('img', { src: u, alt: label }), el('figcaption', { text: label })]));
          }).catch(function () {});
        };
        if (row.selfie) add('סלפי', '/admin/verifications/' + row.selfie + '/photo');
        (row.photos || []).forEach(function (k, i) { add('פרופיל ' + (i + 1), '/admin/photos/' + k); });
      });
    });
  }

  function decide(id, approve) {
    api('POST', '/admin/verifications/' + id + '/decide', { approve: approve })
      .then(function () { say(approve ? 'אושר' : 'נדחה'); loadQueue(); })
      .catch(function (e) { say(e.message); });
  }

  function loadPhotoReviews() {
    return api('GET', '/admin/photo-reviews').then(function (j) {
      var box = $('photos'); box.innerHTML = '';
      $('p-count').textContent = '(' + j.pending.length + ')';
      if (!j.pending.length) box.appendChild(el('p', { class: 'muted', text: 'אין ממתינות.' }));
      j.pending.forEach(function (row) {
        var imgs = el('div', { class: 'imgs' });
        box.appendChild(el('div', { class: 'card' }, [
          el('div', {}, [el('b', { text: row.firstName || '(ללא שם)' }),
            document.createTextNode(' · התאמה ' + (row.score != null ? Number(row.score).toFixed(2) : '?'))]),
          imgs,
          el('div', { class: 'row' }, [
            el('button', { class: 'mint', text: 'זה הוא/היא', onclick: function () { photoDecide(row.key, true); } }),
            el('button', { class: 'danger', text: 'לא תואם', onclick: function () { photoDecide(row.key, false); } })
          ])
        ]));
        imageUrl('/admin/photos/' + row.key).then(function (u) {
          imgs.appendChild(el('img', { src: u, alt: '' }));
        }).catch(function () {});
      });
    });
  }

  function photoDecide(key, approve) {
    api('POST', '/admin/photo-reviews/' + key + '/decide', { approve: approve })
      .then(function () { loadPhotoReviews(); })
      .catch(function (e) { say(e.message); });
  }

  // -- boot ---------------------------------------------------------------------

  function boot() {
    Promise.all([loadVenues(), loadQueue(), loadPhotoReviews()]).then(function () {
      $('app').hidden = false;
      $('auth').style.display = 'none';
    }).catch(function (e) {
      $('app').hidden = true;
      $('auth').style.display = '';
      say(e.message === 'unauthorized' ? 'מפתח שגוי' : 'שגיאה: ' + e.message);
    });
  }

  $('save-token').onclick = function () {
    token = $('token').value.trim();
    try { localStorage.setItem(KEY, token); } catch (e) {}
    boot();
  };
  if (token) boot();
})();
</script>
</body>
</html>`;
