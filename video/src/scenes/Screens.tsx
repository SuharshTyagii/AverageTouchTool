import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { C } from "../theme";

/**
 * Screenshot showcase. The PNGs in public/screens/ are transparent renders of
 * the real app UI (window chrome + shadow baked in), so they composite straight
 * onto the graph paper with no extra framing. Replace them with literal captures
 * any time — same filenames.
 */
export const Screens: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const a = spring({ frame: frame - 4, fps, config: { damping: 200 } });
  const b = spring({ frame: frame - 18, fps, config: { damping: 200 } });
  const headIn = interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" });

  return (
    <GraphPaper>
      <AbsoluteFill style={{ padding: "70px 120px 0", alignItems: "center" }}>
        <h2
          style={{
            fontSize: 70,
            fontWeight: 600,
            letterSpacing: "-0.03em",
            margin: 0,
            alignSelf: "flex-start",
            opacity: headIn,
            transform: `translateY(${interpolate(headIn, [0, 1], [20, 0])}px)`,
          }}
        >
          A real native app.
        </h2>

        <div style={{ position: "relative", width: 1480, height: 760, marginTop: 10 }}>
          {/* Settings window */}
          <Img
            src={staticFile("screens/settings.png")}
            style={{
              position: "absolute",
              left: 0,
              top: 40,
              width: 1120,
              opacity: a,
              transform: `translateY(${interpolate(a, [0, 1], [60, 0])}px) rotate(-2deg)`,
              filter: `drop-shadow(0 30px 60px ${C.line})`,
            }}
          />
          {/* Action picker, overlapping bottom-right for depth */}
          <Img
            src={staticFile("screens/action-picker.png")}
            style={{
              position: "absolute",
              right: -20,
              top: 250,
              width: 470,
              opacity: b,
              transform: `translateY(${interpolate(b, [0, 1], [70, 0])}px) rotate(3deg)`,
            }}
          />
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
