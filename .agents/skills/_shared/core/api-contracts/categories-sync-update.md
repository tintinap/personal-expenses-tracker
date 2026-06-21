# Category Entity Sync Update

## 1. Overview
Updates the Category entity schema to support sub-categories via a self-referential `parentId` field.

## 2. Updated Entity Schema
This represents the payload inside the `SyncRequest` when `recordType` is `"category"`.

```typescript
{
  "id": "uuid",
  "name": "string (max 50)",
  "colourHex": "string (hex format #RRGGBB)",
  "isDefault": "boolean",
  "isHidden": "boolean",
  "sortOrder": "integer",
  "parentId": "uuid | null", // NEW FIELD
  "createdAt": "iso-date",
  "updatedAt": "iso-date"
}
```

## 3. Constraints & Validation
- `parentId` must be a valid UUID or `null`.
- If `parentId` is provided, the referenced Category must exist and belong to the same `userId`.
- Maximum depth is 1 level. If Category A has `parentId = B`, then Category B MUST have `parentId = null`.

## 4. Error Responses
- **400 Bad Request**: `"Invalid parentId: Maximum category depth exceeded (1 level allowed)."`
- **400 Bad Request**: `"Invalid parentId: Parent category not found or does not belong to user."`
