# Operations & Financials — Design Spec

**Date:** 2026-05-14
**Sub-project:** B (second in the planned series; A — Swine CRM Foundation — is complete on `feature/swine-crm-foundation`)
**Status:** Approved scope, ready for implementation planning

---

## 1. Overview

Layer financial discipline on top of the Sub-project A swine CRM. Track feed and medicine inventory as a movement ledger with denormalized stock balances; record vendor purchases that automatically build supply stock; capture direct expenses by category; record pig sales as truckload transactions with per-pig line items; and surface profitability per batch and per period as an extension of the existing Yield Reports.

This spec defines **Sub-project B only**. Bilingual UX, push notifications, telemedicine, poultry, and the B2B marketplace remain in Sub-projects C, D, E, F respectively.

## 2. Goals

1. **Make every peso traceable** — feed, medicine, treatments, equipment maintenance, and labor costs all show up in a single period or per-batch P&L.
2. **Replace pencil-on-a-sack inventory** with a real ledger that survives shift changes and disagreements.
3. **Capture sale events the way farmers experience them** — one truckload, one buyer, one payment, but many pigs.
4. **Give the owner actionable answers** to "Is this batch making money?" and "How did last month go?" without spreadsheet acrobatics.
5. **Match the existing app's UX bar** — every new screen honors `CLAUDE.md` and `.impeccable.md`.

## 3. Non-goals

- **Multi-currency.** PHP only. No FX, no conversion rates.
- **VAT / tax computation.** Record gross amounts; tax reporting is a future concern.
- **Vendor catalog.** `vendorName` is a free-text field on `Purchase` — no `vendors/` collection in this sub-project.
- **Construction-project tracking** (deferred to a future sub-project).
- **Payroll / labor tracking with employee records.** A "Labor" expense category exists but is just an `Expense` doc with a description; no per-employee time logs.
- **Loans, financing, accounts receivable beyond paymentStatus.** A sale can be marked `partial` or `unpaid`, but no aging or reminders.
- **Forecasting.** Historic and current P&L only. No projections.
- **Cost allocation across batches via rules.** If a feed consumption isn't tagged to a pen with a clear batch, the cost lands in period P&L but no batch's P&L. No proportional splitting.

## 4. Personas & roles (unchanged from spec A)

The four roles continue to apply. Financial actions add to the permissions matrix per §8 below.

| Role | New financial scope |
|---|---|
| **Owner** | All financial views and actions; sole role allowed to approve sales paid `partial` / `unpaid` (no extra UI gate in v1, just a future hook). |
| **Manager** | All financial views and actions except billing (not in scope). |
| **Worker** | View inventory; log feed and medicine consumption (already in workflow). Cannot create sales, purchases, or expenses. Cannot view profit numbers. |
| **Veterinarian** | View inventory (medicine stocks help diagnosis). Cannot view financial reports. |

## 5. Data model

All under `farms/{farmId}/...`. Sub-collection pattern matches spec A.

