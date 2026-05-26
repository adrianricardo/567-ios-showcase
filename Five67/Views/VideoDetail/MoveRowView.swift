import SwiftUI

struct MoveRowView: View {
    let move: Move
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExclude: () -> Void

    @State private var showRename = false

    private var displayName: String {
        move.name.isEmpty ? "Unnamed segment" : move.name
    }

    private var showAddName: Bool {
        move.name.isEmpty && !move.isExcluded
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Text(displayName)
                    .font(.body)
                    .foregroundStyle(move.isExcluded ? .tertiary : .primary)
                    .lineLimit(1)
                    .padding(.leading, Spacing.lg)

                Text(move.durationLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Spacer(minLength: Spacing.sm)

                if showAddName {
                    Button {
                        showRename = true
                    } label: {
                        Text("Add name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, Spacing.lg)
            .frame(minHeight: Spacing.rowMinHeight + Spacing.smPlus)
            .background(
                isActive && !move.isExcluded
                    ? Theme.rowActiveBackground
                    : Color(.systemBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(move.isExcluded ? 0.5 : 1)
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
}
