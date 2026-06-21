import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { C, mono } from "../theme";

export const Title: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = spring({ frame, fps, config: { damping: 200 } });
  const y = interpolate(rise, [0, 1], [40, 0]);
  const tagOpacity = interpolate(frame, [18, 36], [0, 1], { extrapolateRight: "clamp" });
  const eyebrowOpacity = interpolate(frame, [6, 20], [0, 1], { extrapolateRight: "clamp" });

  return (
    <GraphPaper>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", textAlign: "center" }}>
        <div style={{ transform: `translateY(${y}px)`, opacity: rise }}>
          <p
            style={{
              fontFamily: mono,
              textTransform: "uppercase",
              letterSpacing: "0.22em",
              fontSize: 22,
              color: C.trace,
              margin: 0,
              opacity: eyebrowOpacity,
            }}
          >
            open source · macOS menu-bar app
          </p>
          <h1
            style={{
              fontSize: 132,
              fontWeight: 700,
              letterSpacing: "-0.04em",
              margin: "18px 0 0",
              lineHeight: 1,
            }}
          >
            <span style={{ fontWeight: 400, color: C.inkSoft }}>Average</span>TouchTool
          </h1>
          <p
            style={{
              fontSize: 34,
              color: C.inkSoft,
              marginTop: 26,
              opacity: tagOpacity,
            }}
          >
            Trackpad gestures &amp; custom actions. Named conservatively.
          </p>
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
