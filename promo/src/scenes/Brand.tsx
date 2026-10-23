import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Logo } from "../Logo";
import { C, fontFamily, t } from "../theme";

const WORDS = ["Drag.", "Flick.", "Done."];

export const Brand: React.FC = () => {
  const frame = useCurrentFrame();
  const sweep = Math.min(7, Math.max(0, Math.floor((frame - 16) / 4)));
  return (
    <AbsoluteFill
      style={{ fontFamily, alignItems: "center", justifyContent: "center", gap: 34 }}
    >
      <div style={{ scale: 0.92 + 0.08 * t(frame, 0, 24) }}>
        <Logo size={250} start={0} active={frame < 16 || frame >= 48 ? null : sweep} />
      </div>
      <div style={{ display: "flex", gap: 44 }}>
        {WORDS.map((w, i) => {
          const p = t(frame, 14 + i * 9, 18);
          return (
            <div key={w} style={{ overflow: "hidden", padding: "0 6px", lineHeight: 1.1 }}>
              <div
                style={{
                  fontSize: 190,
                  fontWeight: 800,
                  letterSpacing: "-0.045em",
                  translate: `0 ${(1 - p) * 105}%`,
                  opacity: p,
                  ...(i === 1
                    ? {
                        backgroundImage: `linear-gradient(100deg, ${C.shift}, ${C.command} 55%, ${C.control})`,
                        WebkitBackgroundClip: "text",
                        color: "transparent",
                      }
                    : { color: C.fg }),
                }}
              >
                {w}
              </div>
            </div>
          );
        })}
      </div>
      <div style={{ fontSize: 56, fontWeight: 500, color: C.mute, opacity: t(frame, 44, 18) }}>
        A radial wheel for every file on your Mac.
      </div>
    </AbsoluteFill>
  );
};
