import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from "remotion";
import { GlassWheel, PuckKey, WheelItem, segmentCenter } from "../GlassWheel";
import { C, fontFamily, t } from "../theme";

const PHASE = 80;
const FADE = 10;
const SCALE = 2.2;

const SHIFT: WheelItem[] = [
  { label: "JPG", icon: "photo", description: "Convert to JPG" },
  { label: "PNG", icon: "photo", description: "Convert to PNG" },
  { label: "WebP 80%", icon: "photo", description: "Convert to WebP (quality 80)" },
  { label: "HEIC", icon: "photo", description: "Convert to HEIC" },
  { label: "PDF", icon: "pdf", description: "Wrap the image in a PDF" },
  { label: "GIF", icon: "gif", description: "Make a GIF (15 fps, up to 720 px wide)" },
  { label: "MP3", icon: "music", description: "Extract or convert audio to MP3" },
  { label: "M4A", icon: "music", description: "Extract or convert audio to M4A" },
];
const COMMAND: WheelItem[] = [
  { label: "Annotate", icon: "annotate", description: "Draw arrows, text and marks on the image" },
  { label: "Crop", icon: "crop", description: "Crop an image or video" },
  { label: "Add BG", icon: "addbg", description: "Put the image on a gradient or solid backdrop" },
  { label: "Pixel Perfect", icon: "pixelperfect", description: "Overlay two images to compare them" },
  { label: "Redact", icon: "redact", description: "Hide parts of the image with solid blocks" },
  { label: "Edit", icon: "edit", description: "Open in Preview or QuickTime Player" },
  { label: "Compress", icon: "compress", description: "Make the file smaller (video or JPG)" },
  { label: "50%", icon: "resize", description: "Halve the width" },
];
const CONTROL: WheelItem[] = [
  { label: "AirDrop", icon: "airdrop", description: "Send with AirDrop" },
  { label: "Reveal", icon: "reveal", description: "Show in Finder" },
  { label: "Copy file", icon: "copyfile", description: "Copy the file to the clipboard" },
  { label: "Copy image", icon: "copyimage", description: "Copy the image to the clipboard" },
  { label: "Copy path", icon: "copypath", description: "Copy the full path" },
  { label: "Terminal", icon: "terminal", description: "Open Terminal here" },
  { label: "Zip", icon: "zip", description: "Make a zip next to the file" },
  { label: "SHA-256", icon: "checksum", description: "Copy the SHA-256 hash" },
];

// puck keyframes: centre, then through two segments, then onto the one it drops on
const route = (items: WheelItem[], idx: number[]): PuckKey[] => {
  const at = (i: number) => segmentCenter(i, items.length);
  const frames = [[16, 26], [30, 40], [44, 54]];
  return [
    { f: 8, x: 0, y: 0 },
    ...idx.flatMap((i, k) => [
      { f: frames[k][0], x: k === 0 ? 0 : at(idx[k - 1]).x, y: k === 0 ? 0 : at(idx[k - 1]).y },
      { f: frames[k][1], x: at(i).x, y: at(i).y },
    ]),
  ];
};

const PHASES = [
  { key: "shift", sym: "⇧", label: "shift", color: C.shift, title: "Convert.", items: SHIFT, idx: [0, 1, 2],
    line: "Images, PDFs, GIFs and audio. One drop.", result: "photo.webp" },
  { key: "command", sym: "⌘", label: "command", color: C.command, title: "Annotate.", items: COMMAND, idx: [0, 1, 3],
    line: "Crop, mark up, compare pixels, redact.", result: "Pixel Perfect" },
  { key: "control", sym: "⌃", label: "control", color: C.control, title: "Share.", items: CONTROL, idx: [4, 6, 0],
    line: "AirDrop, zip, copy, hash. One drop.", result: "AirDrop" },
] as const;

const KeyCap: React.FC<{ sym: string; label: string; color: string }> = ({ sym, label, color }) => {
  const frame = useCurrentFrame();
  const down = interpolate(frame, [3, 6, 14, 18], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div
      style={{
        width: 210, height: 130, borderRadius: 30,
        background: `linear-gradient(180deg, ${color}33, ${color}18)`,
        border: `2px solid ${color}88`,
        boxShadow: `0 ${10 - 8 * down}px 0 ${color}55, 0 0 ${50 * down}px ${color}88`,
        translate: `0 ${8 * down}px`,
        display: "flex", flexDirection: "column", justifyContent: "space-between",
        padding: "14px 22px", color: C.fg,
      }}
    >
      <div style={{ fontSize: 56, fontWeight: 600, lineHeight: 1 }}>{sym}</div>
      <div style={{ fontSize: 30, fontWeight: 600, color: C.mute }}>{label}</div>
    </div>
  );
};

const Phase: React.FC<{ index: number; last: boolean; len: number }> = ({ index, last, len }) => {
  const p = PHASES[index];
  const frame = useCurrentFrame();
  const inP = t(frame, 0, FADE + 6);
  const out = last ? 0 : interpolate(frame, [len - FADE, len], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const push = interpolate(frame, [0, PHASE], [1, 1.035], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ fontFamily, opacity: 1 - out }}>
      <div
        style={{
          position: "absolute", right: -40, top: 40, width: 1150, height: 1000,
          backgroundImage: `radial-gradient(closest-side, ${p.color}55, transparent)`, opacity: inP,
        }}
      />
      <div style={{ position: "absolute", left: 150, top: 0, bottom: 0, width: 820, display: "flex", flexDirection: "column", justifyContent: "center", gap: 28 }}>
        <div style={{ opacity: inP, translate: `0 ${(1 - inP) * 24}px` }}>
          <KeyCap sym={p.sym} label={p.label} color={p.color} />
        </div>
        <div style={{ overflow: "hidden", lineHeight: 1.05, padding: "0 0 10px" }}>
          <div
            style={{
              fontSize: 164, fontWeight: 800, letterSpacing: "-0.045em", color: C.fg,
              translate: `0 ${(1 - t(frame, 6, 18)) * 100}%`, opacity: t(frame, 6, 14),
            }}
          >
            {p.title}
          </div>
        </div>
        <div style={{ fontSize: 54, fontWeight: 500, color: C.mute, lineHeight: 1.25, maxWidth: 760, opacity: t(frame, 14, 18), translate: `0 ${(1 - t(frame, 14, 18)) * 18}px` }}>
          {p.line}
        </div>
      </div>
      <div style={{ position: "absolute", right: 120, top: 0, bottom: 0, width: 830, display: "flex", alignItems: "center", justifyContent: "center", scale: push }}>
        <GlassWheel items={[...p.items]} path={route(p.items, [...p.idx])} dropFrame={58} result={p.result} scale={SCALE} />
      </div>
      <div style={{ position: "absolute", left: 150, bottom: 100, display: "flex", gap: 12 }}>
        {PHASES.map((q, i) => (
          <div key={q.key} style={{ width: i === index ? 64 : 20, height: 10, borderRadius: 5, background: i === index ? q.color : "rgba(255,255,255,.2)" }} />
        ))}
      </div>
    </AbsoluteFill>
  );
};

export const Wheels: React.FC = () => (
  <AbsoluteFill>
    {PHASES.map((p, i) => {
      const last = i === PHASES.length - 1;
      const len = last ? PHASE : PHASE + FADE;
      return (
        <Sequence key={p.key} from={i * PHASE} durationInFrames={len} layout="absolute-fill" name={p.key}>
          <Phase index={i} last={last} len={len} />
        </Sequence>
      );
    })}
  </AbsoluteFill>
);
