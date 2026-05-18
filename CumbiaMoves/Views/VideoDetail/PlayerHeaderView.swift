import SwiftUI
import AVKit

// MARK: - Player + Trim region (sticky top inset)

struct PlayerAndTrimSection: View {
    let video: Video
    let controller: PlaybackController
    let moves: [Move]
    @Binding var isCollapsed: Bool
    let onSplit: () -> Void

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PlayerHeaderView(
                video: video,
                controller: controller,
                isCollapsed: $isCollapsed,
                onExpand: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isCollapsed = false
                    }
                }
            )

            TrimTrackView(
                controller: controller,
                videoID: video.id,
                videoURL: video.fileURL,
                moves: moves,
                allowsMarkerEditing: true
            )
            .frame(height: isCollapsed ? 32 : 44)
            .padding(.horizontal, 16)
            .padding(.top, isCollapsed ? 4 : 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isCollapsed)

            // Split button
            Button {
                onSplit()
            } label: {
                Label("Split", systemImage: "scissors")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(controller.duration == 0)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showRename) {
            RenameSheet(
                title: "Rename Video",
                isPresented: $showRename,
                initial: video.displayName
            ) { newName in
                video.displayName = newName
            }
        }
        .confirmationDialog(
            "Delete \"\(video.displayName)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Video & All Moves", role: .destructive) {
                let videoID = video.id
                Task { await ThumbnailService.shared.clearCache(for: videoID) }
                try? FileManager.default.removeItem(at: video.fileURL)
                modelContext.delete(video)
                dismiss()
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Player header (full vs. card)

struct PlayerHeaderView: View {
    let video: Video
    let controller: PlaybackController
    @Binding var isCollapsed: Bool
    let onExpand: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            PlayerFullView(video: video, controller: controller, isCollapsed: $isCollapsed)
                .opacity(isCollapsed ? 0 : 1)
                .allowsHitTesting(!isCollapsed)

            if isCollapsed {
                PlayerCardView(video: video, controller: controller, onExpand: onExpand)
                    .transition(.opacity)
            }
        }
        .frame(height: isCollapsed ? 64 : nil)
        .clipped()
    }
}

// MARK: - Full player

struct PlayerFullView: View {
    let video: Video
    let controller: PlaybackController
    @Binding var isCollapsed: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(video.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Menu {
                    Button("Rename Video", systemImage: "pencil") { }
                    Divider()
                    Button("Delete Video", systemImage: "trash", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            VideoPlayer(player: controller.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)

            PlayerControlsBar(controller: controller)
        }
    }
}

// MARK: - Controls bar

struct PlayerControlsBar: View {
    let controller: PlaybackController

    var body: some View {
        HStack(spacing: 0) {
            Button {
                controller.toggle()
                Haptics.light()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }

            Spacer()
            Text(formatTime(controller.currentTime))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()

            Button {
                controller.isLooping.toggle()
                Haptics.light()
            } label: {
                Image(systemName: "repeat")
                    .font(.title3)
                    .foregroundStyle(controller.isLooping ? Color.accentColor : .secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(controller.isLooping ? "Loop on" : "Loop off")
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}

// MARK: - Collapsed card

struct PlayerCardView: View {
    let video: Video
    let controller: PlaybackController
    let onExpand: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color(.systemGray4))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(formatTime(controller.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(
                for: video.fileURL,
                at: controller.currentTime,
                videoID: video.id,
                height: 44
            )
        }
    }
}
