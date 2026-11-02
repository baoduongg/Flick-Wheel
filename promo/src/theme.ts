import { Easing, interpolate } from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";

export const { fontFamily } = loadFont("normal", {
  weights: ["500", "600", "700", "800"],
  subsets: ["latin"],
});

export const C = {
  bg: "#0b0c14",
  fg: "#f2f2f7",
  mute: "#a1a1aa",
  shift: "#0a84ff",
  command: "#a64dd6",
  control: "#ff9f0a",
};

export const ease = Easing.bezier(0.16, 1, 0.3, 1);

/** 0 to 1 eased progress between frame `from` and `from + dur`. */
export const t = (frame: number, from: number, dur: number) =>
  interpolate(frame, [from, from + dur], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: ease,
  });
