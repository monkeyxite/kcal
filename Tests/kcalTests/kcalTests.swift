import Testing
import Foundation
@testable import KcalCore

// Fixed reference date: 2026-05-16 12:00:00 UTC
private let refDate: Date = {
    var c = DateComponents()
    c.year = 2026; c.month = 5; c.day = 16; c.hour = 12; c.minute = 0; c.second = 0
    c.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: c)!
}()

private let utcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func makeArgs(_ command: KcalArgs.Command, limit: Int? = nil, days: Int? = nil,
                      includeCals: [String] = [], excludeCals: [String] = [],
                      excludeAllDay: Bool = false, includeAllDayOnly: Bool = false,
                      match: (field: String, regex: String)? = nil,
                      sortBy: String? = nil, reverse: Bool = false,
                      outputFormat: OutputFormat = .json,
                      noCalendarName: Bool = false, noBullets: Bool = false) -> KcalArgs {
    KcalArgs(command: command, limit: limit, days: days,
             includeCals: includeCals, excludeCals: excludeCals,
             excludeAllDay: excludeAllDay, includeAllDayOnly: includeAllDayOnly,
             match: match, sortBy: sortBy, reverse: reverse,
             outputFormat: outputFormat, noCalendarName: noCalendarName, noBullets: noBullets)
}

// MARK: - parseArgs: commands

@Test func parseArgs_defaultsToEventsToday() {
    let a = parseArgs([], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 0)
    #expect(a.limit == nil)
}

@Test func parseArgs_eventsToday() {
    let a = parseArgs(["eventsToday"], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 0)
}

@Test func parseArgs_eventsTodayPlusN() {
    let a = parseArgs(["eventsToday+3"], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 3)
}

@Test func parseArgs_eventsTodayPlus1() {
    let a = parseArgs(["eventsToday+1"], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 1)
}

@Test func parseArgs_eventsNow() {
    let a = parseArgs(["eventsNow"], now: refDate)
    guard case .eventsNow = a.command else { Issue.record("wrong command"); return }
}

@Test func parseArgs_eventsRemaining() {
    let a = parseArgs(["eventsRemaining"], now: refDate)
    guard case .eventsRemaining = a.command else { Issue.record("wrong command"); return }
}

@Test func parseArgs_eventsWithDateRange() {
    let a = parseArgs(["events", "--from=2026-05-01", "--to=2026-05-31"], now: refDate)
    guard case .events(let from, let to) = a.command else { Issue.record("wrong command"); return }
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    #expect(fmt.string(from: from) == "2026-05-01")
    #expect(fmt.string(from: to) == "2026-05-31")
}

@Test func parseArgs_calendars() {
    let a = parseArgs(["calendars"], now: refDate)
    guard case .calendars = a.command else { Issue.record("wrong command"); return }
}

@Test func parseArgs_accounts() {
    let a = parseArgs(["accounts"], now: refDate)
    guard case .accounts = a.command else { Issue.record("wrong command"); return }
}

@Test func parseArgs_stores_aliasForAccounts() {
    let a = parseArgs(["stores"], now: refDate)
    guard case .accounts = a.command else { Issue.record("wrong command"); return }
}

@Test func parseArgs_tasks() {
    let a = parseArgs(["tasks"], now: refDate)
    guard case .tasks(let dated, let before) = a.command else { Issue.record("wrong command"); return }
    #expect(dated == nil); #expect(before == false)
}

@Test func parseArgs_reminders_aliasForTasks() {
    let a = parseArgs(["reminders"], now: refDate)
    guard case .tasks(let dated, _) = a.command else { Issue.record("wrong command"); return }
    #expect(dated == nil)
}

@Test func parseArgs_datedTasks() {
    let a = parseArgs(["datedTasks"], now: refDate)
    guard case .tasks(let dated, _) = a.command else { Issue.record("wrong command"); return }
    #expect(dated == true)
}

@Test func parseArgs_undatedTasks() {
    let a = parseArgs(["undatedTasks"], now: refDate)
    guard case .tasks(let dated, _) = a.command else { Issue.record("wrong command"); return }
    #expect(dated == false)
}

@Test func parseArgs_unknownCommandFallsBackToToday() {
    let a = parseArgs(["bogus"], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 0)
}

// MARK: - parseArgs: options

@Test func parseArgs_limitLongForm() {
    let a = parseArgs(["eventsToday", "--li=5"], now: refDate)
    #expect(a.limit == 5)
}

@Test func parseArgs_limitShortForm() {
    let a = parseArgs(["eventsToday", "--li", "3"], now: refDate)
    #expect(a.limit == 3)
}

@Test func parseArgs_days() {
    let a = parseArgs(["eventsToday", "--days=7"], now: refDate)
    #expect(a.days == 7)
}

@Test func parseArgs_includeCals() {
    let a = parseArgs(["eventsToday", "--ic=Work,Personal"], now: refDate)
    #expect(a.includeCals == ["Work", "Personal"])
}

