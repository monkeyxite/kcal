import EventKit
import Foundation
import KcalCore

let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)
store.requestFullAccessToEvents { granted, _ in
    guard granted else { print("[]"); exit(1) }
    sema.signal()
}
sema.wait()

let rawArgs = Array(CommandLine.arguments.dropFirst())
if rawArgs.first == "--help" || rawArgs.first == "-h" {
    print("""
    Usage: kcal <command> [options]

    Commands:
      eventsToday          Today's events
      eventsToday+N        Events N days from now (e.g. eventsToday+1)
      eventsRemaining      Remaining events from now until end of today
      events               Events in a date range

    Options:
      --from=YYYY-MM-DD    Start date (use with 'events')
      --to=YYYY-MM-DD      End date   (use with 'events')
      --li N               Limit output to N events
      --help, -h           Show this help

    Output: JSON array with fields: title, datetime, sctime, ectime,
            start_date, end_date, attendees, notes, url,
            conference_url_detected, location
    """)
    exit(0)
}
let args = parseArgs(rawArgs)
let (start, end) = dateRange(for: args)
let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
var events = store.events(matching: pred).sorted { $0.startDate < $1.startDate }
if let l = args.limit { events = Array(events.prefix(l)) }

print(toJSON(events.map(eventToDict)))
