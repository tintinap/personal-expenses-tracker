# Execution Plan: Sub-Categories Implementation

## Overview
Implement 1-level deep sub-categories across the mobile app and backend.

## Status: COMPLETE

## Tasks

### [x] T1: Backend Database Migration (@oma-backend)
- [x] Add `parentId` to `Category` model in `apps/api/prisma/schema.prisma`
- [x] Update sync logic to accept and validate `parentId`
- [x] Ensure 1-level depth constraint in backend validation

### [x] T2: Mobile Database & Sync Update (@oma-mobile)
- [x] Add `parentId` to `Categories` table in `tables.dart`
- [x] Increment schema version and write migration
- [x] Update sync payload mapping

### [x] T3: Category Management UI (@oma-mobile)
- [x] Build `CategoryBottomSheet` with "Parent Category" selector
- [x] Filter out categories that already have a parent from the selector
- [x] Update `CategoriesScreen` list to group children under parents

### [x] T4: Transaction UI & Chart Grouping (@oma-mobile)
- [x] Update `TransactionBottomSheet` to show hierarchy (e.g. `Parent - Child`)
- [x] Update `CategoryDonutChart` to group sub-category amounts under their `parentId`

### [x] T5: Update PRD Document (@oma-pm)
- [x] Update `docs/prd-project-pet.md` to document the sub-category hierarchy rules and sync schema changes.
