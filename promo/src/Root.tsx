import { Composition } from "remotion";
import { Promo } from "./Promo";

export const RemotionRoot: React.FC = () => (
  <Composition id="FlickWheelPromo" component={Promo} durationInFrames={450} fps={30} width={1920} height={1080} />
);
