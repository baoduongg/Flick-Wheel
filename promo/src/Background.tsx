import { AbsoluteFill, useCurrentFrame } from "remotion";
import { C } from "./theme";

const glow = (x: number, y: number, r: number, color: string, a: string) =>
  `radial-gradient(circle ${r}px at ${x}% ${y}%, ${color}${a}, transparent 70%)`;

export const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const s = (n: number, k: number) => Math.sin(frame / k) * n;
  return (
    <AbsoluteFill
      style={{
        backgroundColor: C.bg,
        backgroundImage: [
          glow(18 + s(4, 70), 22 + s(5, 90), 820, C.shift, "38"),
          glow(82 + s(4, 80), 78 + s(4, 60), 900, C.command, "30"),
          glow(88 + s(3, 50), 14 + s(3, 75), 520, C.control, "1c"),
        ].join(","),
      }}
    >
      <AbsoluteFill
        style={{
          backgroundImage:
            "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,.55) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
