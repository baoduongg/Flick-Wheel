// Landing page script. ACTIONS comes from actions-data.js, generated from the app's default manifest.
// Wheel geometry is ported from promo/src/GlassWheel.tsx, which mirrors FlickWheel/Wheel/RadialWheelView.swift.
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

const FALLBACK = { shift: 'arrow.triangle.2.circlepath', command: 'wand.and.stars', control: 'square.and.arrow.up' };
const sf = name => `assets/sf/${name}.png`;
const icon = a => sf(ICONS[a.id] || FALLBACK[a.wheel]);
const ext = f => f.split('.').pop().toLowerCase();
// ActionRegistry rule: "!ext" rules a type out, "*" takes anything
const takes = (a, e) => { const r = a.accepts.map(x => x.toLowerCase()); return !r.includes('!' + e) && r.some(x => x === '*' || x === e); };
const stem = f => f.slice(0, f.lastIndexOf('.'));

// ---------- logo: eight-segment mark from promo/src/Logo.tsx ----------
const LOGO = ['#0a84ff', '#3d7bff', '#7a63f0', '#a64dd6', '#d4609f', '#ff7f50', '#ff9f0a', '#ffb340'];
const pol = (r, a) => [r * Math.cos(a), r * Math.sin(a)];
function logoSVG() {
  const paths = LOGO.map((c, i) => {
    const a0 = -Math.PI / 2 + i * Math.PI / 4 + .045, a1 = -Math.PI / 2 + (i + 1) * Math.PI / 4 - .045, mid = -Math.PI / 2 + (i + .5) * Math.PI / 4;
    const [x0, y0] = pol(100, a0), [x1, y1] = pol(100, a1), [x2, y2] = pol(50, a1), [x3, y3] = pol(50, a0);
    const [dx, dy] = pol(-26, mid), [ox, oy] = pol(6, mid);
    const d = `M${x0} ${y0}A100 100 0 0 1 ${x1} ${y1}L${x2} ${y2}A50 50 0 0 0 ${x3} ${y3}Z`;
    return `<path d="${d}" fill="${c}" style="--i:${i};--dx:${dx.toFixed(1)}px;--dy:${dy.toFixed(1)}px;--ox:${ox.toFixed(1)}px;--oy:${oy.toFixed(1)}px"/>`;
  }).join('');
  return `<svg class="logo" viewBox="-110 -110 220 220" aria-hidden="true">${paths}</svg>`;
}
$$('[data-logo]').forEach(el => { el.innerHTML = logoSVG(); el.style.display = 'block'; });

// highlight each segment in turn, like the wheel selection in the promo
function sweep(logo) {
  if (reduce) return;
  const ps = $$('path', logo);
  logo.classList.add('sweep');
  ps.forEach((p, i) => setTimeout(() => { ps.forEach(q => q.classList.remove('hot')); p.classList.add('hot'); }, i * 160));
  setTimeout(() => { ps.forEach(q => q.classList.remove('hot')); logo.classList.remove('sweep'); }, ps.length * 160 + 300);
}

// ---------- scroll reveal (IntersectionObserver, no scroll listeners) ----------
function count(el) {
  const to = +el.dataset.count;
  if (reduce || !to) return (el.textContent = to);
  const t0 = performance.now();
  (function tick(now) {
    const p = Math.min(1, (now - t0) / 1100);
    el.textContent = Math.round(to * (1 - Math.pow(2, -10 * p)));
    if (p < 1) requestAnimationFrame(tick);
  })(t0);
}
const io = new IntersectionObserver(entries => entries.forEach(e => {
  if (!e.isIntersecting) return;
  const el = e.target;
  el.classList.add('in');
  io.unobserve(el);
  if (el.matches('[data-demo]')) $('.wheel', el)?.classList.add('enter');
  $$('[data-count]', el).forEach(count);
  if (el.matches('.logo[data-sweepme]')) setTimeout(() => sweep(el), 1300);
}), { threshold: .15, rootMargin: '0px 0px -6% 0px' });
$$('.final .logo').forEach(l => l.dataset.sweepme = '1');
$$('.rv, .logo, .hero, .hook').forEach(el => io.observe(el));

// ---------- nav: hamburger morph + staggered overlay ----------
const burger = $('#burger'), menu = $('#menu');
function toggleMenu(open) {
  burger.setAttribute('aria-expanded', open);
  menu.classList.toggle('open', open);
  menu.toggleAttribute('inert', !open);
  document.documentElement.classList.toggle('locked', open);
}
burger.addEventListener('click', () => toggleMenu(burger.getAttribute('aria-expanded') !== 'true'));
$$('a', menu).forEach(a => a.addEventListener('click', () => toggleMenu(false)));
addEventListener('keydown', e => { if (e.key === 'Escape') toggleMenu(false); });

