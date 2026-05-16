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

let args = parseArgs(Array(CommandLine.arguments.dropFirst()))
let (start, end) = dateRange(for: args)
let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
var events = store.events(matching: pred).sorted { $0.startDate < $1.startDate }
if let l = args.limit { events = Array(events.prefix(l)) }

print(toJSON(events.map(eventToDict)))
