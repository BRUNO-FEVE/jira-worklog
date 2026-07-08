# Contributing to WorklogBar

Thanks for your interest! WorklogBar is a native SwiftUI menu bar app for Jira time tracking, MIT-licensed and maintained by [Bruno Fevereiro](https://www.linkedin.com/in/bruno-fevereiro/).

## Getting started

```sh
git clone https://github.com/BRUNO-FEVE/jira-worklog.git
cd jira-worklog
swift run          # development build (bare executable)
```

You'll need macOS 14+ and the Swift toolchain (`xcode-select --install`). No other dependencies — the app is a single SwiftPM executable target. `./make_app.sh` produces the `.app` bundle; the widget extension additionally needs full Xcode (`xcodegen && xcodebuild`).

To test against a real Jira you can create a free Cloud site at [atlassian.com/software/jira/free](https://www.atlassian.com/software/jira/free) and an API token at [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens).

## Project layout

- `Sources/WorklogBar/JiraClient.swift` — REST client; handles Cloud (Basic auth, `/rest/api/3/search/jql`) vs Data Center (Bearer PAT, `/rest/api/2/search`)
- `Sources/WorklogBar/AppState.swift` — observable state: tickets, week grid, reminders, settings
- `Sources/WorklogBar/Views.swift` — all SwiftUI views (tabs, grid, popovers)
- `WidgetExtension/` — WidgetKit desktop widgets, fed by `Snapshot.swift`

## Pull requests

- Branch from `main`; PRs are squash-merged
- Keep changes focused — one feature or fix per PR
- Make sure `swift build` passes with no warnings
- If you change UI, include a screenshot in the PR
- If you change Jira API behavior, note whether you tested on Cloud, Data Center, or both

## Bugs and ideas

Open an [issue](https://github.com/BRUNO-FEVE/jira-worklog/issues) with the template. For bugs, include your macOS version and whether your Jira is Cloud or Data Center — never include your API token or site data in logs.
