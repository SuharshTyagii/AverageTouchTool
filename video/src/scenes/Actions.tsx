import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { C, mono } from "../theme";

const CATS: { title: string; items: string[] }[] = [
  { title: "Window", items: ["Snap left / right", "Maximize", "Center"] },
  { title: "Audio & media", items: ["Volume · mute · mic", "Play / pause", "Next · previous"] },
  { title: "System", items: ["Mission Control", "Control Center", "Lock · Night Shift"] },
  { title: "Screenshots", items: ["Capture selection", "Whole screen", "Clipboard + file"] },
  { title: "Launch & run", items: ["Launch · open URL", "Run shell", "Run AppleScript"] },
  { title: "Keyboard", items: ["Send any shortcut", "Even stolen combos", "Consume the key"] },
];

export const Actions: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const head = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });

  return (
    <GraphPaper>
      <AbsoluteFill style={{ padding: "90px 140px", justifyContent: "center" }}>
        <div style={{ opacity: head, marginBottom: 44 }}>
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
            what it does
          </p>
          <h2 style={{ fontSize: 70, fontWeight: 600, letterSpacing: "-0.03em", margin: "10px 0 0" }}>
            Bind a trigger to anything.
          </h2>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 26 }}>
          {CATS.map((c, i) => {
            const s = spring({ frame: frame - 14 - i * 6, fps, config: { damping: 200 } });
            return (
              <div
                key={c.title}
                style={{
                  opacity: s,
                  transform: `translateY(${interpolate(s, [0, 1], [30, 0])}px)`,
                  background: C.panel,
                  border: `2px solid ${C.line}`,
                  borderRadius: 16,
                  padding: "26px 30px",
                }}
              >
                <h3
                  style={{
                    fontFamily: mono,
                    textTransform: "uppercase",
                    letterSpacing: "0.1em",
                    fontSize: 19,
                    color: C.trace,
                    margin: "0 0 16px",
                  }}
                >
                  {c.title}
                </h3>
                {c.items.map((it) => (
                  <div key={it} style={{ display: "flex", alignItems: "center", gap: 12, padding: "7px 0" }}>
                    <span style={{ width: 9, height: 9, borderRadius: "50%", background: C.contact }} />
                    <span style={{ fontSize: 25 }}>{it}</span>
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
