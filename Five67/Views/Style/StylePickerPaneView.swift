import SwiftUI
import SwiftData

/// Styles tab. Lists every `Style`, lets the user pick the active one, add a
/// new custom style, or rename existing custom ones. Selecting a style returns
/// to the Feed tab automatically. Defaults (Cumbia / Salsa / Bachata) are not
/// renameable and not deletable.
struct StylePickerPaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StyleStore.self) private var styleStore
    @Environment(AppRouter.self) private var router

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
        .foregroundStyle(Theme.stagePrimary)
        .background(Theme.stageBackground)
        .preferredColorScheme(.dark)
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
                router.selectedTab = .feed
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Styles")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .tracking(-0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.md)
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
        .scrollContentBackground(.hidden)
        .background(Theme.stageBackground)
        .contentMargins(.bottom, Spacing.bottomBarClearance, for: .scrollContent)
    }

    private var allRow: some View {
        StageSelectableRow(
            title: "All styles",
            isSelected: styleStore.activeStyle == nil,
            action: { select(nil) }
        )
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func styleRow(_ style: Style) -> some View {
        let isActive = styleStore.activeStyle?.id == style.id
        let accent = StyleAccentPalette.accent(forName: style.name, id: style.id)?.color
        return StageSelectableRow(
            title: style.name,
            identityColor: accent,
            isSelected: isActive,
            action: { select(style) }
        )
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityActions {
            if !style.isDefault {
                Button("Rename") {
                    renameTarget = style
                    showRenameSheet = true
                }
            }
        }
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
                    .foregroundStyle(Theme.stagePrimary)
                Text("Add new style")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 56)
            .background(Theme.stageSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stageStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func select(_ style: Style?) {
        styleStore.activeStyle = style
        Haptics.select()
        router.selectedTab = .feed
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
            .foregroundStyle(Theme.stageSecondary)
            .padding(.vertical, Spacing.smPlus)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.bottomBarClearance)
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
        return "567-\(stem)-\(df.string(from: Date()))"
    }
}
