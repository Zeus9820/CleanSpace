# App Review Notes — Draft

CleanSpace provides storage visibility and user-directed cleanup for the current user's files. It does not claim to optimize system performance.

## Current bootstrap build

| Path category | Access | Cleanup action | Safety control |
| --- | --- | --- | --- |
| `~/Library/Caches` | Read/write inside granted Home scope | Permanent deletion | Registered child paths only; preselected; consequence confirmed first |
| `~/.npm`, `~/.gradle/caches`, `~/.m2/repository`, Xcode Derived Data | Read/write inside granted Home scope | Permanent deletion | Registered paths only; safe caches preselected; consequence confirmed first |
| Hugging Face, Ollama and LM Studio registered model locations | Read/write inside granted Home scope | Optional permanent deletion | Versioned exact paths; never preselected; re-download warning |
| MobileSync backup items | Read/write inside granted Home scope | Move to Trash | Individual backups only; never preselected |
| `~/.Trash` | Read/write inside granted Home scope | Permanent deletion | Never preselected; destructive confirmation required |
| Application Support, Containers, Group Containers, simulators and Xcode Archives | Read-only measurement | Reveal in Finder only | No cleanup rule exists for unknown application data |
| Documents, Downloads, Desktop, Pictures, Movies and Music | Read-only measurement | Reveal in Finder only | Personal files are never deleted by CleanSpace |
| Volume capacity | Read-only Foundation resource keys | None | Displayed locally; never transmitted |

The cleanup executor rejects every item that lacks a matching registered rule, supported distribution profile, matching action, and component-aware path containment.

## Store access

The Store target requests the Home folder through `NSOpenPanel`, persists an app-scoped security-scoped bookmark, and shows denied, stale, or restored state in the dashboard. It cannot scan until access has been restored. Paths outside the granted scope remain unavailable or reveal-only.

## Privacy

The app is fully offline and includes no telemetry, accounts, tracking, or third-party packages. `PrivacyInfo.xcprivacy` declares disk-space API use with reason `85F4.1` because capacity is displayed directly to the user. It declares `UserDefaults` use with reason `CA92.1` for the Store build's app-scoped bookmark preference. File timestamps use `DDA9.1` to display sourced model activity; the Store manifest also declares `3B52.1` for metadata within the user-selected Home folder.
