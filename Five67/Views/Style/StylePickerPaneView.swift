import SwiftUI
import SwiftData

/// Swipe-in right-side pane co-equal to the feed. Lists every `Style`, lets
/// the user pick the active one, add a new custom style, or rename existing
/// custom ones. Defaults (Cumbia / Salsa / Bachata) are not renameable and
/// not deletable in this pass.
struct StylePickerPaneView: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore

    @Query(sort: \Style.createdAt, order: .forward)
    private var styles: [Style]

    @State private var renameTarget: Style?
    @State private var showRenameSheet = false
    @State private var showAddSheet = false

    // Export
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportDocument: LibraryExportDocument?
    @State private var pendingExportResult: LibraryExportResult?
    @State private var lastExportResult: LibraryExportResult?
    @State private var showExporterSheet = false
    @State private var showExportSummary = false
    @State private var showExportTypeDialog = false

    var body: some View {
        VStack(spacing: Spacing.none) {
            header
            content
            exportFooter
        }
        .background(Color(.systemBackground))
        .photosExportAttachments(
            isExporting: $isExporting,
            showExportTypeDialog: $showExportTypeDialog,
            showExporterSheet: $showExporterSheet,
            showExportSummary: $showExportSummary,
            exportDocument: exportDocument,
            exportError: $exportError,
            lastExportResult: lastExportResult,
            defaultFilename: defaultExportFilename(),
            onFullExport: { Task { await runExport(includeVideos: true) } },
            onMetadataExport: { Task { await runExport(includeVideos: false) } },
            onExporterResult: handleExporterResult
        )
        .sheet(isPresented: $showRenameSheet) {
            if let style = renameTarget {
                RenameSheet(
                    title: "Rename Style",
                    isPresented: $showRenameSheet,
                    initial: style.name
                ) { newName in
                    style.name = newName
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RenameSheet(
                title: "New Style",
                isPresented: $showAddSheet,
                initial: ""
            ) { newName in
                let style = Style(name: newName)
                modelContext.insert(style)
                styleStore.activeStyle = style
                onClose()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Styles")
                .font(.title3.weight(.semibold))
            Spacer(minLength: 0)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.mdPlus)
        .padding(.bottom, Spacing.smPlus)
    }

    // MARK: - Content

    private var content: some View {
        List {
            allRow
            ForEach(styles) { style in
                styleRow(style)
            }
            addRow
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Spacing.bottomBarTopOffset, for: .scrollContent)
    }

    private var allRow: some View {
        Button {
            select(nil)
        } label: {
            HStack {
                Text("All")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if styleStore.activeStyle == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func styleRow(_ style: Style) -> some View {
        let isActive = styleStore.activeStyle?.id == style.id
        return Button {
            select(style)
        } label: {
            HStack {
                Text(style.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !style.isDefault {
                Button {
                    renameTarget = style
                    showRenameSheet = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }

    private var addRow: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Add new style")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func select(_ style: Style?) {
        styleStore.activeStyle = style
        Haptics.select()
        onClose()
    }

    // MARK: - Export

    private var exportFooter: some View {
        Button {
            showExportTypeDialog = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                Text("Export Library")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, Spacing.smPlus)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.bottomBarTopOffset + Spacing.bottomBarClearance)
    }

    private func handleExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            lastExportResult = pendingExportResult
            showExportSummary = true
        case .failure(let err):
            if (err as NSError).code != NSUserCancelledError {
                exportError = err.localizedDescription
            }
        }
        pendingExportResult = nil
        exportDocument = nil
    }

    @MainActor
    private func runExport(includeVideos: Bool) async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        await Task.yield()

        do {
            try modelContext.save()
            let container = modelContext.container
            let result = try await Task.detached(priority: .userInitiated) {
                let exporter = LibraryExporter(modelContainer: container)
                return try await exporter.export(includeVideos: includeVideos)
            }.value
            pendingExportResult = result
            exportDocument = LibraryExportDocument(zipURL: result.zipURL)
            showExporterSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        let stem = (pendingExportResult?.includesVideoFiles ?? true) ? "Library" : "Metadata"
        return "Five67-\(stem)-\(df.string(from: Date()))"
    }
}