// ---------- wheel cards: chips per wheel, straight from the manifest ----------
$$('[data-wheel-chips]').forEach(box => {
  box.innerHTML = ACTIONS.filter(a => a.wheel === box.dataset.wheelChips)
    .map(a => `<span><img src="${icon(a)}" alt="" width="18" height="16">${a.label}</span>`).join('');
});

// ---------- interactive wheel (hero + Try it share this) ----------
// ring geometry from promo/src/GlassWheel.tsx
const NS = 'http://www.w3.org/2000/svg';
const RING = 90, SEAM = 4, CORNER = 9;
const rad = d => d * Math.PI / 180;
const startDeg = n => (n % 4 === 0 ? 0 : -180 / n);
const radii = n => { const mid = Math.max(110, n * 92 / (2 * Math.PI)); return { inner: mid - RING / 2, outer: mid + RING / 2, mid }; };
const center = (i, n) => {
  const th = rad(startDeg(n) + (i + .5) * (360 / n)), { mid } = radii(n);
  return { x: mid * Math.sin(th), y: -mid * Math.cos(th), th };
};
function segPath(i, n) {
  const step = 360 / n, origin = -90 + startDeg(n), r = radii(n);
  const inner = r.inner + CORNER, outer = r.outer - CORNER;
  const inset = rr => Math.asin((SEAM / 2 + CORNER) / rr) * 180 / Math.PI;
  const from = origin + i * step, to = origin + (i + 1) * step;
  const a1 = from + inset(outer), a2 = to - inset(outer), a3 = to - inset(inner), a4 = from + inset(inner);
  const p = (rr, d) => [rr * Math.cos(rad(d)), rr * Math.sin(rad(d))];
  const arc = (c, rr, d0, d1) => {
    const [bx, by] = p(rr, d0), [ex, ey] = p(rr, d1);
    return `L${c[0] + bx} ${c[1] + by}A${rr} ${rr} 0 0 ${d1 > d0 ? 1 : 0} ${c[0] + ex} ${c[1] + ey}`;
  };
  const o = [0, 0], [sx, sy] = p(outer + CORNER, a1);
  return [`M${sx} ${sy}`, arc(o, outer + CORNER, a1, a2), arc(p(outer, a2), CORNER, a2, to + 90), arc(p(inner, a3), CORNER, to + 90, a3 + 180),
    arc(o, inner - CORNER, a3, a4), arc(p(inner, a4), CORNER, a4 + 180, from + 270), arc(p(outer, a1), CORNER, from - 90, a1), 'Z'].join('');
}
const el = (tag, attrs = {}) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); return e; };

// glass ring shared by the hero demo and the Settings preview; `bind` wires each segment
function drawRing(svg, acts, uid, bind, interactive = true) {
  const cnt = acts.length;
  svg.replaceChildren();
  const defs = el('defs'), lg = el('linearGradient', { id: uid, x1: 0, y1: 0, x2: 0, y2: 1 });
  lg.append(el('stop', { offset: 0, 'stop-color': '#fff', 'stop-opacity': .12 }), el('stop', { offset: 1, 'stop-color': '#fff', 'stop-opacity': 0 }));
  defs.append(lg); svg.append(defs);
  acts.forEach((a, i) => {
    const c = center(i, cnt), d = segPath(i, cnt);
    const g = el('g', interactive ? { class: 's', tabindex: 0, role: 'button' } : { class: 's', 'aria-hidden': 'true' });
    g.style.cssText = `--i:${i};--dx:${(6 * Math.sin(c.th)).toFixed(2)}px;--dy:${(-6 * Math.cos(c.th)).toFixed(2)}px`;
    g.dataset.id = a.id;
    const e = el('g', { class: 'e' });
    const im = el('image', { href: icon(a), x: c.x - 14, y: c.y - 19.5, width: 28, height: 22, preserveAspectRatio: 'xMidYMid meet' });
    const t = el('text', { x: c.x, y: c.y + 16 }); t.textContent = a.label;
    e.append(el('path', { class: 'b', d }), el('path', { class: 'gl', d, fill: `url(#${uid})` }), el('path', { class: 'hot', d }), el('path', { class: 'ln', d }), im, t);
    g.append(e);
    bind?.(g, a);
    svg.append(g);
  });
}

