# DailySpend

A production-ready expense tracking mobile application built with Flutter.

## Tech Stack

- Flutter (latest)
- Provider (state management)
- Hive (local database)
- fl_chart (charts)
- pluto_grid (spreadsheet view)
- excel (XLSX export)
- Material 3 (Green/Teal theme)

## 🚀 How to Run

You don't need to manually install Flutter, Node, or PostgreSQL to run the app. Everything is bundled in Docker.

1. Ensure **Docker Desktop** is running on your machine.
2. In your terminal, run the following command from the project root:
   ```bash
   docker-compose up -d --build
   ```

That's it! The command will build the containers and start the app in the background.

- **Frontend UX:** [http://localhost:8080](http://localhost:8080)
- **Backend API:** `http://localhost:3000/expenses`

### Other Useful Commands

- **Stop the app:**
  ```bash
  docker-compose stop
  ```
- **View logs:**
  ```bash
  docker-compose logs -f
  ```
- **Stop and wipe database data (Reset):**
  ```bash
  docker-compose down -v
  ```

## Features

- **Dashboard**: Filter by Weekly/Fortnightly/Monthly/Yearly, pie chart by category (converted to display currency), net total, transaction list
- **Spreadsheet**: Pivot-style view with categories as rows, time periods as columns, frozen category column (amounts converted to display currency)
- **Settings**: Theme (System/Light/Dark), Display Currency (USD, EUR, GBP, JPY, THB, CNY, etc.), Import/Export Excel
- **Multi-currency**: Per-transaction currency when adding/editing; amounts converted to display currency using Frankfurter (ECB-backed rates, similar to Google Finance)
- **Excel Import**: Supports Date | Category | Amount | Currency | Note (or 4-column format without Currency column)
