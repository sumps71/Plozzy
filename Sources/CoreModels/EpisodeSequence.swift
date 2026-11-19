import Foundation

/// Pure, UI-independent ordering helpers for moving between episodes — used both
/// for auto-advancing when one finishes and for jumping forward/back mid-playback.
/// Kept free of any provider/SwiftUI dependency so it compiles and unit-tests on
/// every platform.
public enum EpisodeSequence {
    /// The previous and next episode relative to `current` within `pool`, in true
    /// broadcast order. `pool` may arrive in any order and may mix seasons: it is
    /// sorted by `(seasonNumber, episodeNumber)` with stable id fallbacks so a
    /// season finale rolls into the next season's premiere. Non-episode entries
    /// and the current item's duplicates are ignored. Returns `(nil, nil)` when
    /// `current` isn't found.
    ///
    /// `next` is the first following episode that has already aired: an episode
    /// dated after `now` (a server's placeholder for an unreleased episode) is
    /// skipped, so neither auto-advance nor the Up Next card offers something
    /// that cannot be played yet.
    public static func neighbors(
        of current: MediaItem,
        in pool: [MediaItem],
        now: Date = Date()
    ) -> (previous: MediaItem?, next: MediaItem?) {
        let ordered = sorted(pool)
        guard let index = ordered.firstIndex(where: { $0.id == current.id }) else {
            return (nil, nil)
        }
        let previous = index > 0 ? ordered[index - 1] : nil
        let next = ordered[(index + 1)...].first { $0.hasAired(by: now) }
        return (previous, next)
    }

    /// `pool` sorted into broadcast order: by season, then episode, then a stable
    /// fallback on id so equal/unknown ordinals stay deterministic. Episodes
    /// missing ordinals sort after numbered ones rather than being dropped.
    public static func sorted(_ pool: [MediaItem]) -> [MediaItem] {
        pool.sorted { lhs, rhs in
            let ls = lhs.seasonNumber ?? Int.max, rs = rhs.seasonNumber ?? Int.max
            if ls != rs { return ls < rs }
            let le = lhs.episodeNumber ?? Int.max, re = rhs.episodeNumber ?? Int.max
            if le != re { return le < re }
            return lhs.id < rhs.id
        }
    }
}

private extension MediaItem {
    /// Whether this episode is released as of `now`. An undated episode counts
    /// as aired; a schedule-derived placeholder or a release date in the future
    /// does not.
    func hasAired(by now: Date) -> Bool {
        if scheduledAirDate != nil { return false }
        guard let releaseDate else { return true }
        return releaseDate <= now
    }
}
