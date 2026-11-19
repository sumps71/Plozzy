import XCTest
import CoreModels

final class EpisodeSequenceTests: XCTestCase {
    private func ep(_ id: String, s: Int, e: Int) -> MediaItem {
        MediaItem(id: id, title: id, kind: .episode, seasonNumber: s, episodeNumber: e)
    }

    func testNeighborsMidSeason() {
        let pool = [ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2), ep("e3", s: 1, e: 3)]
        let n = EpisodeSequence.neighbors(of: pool[1], in: pool)
        XCTAssertEqual(n.previous?.id, "e1")
        XCTAssertEqual(n.next?.id, "e3")
    }

    func testNeighborsRollsIntoNextSeason() {
        let pool = [ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2), ep("p1", s: 2, e: 1)]
        let n = EpisodeSequence.neighbors(of: pool[1], in: pool)
        XCTAssertEqual(n.next?.id, "p1")
    }

    func testFirstHasNoPrevious() {
        let pool = [ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2)]
        let n = EpisodeSequence.neighbors(of: pool[0], in: pool)
        XCTAssertNil(n.previous)
        XCTAssertEqual(n.next?.id, "e2")
    }

    func testLastHasNoNext() {
        let pool = [ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2)]
        let n = EpisodeSequence.neighbors(of: pool[1], in: pool)
        XCTAssertEqual(n.previous?.id, "e1")
        XCTAssertNil(n.next)
    }

    func testUnsortedInputAndMissing() {
        let pool = [ep("e3", s: 1, e: 3), ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2)]
        XCTAssertEqual(EpisodeSequence.neighbors(of: pool[0], in: pool).previous?.id, "e2")
        let missing = MediaItem(id: "x", title: "x", kind: .episode)
        XCTAssertNil(EpisodeSequence.neighbors(of: missing, in: pool).next)
    }

    func testUnairedNextEpisodeIsNotOffered() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var future = ep("e3", s: 1, e: 3)
        future.releaseDate = now.addingTimeInterval(86_400)
        let pool = [ep("e1", s: 1, e: 1), ep("e2", s: 1, e: 2), future]
        XCTAssertNil(EpisodeSequence.neighbors(of: pool[1], in: pool, now: now).next)
    }

    func testAiredAndUndatedNextEpisodesAreOffered() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var aired = ep("e2", s: 1, e: 2)
        aired.releaseDate = now.addingTimeInterval(-86_400)
        let pool = [ep("e1", s: 1, e: 1), aired, ep("e3", s: 1, e: 3)]
        XCTAssertEqual(EpisodeSequence.neighbors(of: pool[0], in: pool, now: now).next?.id, "e2")
        XCTAssertEqual(EpisodeSequence.neighbors(of: pool[1], in: pool, now: now).next?.id, "e3")
    }

    func testSchedulePlaceholderNextEpisodeIsNotOffered() {
        var placeholder = ep("e2", s: 1, e: 2)
        placeholder.scheduledAirDate = Date().addingTimeInterval(86_400)
        let pool = [ep("e1", s: 1, e: 1), placeholder]
        XCTAssertNil(EpisodeSequence.neighbors(of: pool[0], in: pool).next)
    }
}
