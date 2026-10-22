/** Synthetic fixtures intentionally include ties, repeated amounts, missing activity, and cross-store attribution. */
export function sqlFixture(variant = 0): string {
 const extra = variant ? "INSERT INTO payment VALUES (8,2,2,2,4.99,'2026-03-08'), (9,3,1,3,0,'2026-03-09'); INSERT INTO rental VALUES (7,'2026-03-10',2,2,NULL,1),(8,'2026-03-11',999,999,NULL,999); INSERT INTO payment VALUES(10,999,999,999,7.00,'2026-03-11');" : "";
 return `
CREATE TABLE country(country_id int PRIMARY KEY,country text);
CREATE TABLE city(city_id int PRIMARY KEY,city text,country_id int);
CREATE TABLE address(address_id int PRIMARY KEY,address text,address2 text,district text,city_id int,postal_code text);
CREATE TABLE store(store_id int PRIMARY KEY,manager_staff_id int,address_id int);
CREATE TABLE staff(staff_id int PRIMARY KEY,first_name text,last_name text,store_id int,address_id int);
CREATE TABLE language(language_id int PRIMARY KEY,name text);
CREATE TABLE customer(customer_id int PRIMARY KEY,store_id int,first_name text,last_name text,email text,address_id int,activebool boolean);
CREATE TABLE film(film_id int PRIMARY KEY,title text,rating text,length int,rental_rate numeric, replacement_cost numeric,language_id int,original_language_id int);
CREATE TABLE actor(actor_id int PRIMARY KEY,first_name text,last_name text);
CREATE TABLE category(category_id int PRIMARY KEY,name text);
CREATE TABLE film_actor(actor_id int,film_id int,PRIMARY KEY(actor_id,film_id));
CREATE TABLE film_category(film_id int,category_id int,PRIMARY KEY(film_id,category_id));
CREATE TABLE inventory(inventory_id int PRIMARY KEY,film_id int,store_id int);
CREATE TABLE rental(rental_id int PRIMARY KEY,rental_date timestamp,inventory_id int,customer_id int,return_date timestamp,staff_id int);
CREATE TABLE payment(payment_id int PRIMARY KEY,customer_id int,staff_id int,rental_id int,amount numeric,payment_date timestamp);
INSERT INTO country VALUES (1,'Israel'),(2,'United Kingdom');
INSERT INTO city VALUES(1,'Tel Aviv',1),(2,'Haifa',1),(3,'London',2);
INSERT INTO address VALUES(1,'1 Cedar St',NULL,'Central',1,'1000'),(2,'2 Pine St','','North',2,'2000'),(3,'3 Oak St',NULL,'Central',3,NULL);
INSERT INTO store VALUES(1,1,1),(2,2,2);
INSERT INTO staff VALUES(1,'Dana','Levi',1,1),(2,'Alex','Green',2,2);
INSERT INTO language VALUES(1,'English'),(2,'Hebrew');
INSERT INTO customer VALUES(1,1,'Ari','Levi','ari@example.test',1,true),(2,1,'Noa','Cohen','noa@example.test',2,true),(3,2,'Sam','Green','sam@example.test',3,true),(4,2,'Mika','Day','mika@example.test',1,false),(5,1,'Lee','Fox','lee@example.test',1,true),(6,2,'Jo','Stone','jo@example.test',2,true);
INSERT INTO film VALUES(1,'Blue Horizon','PG',130,2.99,20,1,NULL),(2,'Quiet City','G',125,1.99,15,2,NULL),(3,'Red Dune','R',90,4.99,25,1,NULL),(4,'Zero Inventory','PG',140,2.99,18,1,NULL),(5,'Long Journey','PG',130,2.49,18,1,2);
INSERT INTO actor VALUES(1,'Pat','Ash'),(2,'Kai','Lake'),(3,'Kim','Reed');
INSERT INTO category VALUES(1,'Drama'),(2,'Comedy'),(3,'Documentary'),(4,'Empty category');
INSERT INTO film_actor VALUES(1,1),(2,1),(2,2),(3,3),(1,5),(3,5);
INSERT INTO film_category VALUES(1,1),(1,2),(2,2),(3,1),(4,3),(5,3);
INSERT INTO inventory VALUES(1,1,1),(2,1,1),(3,1,2),(4,2,1),(5,3,2),(6,5,2);
INSERT INTO rental VALUES(1,'2026-01-01',1,1,'2026-01-03',1),(2,'2026-01-05',2,2,'2026-01-07',1),(3,'2026-02-01',3,3,NULL,2),(4,'2026-02-01',4,1,'2026-02-02',1),(5,'2026-03-05',5,4,'2026-03-01',2),(6,'2026-03-05',1,1,NULL,1);
INSERT INTO payment VALUES(1,1,1,1,4.99,'2026-01-01'),(2,1,1,1,4.99,'2026-01-02'),(3,2,1,2,9.98,'2026-01-05'),(4,3,1,3,3.00,'2026-02-01'),(5,1,1,4,2.00,'2026-02-01'),(6,4,2,5,0,'2026-03-04'),(7,2,1,6,1.00,'2026-03-05');
${extra}
`;
}
export const schemaGuide = `Synthetic Pagila-style tables (not the complete Pagila dataset):
film(film_id PK, title, rating, length, rental_rate, replacement_cost, language_id, original_language_id)
inventory(inventory_id PK, film_id, store_id)
rental(rental_id PK, rental_date, inventory_id, customer_id, return_date, staff_id)
payment(payment_id PK, customer_id, staff_id, rental_id, amount, payment_date)
customer(customer_id PK, store_id, first_name, last_name, email, address_id, activebool)
store(store_id PK, manager_staff_id, address_id)
staff(staff_id PK, first_name, last_name, store_id, address_id)
actor(actor_id PK, first_name, last_name)
film_actor(actor_id + film_id composite PK)
category(category_id PK, name)
film_category(film_id + category_id composite PK)
language(language_id PK, name)
address(address_id PK, address, address2, district, city_id, postal_code)
city(city_id PK, city, country_id)
country(country_id PK, country)
Columns sharing *_id names indicate relationships to the corresponding primary key. Constraints on relationships are deliberately not enforced so validation scenarios can be explored. Payment 7 disagrees with its rental customer; rental 5 has a return before rental; the first fixture has no orphans; the second introduces invalid references. Payment is an ordinary table here; partitioning questions refer to the original Pagila schema. Dates are fixed in 2026. The second check adds records to catch fixed-output answers.`;
