import { AbsoluteFill, useCurrentFrame } from "remotion";
import { C, fontFamily, t } from "../theme";

const STATS = [
  { n: 3, pre: "", label: "wheels", color: C.shift },
  { n: 24, pre: "", label: "actions", color: C.command },
  { n: 0, pre: "$", label: "to use", color: C.control },
];

export const Stats: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ fontFamily, alignItems: "center", justifyContent: "center", gap: 90 }}>
      <div style={{ display: "flex", gap: 20 }}>
        {STATS.map((s, i) => {
          const p = t(frame, 2 + i * 6, 18);
          const count = Math.round(s.n * t(frame, 2 + i * 6, 18));
          return (
            <div key={s.label} style={{ width: 480, textAlign: "center", opacity: p, translate: `0 ${(1 - p) * 50}px` }}>
              <div
                style={{
                  fontSize: 300,
                  fontWeight: 800,
                  letterSpacing: "-0.05em",
                  lineHeight: 1,
                  color: C.fg,
                  textShadow: `0 0 90px ${s.color}88`,
                }}
              >
                {s.pre}
                {count}
              </div>
              <div style={{ fontSize: 64, fontWeight: 600, color: s.color, marginTop: 10 }}>{s.label}</div>
            </div>
          );
        })}
      </div>
      <div style={{ display: "flex", gap: 22, opacity: t(frame, 24, 16) }}>
        {["Annotate", "Crop", "Add BG", "Video trim"].map((x) => (
          <div
            key={x}
            style={{
              fontSize: 46,
              fontWeight: 600,
              color: C.fg,
              padding: "14px 34px",
              borderRadius: 999,
              background: "rgba(255,255,255,.07)",
              border: "1.5px solid rgba(255,255,255,.16)",
            }}
          >
            {x}
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
