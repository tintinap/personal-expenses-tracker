# Execution Plan: Sub-Categories Implementation

## Overview
Implement 1-level deep sub-categories across the mobile app and backend.

## Status: PLANNED

## Tasks

### [ ] T1: Backend Database Migration (@oma-backend)
- [ ] Add `parentId` to `Category` model in `apps/api/prisma/schema.prisma`
- [ ] Update sync logic to accept and validate `parentId`
- [ ] Ensure 1-level depth constraint in backend validation

### [ ] T2: Mobile Database & Sync Update (@oma-mobile)
- [ ] Add `parentId` to `Categories` table in `tables.dart`
- [ ] Increment schema version and write migration
- [ ] Update sync payload mapping

### [ ] T3: Category Management UI (@oma-mobile)
- [ ] Build `CategoryBottomSheet` with "Parent Category" selector
- [ ] Filter out categories that already have a parent from the selector
- [ ] Update `CategoriesScreen` list to group children under parents

### [ ] T4: Transaction UI & Chart Grouping (@oma-mobile)
- [ ] Update `TransactionBottomSheet` to show hierarchy (e.g. `Parent - Child`)
- [ ] Update `CategoryDonutChart` to group sub-category amounts under their `parentId`

### [ ] T5: Update PRD Document (@oma-pm)
- [ ] Update `docs/prd-project-pet.md` to document the sub-category hierarchy rules and sync schema changes.
