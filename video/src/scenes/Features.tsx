import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { GraphPaper } from "../components/GraphPaper";
import { C, mono } from "../theme";

const FEATS: { k: string; title: string; body: string }[] = [
  { k: "01", title: "Per-app profiles", body: "Global bindings, or ones that only fire when a chosen app is frontmost." },
  { k: "02", title: "Customizable Touch Bar", body: "One launcher in the Control Strip opens a full-width modal of your buttons & sliders." },
  { k: "03", title: "Record a gesture", body: "Hit Record, perform the gesture, and the trigger fills itself in." },
  { k: "04", title: "Import / export", body: "Your whole setup is one JSON file. Back it up, share it, version it." },
];

export const Features: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  return (
    <GraphPaper>
      <AbsoluteFill style={{ padding: "0 140px", justifyContent: "center" }}>
        <h2 style={{ fontSize: 70, fontWeight: 600, letterSpacing: "-0.03em", margin: "0 0 50px" }}>
          And the rest of it.
        </h2>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: "44px 70px" }}>
          {FEATS.map((f, i) => {
            const s = spring({ frame: frame - i * 7, fps, config: { damping: 200 } });
            return (
              <div
                key={f.k}
                style={{
                  opacity: s,
                  transform: `translateY(${interpolate(s, [0, 1], [26, 0])}px)`,
                  borderTop: `3px solid ${C.ink}`,
                  paddingTop: 22,
                }}
              >
                <span style={{ fontFamily: mono, fontSize: 22, color: C.trace }}>{f.k}</span>
                <h3 style={{ fontSize: 40, fontWeight: 600, margin: "8px 0 12px" }}>{f.title}</h3>
                <p style={{ fontSize: 27, color: C.inkSoft, margin: 0, lineHeight: 1.4 }}>{f.body}</p>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </GraphPaper>
  );
};
