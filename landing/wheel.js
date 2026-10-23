// Demo for the landing page. ACTIONS comes from actions-data.js, generated from the app's default manifest.
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

let key = 'shift';
let file = 'photo.png';
const ext = f => f.split('.').pop().toLowerCase();
const stem = f => f.slice(0, f.lastIndexOf('.'));

// hero: real screenshots per wheel
function setHero(k) {
  $$('.keys button').forEach(b => b.setAttribute('aria-selected', b.dataset.wheel === k));
  $('#heroImg').src = `assets/wheel-${k}.webp`;
  $('#heroImg').alt = `The FlickWheel ${k[0].toUpperCase() + k.slice(1)} wheel captured from the app.`;
}
$$('.keys button').forEach(b => b.addEventListener('click', () => { setHero(b.dataset.wheel); setKey(b.dataset.wheel); }));

// demo ring: same geometry rules as the app (start angle, equal segments, constant seam)
const NS = 'http://www.w3.org/2000/svg';
const C = 200, R_IN = 80, R_OUT = 185, SEAM = 4;
const pt = (r, deg) => [C + r * Math.cos(deg * Math.PI / 180), C + r * Math.sin(deg * Math.PI / 180)].map(n => n.toFixed(2));
function segPath(i, n) {
  const step = 360 / n, origin = -90 + (n % 4 === 0 ? 0 : -180 / n);
  const inset = r => n > 1 ? Math.asin(SEAM / 2 / r) * 180 / Math.PI : 0;
  const a = origin + i * step, b = a + step;
  const [o1, o2, i1, i2] = [pt(R_OUT, a + inset(R_OUT)), pt(R_OUT, b - inset(R_OUT)), pt(R_IN, b - inset(R_IN)), pt(R_IN, a + inset(R_IN))];
  const big = step > 180 ? 1 : 0;
  return `M${o1}A${R_OUT} ${R_OUT} 0 ${big} 1 ${o2}L${i1}A${R_IN} ${R_IN} 0 ${big} 0 ${i2}Z`;
}
function labelPos(i, n) {
  const step = 360 / n, origin = -90 + (n % 4 === 0 ? 0 : -180 / n);
  return pt((R_IN + R_OUT) / 2, origin + (i + .5) * step);
}

function visible() {
  const e = ext(file);
  return ACTIONS.filter(a => a.wheel === key && a.accepts.some(x => x === '*' || x === e)).slice(0, 8);
}

function render() {
  const acts = visible(), svg = $('#wheel');
  svg.replaceChildren();
  $('#empty').hidden = acts.length > 0;
  acts.forEach((a, i) => {
    const g = document.createElementNS(NS, 'g');
    g.setAttribute('class', 's'); g.setAttribute('tabindex', '0'); g.setAttribute('role', 'button');
    g.setAttribute('aria-label', `${a.label} on ${file}`);
    g.dataset.id = a.id;
    const p = document.createElementNS(NS, 'path'); p.setAttribute('d', segPath(i, acts.length));
    const t = document.createElementNS(NS, 'text'); const [x, y] = labelPos(i, acts.length);
    t.setAttribute('x', x); t.setAttribute('y', +y + 4); t.textContent = a.label;
    g.append(p, t);
    g.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); run(a); } });
    svg.append(g);
  });
}

function run(a) {
  const e = ext(file);
  const out = a.out ? stem(file) + a.out.replace('${INPUT##*.}', e) : null;
  $('#toast').textContent = out ? `✓ ${a.label}: ${file} → ${out}` : `✓ ${a.label}: ${file}`;
  resetChip();
}

function setKey(k) {
  key = k;
  $$('[data-key]').forEach(b => b.setAttribute('aria-pressed', b.dataset.key === k));
  $('#toast').textContent = '';
  render();
}
function setFile(f) {
  file = f;
  $$('[data-file]').forEach(b => b.setAttribute('aria-pressed', b.dataset.file === f));
  $('#chip').textContent = f;
  $('#toast').textContent = '';
  render();
}
$$('[data-key]').forEach(b => b.addEventListener('click', () => setKey(b.dataset.key)));
$$('[data-file]').forEach(b => b.addEventListener('click', () => setFile(b.dataset.file)));
addEventListener('keydown', e => {
  if (e.metaKey || e.ctrlKey || e.altKey || /input|textarea/i.test(e.target.tagName)) return;
  const k = { s: 'shift', c: 'command', k: 'control' }[e.key.toLowerCase()];
  if (k) { setKey(k); setHero(k); }
});

// chip drag with pointer events (works for mouse, touch and pen)
const chip = $('#chip'), stage = $('.stage');
function resetChip() { chip.classList.remove('drag'); chip.style.left = chip.style.top = '50%'; $$('.s.over').forEach(s => s.classList.remove('over')); }
function segAt(x, y) { return document.elementFromPoint(x, y)?.closest('.s'); }
chip.addEventListener('pointerdown', e => { chip.setPointerCapture(e.pointerId); chip.classList.add('drag'); $('#toast').textContent = ''; });
chip.addEventListener('pointermove', e => {
  if (!chip.classList.contains('drag')) return;
  const r = stage.getBoundingClientRect();
  chip.style.left = e.clientX - r.left + 'px'; chip.style.top = e.clientY - r.top + 'px';
  chip.style.pointerEvents = 'none';
  const s = segAt(e.clientX, e.clientY); chip.style.pointerEvents = '';
  $$('.s.over').forEach(x => x.classList.remove('over')); s?.classList.add('over');
});
chip.addEventListener('pointerup', e => {
  if (!chip.classList.contains('drag')) return;
  chip.style.pointerEvents = 'none';
  const s = segAt(e.clientX, e.clientY); chip.style.pointerEvents = '';
  const a = s && ACTIONS.find(x => x.id === s.dataset.id);
  if (a) run(a); else { resetChip(); $('#toast').textContent = 'Dropped outside a segment: nothing runs.'; }
});
chip.addEventListener('pointercancel', resetChip);

// copy button
$('#copy').addEventListener('click', async e => {
  try { await navigator.clipboard.writeText($('#snippet').textContent); e.target.textContent = 'Copied'; }
  catch { e.target.textContent = 'Press ⌘C'; }
  setTimeout(() => (e.target.textContent = 'Copy'), 1500);
});

render();
