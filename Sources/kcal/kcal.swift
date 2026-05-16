import EventKit
import Foundation

let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)

store.requestFullAccessToEvents { granted, _ in
    guard granted else { print("[]"); exit(1) }
    sema.signal()
}
sema.wait()

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "eventsToday"

let cal = Calendar.current
let now = Date()

func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
func endOfDay(_ d: Date) -> Date { cal.date(byAdding: .day, value: 1, to: startOfDay(d))! }

var start: Date
var end: Date
var remaining = false
var limit: Int? = nil

// Parse --li flag
if let liIdx = args.firstIndex(where: { $0.hasPrefix("--li=") }) {
    limit = Int(args[liIdx].dropFirst(5))
} else if let liIdx = args.firstIndex(of: "--li"), liIdx + 1 < args.count {
    limit = Int(args[liIdx + 1])
}

if cmd.hasPrefix("eventsToday") {
    let offset = Int(cmd.dropFirst("eventsToday".count).replacingOccurrences(of: "+", with: "")) ?? 0
    let day = cal.date(byAdding: .day, value: offset, to: now)!
    start = startOfDay(day); end = endOfDay(day)
} else if cmd == "eventsRemaining" {
    start = now; end = endOfDay(now); remaining = true
} else if cmd == "events" {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    var fromDate = now, toDate = now
    for arg in args.dropFirst() {
        if arg.hasPrefix("--from=") { fromDate = fmt.date(from: String(arg.dropFirst(7))) ?? now }
        if arg.hasPrefix("--to=") { toDate = fmt.date(from: String(arg.dropFirst(5))) ?? now }
    }
    start = startOfDay(fromDate); end = endOfDay(toDate)
} else {
    start = startOfDay(now); end = endOfDay(now)
}

let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
var events = store.events(matching: pred).sorted { $0.startDate < $1.startDate }
if let l = limit { events = Array(events.prefix(l)) }

let iso = ISO8601DateFormatter()
iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]

func fmtISO(_ d: Date?) -> String { d.map { iso.string(from: $0) } ?? "" }

var out: [[String: Any]] = []
for e in events {
    let attendees = (e.attendees ?? []).compactMap { $0.name }
    out.append([
        "title": e.title ?? "",
        "datetime": fmtISO(e.startDate),
        "sctime": fmtISO(e.startDate),
        "ectime": fmtISO(e.endDate),
        "start_date": e.startDate.timeIntervalSince1970,
        "end_date": (e.endDate ?? e.startDate).timeIntervalSince1970,
        "attendees": attendees,
        "notes": e.notes ?? "",
        "url": e.url?.absoluteString ?? "",
        "conference_url_detected": e.url?.absoluteString ?? "",
        "location": e.location ?? "",
    ])
}

let data = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted])
print(String(data: data, encoding: .utf8)!)
