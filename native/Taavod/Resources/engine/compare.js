function normalized(value) {
    if (value instanceof Date)
        return value.toISOString();
    if (typeof value === 'bigint')
        return Number(value);
    if (typeof value === 'number')
        return Number.isFinite(value) ? Math.round(value * 1e7) / 1e7 : String(value);
    if (typeof value === 'string' && /^-?\d+(\.\d+)?$/.test(value))
        return Math.round(Number(value) * 1e7) / 1e7;
    return value;
}
/** Compare multisets, preserving duplicate rows; column aliases and row order do not define correctness. */
export function equivalentResults(actual, expected) {
    if (actual.length !== expected.length)
        return false;
    return actual.every((set, i) => {
        const reference = expected[i];
        if (set.fields.length !== reference.fields.length || set.rows.length !== reference.rows.length)
            return false;
        const rows = (s) => s.rows.map(row => JSON.stringify(s.fields.map(f => normalized(row[f.name])))).sort();
        return JSON.stringify(rows(set)) === JSON.stringify(rows(reference));
    });
}
