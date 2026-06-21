# Sub-Categories Feature Design

## Overview
Implement a 1-level deep sub-category hierarchy (Parent -> Sub-category) to allow fine-grained expense tracking while maintaining aggregated reporting at the parent level.

## Architecture & Data Flow
1. **Data Model (Self-Referential)**
   - **Backend (Prisma)**: Add `parentId String? @map("parent_id") @db.Uuid` to the `Category` model.
   - **Mobile (Drift)**: Add `TextColumn get parentId => text().named('parent_id').nullable()()` to the `Categories` table in `tables.dart`.
2. **Transaction Assignment**
   - Transactions can be assigned to either a top-level Parent category or a Sub-category.
3. **Data Aggregation**
   - For UI charts (`CategoryDonutChart`) and `DashboardSummaryCards`, all expenses assigned to sub-categories are visually grouped and summed under their respective `parentId`.

## Key Interfaces & Integration Points
1. **Add/Edit Category UI**
   - Implement a new `CategoryBottomSheet` in `CategoriesScreen`.
   - Includes: Name, Hex Color, and an optional "Parent Category" dropdown.
2. **Categories List**
   - `CategoriesScreen` will render top-level parents with their respective sub-categories indented/grouped below them.
3. **Transaction Entry Dropdown**
   - The category selector in `TransactionBottomSheet` will display hierarchy (e.g., `Subscription - Netflix`) for clear selection.

## Edge Cases & Error Handling
1. **Depth Enforcement**
   - The hierarchy is strictly limited to 1 level. 
   - The "Parent Category" dropdown will filter out any category that already has a `parentId`.
2. **Downgrading a Parent**
   - If a user edits a top-level Parent to assign it a `parentId`, this action will be blocked if the category currently has its own sub-categories.
3. **Deletion Safety**
   - Deleting a parent category is blocked if it currently has any active sub-categories, preventing orphaned child records.
