# Panda one-time code service

This Worker reserves a code before returning it. A used redemption link receives
`code_already_shown` and never receives the code again.

## Deploy

1. Install Wrangler: `npm install --global wrangler`, then run `wrangler login`.
2. From this directory run `wrangler d1 create panda-codes`; copy the returned id into `wrangler.toml`.
3. Run `wrangler d1 execute panda-codes --remote --file=./schema.sql`.
4. Set secrets (they are not committed):
   - `wrangler secret put WEBHOOK_SECRET`
   - `wrangler secret put PAGES_ORIGIN` (for example `https://YOUR-USER.github.io/YOUR-REPO`)
5. Deploy with `wrangler deploy`.

## Add code stock

Keep the real codes in a private local SQL file, such as:

```sql
INSERT INTO codes (code, plan) VALUES
  ('YOUR-DAY-CODE-1', 'day'),
  ('YOUR-MONTH-CODE-1', 'month');
```

Then run `wrangler d1 execute panda-codes --remote --file=./private-codes.sql`.
Do not commit `private-codes.sql`.

## Connect payment verification

After XPay has independently confirmed a successful payment, call
`POST /internal/create-purchase` from a webhook/server with header
`x-panda-webhook-secret: <WEBHOOK_SECRET>` and JSON:

```json
{ "paymentId": "xpay-payment-id", "plan": "month" }
```

It returns a `redemptionUrl`. Redirect or email that exact URL to the buyer.
Do not expose this endpoint or `WEBHOOK_SECRET` in GitHub Pages.
