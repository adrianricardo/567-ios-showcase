import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Group {
                if router.selectedTab == .moves {
                    MovesView()
                } else {
                    Color.clear
                }
            }
                .tabItem {
                    Label("Moves", systemImage: "music.note.list")
                }
                .tag(AppTab.moves)

            LibraryView()
                .tabItem {
                    Label("Videos", systemImage: "film.stack")
                }
                .tag(AppTab.library)
        }
    }
}
