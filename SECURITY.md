# Security

## Reporting

Open a [private security advisory](https://github.com/GeiserX/supermealplanner-ios/security/advisories/new).
Please do not open a public issue for a vulnerability.

## What this app holds

- **One bearer token**, in the iOS keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so
  it is not in an iCloud or iTunes backup). It is the only credential involved: there is no password
  and no account.
- **The last answer from each screen**, in the app group container, so the app opens with something
  and the widget has a plan to show. This holds meal plans and shopping lists, never the token.

## What it talks to

Only the server whose address was typed at pairing. There is no analytics, no crash reporter, no
advertising identifier and no third-party SDK of any kind.

Certificate errors are never bypassed. `NSAllowsLocalNetworking` is set so a server on a home
network can be reached over plain http by name; anything else needs valid TLS.

## Taking a phone away

`/devices` in the household's Telegram bot, or **Me → Paired phones** in the app. Revocation is
immediate: the server looks the device up on every request, so the next call that phone makes gets a
401 and the app drops its token.
