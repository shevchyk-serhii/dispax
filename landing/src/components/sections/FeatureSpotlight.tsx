import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { SectionHeader } from "../ui/SectionHeader";
import { IconName } from "../ui/icons";
import { FeatureStatus } from "../ui/StatusBadge";
import { Reveal } from "../ui/Reveal";
import { FeatureRow } from "./marketing/FeatureRow";
import { EtaMock, AirportMock, BillingMock, PoolsMock } from "./marketing/mocks";

type Block = {
  title: string;
  desc: string;
  bullets: string[];
  status: FeatureStatus;
};

const blockIcons: IconName[] = ["radar", "planeLand", "receipt", "layers"];
const mocks = [EtaMock, AirportMock, BillingMock, PoolsMock];

export function FeatureSpotlight() {
  const t = useTranslations("spotlight");
  const blocks = t.raw("blocks") as Block[];

  return (
    <section id="spotlight" className="scroll-mt-20 bg-accent-wash bg-bg py-28">
      <Container>
        <Reveal>
          <SectionHeader
            eyebrow={t("eyebrow")}
            title={t("title")}
            subtitle={t("subtitle")}
          />
        </Reveal>

        <div className="mt-20 flex flex-col gap-24">
          {blocks.map((block, i) => {
            const Mock = mocks[i];
            return (
              <FeatureRow
                key={i}
                index={i}
                icon={blockIcons[i]}
                title={block.title}
                desc={block.desc}
                bullets={block.bullets}
                status={block.status}
                visual={<Mock />}
              />
            );
          })}
        </div>
      </Container>
    </section>
  );
}
