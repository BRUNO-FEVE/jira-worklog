# WorklogBar

Native macOS menu bar app for Jira time tracking. Shows today's logged hours in the menu bar, lists your open assigned tickets with one-click worklog entry, and renders a weekly table of time logged per day per ticket.

## Installation

### One-line install (recommended)

Builds from source on your machine — no Gatekeeper warnings, no App Store. Requires the Swift toolchain (`xcode-select --install` if you don't have it):

```sh
curl -fsSL https://raw.githubusercontent.com/BRUNO-FEVE/jira-worklog/main/install.sh | sh
```

The app lands in `/Applications` and starts automatically. Look for the Jira icon in your menu bar.

### DMG

Download `WorklogBar-x.y.z.dmg` from [Releases](https://github.com/BRUNO-FEVE/jira-worklog/releases), open it, and drag WorklogBar into Applications.

> **First launch:** the DMG build is not yet notarized by Apple, so macOS will warn about an unidentified developer. Right-click the app → **Open** → **Open** (needed only once). If the option doesn't appear: `xattr -dr com.apple.quarantine /Applications/WorklogBar.app`

### Build from source manually

```sh
git clone https://github.com/BRUNO-FEVE/jira-worklog.git
cd jira-worklog
./make_app.sh && cp -R build/WorklogBar.app /Applications/
```

Other build modes:

```sh
swift run          # development, bare executable
./make_dmg.sh      # package a DMG into build/
xcodegen && xcodebuild -scheme WorklogBar -configuration Release build
                   # full build incl. desktop widgets (requires full Xcode)
```

## First-time setup

1. Click the Jira icon in the menu bar → **Settings**
2. Enter your Jira site URL (e.g. `https://yourcompany.atlassian.net`), your email, and an API token from [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens) (Data Center: just a Personal Access Token, no email)
3. **Save & Connect** — your tickets and week appear immediately

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
