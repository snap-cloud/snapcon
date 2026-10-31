# Stripe Checkout

Snap!Con takes ticket payments with [Stripe Checkout](https://docs.stripe.com/payments/checkout).

## How a payment works

1. On the payment page, the user clicks **Pay**. `PaymentsController#create` makes a `Payment`, and
   `Payment#create_checkout_session` creates a Checkout session for the user's unpaid ticket
   purchases. Those purchases are linked to the payment (`ticket_purchases.payment_id`), and the
   expected total is stored in `payments.amount`.
2. The user pays on Stripe's hosted page.
3. The payment is completed by **either**:
   - the user returning to `/conferences/:id/payments/success?session_id=...`, or
   - Stripe calling `POST /stripe/webhook` with `checkout.session.completed`.

   Both call `Payment#fulfill_checkout`, which is idempotent. It marks only the linked purchases
   paid, issues physical tickets, and sends confirmation emails.
4. If the amount Stripe charged doesn't match the linked tickets (for example, the user changed a
   quantity in another tab), the payment is marked `failure`. The tickets are left unpaid, an error
   goes to Sentry, and the user is asked to contact the organizers. Reconcile these by hand: refund
   in Stripe (the PaymentIntent id is in `payments.authorization_code`), or mark the tickets paid in
   the console.

## Configuration

| Setting | Where | Value |
| --- | --- | --- |
| `STRIPE_SECRET_KEY` | Heroku config | Secret API key: `sk_live_...` in production, `sk_test_...` elsewhere |
| `STRIPE_WEBHOOK_SECRET` | Heroku config | Signing secret of the webhook endpoint below (`whsec_...`) |
| API version | `config/initializers/stripe.rb` | Pinned to `2022-11-15`. Test checkout before changing it. |

`STRIPE_PUBLISHABLE_KEY` is no longer used.

Success and cancel URLs are built per request, so they need no Stripe-side setup.

## Deploying

1. **Create the webhook endpoint** in the Stripe Dashboard → Developers → Webhooks → *Add endpoint*:
   - URL: `https://<production host>/stripe/webhook`
   - Events: `checkout.session.completed` and `checkout.session.async_payment_succeeded`
2. **Set the secrets on Heroku**:
   ```sh
   heroku config:set STRIPE_WEBHOOK_SECRET=whsec_... -a snapcon
   heroku config:get STRIPE_SECRET_KEY -a snapcon   # check it starts with sk_live_
   ```
3. **Deploy and migrate**. The Procfile has no release phase, so run migrations yourself:
   ```sh
   git push heroku main
   heroku run rails db:migrate -a snapcon
   ```
4. **Smoke test** with a cheap real ticket:
   - Pay, then confirm the success page shows your tickets and the `Payment` is `success`.
   - Pay again and close the tab on Stripe's confirmation page. Within a minute the webhook should
     mark the tickets paid. Check Dashboard → Webhooks → the endpoint → *Recent deliveries* for a
     `200`.
   - Refund both test purchases in the Stripe Dashboard.

## Local testing

Use test keys and the [Stripe CLI](https://docs.stripe.com/stripe-cli) to forward webhooks:

```sh
stripe listen --forward-to localhost:3000/stripe/webhook
# copy the printed whsec_... into STRIPE_WEBHOOK_SECRET in .env, then restart the server
```

Pay with card `4242 4242 4242 4242`, any future expiry, and any CVC.
