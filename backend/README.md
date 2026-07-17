# Sales ERP PostgreSQL API

This backend provides REST APIs for the Flutter desktop app and uses PostgreSQL (pgAdmin-friendly).

## 1) Create Database

In pgAdmin / psql:

```sql
CREATE DATABASE sales_erp;
```

Run schema script:

```sql
\c sales_erp
\i sql/schema.sql
```

## 2) Configure Environment

Copy `.env.example` to `.env` and update credentials:

```env
PORT=4000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/sales_erp
```

## 3) Install and Run

```bash
npm install
npm run dev
```

API base URL: `http://localhost:4000/api`

## 4) Endpoints

- `GET /api/health`
- `GET /api/customers`
- `POST /api/customers`
- `GET /api/catalog`
- `POST /api/catalog`
- `GET /api/orders`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`
- `POST /api/warehouse/receipts`

## Notes

- Keep Flutter running with `--dart-define=API_BASE_URL=http://localhost:4000/api`.
- Backend and Flutter app can run on same machine for desktop usage.
