import SwiftUI
import UIKit

struct MoveRowView: View {
    let move: Move
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExclude: () -> Void
    let accentColor: Color
    let activeForegroundColor: Color?
    let showsInlineRename: Bool

    @State private var showRename = false
    @State private var thumbnail: UIImage?

    init(
        move: Move,
        isActive: Bool,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRename: @escaping (String) -> Void,
        onExclude: @escaping () -> Void,
        accentColor: Color = Color.accentColor,
        activeForegroundColor: Color? = nil,
        showsInlineRename: Bool = true
    ) {
        self.move = move
        self.isActive = isActive
        self.onTap = onTap
        self.onDelete = onDelete
        self.onRename = onRename
        self.onExclude = onExclude
        self.accentColor = accentColor
        self.activeForegroundColor = activeForegroundColor
        self.showsInlineRename = showsInlineRename
    }

    private var primaryForeground: Color {
        if move.isExcluded { return Color.secondary }
        if isActive, let activeForegroundColor { return activeForegroundColor }
        return Color.primary
    }

    private var secondaryForeground: Color {
        if isActive, let activeForegroundColor { return activeForegroundColor.opacity(0.58) }
        return Color.secondary
    }

    private var displayName: String {
        move.name.isEmpty ? "Unnamed segment" : move.name
    }

    private var showAddName: Bool {
        move.name.isEmpty && !move.isExcluded
    }

    private var thumbnailTaskID: String {
        guard let video = move.video else { return "missing-\(move.id.uuidString)" }
        return "\(video.id.uuidString)-\(move.time)-\(video.localFilename)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                thumbnailView
                    .padding(.leading, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(displayName)
                        .font(.body)
                        .foregroundStyle(primaryForeground)
                        .lineLimit(1)

                    Text(move.durationLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(secondaryForeground)
                }

                Spacer(minLength: Spacing.sm)

                if showAddName && showsInlineRename {
                    Button {
                        showRename = true
                    } label: {
                        // Quiet, mode-consistent "add" affordance: system fill
                        // + accent label. The old solid-blue pill glared in the
                        // (now adaptive) dark move list.
                        Text("Add name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isActive && activeForegroundColor != nil ? primaryForeground : accentColor)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Capsule().fill(Theme.secondaryChipFill))
                    }
                    .buttonStyle(.plain)
                }

                if isActive {
                    Image(systemName: "waveform")
                        .font(.body.weight(.bold))
                        .foregroundStyle(accentColor)
                        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                        .accessibilityHidden(true)
                }
            }
            .padding(.trailing, Spacing.lg)
            .frame(minHeight: Spacing.rowMinHeight + Spacing.smPlus)
            .background(Theme.stageSurface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName), \(move.durationLabel)")
        .accessibilityValue(isActive ? "Playing" : "")
        .accessibilityAction(named: "Rename") {
            showRename = true
        }
        .accessibilityAction(named: move.isExcluded ? "Include" : "Exclude") {
            onExclude()
        }
        .accessibilityAction(named: "Delete") {
            onDelete()
        }
        .opacity(move.isExcluded ? 0.5 : 1)
        .task(id: thumbnailTaskID) { await loadThumbnail() }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onExclude()
            } label: {
                Label(
                    move.isExcluded ? "Include" : "Exclude",
                    systemImage: move.isExcluded ? "eye" : "eye.slash"
                )
            }
            .tint(move.isExcluded ? .blue : .gray)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                showRename = true
            }
            Divider()
            Button(
                move.isExcluded ? "Include" : "Exclude",
                systemImage: move.isExcluded ? "eye" : "eye.slash"
            ) {
                onExclude()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showRename) {
            RenameSheet(
                title: "Rename Segment",
                isPresented: $showRename,
                initial: move.name,
                onSave: onRename
            )
        }
    }

    private var thumbnailView: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
        }
        .frame(width: 54, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func loadThumbnail() async {
        guard let video = move.video else {
            thumbnail = nil
            return
        }
        thumbnail = await ThumbnailService.shared.thumbnail(
            for: video.fileURL,
            at: move.time,
            videoID: video.id,
            height: 40
        )
    }
}
