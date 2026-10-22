export type PracticeColumn = {
  name: string;
  type: string;
  nullable: boolean;
  primaryKey: boolean;
  primaryKeyPosition: number | null;
  foreignKeys: { table: string; column: string }[];
};

export type PracticeTable = {
  name: string;
  label: string;
  group: 'catalog' | 'people' | 'rental';
  x: number;
  y: number;
  rowCount: number;
  columns: PracticeColumn[];
};

export type PracticeRelationship = {
  fromTable: string;
  fromColumn: string;
  toTable: string;
  toColumn: string;
  enforced: boolean;
};

export type PagilaSchema = {
  tables: PracticeTable[];
  relationships: PracticeRelationship[];
  totalRows: number;
};

type SchemaSource = {
  columns: { table_name: string; column_name: string; data_type: string; is_nullable: string; ordinal_position: number }[];
  constraints: { table_name: string; kind: 'p' | 'f'; definition: string }[];
};

type ManifestSource = { tables: Record<string, number> };

const tablePlacement: Record<string, { x: number; y: number; group: PracticeTable['group'] }> = {
  country: { x: 20, y: 25, group: 'people' },
  city: { x: 210, y: 25, group: 'people' },
  address: { x: 400, y: 25, group: 'people' },
  store: { x: 590, y: 25, group: 'people' },
  staff: { x: 780, y: 25, group: 'people' },
  customer: { x: 780, y: 170, group: 'people' },
  language: { x: 20, y: 170, group: 'catalog' },
  film: { x: 210, y: 170, group: 'catalog' },
  film_actor: { x: 400, y: 170, group: 'catalog' },
  actor: { x: 590, y: 170, group: 'catalog' },
  category: { x: 20, y: 315, group: 'catalog' },
  film_category: { x: 210, y: 315, group: 'catalog' },
  inventory: { x: 400, y: 315, group: 'rental' },
  rental: { x: 590, y: 315, group: 'rental' },
  payment: { x: 780, y: 315, group: 'rental' },
};

function parseKeyColumns(definition: string): string[] {
  const match = definition.match(/(?:PRIMARY KEY|FOREIGN KEY)\s*\(([^)]+)\)/i);
  return match ? match[1].split(',').map((column) => column.trim().replaceAll('"', '')) : [];
}

export function parsePagilaSchema(source: SchemaSource, manifest: ManifestSource): PagilaSchema {
  const primaryKeys = new Map<string, Map<string, number>>();
  const relationships: PracticeRelationship[] = [];
  for (const constraint of source.constraints) {
    if (constraint.kind === 'p') {
      primaryKeys.set(constraint.table_name, new Map(parseKeyColumns(constraint.definition).map((column, index) => [column, index + 1])));
      continue;
    }
    const match = constraint.definition.match(/FOREIGN KEY\s*\(([^)]+)\)\s*REFERENCES\s+([^.(]+)\s*\(([^)]+)\)/i);
    if (!match) continue;
    const fromColumns = match[1].split(',').map((column) => column.trim().replaceAll('"', ''));
    const toColumns = match[3].split(',').map((column) => column.trim().replaceAll('"', ''));
    fromColumns.forEach((fromColumn, index) => relationships.push({
      fromTable: constraint.table_name,
      fromColumn,
      toTable: match[2].trim().replaceAll('"', ''),
      toColumn: toColumns[index] ?? toColumns[0],
      enforced: true,
    }));
  }

  const byTable = new Map<string, PracticeColumn[]>();
  for (const column of source.columns) {
    const values = byTable.get(column.table_name) ?? [];
    values.push({
      name: column.column_name,
      type: column.data_type,
      nullable: column.is_nullable === 'YES',
      primaryKey: primaryKeys.get(column.table_name)?.has(column.column_name) ?? false,
      primaryKeyPosition: primaryKeys.get(column.table_name)?.get(column.column_name) ?? null,
      foreignKeys: relationships
        .filter((relationship) => relationship.fromTable === column.table_name && relationship.fromColumn === column.column_name)
        .map((relationship) => ({ table: relationship.toTable, column: relationship.toColumn })),
    });
    byTable.set(column.table_name, values);
  }

  const tables = [...byTable.entries()].map(([name, columns]) => {
    const placement = tablePlacement[name] ?? { x: 20, y: 25, group: 'catalog' as const };
    return {
      name,
      label: name.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()),
      group: placement.group,
      x: placement.x,
      y: placement.y,
      rowCount: manifest.tables[name] ?? 0,
      columns,
    };
  }).sort((left, right) => left.y - right.y || left.x - right.x);

  return { tables, relationships, totalRows: Object.values(manifest.tables).reduce((sum, count) => sum + count, 0) };
}

export function relationshipsForTable(schema: PagilaSchema, tableName: string): PracticeRelationship[] {
  return schema.relationships.filter((relationship) => relationship.fromTable === tableName || relationship.toTable === tableName);
}

export function completionSchema(tables: PracticeTable[]) {
  return { public: Object.fromEntries(tables.map((table) => [table.name, table.columns.map((column) => column.name)])) };
}

export async function fetchPagilaSchema(): Promise<PagilaSchema> {
  const [schemaResponse, manifestResponse] = await Promise.all([
    fetch('/practice/datasets/pagila-schema.json'),
    fetch('/practice/datasets/pagila-manifest.json'),
  ]);
  if (!schemaResponse.ok || !manifestResponse.ok) throw new Error('Pagila schema metadata could not be loaded.');
  const [schema, manifest] = await Promise.all([schemaResponse.json(), manifestResponse.json()]) as [SchemaSource, ManifestSource];
  return parsePagilaSchema(schema, manifest);
}
