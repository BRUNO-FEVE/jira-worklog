# WorklogBar

Native macOS menu bar app for Jira time tracking. Shows today's logged hours in the menu bar, lists your open assigned tickets with one-click worklog entry, and renders a weekly table of time logged per day per ticket.

## Run

Development (bare executable):

```sh
swift run
```

App bundle without Xcode (no widgets — installs menu bar app only):

```sh
./make_app.sh && cp -R build/WorklogBar.app /Applications/
```

Full build with desktop widgets (requires full Xcode from the App Store):

```sh
xcodegen
xcodebuild -scheme WorklogBar -configuration Release build
```

A clock icon appears in the menu bar. Open **Settings** inside the popover and enter:

- **Jira URL** — e.g. `https://yourcompany.atlassian.net` (Cloud) or your self-hosted Data Center URL
- **Email** — only needed for Cloud
- **Token** — Cloud: API token from [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens); Data Center: a Personal Access Token from your Jira profile

The token is stored in the macOS Keychain. Cloud vs Data Center auth (Basic vs Bearer) is auto-detected from the URL.

## Features

- **Tickets** — open issues assigned to you (`assignee = currentUser() AND resolution = EMPTY`); click a row to log time (`1h 30m`, `45m`, or `1.5` for hours) on any date
- **Week** — Monday–Sunday grid of your worklogs per ticket, with per-day and per-ticket totals
- **Menu bar** — total time logged today

## Notes

- Jira Cloud API tokens expire after at most one year; the app surfaces a clear 401 message when that happens.
- Old Jira Server (< 8.14, no PAT support) is not supported.
