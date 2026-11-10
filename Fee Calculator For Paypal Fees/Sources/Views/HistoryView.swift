//
//  HistoryView.swift
//  Fee Calculator For Paypal Fees
//

import SwiftData
import SwiftUI

/// Saved calculations, newest first.
struct HistoryView: View {
    @Environment(CalculatorModel.self) private var calculator
    @Environment(AppRouter.self) private var router
    @Environment(AdsManager.self) private var ads
    @Environment(ProStore.self) private var pro
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedCalculation.date, order: .reverse) private var entries: [SavedCalculation]

    @State private var searchText = ""
    @State private var isConfirmingDeleteAll = false
    /// The CSV file, prepared ahead so the share sheet opens on the first tap.
    @State private var exportURL: URL?

    private var filteredEntries: [SavedCalculation] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.title.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Calculations", systemImage: "bookmark")
                    } description: {
                        Text("Tap the bookmark in the calculator to save a calculation here.")
                    } actions: {
                        Button("Open Calculator") { router.selectedTab = .calculator }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in
                                Button {
                                    restore(entry)
                                } label: {
                                    HistoryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        modelContext.delete(entry)
                                    }
                                }
                                .contextMenu {
                                    Button("Open in Calculator", systemImage: "plusminus.circle") { restore(entry) }
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        modelContext.delete(entry)
                                    }
                                }
                            }
                        } footer: {
                            Text("Tap a calculation to open it in the calculator with the current fee profile.")
                        }
                    }
                    .searchable(text: $searchText, prompt: Text("Search by Name"))
                }
            }
            .navigationTitle("History")
            .appListStyle()
            .adBanner()
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        if pro.isPro {
                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    Label("Export History", systemImage: "square.and.arrow.up")
                                }
                            } else {
                                // The file is still being written.
                                Button("Export History", systemImage: "square.and.arrow.up") {}
                                    .disabled(true)
                            }
                        } else {
                            Button("Export History", systemImage: "square.and.arrow.up") {
                                router.isShowingPaywall = true
                            }
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Delete All", systemImage: "trash") {
                            isConfirmingDeleteAll = true
                        }
                    }
                }
            }
            .task(id: ExportSignature(isPro: pro.isPro, count: entries.count, newest: entries.first?.date)) {
                guard pro.isPro, !entries.isEmpty else { exportURL = nil; return }
                exportURL = try? HistoryExport(entries: entries).write()
            }
            .confirmationDialog("Delete all saved calculations?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    withAnimation {
                        for entry in entries { modelContext.delete(entry) }
                    }
                }
            }
        }
    }

    private func restore(_ entry: SavedCalculation) {
        calculator.mode = entry.mode
        calculator.setAmount(entry.amount)
        router.selectedTab = .calculator
        ads.registerCompletedAction()
    }
}

/// Changes whenever the exported file would change.
private struct ExportSignature: Equatable {
    let isPro: Bool
    let count: Int
    let newest: Date?
}

private struct HistoryRow: View {
    let entry: SavedCalculation

    var body: some View {
        HStack(spacing: 12) {
            IconTile(
                systemImage: entry.mode == .send ? "arrow.up.right" : "arrow.down.left",
                color: entry.mode == .send ? .blue : .indigo,
                size: 36
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title.isEmpty ? String(localized: entry.mode.title) : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(Formatting.currency(entry.gross, code: entry.currencyCode)) sent · \(entry.rateSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(entry.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(verbatim: Formatting.currency(entry.net, code: entry.currencyCode))
                    .font(.headline)
                    .monospacedDigit()
                Text(verbatim: "− " + Formatting.currency(entry.totalFees, code: entry.currencyCode))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
