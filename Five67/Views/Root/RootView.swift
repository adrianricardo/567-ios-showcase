import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Last real (non-`.add`) tab, so selecting the detached add control can
    /// restore the visible content without a flicker.
    @State private var previousTab: AppTab = .feed

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Library", systemImage: "photo.stack.fill", value: AppTab.library) {
                LibraryPaneView(
                    activeVideoID: router.currentFeedVideoID,
                    activeMoveID: router.currentFeedMoveID,
                    onSelectVideo: { video in
                        router.showInFeed(FeedSelection(videoID: video.id, moveID: nil))
                    },
                    onSelectMove: { move in
                        if let videoID = move.video?.id {
                            router.showInFeed(FeedSelection(videoID: videoID, moveID: move.id))
                        }
                    },
                    onImportPhotos: {
                        router.addVideoRequested = true
                        router.selectedTab = .feed
                    },
                    onImportFiles: {
                        router.addVideoRequested = true
                        router.selectedTab = .feed
                    }
                )
            }
            Tab("Feed", systemImage: "play.rectangle.fill", value: AppTab.feed) {
                VideoFeedView()
            }
            Tab("Styles", systemImage: "slider.horizontal.3", value: AppTab.style) {
                StylePickerPaneView()
            }
            // Detached add-video control. The `.search` role makes the system
            // render this tab separated from the main cluster (trailing pill).
            // It never actually displays — selecting it triggers an import and
            // restores the previous tab in the `.onChange` below.
            Tab("Add video", systemImage: "plus", value: AppTab.add, role: .search) {
                EmptyView()
            }
            .accessibilityLabel("Add video")
        }
        .tint(.primary)
        .toolbarVisibility(router.hidesBottomChrome ? .hidden : .automatic, for: .tabBar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.hidesBottomChrome)
        .onChange(of: router.selectedTab) { _, newValue in
            guard newValue == .add else {
                previousTab = newValue
                return
            }
            // Intercept: fire the import request and restore the prior tab so
            // the empty search pane is never shown.
            router.addVideoRequested = true
            Haptics.light()
            router.selectedTab = previousTab
        }
    }
}
