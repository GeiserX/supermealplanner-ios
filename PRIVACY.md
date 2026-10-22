# Privacy

This app collects nothing.

There is no account, no server of ours, no analytics, no crash reporting, no advertising identifier
and no third-party SDK. The app talks to exactly one host: the SuperMealPlanner server whose address
you typed when you paired the phone, which is yours or your household's.

What is stored on the phone:

- the bearer token for that server, in the iOS keychain;
- the server's address and the name of the household, so the app can open;
- the last answer from each screen, so the app works without a signal and the widget has something
  to show.

**Try the demo** shows an invented household that is built into the app. It is not fetched from
any server, and no token is created for it.

Deleting the app, or unpairing in **Me → Server**, removes all of it from the phone. Nothing is sent
anywhere else, by anyone, at any time.

Questions: open an issue at https://github.com/GeiserX/supermealplanner-ios/issues
