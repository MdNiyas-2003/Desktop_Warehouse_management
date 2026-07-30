# Sales Order Desktop / Sales ERP Project Documentation

## Project Overview

This project is a Flutter desktop application for sales order and warehouse management paired with a Node.js backend API that stores data in PostgreSQL.

- Frontend: Flutter desktop app (`lib/`, `android/`, `ios/`, `windows/`, `linux/`, `macos/`)
- Backend: Node.js + Express API (`backend/src/server.js`)
- Database: PostgreSQL

## Architecture

### Frontend

- Most app UI lives under `lib/`
- Core network API client is in `lib/core/network/backend_api.dart`
- Warehouse receipt and supplier UI are in `lib/features/warehouse/warehouse_screen.dart`
- Orders management UI is in `lib/features/orders/orders_screen.dart`
- The app uses packages such as `http`, `pdf`, `printing`, `share_plus`, `firebase_core`, `firebase_auth`, `cloud_firestore`, and `google_fonts`

### Backend

- REST API server is in `backend/src/server.js`
- PostgreSQL schema is defined in `backend/sql/schema.sql`
- API base URL is `http://localhost:4000/api`
- Backend dependencies are in `backend/package.json`

## Prerequisites

- Flutter SDK
- Dart SDK
- Node.js
- PostgreSQL
- PostgreSQL client (optional but recommended)

## Backend Setup

1. Open a terminal in `backend/`
2. Copy `.env.example` to `.env`
3. Update database connection settings as needed:

```env
PORT=4000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/sales_erp
```

4. Install dependencies:

```bash
npm install
```

5. Create the database and schema:

```sql
CREATE DATABASE sales_erp;
\c sales_erp
\i sql/schema.sql
```

6. Run the backend:

```bash
npm run dev
```

The API should now be available at `http://localhost:4000/api`.

## Frontend Setup

1. Open a terminal in the project root (`desktop/`)
2. Install Flutter dependencies:

```bash
flutter pub get
```

3. Run the Flutter desktop app:

```bash
flutter run -d windows
```

If using a different desktop platform, replace `windows` with `linux` or `macos`.

## Environment and API URL

The frontend `BackendApi` client uses the environment variable `API_BASE_URL`:

- Default: `http://localhost:4000/api`
- You can override it at runtime:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
```

## Backend API Endpoints

### Supplier and Warehouse

- `GET /api/suppliers`
- `POST /api/warehouse/receipts`
- `POST /api/warehouse/receipt` (alias for receipts route)
- `GET /api/supplier-invoices/:supplierName`

### Orders and Catalog

- `GET /api/orders`
- `GET /api/catalog`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`
- `GET /api/customers`
- `POST /api/customers`

> Note: the backend README lists the main routes, but the code also supports the warehouse receipts route alias.

## Key Files

- `README.md` — existing project README for Flutter
- `PROJECT_DOCUMENTATION.md` — this generated documentation
- `pubspec.yaml` — Flutter dependency configuration
- `backend/package.json` — backend dependencies and scripts
- `backend/src/server.js` — primary backend route definitions
- `backend/sql/schema.sql` — database schema definition
- `lib/core/network/backend_api.dart` — Flutter API client and request helper
- `lib/features/warehouse/warehouse_screen.dart` — warehouse receipt UI and supplier dropdown logic
- `lib/features/orders/orders_screen.dart` — orders management UI
- `lib/features/warehouse/services/supplier_service.dart` — supplier API helper

## Notes for Developers

- The supplier UI has a custom dropdown overlay for selecting and adding suppliers.
- New supplier creation is currently handled by detecting when typed text does not match existing supplier names.
- The backend route for warehouse receipts performs transaction-safe inserts into `supplier_invoices`, `supplier_invoice_items`, `items`, `inventory_items`, and `catalog_items`.
- The default backend connection is `localhost:4000`, so the Flutter app and backend must run on the same machine or use a forwarded URL.

## Running the Full System

1. Start PostgreSQL and ensure the `sales_erp` database is available.
2. Run the backend API in `backend/`:

```bash
npm run dev
```

3. Run the Flutter desktop app from `desktop/`:

```bash
flutter run -d windows
```

4. Confirm the UI loads and the backend routes are reachable.

## Troubleshooting

- If the frontend shows `Connection closed before full header was received`, verify the backend server is running and inspect backend startup logs.
- If you receive `404 Not Found` for `/api/warehouse/receipt`, use `/api/warehouse/receipts` or the alias route now supported in the backend.
- Ensure `API_BASE_URL` matches the backend host and port.

## Further Improvements

- Add dedicated supplier master storage separate from `supplier_invoices`
- Add backend `POST /api/suppliers` route for explicit supplier creation
- Add authentication for backend API routes
- Improve error handling and validation in Flutter submit forms

---

This document was generated from the current project structure and existing README files.