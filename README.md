# sprint_plate

A personal GitHub sprint command-center. One command prints your current
GitHub work queue — what you owe, what you're building, what's assigned, and
what's gone quiet — to your terminal or a self-contained browser page.

Personal tool, single user, GitHub-only, **serverless**. No server, no OAuth
flow, no database, no gems. Just Ruby and the standard library.

```
$ ruby sprint_plate.rb
Sprint plate for @you  —  2026-06-22 09:14  (business days)
========================================================================

Reviews you owe (2)
-------------------
  #482 Tighten retry backoff  (acme/api)
    https://github.com/acme/api/pull/482
  ...

Your PRs gone quiet (1)
-----------------------
  #501 Add billing webhook  (acme/api)  — 3 business days since you handed off
    https://github.com/acme/api/pull/501
```

---

## What it shows — four buckets (+ one bonus)

1. **Reviews you owe** — open PRs where review is requested *from you*.
2. **Currently building (WIP)** — your own open **draft** PRs.
3. **Assigned, not started** — issues on a GitHub **Projects V2** board,
   assigned to you, whose **Status** is in a configurable "not started" set.
4. **Your PRs gone quiet** — your **ready** (non-draft) PRs where the ball is on
   the reviewer and the wait exceeds a threshold. *(See [Bucket #4](#bucket-4--the-handoff-vs-reviewer-race) below.)*
   - **Bonus — Ready, no reviewer requested**: your non-draft PRs with nobody
     asked to review and no reviews yet (silently invisible to everyone).

---

## Install

Requires **Ruby 3.2+**. No gems — stdlib only.

```sh
git clone https://github.com/cdrrazan/releaser.git
cd releaser
ruby sprint_plate.rb --help   # see header for full docs
```

Optionally make it executable and put it on your `PATH`:

```sh
chmod +x sprint_plate.rb
ln -s "$PWD/sprint_plate.rb" ~/.local/bin/sprint_plate
```

---

## Setup

1. Create a **classic Personal Access Token** with scopes: `repo`,
   `read:org`, `read:project`.
2. Export your configuration:

   ```sh
   export GITHUB_TOKEN=ghp_xxx
   export GH_LOGIN=your-username
   export PROJECT_URL='https://github.com/orgs/YourOrg/projects/10/views/5'
   ```

3. Run it:

   ```sh
   ruby sprint_plate.rb                 # terminal output (default)
   ruby sprint_plate.rb --browser       # render + open a static HTML page
   ruby sprint_plate.rb -b --watch 60   # live tab, refreshed every 60s
   ```

---

## Configuration

CLI flags take precedence over environment variables.

| Var / flag | Required | Default | Purpose |
|---|---|---|---|
| `GITHUB_TOKEN` | yes | — | Classic PAT: `repo`, `read:org`, `read:project` |
| `GH_LOGIN` | yes | — | Your GitHub username |
| `OUTPUT` / `--browser`, `-b` | no | `terminal` | Surface: `terminal` or `browser`. The flag forces browser and overrides `OUTPUT`. |
| `WATCH_SECONDS` / `--watch N` | no | `0` (off) | Browser only: re-fetch + rewrite the page every N seconds for a live tab |
| `PROJECT_URL` | for #3 | — | Board/view URL, e.g. `https://github.com/orgs/Recognize/projects/10/views/5` |
| `NOT_STARTED_STATUSES` | no | `Todo,Backlog,No Status` | Status column names treated as "not started" (case-insensitive) |
| `ITERATION_FILTER` | no | `off` | `current` restricts #3 to the active sprint |
| `ITERATION_FIELD` | no | `Iteration` | Board's iteration field name |
| `STALE_DAYS` | no | `2` | Threshold (in days) for bucket #4 |
| `DAY_MODE` | no | `business` | `business` (skip Sat/Sun) or `calendar` |

Only the **org** and **project number** are parsed from `PROJECT_URL` (via
`/orgs/<org>/projects/<num>`); the saved-view number is ignored — see
[Non-goals](#non-goals--known-limitations).

---

## Surfaces

The same classified buckets feed both surfaces — surfaces never re-query or
re-classify.

### Terminal (default)

Plain text grouped by bucket, no ANSI, safe to pipe to `mail`. Ideal for cron.

### Browser (serverless)

Renders **one self-contained HTML document** (inline CSS, no external/CDN
resources, works offline over `file://`) to a stable path
(`<tmpdir>/sprint_plate.html`) and opens it in your default browser. Bucket #4
gets a distinct warning accent and a "days since handoff" badge per card.

- **Watch mode** (`--watch N`): re-fetches, re-classifies, and rewrites the
  same file every N seconds, opening the browser only on the first cycle. The
  page carries `<meta http-equiv="refresh">` so the open tab reloads itself.
  Meta-refresh over `file://` works in current Chrome, Firefox, and Safari.
- **Security:** the page is a static in-process snapshot. It makes no GitHub
  calls and **never contains your token or any secret**. See [SECURITY.md](SECURITY.md).

---

## Bucket #4 — the handoff-vs-reviewer race

Keying off `reviewDecision == REVIEW_REQUIRED` is **wrong**: after a reviewer
requests changes and the author pushes fixes, `reviewDecision` stays
`CHANGES_REQUESTED` until the reviewer re-reviews — so the PR you most want
flagged gets dropped. sprint_plate uses a **timestamp race** instead:

- **handoff** = the last moment *you* put the ball in the reviewer's court =
  `max(last review-requested event, last commit pushed, PR created)`.
- **reviewer's last action** = the latest *opinionated* review (`APPROVED` /
  `CHANGES_REQUESTED`). Plain `COMMENTED` reviews don't count.
- The ball is on the reviewer when your handoff is newer than their last
  action, or they never acted.
- A PR is **stale** when it's non-draft, the ball is on the reviewer, and the
  wait since handoff is `>= STALE_DAYS`.

This correctly handles: fresh-awaiting-review → stale; changes-requested-not-
yet-fixed → not stale; changes-requested-then-pushed → stale; approved-no-new-
commits → not stale; approved-then-pushed → stale; no-reviewer →
forgot-reviewer (not stale).

---

## Push layer (terminal mode)

No scheduler code lives in the tool. Wire terminal output into your own cron.
Example — weekday mornings at 8:30, emailed to yourself:

```cron
30 8 * * 1-5  GITHUB_TOKEN=... GH_LOGIN=you PROJECT_URL=... \
              ruby /path/sprint_plate.rb | mail -s "Sprint plate" you@example.com
```

Swap `mail` for `notify-send` (Linux desktop) or `terminal-notifier` (macOS).
Browser mode is for interactive/ambient use (optionally with `--watch`), not
cron.

---

## Architecture

**Engine → buckets → Surface**, in three separable layers:

1. **Engine** — pure, side-effect-free functions (GraphQL building, time math,
   classification). Unit-testable with zero network.
2. **Buckets** — a plain hash the engine returns.
3. **Surface** — consumes buckets and emits output, behind one tiny contract
   (`render(buckets, ...) -> String` + an `emit`). Two implementations
   (terminal, browser). Adding email or a menubar app later requires no engine
   change.

A single GraphQL call (aliased) runs both PR searches; the Projects V2 board is
fetched with paginated GraphQL. Everything is guarded by
`if __FILE__ == $PROGRAM_NAME` so the test suite can `require` the file without
running it or touching ENV.

---

## Tests

Every scenario in the spec's acceptance section is encoded as a test with a
fixed "today" (Monday 2026-06-22) and fabricated fixtures — zero network.

```sh
ruby test_plate.rb
# ...
# 30 passed, 0 failed
```

---

## Roadmap

A **v2** that abstracts the provider layer to support GitLab and other project
managers (Jira, Linear) is sketched in [V2.md](V2.md).

---

## Non-goals / known limitations

- The saved **view** filter DSL is **not** replicated; #3 is approximated by
  Status (+ optional iteration). Only org + project number are read from the URL.
- "Commented" reviews are intentionally ignored — a comment doesn't flip the ball.
- Any push (incl. a typo fix or rebase/force-push) resets the #4 clock by
  design ("you resubmitted"). To reset only on an explicit re-request, drop
  `last_push` from `handoff_at` in the engine.
- Browser mode is a **static snapshot** rendered in-process: no client-side
  GitHub calls, no live data except via `--watch` re-runs. The token never
  reaches the page.
- Single user, single token, no multi-tenant concerns.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security policy in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 cdrrazan
