# FarmApp — Manual Smoke Checklist

End-to-end verification of the Swine CRM foundation. Test across all four roles
by creating four accounts on the same Firebase project. Confirm every row before
merging `feature/swine-crm-foundation`.

> **How to run:** install a release build on a real Android device, create four
> Gmail aliases (e.g. `owner+farm@…`, `mgr+farm@…`, `worker+farm@…`,
> `vet+farm@…`), and walk through each section in order. Owner runs first;
> invitations issued by Owner unlock the remaining flows.

---

## Owner flow

- [ ] Sign up with the Owner email → land on the Create Farm screen → create farm.
- [ ] Add 3 areas (Farrowing, Gestation, Grow-Finish) each with 2 pens (set capacities).
- [ ] Add 3 equipment items (Ventilation Fan, Feeder, Generator) per area.
- [ ] Add 4 pigs: 2 sows, 1 boar, 1 grower. Verify photos upload to Storage.
- [ ] Log breeding on a sow → 3 auto tasks created (preg check, prep, farrowing).
- [ ] Record pregnancy check **confirmed** → preg-check task auto-completes.
- [ ] Log farrowing → 10 live, 1 stillborn, create litter batch → breeding closed, farrowing task completed, litter batch visible on the sow.
- [ ] Log a vaccination on a pig with 21-day withdrawal → `withdrawal_end` task scheduled at +21d.
- [ ] Log mortality on a grower with cause "Respiratory" → pig flagged deceased, activity entry appears.
- [ ] Quick-toggle equipment status from list → status cycles (operational → needs-maintenance → broken → operational).
- [ ] Log maintenance with cost ₱500 and an attached photo.
- [ ] Create a daily shift assigning two future workers; today's roster shows their names.
- [ ] Invite a Manager, Worker, and Vet (by email) — three pending invitations appear in Team.
- [ ] Open Yield reports → all six metrics populated (born alive, weaning rate, FCR placeholder, mortality %, etc.).
- [ ] Open Farm Layout → all areas render with pen tiles, equipment chips, and occupancy badges.

## Manager flow

- [ ] Sign up with the invited Manager email → see Accept Invitation screen → accept.
- [ ] Land on Dashboard scoped to the Owner's farm.
- [ ] Add 5 more pigs (different sex/stage mix).
- [ ] Edit Team — promotion to Owner is disabled / not offered.
- [ ] Create, edit, and delete an area; create, edit, and delete a pen.
- [ ] Add and edit equipment; log a maintenance record with a photo.
- [ ] Create a shift assignment for tomorrow.
- [ ] Create a manual task assigned to a Worker.
- [ ] Delete one of the pigs you created → activity entry recorded.
- [ ] Yield reports load and reflect new pigs.

## Worker flow

- [ ] Sign up with the Worker email → accept invitation → land on Dashboard.
- [ ] Dashboard shows "My Tasks" tab with tasks assigned to me.
- [ ] Log a treatment (health record) on a pig in my assigned area.
- [ ] Add a new pig → allowed (workers can create pigs).
- [ ] Quick-toggle equipment status from the equipment list → succeeds.
- [ ] Log a maintenance record with photo → succeeds.
- [ ] Open Team page — the Invite / Remove member actions are not visible.
- [ ] Open Shifts — read-only; no "create shift" button visible.
- [ ] Try to delete a pig — option not present.
- [ ] Complete one of my assigned tasks → task moves to Done, completedBy/completedAt recorded.

## Vet flow

- [ ] Sign up with the Vet email → accept invitation → land on Dashboard.
- [ ] View the pig list and a pig detail screen — fully readable.
- [ ] Log a vaccination on a pig → succeeds, withdrawal task scheduled.
- [ ] Log a treatment with notes — succeeds.
- [ ] Try to add a new pig — the "Add Pig" CTA is not visible.
- [ ] Try to log mortality — the option is not visible from the pig detail.
- [ ] Open Equipment — list is read-only; no quick-toggle, no maintenance CTA.
- [ ] Open Shifts — read-only; no create / edit CTA.
- [ ] Open Team — no invite or member-management CTAs.
- [ ] Yield reports load (Vet can read aggregates).

## Multi-farm

- [ ] As Owner of Farm A, invite User X as Manager (use a fresh email).
- [ ] Sign up User X separately and have them create their own Farm B.
- [ ] User X accepts the invite to Farm A → now belongs to 2 farms.
- [ ] AppBar farm switcher shows both Farm A and Farm B for User X.
- [ ] Switching farms swaps every list (pigs, areas, equipment, tasks) to the selected farm's data.
- [ ] Farm B data is invisible to Farm A's Owner (confirm by listing pigs on each side).
- [ ] User X's role on Farm A is Manager but Owner on Farm B — toolbar CTAs adjust on switch.

## Offline

- [ ] Toggle airplane mode mid-session → orange "Offline" banner appears within ~2 s.
- [ ] Add a pig with a photo while offline → save completes locally (Firestore offline cache + queued upload).
- [ ] Edit an existing pig's notes while offline → change reflected on screen.
- [ ] Complete a task while offline → marked Done locally.
- [ ] Re-enable network → banner disappears within ~5 s; photo upload flushes; URL appears on the pig.
- [ ] Confirm activity log received the offline events with their original timestamps after sync.
- [ ] Force-quit the app while offline and relaunch → queued writes still flush on reconnect.

---

## Sign-off

- [ ] All sections above pass on a real Android device against the production Firebase project.
- [ ] Rules deployed via `firebase deploy --only firestore:rules,storage:rules`.
- [ ] `flutter analyze` zero issues; `flutter test` all green.
- [ ] Branch tagged `sub-project-A` and pushed.
