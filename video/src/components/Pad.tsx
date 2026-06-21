import React from "react";
import { C } from "../theme";

export type GestureKind = "tap" | "swipe" | "pinch" | "rotate";
export type Dir = "up" | "down" | "left" | "right";

const W = 480;
const H = 320;

function grid() {
  const lines: React.ReactNode[] = [];
  for (let x = 20; x < W; x += 20)
    lines.push(<line key={"x" + x} x1={x} y1={0} x2={x} y2={H} stroke={C.gridLine} strokeWidth={1} />);
  for (let y = 20; y < H; y += 20)
    lines.push(<line key={"y" + y} x1={0} y1={y} x2={W} y2={y} stroke={C.gridLine} strokeWidth={1} />);
  return lines;
}

/**
 * Animated trackpad surface. `progress` (0..1) drives the gesture motion, so the
 * caller maps its local frame onto it.
 */
export const Pad: React.FC<{
  kind: GestureKind;
  fingers: number;
  progress: number;
  dir?: Dir;
}> = ({ kind, fingers, progress, dir = "left" }) => {
  const cx = W / 2;
  const cy = H / 2;
  const points: { x: number; y: number }[] = [];
  let trace: { x: number; y: number }[] = [];

  if (kind === "tap") {
    const spread = 40;
    const off = (fingers - 1) / 2;
    for (let i = 0; i < fingers; i++) points.push({ x: cx + (i - off) * spread, y: cy });
  } else if (kind === "swipe") {
    const dist = 150;
    const vx = dir === "left" ? -1 : dir === "right" ? 1 : 0;
    const vy = dir === "up" ? -1 : dir === "down" ? 1 : 0;
    const spread = 36;
    const off = (fingers - 1) / 2;
    const sx = cx - (vx * dist) / 2;
    const sy = cy - (vy * dist) / 2;
    const px = sx + vx * dist * progress;
    const py = sy + vy * dist * progress;
    const perpx = vy;
    const perpy = vx;
    for (let i = 0; i < fingers; i++)
      points.push({ x: px + (i - off) * spread * perpx, y: py + (i - off) * spread * perpy });
    trace = [];
    for (let t = 0; t <= progress + 0.001; t += 0.04)
      trace.push({ x: sx + vx * dist * t, y: sy + vy * dist * t });
  } else if (kind === "pinch") {
    const base = 150;
    const min = 50;
    const d = base - (base - min) * progress;
    points.push({ x: cx - d / 2, y: cy });
    points.push({ x: cx + d / 2, y: cy });
  } else {
    // rotate
    const r = 86;
    const a = -0.7 + 1.4 * progress;
    points.push({ x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) });
    points.push({ x: cx - r * Math.cos(a), y: cy - r * Math.sin(a) });
  }

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: "block" }}>
      <defs>
        <clipPath id="pad-clip">
          <rect x={1} y={1} width={W - 2} height={H - 2} rx={16} />
        </clipPath>
      </defs>
      <g clipPath="url(#pad-clip)">
        <rect x={0} y={0} width={W} height={H} fill={C.panel} />
        {grid()}
        {trace.length > 1 && (
          <polyline
            fill="none"
            stroke={C.trace}
            strokeWidth={5}
            strokeLinecap="round"
            strokeLinejoin="round"
            points={trace.map((p) => `${p.x},${p.y}`).join(" ")}
          />
        )}
        {points.map((p, i) => (
          <g key={i}>
            <circle cx={p.x} cy={p.y} r={20} fill={C.contact} opacity={0.16} />
            <circle cx={p.x} cy={p.y} r={10} fill={C.contact} />
          </g>
        ))}
      </g>
      <rect x={1} y={1} width={W - 2} height={H - 2} rx={16} fill="none" stroke={C.ink} strokeWidth={2.5} />
    </svg>
  );
};
