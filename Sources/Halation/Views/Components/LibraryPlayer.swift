import AVKit
import SwiftUI

/// The preview in the Library's inspector.
///
/// `AVPlayerView` rather than SwiftUI's `VideoPlayer`, for one reason:
/// `showsFullScreenToggleButton`. AVKit already has an enlarge control, sitting
/// in the player's own transport bar where people look for it, and SwiftUI's
/// wrapper exposes no way to turn it on. Rather than build a second button next
/// to a set of native ones, this uses the native one.
///
/// It also owns the playback outright — loading the clip, starting it, and
/// rewinding it — and that is load-bearing rather than tidiness.
///
/// It was split before: this view started playback while the enclosing view's
/// `onChange(of: item.id)` paused the player and swapped the item. SwiftUI runs
/// `updateNSView` during the update and `onChange` after it, so the pause landed
/// on top of the play and every selection after the first sat still. The first
/// worked only because it went through `makeNSView`, where there was no
/// `onChange` to undo it.
///
/// One owner, so there is no order for the two halves to get wrong.
struct LibraryPlayer: NSViewRepresentable {
    let player: AVPlayer
    /// The clip to show. Loaded here rather than by the caller, so loading and
    /// playing cannot be sequenced against each other.
    let url: URL
    /// Changing this loads and restarts: it is the identity of what is being
    /// shown, not a value the player reads.
    let itemID: LibraryItem.ID

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        // Sharing from a preview of a file the person already has is noise.
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        context.coordinator.show(url: url, itemID: itemID, on: player)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
        context.coordinator.show(url: url, itemID: itemID, on: player)
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        view.player?.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var shownID: LibraryItem.ID?
        private var endObserver: NSObjectProtocol?

        /// Loads a clip and plays it through once, muted, then returns it to the
        /// first frame and leaves it there.
        ///
        /// Muted because this starts on its own: a preview that selects itself
        /// and then makes noise is the kind of thing people turn off entirely.
        /// Rewound rather than left on the last frame so the tile and the
        /// preview agree about what the clip looks like, and so pressing play
        /// replays it instead of doing nothing.
        func show(url: URL, itemID: LibraryItem.ID, on player: AVPlayer) {
            guard shownID != itemID else { return }
            shownID = itemID
            stop()

            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            player.isMuted = true
            player.actionAtItemEnd = .pause
            player.seek(to: .zero)
            player.play()

            // Registered against this item, not the player: a notification for
            // the clip shown a moment ago would rewind the one showing now.
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item, queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    player.seek(to: .zero)
                }
            }
        }

        func stop() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
        }
    }
}
