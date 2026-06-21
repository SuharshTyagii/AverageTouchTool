import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { Pad, GestureKind, Dir } from "../components/Pad";
import { Readout } from "../components/Readout";
import { C, mono } from "../theme";

/** One gesture showcased on the animated pad with a live readout. */
export const GestureDemo: React.FC<{
  kind: GestureKind;
  dir?: Dir;
  fingers: number;
  title: string;
  blurb: string;
  readout: [string, string][];
}> = ({ kind, dir, fingers, title, blurb, readout }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  const progress = interpolate(frame, [8, durationInFrames - 14], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const enter = interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" });

  return (
    <GraphPaper>
      <AbsoluteFill
        style={{
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "center",
          gap: 80,
          padding: "0 140px",
          opacity: enter,
        }}
      >
        <div style={{ width: 720 }}>
          <Pad kind={kind} dir={dir} fingers={fingers} progress={progress} />
        </div>

        <div style={{ width: 520 }}>
          <p
            style={{
              fontFamily: mono,
              textTransform: "uppercase",
              letterSpacing: "0.16em",
              fontSize: 20,
              color: C.trace,
              margin: 0,
            }}
          >
            gesture
          </p>
          <h2 style={{ fontSize: 76, fontWeight: 600, letterSpacing: "-0.03em", margin: "10px 0 18px" }}>
            {title}
          </h2>
          <p style={{ fontSize: 28, color: C.inkSoft, margin: "0 0 34px", lineHeight: 1.45 }}>{blurb}</p>
          <Readout rows={readout} />
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
