export type ProductCategory = 'All products' | 'Software' | 'Services';
export const salesLines = [
  {line: 'L1', order: 'O1', product: 'P1', category: 'Software', amount: 40, orderTotal: 100},
  {line: 'L2', order: 'O1', product: 'P2', category: 'Services', amount: 60, orderTotal: 100},
  {line: 'L3', order: 'O2', product: 'P1', category: 'Software', amount: 80, orderTotal: 80},
] as const;

export function modelGrainResult(category: ProductCategory, mixedGrain: boolean) {
  const rows = salesLines.filter(row => category === 'All products' || row.category === category);
  return {
    rows,
    correctTotal: rows.reduce((sum, row) => sum + row.amount, 0),
    displayedTotal: rows.reduce((sum, row) => sum + (mixedGrain ? row.orderTotal : row.amount), 0),
  };
}
