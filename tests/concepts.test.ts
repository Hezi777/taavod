import {describe,it,expect} from 'vitest';
import {loadPayments,sourcePayments,combinedConversion} from '../src/lib/practice/concepts';
describe('interactive BI reasoning',()=>{
 it('demonstrates safe replay and late corrections with stable keys',()=>{let rows=loadPayments([],sourcePayments,true);rows=loadPayments(rows,sourcePayments,true);expect(rows).toEqual(sourcePayments);rows=loadPayments(rows,[{id:'P1',amount:45}],true);expect(rows).toHaveLength(2);expect(rows.reduce((sum,row)=>sum+row.amount,0)).toBe(105)});
 it('exposes append duplication without mutating source data',()=>{const initial=loadPayments([],sourcePayments,false);expect(loadPayments(initial,sourcePayments,false)).toHaveLength(4);expect(initial).toHaveLength(2);expect(sourcePayments[0].amount).toBe(40)});
 it('distinguishes visitor-level conversion from an equal-store average',()=>{const result=combinedConversion(1,2,90,100);expect(result.weighted).toBeCloseTo(91/102);expect(result.unweighted).toBe(.7)});
});
