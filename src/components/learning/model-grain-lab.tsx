'use client';

import {useState} from 'react';
import {Database, Filter, ArrowDown, CheckCircle2, TriangleAlert} from 'lucide-react';
import {Button} from '@/components/ui/button';
import {Card, CardContent} from '@/components/ui/card';
import {Input} from '@/components/ui/input';
import {Label} from '@/components/ui/label';
import {Table, TableHeader, TableHead, TableBody, TableRow, TableCell} from '@/components/ui/table';
import {Select, SelectTrigger, SelectValue, SelectContent, SelectItem} from '@/components/ui/select';
import {modelGrainResult, type ProductCategory} from '@/lib/practice/model-grain';
import './model-grain-lab.css';

/** An explicit arithmetic illustration, separate from executed SQL and saved proficiency. */
export function ModelGrainLab() {
  const [mixed,setMixed]=useState(true);
  const [category,setCategory]=useState<ProductCategory>('All products');
  const [prediction,setPrediction]=useState('');
  const [checked,setChecked]=useState(false);
  const result=modelGrainResult(category,mixed);
  const change=()=>{setChecked(false);setPrediction('')};
  return <Card className="grain-lab"><CardContent>
    <header><span className="grain-icon"><Database size={22}/></span><div><h3>Build a model you can trust</h3><p>A three-row sales illustration. Change the grain and watch the total.</p></div></header>
    <div className="grain-controls"><div role="group" aria-label="Fact grain"><Button variant={mixed?'secondary':'ghost'} size="sm" aria-pressed={mixed} onClick={()=>{setMixed(true);change()}}>Order total on each line</Button><Button variant={!mixed?'secondary':'ghost'} size="sm" aria-pressed={!mixed} onClick={()=>{setMixed(false);change()}}>One amount per order line</Button></div><Select value={category} onValueChange={value=>{setCategory(value as ProductCategory);change()}}><SelectTrigger aria-label="Product category filter"><Filter size={14}/><SelectValue/></SelectTrigger><SelectContent>{(['All products','Software','Services'] as const).map(value=><SelectItem key={value} value={value}>{value}</SelectItem>)}</SelectContent></Select></div>
    <div className="grain-model" aria-label="Star schema: product and date dimensions filter sales lines">
      <div className="grain-dim"><strong>DimProduct</strong><span>ProductKey <b>1</b></span><small>P1 Software · P2 Services</small></div><div className="grain-dim"><strong>DimDate</strong><span>DateKey <b>1</b></span><small>Groups sales by event date</small></div>
      <div className="grain-relationship"><ArrowDown size={18}/><span>Filters many sales lines</span><ArrowDown size={18}/></div>
      <div className="grain-fact"><strong>FactSales <span>*</span></strong><p>One row = one order line</p><small>LineKey · ProductKey · DateKey · {mixed?'OrderTotal (wrong grain)':'LineAmount'}</small></div>
    </div>
    <div className="grain-predict"><Label htmlFor="grain-prediction">Before inspecting: what should valid line revenue be?</Label><div><Input id="grain-prediction" type="number" min="0" inputMode="decimal" placeholder="Your prediction" value={prediction} onChange={event=>{setPrediction(event.target.value);setChecked(false)}}/><Button variant="outline" disabled={!prediction.trim()} onClick={()=>setChecked(true)}>Check prediction</Button></div>{checked&&<p role="status">{Number(prediction)===result.correctTotal?'Correct.':'Try tracing the individual line amounts.'} {result.rows.map(row=>row.amount).join(' + ')} = {result.correctTotal}. Count each business event once.</p>}</div>
    <div className="grain-data"><Table><TableHeader><TableRow><TableHead>Line</TableHead><TableHead>Order</TableHead><TableHead>Category</TableHead><TableHead>Line amount</TableHead><TableHead>Summed measure</TableHead></TableRow></TableHeader><TableBody>{result.rows.map(row=><TableRow key={row.line}><TableCell>{row.line}</TableCell><TableCell>{row.order}</TableCell><TableCell>{row.category}</TableCell><TableCell>{row.amount}</TableCell><TableCell className={mixed?'grain-error':''}>{mixed?row.orderTotal:row.amount}</TableCell></TableRow>)}</TableBody></Table></div>
    <div className={`grain-feedback ${mixed?'grain-feedback-warning':''}`} aria-live="polite">{mixed?<TriangleAlert size={20}/>:<CheckCircle2 size={20}/>}<div><strong>Model total: {result.displayedTotal} <span>Valid line revenue: {result.correctTotal}</span></strong><p>{mixed?category==='All products'?'Order O1 has two lines, so its 100 total is counted twice. Joining an order total to lines does not make it additive at line grain.':'A category filter retains a line, but its order total still includes other lines. A correct relationship cannot repair the wrong measure grain.':'The product dimension filters the fact, then line amounts are summed. Each line contributes exactly once.'}</p></div></div>
    <p className="grain-transfer">Explain it: why would SUM(DISTINCT OrderTotal) still fail when two different orders have the same total? Test your reasoning next in the live SQL workspace.</p>
    <a href="https://learn.microsoft.com/en-us/power-bi/guidance/star-schema" target="_blank" rel="noreferrer">Microsoft: facts, dimensions and grain</a>
  </CardContent></Card>;
}
