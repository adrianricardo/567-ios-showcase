import SwiftData
import SwiftUI

/// Utility home for durable, library-level actions. This stays deliberately
/// small: access, backup/export, onboarding replay, and app identity.
struct LibrarySettingsView: View {
    private enum PresentedSheet: Identifiable {
        case exportOptions
        case exportSummary(LibraryExportResult)
        case replayOnboarding
        case unlock

        var id: String {
            switch self {
            case .exportOptions:    "export-options"
            case .exportSummary:    "export-summary"
            case .replayOnboarding: "replay-onboarding"
            case .unlock:           "unlock"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UnlockStore.self) private var unlockStore

    @State private var presentedSheet: PresentedSheet?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportDocument: LibraryExportDocument?
    @State private var pendingExportResult: LibraryExportResult?
    @State private var showExporter = false

    var body: some View {
        Form {
            if !unlockStore.isUnlocked {
                Section("Access") {
                    settingsButton(
                        title: "Upgrade 567",
                        subtitle: "Unlock unlimited videos and dance styles.",
                        systemImage: "infinity"
                    ) {
                        presentedSheet = .unlock
                    }
                }
            }

            Section("Library") {
                settingsButton(
                    title: "Export Library",
                    subtitle: "Back up your videos, moves, and metadata.",
                    systemImage: "square.and.arrow.up"
                ) {
                    presentedSheet = .exportOptions
                }
                .disabled(isExporting)
            }

            Section("Guidance") {
                settingsButton(
                    title: "Replay Onboarding",
                    subtitle: "Walk through the introduction again without changing your library.",
                    systemImage: "sparkles.rectangle.stack"
                ) {
                    presentedSheet = .replayOnboarding
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .exportOptions:
                LibraryExportOptionsSheet(
                    onFullExport: { Task { await runExport(includeVideos: true) } },
                    onMetadataExport: { Task { await runExport(includeVideos: false) } }
                )
            case .exportSummary(let result):
                LibraryExportSummarySheet(result: result)
            case .replayOnboarding:
                ReplayOnboardingSheet()
            case .unlock:
                UnlockPaywallSheet(reason: .durableEntry) {}
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .zip,
            defaultFilename: defaultExportFilename(),
            onCompletion: handleExporterResult
        )
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .overlay {
            if isExporting && !showExporter {
                exportProgress
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: isExporting)
    }

    private func settingsButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(.isButton)
    }

    private var exportProgress: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView().controlSize(.large)
                Text("Preparing export…").font(.headline)
                Text("This may take a moment for large libraries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(Spacing.xl5)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preparing export")
            .accessibilityValue("This may take a moment for large libraries")
        }
        .accessibilityAddTraits(.isModal)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private func handleExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            if let completedResult = pendingExportResult {
                presentedSheet = .exportSummary(completedResult)
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                exportError = error.localizedDescription
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
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func defaultExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let stem = (pendingExportResult?.includesVideoFiles ?? true) ? "Library" : "Metadata"
        return "567-\(stem)-\(formatter.string(from: Date()))"
    }
}

private struct LibraryExportOptionsSheet: View {
    let onFullExport: () -> Void
    let onMetadataExport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StageSheet(
            title: "Export Library",
            subtitle: "Choose whether to include the original video files."
        ) {
            VStack(spacing: Spacing.sm) {
                StageSheetActionRow(
                    title: "Full Export (Videos + Metadata)",
                    systemImage: "archivebox"
                ) {
                    dismiss()
                    onFullExport()
                }
                StageSheetActionRow(
                    title: "Metadata Only (No Videos)",
                    systemImage: "doc.text"
                ) {
                    dismiss()
                    onMetadataExport()
                }
                Button("Cancel") { dismiss() }
                    .buttonStyle(StageSecondaryActionButtonStyle())
            }
        }
    }
}

private struct ReplayOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StageSheet(
            title: "Replay onboarding?",
            subtitle: "Your videos, moves, styles, and purchase status will stay exactly as they are."
        ) {
            VStack(spacing: Spacing.sm) {
                Button("Replay onboarding") {
                    Haptics.success()
                    OnboardingPreferences().replayOnboarding()
                }
                .buttonStyle(StagePrimaryActionButtonStyle())

                Button("Cancel") { dismiss() }
                    .buttonStyle(StageSecondaryActionButtonStyle())
            }
        }
    }
}

private struct LibraryExportSummarySheet: View {
    let result: LibraryExportResult

    @Environment(\.dismiss) private var dismiss
    @State private var detailsExpanded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Export complete", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                Section("Contents") {
                    LabeledContent("Videos", value: "\(result.videoCount)")
                    LabeledContent("Moves", value: "\(result.moveCount)")
                }
                Section("Integrity") {
                    LabeledContent("Missing files", value: "\(result.missingFiles.count)")
                    LabeledContent("Orphan files", value: "\(result.orphanFiles.count)")
                    LabeledContent("Orphan moves", value: "\(result.orphanMoveCount)")
                    if result.hasIntegrityIssues {
                        DisclosureGroup("Show details", isExpanded: $detailsExpanded) {
                            if !result.missingFiles.isEmpty {
                                Text("Missing files").font(.subheadline.weight(.semibold))
                                ForEach(result.missingFiles, id: \.self) { name in
                                    Text(name).font(.footnote.monospaced())
                                }
                            }
                            if !result.orphanFiles.isEmpty {
                                Text("Orphan files").font(.subheadline.weight(.semibold))
                                ForEach(result.orphanFiles, id: \.self) { name in
                                    Text(name).font(.footnote.monospaced())
                                }
                            }
                            if result.orphanMoveCount > 0 {
                                Text("\(result.orphanMoveCount) move(s) have no associated video.")
                                    .font(.footnote)
                            }
                        }
                    } else {
                        Label("No issues found", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
