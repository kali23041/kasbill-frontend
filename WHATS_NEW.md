# Ratnex — what was added

Everything below is additive. No existing Firestore document shape changed, and
every new field defaults so bills, girvi, MOD and stock written before this
release read back exactly as they did.

## Firestore layout

All new data lives in **subcollections under `users/{email}`**, never as new
fields on the shop document:

```
users/{email}/
  udhaar/{phoneId}                              khata summary
    └─ entries/{entryId}                        every rupee given / collected
  schemes/{schemeId}
    └─ members/{memberId}
         └─ installments/{id}                   passbook
  repairs/{jobNo}
    └─ updates/{updateId}                       status history
  karigars/{karigarId}
    └─ issues/{entryId}                         metal issued / received
  staff/{staffEmail}                            roles + permissions
  settings/{preferences|invoiceCounter}         shop preferences, invoice series
  reminders/{id}                                due-date inbox
  devices/{fcmToken}                            push targets
  auditLog/{id}                                 append-only trail
```

The one shape change is on the bill document: `totals.exchangeValue`,
`totals.netPayable` and an `exchange[]` array. `totals.grandTotal` still means
exactly what it meant before — the full taxable sale — so GST and every report
are untouched. Old bills read `exchangeValue: 0`, so `netPayable == grandTotal`.

## New modules

| Module | Where | What it does |
|---|---|---|
| **Customers** | Profile → Customers | The list that never existed for the service that did. Lifetime value, gold bought in grams, outstanding, and one timeline joining bills + girvi + MOD + job cards. |
| **Udhaar (khata)** | Profile → Udhaar, home | Credit book with due dates, ageing buckets (0-30/31-60/61-90/90+), collect/write-off, WhatsApp reminders. A part-paid bill books itself here automatically. |
| **Schemes** | Profile → Savings schemes | 11+1 monthly gold plans. Each installment buys grams at that day's rate, so the member is protected from price rises. Passbook per member, maturity value, redemption against a bill. |
| **Repairs & orders** | Profile → Repairs | Job cards with a token number, item photos, promised date, advance, karigar assignment and a status history. |
| **Karigar** | Profile → Karigar | Grams issued vs returned per goldsmith, with wastage as a percentage and a flag when someone goes over their agreed limit. |
| **Staff** | Profile → Staff | Owner / manager / salesperson / accountant, 26 named permissions. A salesperson cannot see profit or reports. |
| **Reports** | Profile → Reports, home | Estimated margin, weight sold, dead stock, busiest hours, top categories, girvi ageing, and this period vs last year. |
| **Reminders** | Profile → Reminders, home banner | Girvi due, overdue udhaar, missed installments, ready job cards — computed on-device so it works on the free Firebase plan. |
| **Settings** | Profile → Settings | Theme, language, app lock, invoice numbering, paper size, compliance toggles, backup. |

## Compliance

- **Section 269ST warning** on cash of ₹2,00,000 or more.
- **PAN capture** prompted above ₹2,00,000, recorded on the bill.
- **KYC on girvi** — ID proof type and number on the borrower.
- **HUID validation** — 6 alphanumeric characters, plus a duplicate check
  across your stock.
- **HSN summary** table on invoices (mandatory, previously absent).
- **Sequential invoice numbering** — `RTX/25-26/0001`, allocated inside a
  transaction so two counters never collide. Off by default; turn it on in
  Settings → Invoice numbering.
- **GSTR-1 exports** — B2B, B2CS and HSN summary as CSV.

## Everywhere else

- **Dark mode** and **Hindi / Marathi / Gujarati**.
- **Offline persistence** — the counter keeps working when the line drops.
- **Search and filters** on Bills, Stock, Girvi and MOD.
- **Barcode scanning** — scan a tag straight into a bill, or to look up stock.
- **WhatsApp** — send a bill, chase udhaar, remind a girvi, tell a customer
  their repair is ready, broadcast today's rates.
- **Old-gold exchange inside a bill** with a printed working.
- **Amount in words**, round-off, terms and footer on invoices.
- **App lock** (fingerprint / face / PIN) with a 30-second grace period.
- **Draft autosave** — a half-written bill survives a mis-tap.
- **Repeat last bill** and long-press any bill to duplicate it.
- **Calculator in weight and amount fields** — type `12.5+3.2`.
- **Undo on delete** instead of a confirm dialog.
- **Rate delta chips** — "Gold 22K ▲ +₹45 since yesterday".
- **Skeleton loaders** and **empty states with a call to action**.
- **CSV export** of bills, line items, stock, customers, udhaar, girvi, MOD and
  karigar accounts.

## Platform changes you should know about

- `MainActivity` now extends `FlutterFragmentActivity` — required by
  `local_auth`; app lock silently fails without it.
- Core library desugaring is on, required by `flutter_local_notifications`.
- `intl` moved 0.18 → 0.20 to satisfy `flutter_localizations`. Only
  `DateFormat` and `NumberFormat` are used, both unchanged across that bump.
- New permissions: `POST_NOTIFICATIONS`, `VIBRATE`, `USE_BIOMETRIC`, plus
  `<queries>` entries so `wa.me`, `tel:` and `sms:` resolve on Android 11+.
- iOS: `NSFaceIDUsageDescription` and `LSApplicationQueriesSchemes`.

## Before you ship

1. **`firestore.rules` is not deployed.** Read `FIRESTORE_RULES_NOTES.md` first —
   staff permissions are only UI-deep until those rules are live.
2. **Push needs a sender.** Tokens are stored at `users/{email}/devices/{token}`
   and the reminder inbox is written on-device, but nothing sends an actual
   push yet. A Cloud Function reading `users/{email}/reminders` would close that
   loop.
3. **Test the scanner on a real phone.** The simulator has no camera.
