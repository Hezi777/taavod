export type ResultSet = { fields: { name: string }[]; rows: Record<string, unknown>[] };
function normalized(value: unknown): unknown {
 if (value instanceof Date) return value.toISOString();
 if (typeof value === 'bigint') return Number(value);
 if (typeof value === 'number') return Number.isFinite(value) ? Math.round(value * 1e7) / 1e7 : String(value);
 if (typeof value === 'string' && /^-?\d+(\.\d+)?$/.test(value)) return Math.round(Number(value) * 1e7) / 1e7;
 return value;
}
/** Compare multisets, preserving duplicate rows; column aliases and row order do not define correctness. */
export function equivalentResults(actual: ResultSet[], expected: ResultSet[]): boolean {
 if (actual.length !== expected.length) return false;
 return actual.every((set, i) => {
  const reference = expected[i];
  if (set.fields.length !== reference.fields.length || set.rows.length !== reference.rows.length) return false;
  const rows = (s: ResultSet) => s.rows.map(row => JSON.stringify(s.fields.map(f => normalized(row[f.name])))).sort();
  return JSON.stringify(rows(set)) === JSON.stringify(rows(reference));
 });
}
export type PracticeResult = { passed: boolean; feedback: string; results?: ResultSet[]; output?: string; plot?: string; checks: number };