```
farms/{farmId}
  ├─ supplies/{supplyId}                          (the catalog item)
  │    fields:
  │      name (e.g., "Pigrolac Grower Feed")
  │      category: 'feed' | 'medicine' | 'other_input'
  │      unit: 'kg' | 'sack' | 'bag' | 'ml' | 'dose' | 'vial' | 'unit'
  │      unitsPerPackage? (e.g., a sack = 50 kg; null when not applicable)
  │      lowStockThreshold? (quantity below which we surface a low-stock alert)
  │      currentStock (denormalized counter, in `unit`)
  │      weightedAvgUnitCostPhp (denormalized — see §6.1)
  │      notes?
  │      createdBy, createdAt, updatedAt
  │
  ├─ supply_movements/{movementId}                (every inflow/outflow — the ledger)
  │    fields:
  │      supplyId (denormalized so we can query per-supply movements with a single index)
  │      type: 'purchase' | 'consumption' | 'adjustment' | 'wastage'
  │      quantity (signed: + for inflow, − for outflow; in the supply's `unit`)
  │      unitCostPhp? (filled only on purchase movements; used to recompute weighted avg)
  │      relatedPurchaseId?
  │      relatedPenId?    (consumption only — the pen we consumed into)
  │      relatedBatchId?  (consumption only — derived from pen → primary batch at write time)
  │      relatedHealthRecordId? (medicine consumption tied to a treatment)
  │      notes?
  │      createdBy, createdAt
  │
  ├─ purchases/{purchaseId}                       (receipt header)
  │    fields:
  │      vendorName, purchaseDate, referenceNo?,
  │      totalCostPhp (denormalized sum of line items),
  │      receiptPhotoUrl?, notes?,
  │      createdBy, createdAt
  │    └─ line_items/{itemId}
  │         supplyId, quantity, unitCostPhp, lineTotalPhp,
  │         createdAt
  │
  ├─ expenses/{expenseId}                         (direct costs not tied to a supply purchase)
  │    fields:
  │      category: 'feed' | 'medicine' | 'labor' | 'utilities'
  │              | 'equipment' | 'maintenance' | 'other'
  │      description (required, free text)
  │      amountPhp (positive number)
  │      date
  │      relatedBatchId?, relatedEquipmentId?, relatedPigId?, relatedAreaId?
  │      receiptPhotoUrl?
  │      notes?
  │      createdBy, createdAt
  │
  ├─ sales/{saleId}                               (one truckload / one payment)
  │    fields:
  │      buyerName, buyerContact?, saleDate,
  │      totalHeads (denormalized count of line items),
  │      totalWeightKg (denormalized sum),
  │      totalRevenuePhp (denormalized sum),
  │      paymentMethod: 'cash' | 'bank_transfer' | 'gcash' | 'check' | 'other',
  │      paymentStatus: 'paid' | 'partial' | 'unpaid',
  │      amountPaidPhp? (when status is partial),
  │      notes?,
  │      createdBy, createdAt
  │    └─ line_items/{itemId}
  │         pigId,
  │         pigTagId (denormalized snapshot — pig may be edited later),
  │         finalWeightKg, pricePerKgPhp, lineRevenuePhp,
  │         createdAt
```

### Existing fields we will reuse, not duplicate

- **`HealthRecord.costPhp`** — already exists. We add no new `health_costs` entity; `BatchCostCalculator` reads `health_records` directly.
- **`MaintenanceRecord.costPhp`** — already exists. Same pattern.
- **`Equipment.purchaseCostPhp`** — a capital cost; *not* included in operational P&L by default. A future sub-project can add depreciation.

### What we explicitly do NOT add

- No `vendors/` collection (vendor is a free-text string on `Purchase`).
- No `payment_terms/` or `accounts_receivable/`.
- No `supply_batches/` (we use weighted-average, not FIFO/LIFO — see §6.1).
- No first-class linkage between `sales.line_items.pigId` and a `batches/` doc. The link is derived: each sold pig's batch (if any) is fetched via the pig's `currentAreaId`/historical batch membership when computing per-batch P&L.

## 6. Architecture

Stack and conventions are inherited from spec A. New work fits without new packages.

### 6.1 Weighted-average unit cost (the inventory cost model)

To avoid FIFO/LIFO complexity in MVP, every supply carries a denormalized `weightedAvgUnitCostPhp`. On every purchase movement:

```
newAvg = ((currentStock × prevAvg) + (purchasedQty × purchasedUnitCost))
       / (currentStock + purchasedQty)
```

Wastage and adjustments do not change the average. Consumption uses the current average to compute its cost.

This is computed inside the same atomic batch that writes the `purchases/` doc + line items + `supply_movements/`.

### 6.2 Pen → Batch derivation (per-pen consumption attribution)

Workers log consumption against a **pen**, not a batch. At write time, we derive `relatedBatchId`:

1. Query active pigs in the pen (`pigs.where(currentPenId == penId, status == active)`).
2. Group them by `batches` they belong to (via a `pig.currentBatchId` field — see §6.3 below).
3. Pick the batch with the most pigs in the pen ("primary batch").
4. If no pigs or no batch found, leave `relatedBatchId` null — the cost falls into period P&L only.

