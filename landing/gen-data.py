#!/usr/bin/env python3
"""Regenerates landing/actions-data.js, packs-data.js and assets/sf/*.png from the app sources.
Run from anywhere: python3 landing/gen-data.py (needs `swift` for the icons; skips them if missing)."""
import json, os, re, subprocess, sys, tempfile

here = os.path.dirname(os.path.abspath(__file__))
app = os.path.join(here, '..', 'FlickWheel')
read = lambda p: open(os.path.join(app, p), encoding='utf-8').read()

# 1. built-in manifest, straight from ActionRegistry.defaultManifest
src = read('Actions/ActionRegistry.swift')
manifest = json.loads(re.search(r'defaultManifest = #"""\n(.*?)\n\s*"""#', src, re.S).group(1))
# file name the demo toast shows after a drop (the app decides this inside each command)
OUT = {'img-jpg': '.jpg', 'img-png': '.png', 'img-webp': '.webp', 'img-heic': '.heic', 'img-pdf': '.pdf', 'vid-gif': '.gif',
       'to-mp3': '.mp3', 'resize': '-50.${INPUT##*.}', 'zip': '.zip'}
keep = lambda a: {'id': a['id'], 'label': a['label'], 'wheel': a['wheel'], 'accepts': a['accepts'], 'description': a.get('description', ''),
                  **({'multi': True} if a.get('multi') else {}), 'out': OUT.get(a['id'])}
actions = [keep(a) for a in manifest]

# 2. packs
packs = []
for pid in ['everyone', 'dev', 'qc', 'video']:
    d = json.load(open(os.path.join(app, 'Resources/Packs', pid + '.json'), encoding='utf-8'))
    packs.append({'id': pid, 'title': d['title'], 'description': d['description'], 'actions': [keep(a) for a in d['actions']]})

# 3. SF Symbols the app uses (ActionIcon.swift), rendered white on transparent like the promo icons
icon_src = read('App/ActionIcon.swift')
by_id = {m.group(1): re.findall(r'"([^"]+)"', m.group(2)) for m in re.finditer(r'"([a-z0-9-]+)": \[((?:"[^"]+",? ?)+)\]', icon_src)}
ui = ['shift', 'command', 'control', 'shippingbox', 'magnifyingglass', 'doc.badge.gearshape', 'arrow.clockwise', 'photo', 'film', 'music.note', 'doc.text',
      'chevron.left.forwardslash.chevron.right', 'asterisk', 'arrow.triangle.2.circlepath', 'wand.and.stars', 'square.and.arrow.up', 'xmark.circle.fill']
symbols = sorted({s for v in by_id.values() for s in v} | set(ui))
out_dir = os.path.join(here, 'assets', 'sf'); os.makedirs(out_dir, exist_ok=True)
# tinted copies for the small glyphs in chips and links (CSS masks do not load from file://, so they are baked into PNGs)
COL = {'blue': (10, 132, 255), 'purple': (166, 77, 214), 'orange': (255, 159, 10), 'gray': (174, 174, 184), 'light': (238, 238, 238),
       'link': (77, 163, 255), 'muted': (138, 138, 148)}
tints = [(s, c) for s, c in [('shift', 'blue'), ('command', 'purple'), ('control', 'orange')]]
tints += [(s, 'gray') for s in ('photo', 'film', 'music.note', 'doc.text', 'chevron.left.forwardslash.chevron.right', 'asterisk')]
tints += [(s, 'light') for s in ('photo', 'film', 'music.note', 'doc.text', 'chevron.left.forwardslash.chevron.right', 'asterisk')]
tints += [('doc.badge.gearshape', 'link'), ('arrow.clockwise', 'link'), ('magnifyingglass', 'muted'), ('xmark.circle.fill', 'muted')]
jobs = [{'n': s, 'o': s + '.png', 'c': [1, 1, 1]} for s in symbols] + [{'n': s, 'o': f'{s}--{c}.png', 'c': [v / 255 for v in COL[c]]} for s, c in tints]
swift = '''import AppKit
struct Job: Codable { let n: String; let o: String; let c: [Double] }
let jobs = try! JSONDecoder().decode([Job].self, from: FileHandle.standardInput.readDataToEndOfFile())
let dir = CommandLine.arguments[1]
var ok: [String] = []
for j in jobs {
  guard let sym = NSImage(systemSymbolName: j.n, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 64, weight: .regular)) else { continue }
  let W = 160, H = 144
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let s = sym.size
  let color = NSColor(srgbRed: j.c[0], green: j.c[1], blue: j.c[2], alpha: 1)
  let tinted = NSImage(size: s, flipped: false) { r in sym.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true }
  let k = min(Double(W) * 0.8 / Double(s.width), Double(H) * 0.8 / Double(s.height))
  let w = Double(s.width) * k, h = Double(s.height) * k
  tinted.draw(in: NSRect(x: (Double(W) - w) / 2, y: (Double(H) - h) / 2, width: w, height: h))
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: dir + "/" + j.o))
  if !j.o.contains("--") { ok.append(j.n) }
}
print(String(data: try! JSONEncoder().encode(ok), encoding: .utf8)!)
'''
existing = set()
try:
    with tempfile.NamedTemporaryFile('w', suffix='.swift', delete=False) as f: f.write(swift)
    r = subprocess.run(['swift', f.name, out_dir], input=json.dumps(jobs), capture_output=True, text=True, check=True)
    existing = set(json.loads(r.stdout.strip().splitlines()[-1]))
except Exception as e:
    print('icons skipped:', e, file=sys.stderr)
    existing = {os.path.splitext(n)[0] for n in os.listdir(out_dir) if '--' not in n}
icons = {i: next((s for s in c if s in existing), None) for i, c in by_id.items()}
icons = {i: s for i, s in icons.items() if s}

js = lambda name, v: f'const {name} = {json.dumps(v, separators=(",", ":"))};\n'
open(os.path.join(here, 'actions-data.js'), 'w').write('// generated by gen-data.py from ActionRegistry.defaultManifest and App/ActionIcon.swift\n' + js('ACTIONS', actions) + js('ICONS', icons))
open(os.path.join(here, 'packs-data.js'), 'w').write('// generated by gen-data.py from FlickWheel/Resources/Packs/*.json\n' + js('PACKS', packs))
print(len(actions), 'actions,', sum(len(p['actions']) for p in packs), 'pack actions,', len(existing), 'symbols')
