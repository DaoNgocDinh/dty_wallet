# App_Nhom11 backend

Express REST API with MongoDB/Mongoose persistence. All `/api` endpoints except health, register, and login require `Authorization: Bearer <token>`.

## Run

1. Install Node.js and MongoDB, then start MongoDB locally (or provide an Atlas connection string).
2. Copy `.env.example` to `.env` and set a private `JWT_SECRET` and `MONGODB_URI`.
3. Run `npm install`, then `npm start` from this folder. The server listens on port 3000 by default.

The server exits if MongoDB cannot be reached. `GET /api/health` reports server and database status. Pug is used for the retained starter pages.

## API overview

- `POST /api/auth/register` — `{ name, email, password, pin? }`; password must be at least 8 characters; optional PIN is 4–6 digits.
- `POST /api/auth/login` — `{ email, password }`; returns a bearer token.
- `POST /api/auth/change-password` — `{ currentPassword, newPassword, confirmNewPassword }`.
- `PUT /api/auth/pin` — `{ password, pin }` to set/reset a transaction PIN.
- `GET /api/transactions` — search by `transactionCode`, `type`, `status`, `fromDate`, `toDate`, `sender`, `recipient`; supports `page` and `limit`.
- `GET /api/transactions/history` — authenticated user's transaction history; each item includes account, user ID, time, type, status and amount.
- `GET /api/funds` — returns the user's funds and computed current fund count.
- `POST /api/funds` — `{ name, fundType, targetAmount, completionDate? }`.
- `POST /api/funds/:id/contributions` — `{ amount, note?, pin }`; debits available wallet balance and records contribution.
- `GET /api/wallet` — available wallet balance.
- `POST /api/wallet/deposits` — `{ source, amount, paymentMethod? , qrInfo? }`; creates a pending payment intent and does not credit the wallet before external payment confirmation.
- `POST /api/wallet/topups/mobile` — `{ carrier, phoneNumber, amount, denomination?, pin }`.
- `POST /api/wallet/topups/data` — same as mobile top-up plus `dataPackage`.
- `POST /api/wallet/bill-payments` — `{ paymentMethod, billType, customerCode, amount, content?, qrCode?, pin }`.
- `GET /api/spending-jars` — list/count of the user's jars.
- `POST /api/spending-jars` — `{ name, amount, pin }`; moves the initial amount from wallet balance into the jar.
- `GET /api/spending-jars/:id?year=2026&month=10` — jar details and transactions, optionally filtered by month.

Payment provider, bank/QR confirmation, SMS/OTP delivery, and biller integrations are not configured in the project. Top-up and bill-payment requests are stored as `pending` and do not debit the wallet; deposit intents do not increase wallet balance until a trusted provider callback is implemented. Never treat client-submitted QR data or OTP as provider confirmation.

The invite-member feature is intentionally not implemented yet: its input-field requirements were marked as needing clarification, so this backend does not invent an invitation payload.

Amounts are numeric values in the application's chosen currency unit. Do not expose internal database errors or the development JWT fallback in production; set a strong `JWT_SECRET`.