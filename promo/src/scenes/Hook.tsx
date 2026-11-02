import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C, ease, fontFamily, t } from "../theme";

const WORDS: [string, string][] = [
  ["Convert.", C.shift],
  ["Compress.", C.command],
  ["Annotate.", C.control],
  ["Share.", C.fg],
];

export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{ fontFamily, alignItems: "center", justifyContent: "center", gap: 18 }}
    >
      <div
        style={{
          fontSize: 34,
          fontWeight: 600,
          letterSpacing: "0.22em",
          color: C.mute,
          opacity: t(frame, 0, 14),
          marginBottom: 14,
        }}
      >
        EVERY FILE, EVERY DAY
      </div>
      {WORDS.map(([w, color], i) => {
        const p = t(frame, 4 + i * 7, 16);
        return (
          <div key={w} style={{ overflow: "hidden", padding: "0 40px", lineHeight: 1.04 }}>
            <div
              style={{
                fontSize: 150,
                fontWeight: 800,
                letterSpacing: "-0.04em",
                color,
                translate: `0 ${(1 - p) * 110}%`,
                opacity: p,
              }}
            >
              {w}
            </div>
          </div>
        );
      })}
      <div
        style={{
          fontSize: 56,
          fontWeight: 500,
          color: C.mute,
          marginTop: 22,
          opacity: interpolate(frame, [34, 48], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: ease,
          }),
        }}
      >
        There's a faster way.
      </div>
    </AbsoluteFill>
  );
};
