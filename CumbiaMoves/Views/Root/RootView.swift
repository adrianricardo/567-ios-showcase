import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library

    private enum AppTab {
        case moves
        case library
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if selectedTab == .moves {
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
