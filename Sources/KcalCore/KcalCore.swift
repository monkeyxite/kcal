import EventKit
import Foundation

// MARK: - Types

public enum OutputFormat: String {
    case json, csv, default_ = "default"
}

public struct KcalArgs {
    public enum Command {
        case eventsToday(offset: Int)
        case eventsNow
        case eventsRemaining
        case events(from: Date, to: Date)
        case calendars
        case accounts
        case tasks(dated: Bool?, before: Bool)  // nil=all, true=dated, false=undated
    }

    public let command: Command
    public let limit: Int?
    public let days: Int?
    public let includeCals: [String]    // --ic
    public let excludeCals: [String]    // --ec
    public let excludeAllDay: Bool      // --ea
    public let includeAllDayOnly: Bool  // --ia
    public let match: (field: String, regex: String)?  // --match=FIELD=REGEX
    public let sortBy: String?          // --sort
    public let reverse: Bool            // -r
    public let outputFormat: OutputFormat
    public let noCalendarName: Bool     // --nc
    public let noBullets: Bool          // --nb

    public init(command: Command, limit: Int?, days: Int?,
                includeCals: [String], excludeCals: [String],
                excludeAllDay: Bool, includeAllDayOnly: Bool,
                match: (field: String, regex: String)?,
                sortBy: String?, reverse: Bool,
                outputFormat: OutputFormat,
                noCalendarName: Bool, noBullets: Bool) {
        self.command = command; self.limit = limit; self.days = days
        self.includeCals = includeCals; self.excludeCals = excludeCals
        self.excludeAllDay = excludeAllDay; self.includeAllDayOnly = includeAllDayOnly
        self.match = match; self.sortBy = sortBy; self.reverse = reverse
        self.outputFormat = outputFormat
        self.noCalendarName = noCalendarName; self.noBullets = noBullets
    }
}

// MARK: - Argument Parsing

/// Parse raw CLI arguments into a `KcalArgs` value.
///
/// Supported commands: eventsToday[+N], eventsNow, eventsRemaining,
/// events, calendars, accounts, tasks, datedTasks, undatedTasks,
/// tasksDueBefore, reminders, stores
///
/// Supported options: --from, --to, --days, --li, --ic, --ec,
/// --ea, --ia, --match, --sort, -r/--reverse, -o/--output,
/// --nc, --nb, --iep, --eep, --aep (accepted, ignored for compat)
public func parseArgs(_ args: [String], now: Date = Date()) -> KcalArgs {
    // Find command (first non-flag arg, or via -c/--cmd)
    var cmdStr = "eventsToday"
    let remaining = args

    // -c / --cmd
    if let ci = args.firstIndex(where: { $0 == "-c" || $0 == "--cmd" }), ci + 1 < args.count {
        cmdStr = args[ci + 1]
    } else if let ci = args.firstIndex(where: { $0.hasPrefix("--cmd=") }) {
        cmdStr = String(args[ci].dropFirst(6))
    } else if let first = args.first(where: { !$0.hasPrefix("-") }) {
        cmdStr = first
    }

    func flag(_ names: String...) -> Bool {
        names.contains(where: { remaining.contains($0) })
    }
    func opt(_ prefix: String, short: String? = nil) -> String? {
        if let i = remaining.firstIndex(where: { $0.hasPrefix(prefix + "=") }) {
            return String(remaining[i].dropFirst(prefix.count + 1))
        }
        let flags = short.map { [$0] } ?? [] as [String]
        if let i = remaining.firstIndex(where: { flags.contains($0) || $0 == prefix }), i + 1 < remaining.count {
            return remaining[i + 1]
        }
        return nil
    }

    let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
    func parseDate(_ s: String) -> Date {
        if s == "today" { return now }
        if s == "tomorrow" { return Calendar.current.date(byAdding: .day, value: 1, to: now)! }
        if s == "yesterday" { return Calendar.current.date(byAdding: .day, value: -1, to: now)! }
        if s.hasPrefix("+"), let n = Int(s.dropFirst()) { return Calendar.current.date(byAdding: .day, value: n, to: now)! }
        if s.hasPrefix("-"), let n = Int(s.dropFirst()) { return Calendar.current.date(byAdding: .day, value: -n, to: now)! }
        return dateFmt.date(from: s) ?? now
    }

    let fromDate = opt("--from").map(parseDate) ?? now
    let toDate   = opt("--to").map(parseDate) ?? now
    let days     = opt("--days").flatMap(Int.init)
    let limit    = opt("--li").flatMap(Int.init)
    let sortBy   = opt("--sort")
    let outFmt   = OutputFormat(rawValue: opt("--output", short: "-o") ?? "json") ?? .json

    let includeCals = opt("--ic")?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    let excludeCals = opt("--ec")?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []

    var matchArg: (field: String, regex: String)? = nil
    if let m = opt("--match") {
        let parts = m.components(separatedBy: "=")
        if parts.count >= 2 { matchArg = (parts[0], parts[1...].joined(separator: "=")) }
    }

    let command: KcalArgs.Command
    switch cmdStr {
    case "eventsNow":
        command = .eventsNow
    case "eventsRemaining":
        command = .eventsRemaining
    case "events":
        command = .events(from: fromDate, to: toDate)
    case "calendars":
        command = .calendars
    case "accounts", "stores":
        command = .accounts
    case "tasks", "reminders":
        command = .tasks(dated: nil, before: false)
    case "datedTasks", "datedReminders":
        command = .tasks(dated: true, before: false)
    case "undatedTasks", "undatedReminders":
        command = .tasks(dated: false, before: false)
    case "tasksDueBefore", "remindersDueBefore":
        command = .tasks(dated: true, before: true)
    default:
        if cmdStr.hasPrefix("eventsToday") {
            let suffix = cmdStr.dropFirst("eventsToday".count).replacingOccurrences(of: "+", with: "")
            command = .eventsToday(offset: Int(suffix) ?? 0)
        } else {
            command = .eventsToday(offset: 0)
        }
    }

    return KcalArgs(
        command: command, limit: limit, days: days,
        includeCals: includeCals, excludeCals: excludeCals,
        excludeAllDay: flag("--ea"), includeAllDayOnly: flag("--ia"),
        match: matchArg, sortBy: sortBy, reverse: flag("-r", "--reverse"),
        outputFormat: outFmt,
        noCalendarName: flag("--nc"), noBullets: flag("--nb")
    )
}

