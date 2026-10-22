'use client';

import { useState } from 'react';
import { Database, KeyRound, Link2 } from 'lucide-react';
import { relationshipsForTable, type PagilaSchema } from '@/lib/practice/schema';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';

export type QueryPreview = {
  fields: { name: string }[];
  rows: Record<string, unknown>[];
  rowCount: number;
  tableName?: string;
};

export function SchemaExplorer({
  schema,
  onPreview,
  preview,
  loading = false,
}: {
  schema: PagilaSchema | null;
  onPreview: (tableName: string) => void;
  preview?: QueryPreview | null;
  loading?: boolean;
}) {
  const [selectedName, setSelectedName] = useState('payment');
  const selected = schema?.tables.find((table) => table.name === selectedName) ?? schema?.tables[0];
  const relationships = schema&&selected ? relationshipsForTable(schema, selected.name) : [];

  function selectTable(name: string, shouldPreview = false) {
    setSelectedName(name);
    if (shouldPreview) onPreview(name);
  }

  if (!schema) return <div className="schema-loading" role="status">Loading exact Pagila table and key metadata…</div>;

  return <div className="schema-explorer space-y-5">
    <header className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <div className="flex items-center gap-2"><Database className="size-4 text-primary"/><h3 className="text-lg font-semibold">Explore the database</h3></div>
        <p className="mt-1 max-w-2xl text-sm leading-6 text-muted-foreground">The diagram comes from the loaded core Pagila schema. Select a table to inspect its columns and join paths, then preview its real rows.</p>
      </div>
      <Badge variant="secondary">{schema.tables.length} tables · {schema.totalRows.toLocaleString()} rows</Badge>
    </header>

    <div className="schema-diagram-scroll" role="group" aria-label="Pagila table relationship diagram. Select a table to inspect it.">
      <div className="schema-diagram" style={{ width: 970, height: 440 }}>
        <svg className="schema-diagram-lines" width="970" height="440" aria-hidden="true">
          <defs><marker id="schema-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M 0 0 L 8 4 L 0 8 z" /></marker></defs>
          {schema.relationships.map((relationship) => {
            const from = schema.tables.find((table) => table.name === relationship.fromTable);
            const to = schema.tables.find((table) => table.name === relationship.toTable);
            if (!from || !to) return null;
            return <line key={`${relationship.fromTable}.${relationship.fromColumn}-${relationship.toTable}.${relationship.toColumn}`} x1={from.x + 78} y1={from.y + 42} x2={to.x + 78} y2={to.y + 42} className={selected?.name === from.name || selected?.name === to.name ? 'is-related' : ''} markerEnd="url(#schema-arrow)" />;
          })}
        </svg>
        {schema.tables.map((table) => {
          const incoming = schema.relationships.some((relationship) => relationship.toTable === table.name);
          const outgoing = schema.relationships.some((relationship) => relationship.fromTable === table.name);
          return <button
            key={table.name}
            type="button"
            className={`schema-table-node ${table.group} ${selected?.name === table.name ? 'selected' : ''}`}
            style={{ left: table.x, top: table.y }}
            aria-pressed={selected?.name === table.name}
            onClick={() => selectTable(table.name)}
            title={`Select ${table.name}`}
          >
            <span className="schema-node-title">{table.label}</span>
            <span className="schema-node-name">{table.name}</span>
            <span className="schema-node-meta">{table.rowCount.toLocaleString()} rows · {incoming && outgoing ? 'parent + child' : incoming ? 'parent' : outgoing ? 'child' : 'standalone'}</span>
          </button>;
        })}
      </div>
    </div>
    <div className="flex flex-wrap gap-3 text-xs text-muted-foreground"><span><i className="schema-legend-dot catalog"/>Catalog</span><span><i className="schema-legend-dot people"/>People and places</span><span><i className="schema-legend-dot rental"/>Rental events</span><span>Lines are enforced foreign keys.</span></div>
    <p className="text-xs leading-5 text-muted-foreground">This is real core Pagila data: 15 tables and 121,209 rows. Payment partitions are combined into one table for this browser sample. Source: <a className="underline underline-offset-2" href="https://github.com/devrimgunduz/pagila/tree/ce6e114236bb828e5ec0dc835f65f1bf1b9179f5" target="_blank" rel="noreferrer">Pagila, PostgreSQL License</a>.</p>

    {selected&&<div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(250px,.72fr)]">
      <Card className="schema-detail-card">
        <CardContent className="space-y-4 py-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div><p className="text-xs uppercase tracking-wide text-muted-foreground">Selected table</p><h4 className="mt-1 text-lg font-semibold">{selected.name}</h4><p className="mt-1 text-xs text-muted-foreground">{selected.rowCount.toLocaleString()} sample rows</p></div>
            <Button size="sm" variant="outline" onClick={() => onPreview(selected.name)} disabled={loading}>{loading?'Loading…':'Preview rows'}</Button>
          </div>
          <div className="overflow-x-auto rounded-xl border">
            <Table>
              <TableHeader><TableRow><TableHead>Column</TableHead><TableHead>Type</TableHead><TableHead>Key</TableHead></TableRow></TableHeader>
              <TableBody>{selected.columns.map((column) => <TableRow key={column.name}><TableCell className="font-mono text-xs">{column.name}</TableCell><TableCell className="font-mono text-xs text-muted-foreground">{column.type}{column.nullable?' nullable':''}</TableCell><TableCell>{column.primaryKey?<span className="inline-flex items-center gap-1 text-xs text-primary"><KeyRound className="size-3"/>PK {column.primaryKeyPosition}</span>:column.foreignKeys.length?<span className="inline-flex items-center gap-1 text-xs text-muted-foreground"><Link2 className="size-3"/>FK → {column.foreignKeys.map((key) => `${key.table}.${key.column}`).join(', ')}</span>:<span className="text-xs text-muted-foreground">—</span>}</TableCell></TableRow>)}</TableBody>
            </Table>
          </div>
          <p className="text-xs leading-5 text-muted-foreground">Primary key: {selected.columns.filter((column) => column.primaryKey).sort((left, right) => (left.primaryKeyPosition ?? 0) - (right.primaryKeyPosition ?? 0)).map((column) => column.name).join(' + ') || 'none declared'}.</p>
        </CardContent>
      </Card>
      <Card className="schema-relationship-card">
        <CardContent className="space-y-4 py-5">
          <div><p className="text-xs uppercase tracking-wide text-muted-foreground">Join paths</p><h4 className="mt-1 text-base font-semibold">How {selected.name} connects</h4></div>
          {relationships.length ? <ul className="space-y-2">{relationships.map((relationship) => {
            const isFrom = relationship.fromTable === selected.name;
            const neighbor = isFrom ? relationship.toTable : relationship.fromTable;
            return <li key={`${relationship.fromTable}.${relationship.fromColumn}-${relationship.toTable}.${relationship.toColumn}`}>
              <button type="button" className="schema-relationship-link" onClick={() => selectTable(neighbor)}>
                <span className="font-mono text-xs">{relationship.fromTable}.{relationship.fromColumn} = {relationship.toTable}.{relationship.toColumn}</span>
                <span className="text-[11px] text-muted-foreground">{isFrom?'many rows → one':'one → many rows'} · foreign key enforced</span>
              </button>
            </li>;
          })}</ul> : <p className="text-sm text-muted-foreground">This table has no foreign-key paths in the loaded core schema.</p>}
          <p className="border-t pt-3 text-xs leading-5 text-muted-foreground">Start at the table that matches the question’s row grain. Follow one path at a time, then check whether each join multiplies rows.</p>
        </CardContent>
      </Card>
    </div>}

    {preview&&<Card className="schema-preview-card"><CardContent className="space-y-3 py-5"><div className="flex items-baseline justify-between gap-3"><h4 className="text-base font-semibold">Live query results{preview.tableName?` · ${preview.tableName}`:''}</h4><span className="text-xs text-muted-foreground">{preview.rowCount.toLocaleString()} rows · showing {preview.rows.length}</span></div><div className="max-h-80 overflow-auto rounded-xl border"><Table><TableHeader><TableRow>{preview.fields.map((field) => <TableHead key={field.name} className="whitespace-nowrap">{field.name}</TableHead>)}</TableRow></TableHeader><TableBody>{preview.rows.map((row, index) => <TableRow key={index}>{preview.fields.map((field) => <TableCell key={field.name} className="max-w-56 whitespace-nowrap font-mono text-xs">{row[field.name] === null ? <span className="text-muted-foreground">NULL</span> : String(row[field.name])}</TableCell>)}</TableRow>)}</TableBody></Table></div><p className="text-xs text-muted-foreground">Query results come from the PostgreSQL database running in your browser.</p></CardContent></Card>}
  </div>;
}