This derivation runs in the repository layer at write time. Stored once on the movement so historical attribution doesn't change if pigs move later.

### 6.3 Pig → Batch membership (new on `Pig`)

Currently `Pig` has no `currentBatchId`. We add the field:

```
Pig.currentBatchId?  // nullable; set when pig joins a batch
```

Migration: existing pigs default to null. New pigs created from a farrowing event with `createLitterBatch=true` get `currentBatchId = newBatchId` written in the same atomic batch as the litter creation. Pigs added to grow-finish batches in the future would also set this.

**Out of scope for this spec:** a UI flow to move a pig between batches. The field exists, but reassigning is owner-edits-pig-record only.

### 6.4 New file structure

```
lib/src/features/
├─ inventory/
│   ├─ domain/    supply.dart, supply_movement.dart, supply_category.dart
│   ├─ data/      supply_repository.dart, movement_repository.dart
│   ├─ application/  inventory_providers.dart
│   └─ presentation/  inventory_list_screen.dart, supply_detail_screen.dart,
│                     add_edit_supply_screen.dart, log_consumption_screen.dart
├─ purchases/
│   ├─ domain/    purchase.dart, purchase_line_item.dart
│   ├─ data/      purchase_repository.dart
│   ├─ application/  purchase_providers.dart
│   └─ presentation/  purchases_list_screen.dart, log_purchase_screen.dart
├─ expenses/
│   ├─ domain/    expense.dart, expense_category.dart
│   ├─ data/      expense_repository.dart
│   ├─ application/  expense_providers.dart
│   └─ presentation/  expenses_list_screen.dart, log_expense_screen.dart
├─ sales/
│   ├─ domain/    sale.dart, sale_line_item.dart, payment_method.dart, payment_status.dart
│   ├─ data/      sale_repository.dart
│   ├─ application/  sale_providers.dart
│   └─ presentation/  sales_list_screen.dart, sale_detail_screen.dart, log_sale_screen.dart
└─ profitability/
    ├─ application/  batch_cost_calculator.dart, profitability_providers.dart
    └─ presentation/  batch_profitability_screen.dart, batches_list_screen.dart
```

Modifications to existing files:

- `lib/src/features/pigs/domain/pig.dart` — add `currentBatchId?` field.
- `lib/src/features/pigs/data/farrowing_repository.dart` — when creating a litter batch, write `currentBatchId` to the litter members (currently the piglets aren't individual `Pig` docs — but if/when they're created, set the field).
- `lib/src/features/pigs/data/health_repository.dart` — when a health record's `productName` matches a `Supply` (by name), optionally trigger a consumption movement. **Skipped in v1** — the user manually logs consumption separately. See §10 follow-up.
- `lib/src/features/yield/yield_screen.dart` — add the Period P&L card.
- `lib/src/features/dashboard/dashboard_screen.dart` — add a "Low stock" stat tile and a "Revenue this month" tile (visible to Owner/Manager only).
- `lib/src/routing/app_router.dart` — wire new routes.
- `firestore.rules` — add per-collection rules per §8.

## 7. Feature breakdown

### 7.1 Inventory list (`inventory_list_screen.dart`)

- Grouped by category: **Feed**, **Medicine**, **Other inputs**. Section headers via the shared `SectionHeader` widget.
- Each supply card: name (`titleMedium`), `currentStock unit` (large), status pill — OK (`primary`), Low (`tertiary`), Out (`error`) — based on `currentStock` vs `lowStockThreshold`.
- Filter chips (wrap, not horizontal scroll): All / Low stock / Out of stock.
- FAB visible to Manager/Owner: "+ Add supply" → `AddEditSupplyScreen`.
- Empty state via shared `EmptyState`: icon `Iconsax.box`, title "No supplies tracked", subtitle "Tap + to track your first feed or medicine."

### 7.2 Supply detail (`supply_detail_screen.dart`)

