import React from "react";
import { Series } from "remotion";
import { Title } from "./scenes/Title";
import { GestureDemo } from "./scenes/GestureDemo";
import { Actions } from "./scenes/Actions";
import { Features } from "./scenes/Features";
import { Screens } from "./scenes/Screens";
import { Outro } from "./scenes/Outro";

export const PROMO_DURATION = 930;

export const Promo: React.FC = () => (
  <Series>
    <Series.Sequence durationInFrames={90}>
      <Title />
    </Series.Sequence>

    <Series.Sequence durationInFrames={80}>
      <GestureDemo
        kind="tap"
        fingers={3}
        title="Tap"
        blurb="Two to five fingers, stationary and quick. Single-finger taps stay out of the way of normal clicking."
        readout={[
          ["gesture", "tap"],
          ["fingers", "3"],
          ["travel", "0.012"],
        ]}
      />
    </Series.Sequence>

    <Series.Sequence durationInFrames={80}>
      <GestureDemo
        kind="swipe"
        dir="left"
        fingers={3}
        title="Swipe"
        blurb="Up, down, left, right with two to four fingers. Direction comes from the dominant travel axis."
        readout={[
          ["gesture", "swipe ←"],
          ["fingers", "3"],
          ["travel", "0.341"],
        ]}
      />
    </Series.Sequence>

    <Series.Sequence durationInFrames={80}>
      <GestureDemo
        kind="pinch"
        fingers={2}
        title="Pinch"
        blurb="Two fingers in or out. Classified from the change in spread between the two contacts."
        readout={[
          ["gesture", "pinch in"],
          ["fingers", "2"],
          ["spread Δ", "-0.21"],
        ]}
      />
    </Series.Sequence>

    <Series.Sequence durationInFrames={80}>
      <GestureDemo
        kind="rotate"
        fingers={2}
        title="Rotate"
        blurb="Two fingers, clockwise or counter. The angle is folded to ±90° so finger order can't flip it."
        readout={[
          ["gesture", "rotate ↺"],
          ["fingers", "2"],
          ["angle", "0.52 rad"],
        ]}
      />
    </Series.Sequence>

    <Series.Sequence durationInFrames={150}>
      <Actions />
    </Series.Sequence>

    <Series.Sequence durationInFrames={130}>
      <Features />
    </Series.Sequence>

    <Series.Sequence durationInFrames={140}>
      <Screens />
    </Series.Sequence>

    <Series.Sequence durationInFrames={100}>
      <Outro />
    </Series.Sequence>
  </Series>
);
