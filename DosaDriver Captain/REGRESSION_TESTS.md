# DosaDriver Regression Test Pack (Phase 0)

## A) Auth
- [ ] Login with phone OTP
- [ ] Login with email/password (if enabled)
- [ ] Logout and relaunch

## B) Ride Happy Path
- [ ] Client creates ride (pickup -> dropoff)
- [ ] Captain receives request
- [ ] Captain accepts
- [ ] Client tracking opens and captain marker updates
- [ ] Captain status flow: accepted -> on_the_way -> arrived -> started -> completed
- [ ] Client sees completed screen / ride history updates

## C) Cancel Rules
- [ ] Client cancels before acceptance
- [ ] Client cancels after acceptance (fee applied correctly)
- [ ] Captain cancels (client notified, ride closed cleanly)
- [ ] Cancel is blocked after completed/cancelled

## D) Consistency / Reconnect
- [ ] Kill Rider app and reopen during active ride (reconnect works)
- [ ] Kill Captain app and reopen during active ride (reconnect works)
- [ ] After cancel/complete: captain activeRideId is cleared

## E) Settings Consistency (Admin -> Apps)
- [ ] Change cancellation free window in Firestore/Admin and verify Rider reads it
- [ ] Change commission percent and verify earnings logic uses it
- [ ] Toggle surge and verify pricing reflects it

## F) Safety Checks
- [ ] Invalid status jump is blocked (e.g., accepted -> started)
- [ ] Double accept is prevented (2 captains can’t accept same ride)

## Result
- [ ] PASS
- [ ] FAIL (attach screenshots/logs)
