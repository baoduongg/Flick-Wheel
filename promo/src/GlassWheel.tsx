import { Easing, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "./theme";

// Geometry mirrors FlickWheel/Wheel/RadialWheelView.swift (points; scaled by the `scale` prop).
const RING = 90;
const SEAM = 4;
const CORNER = 9;
const ACCENT = "10,132,255";

export type WheelItem = { label: string; icon: string; description: string };
export type PuckKey = { f: number; x: number; y: number };

const radii = (n: number) => {
  const mid = Math.max(110, (n * 92) / (2 * Math.PI));
  return { inner: mid - RING / 2, outer: mid + RING / 2, mid };
};
export const wheelSize = (n: number) => 2 * radii(n).outer + 48;
const startDeg = (n: number) => (n % 4 === 0 ? 0 : -180 / n);
const rad = (d: number) => (d * Math.PI) / 180;

/** Centre of segment i, relative to the wheel centre (y down). */
export const segmentCenter = (i: number, n: number) => {
  const theta = rad(startDeg(n) + (i + 0.5) * (360 / n));
  const { mid } = radii(n);
  return { x: mid * Math.sin(theta), y: -mid * Math.cos(theta), theta };
};

const segPath = (i: number, n: number) => {
  const step = 360 / n;
  const origin = -90 + startDeg(n);
  const r = radii(n);
  const inner = r.inner + CORNER;
  const outer = r.outer - CORNER;
  const inset = (radius: number) => (Math.asin((SEAM / 2 + CORNER) / radius) * 180) / Math.PI;
  const from = origin + i * step;
  const to = origin + (i + 1) * step;
  const a1 = from + inset(outer), a2 = to - inset(outer);
  const a3 = to - inset(inner), a4 = from + inset(inner);
  const pt = (rr: number, d: number): [number, number] => [rr * Math.cos(rad(d)), rr * Math.sin(rad(d))];
  const arc = (c: [number, number], rr: number, d0: number, d1: number) => {
    // like Path.addArc: a straight line joins the previous point to the arc start
    const [bx, by] = pt(rr, d0);
    const [ex, ey] = pt(rr, d1);
    return `L${c[0] + bx} ${c[1] + by}A${rr} ${rr} 0 0 ${d1 > d0 ? 1 : 0} ${c[0] + ex} ${c[1] + ey}`;
  };
  const o: [number, number] = [0, 0];
  const [sx, sy] = pt(outer + CORNER, a1);
  return [
    `M${sx} ${sy}`,
    arc(o, outer + CORNER, a1, a2),
    arc(pt(outer, a2), CORNER, a2, to + 90),
    arc(pt(inner, a3), CORNER, to + 90, a3 + 180),
    arc(o, inner - CORNER, a3, a4),
    arc(pt(inner, a4), CORNER, a4 + 180, from + 270),
    arc(pt(outer, a1), CORNER, from - 90, a1),
    "Z",
  ].join("");
};

const hoverIndex = (x: number, y: number, n: number) => {
  const r = radii(n);
  const d = Math.hypot(x, y);
  if (d < r.inner || d > r.outer) return -1;
  const ang = (Math.atan2(x, -y) * 180) / Math.PI - startDeg(n);
  return Math.floor((((ang % 360) + 360) % 360) / (360 / n));
};

const puckAt = (frame: number, keys: PuckKey[]) => {
  const fs = keys.map((k) => k.f);
  const opts = { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) } as const;
  return {
    x: interpolate(frame, fs, keys.map((k) => k.x), opts),
    y: interpolate(frame, fs, keys.map((k) => k.y), opts),
  };
};

