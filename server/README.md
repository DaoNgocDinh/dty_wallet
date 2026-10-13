# App_Nhom11 backend

Express REST API with MongoDB/Mongoose persistence. All `/api` endpoints except health, register, and login require `Authorization: Bearer <token>`.

Error responses carry a machine-readable `code` (`INVALID_CREDENTIALS`, `INVALID_INPUT`, `USERNAME_EXISTS`, `EMAIL_EXISTS`) alongside the English `error` message.

## Run

1. Install Node.js and MongoDB, then start MongoDB locally (or provide an Atlas connection string).
2. Copy `.env.example` to `.env` and set a private `JWT_SECRET` and `MONGODB_URI`. The default database is **`dty_wallet`** (`mongodb://127.0.0.1:27017/dty_wallet`).
3. Run `npm install`, then `npm run seed` to create the admin account, then `npm start` from this folder. The server listens on port 3000 by default.

The server exits if MongoDB cannot be reached. `GET /api/health` reports server and database status. Pug is used for the retained starter pages.

## Admin account

`npm run seed` creates (or updates) one account:

| Field    | Default       |
| -------- | ------------- |
| name     | `admin`       |
| email    | `admin@gmail.com` |
| password | `123456`      |

The script is safe to re-run and reads `ADMIN_NAME`, `ADMIN_EMAIL`, `ADMIN_PASSWORD` and `ADMIN_WALLET_BALANCE` from `.env`. This is a demo account with a weak password — change or remove it before any real deployment.

## CORS

`/api` allows cross-origin requests so the Flutter web build can call the API from another port. Restrict it by setting `CORS_ORIGIN` in `.env` (it defaults to `*`).

## API overview

- `POST /api/auth/register` — `{ name, password, pin? }`; password must be at least `MIN_PASSWORD_LENGTH` characters (default 6); `email` is optional and generated from `name` when omitted; optional PIN is 4–6 digits.
- `POST /api/auth/login` — `{ name, password }`; logs in by **account name**, case-insensitive; returns a bearer token.
- `POST /api/auth/logout` — requires a bearer token; acknowledges the logout. JWTs are stateless, so the client must discard its stored token.
- `POST /api/auth/change-password` — `{ currentPassword, newPassword, confirmNewPassword }`; returns `WRONG_PASSWORD` when the current password does not match.
- `PUT /api/auth/pin` — `{ password, pin }` to set/reset a transaction PIN.
- `GET /api/transactions` — search by `transactionCode`, `type`, `status`, `fromDate`, `toDate`, `sender`, `recipient`; supports `page` and `limit`.
- `GET /api/transactions/history` — authenticated user's transaction history; each item includes account, user ID, time, type, status and amount.
- `GET /api/funds` — returns the user's funds and computed current fund count.
- `POST /api/funds` — `{ name, fundType, targetAmount, completionDate?, partnerId? }`. `fundType: "Cặp đôi"` **requires** `partnerId` (or `partnerPhoneNumber`/`partnerName`): the fund is created with status `pending_partner` plus a pending invitation, and only becomes an active two-member fund after the selected user accepts. Missing partner → `PARTNER_REQUIRED`, self-selection → `CANNOT_INVITE_SELF`, admin account → `CANNOT_INVITE_ADMIN`.
- `GET /api/funds/partner-candidates?query=` — users that can be picked as the partner of a couple fund (never returns the current user or admin accounts). Empty search result returns `NO_USER_FOUND`.
- `POST /api/funds/:id/contributions` — `{ amount, note? }`; debits available wallet balance and records contribution.
- `POST /api/funds/:id/withdraw` — `{ amount, note? }`; **owner only** (`NOT_FUND_OWNER` otherwise). Minimum 1.000đ (`MIN_AMOUNT_1000`), the amount may not exceed the fund balance (`INSUFFICIENT_FUND_BALANCE`), and the money is credited back to the owner's wallet with a `fund_withdrawal` transaction.
- `DELETE /api/funds/:id` — owner only; a fund can **only** be deleted while its balance is `0`, otherwise `FUND_NOT_EMPTY` (the response carries `currentAmount`).
- `POST /api/funds/:id/invitations` and `GET /api/funds/:id/candidates` — couple funds are capped at 2 users: `COUPLE_FUND_FULL` once both users are in, `COUPLE_FUND_PENDING` while waiting for the selected partner to accept.
- `GET /api/wallet` — available wallet balance.
- `POST /api/wallet/deposits` — `{ source, amount, paymentMethod? , qrInfo? }`; creates a pending payment intent and does not credit the wallet before external payment confirmation.
- `POST /api/wallet/topups/mobile` — `{ carrier, phoneNumber, amount, denomination?, pin }`.
- `POST /api/wallet/topups/data` — same as mobile top-up plus `dataPackage`.
- `POST /api/wallet/bill-payments` — `{ paymentMethod, billType, customerCode, amount, content?, qrCode?, pin }`.
- `GET /api/spending-jars` — list/count of the user's jars.
- `POST /api/spending-jars` — `{ name, amount, pin }`; moves the initial amount from wallet balance into the jar.
- `GET /api/spending-jars/:id?year=2026&month=10` — jar details and transactions, optionally filtered by month.

Payment provider, bank/QR confirmation, SMS/OTP delivery, and biller integrations are not configured in the project. Top-up and bill-payment requests are stored as `pending` and do not debit the wallet; deposit intents do not increase wallet balance until a trusted provider callback is implemented. Never treat client-submitted QR data or OTP as provider confirmation.

## Tests

| Script | Scope |
| --- | --- |
| `npm test` | runs every suite below in order |
| `npm run test:withdraw` | fund withdrawal for the owner + "delete only at 0đ" rule (`test/fund_withdraw_test.js`) |
| `npm run test:couple` | couple fund rules: mandatory partner, 2-user cap, delete at 0đ (`test/couple_fund_test.js`) |

The suites connect to the same MongoDB database and clean up their own fixtures, so they can be re-run safely.

Amounts are numeric values in the application's chosen currency unit. Do not expose internal database errors or the development JWT fallback in production; set a strong `JWT_SECRET`.