import { useCurrentFrame } from "remotion";
import { t } from "./theme";

const COLORS = [
  "#0a84ff", "#3d7bff", "#7a63f0", "#a64dd6",
  "#d4609f", "#ff7f50", "#ff9f0a", "#ffb340",
];
const pt = (r: number, a: number) => [r * Math.cos(a), r * Math.sin(a)];
const seg = (a0: number, a1: number, r0: number, r1: number) => {
  const [x0, y0] = pt(r1, a0);
  const [x1, y1] = pt(r1, a1);
  const [x2, y2] = pt(r0, a1);
  const [x3, y3] = pt(r0, a0);
  return `M${x0} ${y0}A${r1} ${r1} 0 0 1 ${x1} ${y1}L${x2} ${y2}A${r0} ${r0} 0 0 0 ${x3} ${y3}Z`;
};

/** Eight-segment wheel mark. `active` lights one segment like a wheel selection. */
export const Logo: React.FC<{ size: number; start?: number; active?: number | null }> = ({
  size,
  start = 0,
  active = null,
}) => {
  const frame = useCurrentFrame();
  return (
    <svg width={size} height={size} viewBox="-110 -110 220 220">
      {COLORS.map((color, i) => {
        const p = t(frame, start + i * 2, 16);
        const mid = -Math.PI / 2 + (i + 0.5) * (Math.PI / 4);
        const hot = active === i;
        const push = (1 - p) * -26 + (hot ? 6 : 0);
        const [dx, dy] = pt(push, mid);
        return (
          <path
            key={i}
            d={seg(-Math.PI / 2 + i * (Math.PI / 4) + 0.045, -Math.PI / 2 + (i + 1) * (Math.PI / 4) - 0.045, 50, 100)}
            fill={color}
            opacity={p * (active === null || hot ? 1 : 0.5)}
            transform={`translate(${dx} ${dy})`}
          />
        );
      })}
    </svg>
  );
};
