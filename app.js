'use strict';
/* Woven Word — interactive Bible cross references
   Data: cross references from OpenBible.info (CC BY), text: King James Version (public domain). */
const $ = s => document.querySelector(s);
const loadMsg = t => { const el = $('#loadMsg'); if (el) el.textContent = t; };

let DATA = null, KJV = null;
let TEXTS = { kjv: null, web: null };
let trans = localStorage.getItem('ww_trans') || 'kjv';
let chapterStart = [];   // global verse offset per chapter
let totalVerses = 0;
let refsByVerse = new Map();   // "ch:v" -> [[ch2,v2,votes],...]
let refsByChapter = new Map(); // ch -> Set of ref row indexes not needed; store counts + partner counts
let chapterPartners = new Map(); // ch -> Map(partnerCh -> count)
let selChapter = null;
let scope = 'all';
let readChapter = null, selVerse = null;

/* ---------------- profiles (local, on-device) ---------------- */
const store = {
  get profiles(){ try { return JSON.parse(localStorage.getItem('ww_profiles')) || []; } catch { return []; } },
  set profiles(v){ localStorage.setItem('ww_profiles', JSON.stringify(v)); },
  get active(){ return localStorage.getItem('ww_active') || ''; },
  set active(v){ localStorage.setItem('ww_active', v); },
};
let profile = null;   // {id, name}
let pdata = { hl: {}, notes: {} };  // hl: "ch:v" -> color ; notes: "ch:v" -> {text, ts}
function loadProfiles(){
  let ps = store.profiles;
  if (!ps.length){ ps = [{ id: 'p' + Date.now(), name: 'My Study' }]; store.profiles = ps; store.active = ps[0].id; }
  profile = ps.find(p => p.id === store.active) || ps[0];
  store.active = profile.id;
  try { pdata = JSON.parse(localStorage.getItem('ww_pdata_' + profile.id)) || { hl: {}, notes: {} }; }
  catch { pdata = { hl: {}, notes: {} }; }
  pdata.hl = pdata.hl || {}; pdata.notes = pdata.notes || {};
  $('#profileBtn').textContent = profile.name;
}
function savePdata(){ localStorage.setItem('ww_pdata_' + profile.id, JSON.stringify(pdata)); }

/* ---------------- helpers ---------------- */
const chName = ch => DATA.books[DATA.chapters[ch].b].name + ' ' + DATA.chapters[ch].c;
const refName = (ch, v) => chName(ch) + ':' + v;
function versePos(ch, v){
  const len = DATA.chapters[ch].v;
  return chapterStart[ch] + Math.min(Math.max(v, 1), len) - 1;
}
function scopeRange(){
  if (scope === 'ot') return [0, DATA.books[38].start + DATA.books[38].chapters - 1];
  if (scope === 'nt') return [DATA.books[39].start, 1188];
  return [0, 1188];
}

/* ---------------- data ---------------- */
async function loadData(){
  loadMsg('Loading the web of connections…');
  DATA = await (await fetch('data.json')).json();
  loadMsg('Loading the King James text…');
  TEXTS.kjv = await (await fetch('kjv.json')).json();
  KJV = TEXTS.kjv;
  loadMsg('Loading the World English Bible…');
  TEXTS.web = await (await fetch('web.json')).json();
  let acc = 0;
  chapterStart = DATA.chapters.map(c => { const s = acc; acc += c.v; return s; });
  totalVerses = acc;
  loadMsg('Indexing 344,799 connections…');
  await new Promise(r => setTimeout(r, 30));
  for (const [fc, fv, tc, tv, votes] of DATA.refs){
    const k1 = fc + ':' + fv, k2 = tc + ':' + tv;
    (refsByVerse.get(k1) || refsByVerse.set(k1, []).get(k1)).push([tc, tv, votes]);
    (refsByVerse.get(k2) || refsByVerse.set(k2, []).get(k2)).push([fc, fv, votes]);
    for (const [a, b] of [[fc, tc], [tc, fc]]){
      let m = chapterPartners.get(a);
      if (!m){ m = new Map(); chapterPartners.set(a, m); }
      m.set(b, (m.get(b) || 0) + 1);
    }
  }
  $('#loading').style.display = 'none';
}