const demos = [];
function makeDemo(root, n) {
  const svg = $('.wheel', root), chip = $('.chip', root), stage = $('.stage', root), toast = $('.toast', root), empty = $('.empty', root);
  let key = 'shift', file = 'photo.png';
  const say = (text, cls = '') => { toast.textContent = text; toast.className = 'toast ' + cls; };
  const visible = () => { const e = ext(file); return ACTIONS.filter(a => a.wheel === key && !a.multi && takes(a, e)).slice(0, 8); };

  function render(fade = false) {
    const acts = visible();
    empty.hidden = acts.length > 0;
    drawRing(svg, acts, `gl${n}`, (g, a) => {
      g.setAttribute('aria-label', `${a.label} on ${file}`);
      g.addEventListener('keydown', ev => { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); run(a); } });
    });
    if (fade) {
      svg.classList.remove('enter'); // the pop-in is for the first reveal only
      if (!reduce) svg.animate({ opacity: [0, 1] }, { duration: 150, easing: 'ease-out' });
    }
  }

  function run(a) {
    const e = ext(file);
    const out = a.out ? stem(file) + a.out.replace('${INPUT##*.}', e) : null;
    say(out ? `✓ ${a.label}: ${file} → ${out}` : `✓ ${a.label}: ${file}`, 'ok');
  }

  function setKey(k) {
    key = k;
    $$('[data-key]', root).forEach(b => b.setAttribute(b.getAttribute('role') === 'tab' ? 'aria-selected' : 'aria-pressed', b.dataset.key === k));
    say('');
    render(true);
  }
  function setFile(f) {
    file = f;
    $$('[data-file]', root).forEach(b => b.setAttribute('aria-pressed', b.dataset.file === f));
    $('.chipName', root).textContent = f;
    say('');
    render(true);
  }
  $$('[data-key]', root).forEach(b => b.addEventListener('click', () => setKey(b.dataset.key)));
  $$('[data-file]', root).forEach(b => b.addEventListener('click', () => setFile(b.dataset.file)));

  // chip drag with pointer events (mouse, touch, pen): keeps the grab offset, moves by transform,
  // springs back from the release velocity, and is absorbed by the segment it lands on
  let pos = { x: 0, y: 0 }, grab = { x: 0, y: 0 }, trail = [], raf = 0;
  const place = (x, y) => { pos = { x, y }; chip.style.transform = x || y ? `translate3d(${x}px,${y}px,0)` : ''; };
  const clearOver = () => $$('.s.over', root).forEach(s => s.classList.remove('over'));
  const settle = () => { cancelAnimationFrame(raf); chip.getAnimations().forEach(a => a.cancel()); }; // grabbing mid-flight starts from where it is
  function resetChip() { settle(); chip.classList.remove('drag'); place(0, 0); clearOver(); }
  function velocity() {
    const now = performance.now(), a = trail.find(q => now - q.t < 100), b = trail.at(-1);
    if (!a || a === b || now - b.t > 60) return { x: 0, y: 0 };
    const dt = (b.t - a.t) / 1000;
    return { x: (b.x - a.x) / dt, y: (b.y - a.y) / dt };
  }
  function springBack({ x: vx, y: vy }) {
    if (reduce) return resetChip();
    const w = 2 * Math.PI / .4, k = w * w, c = 2 * .8 * w; // response .4s, damping .8: a little bounce because the throw carried momentum
    let { x, y } = pos, last = performance.now();
    clearOver(); chip.classList.remove('drag');
    raf = requestAnimationFrame(function step(now) {
      const dt = Math.min(.032, Math.max(0, (now - last) / 1000)); last = now;
      vx += (-k * x - c * vx) * dt; vy += (-k * y - c * vy) * dt; x += vx * dt; y += vy * dt;
      if (Math.hypot(x, y) < .4 && Math.hypot(vx, vy) < 8) return place(0, 0);
      place(x, y); raf = requestAnimationFrame(step);
    });
  }
  function absorb(seg) {
    if (reduce) return resetChip();
    const r = seg.getBoundingClientRect(), st = stage.getBoundingClientRect();
    const tx = r.left + r.width / 2 - (st.left + st.width / 2), ty = r.top + r.height / 2 - (st.top + st.height / 2);
    chip.classList.remove('drag');
    chip.animate([{ transform: `translate3d(${pos.x}px,${pos.y}px,0)`, opacity: 1 }, { transform: `translate3d(${tx}px,${ty}px,0) scale(.35)`, opacity: 0 }],
      { duration: 180, easing: 'cubic-bezier(.32,.72,0,1)', fill: 'forwards' }).finished
      .then(() => { resetChip(); chip.animate({ opacity: [0, 1] }, { duration: 250, delay: 120, easing: 'ease-out', fill: 'backwards' }); })
      .catch(() => {}); // grabbed again mid-absorb
  }
  function segAt(x, y) { chip.style.pointerEvents = 'none'; const s = document.elementFromPoint(x, y)?.closest('.s'); chip.style.pointerEvents = ''; return s && root.contains(s) ? s : null; }
  chip.addEventListener('pointerdown', e => {
    settle(); chip.setPointerCapture(e.pointerId); chip.classList.add('drag'); say('');
    const r = chip.getBoundingClientRect(); grab = { x: e.clientX - (r.left + r.width / 2), y: e.clientY - (r.top + r.height / 2) }; trail = [];
  });
  chip.addEventListener('pointermove', e => {
    if (!chip.classList.contains('drag')) return;
    const r = stage.getBoundingClientRect();
    place(e.clientX - grab.x - (r.left + r.width / 2), e.clientY - grab.y - (r.top + r.height / 2));
    trail.push({ t: performance.now(), x: pos.x, y: pos.y }); if (trail.length > 6) trail.shift();
    const s = segAt(e.clientX, e.clientY);
    $$('.s.over', root).forEach(x => x !== s && x.classList.remove('over')); s?.classList.add('over');
  });
  chip.addEventListener('pointerup', e => {
    if (!chip.classList.contains('drag')) return;
    const s = segAt(e.clientX, e.clientY);
    const a = s && ACTIONS.find(x => x.id === s.dataset.id);
    if (a) { run(a); absorb(s); } else { springBack(velocity()); say('Dropped outside a segment: nothing runs.'); }
  });
  chip.addEventListener('pointercancel', resetChip);

  render();
  return { setKey };
}
$$('[data-demo]').forEach((root, i) => demos.push(makeDemo(root, i)));
addEventListener('keydown', e => {
  if (e.metaKey || e.ctrlKey || e.altKey || /input|textarea/i.test(e.target.tagName)) return;
  const k = { s: 'shift', c: 'command', k: 'control' }[e.key.toLowerCase()];
  if (k) demos.forEach(d => d.setKey(k));
});

