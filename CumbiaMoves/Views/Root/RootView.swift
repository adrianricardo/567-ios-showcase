import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            MovesView()
                .tabItem {
                    Label("Moves", systemImage: "music.note.list")
                }

            LibraryView()
                .tabItem {
                    Label("Videos", systemImage: "film.stack")
                }
        }
    }
}
