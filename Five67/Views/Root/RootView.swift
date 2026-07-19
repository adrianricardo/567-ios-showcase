import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        router.requestAddVideo()
                    },
                    onImportFiles: {
                        router.requestAddVideo()
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
            // It never actually displays — selecting it routes to Feed, where
            // the one canonical import action owns its visible dialog.
            Tab("Add video", systemImage: "plus", value: AppTab.add, role: .search) {
                EmptyView()
            }
            .accessibilityLabel("Add video")
        }
        .tint(.primary)
        .toolbarVisibility(router.hidesBottomChrome ? .hidden : .automatic, for: .tabBar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.hidesBottomChrome)
        .onChange(of: router.selectedTab) { _, newValue in
            guard newValue == .add else { return }
            // Intercept before the empty add pane renders. Feed owns every
            // import source and paywall decision, so its dialog stays visible
            // regardless of which tab initiated the action.
            Haptics.light()
            router.requestAddVideo()
        }
    }
}