- Profile card: name, category, unit, package conversion, current stock (huge `headlineLarge`), weighted avg unit cost (`titleMedium`).
- Low-stock threshold chip (editable inline via icon button → AlertDialog).
- Two tabs:
  - **Stock history** — chronological list of movements with type icons:
    - purchase → `Iconsax.arrow_down_3` in `primary`
    - consumption → `Iconsax.arrow_up_3` in `onSurfaceVariant`
    - adjustment → `Iconsax.refresh` in `tertiary`
    - wastage → `Icons.delete_outline` in `error`
  - **Summary** — totals: stock purchased, consumed, wasted, adjusted (period selector: 30d / 90d / YTD / all).
- "Log consumption" FAB (any role except Vet) and "Log purchase" FAB (Manager/Owner only) on the screen. If both available, prefer a primary "Log" SegmentedButton chooser.

### 7.3 Add/Edit Supply (`add_edit_supply_screen.dart`)

- Form grouped under `SectionHeader`s: NAME / CATEGORY / UNIT / THRESHOLDS.
- Name (TextField, required).
- Category SegmentedButton (Feed / Medicine / Other).
- Unit dropdown (kg/sack/bag/ml/dose/vial/unit).
- Optional "Units per package" (e.g., 1 sack = 50 kg) — informational; conversion is not auto-applied in MVP.
- Low-stock threshold (TextField, number, optional).
- Save button full-width 48 dp tall.

### 7.4 Log consumption (`log_consumption_screen.dart`)

