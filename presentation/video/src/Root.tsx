import React from "react";
import { Composition } from "remotion";
import { EcoHealthPromo } from "./EcoHealthPromo";
import { EcoHealthPromoStat2 } from "./stat2/Promo";
import { DURATION_FRAMES, FPS } from "./theme";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* stat1 — the original cut (unchanged) */}
      <Composition
        id="stat1"
        component={EcoHealthPromo}
        durationInFrames={DURATION_FRAMES}
        fps={FPS}
        width={1920}
        height={1080}
      />
      {/* stat2 — edited variant */}
      <Composition
        id="stat2"
        component={EcoHealthPromoStat2}
        durationInFrames={DURATION_FRAMES}
        fps={FPS}
        width={1920}
        height={1080}
      />
    </>
  );
};
