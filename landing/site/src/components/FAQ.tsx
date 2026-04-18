import { SectionFrame } from './primitives/SectionFrame';
import { Accordion, AccordionGroup } from './primitives/Accordion';
import { faq } from '@/content/faq';

export function FAQ() {
  return (
    <SectionFrame
      id="faq"
      eyebrow={faq.eyebrow}
      title={faq.title}
    >
      <div className="mt-6 max-w-3xl">
        <AccordionGroup>
          {faq.items.map((it, i) => (
            <Accordion key={i} title={it.q}>
              <p className="mt-2">{it.a}</p>
            </Accordion>
          ))}
        </AccordionGroup>
      </div>
    </SectionFrame>
  );
}
