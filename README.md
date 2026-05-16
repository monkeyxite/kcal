# kcal

![kcal banner](https://raw.githubusercontent.com/monkeyxite/kcal/master/assets/banner.png)

[![CI](https://github.com/monkeyxite/kcal/actions/workflows/ci.yml/badge.svg)](https://github.com/monkeyxite/kcal/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple)
![License](https://img.shields.io/badge/license-MIT-blue)
![Version](https://img.shields.io/badge/version-0.2.0-green)

Fast macOS Calendar CLI using EventKit directly. **~100ms vs ~3s for icalpal** — 30–40× faster, no Ruby runtime.

Drop-in replacement for [icalPal](https://github.com/ajrosen/icalPal) for common workflows.

---

## Install

```sh
git clone https://github.com/monkeyxite/kcal
cd kcal
swift build -c release
cp .build/release/kcal ~/.local/bin/kcal
codesign --force --sign - --entitlements kcal.entitlements ~/.local/bin/kcal
```

Grant calendar access when prompted on first run.

---

## Commands

| Command | Description |
|---|---|
| `eventsToday` | Events today |
| `eventsToday+N` | Events N days from now |
| `eventsNow` | Events happening right now |
| `eventsRemaining` | Events from now until midnight |
| `events` | Events in a date range |
| `calendars` | List all calendars |
| `accounts` / `stores` | List all accounts |
| `tasks` / `reminders` | All reminders |
| `datedTasks` / `datedReminders` | Reminders with a due date |
| `undatedTasks` / `undatedReminders` | Reminders without a due date |
| `tasksDueBefore` / `remindersDueBefore` | Reminders due in date range |

---

## Options

### Date

| Flag | Description |
|---|---|
| `--from=DATE` | Start date |
| `--to=DATE` | End date |
| `--days=N` | N days from start date |

`DATE` accepts: `today`, `tomorrow`, `yesterday`, `+N`, `-N`, `YYYY-MM-DD`

### Filtering

| Flag | Description |
|---|---|
| `--ic=CALENDARS` | Include only these calendars (comma-separated) |
| `--ec=CALENDARS` | Exclude these calendars (comma-separated) |
| `--ea` | Exclude all-day events |
| `--ia` | Include only all-day events |
| `--match=FIELD=REGEX` | Filter by field regex (case-insensitive) |
| `--li=N` | Limit to N results |

`FIELD` for `--match`: `title`, `notes`, `location`, `url`, `calendar`

### Output

| Flag | Description |
|---|---|
| `-o json` | JSON output (default) |
| `-o csv` | CSV output |
| `--sort=PROPERTY` | Sort by `datetime` (default), `title`, `calendar`, `location` |
| `-r`, `--reverse` | Reverse sort order |
| `--nc` | No calendar names |
| `--nb` | No bullets |

---

## Examples

```sh
# Tomorrow's events
kcal eventsToday+1

# Next 7 days
kcal eventsToday --days=7

# Only Zoom meetings
kcal eventsToday --match=notes=zoom.us

# Events sorted by title, reversed
kcal events --from=2026-05-01 --to=2026-05-31 --sort=title -r

# Exclude all-day events, limit 5
kcal eventsToday --ea --li=5

# Work calendar only, CSV
kcal events --from=2026-05-01 --to=2026-05-31 --ic=Work -o csv

# List calendars
kcal calendars

# Reminders with due dates
kcal datedTasks
```

---

## JSON Output

### Events

```json
{
  "title": "Standup",
  "datetime": "2026-05-16 09:00:00",
  "sctime": "2026-05-16 09:00:00",
  "ectime": "2026-05-16 09:30:00",
  "start_date": 1747386000.0,
  "end_date": 1747387800.0,
  "attendees": ["Alice", "Bob"],
  "notes": "",
  "url": "",
  "conference_url_detected": "https://meet.google.com/abc",
  "location": "Conference Room",
  "calendar": "Work",
  "all_day": false
}
```

### Calendars

```json
{
  "title": "Work",
  "type": "CalDAV",
  "account": "Google",
  "color": "#4285F4"
}
```

### Reminders

```json
{
  "title": "Send report",
  "notes": "",
  "calendar": "Reminders",
  "completed": false,
  "due": "2026-05-17 09:00:00",
  "due_date": 1747472400.0,
  "priority": 0
}
```

---

## Integrations

- **[kms-select](https://github.com/monkeyxite/dotfiles)** — fzf meeting picker + MoM generation
- **nvim-mail** — Telescope calendar picker
- **icalpal-md** — markdown table of day's events
- **cal.sh** — tmux status bar next meeting

---

## Performance

| Tool | Time (eventsToday) | Time (1 month) |
|---|---|---|
| icalpal | ~3.3s | ~2.9s |
| kcal | ~85ms | ~350ms |

---

## Requirements

- macOS 14+
- Xcode 15+ / Swift 5.9+
- Calendar access permission

---

## License

MIT
