import { loadFont as loadDisplay } from "@remotion/google-fonts/SpaceGrotesk";
import { loadFont as loadMono } from "@remotion/google-fonts/IBMPlexMono";

export const { fontFamily: display } = loadDisplay();
export const { fontFamily: mono } = loadMono();

// Same identity as the website: trackpad telemetry on graph paper.
export const C = {
  ink: "#12161B",
  inkSoft: "#3A434E",
  paper: "#E9ECEF",
  panel: "#FBFCFD",
  line: "rgba(18,22,27,0.12)",
  gridLine: "rgba(18,22,27,0.05)",
  trace: "#1F5AE6",
  contact: "#E0457B",
  readout: "#FFC65A",
  green: "#5EE0A0",
  steel: "#8FA0B6",
} as const;

export const FPS = 30;