// MARK: - Date Range

/// Compute the EventKit query `(start, end)` interval for the given command.
public func dateRange(for args: KcalArgs, now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
    func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }
    func endOfDay(_ d: Date) -> Date { calendar.date(byAdding: .day, value: 1, to: startOfDay(d))! }

    switch args.command {
    case .eventsToday(let offset):
        let base = calendar.date(byAdding: .day, value: offset, to: now)!
        let start = startOfDay(base)
        if let days = args.days {
            let end = calendar.date(byAdding: .day, value: days, to: start)!
            return (start, end)
        }
        return (start, endOfDay(base))
    case .eventsNow:
        return (now, now)
    case .eventsRemaining:
        return (now, endOfDay(now))
    case .events(let from, let to):
        let start = startOfDay(from)
        if let days = args.days {
            return (start, calendar.date(byAdding: .day, value: days, to: start)!)
        }
        return (start, endOfDay(to))
    default:
        return (startOfDay(now), endOfDay(now))
    }
}

// MARK: - Filtering

/// Apply calendar include/exclude, all-day, and --match filters to events.
public func filterEvents(_ events: [EKEvent], args: KcalArgs) -> [EKEvent] {
    var result = events

    if !args.includeCals.isEmpty {
        result = result.filter { e in args.includeCals.contains(e.calendar?.title ?? "") }
    }
    if !args.excludeCals.isEmpty {
        result = result.filter { e in !args.excludeCals.contains(e.calendar?.title ?? "") }
    }
    if args.excludeAllDay {
        result = result.filter { !$0.isAllDay }
    }
    if args.includeAllDayOnly {
        result = result.filter { $0.isAllDay }
    }
    if let (field, pattern) = args.match,
       let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        result = result.filter { e in
            let val = eventFieldString(e, field: field)
            return regex.firstMatch(in: val, range: NSRange(val.startIndex..., in: val)) != nil
        }
    }
    return result
}

/// Apply calendar include/exclude and --match filters to reminders.
public func filterReminders(_ reminders: [EKReminder], args: KcalArgs) -> [EKReminder] {
    var result = reminders

    if !args.includeCals.isEmpty {
        result = result.filter { args.includeCals.contains($0.calendar?.title ?? "") }
    }
    if !args.excludeCals.isEmpty {
        result = result.filter { !args.excludeCals.contains($0.calendar?.title ?? "") }
    }
    if let (_, pattern) = args.match,
       let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        result = result.filter { r in
            let val = r.title ?? ""
            return regex.firstMatch(in: val, range: NSRange(val.startIndex..., in: val)) != nil
        }
    }
    return result
}

private func eventFieldString(_ e: EKEvent, field: String) -> String {
    switch field.lowercased() {
    case "title":    return e.title ?? ""
    case "notes":    return e.notes ?? ""
    case "location": return e.location ?? ""
    case "url":      return e.url?.absoluteString ?? ""
    case "calendar": return e.calendar?.title ?? ""
    default:         return e.title ?? ""
    }
}

// MARK: - Sorting

