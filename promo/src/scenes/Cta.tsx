import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Logo } from "../Logo";
import { C, fontFamily, t } from "../theme";

export const Cta: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ fontFamily, alignItems: "center", justifyContent: "center", gap: 30 }}>
      <div style={{ scale: 0.9 + 0.1 * t(frame, 0, 26) }}>
        <Logo size={280} start={0} />
      </div>
      <div
        style={{
          fontSize: 190,
          fontWeight: 800,
          letterSpacing: "-0.045em",
          lineHeight: 1,
          color: C.fg,
          opacity: t(frame, 12, 18),
          translate: `0 ${(1 - t(frame, 12, 18)) * 40}px`,
        }}
      >
        FlickWheel
      </div>
      <div
        style={{
          fontSize: 64,
          fontWeight: 700,
          backgroundImage: `linear-gradient(100deg, ${C.shift}, ${C.command} 55%, ${C.control})`,
          WebkitBackgroundClip: "text",
          color: "transparent",
          opacity: t(frame, 22, 18),
        }}
      >
        Drag. Flick. Done.
      </div>
      <div style={{ display: "flex", gap: 24, marginTop: 24, opacity: t(frame, 32, 18), translate: `0 ${(1 - t(frame, 32, 18)) * 24}px` }}>
        <div style={{ fontSize: 46, fontWeight: 700, color: "#fff", background: C.shift, padding: "20px 48px", borderRadius: 999 }}>
          View on GitHub
        </div>
        <div style={{ fontSize: 46, fontWeight: 600, color: C.fg, padding: "20px 48px", borderRadius: 999, background: "rgba(255,255,255,.08)", border: "1.5px solid rgba(255,255,255,.18)" }}>
          Free · macOS 13+ · Apple silicon
        </div>
      </div>
    </AbsoluteFill>
  );
};