// copy button
$('#copy').addEventListener('click', async e => {
  try { await navigator.clipboard.writeText($('#snippet').textContent); e.target.textContent = 'Copied'; }
  catch { e.target.textContent = 'Press ⌘C'; }
  setTimeout(() => (e.target.textContent = 'Copy'), 1500);
});


// ---------- editor showcase: mock windows ----------
const I = {
  arrow: '<path d="M17 17 7 7M7 15V7h8"/>', highlighter: '<path d="m4 20 3.5-1 10-10-2.5-2.5-10 10zM14 6.5l2.5 2.5M13 20h7"/>', text: '',
  rectangle: '<rect x="4" y="6" width="16" height="12" rx="1.5"/>', ellipse: '<circle cx="12" cy="12" r="8"/>', pen: '<path d="m5 19 1-4L16.5 4.5l3 3L9 18z"/>',
  badge: '<circle cx="12" cy="12" r="8.5"/><path d="M10.3 9.8 12.2 8.5v7"/>', redact: '<path d="M3.5 12s3.2-6 8.5-6 8.5 6 8.5 6-3.2 6-8.5 6-8.5-6-8.5-6zM4 4l16 16"/>',
  zoomout: '<circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 5 5M8 10.5h5"/>', zoomin: '<circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 5 5M8 10.5h5M10.5 8v5"/>',
  undo: '<path d="M9 8H5v-4M5 8c2-3 5-4 8-3.5s6 3.5 6 7.5-3.5 7-7.500 7"/>', trash: '<path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/>',
  back: '<path d="M6 6v12M18 6l-9 6 9 6z" fill="currentColor"/>', play: '<path d="M8 5.5v13l11-6.5z" fill="currentColor"/>', fwd: '<path d="M18 6v12M6 6l9 6-9 6z" fill="currentColor"/>',
};
const svgI = k => `<svg viewBox="0 0 24 24" aria-hidden="true">${I[k]}</svg>`;
$$('[data-i]').forEach(b => (b.innerHTML = svgI(b.dataset.i)));