/* ---------------- canvas web ---------------- */
const canvas = $('#arcCanvas'), ctx = canvas.getContext('2d');
let viewCache = null;
function drawWeb(){
  const wrap = $('#webView');
  const W = wrap.clientWidth, H = wrap.clientHeight;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = W * dpr; canvas.height = H * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  const [lo, hi] = scopeRange();
  const loV = chapterStart[lo], hiV = chapterStart[hi] + DATA.chapters[hi].v;
  const padX = 8, axisY = H - 108, maxArcH = axisY - 64;
  const X = pos => padX + (pos - loV) / (hiV - loV) * (W - padX * 2);
  // chapter bars
  for (let ch = lo; ch <= hi; ch++){
    const c = DATA.chapters[ch];
    const x0 = X(chapterStart[ch]), x1 = X(chapterStart[ch] + c.v);
    const h = 14 + Math.sqrt(c.v) * 4.4;
    const isSel = ch === selChapter;
    ctx.fillStyle = isSel ? '#e8b33c' : (DATA.chapters[ch].b % 2 ? '#8f8a7a' : '#c9c2ab');
    ctx.fillRect(x0, axisY, Math.max(1, x1 - x0 - 0.4), h);
  }
  // book labels
  ctx.fillStyle = '#7d7763'; ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
  for (const b of DATA.books){
    const mid = b.start + (b.chapters - 1) / 2;
    if (mid < lo || mid > hi) continue;
    const w = (chapterStart[Math.min(1188, b.start + b.chapters)] - chapterStart[b.start]) / (hiV - loV) * W;
    if (w > 34) ctx.fillText(b.abbr, X(chapterStart[b.start] + DATA.chapters[b.start].v * b.chapters / 2), axisY + 66);
  }
  // arcs
  ctx.globalCompositeOperation = 'lighter';
  ctx.lineWidth = 1;
  const drawArc = (a, b, style) => {
    const x1 = X(a), x2 = X(b);
    if (Math.abs(x2 - x1) < 0.6) return;
    const hgt = Math.min(maxArcH, Math.abs(x2 - x1) * 0.52);
    ctx.strokeStyle = style;
    ctx.beginPath(); ctx.moveTo(x1, axisY);
    ctx.quadraticCurveTo((x1 + x2) / 2, axisY - hgt * 2, x2, axisY); ctx.stroke();
  };
  const arcColor = (d, alpha) => {
    const t = Math.pow(d / (hiV - loV), 0.42);
    const hue = 275 - t * 275; // near = purple/blue, far = gold/red
    return `hsla(${hue},85%,58%,${alpha})`;
  };
  if (selChapter === null || selChapter < lo || selChapter > hi){
    for (const [a, b, n] of DATA.chapterArcs){
      if (a < lo || a > hi || b < lo || b > hi) continue;
      const pa = versePos(a, Math.ceil(DATA.chapters[a].v / 2));
      const pb = versePos(b, Math.ceil(DATA.chapters[b].v / 2));
      drawArc(pa, pb, arcColor(Math.abs(pb - pa), Math.min(0.30, 0.028 + Math.log10(n) * 0.055)));
    }
  } else {
    for (const [a, b] of DATA.chapterArcs){
      if (a < lo || a > hi || b < lo || b > hi) continue;
      const pa = versePos(a, Math.ceil(DATA.chapters[a].v / 2));
      const pb = versePos(b, Math.ceil(DATA.chapters[b].v / 2));
      drawArc(pa, pb, 'rgba(70,66,60,0.05)');
    }
    const partners = chapterPartners.get(selChapter) || new Map();
    for (const [p, n] of partners){
      if (p < lo || p > hi) continue;
      const pa = versePos(selChapter, Math.ceil(DATA.chapters[selChapter].v / 2));
      const pb = versePos(p, Math.ceil(DATA.chapters[p].v / 2));
      for (let i = 0; i < Math.min(3, 1 + Math.floor(Math.log10(n))); i++)
        drawArc(pa, pb, arcColor(Math.abs(pb - pa), 0.5));
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  viewCache = { X, loV, hiV, W, axisY };
}
canvas.addEventListener('click', e => {
  if (!viewCache) return;
  const r = canvas.getBoundingClientRect();
  const x = e.clientX - r.left;
  const frac = (x - 8) / (viewCache.W - 16);
  const pos = viewCache.loV + frac * (viewCache.hiV - viewCache.loV);
  let ch = 1188;
  for (let i = 0; i < 1189; i++){ if (pos < chapterStart[i] + DATA.chapters[i].v){ ch = i; break; } }
  const [lo, hi] = scopeRange();
  if (ch < lo || ch > hi) return;
  selectChapter(ch);
});
function selectChapter(ch){
  selChapter = ch;
  drawWeb();
  const partners = chapterPartners.get(ch) || new Map();
  let out = 0, into = 0;
  for (const [fc, fv, tc] of DATA.refs){ if (fc === ch) out++; if (tc === ch) into++; }
  const top = [...partners.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
  const sheet = $('#sheet');
  sheet.innerHTML = `
    <h2>${chName(ch)}</h2>
    <div class="sub">${DATA.chapters[ch].v} verses · ${out + into} connections woven from this chapter</div>
    ${top.map(([p, n]) => `<div class="conn" data-ch="${p}"><b>${chName(p)}</b><span>${n} connection${n === 1 ? '' : 's'}</span></div>`).join('')}
    <div class="row">
      <button id="sheetClose">Close</button>
      <button class="primary" id="sheetRead">Read ${chName(ch)}</button>
    </div>`;
  sheet.classList.add('open');
  sheet.querySelectorAll('.conn').forEach(el => el.onclick = () => selectChapter(+el.dataset.ch));
  $('#sheetClose').onclick = () => { sheet.classList.remove('open'); selChapter = null; drawWeb(); };
  $('#sheetRead').onclick = () => { sheet.classList.remove('open'); openChapter(ch); };
}

/* ---------------- reading view ---------------- */
function showView(id){
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  $('#' + id).classList.add('active');
  $('#readNav').style.display = id === 'readView' ? 'flex' : 'none';
  if (id === 'webView') requestAnimationFrame(drawWeb);
}
function openChapter(ch, flashVerse){
  readChapter = ch; selVerse = null;
  hideVerseBar();
  const c = DATA.chapters[ch], book = DATA.books[c.b];
  $('#rhBook').textContent = 'The Book of ' + book.name.replace(/^\d /, '');
  $('#rhChap').innerHTML = `${book.name} <small>CHAPTER ${c.c}</small>`;
  const verses = (TEXTS[trans] || TEXTS.kjv)[c.b][c.c - 1];
  document.querySelectorAll('#transBar button').forEach(b => b.classList.toggle('on', b.dataset.t === trans));
  $('#readBody').innerHTML = verses.map((t, i) => {
    const v = i + 1, key = ch + ':' + v;
    const hl = pdata.hl[key], note = pdata.notes[key];
    const has = refsByVerse.has(key);
    return `<span class="v ${hl ? 'hl-' + hl : ''} ${note ? 'hasnote' : ''}" data-v="${v}"><span class="vnum">${v}</span>${has ? '<span class="cdot">•</span>' : ''}${escapeHtml(t)}</span>`;
  }).join(' ');
  $('#readBody').querySelectorAll('.v').forEach(el => {
    el.onclick = () => selectVerse(ch, +el.dataset.v);
  });
  showView('readView');
  $('#readView').scrollTop = 0;
  if (flashVerse){
    setTimeout(() => {
      const el = $('#readBody').querySelector(`.v[data-v="${flashVerse}"]`);
      if (el){ el.scrollIntoView({ block: 'center' }); el.classList.add('sel'); setTimeout(() => el.classList.remove('sel'), 2600); }
    }, 60);
  }
}
function escapeHtml(s){ return s.replace(/&/g, '&amp;').replace(/</g, '&lt;'); }
function selectVerse(ch, v){
  selVerse = v;
  $('#readBody').querySelectorAll('.v').forEach(el => el.classList.toggle('sel', +el.dataset.v === v));
  const key = ch + ':' + v;
  const conns = (refsByVerse.get(key) || []).length;
  const bar = $('#verseBar');
  bar.innerHTML = `
    <div class="vref">${refName(ch, v)}${conns ? ` · ${conns} connection${conns === 1 ? '' : 's'}` : ''}</div>
    <div class="acts">
      <button id="vbConn">Connections</button>
      <button id="vbHl">Highlight</button>
      <button id="vbNote">${pdata.notes[key] ? 'Edit note' : 'Add note'}</button>
      <button id="vbDone">Done</button>
    </div>
    <div class="swatches" id="vbSw" style="display:none">
      ${['gold', 'green', 'blue', 'pink', 'purple'].map(c => `<div class="sw hl-${c}" data-c="${c}"></div>`).join('')}
      <div class="sw" data-c="" style="background:#22222c;color:#ccc;display:flex;align-items:center;justify-content:center;font-size:11px">Off</div>
    </div>`;
  bar.classList.add('open');
  $('#vbDone').onclick = hideVerseBar;
  $('#vbHl').onclick = () => { const sw = $('#vbSw'); sw.style.display = sw.style.display === 'none' ? 'flex' : 'none'; };
  bar.querySelectorAll('.sw').forEach(sw => sw.onclick = () => {
    if (sw.dataset.c) pdata.hl[key] = sw.dataset.c; else delete pdata.hl[key];
    savePdata(); openChapter(ch); selectVerse(ch, v);
  });
  $('#vbConn').onclick = () => showConnections(ch, v);
  $('#vbNote').onclick = () => editNote(ch, v);
}
function hideVerseBar(){ $('#verseBar').classList.remove('open'); selVerse = null; }
function verseText(ch, v){
  const c = DATA.chapters[ch];
  return ((TEXTS[trans] || TEXTS.kjv)[c.b][c.c - 1][v - 1] || '');
}
function showConnections(ch, v){
  const list = [...(refsByVerse.get(ch + ':' + v) || [])].sort((a, b) => b[2] - a[2]);
  openModal(`
    <h3>${refName(ch, v)}</h3>
    <div style="font-family:var(--serif); font-size:15.5px; color:#ddd6bd; line-height:1.5; margin-bottom:8px">${escapeHtml(verseText(ch, v))}</div>
    ${list.length ? list.map(([c2, v2]) => `
      <div class="connitem" data-ch="${c2}" data-v="${v2}"><b>${refName(c2, v2)}</b><p>${escapeHtml(verseText(c2, v2))}</p></div>`).join('')
      : '<div style="color:#98917a">No cross references are recorded for this verse.</div>'}
    <div class="row"><button id="mClose">Close</button></div>`);
  $('#modal').querySelectorAll('.connitem').forEach(el => el.onclick = () => { closeModal(); hideVerseBar(); openChapter(+el.dataset.ch, +el.dataset.v); });
  $('#mClose').onclick = closeModal;
}
function editNote(ch, v){
  const key = ch + ':' + v;
  const cur = pdata.notes[key];
  openModal(`
    <h3>Note on ${refName(ch, v)}</h3>
    <div style="font-family:var(--serif); font-size:15px; color:#c9c2ab; margin-bottom:10px; line-height:1.5">${escapeHtml(verseText(ch, v))}</div>
    <textarea id="noteText" placeholder="Write your note…">${cur ? escapeHtml(cur.text) : ''}</textarea>
    <div class="row">
      ${cur ? '<button class="danger" id="noteDel">Delete</button>' : ''}
      <button id="noteCancel">Cancel</button>
      <button class="primary" id="noteSave">Save note</button>
    </div>`);
  $('#noteCancel').onclick = closeModal;
  $('#noteSave').onclick = () => {
    const t = $('#noteText').value.trim();
    if (t) pdata.notes[key] = { text: t, ts: Date.now() }; else delete pdata.notes[key];
    savePdata(); closeModal(); openChapter(ch); selectVerse(ch, v);
  };
  if (cur) $('#noteDel').onclick = () => { delete pdata.notes[key]; savePdata(); closeModal(); openChapter(ch); };
}

/* ---------------- modal ---------------- */
function openModal(html){ $('#modal').innerHTML = html; $('#modalWrap').classList.add('open'); }
function closeModal(){ $('#modalWrap').classList.remove('open'); }
$('#modalWrap').addEventListener('click', e => { if (e.target.id === 'modalWrap') closeModal(); });

/* ---------------- notes & highlights list ---------------- */
function showNotes(){
  const notes = Object.entries(pdata.notes).sort((a, b) => b[1].ts - a[1].ts);
  const hls = Object.entries(pdata.hl);
  $('#listInner').innerHTML = `
    <h2>My Notes</h2>
    <div class="sub">Saved on this device for ${escapeHtml(profile.name)}. Highlights and notes stay in your browser storage.</div>
    ${notes.length ? notes.map(([key, n]) => {
      const [ch, v] = key.split(':').map(Number);
      return `<div class="item" data-ch="${ch}" data-v="${v}"><b>${refName(ch, v)}</b><p>${escapeHtml(n.text)}</p><div class="meta">${new Date(n.ts).toLocaleDateString()} · on: “${escapeHtml(verseText(ch, v).slice(0, 90))}…”</div></div>`;
    }).join('') : '<div class="empty">No notes yet.<br>Open any chapter, tap a verse, and choose Add note.</div>'}
    <h2 style="margin-top:26px">Highlights</h2>
    ${hls.length ? hls.map(([key, c]) => {
      const [ch, v] = key.split(':').map(Number);
      return `<div class="item" data-ch="${ch}" data-v="${v}"><b>${refName(ch, v)}</b><p><span class="hl-${c}" style="padding:1px 4px; border-radius:4px">${escapeHtml(verseText(ch, v))}</span></p></div>`;
    }).join('') : '<div class="empty">No highlights yet.<br>Tap a verse while reading and choose Highlight.</div>'}
    <div class="row" style="margin-top:20px"><button class="tbtn" id="backWeb" style="width:100%; padding:12px">Back to the Web</button></div>`;
  showView('listView');
  $('#listInner').querySelectorAll('.item').forEach(el => el.onclick = () => openChapter(+el.dataset.ch, +el.dataset.v));
  $('#backWeb').onclick = () => showView('webView');
}

/* ---------------- profiles modal ---------------- */
function showProfiles(){
  const ps = store.profiles;
  openModal(`
    <h3>Study Profiles</h3>
    <div style="color:#a49e88; font-size:13px; margin-bottom:8px">Profiles live on this device only. Each keeps its own highlights and notes.</div>
    ${ps.map(p => `<div class="profrow"><div class="nm">${escapeHtml(p.name)}${p.id === profile.id ? ' · current' : ''}</div>
      ${p.id !== profile.id ? `<button data-use="${p.id}">Use</button>` : ''}
      ${ps.length > 1 ? `<button data-del="${p.id}">Delete</button>` : ''}</div>`).join('')}
    <input type="text" id="newProf" placeholder="New profile name" style="margin-top:10px">
    <div class="row"><button id="pClose">Close</button><button class="primary" id="pAdd">Add profile</button></div>`);
  $('#pClose').onclick = closeModal;
  $('#modal').querySelectorAll('[data-use]').forEach(b => b.onclick = () => { store.active = b.dataset.use; loadProfiles(); closeModal(); if (readChapter !== null && $('#readView').classList.contains('active')) openChapter(readChapter); });
  $('#modal').querySelectorAll('[data-del]').forEach(b => b.onclick = () => {
    const id = b.dataset.del;
    store.profiles = store.profiles.filter(p => p.id !== id);
    localStorage.removeItem('ww_pdata_' + id);
    if (store.active === id) store.active = store.profiles[0].id;
    loadProfiles(); showProfiles();
  });
  $('#pAdd').onclick = () => {
    const nm = $('#newProf').value.trim(); if (!nm) return;
    const p = { id: 'p' + Date.now(), name: nm };
    store.profiles = [...store.profiles, p]; store.active = p.id;
    loadProfiles(); closeModal();
  };
}

/* ---------------- search ---------------- */
function parseSearch(q){
  q = q.trim().toLowerCase(); if (!q) return null;
  const m = q.match(/^(.*?)\s+(\d+)$/);
  const bookPart = m ? m[1] : q, chapNum = m ? +m[2] : 1;
  const bi = DATA.books.findIndex(b => b.name.toLowerCase().startsWith(bookPart) || b.abbr.toLowerCase() === bookPart.replace(/\s/g, ''));
  if (bi < 0) return null;
  const ch = DATA.books[bi].start + Math.min(Math.max(chapNum, 1), DATA.books[bi].chapters) - 1;
  return ch;
}

/* ---------------- wiring ---------------- */
$('#scopeSel').addEventListener('change', e => { scope = e.target.value; selChapter = null; $('#sheet').classList.remove('open'); drawWeb(); });
$('#searchBox').addEventListener('change', e => { const ch = parseSearch(e.target.value); if (ch !== null) selectChapter(ch); });
$('#prevCh').onclick = () => { if (readChapter > 0) openChapter(readChapter - 1); };
$('#nextCh').onclick = () => { if (readChapter < 1188) openChapter(readChapter + 1); };
$('#toWeb').onclick = () => showView('webView');
$('#notesBtn').onclick = showNotes;
document.querySelectorAll('#transBar button').forEach(b => b.onclick = () => {
  trans = b.dataset.t; localStorage.setItem('ww_trans', trans);
  if (readChapter !== null) openChapter(readChapter);
});
$('#profileBtn').onclick = showProfiles;
window.addEventListener('resize', () => { if ($('#webView').classList.contains('active')) drawWeb(); });

loadProfiles();
loadData().then(() => { drawWeb(); });
