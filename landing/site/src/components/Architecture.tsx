import { SectionFrame } from './primitives/SectionFrame';
import { Accordion, AccordionGroup } from './primitives/Accordion';
import { CodeWindow, Token } from './primitives/CodeWindow';
import { MeshSimulation } from './MeshSimulation';
import { architecture } from '@/content/copy';

export function Architecture() {
  return (
    <SectionFrame
      id="architecture"
      eyebrow={architecture.eyebrow}
      title={architecture.title}
      intro={<p>{architecture.intro}</p>}
      background="grid"
    >
      <div className="mt-6">
        <MeshSimulation />
      </div>

      <div className="mt-14 max-w-3xl">
        <AccordionGroup>
          <Accordion title="BLE flooding with TTL + UUID deduplication">
            <p className="mt-2">
              Each message carries a <code className="font-mono text-[13px] text-[color:var(--color-accent)]">uuid</code> and a <code className="font-mono text-[13px] text-[color:var(--color-accent)]">ttl</code> (default 10).
              On receive, a node checks the UUID against a bounded seen-set (ring buffer capacity 50k);
              if unseen, it re-broadcasts with <code className="font-mono text-[13px] text-[color:var(--color-accent)]">ttl − 1</code>.
              Messages dying at ttl=0 prevent infinite loops.
            </p>
            <p className="mt-4">
              The mesh floods <em>everything</em>; the app layer filters by role (see routing rules below).
            </p>
          </Accordion>

          <Accordion title="Routing rules">
            <div
              className="mt-4 overflow-x-auto border"
              style={{
                borderColor: 'var(--color-border)',
                background: 'var(--color-surface)',
              }}
            >
              <table
                className="w-full text-[13px]"
                style={{ fontFamily: 'var(--font-mono)' }}
              >
                <thead>
                  <tr
                    className="border-b"
                    style={{
                      borderColor: 'var(--color-border)',
                      color: 'var(--color-text-muted)',
                    }}
                  >
                    <th className="px-4 py-2 text-left text-[10px] uppercase tracking-[0.14em]">
                      Type
                    </th>
                    <th className="px-4 py-2 text-left text-[10px] uppercase tracking-[0.14em]">
                      Sender
                    </th>
                    <th className="px-4 py-2 text-left text-[10px] uppercase tracking-[0.14em]">
                      Who displays / plays it
                    </th>
                  </tr>
                </thead>
                <tbody
                  className="divide-y"
                  style={{ borderColor: 'var(--color-border)', color: 'var(--color-text)' }}
                >
                  <tr>
                    <td className="px-4 py-2.5">BROADCAST</td>
                    <td className="px-4 py-2.5">Any node</td>
                    <td className="px-4 py-2.5">Sender&rsquo;s siblings + sender&rsquo;s parent</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-2.5">COMPACTION</td>
                    <td className="px-4 py-2.5">Intermediate / root node</td>
                    <td className="px-4 py-2.5">That node&rsquo;s parent only</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </Accordion>

          <Accordion title="Message envelope schema">
            <div className="mt-4">
              <CodeWindow filename="message-envelope.json" lang="json">
                <span>
                  {'{'}<br />
                  {'  '}<Token kind="string">&quot;id&quot;</Token>: <Token kind="string">&quot;uuid-v4&quot;</Token>,<br />
                  {'  '}<Token kind="string">&quot;type&quot;</Token>: <Token kind="string">&quot;BROADCAST&quot;</Token> <Token kind="punct">|</Token> <Token kind="string">&quot;COMPACTION&quot;</Token> <Token kind="punct">|</Token> <Token kind="string">&quot;CLAIM&quot;</Token>,<br />
                  {'  '}<Token kind="string">&quot;sender_id&quot;</Token>: <Token kind="string">&quot;node-uuid&quot;</Token>,<br />
                  {'  '}<Token kind="string">&quot;sender_role&quot;</Token>: <Token kind="string">&quot;Alpha-2&quot;</Token>,<br />
                  {'  '}<Token kind="string">&quot;parent_id&quot;</Token>: <Token kind="string">&quot;node-uuid&quot;</Token>,<br />
                  {'  '}<Token kind="string">&quot;tree_level&quot;</Token>: <Token kind="number">2</Token>,<br />
                  {'  '}<Token kind="string">&quot;timestamp&quot;</Token>: <Token kind="number">1713200000</Token>,<br />
                  {'  '}<Token kind="string">&quot;ttl&quot;</Token>: <Token kind="number">10</Token>,<br />
                  {'  '}<Token kind="string">&quot;encrypted&quot;</Token>: <Token kind="keyword">true</Token>,<br />
                  {'  '}<Token kind="string">&quot;location&quot;</Token>: {'{ '}<Token kind="string">&quot;lat&quot;</Token>: <Token kind="number">37.7749</Token>, <Token kind="string">&quot;lon&quot;</Token>: <Token kind="number">-122.4194</Token>{' }'},<br />
                  {'  '}<Token kind="string">&quot;payload&quot;</Token>: {'{'}<br />
                  {'    '}<Token kind="string">&quot;transcript&quot;</Token>: <Token kind="string">&quot;Movement sector 7&quot;</Token>,<br />
                  {'    '}<Token kind="string">&quot;summary&quot;</Token>: <Token kind="keyword">null</Token>,<br />
                  {'    '}<Token kind="string">&quot;source_ids&quot;</Token>: [...]<br />
                  {'  }'}<br />
                  {'}'}
                </span>
              </CodeWindow>
            </div>
          </Accordion>

          <Accordion title="Auto-reparenting on parent disconnect">
            <p className="mt-2">
              Every node monitors its BLE connection to its parent. If 60 seconds
              elapse with no heartbeat, the child traverses upward to find the
              nearest still-connected ancestor and sends a{' '}
              <code className="font-mono text-[13px] text-[color:var(--color-accent)]">TREE_UPDATE</code>{' '}
              with the new <code className="font-mono text-[13px] text-[color:var(--color-accent)]">parent_id</code>.
              All peers converge on the new topology by version number.
            </p>
            <p className="mt-4">
              Net effect: a squad leader going down never strands a leaf. Routing
              continues with one extra hop.
            </p>
          </Accordion>

          <Accordion title="Organiser promotion (PROMOTE)">
            <p className="mt-2">
              The organiser can broadcast{' '}
              <code className="font-mono text-[13px] text-[color:var(--color-accent)]">{'{ type: PROMOTE, target_node_id: ... }'}</code>{' '}
              at any time. The target device inherits organiser privileges,{' '}
              <code className="font-mono text-[13px] text-[color:var(--color-accent)]">created_by</code>{' '}
              updates, and the previous organiser becomes a regular participant.
              Designed to handle real-world command transfer mid-operation.
            </p>
          </Accordion>

          <Accordion title="Encryption + pre-shared key">
            <p className="mt-2">
              On network join, the participant authenticates with the network PIN.
              The organiser derives a session key from the PIN and sends it to the
              joining participant over the authenticated BLE channel. All subsequent
              messages (BROADCAST, COMPACTION, TREE_UPDATE, CLAIM, PROMOTE) are
              AES-256-GCM encrypted. The mesh routes ciphertext it cannot read.
            </p>
          </Accordion>
        </AccordionGroup>
      </div>
    </SectionFrame>
  );
}
