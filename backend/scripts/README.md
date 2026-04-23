# LUMA Waitlist — Verification Scripts

Two ways to verify the waitlist flow end-to-end against a running backend.

## 1. Bash script (automated assertions)

```bash
./test-waitlist.sh                                          # free event
EVENT_NAME="Waitlist Demo (Paid)" ./test-waitlist.sh        # paid event
BASE_URL=http://localhost:8080 ./test-waitlist.sh
```

Requirements: `curl`, `jq`, backend running, DataSeeder ran (creates the demo
events + test users). On Windows use Git Bash or WSL.

The script drives the full scenario — 3 users registering on a capacity=1
event, first user cancels, asserts position shifts + promotion happens — and
exits non-zero on any failed assertion.

## 2. Postman collection

Import `luma-waitlist.postman_collection.json` into Postman, then run the
folder **Waitlist E2E Scenario** via the Collection Runner. Each request has
test assertions that capture auth tokens / IDs into collection variables, so
just press **Run**.

Bonus folders:

- **Device Token (FCM)** — register/unregister FCM tokens.
- **Waitlist Offer actions** — accept/decline waitlist offers (paste the
  offerId from the scenario's "pending offers" response).

## Seed data the scripts expect

`DataSeeder.seedWaitlistDemo()` creates:

- `Waitlist Demo (Free)` — capacity 1, price 0, `requiresApproval=false`.
- `Waitlist Demo (Paid)` — capacity 1, price 100,000, `requiresApproval=false`.

And relies on the existing user seed:

| email                  | password |
|------------------------|----------|
| nguyenvan@gmail.com    | user123  |
| tranbi@gmail.com       | user123  |
| leminh@gmail.com       | user123  |
| admin@luma.com         | admin123 |

Both events are idempotent — the seeder skips if either already exists.
