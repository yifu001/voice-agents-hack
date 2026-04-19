import { SectionFrame } from './primitives/SectionFrame';
import { Accordion, AccordionGroup } from './primitives/Accordion';
import { problem } from '@/content/copy';

export function Problem() {
  return (
    <SectionFrame
      id="problem"
      code="S-03"
      eyebrow={problem.eyebrow}
      title={problem.title}
      intro={
        <div className="space-y-5">
          {problem.body.map((p, i) => (
            <p key={i}>{p}</p>
          ))}
        </div>
      }
    >
      <div className="mt-10 max-w-3xl">
        <AccordionGroup>
          <Accordion title="Why existing radios hit the scaling wall">
            <p className="mt-2">
              A single voice channel is serial: only one person talks at a time. Fifty
              subordinates with anything useful to say share one slot. In practice,
              units split onto sub-channels and appoint human relays who summarise
              upward by hand — which introduces latency, loses detail, and drains the
              attention of the most experienced operators.
            </p>
            <p className="mt-4">
              The scaling wall is not the radios. It&rsquo;s the commander&rsquo;s
              cognitive bandwidth.
            </p>
          </Accordion>
          <Accordion title="How TacNet inverts the model">
            <p className="mt-2">
              TacNet treats the commander like a single consumer of structured data.
              Every node in the tree is responsible for producing one compacted line
              per interval, summarising the children below it. By the time a signal
              reaches the top, it has been compressed N times and carries only what
              the commander needs to decide.
            </p>
            <p className="mt-4">
              The radios still exist as a layer: siblings and direct parent see the
              raw transcript text. Compaction is an <em>additional</em> channel that
              climbs upward, not a replacement for first-person voice.
            </p>
          </Accordion>
        </AccordionGroup>
      </div>
    </SectionFrame>
  );
}