export const GlassWheel: React.FC<{
  items: WheelItem[];
  path: PuckKey[];
  dropFrame: number;
  result: string;
  scale: number;
}> = ({ items, path, dropFrame, result, scale }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const n = items.length;
  const size = wheelSize(n);
  const SPRING = { damping: 9, stiffness: 210, mass: 0.55 };

  // hovered segment per frame, derived from the puck position like the real app
  const hoverAt = (f: number) => {
    if (f >= dropFrame) return hoverIndex(path[path.length - 1].x, path[path.length - 1].y, n);
    const p = puckAt(f, path);
    return hoverIndex(p.x, p.y, n);
  };
  // hover progress = sum of signed spring step responses at each hover change
  const hoverProgress = (i: number) => {
    let h = 0;
    let prev = false;
    for (let f = 0; f <= frame; f++) {
      const cur = hoverAt(f) === i;
      if (cur !== prev) {
        h += (cur ? 1 : -1) * spring({ frame: frame - f, fps, config: SPRING });
        prev = cur;
      }
    }
    return h;
  };

  const puck = puckAt(frame, path);
  const dropT = interpolate(frame, [dropFrame, dropFrame + 9], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const puckIn = spring({ frame: frame - 4, fps, config: { damping: 12, stiffness: 180 } });
  const cur = hoverAt(frame);
  const pulse = interpolate(frame, [dropFrame, dropFrame + 14], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const resultT = interpolate(frame, [dropFrame + 3, dropFrame + 13], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const descT = frame < dropFrame ? 1 : 0;

  return (
    <svg width={size * scale} height={size * scale} viewBox={`${-size / 2} ${-size / 2} ${size} ${size}`} style={{ overflow: "visible", fontFamily }}>
      <defs>
        <linearGradient id="gl" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.12" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
      </defs>
      {items.map((it, i) => {
        const hv = hoverProgress(i);
        const hc = Math.min(1, Math.max(0, hv));
        const c = segmentCenter(i, n);
        const enter = spring({ frame: frame - 6 - i * 1.2, fps, config: { damping: 13, stiffness: 150 } });
        const s = 1 + 0.1 * hv;
        const dx = 6 * hv * Math.sin(c.theta);
        const dy = -6 * hv * Math.cos(c.theta);
        const flash = i === cur && frame >= dropFrame ? pulse * 0.55 : 0;
        const d = segPath(i, n);
        return (
          <g key={it.label} opacity={Math.min(1, enter * 1.6)} transform={`scale(${0.6 + 0.4 * enter})`}>
            <g
              transform={`translate(${dx} ${dy}) translate(${c.x} ${c.y}) scale(${s}) translate(${-c.x} ${-c.y})`}
              style={{ filter: `drop-shadow(0 ${3 + 2 * hc}px ${8 + 4 * hc}px rgba(0,0,0,${0.22 + 0.14 * hc}))` }}
            >
              <path d={d} fill="rgba(40,43,68,0.64)" />
              <path d={d} fill="url(#gl)" />
              <path d={d} fill={`rgba(${ACCENT},${0.92 * hc})`} />
              <path d={d} fill={`rgba(255,255,255,${flash})`} />
              <path d={d} fill="none" stroke={`rgba(255,255,255,${0.16 + 0.19 * hc})`} strokeWidth={0.5} />
              <image
                href={staticFile(`icons/${it.icon}.png`)}
                x={c.x - 14}
                y={c.y - 19.5}
                width={28}
                height={22}
                preserveAspectRatio="xMidYMid meet"
              />
              <text
                x={c.x}
                y={c.y + 16}
                textAnchor="middle"
                fontSize={11}
                fontWeight={500}
                fill="#fff"
              >
                {it.label}
              </text>
            </g>
          </g>
        );
      })}
      {/* centre: description of the hovered action, then the result */}
      <foreignObject x={-60} y={-30} width={120} height={60} style={{ overflow: "visible" }}>
        <div
          style={{
            width: 120, height: 60, display: "flex", alignItems: "center", justifyContent: "center",
            textAlign: "center", color: "rgba(255,255,255,.85)", fontSize: 10.5, lineHeight: 1.25,
            opacity: cur >= 0 ? descT * Math.min(1, puckIn) : 0,
          }}
        >
          {cur >= 0 ? items[cur].description : ""}
        </div>
      </foreignObject>
      <g opacity={resultT} transform={`scale(${0.85 + 0.15 * resultT})`}>
        <image href={staticFile("icons/check.png")} x={-13} y={-30} width={26} height={26} />
        <text x={0} y={16} textAnchor="middle" fontSize={11.5} fontWeight={600} fill="#fff">{result}</text>
      </g>
      {/* drag puck, stands in for Finder's drag image */}
      <image
        href={staticFile("icons/file.png")}
        x={-22}
        y={-22}
        width={44}
        height={44}
        opacity={Math.min(1, puckIn) * (1 - dropT)}
        transform={`translate(${puck.x} ${puck.y}) scale(${(0.6 + 0.4 * Math.min(1, puckIn)) * (1 - 0.55 * dropT)})`}
        style={{ filter: "drop-shadow(0 3px 6px rgba(0,0,0,.35))" }}
      />
    </svg>
  );
};
