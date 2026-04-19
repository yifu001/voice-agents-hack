import { SectionFrame } from './primitives/SectionFrame';
import { CodeWindow, Token } from './primitives/CodeWindow';
import { Accordion, AccordionGroup } from './primitives/Accordion';
import { ai } from '@/content/copy';

export function AI() {
  return (
    <SectionFrame
      id="ai"
      code="S-06"
      eyebrow={ai.eyebrow}
      title={ai.title}
      intro={<p>{ai.intro}</p>}
    >
      <div className="mt-10 grid gap-10 lg:grid-cols-[1fr_1.1fr]">
        {/* Spec table */}
        <div
          className="border"
          style={{
            borderColor: 'var(--color-border)',
            background: 'var(--color-surface)',
          }}
        >
          <div
            className="border-b px-5 py-3"
            style={{ borderColor: 'var(--color-border)' }}
          >
            <span
              className="text-[11px] uppercase tracking-[0.14em]"
              style={{
                color: 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              // model spec
            </span>
          </div>
          <div className="divide-y" style={{ borderColor: 'var(--color-border)' }}>
            {ai.specs.map(([k, v]) => (
              <div
                key={k}
                className="flex items-center justify-between gap-4 px-5 py-3"
                style={{ borderColor: 'var(--color-border)' }}
              >
                <span
                  className="text-[11px] uppercase tracking-[0.12em]"
                  style={{
                    color: 'var(--color-text-muted)',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {k}
                </span>
                <span
                  className="text-right text-[13px]"
                  style={{
                    color: 'var(--color-text)',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {v}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Prompt */}
        <div>
          <CodeWindow filename={ai.promptTitle} lang="prompt" stacked>
            <span style={{ color: '#8A918C' }}>
              {ai.promptBody.split('\n').map((line, i) => (
                <span key={i} style={{ display: 'block' }}>
                  {colorize(line)}
                </span>
              ))}
            </span>
          </CodeWindow>
        </div>
      </div>

      <div className="mt-12 max-w-3xl">
        <AccordionGroup>
          <Accordion title="See the Swift integration (CompactionEngine)">
            <div className="mt-4">
              <CodeWindow filename="CompactionEngine.swift" lang="swift">
                <span>
                  <Token kind="keyword">import</Token> <Token kind="type">Cactus</Token>
                  <br />
                  <br />
                  <Token kind="keyword">actor</Token> <Token kind="type">CompactionEngine</Token> {'{'}
                  <br />
                  {'  '}<Token kind="keyword">private var</Token> context: <Token kind="type">OpaquePointer</Token>?
                  <br />
                  {'  '}<Token kind="keyword">private var</Token> queue: [<Token kind="type">Message</Token>] = []
                  <br />
                  <br />
                  {'  '}<Token kind="keyword">init</Token>(modelPath: <Token kind="type">String</Token>) <Token kind="keyword">async throws</Token> {'{'}
                  <br />
                  {'    '}<Token kind="keyword">let</Token> params = <Token kind="fn">cactusDefaultParams</Token>()
                  <br />
                  {'    '}context = <Token kind="fn">cactusInit</Token>(modelPath, params)
                  <br />
                  {'  '}{'}'}
                  <br />
                  <br />
                  {'  '}<Token kind="keyword">func</Token> <Token kind="fn">queue</Token>(_ msg: <Token kind="type">Message</Token>) <Token kind="keyword">async</Token> -&gt; <Token kind="type">Summary</Token>? {'{'}
                  <br />
                  {'    '}queue.<Token kind="fn">append</Token>(msg)
                  <br />
                  {'    '}<Token kind="keyword">guard</Token> queue.count &gt;= <Token kind="number">3</Token> <Token kind="keyword">else</Token> {'{ '}<Token kind="keyword">return nil</Token>{' }'}
                  <br />
                  {'    '}<Token kind="keyword">let</Token> prompt = <Token kind="fn">buildPrompt</Token>(queue)
                  <br />
                  {'    '}<Token kind="keyword">let</Token> summary = <Token kind="fn">cactusComplete</Token>(context, prompt, <Token kind="number">64</Token>)
                  <br />
                  {'    '}queue.<Token kind="fn">removeAll</Token>()
                  <br />
                  {'    '}<Token kind="keyword">return</Token> <Token kind="type">Summary</Token>(text: summary)
                  <br />
                  {'  '}{'}'}
                  <br />
                  {'}'}
                </span>
              </CodeWindow>
            </div>
          </Accordion>
          <Accordion title="Why one model for both STT and summarisation">
            <p className="mt-2">
              Gemma 4 E4B ships with a native ~300M parameter audio conformer encoder.
              Audio goes in, text comes out — no separate Whisper or Apple Speech
              model to load, version, or bug-chase.
            </p>
            <p className="mt-4">
              For the hackathon MVP we run the same E4B on every device regardless of
              role. Future tiers may swap leaf nodes to a lighter E2B and keep the
              parent/root nodes on E4B to balance battery versus compaction quality.
            </p>
          </Accordion>
          <Accordion title="Latency math (30 s audio → 0.3 s)">
            <p className="mt-2">
              On Apple Silicon, the Gemma 4 E4B audio conformer processes 30 seconds
              of PCM in ~0.3 s, and decode runs at ~40 tokens/s. A typical compaction
              emits under 60 tokens, so end-to-end wall time from last child message
              to emitted summary is under 2 seconds — which is what the compaction
              latency target in the spec locks in.
            </p>
          </Accordion>
        </AccordionGroup>
      </div>
    </SectionFrame>
  );
}

/** Light-touch colouring for the compaction-prompt display. */
function colorize(line: string) {
  if (line.startsWith('SYSTEM:')) {
    return (
      <>
        <span style={{ color: '#C678DD' }}>SYSTEM:</span>
        {line.slice(7)}
      </>
    );
  }
  if (line.startsWith('MESSAGES:')) {
    return <span style={{ color: '#C678DD' }}>{line}</span>;
  }
  if (line.startsWith('SUMMARY:')) {
    return <span style={{ color: '#C678DD' }}>{line}</span>;
  }
  if (line.startsWith('> ')) {
    return <span style={{ color: '#B8FF2C' }}>{line}</span>;
  }
  if (line.startsWith('- [')) {
    const close = line.indexOf(']:');
    if (close !== -1) {
      return (
        <>
          <span style={{ color: '#8A918C' }}>- </span>
          <span style={{ color: '#D19A66' }}>{line.slice(2, close + 1)}</span>
          <span style={{ color: '#E2E8F0' }}>{line.slice(close + 1)}</span>
        </>
      );
    }
  }
  return <span style={{ color: '#E2E8F0' }}>{line}</span>;
}
