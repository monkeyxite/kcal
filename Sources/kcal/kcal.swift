import EventKit
import Foundation
import KcalCore

// MARK: - Help

let helpText = """
Usage: kcal [options] [-c] COMMAND

Commands:
  eventsToday[+N]      Events today, or N days from now
  eventsNow            Events happening right now
  eventsRemaining      Events from now until midnight
  events               Events in a date range
  calendars            List calendars
  accounts             List accounts (alias: stores)
  tasks                List reminders (alias: reminders)
  datedTasks           Reminders with a due date
  undatedTasks         Reminders without a due date
  tasksDueBefore       Reminders due in date range

Date options:
  --from=DATE          Start date (today, tomorrow, yesterday, +N, -N, YYYY-MM-DD)
  --to=DATE            End date
  --days=N             N days from start date

Filtering:
  --ic=CALENDARS       Include only these calendars (comma-separated)
  --ec=CALENDARS       Exclude these calendars (comma-separated)
  --ea                 Exclude all-day events
  --ia                 Include only all-day events
  --match=FIELD=REGEX  Filter by field regex (fields: title, notes, location, url, calendar)

Output:
  --li=N               Limit to N items
  --sort=PROPERTY      Sort by property (datetime, title, calendar, location)
  -r, --reverse        Reverse sort order
  -o, --output=FORMAT  Output format: json (default), csv
  --nc                 No calendar names in output
  --nb                 No bullets

  -h, --help           Show this help
"""

// MARK: - Entry point

let rawArgs = Array(CommandLine.arguments.dropFirst())
if rawArgs.isEmpty || rawArgs.first == "--help" || rawArgs.first == "-h" {
    print(helpText); exit(0)
}

let args = parseArgs(rawArgs)

// Request appropriate access
let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)

let needsReminders: Bool
switch args.command {
case .tasks, .calendars, .accounts: needsReminders = true
default: needsReminders = false
}

if needsReminders {
    store.requestFullAccessToReminders { _, _ in sema.signal() }
} else {
    store.requestFullAccessToEvents { granted, _ in
        guard granted else { print("[]"); exit(1) }
        sema.signal()
    }
}
sema.wait()

// MARK: - Execute command

func output(_ dicts: [[String: Any]]) {
    switch args.outputFormat {
    case .csv:     print(toCSV(dicts))
    default:       print(toJSON(dicts))
    }
}

switch args.command {

case .calendars:
    let cals = store.calendars(for: .event) + store.calendars(for: .reminder)
    output(cals.map(calendarToDict))

case .accounts:
    output(store.sources.map(sourceToDict))

case .tasks(let dated, _):
    let taskSema = DispatchSemaphore(value: 0)
    var results: [EKReminder] = []
    let pred = store.predicateForReminders(in: nil)
    store.fetchReminders(matching: pred) { reminders in
        results = reminders ?? []
        taskSema.signal()
    }
    taskSema.wait()

    var filtered = filterReminders(results, args: args)
    switch dated {
    case true:  filtered = filtered.filter { $0.dueDateComponents != nil }
    case false: filtered = filtered.filter { $0.dueDateComponents == nil }
    case nil:   break
    }
    if let l = args.limit { filtered = Array(filtered.prefix(l)) }
    output(filtered.map(reminderToDict))

default:
    let (start, end) = dateRange(for: args)
    let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    var events = store.events(matching: pred)

    // eventsNow: only events currently in progress
    if case .eventsNow = args.command {
        let now = Date()
        events = events.filter { $0.startDate <= now && ($0.endDate ?? now) >= now }
    }

    events = filterEvents(events, args: args)
    events = sortEvents(events, by: args.sortBy, reverse: args.reverse)
    if let l = args.limit { events = Array(events.prefix(l)) }
    output(events.map(eventToDict))
}
