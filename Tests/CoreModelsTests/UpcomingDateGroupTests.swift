import XCTest
@testable import CoreModels

final class UpcomingDateGroupTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func release(_ id: String, hour: Int, day: Int) -> UpcomingRelease {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
        return UpcomingRelease(
            id: id, titleKey: id, item: MediaItem(id: id, title: id, kind: .series), date: date,
            datePrecision: .dateAndTime, kind: .episode, interests: [.watching]
        )
    }

    func testSameDayReleasesShareOneGroupRegardlessOfTime() {
        let groups = UpcomingDateGroup.groups(
            [release("a", hour: 9, day: 19), release("b", hour: 21, day: 19), release("c", hour: 8, day: 21)],
            calendar: calendar
        )
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].releases.map(\.id), ["a", "b"])
        XCTAssertTrue(groups[0].isShared)
        XCTAssertEqual(groups[0].lead.id, "a")
        XCTAssertFalse(groups[1].isShared)
    }

    func testGroupsAreOrderedByDayEvenWhenInputIsNot() {
        let groups = UpcomingDateGroup.groups(
            [release("late", hour: 9, day: 25), release("early", hour: 9, day: 19)], calendar: calendar
        )
        XCTAssertEqual(groups.map(\.lead.id), ["early", "late"])
    }

    func testEmptyInputYieldsNoGroups() {
        XCTAssertTrue(UpcomingDateGroup.groups([], calendar: calendar).isEmpty)
    }
}