/// Sort events by a named property, optionally reversed.
public func sortEvents(_ events: [EKEvent], by property: String?, reverse: Bool) -> [EKEvent] {
    var sorted = events
    switch property?.lowercased() {
    case "title":    sorted.sort { ($0.title ?? "") < ($1.title ?? "") }
    case "calendar": sorted.sort { ($0.calendar?.title ?? "") < ($1.calendar?.title ?? "") }
    case "location": sorted.sort { ($0.location ?? "") < ($1.location ?? "") }
    default:         sorted.sort { $0.startDate < $1.startDate }  // datetime (default)
    }
    return reverse ? sorted.reversed() : sorted
}

// MARK: - Serialisation

/// Format a `Date` as `"YYYY-MM-DD HH:MM:SS"` in local time (matches icalpal sctime/ectime format).
public func formatISO(_ date: Date?) -> String {
    guard let date else { return "" }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
    fmt.timeZone = TimeZone.current
    return fmt.string(from: date)
}

/// Strip Windows-style carriage returns from calendar data.
private func clean(_ s: String?) -> String { (s ?? "").replacingOccurrences(of: "\r", with: "") }

/// Serialise an `EKEvent` to a dictionary.
///
/// Fields: title, datetime, sctime, ectime, start_date, end_date,
/// attendees, notes, url, conference_url_detected, location, calendar, all_day
public func eventToDict(_ event: EKEvent) -> [String: Any] {
    let attendees = (event.attendees ?? []).compactMap { $0.name }.map { clean($0) }
    let urlStr = clean(event.url?.absoluteString)
    return [
        "title":                    clean(event.title),
        "datetime":                 formatISO(event.startDate),
        "sctime":                   formatISO(event.startDate),
        "ectime":                   formatISO(event.endDate),
        "start_date":               event.startDate.timeIntervalSince1970,
        "end_date":                 (event.endDate ?? event.startDate).timeIntervalSince1970,
        "attendees":                attendees,
        "notes":                    clean(event.notes),
        "url":                      urlStr,
        "conference_url_detected":  urlStr,
        "location":                 clean(event.location),
        "calendar":                 clean(event.calendar?.title),
        "all_day":                  event.isAllDay,
    ]
}

/// Serialise an `EKCalendar` to a dictionary.
public func calendarToDict(_ cal: EKCalendar) -> [String: Any] {
    [
        "title":   cal.title,
        "type":    calendarTypeName(cal.type),
        "account": cal.source?.title ?? "",
        "color":   cal.cgColor.map { hexColor($0) } ?? "",
    ]
}

/// Serialise an `EKSource` (account) to a dictionary.
public func sourceToDict(_ source: EKSource) -> [String: Any] {
    [
        "title": source.title,
        "type":  sourceTypeName(source.sourceType),
    ]
}

/// Serialise an `EKReminder` to a dictionary.
public func reminderToDict(_ r: EKReminder) -> [String: Any] {
    var due = ""
    var dueTs: Double = 0
    if let dc = r.dueDateComponents, let d = Calendar.current.date(from: dc) {
        due = formatISO(d); dueTs = d.timeIntervalSince1970
    }
    return [
        "title":     clean(r.title),
        "notes":     clean(r.notes),
        "calendar":  clean(r.calendar?.title),
        "completed": r.isCompleted,
        "due":       due,
        "due_date":  dueTs,
        "priority":  r.priority,
    ]
}

/// Render a list of dictionaries as pretty-printed JSON.
public func toJSON(_ dicts: [[String: Any]]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted])
    return String(data: data, encoding: .utf8)!
}

/// Render a list of dictionaries as CSV (keys from first row as header).
public func toCSV(_ dicts: [[String: Any]]) -> String {
    guard let first = dicts.first else { return "" }
    let keys = first.keys.sorted()
    var lines = [keys.joined(separator: ",")]
    for d in dicts {
        let row = keys.map { k -> String in
            let v = "\(d[k] ?? "")"
            return v.contains(",") || v.contains("\"") || v.contains("\n")
                ? "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\""
                : v
        }
        lines.append(row.joined(separator: ","))
    }
    return lines.joined(separator: "\n")
}

// MARK: - Helpers

private func calendarTypeName(_ type: EKCalendarType) -> String {
    switch type {
    case .local:       return "Local"
    case .calDAV:      return "CalDAV"
    case .exchange:    return "Exchange"
    case .subscription: return "Subscribed"
    case .birthday:    return "Birthdays"
    @unknown default:  return "Unknown"
    }
}

private func sourceTypeName(_ type: EKSourceType) -> String {
    switch type {
    case .local:       return "Local"
    case .exchange:    return "Exchange"
    case .calDAV:      return "CalDAV"
    case .mobileMe:    return "MobileMe"
    case .subscribed:  return "Subscribed"
    case .birthdays:   return "Birthdays"
    @unknown default:  return "Unknown"
    }
}

private func hexColor(_ cg: CGColor) -> String {
    guard let c = cg.components, c.count >= 3 else { return "" }
    return String(format: "#%02X%02X%02X", Int(c[0]*255), Int(c[1]*255), Int(c[2]*255))
}
