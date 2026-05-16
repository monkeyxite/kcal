import EventKit
import Foundation

// MARK: - Argument Parsing

/// Parsed representation of CLI arguments.
public struct KcalArgs {
    public enum Command {
        /// Events for a specific day offset from today (0 = today, 1 = tomorrow, etc.)
        case eventsToday(offset: Int)
        /// Remaining events from now until end of today
        case eventsRemaining
        /// Events in an explicit date range
        case events(from: Date, to: Date)
    }
    public let command: Command
    /// Maximum number of events to return (nil = unlimited)
    public let limit: Int?

    public init(command: Command, limit: Int?) {
        self.command = command
        self.limit = limit
    }
}

/// Parse raw CLI arguments into a `KcalArgs` value.
///
/// Supported forms:
/// - `eventsToday`          → today
/// - `eventsToday+N`        → N days from today
/// - `eventsRemaining`      → from now until end of today
/// - `events --from=YYYY-MM-DD --to=YYYY-MM-DD`
/// - `--li N` or `--li=N`  → limit results
public func parseArgs(_ args: [String], now: Date = Date()) -> KcalArgs {
    let cmd = args.first ?? "eventsToday"

    // Parse --li
    var limit: Int? = nil
    if let idx = args.firstIndex(where: { $0.hasPrefix("--li=") }) {
        limit = Int(args[idx].dropFirst(5))
    } else if let idx = args.firstIndex(of: "--li"), idx + 1 < args.count {
        limit = Int(args[idx + 1])
    }

    let command: KcalArgs.Command
    if cmd.hasPrefix("eventsToday") {
        let suffix = cmd.dropFirst("eventsToday".count).replacingOccurrences(of: "+", with: "")
        let offset = Int(suffix) ?? 0
        command = .eventsToday(offset: offset)
    } else if cmd == "eventsRemaining" {
        command = .eventsRemaining
    } else if cmd == "events" {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var from = now, to = now
        for arg in args.dropFirst() {
            if arg.hasPrefix("--from=") { from = fmt.date(from: String(arg.dropFirst(7))) ?? now }
            if arg.hasPrefix("--to=") { to = fmt.date(from: String(arg.dropFirst(5))) ?? now }
        }
        command = .events(from: from, to: to)
    } else {
        command = .eventsToday(offset: 0)
    }

    return KcalArgs(command: command, limit: limit)
}

// MARK: - Date Range

/// Compute the EventKit query `(start, end)` interval for the given command.
public func dateRange(for args: KcalArgs, now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
    func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }
    func endOfDay(_ d: Date) -> Date { calendar.date(byAdding: .day, value: 1, to: startOfDay(d))! }

    switch args.command {
    case .eventsToday(let offset):
        let day = calendar.date(byAdding: .day, value: offset, to: now)!
        return (startOfDay(day), endOfDay(day))
    case .eventsRemaining:
        return (now, endOfDay(now))
    case .events(let from, let to):
        return (startOfDay(from), endOfDay(to))
    }
}

// MARK: - JSON Serialisation

/// Format a `Date` as `"YYYY-MM-DD HH:MM:SS"` in local time (matches icalpal sctime/ectime format).
public func formatISO(_ date: Date?) -> String {
    guard let date else { return "" }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
    return fmt.string(from: date)
}

/// Serialise an `EKEvent` to the JSON dictionary shape consumed by kms-select, nvim-mail, icalpal-md, and cal.sh.
///
/// Fields:
/// - `title`, `datetime`, `sctime`, `ectime` — ISO-8601 strings
/// - `start_date`, `end_date`                — Unix timestamps (Double)
/// - `attendees`                             — display names
/// - `notes`, `url`, `conference_url_detected`, `location`
public func eventToDict(_ event: EKEvent) -> [String: Any] {
    let attendees = (event.attendees ?? []).compactMap { $0.name }
    let urlStr = event.url?.absoluteString ?? ""
    return [
        "title":                    event.title ?? "",
        "datetime":                 formatISO(event.startDate),
        "sctime":                   formatISO(event.startDate),
        "ectime":                   formatISO(event.endDate),
        "start_date":               event.startDate.timeIntervalSince1970,
        "end_date":                 (event.endDate ?? event.startDate).timeIntervalSince1970,
        "attendees":                attendees,
        "notes":                    event.notes ?? "",
        "url":                      urlStr,
        "conference_url_detected":  urlStr,
        "location":                 event.location ?? "",
    ]
}

/// Render a list of event dictionaries as a pretty-printed JSON string.
public func toJSON(_ dicts: [[String: Any]]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted])
    return String(data: data, encoding: .utf8)!
}
