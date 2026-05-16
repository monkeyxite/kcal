# kcal

Fast macOS Calendar CLI. Reads EventKit directly — ~100ms vs ~3s for icalpal.

## Install

```sh
swift build -c release
cp .build/release/kcal ~/.local/bin/kcal
codesign --force --sign - --entitlements kcal.entitlements ~/.local/bin/kcal
```

Grant calendar access when prompted on first run.

## Commands

| Command | Description |
|---|---|
| `kcal eventsToday` | Today's events |
| `kcal eventsToday+1` | Tomorrow's events |
| `kcal eventsToday+N` | Events N days from now |
| `kcal eventsRemaining` | Remaining events today (from now) |
| `kcal events --from=YYYY-MM-DD --to=YYYY-MM-DD` | Events in date range |

## Options

| Flag | Description |
|---|---|
| `--li N` | Limit output to N events |

## Output

JSON array. Each event:

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
  "conference_url_detected": "https://meet.google.com/...",
  "location": ""
}
```

## Integrations

- **kms-select** — fzf meeting picker, MoM generation
- **nvim-mail** — Telescope calendar picker
- **icalpal-md** — markdown table of day's events
- **cal.sh** — tmux status bar next meeting
