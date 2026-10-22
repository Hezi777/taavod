import type { Exercise } from "@/lib/curriculum";

export const pagilaExercises: Exercise[] = [
  {
    "id": "pagila-schema-and-grain-1",
    "skillId": "sql",
    "title": "Business process",
    "prompt": "Describe the business process represented by `film`, `inventory`, `rental`, and `payment`. Explain why these four tables cannot be collapsed into one concept.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "- `film`: one title offered by the business. It describes the product, not an individual copy.\n- `inventory`: one physical copy of a film held at one store.\n- `rental`: one event in which a customer rents one inventory copy.\n- `payment`: one monetary transaction associated with a customer, rental, and staff member.\nOne film can have many copies, one copy can be rented many times over time, and one rental can be referenced by payment activity. Combining these grains would repeat film and inventory attributes and make event counts unreliable.",
    "explanation": "- `film`: one title offered by the business. It describes the product, not an individual copy.\n- `inventory`: one physical copy of a film held at one store.\n- `rental`: one event in which a customer rents one inventory copy.\n- `payment`: one monetary transaction associated with a customer, rental, and staff member.\nOne film can have many copies, one copy can be rented many times over time, and one rental can be referenced by payment activity. Combining these grains would repeat film and inventory attributes and make event counts unreliable.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-2",
    "skillId": "sql",
    "title": "Entity grains",
    "prompt": "State the grain and primary key of every main table:\n\n`actor`, `film`, `category`, `language`, `film_actor`, `film_category`, `store`, `staff`, `customer`, `country`, `city`, `address`, `inventory`, `rental`, and `payment`.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "| Table | One row represents | Primary key | Important foreign keys |\n|---|---|---|---|\n| `actor` | one actor | `actor_id` | — |\n| `film` | one film title | `film_id` | `language_id`, `original_language_id` |\n| `category` | one film category | `category_id` | — |\n| `language` | one language | `language_id` | — |\n| `film_actor` | one actor–film association | (`actor_id`, `film_id`) | both columns |\n| `film_category` | one film–category association | (`film_id`, `category_id`) | both columns |\n| `store` | one store | `store_id` | `manager_staff_id`, `address_id` |\n| `staff` | one staff member | `staff_id` | `store_id`, `address_id` |\n| `customer` | one customer | `customer_id` | `store_id`, `address_id` |\n| `country` | one country | `country_id` | — |\n| `city` | one city record | `city_id` | `country_id` |\n| `address` | one address record | `address_id` | `city_id` |\n| `inventory` | one physical film copy | `inventory_id` | `film_id`, `store_id` |\n| `rental` | one rental event | `rental_id` | `inventory_id`, `customer_id`, `staff_id` |\n| `payment` | one payment transaction | `payment_id` | `customer_id`, `rental_id`, `staff_id` |\nMost parent-to-child relationships above are one-to-many. `store.manager_staff_id` is a special manager relationship rather than the same relationship as `staff.store_id`.",
    "explanation": "| Table | One row represents | Primary key | Important foreign keys |\n|---|---|---|---|\n| `actor` | one actor | `actor_id` | — |\n| `film` | one film title | `film_id` | `language_id`, `original_language_id` |\n| `category` | one film category | `category_id` | — |\n| `language` | one language | `language_id` | — |\n| `film_actor` | one actor–film association | (`actor_id`, `film_id`) | both columns |\n| `film_category` | one film–category association | (`film_id`, `category_id`) | both columns |\n| `store` | one store | `store_id` | `manager_staff_id`, `address_id` |\n| `staff` | one staff member | `staff_id` | `store_id`, `address_id` |\n| `customer` | one customer | `customer_id` | `store_id`, `address_id` |\n| `country` | one country | `country_id` | — |\n| `city` | one city record | `city_id` | `country_id` |\n| `address` | one address record | `address_id` | `city_id` |\n| `inventory` | one physical film copy | `inventory_id` | `film_id`, `store_id` |\n| `rental` | one rental event | `rental_id` | `inventory_id`, `customer_id`, `staff_id` |\n| `payment` | one payment transaction | `payment_id` | `customer_id`, `rental_id`, `staff_id` |\nMost parent-to-child relationships above are one-to-many. `store.manager_staff_id` is a special manager relationship rather than the same relationship as `staff.store_id`.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-3",
    "skillId": "sql",
    "title": "Bridge tables",
    "prompt": "Identify Pagila's many-to-many relationships. Name the bridge table used for each and explain what would go wrong if you joined both bridges to `film` and immediately counted films.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "- Actors and films are many-to-many through `film_actor`.\n- Films and categories are many-to-many in the schema through `film_category`, even if the loaded data currently assigns only one category to a film.\nJoining both bridges gives one row per film–actor–category combination. Counting rows would count combinations, not films. Use `COUNT(DISTINCT film_id)` when that is truly the intended metric, or aggregate each many-side independently before joining.",
    "explanation": "- Actors and films are many-to-many through `film_actor`.\n- Films and categories are many-to-many in the schema through `film_category`, even if the loaded data currently assigns only one category to a film.\nJoining both bridges gives one row per film–actor–category combination. Counting rows would count combinations, not films. Use `COUNT(DISTINCT film_id)` when that is truly the intended metric, or aggregate each many-side independently before joining.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-4",
    "skillId": "sql",
    "title": "Payment lineage",
    "prompt": "Starting from one payment, trace how you would identify its customer, rental, inventory copy, film, category, store, and staff member. Note where more than one reasonable definition of “store” exists.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "- Payment → customer: `payment.customer_id = customer.customer_id`\n- Payment → rental: `payment.rental_id = rental.rental_id`\n- Rental → inventory copy: `rental.inventory_id = inventory.inventory_id`\n- Inventory → film: `inventory.film_id = film.film_id`\n- Film → category: through `film_category`, then `category`\n- Payment → processing staff member: `payment.staff_id = staff.staff_id`\n- Rental → rental staff member: `rental.staff_id = staff.staff_id`\n“Store” can mean the store holding the inventory (`inventory.store_id`), the payment staff member's home store (`staff.store_id`), or the customer's home store (`customer.store_id`). Choose based on the business question and name the definition.",
    "explanation": "- Payment → customer: `payment.customer_id = customer.customer_id`\n- Payment → rental: `payment.rental_id = rental.rental_id`\n- Rental → inventory copy: `rental.inventory_id = inventory.inventory_id`\n- Inventory → film: `inventory.film_id = film.film_id`\n- Film → category: through `film_category`, then `category`\n- Payment → processing staff member: `payment.staff_id = staff.staff_id`\n- Rental → rental staff member: `rental.staff_id = staff.staff_id`\n“Store” can mean the store holding the inventory (`inventory.store_id`), the payment staff member's home store (`staff.store_id`), or the customer's home store (`customer.store_id`). Choose based on the business question and name the definition.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-5",
    "skillId": "sql",
    "title": "Customer geography",
    "prompt": "Trace the path from a customer to their city and country. Explain why grouping customers by `address.district` alone could be ambiguous.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "The path is `customer → address → city → country`. District names are not guaranteed to be globally unique, so grouping by district alone can merge unrelated places. Include city/country keys or names appropriate to the required geography.",
    "explanation": "The path is `customer → address → city → country`. District names are not guaranteed to be globally unique, so grouping by district alone can merge unrelated places. Include city/country keys or names appropriate to the required geography.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-6",
    "skillId": "sql",
    "title": "Optional relationships and nulls",
    "prompt": "Find relationships or attributes that may legitimately be absent. Explain how an inner join could silently remove those records.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "Examples include:\n- `film.original_language_id` may be null;\n- `address.address2` and `address.postal_code` may be empty or null;\n- `rental.return_date` may be null for an unreturned rental;\n- a film may have no inventory;\n- a customer could have no payments or rentals.\nAn inner join retains only matched rows. Use a left join when the business question requires retaining the entity on the left despite a missing optional relationship.",
    "explanation": "Examples include:\n- `film.original_language_id` may be null;\n- `address.address2` and `address.postal_code` may be empty or null;\n- `rental.return_date` may be null for an unreturned rental;\n- a film may have no inventory;\n- a customer could have no payments or rentals.\nAn inner join retains only matched rows. Use a left join when the business question requires retaining the entity on the left despite a missing optional relationship.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-7",
    "skillId": "sql",
    "title": "Payment partitions",
    "prompt": "DataGrip shows `payment` plus tables named `payment_p2020_01` through `payment_p2020_06`. Explain their relationship and which object analysts should normally query.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "`payment` is the partitioned parent table. Each `payment_p2020_MM` table stores rows for one month. Analysts should normally query `payment`; PostgreSQL routes the query to relevant partitions and returns them as one logical table.",
    "explanation": "`payment` is the partitioned parent table. Each `payment_p2020_MM` table stores rows for one month. Analysts should normally query `payment`; PostgreSQL routes the query to relevant partitions and returns them as one logical table.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-schema-and-grain-8",
    "skillId": "sql",
    "title": "Join-multiplication prediction",
    "prompt": "Before running anything, predict the grain produced by joining:\n\n`film → film_actor → actor` and `film → film_category → category`.\n\nThen explain why summing a film-level value such as `replacement_cost` after that join can be incorrect.\n\nUse the schema guide. Explain assumptions and grain before choosing joins.",
    "kind": "written",
    "difficulty": "Foundation",
    "minutes": 10,
    "starter": "",
    "solution": "The result grain is one film–actor–category association. A film-level value repeats once for every resulting actor/category combination. Summing `replacement_cost` at that grain overstates the film-level total. Aggregate to film grain before joining, or select one row per film before summing.",
    "explanation": "The result grain is one film–actor–category association. A film-level value repeats once for every resulting actor/category combination. Summing `replacement_cost` at that grain overstates the film-level total. Aggregate to film grain before joining, or select one row per film before summing.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-1",
    "skillId": "sql",
    "title": "Active customer directory",
    "prompt": "Return one row per active customer with customer ID, full name, email, home store, street address, district, city, and country. Sort by customer ID.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    c.customer_id,\n    concat_ws(' ', c.first_name, c.last_name) AS customer_name,\n    c.email,\n    c.store_id AS home_store_id,\n    a.address,\n    a.district,\n    ci.city,\n    co.country\nFROM customer AS c\nJOIN address AS a ON a.address_id = c.address_id\nJOIN city AS ci ON ci.city_id = a.city_id\nJOIN country AS co ON co.country_id = ci.country_id\nWHERE c.activebool\nORDER BY c.customer_id;",
    "explanation": "Grain: one row per active customer.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-2",
    "skillId": "sql",
    "title": "Film selection",
    "prompt": "Return films at least 120 minutes long with a rental rate below 3. Include film ID, title, rating, length, and rental rate. Sort longest first, then by title.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT film_id, title, rating, length, rental_rate\nFROM film\nWHERE length >= 120\n  AND rental_rate < 3\nORDER BY length DESC, title;",
    "explanation": "Grain: one row per film.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-3",
    "skillId": "sql",
    "title": "Category catalogue size",
    "prompt": "Return one row per category with its number of films. Include categories with no films and sort from largest to smallest.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    c.category_id,\n    c.name AS category_name,\n    COUNT(fc.film_id) AS film_count\nFROM category AS c\nLEFT JOIN film_category AS fc ON fc.category_id = c.category_id\nGROUP BY c.category_id, c.name\nORDER BY film_count DESC, c.name;",
    "explanation": "Grain: one row per category.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-4",
    "skillId": "sql",
    "title": "Store inventory",
    "prompt": "Return one row per store and film held there, including store ID, film ID, title, and number of physical copies. Sort by store and title.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    i.store_id,\n    f.film_id,\n    f.title,\n    COUNT(*) AS copy_count\nFROM inventory AS i\nJOIN film AS f ON f.film_id = i.film_id\nGROUP BY i.store_id, f.film_id, f.title\nORDER BY i.store_id, f.title;",
    "explanation": "Grain: one row per store–film combination that has inventory.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-5",
    "skillId": "sql",
    "title": "Films without inventory",
    "prompt": "Return every film that has no physical inventory copy in any store. Include film ID and title.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT f.film_id, f.title\nFROM film AS f\nLEFT JOIN inventory AS i ON i.film_id = f.film_id\nWHERE i.inventory_id IS NULL\nORDER BY f.title;",
    "explanation": "Grain: one row per film with no inventory.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-6",
    "skillId": "sql",
    "title": "Monthly payment activity",
    "prompt": "Return one row per calendar month with total revenue, payment transaction count, paying customer count, and average payment amount.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    date_trunc('month', payment_date)::date AS payment_month,\n    SUM(amount) AS revenue,\n    COUNT(*) AS payment_count,\n    COUNT(DISTINCT customer_id) AS paying_customer_count,\n    AVG(amount) AS average_payment\nFROM payment\nGROUP BY date_trunc('month', payment_date)::date\nORDER BY payment_month;",
    "explanation": "Grain: one row per calendar month.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-7",
    "skillId": "sql",
    "title": "Customer value",
    "prompt": "Return one row per customer with total revenue, payment count, and average payment. Include customers with no payments. Rank customers by total revenue without arbitrarily breaking ties.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH customer_value AS (\n    SELECT\n        c.customer_id,\n        concat_ws(' ', c.first_name, c.last_name) AS customer_name,\n        COALESCE(SUM(p.amount), 0) AS revenue,\n        COUNT(p.payment_id) AS payment_count,\n        AVG(p.amount) AS average_payment\n    FROM customer AS c\n    LEFT JOIN payment AS p ON p.customer_id = c.customer_id\n    GROUP BY c.customer_id, c.first_name, c.last_name\n)\nSELECT\n    customer_id,\n    customer_name,\n    revenue,\n    payment_count,\n    average_payment,\n    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank\nFROM customer_value\nORDER BY revenue_rank, customer_id;",
    "explanation": "Grain: one row per customer.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-8",
    "skillId": "sql",
    "title": "Latest rental",
    "prompt": "Return every customer and their latest rental, if any. Include customer ID, full name, rental ID, rental date, film title, and return date. Return exactly one row per customer.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH ranked_rentals AS (\n    SELECT\n        r.*,\n        ROW_NUMBER() OVER (\n            PARTITION BY r.customer_id\n            ORDER BY r.rental_date DESC, r.rental_id DESC\n        ) AS rental_recency\n    FROM rental AS r\n)\nSELECT\n    c.customer_id,\n    concat_ws(' ', c.first_name, c.last_name) AS customer_name,\n    rr.rental_id,\n    rr.rental_date,\n    f.title,\n    rr.return_date\nFROM customer AS c\nLEFT JOIN ranked_rentals AS rr\n    ON rr.customer_id = c.customer_id\n   AND rr.rental_recency = 1\nLEFT JOIN inventory AS i ON i.inventory_id = rr.inventory_id\nLEFT JOIN film AS f ON f.film_id = i.film_id\nORDER BY c.customer_id;",
    "explanation": "Grain: one row per customer.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-9",
    "skillId": "sql",
    "title": "Top customers within each store",
    "prompt": "Using each customer's home store, return the three highest revenue ranks per store. Preserve ties. Include store, customer, total revenue, and rank.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH customer_revenue AS (\n    SELECT\n        c.store_id,\n        c.customer_id,\n        concat_ws(' ', c.first_name, c.last_name) AS customer_name,\n        COALESCE(SUM(p.amount), 0) AS revenue\n    FROM customer AS c\n    LEFT JOIN payment AS p ON p.customer_id = c.customer_id\n    GROUP BY c.store_id, c.customer_id, c.first_name, c.last_name\n), ranked AS (\n    SELECT\n        *,\n        DENSE_RANK() OVER (\n            PARTITION BY store_id\n            ORDER BY revenue DESC\n        ) AS store_revenue_rank\n    FROM customer_revenue\n)\nSELECT store_id, customer_id, customer_name, revenue, store_revenue_rank\nFROM ranked\nWHERE store_revenue_rank <= 3\nORDER BY store_id, store_revenue_rank, customer_id;",
    "explanation": "Grain: one row per qualifying customer.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-querying-and-joins-10",
    "skillId": "sql",
    "title": "Running and month-over-month revenue",
    "prompt": "Produce two results:\n\n- daily revenue with a cumulative running total;\n- monthly revenue with previous-month revenue, absolute change, and percentage change.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Applied",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH daily_revenue AS (\n    SELECT\n        payment_date::date AS payment_day,\n        SUM(amount) AS revenue\n    FROM payment\n    GROUP BY payment_date::date\n)\nSELECT\n    payment_day,\n    revenue,\n    SUM(revenue) OVER (ORDER BY payment_day) AS cumulative_revenue\nFROM daily_revenue\nORDER BY payment_day;\n\n\nWITH monthly_revenue AS (\n    SELECT\n        date_trunc('month', payment_date)::date AS payment_month,\n        SUM(amount) AS revenue\n    FROM payment\n    GROUP BY date_trunc('month', payment_date)::date\n), compared AS (\n    SELECT\n        payment_month,\n        revenue,\n        LAG(revenue) OVER (ORDER BY payment_month) AS previous_month_revenue\n    FROM monthly_revenue\n)\nSELECT\n    payment_month,\n    revenue,\n    previous_month_revenue,\n    revenue - previous_month_revenue AS absolute_change,\n    100.0 * (revenue - previous_month_revenue)\n        / NULLIF(previous_month_revenue, 0) AS percentage_change\nFROM compared\nORDER BY payment_month;",
    "explanation": "Daily grain:\nMonthly grain:",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-1",
    "skillId": "sql",
    "title": "Revenue multiplication",
    "prompt": "Demonstrate how joining payments through films to actors can inflate revenue. Then calculate revenue by film correctly while still including actor count.\n\nExplain why `SUM(DISTINCT payment.amount)` is not a valid general repair.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH film_revenue AS (\n    SELECT\n        i.film_id,\n        SUM(p.amount) AS revenue\n    FROM payment AS p\n    JOIN rental AS r ON r.rental_id = p.rental_id\n    JOIN inventory AS i ON i.inventory_id = r.inventory_id\n    GROUP BY i.film_id\n), film_actor_count AS (\n    SELECT film_id, COUNT(*) AS actor_count\n    FROM film_actor\n    GROUP BY film_id\n)\nSELECT\n    f.film_id,\n    f.title,\n    COALESCE(fr.revenue, 0) AS revenue,\n    COALESCE(fac.actor_count, 0) AS actor_count\nFROM film AS f\nLEFT JOIN film_revenue AS fr ON fr.film_id = f.film_id\nLEFT JOIN film_actor_count AS fac ON fac.film_id = f.film_id\nORDER BY f.film_id;",
    "explanation": "This intentionally incorrect calculation repeats each payment once per actor in its film:\nAggregate revenue and actor count separately at film grain, then join:\n`SUM(DISTINCT amount)` removes equal numeric amounts even when they belong to different legitimate payments. It deduplicates values, not business events.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-2",
    "skillId": "sql",
    "title": "Customer consistency",
    "prompt": "Check whether the customer stored on each payment agrees with the customer stored on its referenced rental. Return the offending records, not just a count.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    p.payment_id,\n    p.customer_id AS payment_customer_id,\n    r.rental_id,\n    r.customer_id AS rental_customer_id\nFROM payment AS p\nJOIN rental AS r ON r.rental_id = p.rental_id\nWHERE p.customer_id IS DISTINCT FROM r.customer_id\nORDER BY p.payment_id;",
    "explanation": "Expected grain: one row per inconsistent payment.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-3",
    "skillId": "sql",
    "title": "Orphan checks",
    "prompt": "Check these relationships for missing parents:\n\n- rental to customer;\n- rental to inventory;\n- payment to customer;\n- payment to rental;\n- payment to staff.\n\nReturn one summary with the relationship name and orphan count.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT 'rental → customer' AS relationship, COUNT(*) AS orphan_count\nFROM rental AS r\nLEFT JOIN customer AS c ON c.customer_id = r.customer_id\nWHERE c.customer_id IS NULL\n\nUNION ALL\n\nSELECT 'rental → inventory', COUNT(*)\nFROM rental AS r\nLEFT JOIN inventory AS i ON i.inventory_id = r.inventory_id\nWHERE i.inventory_id IS NULL\n\nUNION ALL\n\nSELECT 'payment → customer', COUNT(*)\nFROM payment AS p\nLEFT JOIN customer AS c ON c.customer_id = p.customer_id\nWHERE c.customer_id IS NULL\n\nUNION ALL\n\nSELECT 'payment → rental', COUNT(*)\nFROM payment AS p\nLEFT JOIN rental AS r ON r.rental_id = p.rental_id\nWHERE r.rental_id IS NULL\n\nUNION ALL\n\nSELECT 'payment → staff', COUNT(*)\nFROM payment AS p\nLEFT JOIN staff AS s ON s.staff_id = p.staff_id\nWHERE s.staff_id IS NULL\nORDER BY relationship;",
    "explanation": "Expected grain: one row per tested relationship.\nForeign keys should prevent these cases under normal enforcement. The checks remain useful when working with imported, staged, or weakly constrained data.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-4",
    "skillId": "sql",
    "title": "Date validity",
    "prompt": "Find impossible or suspicious sequences involving rental date, return date, and payment date. Define what you consider impossible separately from what you consider merely suspicious.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT rental_id, rental_date, return_date\nFROM rental\nWHERE return_date < rental_date\nORDER BY rental_id;\n\n\nSELECT\n    p.payment_id,\n    p.payment_date,\n    r.rental_id,\n    r.rental_date\nFROM payment AS p\nJOIN rental AS r ON r.rental_id = p.rental_id\nWHERE p.payment_date < r.rental_date\nORDER BY p.payment_id;",
    "explanation": "An impossible sequence under the usual business rules is a return before its rental:\nA payment before its referenced rental is also inconsistent if payment is expected at or after rental creation:\nA null `return_date` is not inherently invalid; it may mean the item is still out. Very long rental durations are suspicious rather than automatically impossible and require a business threshold.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-5",
    "skillId": "sql",
    "title": "Independent revenue checks",
    "prompt": "Calculate total payment revenue in at least two independently structured ways. The methods should agree when the relationships are valid. Explain what a difference would imply.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT 'direct payment total' AS method, SUM(amount) AS revenue\nFROM payment\n\nUNION ALL\n\nSELECT 'payments joined to rentals', SUM(p.amount)\nFROM rental AS r\nJOIN payment AS p ON p.rental_id = r.rental_id;",
    "explanation": "The first method reads payments directly. The second reaches payments through their rentals:\nIf totals differ, investigate orphaned payments, rentals associated with multiple payments, unexpected join cardinality, or filtering differences. Agreement does not prove every individual row is correct, so pair this with relationship checks.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-6",
    "skillId": "sql",
    "title": "Competing store definitions",
    "prompt": "Compare store performance using:\n\n- revenue attributed to the staff member's home store;\n- revenue attributed to the store that held the rented inventory;\n- number of customers whose home store is that store.\n\nDo the revenue definitions agree? Explain why they might not in another dataset.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH staff_store_revenue AS (\n    SELECT s.store_id, SUM(p.amount) AS revenue\n    FROM payment AS p\n    JOIN staff AS s ON s.staff_id = p.staff_id\n    GROUP BY s.store_id\n), inventory_store_revenue AS (\n    SELECT i.store_id, SUM(p.amount) AS revenue\n    FROM payment AS p\n    JOIN rental AS r ON r.rental_id = p.rental_id\n    JOIN inventory AS i ON i.inventory_id = r.inventory_id\n    GROUP BY i.store_id\n), home_store_customers AS (\n    SELECT store_id, COUNT(*) AS customer_count\n    FROM customer\n    GROUP BY store_id\n)\nSELECT\n    s.store_id,\n    ssr.revenue AS staff_store_revenue,\n    isr.revenue AS inventory_store_revenue,\n    hsc.customer_count AS home_store_customer_count\nFROM store AS s\nLEFT JOIN staff_store_revenue AS ssr ON ssr.store_id = s.store_id\nLEFT JOIN inventory_store_revenue AS isr ON isr.store_id = s.store_id\nLEFT JOIN home_store_customers AS hsc ON hsc.store_id = s.store_id\nORDER BY s.store_id;",
    "explanation": "Expected grain: one row per store definition and store.\nThe revenue definitions agree only if payment-processing staff always belong to the store that supplied the rented copy. Cross-store work, reassignment, or data errors would make them differ. Customer count is a population measure, not a revenue measure.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-7",
    "skillId": "sql",
    "title": "Inactive customers",
    "prompt": "Define inactivity in at least two reasonable ways. Do not compare this historical dataset with today's date; anchor relative definitions to the latest rental date in the data. Compare the populations produced by your definitions.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH reference_date AS (\n    SELECT MAX(rental_date) AS latest_rental_date\n    FROM rental\n), customer_activity AS (\n    SELECT\n        c.customer_id,\n        MAX(r.rental_date) AS latest_customer_rental\n    FROM customer AS c\n    LEFT JOIN rental AS r ON r.customer_id = c.customer_id\n    GROUP BY c.customer_id\n)\nSELECT\n    COUNT(*) FILTER (\n        WHERE latest_customer_rental IS NULL\n    ) AS never_rented,\n    COUNT(*) FILTER (\n        WHERE latest_customer_rental < latest_rental_date - INTERVAL '30 days'\n    ) AS no_rental_in_last_30_dataset_days,\n    COUNT(*) FILTER (\n        WHERE latest_customer_rental < latest_rental_date - INTERVAL '90 days'\n    ) AS no_rental_in_last_90_dataset_days\nFROM customer_activity\nCROSS JOIN reference_date;",
    "explanation": "These definitions use the dataset's latest rental date as the reference point:\nThe right definition depends on the decision. A re-engagement campaign, churn report, and account-status rule may need different thresholds and eligibility criteria.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-8",
    "skillId": "sql",
    "title": "Demand versus supply",
    "prompt": "For each store and film with inventory, calculate physical copy count, rental count, and rentals per copy. Keep demand and supply aggregations separate until their grains match. Explain what the result can and cannot prove about understocking.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "WITH supply AS (\n    SELECT\n        store_id,\n        film_id,\n        COUNT(*) AS copy_count\n    FROM inventory\n    GROUP BY store_id, film_id\n), demand AS (\n    SELECT\n        i.store_id,\n        i.film_id,\n        COUNT(*) AS rental_count\n    FROM rental AS r\n    JOIN inventory AS i ON i.inventory_id = r.inventory_id\n    GROUP BY i.store_id, i.film_id\n)\nSELECT\n    s.store_id,\n    s.film_id,\n    f.title,\n    s.copy_count,\n    COALESCE(d.rental_count, 0) AS rental_count,\n    COALESCE(d.rental_count, 0)::numeric / NULLIF(s.copy_count, 0)\n        AS rentals_per_copy\nFROM supply AS s\nJOIN film AS f ON f.film_id = s.film_id\nLEFT JOIN demand AS d\n    ON d.store_id = s.store_id\n   AND d.film_id = s.film_id\nORDER BY rentals_per_copy DESC, s.store_id, f.title;",
    "explanation": "Supply and demand are each aggregated to store–film grain before joining:\nHigh rentals per copy can flag candidates for investigation. It does not prove lost demand or profitability because Pagila lacks rejected requests, wait times, acquisition costs, and a causal estimate of how extra copies would affect rentals.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  },
  {
    "id": "pagila-analysis-and-validation-9",
    "skillId": "sql",
    "title": "Count semantics",
    "prompt": "Using a left join between customers and payments, demonstrate when `COUNT(*)`, `COUNT(payment_id)`, and `COUNT(DISTINCT rental_id)` answer different questions.\n\nUse the synthetic Pagila-style fixture, not the original full Pagila database. Return the columns and result sets shown in the reference after attempting independently.",
    "kind": "sql",
    "difficulty": "Stretch",
    "minutes": 18,
    "starter": "-- Define your output grain first.\nSELECT * FROM film LIMIT 5;",
    "solution": "SELECT\n    c.customer_id,\n    COUNT(*) AS joined_row_count,\n    COUNT(p.payment_id) AS payment_count,\n    COUNT(DISTINCT p.rental_id) AS paid_rental_count\nFROM customer AS c\nLEFT JOIN payment AS p ON p.customer_id = c.customer_id\nGROUP BY c.customer_id\nORDER BY c.customer_id;",
    "explanation": "Expected grain: one row per customer.\n- `COUNT(*)` counts the left-join placeholder row even when a customer has no payment.\n- `COUNT(payment_id)` counts matched non-null payment IDs.\n- `COUNT(DISTINCT rental_id)` counts distinct rentals represented by those payments, which can differ if a rental has multiple payment rows.",
    "hints": [
      "Identify what one output row represents.",
      "Trace the relationship path in the schema; aggregate each many-side before joining.",
      "Check rows without matches, duplicate amounts, and tied ranks."
    ],
    "rubric": [
      "State the output grain and chosen business definition.",
      "Explain the relationship path and treatment of missing values.",
      "Validate with an independent total or edge case."
    ],
    "source": "Adapted from Career/analyst-job-prep SQL prompts and answer keys."
  }
];

// State the result contract before practice; learners should never have to reveal
// a reference solution just to discover the required output columns.
const resultContracts: Record<string,string> = {
 'pagila-querying-and-joins-1':'customer_id, full customer name (first + last, separated by a space), email, home store ID, street address, district, city, country.',
 'pagila-querying-and-joins-2':'film_id, title, rating, length, rental_rate.',
 'pagila-querying-and-joins-3':'category_id, category name, film count. Include empty categories with 0.',
 'pagila-querying-and-joins-4':'store_id, film_id, title, physical copy count. Only observed store/film combinations are needed.',
 'pagila-querying-and-joins-5':'film_id, title. Include films for which no inventory copy exists.',
 'pagila-querying-and-joins-6':'month as a date (first day), revenue, payment count, distinct paying customer count, average payment.',
 'pagila-querying-and-joins-7':'customer_id, full customer name, revenue, payment count, average payment, dense revenue rank. Non-payers have revenue 0, count 0 and average NULL.',
 'pagila-querying-and-joins-8':'customer_id, full customer name, rental_id, rental_date, film title, return_date. Include customers with no rental; break same-date ties by larger rental_id.',
 'pagila-querying-and-joins-9':'home store_id, customer_id, full customer name, revenue, dense revenue rank within home store. Keep ranks 1–3 including ties and non-payers with revenue 0.',
 'pagila-querying-and-joins-10':'Two SELECT results, in this order: (1) payment day as date, daily revenue, cumulative revenue; (2) month as date, revenue, previous observed month revenue, absolute change, percentage change multiplied by 100. Missing prior/zero denominator produces NULL. Compare observed months; no calendar scaffold is required here.',
 'pagila-analysis-and-validation-1':'film_id, title, revenue, actor count. Include every film, using 0 for missing revenue or actor count. Attribute revenue through payment → rental → inventory → film.',
 'pagila-analysis-and-validation-2':'payment_id, payment customer_id, rental_id, rental customer_id. Return matched rentals whose customer differs from the payment customer, treating NULL as a distinct value.',
 'pagila-analysis-and-validation-3':"relationship label, orphan count. Return five rows with these exact labels: 'rental → customer', 'rental → inventory', 'payment → customer', 'payment → rental', 'payment → staff'. Include zero counts.",
 'pagila-analysis-and-validation-4':'Two SELECT results, in this order: (1) rental_id, rental_date, return_date for returns before rentals; (2) payment_id, payment_date, rental_id, rental_date for payments before their matched rental.',
 'pagila-analysis-and-validation-5':"method label, revenue. Return 'direct payment total' and 'payments joined to rentals'. The second uses matched rentals only so the orphan fixture can expose a difference.",
 'pagila-analysis-and-validation-6':'store_id, revenue by payment staff home store, revenue by inventory store, number of customers assigned to that home store. Include every store; leave missing aggregates NULL.',
 'pagila-analysis-and-validation-7':'One row with three counts: never rented, no rental in last 30 dataset days, no rental in last 90 dataset days. Use the latest rental timestamp in the dataset as reference. Never-rented customers are excluded from the two inactivity counts; the cutoff comparison is strictly earlier than reference minus the interval.',
 'pagila-analysis-and-validation-8':'store_id, film_id, title, copy count, rental count, rentals per copy. Start with store/film combinations in inventory, count all historical matched rental events, and use 0 for no rentals.',
 'pagila-analysis-and-validation-9':'customer_id, joined row count using COUNT(*), payment count using its key, distinct paid rental count. Include every customer.',
};
for(const exercise of pagilaExercises){
 const contract=resultContracts[exercise.id];
 if(contract) exercise.prompt=exercise.prompt.replace('Return the columns and result sets shown in the reference after attempting independently.',`Output columns, in order: ${contract}\n\nAliases and row order are flexible in the checker; column position matters. Follow the requested sort to practice presentation.`);
}
const focusedHints: Record<string,string[]> = {
 'pagila-querying-and-joins-5':['Start with film so a title without a copy can still appear. Which join preserves it?','After a LEFT JOIN, an unmatched film has NULL in inventory.inventory_id. Filter on that key, not title.','NOT EXISTS is another valid approach. Return only film_id and title; test a film with several copies as well as one with none.'],
 'pagila-querying-and-joins-10':['Solve the daily and monthly parts separately. Both start by aggregating payments to the required period.','The daily running total is a SUM window over daily revenue. The month comparison uses LAG over monthly revenue.','Return two SELECT result sets. Calculate 100 × (current - previous) / NULLIF(previous, 0); keep the first month comparison NULL.'],
 'pagila-analysis-and-validation-1':['Trace one payment to its film, then count how many film_actor rows it would match. Which part causes repetition?','Calculate film revenue and actor count separately, each grouped by film_id, before joining to film.','Preserve films with no revenue or no actors and replace missing aggregates with 0. SUM(DISTINCT amount) loses legitimate equal-valued payments.'],
};
for(const exercise of pagilaExercises) if(focusedHints[exercise.id]) exercise.hints=focusedHints[exercise.id];
