import React from "react";
import { C, mono } from "../theme";

/** The dark telemetry panel used across scenes. */
export const Readout: React.FC<{ rows: [string, string][]; width?: number }> = ({
  rows,
  width = 360,
}) => (
  <div
    style={{
      fontFamily: mono,
      background: C.ink,
      color: C.paper,
      borderRadius: 14,
      padding: "22px 26px",
      width,
    }}
  >
    {rows.map(([k, v], i) => (
      <div
        key={i}
        style={{
          display: "flex",
          justifyContent: "space-between",
          gap: 28,
          padding: "6px 0",
          fontSize: 24,
        }}
      >
        <span style={{ color: C.steel, letterSpacing: "0.04em" }}>{k}</span>
        <span
          style={{
            color: k === "gesture" ? C.contact : k === "travel" ? C.readout : "#fff",
            textTransform: k === "gesture" ? "uppercase" : "none",
            fontWeight: 500,
          }}
        >
          {v}
        </span>
      </div>
    ))}
  </div>
);
