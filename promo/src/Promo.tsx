import { AbsoluteFill, Audio, Sequence } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { uiSwitch, whoosh, ding, mouseClick } from "@remotion/sfx";
import { Background } from "./Background";
import { Hook } from "./scenes/Hook";
import { Brand } from "./scenes/Brand";
import { Wheels } from "./scenes/Wheels";
import { Stats } from "./scenes/Stats";
import { Cta } from "./scenes/Cta";

const T = linearTiming({ durationInFrames: 12 });

// Scene starts (frames): 0, 44, 106, 334, 382. Total 450 = 15 s at 30 fps.
export const Promo: React.FC = () => (
  <AbsoluteFill>
    <Background />
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={56} name="Hook"><Hook /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={T} />
      <TransitionSeries.Sequence durationInFrames={74} name="Brand"><Brand /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={T} />
      <TransitionSeries.Sequence durationInFrames={240} name="Wheels"><Wheels /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={T} />
      <TransitionSeries.Sequence durationInFrames={60} name="Stats"><Stats /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={T} />
      <TransitionSeries.Sequence durationInFrames={68} name="CTA"><Cta /></TransitionSeries.Sequence>
    </TransitionSeries>

    {/* sound design */}
    {[40, 102, 330, 378].map((f) => (
      <Sequence key={f} from={f} layout="none"><Audio src={whoosh} volume={0.35} /></Sequence>
    ))}
    {[112, 192, 272].map((f) => (
      <Sequence key={f} from={f} layout="none"><Audio src={uiSwitch} volume={0.5} /></Sequence>
    ))}
    {[164, 244, 324].map((f) => (
      <Sequence key={f} from={f} layout="none"><Audio src={mouseClick} volume={0.45} /></Sequence>
    ))}
    <Sequence from={396} layout="none"><Audio src={ding} volume={0.35} /></Sequence>
  </AbsoluteFill>
);