const HINTS = {
  arrow: 'Drag from the tail toward the arrowhead. Drag an annotation to move it.', highlighter: 'Drag over the area to highlight. Drag an annotation to move it.',
  text: 'Click to place text, type, then press Return. Drag text to move it.', rectangle: 'Drag from corner to corner. Drag an outline to move it.',
  ellipse: 'Drag across the area to circle. Drag an outline to move it.', pen: 'Drag to draw freehand. Drag a stroke to move it.',
  badge: 'Click to drop a numbered marker. Drag a marker to move it.', redact: 'Drag over what to hide. The saved copy covers it with a solid block in the picked color.',
};
const tb = $('.tools8');
tb.innerHTML = Object.keys(HINTS).map((k, i) => `<button aria-pressed="${i === 0}" data-t="${k}" aria-label="${k}">${k === 'text' ? 'Aa' : svgI(k)}</button>`).join('');
tb.addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  $$('button', tb).forEach(x => x.setAttribute('aria-pressed', x === b));
  $('[data-hint]').textContent = HINTS[b.dataset.t];
});

// filmstrip: same frame, hue-shifted, like thumbnails along a video
$('#strip').insertAdjacentHTML('afterbegin', Array.from({ length: 12 }, (_, i) =>
  `<svg class="f" viewBox="0 0 400 250" preserveAspectRatio="xMidYMid slice" style="filter:hue-rotate(${i * 14}deg) saturate(${1 + (i % 3) * .1})" aria-hidden="true"><use href="#fake" width="400" height="250"/></svg>`).join(''));

new IntersectionObserver(es => es.forEach(e => e.target.classList.toggle('live', e.isIntersecting))).observe($('#strip'));

// crop: ratio presets fit inside the image like CropModel does
const cropBox = $('#cbox'), IMG = { w: 1600, h: 1000 };
const CR = { Free: null, '1:1': 1, '16:9': 16 / 9, '9:16': 9 / 16, '4:3': 4 / 3, '3:4': 3 / 4 };
function setCrop(ratio) {
  let w = .8, h = .76; // fraction of the image
  if (ratio) { const r = ratio * IMG.h / IMG.w; h = Math.min(.76, .8 / r); w = h * r; if (w > .8) { w = .8; h = w / r; } }
  Object.assign(cropBox.style, { width: w * 100 + '%', height: h * 100 + '%', left: (1 - w) / 2 * 100 + '%', top: (1 - h) / 2 * 100 + '%' });
  $('#cw').textContent = Math.round(w * IMG.w); $('#ch').textContent = Math.round(h * IMG.h);
}
$('#cratio').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  $$('button', e.currentTarget).forEach(x => x.setAttribute('aria-pressed', x === b));
  setCrop(CR[b.textContent]);
});
setCrop(null);

// add background: swatches, sliders and ratio drive the preview (values from Backdrop.swift)
const GRAD = [['FF6B6B', 'FFA64D', 'FFD93D'], ['3A7BD5', '00D2FF'], ['43E97B', '38F9D7'], ['FF9A9E', 'FECFEF'], ['A18CD1', 'FBC2EB'], ['0F2027', '2C5364', '6DD5ED'], ['2193B0', '6DD5ED'], ['F093FB', 'F5576C'], ['4E54C8', '8F94FB']];
const SOLID = ['FFFFFF', 'F2C94C', 'A5CF4D', '4BA871', '2E9C93', '56C9DB', '3B6BD6', '233047', '7E57C2'];
const fills = [...GRAD.map(g => `linear-gradient(135deg,${g.map(c => '#' + c).join(',')})`), ...SOLID.map(c => '#' + c)];
const bgc = $('#bgc');
$('#sw').innerHTML = fills.map((f, i) => `<button aria-pressed="${i === 0}" aria-label="Backdrop ${i + 1}" style="background:${f}"></button>`).join('');
$('#sw').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  $$('button', e.currentTarget).forEach(x => x.setAttribute('aria-pressed', x === b));
  bgc.style.setProperty('--fill', b.style.background);
});
[['#rp', '--pad', .3], ['#rc', '--rad', .35], ['#rs', '--sh', .4]].forEach(([id, v, k]) => {
  const inp = $(id); inp.addEventListener('input', () => { bgc.style.setProperty(v, inp.value * k + 'px'); inp.nextElementSibling.textContent = inp.value + ' px'; });
});
$('#bratio').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  const all = $$('button', e.currentTarget);
  all.forEach(x => x.setAttribute('aria-pressed', x === b));
  bgc.className = 'bgcanvas' + (all.indexOf(b) ? ' r' + all.indexOf(b) : '');
});


