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

// MARK: - parseArgs

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

@Test func parseArgs_limitLongForm() {
    let a = parseArgs(["eventsToday", "--li=5"], now: refDate)
    #expect(a.limit == 5)
}

@Test func parseArgs_limitShortForm() {
    let a = parseArgs(["eventsToday", "--li", "3"], now: refDate)
    #expect(a.limit == 3)
}

@Test func parseArgs_unknownCommandFallsBackToToday() {
    let a = parseArgs(["bogus"], now: refDate)
    guard case .eventsToday(let offset) = a.command else { Issue.record("wrong command"); return }
    #expect(offset == 0)
}

// MARK: - dateRange

private let utcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

@Test func dateRange_eventsToday_spansFullDay() {
    let args = KcalArgs(command: .eventsToday(offset: 0), limit: nil)
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == utcCal.startOfDay(for: refDate))
    #expect(end == utcCal.date(byAdding: .day, value: 1, to: utcCal.startOfDay(for: refDate))!)
}

@Test func dateRange_eventsTodayPlusOne_isTomorrow() {
    let args = KcalArgs(command: .eventsToday(offset: 1), limit: nil)
    let (start, _) = dateRange(for: args, now: refDate, calendar: utcCal)
    let tomorrow = utcCal.date(byAdding: .day, value: 1, to: utcCal.startOfDay(for: refDate))!
    #expect(start == tomorrow)
}

@Test func dateRange_eventsRemaining_startsFromNow() {
    let args = KcalArgs(command: .eventsRemaining, limit: nil)
    let (start, end) = dateRange(for: args, now: refDate, calendar: utcCal)
    #expect(start == refDate)
    #expect(end > refDate)
}

@Test func dateRange_events_usesFromTo() {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = TimeZone(identifier: "UTC")
    let from = fmt.date(from: "2026-05-01")!
    let to   = fmt.date(from: "2026-05-03")!
    let args = KcalArgs(command: .events(from: from, to: to), limit: nil)
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

// MARK: - toJSON

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
