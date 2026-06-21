import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { C, mono } from "../theme";

export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 200 } });
  const sub = interpolate(frame, [16, 32], [0, 1], { extrapolateRight: "clamp" });

  return (
    <GraphPaper>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", textAlign: "center" }}>
        <div style={{ opacity: s, transform: `translateY(${interpolate(s, [0, 1], [30, 0])}px)` }}>
          <h2 style={{ fontSize: 110, fontWeight: 700, letterSpacing: "-0.04em", margin: 0 }}>
            <span style={{ fontWeight: 400, color: C.inkSoft }}>Average</span>TouchTool
          </h2>
          <p style={{ fontSize: 32, color: C.inkSoft, margin: "22px 0 40px", opacity: sub }}>
            Open source · MIT licensed · free
          </p>
          <div
            style={{
              opacity: sub,
              fontFamily: mono,
              fontSize: 26,
              display: "inline-flex",
              flexDirection: "column",
              gap: 10,
              color: C.ink,
            }}
          >
            <span style={{ color: C.trace }}>github.com/SuharshTyagii/AverageTouchTool</span>
            <span>Built by Suharsh Tyagi · suharshh.com</span>
          </div>
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