// ---------- Settings window: same pages and rules as FlickWheel/App/SettingsView.swift ----------
const WK = {
  shift: { title: 'Shift', purpose: 'Convert', sym: 'shift', tc: 'var(--shift)', c: 'blue' },
  command: { title: 'Command', purpose: 'Tools', sym: 'command', tc: 'var(--command)', c: 'purple' },
  control: { title: 'Control', purpose: 'File', sym: 'control', tc: 'var(--control)', c: 'orange' },
};
const MAX = 8; // ActionRegistry.maxPerWheel
// FileKind.swift
const FK = [
  { id: 'image', short: 'Image', sym: 'photo' }, { id: 'video', short: 'Video', sym: 'film' }, { id: 'audio', short: 'Audio', sym: 'music.note' },
  { id: 'document', short: 'Docs', sym: 'doc.text' }, { id: 'code', short: 'Code', sym: 'chevron.left.forwardslash.chevron.right' }, { id: 'any', short: 'Any', sym: 'asterisk' },
];
const FEXT = {
  image: 'png jpg jpeg heic tiff bmp gif webp svg', video: 'mp4 mov m4v mkv webm avi flv wmv', audio: 'mp3 wav m4a flac ogg aiff',
  code: 'json js ts tsx jsx html css xml yml yaml app apk ipa',
};
function fileKinds(accepts) {
  if (accepts.includes('*')) return ['any'];
  const set = [...new Set(accepts.map(x => x.toLowerCase()))];
  if (!set.length) return [];
  const counts = {};
  set.forEach(e => { const k = Object.keys(FEXT).find(k => FEXT[k].split(' ').includes(e)) || 'document'; counts[k] = (counts[k] || 0) + 1; });
  const big = FK.map(k => k.id).filter(k => (counts[k] || 0) / set.length >= .25);
  return big.length ? big : FK.map(k => k.id).filter(k => counts[k]);
}
const SAMPLES = [['Image (png)', 'png'], ['Video (mp4)', 'mp4'], ['Audio (mp3)', 'mp3'], ['PDF', 'pdf'], ['Text (txt)', 'txt'], ['JSON', 'json']];

const S = { page: 'packs', hidden: new Set(), packs: new Set(['everyone']), search: '', filter: null, sample: 'png' };
const sbar = $('#sbar'), smain = $('#smain');
const reg = () => [...ACTIONS, ...PACKS.filter(p => S.packs.has(p.id)).flatMap(p => p.actions.filter(a => !ACTIONS.some(b => b.id === a.id)).map(a => ({ ...a, pack: p.title })))];
const on = a => !S.hidden.has(a.id);
// small glyphs are baked per colour by gen-data.py (a CSS mask would not load from file://)
const mi = (sym, color, w = 10, h = 9) => `<img class="mi" src="assets/sf/${sym}--${color}.png" alt="" width="${w}" height="${h}">`;
const tile = (cls, sym, tc) => `<span class="tile ${cls}" style="--tc:${tc}"><img src="${sf(sym)}" alt="" width="22" height="20"></span>`;
const kchip = k => { const f = FK.find(x => x.id === k); return `<span class="kc">${mi(f.sym, 'gray')}${f.short}</span>`; };
const obadge = a => `<span class="ob${a.pack ? ' pk' : ''}">${a.pack || 'Built in'}</span>`;

function drawSidebar() {
  const all = reg();
  if (!sbar.firstChild) {
    sbar.innerHTML = `<span class="cap2">WHEELS</span>` + Object.keys(WK).map(k => `<button class="srow" data-page="${k}">${tile('', WK[k].sym, WK[k].tc)}<span class="tx"><b>${WK[k].title}</b><small>${WK[k].purpose}</small></span><span class="n"></span></button>`).join('') +
      `<span class="cap2 lib">LIBRARY</span><button class="srow" data-page="packs">${tile('', 'shippingbox', 'var(--indigo)')}<span class="tx"><b>Packs</b><small>Extra actions</small></span><span class="n"></span></button>` +
      `<span class="sp"></span><span class="lnk">${mi('doc.badge.gearshape', 'link', 14, 13)}Open actions.json</span><span class="lnk">${mi('arrow.clockwise', 'link', 14, 13)}Reload actions</span>`;
  }
  $$('[data-page]', sbar).forEach(b => {
    const k = b.dataset.page, w = all.filter(a => a.wheel === k);
    $('.n', b).textContent = k === 'packs' ? `${S.packs.size}/${PACKS.length}` : `${w.filter(on).length}/${w.length}`;
    S.page === k ? b.setAttribute('aria-current', 'page') : b.removeAttribute('aria-current');
  });
}

