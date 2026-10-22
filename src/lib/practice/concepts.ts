export const sourcePayments = [{id:'P1',amount:40},{id:'P2',amount:60}];
export type PaymentRow = {id:string;amount:number};
export function loadPayments(current:PaymentRow[],incoming:PaymentRow[],upsert:boolean):PaymentRow[]{
 if(!upsert)return [...current,...incoming];
 const rows=new Map(current.map(row=>[row.id,row]));
 for(const row of incoming)rows.set(row.id,row);
 return [...rows.values()];
}
export function combinedConversion(aConverted:number,aEligible:number,bConverted:number,bEligible:number){
 return {weighted:(aConverted+bConverted)/(aEligible+bEligible),unweighted:(aConverted/aEligible+bConverted/bEligible)/2};
}
