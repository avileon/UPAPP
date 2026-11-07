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
  /* Tabs, stats, users. */
  .tabs { display: flex; gap: 6px; flex-wrap: wrap; margin: 16px 0 4px; position: sticky; top: 0;
    background: var(--bg); padding: 8px 0; z-index: 3; }
  .tabs button { background: transparent; color: var(--muted); border: 1px solid var(--line); }
  .tabs button.on { background: var(--pink); color: #fff; border-color: var(--pink); }
  .tabs .badge { display: inline-block; min-width: 18px; padding: 0 5px; margin-inline-start: 4px;
    border-radius: 99px; background: var(--danger); color: #fff; font-size: 11px; line-height: 18px; }
  .tabs .badge[hidden] { display: none; }
  @media (max-width: 640px) {
    .stats { grid-auto-flow: column; grid-auto-columns: 112px; grid-template-columns: none !important;
      overflow-x: auto; scrollbar-width: none; }
    .stat b { font-size: 18px; }
    .tabs button { padding: 8px 10px; font-size: 14px; }
  }
  .stats { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 8px; margin-top: 12px; }
  .stat { background: var(--surface); border: 1px solid var(--line); border-radius: 12px; padding: 10px 12px; }
  .stat b { display: block; font-size: 22px; line-height: 1.2; }
  .stat span { font-size: 12px; color: var(--muted); }
  .stat.hot b { color: var(--pink); }
  .stat.cool b { color: var(--mint); }
  .chips { display: flex; gap: 6px; flex-wrap: wrap; margin: 10px 0; }
  .chips button { padding: 6px 10px; font-size: 13px; font-weight: 600; background: transparent;
    color: var(--muted); border: 1px solid var(--line); }
  .chips button.on { color: var(--fg); border-color: var(--mint); }
  .chips button small { color: var(--muted); font-weight: 400; }
  select { padding: 10px 12px; border-radius: 10px; border: 1px solid var(--line);
    background: #0f0b16; color: var(--fg); font: inherit; }
  .urow { display: flex; gap: 12px; align-items: center; padding: 10px 12px; cursor: pointer;
    background: var(--surface); border: 1px solid var(--line); border-radius: 12px; margin-bottom: 8px; }
  .urow:hover { border-color: var(--pink); }
  .urow.dim { opacity: .55; }
  .av { width: 48px; height: 48px; border-radius: 50%; background: #0f0b16 center/cover no-repeat;
    flex: 0 0 48px; display: flex; align-items: center; justify-content: center; color: var(--muted);
    font-weight: 800; border: 2px solid var(--line); }
  .av.live { border-color: var(--mint); box-shadow: 0 0 10px rgba(61,255,197,.5); }
  .urow .who { flex: 1 1 auto; min-width: 0; }
  .urow .who .l1 { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
  .urow .nums { display: flex; gap: 14px; font-size: 12px; color: var(--muted); flex-wrap: wrap; }
  .urow .nums b { color: var(--fg); font-size: 14px; }
  .urow .when { font-size: 12px; color: var(--muted); text-align: end; flex: 0 0 auto; }
  .pill.ok { color: var(--mint); border-color: var(--mint); }
  .pill.warn { color: #ffc861; border-color: #ffc861; }
  .pill.bad { color: var(--danger); border-color: var(--danger); }
  .pill.hot { color: var(--pink); border-color: var(--pink); }
  @media (max-width: 640px) { .urow .nums { display: none; } }
  /* The person's card. */
  #drawer { position: fixed; inset: 0; background: rgba(0,0,0,.6); display: none; z-index: 8; }
  #drawer .panel { position: absolute; inset-block: 0; inset-inline-end: 0; width: min(560px, 100%);
    background: var(--bg); border-inline-start: 1px solid var(--line); overflow-y: auto; padding: 16px; }
  #drawer h3 { margin: 18px 0 8px; font-size: 15px; color: var(--muted); }
  dl.kv { display: grid; grid-template-columns: max-content 1fr; gap: 4px 12px; margin: 0; font-size: 14px; }
  dl.kv dt { color: var(--muted); }
  dl.kv dd { margin: 0; }
  .actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
  .mini { display: flex; justify-content: space-between; gap: 8px; padding: 8px 10px; border-radius: 10px;
    background: var(--surface); border: 1px solid var(--line); margin-bottom: 6px; font-size: 14px; }
  .mini a { color: var(--mint); cursor: pointer; text-decoration: none; }
  .imgs .bad img { outline: 2px solid var(--danger); }
  .imgs .warn img { outline: 2px solid #ffc861; }
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
  <p class="muted">משתמשים, דיווחים, אימותים ומקומות.</p>

  <div class="card" id="auth">
    <label for="token">מפתח ניהול (x-admin-token)</label>
    <div class="row">
      <input id="token" type="password" autocomplete="off" placeholder="המפתח מ-/var/lib/up/.admin-token">
      <button id="save-token" style="flex:0 0 auto">כניסה</button>
    </div>
  </div>

  <section id="app" hidden>
    <div class="stats" id="stats"></div>

    <nav class="tabs" id="tabs">
      <button data-tab="users" class="on">משתמשים</button>
      <button data-tab="reports">דיווחים <span class="badge" id="b-reports" hidden></span></button>
      <button data-tab="reviews">אימותים <span class="badge" id="b-reviews" hidden></span></button>
      <button data-tab="venues">מקומות <span class="badge" id="b-venues" hidden></span></button>
      <button class="ghost" id="refresh" style="margin-inline-start:auto">↻ רענון</button>
    </nav>

    <div data-panel="users">
      <div class="row">
        <div style="flex:3 1 220px"><input id="u-q" placeholder="חיפוש לפי שם או טלפון" autocomplete="off"></div>
        <div style="flex:1 1 140px"><select id="u-sort">
          <option value="created">נרשמו לאחרונה</option>
          <option value="seen">פעילות אחרונה</option>
          <option value="matches">הכי הרבה Matches</option>
          <option value="reports">הכי הרבה דיווחים</option>
        </select></div>
      </div>
      <div class="chips" id="u-filters"></div>
      <div id="users"></div>
    </div>

    <div data-panel="reports" hidden>
      <div class="chips">
        <button id="r-open" class="on">פתוחים</button>
        <button id="r-all">כולל שטופלו</button>
      </div>
      <div id="reports"></div>
    </div>

    <div data-panel="reviews" hidden>
      <h2>תור אימות פנים <span class="muted" id="q-count"></span></h2>
      <div id="queue"></div>
      <h2>תמונות פרופיל לבדיקה <span class="muted" id="p-count"></span></h2>
      <div id="photos"></div>

      <h2>מייל להתראות</h2>
      <div class="card">
        <p class="muted" id="m-status">כשאימות פנים עובר לבדיקה ידנית, נשלח מייל לכתובת הזו.</p>
        <div class="row">
          <div><label for="m-to">לשלוח אל</label><input id="m-to" dir="ltr" value="avi@vibit.co.il"></div>
          <div><label for="m-user">חשבון Gmail ששולח</label><input id="m-user" dir="ltr" value="avi@vibit.co.il"></div>
        </div>
        <div class="row">
          <div><label for="m-pass">סיסמת אפליקציה של Google (16 אותיות)</label><input id="m-pass" type="password" dir="ltr" autocomplete="off" placeholder="נשאר כמו שהוא אם ריק"></div>
        </div>
        <div class="row">
          <button id="m-save">שמירה</button>
          <button class="ghost" id="m-test">שליחת מייל בדיקה</button>
        </div>
      </div>
    </div>

    <div data-panel="venues" hidden>
      <h2>בקשות הצטרפות של עסקים <span class="muted" id="a-count"></span></h2>
      <div id="applications"></div>

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
    </div>
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

<div id="drawer" role="dialog" aria-label="כרטיס משתמש"><div class="panel" id="panel"></div></div>

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
        if (!r.ok) throw new Error((j.error || ('HTTP ' + r.status)) + (j.detail ? ' — ' + j.detail : ''));
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
      var pending = j.venues.filter(function (v) { return v.status === 'pending'; });
      var placed = j.venues.filter(function (v) { return v.status !== 'pending'; });
      renderApplications(pending);
      $('v-count').textContent = '(' + placed.length + ')';
      if (!placed.length) box.appendChild(el('p', { class: 'muted', text: 'עוד אין מקומות.' }));
      placed.forEach(function (v) {
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
              el('span', { class: 'pill' + (v.active ? ' on' : ''), text: v.status === 'rejected' ? 'נדחה' : v.active ? 'פעיל' : 'מושבת' })]),
            v.contact ? el('div', { class: 'muted', text: 'נרשם לבד · ' + v.contact.name + ' · ' + v.contact.phone + (v.contact.email ? ' · ' + v.contact.email : '') }) : null,
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

  var KINDS = { bar: 'בר', pub: 'פאב', club: 'מועדון', cafe: 'בית קפה', restaurant: 'מסעדה', events: 'אירועים', other: 'אחר' };
  function renderApplications(list) {
    var box = $('applications'); box.innerHTML = '';
    $('a-count').textContent = '(' + list.length + ')';
    if (!list.length) { box.appendChild(el('p', { class: 'muted', text: 'אין בקשות שממתינות.' })); return; }
    list.forEach(function (v) {
      var maps = 'https://www.google.com/maps?q=' + v.lat + ',' + v.lng;
      var c = v.contact || {};
      box.appendChild(el('div', { class: 'card venue' }, [
        el('div', { class: 'info' }, [
          el('div', {}, [el('b', { text: v.name }), document.createTextNode(' '),
            el('span', { class: 'pill', text: KINDS[v.kind] || 'אחר' })]),
          el('div', { class: 'muted', text: (v.address || 'מיקום מהטלפון') + ' · נרשם ' + new Date(v.createdAt).toLocaleString('he-IL') }),
          el('div', { class: 'muted' }, [
            document.createTextNode(c.name + ' · '),
            el('a', { href: 'tel:' + c.phone, style: 'color:var(--mint)', text: c.phone, dir: 'ltr' }),
            c.email ? document.createTextNode(' · ' + c.email) : null,
            document.createTextNode(' · '),
            el('a', { href: maps, target: '_blank', rel: 'noopener', style: 'color:var(--muted)', text: 'מפה' })
          ])
        ]),
        el('button', { class: 'mint', text: 'אישור', onclick: function () {
          api('POST', '/admin/venues/' + v.code + '/approve').then(function () { say(v.name + ' אושר — ה-QR פעיל'); loadVenues(); })
            .catch(function (e) { say(e.message); });
        } }),
        el('button', { class: 'danger', text: 'דחייה', onclick: function () {
          if (!confirm('לדחות את ' + v.name + '?')) return;
          api('POST', '/admin/venues/' + v.code + '/reject').then(loadVenues).catch(function (e) { say(e.message); });
        } })
      ]));
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
      .then(function () { say(approve ? 'אושר' : 'נדחה'); loadQueue(); loadStats(); loadUsers(); })
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

  // -- operator email -----------------------------------------------------------

  function loadMail() {
    return api('GET', '/admin/mail').then(function (j) {
      if (j.configured) {
        $('m-to').value = j.to; $('m-user').value = j.user;
        $('m-status').textContent = '✓ מוגדר — התראות נשלחות אל ' + j.to;
      } else {
        $('m-status').textContent = 'עוד לא מוגדר: צריך סיסמת אפליקציה של Google לחשבון ששולח.';
      }
    });
  }

  $('m-save').onclick = function () {
    api('POST', '/admin/mail', { to: $('m-to').value, user: $('m-user').value, pass: $('m-pass').value })
      .then(function () { $('m-pass').value = ''; say('נשמר'); return loadMail(); })
      .catch(function (e) { say('שגיאה: ' + e.message); });
  };

  $('m-test').onclick = function () {
    say('שולח…');
    api('POST', '/admin/mail/test')
      .then(function () { say('נשלח — בדוק את תיבת הדואר'); })
      .catch(function (e) { say('לא נשלח: ' + e.message); });
  };

  // -- shared bits ----------------------------------------------------------------

  var thumbs = {};
  function thumb(key) {
    if (!key) return Promise.reject(new Error('none'));
    if (!thumbs[key]) thumbs[key] = imageUrl('/admin/photos/' + key);
    return thumbs[key];
  }
  function ago(iso) {
    if (!iso) return '—';
    var s = Math.round((Date.now() - Date.parse(iso)) / 1000);
    if (s < 60) return 'עכשיו';
    if (s < 3600) return 'לפני ' + Math.round(s / 60) + ' דק\'';
    if (s < 86400) return 'לפני ' + Math.round(s / 3600) + ' שע\'';
    if (s < 86400 * 30) return 'לפני ' + Math.round(s / 86400) + ' ימים';
    return new Date(iso).toLocaleDateString('he-IL');
  }
  function when(iso) { return iso ? new Date(iso).toLocaleString('he-IL') : '—'; }
  function pill(text, kind) { return el('span', { class: 'pill' + (kind ? ' ' + kind : ''), text: text }); }
  function badge(id, n) { var b = $(id); b.textContent = n; b.hidden = !n; }
  var GENDER = { male: 'גבר', female: 'אישה', other: 'אחר' };
  var INTO = { men: 'גברים', women: 'נשים', everyone: 'כולם' };
  var INTENT = { meet: 'להכיר', date: 'דייט' };
  var CATEGORY = { fake: 'פרופיל מזויף', harassment: 'הטרדה', spam: 'ספאם', inappropriate: 'לא הולם', underage: 'קטין/ה', other: 'אחר' };
  var VSTATUS = { approved: 'אושר', pending: 'ממתין', rejected: 'נדחה', revoked: 'בוטל' };

  function verifyPill(u) {
    if (u.verification === 'approved') return pill('✓ מאומת', 'ok');
    if (u.verification === 'pending') return pill('ממתין לאימות', 'warn');
    if (u.graceEndsAt) return pill('בחסד עד ' + new Date(u.graceEndsAt).toLocaleTimeString('he-IL', { hour: '2-digit', minute: '2-digit' }), 'warn');
    if (u.verification === 'rejected') return pill('אימות נדחה', 'bad');
    return pill('לא מאומת');
  }
  function livePill(u) {
    if (!u.live) return null;
    var where = u.live.mode === 'venue' ? (u.live.venueName || u.live.venue) : 'סביבה';
    return pill('● Live · ' + where + ' · ' + (INTENT[u.live.intent] || u.live.intent), 'ok');
  }

  // -- stats ----------------------------------------------------------------------

  function loadStats() {
    return api('GET', '/admin/stats').then(function (st) {
      var box = $('stats'); box.innerHTML = '';
      [
        ['משתמשים', st.users],
        ['Live עכשיו', st.liveNow, 'cool'],
        ['פעילים 24ש\'', st.activeDay],
        ['חדשים היום', st.newDay, 'hot'],
        ['חדשים השבוע', st.newWeek],
        ['מאומתים', st.verified, 'cool'],
        ['ממתינים לאימות', st.pendingVerifications, st.pendingVerifications ? 'hot' : ''],
        ['Matches', st.matches],
        ['Matches השבוע', st.matchesWeek],
        ['UP ב-24ש\'', st.upsDay],
        ['הודעות 24ש\'', st.messagesDay],
        ['דיווחים פתוחים', st.openReports, st.openReports ? 'hot' : ''],
        ['מושעים', st.suspended]
      ].forEach(function (x) {
        box.appendChild(el('div', { class: 'stat ' + (x[2] || '') }, [el('b', { text: String(x[1]) }), el('span', { text: x[0] })]));
      });
      badge('b-reports', st.openReports);
      badge('b-reviews', st.pendingVerifications);
      badge('b-venues', st.pendingVenues);
    });
  }

  // -- users ----------------------------------------------------------------------

  var users = [];
  var filter = 'all';
  var FILTERS = [
    ['all', 'כולם', function (u) { return u.status !== 'deleted'; }],
    ['live', 'Live עכשיו', function (u) { return !!u.live; }],
    ['new', 'חדשים (24ש\')', function (u) { return u.status !== 'deleted' && Date.now() - Date.parse(u.createdAt) < 86400000; }],
    ['pending', 'ממתינים / בחסד', function (u) { return u.status !== 'deleted' && u.verification !== 'approved' && (u.verification === 'pending' || !!u.graceEndsAt); }],
    ['unverified', 'לא מאומתים', function (u) { return u.status !== 'deleted' && u.verification !== 'approved'; }],
    ['verified', 'מאומתים', function (u) { return u.verification === 'approved' && u.status !== 'deleted'; }],
    ['incomplete', 'פרופיל חסר', function (u) { return u.status !== 'deleted' && !u.profileComplete; }],
    ['reported', 'עם דיווחים', function (u) { return u.counts.reports > 0; }],
    ['suspended', 'מושעים', function (u) { return u.status === 'suspended'; }],
    ['deleted', 'מחקו חשבון', function (u) { return u.status === 'deleted'; }]
  ];

  function loadUsers() {
    return api('GET', '/admin/users').then(function (j) { users = j.users; renderUsers(); });
  }

  function renderUsers() {
    var chips = $('u-filters'); chips.innerHTML = '';
    FILTERS.forEach(function (f) {
      var n = users.filter(f[2]).length;
      if (!n && f[0] !== 'all' && f[0] !== filter) return;
      chips.appendChild(el('button', { class: filter === f[0] ? 'on' : '', onclick: function () { filter = f[0]; renderUsers(); } },
        [document.createTextNode(f[1] + ' '), el('small', { text: '(' + n + ')' })]));
    });
    var test = FILTERS.filter(function (f) { return f[0] === filter; })[0][2];
    var q = $('u-q').value.trim().toLowerCase();
    var digits = q.replace(/\D/g, '');
    var list = users.filter(test).filter(function (u) {
      if (!q) return true;
      return (u.firstName || '').toLowerCase().indexOf(q) !== -1 ||
        (digits.length >= 3 && (u.phone || '').replace(/\D/g, '').indexOf(digits.replace(/^0/, '')) !== -1) ||
        u.id === q;
    });
    var sort = $('u-sort').value;
    var key = {
      created: function (u) { return Date.parse(u.createdAt) || 0; },
      seen: function (u) { return (u.live ? 1e15 : 0) + (Date.parse(u.lastSeenAt) || 0); },
      matches: function (u) { return u.counts.matches; },
      reports: function (u) { return u.counts.reports; }
    }[sort];
    list.sort(function (a, b) { return key(b) - key(a); });

    var box = $('users'); box.innerHTML = '';
    if (!list.length) { box.appendChild(el('p', { class: 'muted', text: 'אין משתמשים שמתאימים.' })); return; }
    list.slice(0, 300).forEach(function (u) {
      var av = el('div', { class: 'av' + (u.live ? ' live' : ''), text: (u.firstName || '?').charAt(0) });
      if (u.mainPhoto) lazy(av, u.mainPhoto);
      var pills = [verifyPill(u), livePill(u)];
      if (u.status === 'suspended') pills.unshift(pill('מושעה', 'bad'));
      if (u.status === 'deleted') pills.unshift(pill('מחק חשבון', 'bad'));
      if (!u.profileComplete && u.status !== 'deleted') pills.push(pill('פרופיל חסר'));
      if (u.counts.reportsOpen) pills.push(pill('⚠ ' + u.counts.reportsOpen + ' דיווחים', 'hot'));
      var sub = [u.age != null ? u.age : null, GENDER[u.gender], u.interestedIn ? '← ' + (INTO[u.interestedIn] || u.interestedIn) : null]
        .filter(Boolean).join(' · ');
      box.appendChild(el('div', { class: 'urow' + (u.status !== 'active' ? ' dim' : ''), onclick: function () { openUser(u.id); } }, [
        av,
        el('div', { class: 'who' }, [
          el('div', { class: 'l1' }, [el('b', { text: u.firstName || '(ללא שם)' })].concat(pills)),
          el('div', { class: 'muted' }, [
            document.createTextNode(sub + (sub && u.phone ? ' · ' : '')),
            u.phone ? el('span', { dir: 'ltr', text: u.phone }) : null
          ]),
          el('div', { class: 'nums' }, [
            num('UP נשלחו', u.counts.upsSent), num('UP התקבלו', u.counts.upsReceived),
            num('Matches', u.counts.matches), num('הודעות', u.counts.messagesSent),
            num('תמונות', u.photoCount)
          ])
        ]),
        el('div', { class: 'when' }, [
          el('div', { text: u.live ? 'Live עכשיו' : ago(u.lastSeenAt) }),
          el('div', { text: 'נרשם ' + ago(u.createdAt) })
        ])
      ]));
    });
    if (list.length > 300) box.appendChild(el('p', { class: 'muted', text: 'מוצגים 300 מתוך ' + list.length + ' — צמצמו בחיפוש.' }));
  }
  function num(label, n) { return el('span', {}, [el('b', { text: String(n) }), document.createTextNode(' ' + label)]); }

  var seen = 'IntersectionObserver' in window ? new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (!e.isIntersecting) return;
      seen.unobserve(e.target);
      var node = e.target;
      thumb(node.getAttribute('data-key')).then(function (u) {
        node.style.backgroundImage = 'url(' + u + ')'; node.textContent = '';
      }).catch(function () {});
    });
  }, { rootMargin: '200px' }) : null;
  function lazy(node, key) {
    node.setAttribute('data-key', key);
    if (seen) seen.observe(node);
    else thumb(key).then(function (u) { node.style.backgroundImage = 'url(' + u + ')'; node.textContent = ''; }).catch(function () {});
  }

  $('u-q').oninput = renderUsers;
  $('u-sort').onchange = renderUsers;

  // -- one person -------------------------------------------------------------------

  function closeUser() { $('drawer').style.display = 'none'; }
  $('drawer').onclick = function (e) { if (e.target === $('drawer')) closeUser(); };
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeUser(); });

  function openUser(id) {
    $('panel').innerHTML = '<p class="muted">טוען…</p>';
    $('drawer').style.display = 'block';
    api('GET', '/admin/users/' + id).then(renderUser).catch(function (e) {
      $('panel').innerHTML = ''; $('panel').appendChild(el('p', { class: 'muted', text: 'שגיאה: ' + e.message }));
    });
  }

  function renderUser(u) {
    var p = $('panel'); p.innerHTML = '';
    var head = el('div', { class: 'row', style: 'align-items:center' }, [
      el('div', { style: 'flex:1 1 auto' }, [
        el('h2', { style: 'margin:0', text: (u.firstName || '(ללא שם)') + (u.age != null ? ', ' + u.age : '') }),
        el('div', { class: 'l1', style: 'display:flex;gap:6px;flex-wrap:wrap;margin-top:6px' }, [
          u.status === 'suspended' ? pill('מושעה', 'bad') : null,
          u.status === 'deleted' ? pill('מחק חשבון', 'bad') : null,
          verifyPill(u), livePill(u), u.realityVerified ? pill('Reality ✓', 'ok') : null
        ])
      ]),
      el('button', { class: 'ghost', style: 'flex:0 0 auto', text: '✕', onclick: closeUser })
    ]);
    p.appendChild(head);

    var imgs = el('div', { class: 'imgs' });
    var CHECK = { ok: ['תואם', ''], review: ['לבדיקה', 'warn'], rejected: ['לא תואם', 'bad'], unverified: ['טרם נבדק', ''] };
    (u.photos || []).forEach(function (ph, i) {
      var c = CHECK[ph.check] || ['', ''];
      var fig = el('figure', { class: c[1] }, [el('figcaption', { text: (ph.key === u.mainPhoto ? '★ ' : '') + (c[0] || ('תמונה ' + (i + 1))) })]);
      imgs.appendChild(fig);
      thumb(ph.key).then(function (src) { fig.insertBefore(el('img', { src: src, alt: '' }), fig.firstChild); }).catch(function () {});
    });
    if (!(u.photos || []).length) imgs.appendChild(el('p', { class: 'muted', text: 'אין תמונות.' }));
    p.appendChild(imgs);
    if (u.bio) p.appendChild(el('p', { text: u.bio }));

    // Actions first: this is what the card is for.
    var acts = el('div', { class: 'actions' });
    if (u.status !== 'deleted') {
      if (u.verification === 'approved') {
        acts.appendChild(el('button', { class: 'ghost', text: 'ביטול אימות', onclick: function () {
          if (!confirm('לבטל את האימות של ' + (u.firstName || 'המשתמש') + '? הוא יאבד את התג ולא יוכל להיכנס ל-Live עד שיאומת שוב.')) return;
          act('POST', '/admin/users/' + u.id + '/verification', { approve: false }, 'האימות בוטל', u.id);
        } }));
      } else {
        acts.appendChild(el('button', { class: 'mint', text: '✓ אישור אימות', onclick: function () {
          act('POST', '/admin/users/' + u.id + '/verification', { approve: true }, 'אושר — נשלחה התראה לטלפון', u.id);
        } }));
      }
      if (u.status === 'suspended') {
        acts.appendChild(el('button', { class: 'mint', text: 'ביטול השעיה', onclick: function () {
          act('POST', '/admin/users/' + u.id + '/unsuspend', undefined, 'ההשעיה בוטלה', u.id);
        } }));
      } else {
        acts.appendChild(el('button', { class: 'ghost', text: '⏸ השעיה', onclick: function () {
          var reason = prompt('סיבת ההשעיה (לשימושך בלבד):', '');
          if (reason === null) return;
          act('POST', '/admin/users/' + u.id + '/suspend', { reason: reason }, 'הושעה — נותק מכל המכשירים', u.id);
        } }));
      }
    }
    acts.appendChild(el('button', { class: 'danger', text: '🗑 מחיקה מלאה', onclick: function () {
      var name = u.firstName || 'מחק';
      var typed = prompt('מחיקה סופית: החשבון, התמונות, ה-UP, ה-Matches וההודעות — הכל נמחק ואין דרך חזרה.\nכדי לאשר הקלידו: ' + name, '');
      if (typed === null) return;
      if (typed.trim() !== name) return say('לא נמחק — השם לא תאם');
      api('DELETE', '/admin/users/' + u.id).then(function () {
        say('נמחק'); closeUser(); refreshAll();
      }).catch(function (e) { say('שגיאה: ' + e.message); });
    } }));
    p.appendChild(acts);
    if (u.status === 'suspended') {
      p.appendChild(el('p', { class: 'muted', text: 'הושעה ' + when(u.suspendedAt) + (u.suspendedReason ? ' · ' + u.suspendedReason : '') }));
    }

    p.appendChild(el('h3', { text: 'פרטים' }));
    var kv = el('dl', { class: 'kv' });
    var row = function (k, v) { if (v === null || v === undefined || v === '') return; kv.appendChild(el('dt', { text: k })); kv.appendChild(v.nodeType ? el('dd', {}, [v]) : el('dd', { text: String(v) })); };
    row('טלפון', u.phone ? el('a', { href: 'tel:' + u.phone, dir: 'ltr', style: 'color:var(--mint)', text: u.phone }) : null);
    row('מגדר', GENDER[u.gender] || u.gender);
    row('מחפש/ת', INTO[u.interestedIn] || u.interestedIn);
    row('תאריך לידה', u.birthDate);
    row('נרשם', when(u.createdAt));
    row('פעילות אחרונה', u.live ? 'Live עכשיו' : when(u.lastSeenAt));
    row('תנאי שימוש', u.termsAcceptedAt ? when(u.termsAcceptedAt) : 'לא אושרו');
    row('מכשירים עם התראות', u.counts.devices);
    row('UP', u.counts.upsSent + ' נשלחו · ' + u.counts.upsReceived + ' התקבלו');
    row('נחסם ע"י', u.counts.blockedBy || null);
    row('מזהה', el('code', { dir: 'ltr', style: 'font-size:12px', text: u.id }));
    p.appendChild(kv);

    if (u.live) {
      p.appendChild(el('h3', { text: 'Live עכשיו' }));
      p.appendChild(el('div', { class: 'mini' }, [
        el('span', { text: (u.live.mode === 'venue' ? '📍 ' + (u.live.venueName || u.live.venue) : '📡 מצב סביבה') + ' · ' + (INTENT[u.live.intent] || u.live.intent) + (u.live.note ? ' · "' + u.live.note + '"' : '') }),
        el('span', { class: 'muted', text: 'עד ' + new Date(u.live.endsAt).toLocaleTimeString('he-IL', { hour: '2-digit', minute: '2-digit' }) })
      ]));
    }

    p.appendChild(el('h3', { text: 'Matches (' + u.matches.length + ')' }));
    if (!u.matches.length) p.appendChild(el('p', { class: 'muted', text: 'אין.' }));
    u.matches.forEach(function (m) {
      p.appendChild(el('div', { class: 'mini' }, [
        el('span', {}, [
          el('a', { text: m.other.firstName || '(ללא שם)', onclick: function () { openUser(m.other.id); } }),
          document.createTextNode(m.status === 'active' ? '' : ' · בוטל')
        ]),
        el('span', { class: 'muted', text: m.messages.mine + '↑ ' + m.messages.theirs + '↓ הודעות · ' + ago(m.lastMessageAt || m.matchedAt) })
      ]));
    });
    p.appendChild(el('p', { class: 'muted', text: 'תוכן ההודעות לא מוצג כאן — רק כמויות.' }));

    p.appendChild(el('h3', { text: 'דיווחים (' + u.reports.length + ')' }));
    if (!u.reports.length) p.appendChild(el('p', { class: 'muted', text: 'אין.' }));
    u.reports.forEach(function (r) {
      var against = r.reported.id === u.id;
      p.appendChild(el('div', { class: 'mini' }, [
        el('span', {}, [
          document.createTextNode((against ? 'דווח ע"י ' : 'דיווח על ')),
          el('a', { text: (against ? r.reporter.firstName : r.reported.firstName) || '(ללא שם)', onclick: function () { openUser(against ? r.reporter.id : r.reported.id); } }),
          document.createTextNode(' · ' + (CATEGORY[r.category] || r.category) + (r.notes ? ' · "' + r.notes + '"' : ''))
        ]),
        el('span', { class: 'muted', text: (r.resolvedAt ? '✓ ' : '') + ago(r.createdAt) })
      ]));
    });

    p.appendChild(el('h3', { text: 'היסטוריית אימות' }));
    if (!u.verifications.length) p.appendChild(el('p', { class: 'muted', text: 'אין ניסיונות.' }));
    u.verifications.forEach(function (v) {
      p.appendChild(el('div', { class: 'mini' }, [
        el('span', { text: (VSTATUS[v.status] || v.status) + ' · ' + (v.method === 'live' ? 'בדיקה חיה' : v.reason === 'operator' ? 'אישור ידני' : 'סלפי') +
          (v.score != null ? ' · ציון ' + Number(v.score).toFixed(2) : '') + (v.reason && v.reason !== 'operator' ? ' · ' + v.reason : '') }),
        el('span', { class: 'muted', text: when(v.createdAt) })
      ]));
    });
  }

  function act(method, path, body, done, reopen) {
    api(method, path, body).then(function () {
      say(done); refreshAll(); if (reopen) openUser(reopen);
    }).catch(function (e) { say('שגיאה: ' + e.message); });
  }

  // -- reports ----------------------------------------------------------------------

  var showResolved = false;
  $('r-open').onclick = function () { showResolved = false; $('r-open').className = 'on'; $('r-all').className = ''; loadReports(); };
  $('r-all').onclick = function () { showResolved = true; $('r-all').className = 'on'; $('r-open').className = ''; loadReports(); };

  function loadReports() {
    return api('GET', '/admin/reports' + (showResolved ? '?all=1' : '')).then(function (j) {
      var box = $('reports'); box.innerHTML = '';
      if (!j.reports.length) box.appendChild(el('p', { class: 'muted', text: 'אין דיווחים.' }));
      j.reports.forEach(function (r) {
        box.appendChild(el('div', { class: 'card' }, [
          el('div', {}, [
            el('b', { text: CATEGORY[r.category] || r.category }),
            document.createTextNode(' · ' + when(r.createdAt) + ' '),
            r.resolvedAt ? pill('טופל', 'ok') : pill('פתוח', 'hot')
          ]),
          r.notes ? el('p', { style: 'margin:6px 0', text: '"' + r.notes + '"' }) : null,
          el('div', { class: 'muted' }, [
            document.createTextNode('על: '),
            el('a', { style: 'color:var(--pink);cursor:pointer', text: r.reported.firstName || '(ללא שם)', onclick: function () { openUser(r.reported.id); } }),
            document.createTextNode(' · מאת: '),
            el('a', { style: 'color:var(--mint);cursor:pointer', text: r.reporter.firstName || '(ללא שם)', onclick: function () { openUser(r.reporter.id); } })
          ]),
          el('div', { class: 'actions' }, [
            el('button', { class: 'ghost', text: 'פתיחת כרטיס המדווח/ת', onclick: function () { openUser(r.reported.id); } }),
            el('button', { class: r.resolvedAt ? 'ghost' : 'mint', text: r.resolvedAt ? 'פתיחה מחדש' : '✓ טופל', onclick: function () {
              api('POST', '/admin/reports/' + r.id + '/resolve', { resolved: !r.resolvedAt })
                .then(function () { loadReports(); loadStats(); loadUsers(); })
                .catch(function (e) { say(e.message); });
            } })
          ])
        ]));
      });
    });
  }

  // -- tabs -------------------------------------------------------------------------

  var TAB_KEY = 'up.admin.tab';
  function showTab(name) {
    Array.prototype.forEach.call(document.querySelectorAll('#tabs [data-tab]'), function (b) {
      b.className = b.getAttribute('data-tab') === name ? 'on' : '';
    });
    Array.prototype.forEach.call(document.querySelectorAll('[data-panel]'), function (p) {
      p.hidden = p.getAttribute('data-panel') !== name;
    });
    try { localStorage.setItem(TAB_KEY, name); } catch (e) {}
  }
  Array.prototype.forEach.call(document.querySelectorAll('#tabs [data-tab]'), function (b) {
    b.onclick = function () { showTab(b.getAttribute('data-tab')); };
  });
  try { var t0 = localStorage.getItem(TAB_KEY); if (t0) showTab(t0); } catch (e) {}

  function refreshAll() {
    return Promise.all([loadStats(), loadUsers(), loadReports(), loadVenues(), loadQueue(), loadPhotoReviews(), loadMail()]);
  }
  $('refresh').onclick = function () { refreshAll().then(function () { say('עודכן'); }).catch(function (e) { say(e.message); }); };

  // -- boot ---------------------------------------------------------------------

  function boot() {
    refreshAll().then(function () {
      $('app').hidden = false;
      $('auth').style.display = 'none';
      // Live status moves on its own; keep the list honest while the page is open.
      clearInterval(boot.t);
      boot.t = setInterval(function () {
        if (document.hidden || $('drawer').style.display === 'block') return;
        loadStats().catch(function () {}); loadUsers().catch(function () {});
      }, 30000);
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
