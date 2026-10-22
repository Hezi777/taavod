import {describe,it,expect} from 'vitest';
import {modelGrainResult} from '../src/lib/practice/model-grain';
describe('model grain teaching example',()=>{
 it('exposes order fanout when a header amount is repeated across lines',()=>{const result=modelGrainResult('All products',true);expect(result.correctTotal).toBe(180);expect(result.displayedTotal).toBe(280)});
 it('shows why category filtering cannot repair mixed-grain measures',()=>{const result=modelGrainResult('Software',true);expect(result.rows).toHaveLength(2);expect(result.correctTotal).toBe(120);expect(result.displayedTotal).toBe(180)});
 it('keeps line-grain revenue additive after dimension filtering',()=>{for(const category of ['All products','Software','Services'] as const){const result=modelGrainResult(category,false);expect(result.displayedTotal).toBe(result.correctTotal)}expect(modelGrainResult('Services',false).correctTotal).toBe(60)});
});
