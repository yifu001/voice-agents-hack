import { MonoStat } from './primitives/MonoStat';
import { dataBand } from '@/content/copy';

export function DataBand() {
  return (
    <section
      className="border-y"
      style={{
        background: 'var(--color-surface)',
        borderColor: 'var(--color-border)',
      }}
    >
      <div
        className="mx-auto grid max-w-[1200px] gap-px"
        style={{
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          background: 'var(--color-border)',
        }}
      >
        {dataBand.map((s, i) => (
          <div
            key={i}
            className="px-6 py-8 sm:px-10"
            style={{ background: 'var(--color-surface)' }}
          >
            <MonoStat big={s.big} small={s.small} emphasis={i === 0} />
          </div>
        ))}
      </div>
    </section>
  );
}