function buildWheelPage(k) {
  const m = WK[k];
  smain.innerHTML = `<div class="wpage"><div class="wleft"><div class="ph">${tile('l', m.sym, m.tc)}<div><h3>${m.title} · ${m.purpose}</h3>` +
    `<p>Hold ${m.title} while dragging a file. A wheel shows the first ${MAX} actions that fit the file, in the order below.</p></div></div>` +
    `<div class="search">${mi('magnifyingglass', 'muted', 14, 13)}<input type="search" placeholder="Search actions" aria-label="Search actions" value="${S.search.replace(/"/g, '&quot;')}"><button hidden aria-label="Clear search">${mi('xmark.circle.fill', 'muted', 14, 13)}</button></div>` +
    `<div class="cnt"></div><div class="fchips" role="group" aria-label="File kind"></div><div class="alist"></div></div><aside class="prevp"></aside></div>`;
  const inp = $('input', smain), clr = $('.search button', smain);
  inp.addEventListener('input', () => { S.search = inp.value; updateWheelPage(k); });
  clr.addEventListener('click', () => { S.search = ''; inp.value = ''; updateWheelPage(k); inp.focus(); });
  $('.fchips', smain).innerHTML = `<button class="fchip" data-k="all">All</button>` + FK.map(f => `<button class="fchip" data-k="${f.id}">${mi(f.sym, 'light')}${f.short}</button>`).join('');
  $('.fchips', smain).addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; S.filter = S.filter === b.dataset.k || b.dataset.k === 'all' ? null : b.dataset.k; updateWheelPage(k); });
  $('.alist', smain).addEventListener('click', e => {
    const b = e.target.closest('[data-id]'); if (!b) return;
    S.hidden.has(b.dataset.id) ? S.hidden.delete(b.dataset.id) : S.hidden.add(b.dataset.id);
    const vis = !S.hidden.has(b.dataset.id); // patch the row in place so the switch can animate
    b.setAttribute('aria-checked', vis); b.title = vis ? 'Shown on the wheel' : 'Hidden from the wheel';
    b.closest('.arow').classList.toggle('off', !vis);
    refreshWheelMeta(k);
  });
  updateWheelPage(k, true);
}

function updateWheelPage(k, enter = false) {
  const all = reg().filter(a => a.wheel === k), q = S.search.toLowerCase();
  const shown = all.filter(a => (!S.filter || fileKinds(a.accepts).includes(S.filter)) &&
    (!q || [a.label, a.description || '', a.id, a.accepts.join(' ')].some(t => t.toLowerCase().includes(q))));
  $('.search button', smain).hidden = !S.search;
  $$('.fchip', smain).forEach(b => b.setAttribute('aria-pressed', b.dataset.k === 'all' ? !S.filter : S.filter === b.dataset.k));
  const list = $('.alist', smain);
  list.classList.toggle('enter', enter); // stagger only on page change, never while typing or toggling
  list.innerHTML = shown.length ? shown.map((a, i) => {
    const ks = fileKinds(a.accepts), vis = on(a);
    return `<div class="arow${vis ? '' : ' off'}" style="--tc:${WK[k].tc};--i:${Math.min(i, 10)}">${tile('m', ICONS[a.id] || FALLBACK[k], WK[k].tc)}<div class="tx"><div class="t1"><b>${a.label}</b>${obadge(a)}</div>` +
      `${a.description ? `<p class="ds">${a.description}</p>` : ''}<div class="t3">${ks.map(kchip).join('')}${ks.join() !== 'any' ? `<span class="ac">${a.accepts.join(' ')}</span>` : ''}</div></div>` +
      `<button class="sw2" role="switch" aria-checked="${vis}" aria-label="${a.label} on the wheel" data-id="${a.id}" title="${vis ? 'Shown on the wheel' : 'Hidden from the wheel'}"></button></div>`;
  }).join('') : `<div class="empty2">${all.length ? 'No actions match' : 'No actions on this wheel'}</div>`;
  refreshWheelMeta(k);
}

function refreshWheelMeta(k) {
  const all = reg().filter(a => a.wheel === k), shown = $$('.arow', smain).length;
  $('.cnt', smain).textContent = `${all.filter(on).length} of ${all.length} actions on` + (shown === all.length ? '' : ` · showing ${shown}`);
  drawPreview(k);
  drawSidebar();
}

