import XCTest
import CoreModels
@testable import FeatureHomeCore

@MainActor
final class HeroDirectTrailerSourceTests: XCTestCase {
    private let direct = MediaItem.directTrailer(fromURL: "https://cdn.trailer.example/dune.mp4", title: "T")!

    func testDirectTrailerBecomesHeroSourceWithMeasuredDuration() async {
        let source = await FastHeroTrailerResolver.directSource(
            from: [MediaItem.youTubeTrailer(videoID: "dQw4w9WgXcQ", title: "YT"), direct],
            ownerItemID: "m1", duration: { _ in 158 }, isPlayable: { _ in true }
        )
        XCTAssertEqual(source?.ownerItemID, "m1")
        XCTAssertEqual(source?.trailerItemID, direct.id)
        XCTAssertEqual(source?.url.absoluteString, "https://cdn.trailer.example/dune.mp4")
        XCTAssertEqual(source?.duration, 158)
    }

    func testNoSourceWhenNoDirectTrailerOrYouTubeOnly() async {
        var probed = false
        let none = await FastHeroTrailerResolver.directSource(
            from: [MediaItem.youTubeTrailer(videoID: "dQw4w9WgXcQ", title: "YT")],
            ownerItemID: "m1", duration: { _ in probed = true; return 10 }, isPlayable: { _ in true }
        )
        XCTAssertNil(none)
        XCTAssertFalse(probed, "YouTube must never be probed")
        let empty = await FastHeroTrailerResolver.directSource(from: [], ownerItemID: "m1", duration: { _ in 10 })
        XCTAssertNil(empty)
    }

    func testNoSourceWhenStreamDurationCannotBeRead() async {
        let source = await FastHeroTrailerResolver.directSource(
            from: [direct], ownerItemID: "m1", duration: { _ in nil }, isPlayable: { _ in true }
        )
        XCTAssertNil(source, "A dead or expired link must fall through, not autoplay")
    }

    func testFallsThroughToNextDirectTrailerWhenFirstFails() async {
        let second = MediaItem.directTrailer(fromURL: "https://cdn.trailer.example/second.mp4", title: "T2")!
        var probed: [String] = []
        let source = await FastHeroTrailerResolver.directSource(
            from: [direct, second], ownerItemID: "m1",
            duration: { url in
                probed.append(url.absoluteString)
                return url.absoluteString.contains("second") ? 90 : nil
            },
            isPlayable: { _ in true }
        )
        XCTAssertEqual(probed, [direct.directTrailerURL!.absoluteString, second.directTrailerURL!.absoluteString])
        XCTAssertEqual(source?.trailerItemID, second.id)
        XCTAssertEqual(source?.duration, 90)
    }

    func testFallsThroughWhenFirstTrailerReadsDurationButNeverBecomesPlayable() async {
        let second = MediaItem.directTrailer(fromURL: "https://cdn.trailer.example/second.mp4", title: "T2")!
        let source = await FastHeroTrailerResolver.directSource(
            from: [direct, second], ownerItemID: "m1",
            duration: { _ in 60 },
            isPlayable: { $0.absoluteString.contains("second") }
        )
        XCTAssertEqual(source?.trailerItemID, second.id)
    }

    func testNoSourceWhenNoTrailerBecomesPlayable() async {
        let source = await FastHeroTrailerResolver.directSource(
            from: [direct], ownerItemID: "m1", duration: { _ in 60 }, isPlayable: { _ in false }
        )
        XCTAssertNil(source)
    }
}