@Test func parseArgs_excludeCals() {
    let a = parseArgs(["eventsToday", "--ec=Birthdays"], now: refDate)
    #expect(a.excludeCals == ["Birthdays"])
}

@Test func parseArgs_excludeAllDay() {
    let a = parseArgs(["eventsToday", "--ea"], now: refDate)
    #expect(a.excludeAllDay == true)
}

@Test func parseArgs_includeAllDayOnly() {
    let a = parseArgs(["eventsToday", "--ia"], now: refDate)
    #expect(a.includeAllDayOnly == true)
}

@Test func parseArgs_match() {
    let a = parseArgs(["eventsToday", "--match=notes=zoom.us"], now: refDate)
    #expect(a.match?.field == "notes")
    #expect(a.match?.regex == "zoom.us")
}

@Test func parseArgs_sort() {
    let a = parseArgs(["eventsToday", "--sort=title"], now: refDate)
    #expect(a.sortBy == "title")
}

@Test func parseArgs_reverse() {
    let a = parseArgs(["eventsToday", "-r"], now: refDate)
    #expect(a.reverse == true)
}

@Test func parseArgs_outputCSV() {
    let a = parseArgs(["eventsToday", "-o", "csv"], now: refDate)
    #expect(a.outputFormat == .csv)
}

@Test func parseArgs_fromRelativeDates() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: refDate)!
    let a = parseArgs(["events", "--from=tomorrow", "--to=tomorrow"], now: refDate)
    guard case .events(let from, _) = a.command else { Issue.record("wrong command"); return }
    #expect(abs(from.timeIntervalSince(tomorrow)) < 1)
}

// MARK: - dateRange

@Test func dateRange_eventsToday_spansFullDay() {
    let args = makeArgs(.eventsToday(offset: 0))
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == utcCal.startOfDay(for: refDate))
    #expect(end == utcCal.date(byAdding: .day, value: 1, to: utcCal.startOfDay(for: refDate))!)
}

@Test func dateRange_eventsTodayPlusOne_isTomorrow() {
    let args = makeArgs(.eventsToday(offset: 1))
    let (start, _) = dateRange(for: args, now: refDate, calendar: utcCal)
    let tomorrow = utcCal.date(byAdding: .day, value: 1, to: utcCal.startOfDay(for: refDate))!
    #expect(start == tomorrow)
}

@Test func dateRange_eventsToday_withDays() {
    let args = makeArgs(.eventsToday(offset: 0), days: 7)
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    let expected = utcCal.date(byAdding: .day, value: 7, to: utcCal.startOfDay(for: refDate))!
    #expect(start == utcCal.startOfDay(for: refDate))
    #expect(end == expected)
}

@Test func dateRange_eventsNow_startEqualsNow() {
    let args = makeArgs(.eventsNow)
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == refDate)
    #expect(end == refDate)
}

@Test func dateRange_eventsRemaining_startsFromNow() {
    let args = makeArgs(.eventsRemaining)
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == refDate)
    #expect(end > refDate)
}

@Test func dateRange_events_usesFromTo() {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = TimeZone(identifier: "UTC")
    let from = fmt.date(from: "2026-05-01")!
    let to   = fmt.date(from: "2026-05-03")!
    let args = makeArgs(.events(from: from, to: to))
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == utcCal.startOfDay(for: from))
    #expect(end == utcCal.date(byAdding: .day, value: 1, to: utcCal.startOfDay(for: to))!)
}

// MARK: - formatISO

@Test func formatISO_nilReturnsEmpty() {
    #expect(formatISO(nil) == "")
}

@Test func formatISO_formatsCorrectly() {
    let s = formatISO(refDate)
    #expect(s.hasPrefix("2026-05-16"))
    #expect(s.contains(":"))
}

// MARK: - toJSON / toCSV

@Test func toJSON_emptyArray() {
    #expect(toJSON([]) == "[\n\n]")
}

@Test func toJSON_roundtrips() throws {
    let dict: [String: Any] = ["title": "Standup", "attendees": ["Alice", "Bob"]]
    let json = toJSON([dict])
    let parsed = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
    #expect(parsed[0]["title"] as? String == "Standup")
    #expect((parsed[0]["attendees"] as? [String])?.count == 2)
}

@Test func toCSV_hasHeader() {
    let csv = toCSV([["title": "Standup", "location": "Zoom"]])
    let lines = csv.components(separatedBy: "\n")
    #expect(lines[0].contains("title"))
    #expect(lines[0].contains("location"))
    #expect(lines[1].contains("Standup"))
}

@Test func toCSV_emptyArray() {
    #expect(toCSV([]) == "")
}

@Test func toCSV_quotesCommas() {
    let csv = toCSV([["title": "A, B"]])
    #expect(csv.contains("\"A, B\""))
}
