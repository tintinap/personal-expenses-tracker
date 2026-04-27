# Flutter Project Structure

## Architecture Pattern
**Riverpod + Clean Architecture Hybrid**
The project uses Riverpod for state management and DI, structured by feature folders (`lib/features/`) with a `core` and `data` layer. It also uses Drift for local offline-first SQLite database management.

## HTTP Package
**dio** (Primary) and **http** (Legacy in DatabaseService)

## Screens Inventory

| Screen | File | API Calls Made |
|--------|------|----------------|
| HomeScreen | `lib/features/home/screens/home_screen.dart` | *(Via sync provider & providers)* |
| DashboardDetailScreen | `lib/features/home/screens/dashboard_detail_screen.dart` | - |
| WalletsScreen | `lib/features/wallets/screens/wallets_screen.dart` | `GET Frankfurter` *(via portfolioProvider)* |
| CurrencyDetailScreen | `lib/features/wallets/screens/currency_detail_screen.dart` | - |
| TransactionBottomSheet | `lib/features/transactions/widgets/transaction_bottom_sheet.dart` | `GET /exchange-rates/{date}`, `GET Frankfurter` |

## Services / Repositories

| Class | File | Endpoints It Calls |
|-------|------|--------------------|
| `DioProvider` / `AuthInterceptor` | `lib/core/network/dio_client.dart` | `POST /auth/refresh` |
| `DatabaseService` (Legacy) | `lib/data/database/database_service.dart` | `GET /expenses`, `POST /expenses`, `PUT`, `DELETE` |
| `ExchangeRateRepository` | `lib/features/transactions/repositories/exchange_rate_repository.dart` | `GET /exchange-rates/{date}`, `POST /exchange-rates`, `GET Frankfurter` |
| `SyncNotifier` | `lib/features/sync/providers/sync_provider.dart` | `POST /sync` *(Mocked in code currently)* |

## Models Inventory

| Model | File | Used As |
|-------|------|---------|
| `Expense` | `lib/data/models/expense.dart` | Response for `GET /expenses`, Body for `POST/PUT /expenses` |
| `ExchangeRateResult` | `lib/features/transactions/repositories/exchange_rate_repository.dart` | Internal representation of rate responses |
| `CurrencyPortfolio` | `lib/features/wallets/providers/wallet_providers.dart` | Internal dashboard model |
| `DashboardSummary` | `lib/features/shared/providers/shared_providers.dart` | Internal UI model |

## API Base URL
`http://localhost:3000` (Injected via `.env` / `dio_client.dart`)

## Endpoints Summary

| Method | Path | Called From | Request Model | Response Model |
|--------|------|-------------|---------------|----------------|
| POST | `/auth/refresh` | Dio Interceptor | - | Anonymous JSON |
| GET | `/expenses` | App Init (Legacy) | - | List<Expense> |
| POST | `/expenses` | Create Transaction | Expense JSON | - |
| PUT | `/expenses/:id` | Edit Transaction | Expense JSON | - |
| DELETE | `/expenses/:id` | Delete Transaction | - | - |
| GET | `/exchange-rates/{date}` | TransactionBottomSheet | URL Params | ExchangeRateResult (Map) |
| POST | `/exchange-rates` | ExchangeRateRepository | Map | - |
| GET | `https://api.frankfurter.app/...` | Wallet/Transaction | URL Params | Map |
