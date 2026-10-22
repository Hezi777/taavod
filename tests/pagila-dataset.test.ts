import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {PGlite} from '@electric-sql/pglite';
import {describe,it,expect} from 'vitest';

describe('official Pagila exploration dataset',()=>{
 it('loads the shipped core data with actual constraints and reconciles payment lineage',async()=>{
  const sql=await readFile('public/practice/datasets/pagila-core.sql','utf8');
  const manifest=JSON.parse(await readFile('public/practice/datasets/pagila-manifest.json','utf8'));
  expect(createHash('sha256').update(sql).digest('hex')).toBe(manifest.sha256);
  const db=await PGlite.create();
  try {
   await db.exec(sql);
   const result=await db.query<{films:number;rentals:number;payments:number}>("SELECT (SELECT COUNT(*)::int FROM film) films,(SELECT COUNT(*)::int FROM rental) rentals,(SELECT COUNT(*)::int FROM payment) payments");
   expect(result.rows[0]).toEqual({films:1000,rentals:51805,payments:51061});
   const revenue=await db.query<{direct:string;joined:string}>("SELECT (SELECT SUM(amount) FROM payment) direct,(SELECT SUM(p.amount) FROM payment p JOIN rental r USING(rental_id) JOIN inventory i USING(inventory_id) JOIN film f USING(film_id)) joined");
   expect(revenue.rows[0].joined).toBe(revenue.rows[0].direct);
   await expect(db.exec("INSERT INTO film_actor(actor_id,film_id) VALUES(999999,1)")).rejects.toThrow(/foreign key/i);
  } finally {await db.close();}
 },30000);
});
