import SwiftUI

struct MoveRowView: View {
    let move: Move
    let isActive: Bool
    let onTap: () -> Void
    let onCycleStatus: () -> Void
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
                if move.isExcluded {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: Spacing.lg)
                        .padding(.leading, Spacing.lg)
                } else {
                    StatusDot(status: move.status)
                        .padding(.leading, Spacing.lg)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(displayName)
                        .font(.body)
                        .foregroundStyle(move.isExcluded ? .tertiary : .primary)
                        .lineLimit(1)
                    Text(move.rangeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: Spacing.sm)

                if showAddName {
                    Button {
                        showRename = true
                    } label: {
                        Label("Add name", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .tint(.accentColor)
                }
            }
            .padding(.trailing, Spacing.lg)
            .frame(minHeight: Spacing.rowMinHeight)
            .background(
                isActive && !move.isExcluded
                    ? Color.accentColor.opacity(0.07)
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
            if !move.isExcluded {
                Button(move.status.next.displayName, systemImage: statusIcon(for: move.status.next)) {
                    onCycleStatus()
                }
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

    private func statusIcon(for status: Status) -> String {
        switch status {
        case .empty:    return "circle.dotted"
        case .stuck:    return "exclamationmark.circle"
        case .mastered: return "checkmark.circle.fill"
        }
    }
}
