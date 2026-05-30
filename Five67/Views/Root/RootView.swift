import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Library", systemImage: "photo.stack.fill", value: AppTab.library) {
                LibraryPaneView(
                    activeVideoID: router.currentFeedVideoID,
                    activeMoveID: router.currentFeedMoveID,
                    onSelectVideo: { video in
                        router.pendingFeedSelection = FeedSelection(videoID: video.id, moveID: nil)
                        router.selectedTab = .feed
                    },
                    onSelectMove: { move in
                        if let videoID = move.video?.id {
                            router.pendingFeedSelection = FeedSelection(videoID: videoID, moveID: move.id)
                        }
                        router.selectedTab = .feed
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
        }
        .overlay(alignment: .bottomTrailing) {
            if !router.hidesBottomChrome {
                addVideoButton
                    .padding(.trailing, Spacing.lgPlus)
                    .padding(.bottom, Spacing.xl2)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.hidesBottomChrome)
    }

    private var addVideoButton: some View {
        Button {
            router.addVideoRequested = true
            router.selectedTab = .feed
            Haptics.light()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 64, height: 64)
                .padding(Spacing.xsPlus)
                .liquidGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add video")
        .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
        .environment(\.colorScheme, .dark)
    }
}