function drawPreview(k) {
  const pane = $('.prevp', smain), all = reg().filter(a => a.wheel === k && on(a));
  const usable = all.filter(a => takes(a, S.sample) && !a.multi), shown = usable.slice(0, MAX), cut = usable.slice(MAX);
  const elsewhere = all.filter(a => !usable.includes(a)), title = SAMPLES.find(x => x[1] === S.sample)[0];
  pane.innerHTML = `<h4>Wheel preview</h4><select aria-label="Sample file">${SAMPLES.map(([t, e]) => `<option value="${e}"${e === S.sample ? ' selected' : ''}>${t}</option>`).join('')}</select>` +
    `<div class="pring">${shown.length ? '<svg class="wheel"></svg>' : `<div class="none"><img src="${sf('arrow.triangle.2.circlepath')}" alt="">Nothing on ${WK[k].title} for this file type</div>`}</div>` +
    `<div class="slots"><b>${shown.length} of ${MAX} slots used</b><span>${all.length} on = ${shown.length} on the wheel${cut.length ? ` + ${cut.length} cut` : ''} + ${elsewhere.length} for other file types</span></div>` +
    (cut.length ? `<div class="more"><div class="warn">⚠ ${cut.length} cut by the ${MAX}-slot limit</div><span>${cut.map(a => a.label).join(', ')}<br>Turn off an action to bring these in.</span></div>` : '') +
    (elsewhere.length ? `<div class="more"><b>Not for ${title}</b><span>${elsewhere.map(a => a.label).join(', ')}</span></div>` : '');
  $('select', pane).addEventListener('change', e => { S.sample = e.target.value; drawPreview(k); });
  const svg = $('svg', pane);
  if (svg) {
    const size = 2 * radii(shown.length).outer + 48, scale = .62;
    svg.setAttribute('viewBox', `${-size / 2} ${-size / 2} ${size} ${size}`);
    svg.setAttribute('width', size * scale); svg.setAttribute('height', size * scale);
    drawRing(svg, shown, 'glp', null, false);
  }
}

const packSum = () => {
  const sum = { shift: 0, command: 0, control: 0 };
  PACKS.filter(p => S.packs.has(p.id)).forEach(p => p.actions.forEach(a => sum[a.wheel]++));
  return `<span>Adds to your wheels</span>${Object.keys(sum).map(w => `<span class="pill" style="--tc:${WK[w].tc}">${mi(WK[w].sym, WK[w].c)}${WK[w].title} <b>+${sum[w]}</b></span>`).join('')}`;
};
function buildPacksPage() {
  smain.innerHTML = `<div class="ppage"><div class="ph">${tile('l', 'shippingbox', 'var(--indigo)')}<div class="grow"><h3>Packs</h3><p>A pack adds actions from its own file, so actions.json stays yours. If both define an id, actions.json wins.</p></div><span class="btn2">Open packs folder</span></div>` +
    `<div class="plist">${PACKS.map(p => { const e = S.packs.has(p.id); return `<div class="prow${e ? ' on' : ''}"><div class="tx"><div class="t1"><b>${p.title}</b><span class="ob">Built in</span></div><p class="ds">${p.description}</p>` +
      `<div class="pchips">${p.actions.map(a => `<span class="pc" style="--tc:${WK[a.wheel].tc}" title="${a.description || a.label}">${mi(WK[a.wheel].sym, WK[a.wheel].c)}${a.label}</span>`).join('')}</div></div>` +
      `<button class="sw2" role="switch" aria-checked="${e}" aria-label="${p.title} pack" data-p="${p.id}"></button></div>`; }).join('')}</div>` +
    `<div class="sum" aria-live="polite">${packSum()}</div></div>`;
  $('.plist', smain).addEventListener('click', e => {
    const b = e.target.closest('[data-p]'); if (!b) return;
    S.packs.has(b.dataset.p) ? S.packs.delete(b.dataset.p) : S.packs.add(b.dataset.p);
    const enabled = S.packs.has(b.dataset.p);
    b.setAttribute('aria-checked', enabled); b.closest('.prow').classList.toggle('on', enabled);
    $('.sum', smain).innerHTML = packSum();
    drawSidebar();
  });
  drawSidebar();
}

function go(p) { S.page = p; p === 'packs' ? buildPacksPage() : buildWheelPage(p); }
sbar.addEventListener('click', e => { const b = e.target.closest('[data-page]'); if (b) go(b.dataset.page); });
go('packs');
