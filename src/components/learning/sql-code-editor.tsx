'use client';

import { useMemo } from 'react';
import CodeMirror from '@uiw/react-codemirror';
import { EditorView } from '@codemirror/view';
import { PostgreSQL, sql } from '@codemirror/lang-sql';
import { python } from '@codemirror/lang-python';
import { useTheme } from 'next-themes';
import { completionSchema, type PracticeTable } from '@/lib/practice/schema';

export function CodeEditor({
  value,
  onChange,
  onRun,
  labelledBy,
  tables,
  language = 'sql',
  minHeight = '300px',
  readOnly = false,
}: {
  value: string;
  onChange: (value: string) => void;
  onRun: () => void;
  labelledBy: string;
  tables: PracticeTable[];
  language?: 'sql' | 'python';
  minHeight?: string;
  readOnly?: boolean;
}) {
  const { resolvedTheme } = useTheme();
  const dark = resolvedTheme === 'dark';
  const extensions = useMemo(() => [
    language === 'sql' ? sql({ dialect: PostgreSQL, schema: completionSchema(tables), defaultSchema: 'public', upperCaseKeywords: true }) : python(),
    EditorView.theme({
      '&': { color: dark ? '#e5f7fb' : '#102b46', backgroundColor: dark ? '#172433' : '#fff' },
      '.cm-content': { caretColor: '#13b8d5' },
      '.cm-cursor, .cm-dropCursor': { borderLeftColor: '#13b8d5' },
      '&.cm-focused .cm-selectionBackground, ::selection': { backgroundColor: dark ? '#15556a' : '#c8f0f7' },
      '.cm-gutters': { backgroundColor: dark ? '#1a2b3d' : '#f4f8fa', color: dark ? '#91a9b4' : '#647b8d' },
      '.cm-activeLine': { backgroundColor: dark ? '#153343' : '#e5f7fb' },
      '.cm-activeLineGutter': { backgroundColor: 'transparent', color: dark ? '#13b8d5' : '#102b46' },
    }, { dark }),
  ], [dark, language, tables]);

  return <div className="sql-code-editor" aria-labelledby={labelledBy} onKeyDownCapture={event => {
    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
      event.preventDefault();
      event.stopPropagation();
      onRun();
    }
  }}>
    <CodeMirror
      value={value}
      onChange={onChange}
      extensions={extensions}
      readOnly={readOnly}
      editable={!readOnly}
      height={minHeight}
      theme={resolvedTheme === 'dark' ? 'dark' : 'light'}
      basicSetup={{ lineNumbers: true, foldGutter: true, highlightActiveLine: true, tabSize: 2, autocompletion: true }}
      indentWithTab
      aria-label={language === 'sql' ? 'PostgreSQL query editor' : 'Python code editor'}
    />
  </div>;
}
