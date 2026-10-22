# AGENTS.md: supermealplanner-ios

Instructions for coding agents working in this repository. `CLAUDE.md` imports this file.

## What this is

The iPhone app for [SuperMealPlanner](https://github.com/GeiserX/SuperMealPlanner), a self-hosted
household meal planner. It is a client of someone's own server, not a front end for a service: the
app asks for a server address and a pairing code and talks to `/api/v1` on that host.

The server side of the contract — the pairing flow, every route and the rules the app relies on —
is `docs/api.md` in the server repository. Read it before changing anything here that touches the
network.

## Repository rules

- Licence: MPL-2.0. Not GPL: Apple's App Store terms add restrictions on top of the copy you
  download, which the GPL forbids, so a GPL app and the store it ships from contradict each
  other. MPL keeps the copyleft where it matters — a change to a file here stays open — without
  that contradiction. The server is AGPL-3.0-or-later and stays that way; this app only talks
  to it over HTTP.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org). Versions follow semver.
- Every change reaches `main` through a pull request with green CI. Never force push, never rewrite
  pushed history.
- No AI attribution anywhere: no `Co-Authored-By` trailers, no "Generated with" lines.
- Never commit a secret, a signing certificate, a provisioning profile or an App Store Connect key.

## The app and the web page go together

The server's web page and this app show the same household: today's plates, the week, the shopping
list, the cooking sheet. A change to how one of them behaves usually belongs in the other too. When
a change lands here, check whether the web page needs it (in the server repository), and the other
way round. What the app shows comes computed from `/api/v1`, so a rule changes on the server, and
the app only follows.

A merge that bumps `MARKETING_VERSION` (patch for a fix or a small change) is what ships it to
TestFlight; without the bump a merged change never reaches a phone.

## Build and test

`project.yml` is the single source of truth (targets, settings, version, build number); the
`.xcodeproj` is generated and never committed, so a change to targets or settings goes in
`project.yml`.

```bash
xcodegen generate
xcodebuild test -project SuperMealPlanner.xcodeproj -scheme SuperMealPlanner \
  -destination "platform=iOS Simulator,id=$(scripts/pick-simulator.sh)" -parallel-testing-enabled NO
```

## Architecture

```
Shared/           compiled into the app, the widget and the tests
  Models.swift    the shapes /api/v1 answers with, plus the missing-key overloads
  Client.swift    the only place that talks to a server; every refusal is named here
  Account.swift   the keychain item, the remembered server, address parsing
  Cache.swift     the last good answer per screen, in the app group
  Demo.swift      "Try the demo": an invented household answered by a URLProtocol, never a server
SuperMealPlanner/        AppModel plus one view per screen
SuperMealPlannerWidget/  the widget: reads the cache, never the network
SuperMealPlannerTests/   the client against a stubbed server, the shapes, the cache
SuperMealPlannerUITests/ one test that pairs for real; skipped unless handed a server
```

## Rules the code depends on

- **The token lives in the keychain and nowhere else.** Not in `UserDefaults`, not in the cache the
  widget reads, never in a log line. `Vault` is the only thing that touches it. A test asserts that
  no cache file contains the word.
- **The widget never calls the server.** It reads the app group cache, so the extension needs no
  token of its own.
- **Every network call goes through `Client.send`,** so there is one answer to what a 401, a 429 and
  an unreachable server mean. A new route is a method on `Client`, never a `URLRequest` in a view.
- **The app recomputes nothing.** Portions, the plan, the shopping order, the flags on the progress
  screen and the household's section labels all arrive computed and translated by the server. Adding
  arithmetic here means two copies of a rule.
- **A cached answer is always shown with the time it was fetched** (`StaleNote`). Never show an old
  plan as if it were live.
- **A write flips the row first and the server's answer replaces the state.** A failure puts the row
  back and says why; it does not leave a lie on screen.
- **Fields are added, never renamed,** inside api version 1. Decoding must survive both an unknown
  field and a missing one — but a field of the wrong type still throws.
- **The demo answers every route the client calls.** A new method on `Client` needs its route in
  `DemoServer.respond`; `DemoTests` walks every call and fails on a 404. Demo content is invented.
- Meal names, section fallbacks and every string the app itself writes are in the app's own
  language, not the server's locale.
- The app icon is `docs/images/icon.svg` rendered square and flattened, so the PNG in the asset
  catalogue is never hand-edited:
  `sed 's/rx="112" //' docs/images/icon.svg | rsvg-convert -w 1024 -h 1024 -b '#df6d43' > icon-1024.png`.
  It carries no alpha and no rounded corners of its own — iOS applies the mask.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
