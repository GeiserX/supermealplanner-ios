# SuperMealPlanner for iPhone

The phone app for [SuperMealPlanner](https://github.com/GeiserX/SuperMealPlanner), a self-hosted
household meal planner. It shows today's plates, the week, the shopping list and the batch-cooking
sheet from **your own server** — there is no service behind this app and no account to create.

It is a client, the way a Jellyfin or a Home Assistant app is: you type the address of the
SuperMealPlanner your household already runs, pair the phone once, and that is it.

<!-- screenshots go here once the first TestFlight build is out -->

## How pairing works

There is no password to type or to lose.

1. Send `/pair` (`/vincular` in Spanish) to your household's Telegram bot, in a **private** chat.
2. It answers with six digits, good for ten minutes and for one phone.
3. Type them into the app with the server's address.

The app gets a long-lived token and keeps it in the phone's keychain. Nothing else on the phone can
read it, it is never written to the cache the widget reads, and it never leaves the device except as
an `Authorization` header to your own server.

To take a phone away — lost, sold, or an ex-flatmate — use `/devices` in the bot or **Me → Paired
phones** in the app. The next call that phone makes gets a 401 and the app returns to the pairing
screen by itself.

## What it shows

| Screen | |
|---|---|
| **Today** | Every meal in the order it is eaten, with each person's plate: the ingredient lines already scaled, the calories and the protein. 👍/👎 on a dish feeds the next draw. |
| **Week** | Seven days of dish names, today marked. |
| **Shopping** | The week's list per store, in aisle order, with the ticks shared live with the laptop and with everyone else's phone. Swipe for «I have it at home». |
| **Kitchen** | The week's jobs with their times — defrost, cook, shop — and a batch afternoon's sheet: every dish, how much, which container goes where. |
| **Me** | Weight, waist and the day's numbers, how the trend is going, the paired phones and the server. |
| **Widget** | What's for the next meal, on the home screen. |

The plan, the portions and the rules are the server's: the app never recomputes any of them, so what
it shows is what the web page shows.

## Requirements

- iPhone on iOS 17 or newer.
- A SuperMealPlanner server **0.16.0 or newer**, reachable from the phone, with its Telegram bot
  running. Older versions have no `/api/v1`.

The server's own notes on exposing the API — and only the API — to the internet are in
[docs/api.md](https://github.com/GeiserX/SuperMealPlanner/blob/main/docs/api.md).

## Building it

`project.yml` is the single source of truth: targets, settings, version and build number. The
`.xcodeproj` is generated and never committed.

```bash
brew install xcodegen
xcodegen generate
xcodebuild test -project SuperMealPlanner.xcodeproj -scheme SuperMealPlanner \
  -destination "platform=iOS Simulator,id=$(scripts/pick-simulator.sh)" -parallel-testing-enabled NO
```

CI runs the same on every pull request, then builds the Release configuration unsigned.
`release.yml` archives and uploads to TestFlight when a `vX.Y.Z` tag that matches
`MARKETING_VERSION` lands on main with green CI. It needs these repository secrets:

| Secret | |
|---|---|
| `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY` | App Store Connect API key for the upload |
| `DIST_CERTIFICATE_P12`, `DIST_CERTIFICATE_PASSWORD` | Apple Distribution certificate, base64 |
| `PROFILE_APP`, `PROFILE_WIDGET` | App Store provisioning profiles, base64 |

## Layout

```
Shared/           compiled into the app, the widget and the tests
  Models.swift    the shapes /api/v1 answers with
  Client.swift    the only place that talks to a server
  Account.swift   the keychain item, the remembered server, address parsing
  Cache.swift     the last good answer per screen, in the app group
SuperMealPlanner/ the app: AppModel plus one view per screen
SuperMealPlannerWidget/  the home screen widget, which reads the cache and never the network
SuperMealPlannerTests/   the client against a stubbed server, the shapes, the cache
```

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
