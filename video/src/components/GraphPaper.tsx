import React from "react";
import { AbsoluteFill } from "remotion";
import { C, display } from "../theme";

/** Shared scene background: cool graph paper, display font. */
export const GraphPaper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill
    style={{
      backgroundColor: C.paper,
      backgroundImage: `linear-gradient(${C.gridLine} 1px, transparent 1px), linear-gradient(90deg, ${C.gridLine} 1px, transparent 1px)`,
      backgroundSize: "44px 44px",
      fontFamily: display,
      color: C.ink,
    }}
  >
    {children}
  </AbsoluteFill>
);