- Picker: supply (typeahead over current farm's supplies, filtered by `category: feed | medicine | other_input`).
- Quantity (TextField, number) with the supply's `unit` shown as a suffix.
- **Pen picker** (dropdown of pens with current occupancy hint, e.g., "Pen A · 12 pigs"). For Workers, the picker defaults to pens in their assigned areas with a "Show all pens" toggle to widen scope. If no pen, the entry is "unattributed".
- Optional notes.
- Save → atomic batch:
  1. Derive `relatedBatchId` via the algorithm in §6.2.
  2. Write a `supply_movements/{id}` with `type: 'consumption'`, `quantity: -X`.
  3. `FieldValue.increment(-X)` on `supplies/{supplyId}.currentStock`.
  4. Write an `activity/{id}` with action `supply_consumed`.
- Validation: cannot log consumption greater than `currentStock` (would result in negative stock). Show inline error.

### 7.5 Log purchase (`log_purchase_screen.dart`)

- Vendor name TextField (required).
- Purchase date with `AdaptiveDatePicker.show(...)`.
- Reference number TextField (optional).
- Line items section: dynamic list of (supply picker, quantity, unit cost). "+ Add line" appends a row. Each row shows `lineTotal` live.
- Total at the bottom updates as line items change (`titleMedium` w700).
- Receipt photo (single photo, `PhotoPicker.pick`).
- Notes.
- Save → atomic batch:
  1. Write `purchases/{purchaseId}` with denormalized `totalCostPhp`.
  2. For each line item: write `line_items/{itemId}`.
  3. For each line item: write a `supply_movements/{id}` with `type: 'purchase'`, `quantity: +qty`, `unitCostPhp`.
  4. For each line item: `FieldValue.increment(+qty)` on `supplies/{supplyId}.currentStock`.
  5. For each line item: recompute `weightedAvgUnitCostPhp` on the supply (in same batch — requires reading current avg+stock first, then setting in batch).
  6. Activity entry `purchase_logged`.

Note on step 5: weighted-avg recomputation needs the *pre-batch* `currentStock` + `weightedAvgUnitCostPhp`. We read them in a transaction (not a plain batch) to avoid race conditions if two purchases land simultaneously. The whole flow uses `firestore.runTransaction` instead of `WriteBatch`.

### 7.6 Expenses

- **Expenses list** — period selector (7d/30d/90d/YTD/all), category filter chips, total at top (`titleMedium` w700).
- **Log expense** — category chip selector (Feed / Medicine / Labor / Utilities / Equipment / Maintenance / Other), description (required), amount (required), date, optional batch/pig/area/equipment attribution dropdowns, receipt photo, notes.

### 7.7 Sales

- **Sales list** — chronological list. Each card: buyer name (`titleMedium`), date, totalHeads · totalWeightKg · totalRevenuePhp, paymentStatus pill.
- **Sale detail** — header with totals, line items list (pigTagId, finalWeightKg, pricePerKgPhp, lineRevenuePhp), payment status with edit affordance.
- **Log sale** (the central new flow):
  1. Header: buyer name, contact, date, payment method (SegmentedButton), payment status (chip), amount paid (only when partial).
  2. "Pigs in sale" section — "+ Add pig" opens a modal bottom sheet listing active pigs of stage grower/finisher, multi-select with checkboxes. After picking, each selected pig becomes a line-item row with:
     - Tag ID (readonly)
     - Final weight kg (TextField, number) — pre-filled with `pig.currentWeight` if available
     - Price per kg (TextField, number) — first line's value pre-fills subsequent lines (operator's most common case is "same price for all")
     - Line revenue (computed, readonly)
  3. Live totals at the bottom: heads, total weight, total revenue.
  4. Save → atomic transaction (not batch — we need to read each pig's current status to confirm `active`, then flip):
     a. Validate every pig is still `active`. If not, error: "Pig X was already sold/marked deceased."
     b. Write `sales/{saleId}` with denormalized totals.
     c. For each line item: write `line_items/{itemId}`.
     d. For each pig: update `pigs/{pigId}` with `status: sold, updatedAt`.
     e. For each pig: mark any open `withdrawal_end` tasks `status: skipped` (since the pig is sold now — withdrawal compliance becomes the buyer's concern; this is a conservative choice — alternative is to leave them open).
     f. One activity entry summarizing the transaction: "Owner logged sale of 12 hogs to Mang Berto · ₱48,000".

### 7.8 Profitability — period P&L (extends Yield Reports)

Add a **sixth card** to `yield_screen.dart`, visible to Owner/Manager only (hidden for Worker/Vet via permission check):

**Profitability** (period selector reuses the existing one)
- Revenue (sum of `sales.totalRevenuePhp` in period)
- Cost: Feed (consumption × weighted avg)
- Cost: Medicine (consumption × weighted avg + medical product costs via `health_records.costPhp`)
- Cost: Labor + Utilities + Equipment Maintenance + Other (sum of `expenses.amountPhp` by category)
- Cost: Other treatments (sum of `health_records.costPhp` not already counted as medicine consumption). **Double-counting rule:** for each health record in the period, look up any `supply_movement` where `relatedHealthRecordId == healthRecord.id`. If found, the inventory-tracked cost is authoritative. If not found, `healthRecord.costPhp` represents an off-inventory cost (service fee, vaccine purchased outside the supply catalog) and is added. This rule is implemented in `ProfitabilityCalculator.medicineCost(...)` and unit-tested with both cases.
- **Gross profit** (Revenue − total costs), `titleMedium` w700, color `primary` if positive, `error` if negative.
- **Margin %** as a small chip.

A horizontal bar chart shows cost breakdown by category (uses `fl_chart`).

### 7.9 Profitability — per-batch (new screens)

**Batches list** (`batches_list_screen.dart`) — accessed from a "Batches" link inside Yield Reports. Lists all active and recently-closed batches (litters + grow-finish). Each card:
- Batch name, type (Litter / Grow-Finish), status, days-on-feed.
- Total revenue (so far), total cost (so far), profit, margin %.
- Tap → batch profitability detail.

**Batch profitability detail** (`batch_profitability_screen.dart`):
- Header card: batch name, head count, days-on-feed, status, current avg weight (computed from member pigs).
- P&L card: revenue, cost breakdown by category, profit, margin.
- Cost breakdown pie chart.
- Cumulative profit line chart over batch lifecycle.
- Member pigs list with their individual sale info if sold.

### 7.10 Dashboard additions

Two new `StatTile`s on `DashboardScreen` for Owner/Manager only:
- **Revenue this month** — sum of `sales.totalRevenuePhp` in current month.
- **Low stock items** — count of supplies where `currentStock < lowStockThreshold`. Tappable → `inventory_list_screen.dart` pre-filtered to "Low stock".

### 7.11 Pig Detail integration

In `pig_detail_screen.dart`:
- When `pig.status == sold`, the Profile tab shows a "Sold" banner with the sale date and a link to the parent `sale_detail_screen.dart`.
- A new mini section "Costs (this pig's batch)" appears under Profile when pig has `currentBatchId` — quick stat tile showing total batch cost so far. Optional and Owner/Manager only.

### 7.12 Atomicity

All multi-doc writes use Firestore `WriteBatch` or `runTransaction`. The table:

| Operation | Mechanism | Why |
|---|---|---|
| Add supply | WriteBatch | Single doc + activity entry |
| Log consumption | WriteBatch | Movement + supply stock decrement + activity |
| Log purchase | `runTransaction` | Need to read current avg+stock to recompute weighted avg |
| Log expense | WriteBatch | Single doc + activity |
| Log sale | `runTransaction` | Need to read every line-item pig's current status to validate `active` |
| Edit supply threshold | WriteBatch | Single update + activity |

## 8. Permissions matrix (delta to spec A §8)

Append these rows:

| Action | Owner | Manager | Worker | Vet |
|---|:---:|:---:|:---:|:---:|
| View inventory | ✓ | ✓ | ✓ | ✓ |
| Add / edit supply | ✓ | ✓ | – | – |
| Adjust supply (`adjustment`, `wastage`) | ✓ | ✓ | – | – |
| Log supply consumption | ✓ | ✓ | ✓ | – |
| Log purchase | ✓ | ✓ | – | – |
| View purchases | ✓ | ✓ | – | – |
| Log expense | ✓ | ✓ | – | – |
| View expenses | ✓ | ✓ | – | – |
| Log sale | ✓ | ✓ | – | – |
| View sales | ✓ | ✓ | – | – |
| View profitability (period or batch) | ✓ | ✓ | – | – |

Vet sees inventory because medicine stock helps clinical decisions; no other financial data.

## 9. Testing strategy

- **Model unit tests:** every new domain class round-trips through `fake_cloud_firestore`.
- **Repository tests:**
  - `SupplyRepository.logConsumption` — verifies movement, stock decrement, activity entry all land atomically. Negative-stock guard tested.
  - `PurchaseRepository.logPurchase` — transaction correctness: weighted avg recomputation matches formula across multiple sequential purchases.
  - `SaleRepository.logSale` — atomic flip of multiple pig statuses; validation rejects already-sold pigs.
  - `ExpenseRepository` — CRUD.
- **`BatchCostCalculator` tests:** synthetic fixtures across multiple cost streams (consumption × avg, health, maintenance, expenses) producing expected totals.
- **`ProfitabilityCalculator` (period) tests:** revenue minus aggregated costs over a date range.
- **Pen → batch derivation tests:** mixed pen returns majority batch; empty pen returns null.
- **Permissions tests** for each new gate added in §8.

## 10. Implementation slices (preview)

The next sub-skill (`writing-plans`) will turn these into bite-sized tasks. The slice list:

1. **Supply + SupplyMovement models, SupplyRepository, inventory list + empty state.**
2. **Supply detail + add/edit + low-stock threshold inline edit.**
3. **Log consumption flow with pen → batch derivation, including unit tests for derivation.**
4. **Purchase model + line items + repository with weighted-avg recomputation in a transaction; log purchase screen.**
5. **Pig → batch membership: add `currentBatchId` field to Pig model; wire farrowing to set it on new piglets.**
6. **Expense model + repository + expenses list + log expense screen.**
7. **Sale + SaleLineItem models, SaleRepository with atomic multi-pig status flip; pig-already-sold validation.**
8. **Sales list + sale detail + log sale screen with multi-select pig picker and "apply price to all" preset.**
9. **Pig Detail "Sold" banner + sale-transaction link on Profile tab.**
10. **BatchCostCalculator + ProfitabilityCalculator pure functions with full unit tests.**
11. **Yield Reports — new Profitability card (period P&L) + Batches list + per-batch profitability detail.**
12. **Dashboard "Revenue this month" + "Low stock" stat tiles; permission-gated for Owner/Manager.**
13. **Firestore security rules for new collections + final permission audit.**

Each slice is independently shippable and follows the established TDD + atomic-batch + activity-entry pattern.

## 11. Open implementation decisions (resolve in plan, not now)

- **Medicine consumption auto-linking from Health log.** When a health record's `productName` matches a supply by name (case-insensitive trim), should logging the health record auto-decrement the supply? The cleaner UX says yes; the simpler MVP says "log separately, link manually if you want." **Recommend:** keep them separate in v1; revisit if users complain.
- **Sold-pig appearance in Pigs list.** Currently sold pigs disappear behind the "Show inactive" toggle. Should they get a permanent "Recently sold" section above active? **Recommend:** keep current behavior; a new "Sales" tab in the main nav surfaces the data.
- **Negative stock on adjustment vs wastage.** Should we allow adjustments that drive stock negative (e.g., correcting an over-recorded consumption)? **Recommend:** yes — adjustment can go either direction; wastage cannot drive stock negative.
- **Receipt photo storage path.** `farms/{farmId}/purchases/{purchaseId}/receipt.jpg` and `farms/{farmId}/expenses/{expenseId}/receipt.jpg` — single photo per record, not multi.
- **Withdrawal task on sold pigs.** §7.7 step (e) marks the task `skipped`. Alternative: leave open as a buyer-side compliance concern. **Choose `skipped` for v1.**

## 12. Future sub-projects (still deferred)

- **C — Bilingual & polish:** EN/Tagalog via `flutter_localizations` + `.arb`, low-end Android perf audit, the few remaining UX polish items from Sub-project A.
- **D — Notifications, telemedicine & Daily Checkup:** FCM push for tasks & overdue alerts; vet appointment scheduling; async photo-based consults; EveryPig-inspired Daily Checkup pen-walk workflow.
- **E — Poultry module:** replicate framework for layers/broilers, add egg collection, swap terminology.
- **F — Marketplace:** B2B feed/pharma listings, buyer connections.

## 13. Success criteria

Sub-project B is "done" when:

1. An Owner can record buying 10 sacks of grower feed at ₱1,650 each, the supply's `currentStock` jumps by 10 atomically, and the weighted-avg unit cost reflects the new purchase.
2. A Worker logs feeding 2 sacks to Pen A; consumption is attributed to Pen A's primary batch; period P&L picks up the cost.
3. Trying to consume more than current stock surfaces an inline error and blocks the write.
4. An Owner logs the sale of 12 hogs to "Mang Berto" in one transaction; all 12 pigs flip to `sold` atomically; sales appear in period revenue immediately.
5. A pig that was sold last week is visible from the Sales list and its line-item detail shows finalWeightKg + pricePerKg.
6. The Period P&L card on Yield Reports shows revenue, cost-by-category, and profit — and matches a hand-rolled spreadsheet on seeded data within ₱1 rounding.
7. The Batch Profitability screen shows revenue, costs, and profit per batch; numbers reconcile with the period P&L for sales attributable to those batches.
8. Dashboard surfaces "Revenue this month" and "Low stock items" tiles to Owner/Manager; both update in real time as data flows in.
9. A Worker (signed-in as worker) cannot see profit numbers anywhere; the route guards and the permission service agree.
10. All 105 prior tests + ~30 new tests pass; analyzer stays at 0 issues.

---

**Pre-implementation reading:** the implementer should familiarize with `CLAUDE.md`, `.impeccable.md`, and the spec A document at `docs/superpowers/specs/2026-05-14-swine-crm-foundation-design.md`. Patterns, atomicity guarantees, and the activity-entry contract are all inherited from there.
