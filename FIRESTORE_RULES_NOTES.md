# Firestore rules — read before deploying

`firestore.rules` in this repo is **not deployed**. The project is live and its
current rules live only in the Firebase Console.

## Why the file exists

The staff feature (`lib/services/shop_staff_service.dart`) gates the UI by
permission. UI gating is a convenience, not security — a staff member with the
app could still read the owner's data directly unless the rules say otherwise.
These rules mirror `Perm.*` server-side.

## Before you deploy

1. Open **Firebase Console → Firestore → Rules** and copy what is there now.
2. Diff it against `firestore.rules`. Anything your current rules allow that
   this file does not will start failing for existing users.
3. Pay particular attention to:
   - the **admin panel** (`lib/admin/`) — it lists and edits other users'
     documents and needs `role == "Admin"` on the admin's own user doc;
   - **`plan` writes** — if your payment webhook writes the plan from a Cloud
     Function or the Admin SDK, it bypasses rules and is unaffected; if it
     writes from the client, it needs an explicit allowance;
   - any collection this repo does not know about.
4. Test with the **Rules Playground** before publishing.

## Cost note

`staffCan()` calls `get()` on the staff document. Each `get()` inside rules is a
billed read. For an owner-only shop the `isOwner()` short-circuit means no extra
reads happen at all — the cost only applies once a shop actually adds staff.

## What is still client-side only

Nothing enforces permissions inside a single document. For example, a
salesperson who can create bills can technically write any field on a bill.
Tightening that needs field-level validation in the rules, which is worth adding
once the staff feature has real usage.
