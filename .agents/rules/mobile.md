---
description: Flutter/Dart cross-platform mobile development standards with Provider state management
globs: "**/*.{dart,swift,kt}"
alwaysApply: false
---

# Mobile Development Standards (Flutter)

## Core Rules

1. **Clean Architecture**: `core` → `data` → `providers` → `screens` → `widgets`
2. **State Management**: Provider with ChangeNotifier. No raw `setState` for complex logic.
3. **Design Guidelines**: Material Design 3 with custom theme (`core/theme/`)
4. **Resource Cleanup**: All controllers disposed in `dispose()` method
5. **Networking**: `http` package for API calls. Handle offline gracefully.
6. **Performance**: 60fps target, test on both platforms. Use `const` constructors.
7. **No Business Logic in Widgets**: Date math, currency conversion, filtering → Provider or service.

## Architecture

```
apps/mobile/lib/
├── core/              # Theme, constants, helpers
├── data/              # Models + API client (HTTP → NestJS)
│   ├── models/        # Data classes (Expense, Category)
│   └── database/      # DatabaseService (REST client)
├── providers/         # State management (ChangeNotifier)
├── screens/           # Full-page widgets
├── services/          # Export, import, exchange rate
└── widgets/           # Reusable UI components
```

## Naming Conventions

- Files: `snake_case.dart`
- Classes/Enums: `PascalCase`
- Functions/Variables: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`
- Private members: prefix with `_`

## i18n

- Use ARB-based localization if `packages/i18n/` exists
- Never hardcode user-facing strings — use localization keys
