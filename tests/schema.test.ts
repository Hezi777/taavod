import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { parsePagilaSchema, relationshipsForTable } from '@/lib/practice/schema';

const dataDirectory = 'public/practice/datasets';
const schemaSource = JSON.parse(readFileSync(`${dataDirectory}/pagila-schema.json`, 'utf8'));
const manifest = JSON.parse(readFileSync(`${dataDirectory}/pagila-manifest.json`, 'utf8'));
const schema = parsePagilaSchema(schemaSource, manifest);

describe('Pagila schema metadata', () => {
  it('describes the exact core tables and sample row counts', () => {
    expect(schema.tables).toHaveLength(15);
    expect(schema.totalRows).toBe(121209);
    expect(schema.tables.find((table) => table.name === 'payment')?.rowCount).toBe(51061);
  });

  it('retains actual column types and composite primary keys', () => {
    const film = schema.tables.find((table) => table.name === 'film');
    expect(film?.columns.find((column) => column.name === 'rating')?.type).toBe('USER-DEFINED');
    const paymentKeys = schema.tables.find((table) => table.name === 'payment')?.columns.filter((column) => column.primaryKey).sort((left, right) => (left.primaryKeyPosition ?? 0) - (right.primaryKeyPosition ?? 0)).map((column) => column.name);
    expect(paymentKeys).toEqual(['payment_date', 'payment_id']);
    const bridgeKeys = schema.tables.find((table) => table.name === 'film_actor')?.columns.filter((column) => column.primaryKey).sort((left, right) => (left.primaryKeyPosition ?? 0) - (right.primaryKeyPosition ?? 0)).map((column) => column.name);
    expect(bridgeKeys).toEqual(['actor_id', 'film_id']);
  });

  it('maps enforced foreign keys to existing target columns', () => {
    expect(relationshipsForTable(schema, 'film_actor')).toEqual(expect.arrayContaining([
      expect.objectContaining({ fromTable: 'film_actor', fromColumn: 'film_id', toTable: 'film', toColumn: 'film_id', enforced: true }),
      expect.objectContaining({ fromTable: 'film_actor', fromColumn: 'actor_id', toTable: 'actor', toColumn: 'actor_id', enforced: true }),
    ]));
    for (const relationship of schema.relationships) {
      const sourceTable = schema.tables.find((table) => table.name === relationship.fromTable);
      const targetTable = schema.tables.find((table) => table.name === relationship.toTable);
      expect(sourceTable?.columns.some((column) => column.name === relationship.fromColumn)).toBe(true);
      expect(targetTable?.columns.some((column) => column.name === relationship.toColumn)).toBe(true);
    }
  });
});
