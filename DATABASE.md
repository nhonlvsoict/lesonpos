Got it 👍 — you mean a **`README.md` / `DATABASE.md`**–style documentation file that you can include in your repo for the data/analytics dev.

Here’s a clean, ready-to-copy version:

---

````markdown
# 📘 LeSon POS — Database Documentation

> **Version:** 1.1  
> **Purpose:** Internal reference for data analytics, reporting, and integration.  
> **Database:** PostgreSQL (Supabase / Neon compatible)  
> **Timezone:** UTC (`timestamptz`)  
> **IDs:** UUID v4 (generated on device)  
> **Sync Rule:** “Freshest-wins” — server upserts only if `excluded.updated_at > current.updated_at`

---

## 🧱 Schema Overview

**Main Tables**
| Table | Purpose |
|--------|----------|
| `staff` | Staff registry (waiters, baristas, etc.) |
| `menu_items` | Menu catalog (both base items and add-ons) |
| `orders` | Master record of each customer order |
| `order_items` | Individual items in each order |
| `payments` | Payment records (cash, card, etc.) |

---

## 🧾 Key Concepts

### 🧩 Menu & Options Model

#### `menu_items`
- Contains **both base menu items** and **optional add-ons**.
- **`is_optional`** → marks the item as an *add-on* that can be attached to other items.  
  Example: “Extra Ice”, “Add Strawberry Syrup +£0.50”.
- **`option_ids`** → list of `menu_items.id` that are valid add-ons for this item.  
  Example:  
  ```json
  ["uuid_add_ice", "uuid_add_strawberry"]
````

✅ Example Data:

| name                   | is_optional | option_ids             |
| ---------------------- | ----------- | ---------------------- |
| Vietnamese Iced Coffee | false       | `["ice_id","milk_id"]` |
| Add Ice                | true        | `[]`                   |
| Add Condensed Milk     | true        | `[]`                   |

> **Meaning:** “Vietnamese Iced Coffee” can have “Add Ice” or “Add Condensed Milk” as selectable options.

---

#### `order_items`

* Represents one ordered item line (e.g. “1x Vietnamese Coffee”).
* **`selected_option_ids`** → JSON array of option item IDs actually chosen in this order.
  Example:

  ```json
  ["milk_id"]
  ```
* **`option_total`** → numeric value of total add-on prices for this line.
* **`line_total`** = `qty × (unit_price + option_total)`

✅ Example:

| item_id   | selected_option_ids | option_total | line_total |
| --------- | ------------------- | ------------ | ---------- |
| coffee_id | `["milk_id"]`       | 0.5          | 4.0        |

Meaning: ordered one Vietnamese Coffee (£3.50) + “Add Milk” (£0.50) → total £4.00.

---

### 🧮 Relationships (Simplified ERD)

```
staff (1) ───< orders (many)
orders (1) ───< order_items (many) >─── (1) menu_items
orders (1) ───< payments (many)
```

---

## 🗃️ Table Summaries

### `staff`

| Column     | Type        | Description      |
| ---------- | ----------- | ---------------- |
| id         | uuid        | Primary key      |
| name       | text        | Staff name       |
| role       | text        | Role in shop     |
| updated_at | timestamptz | Last update time |

---

### `menu_items`

| Column          | Type          | Description                           |
| --------------- | ------------- | ------------------------------------- |
| id              | uuid          | Primary key                           |
| name            | text          | Item name                             |
| category        | text          | Category (Coffee, Tea, Food, etc.)    |
| price           | numeric(12,2) | Base price                            |
| is_active       | boolean       | Whether shown on menu                 |
| **option_ids**  | jsonb         | Add-ons available for this item       |
| **is_optional** | boolean       | True if this item is itself an add-on |
| updated_at      | timestamptz   | Last update time                      |

---

### `orders`

| Column     | Type          | Description                       |
| ---------- | ------------- | --------------------------------- |
| id         | uuid          | Primary key                       |
| table_no   | text          | Table identifier                  |
| note       | text          | Free note                         |
| status     | text          | Order status (OPEN, CLOSED, etc.) |
| subtotal   | numeric(12,2) | Before discount                   |
| discount   | numeric(12,2) | Discount amount                   |
| total      | numeric(12,2) | Final total                       |
| opened_at  | timestamptz   | Time opened                       |
| closed_at  | timestamptz   | Time closed                       |
| updated_at | timestamptz   | Last update time                  |
| staff_id   | uuid          | FK → `staff.id`                   |

---

### `order_items`

| Column                  | Type          | Description                       |
| ----------------------- | ------------- | --------------------------------- |
| id                      | uuid          | Primary key                       |
| order_id                | uuid          | FK → `orders.id`                  |
| item_id                 | uuid          | FK → `menu_items.id`              |
| qty                     | int           | Quantity                          |
| unit_price              | numeric(12,2) | Base item price                   |
| **selected_option_ids** | jsonb         | Chosen add-on IDs                 |
| **option_total**        | numeric(12,2) | Sum of chosen add-ons             |
| line_total              | numeric(12,2) | qty × (unit_price + option_total) |
| note                    | text          | Line note                         |
| updated_at              | timestamptz   | Last update time                  |

---

### `payments`

| Column     | Type          | Description                       |
| ---------- | ------------- | --------------------------------- |
| id         | uuid          | Primary key                       |
| order_id   | uuid          | FK → `orders.id`                  |
| method     | text          | Payment method (cash, card, etc.) |
| amount     | numeric(12,2) | Amount paid                       |
| paid_at    | timestamptz   | Payment timestamp                 |
| updated_at | timestamptz   | Last update time                  |

---

## 🧠 Data Model Highlights

| Concept              | Explanation                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Options System**   | Combines `is_optional`, `option_ids`, and `selected_option_ids` to track relationships between base items and add-ons. |
| **Snapshot Pricing** | `unit_price`, `option_total`, and `line_total` are stored at order time (not recalculated later).                      |
| **Sync Logic**       | Device writes to local DB → pushes via API → server runs upsert only if `updated_at` is newer.                         |
| **Analytics Use**    | Easily aggregate `order_items` and join to `menu_items` to compute sales by category or add-on usage.                  |

---

## 📊 Example Analysis Queries

**Top 10 Menu Items (last 30 days):**

```sql
select mi.name, mi.category,
       sum(oi.qty) as qty_sold,
       sum(oi.line_total) as revenue
from order_items oi
join menu_items mi on mi.id = oi.item_id
join orders o on o.id = oi.order_id
where o.opened_at >= now() - interval '30 days'
group by 1,2
order by revenue desc
limit 10;
```

**Add-on (Option) Usage:**

```sql
select mi_base.name as base_item,
       count(*) filter (where oi.selected_option_ids is not null) as lines_with_addon,
       round(100.0 * count(*) filter (where oi.selected_option_ids is not null) / count(*), 1) as attach_rate_pct
from order_items oi
join menu_items mi_base on mi_base.id = oi.item_id
group by 1
order by attach_rate_pct desc;
```

---

## 📄 Notes

* Use `Europe/London` timezone in dashboards for readability.
* `menu_items.is_optional = true` items can appear in multiple orders via `selected_option_ids`.
* Keep JSON columns (`option_ids`, `selected_option_ids`) intact for easy migration later to a normalized bridge table if needed.

---

**Author:** LeSon POS Dev Team
**Last Updated:** October 2025

```

---

Would you like me to also include a **section at the top for setting up Metabase connection + default dashboards (daily sales, category mix, option usage)** inside this same README?
```
