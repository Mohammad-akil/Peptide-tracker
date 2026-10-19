import SwiftUI

/// How you've been doing: the share of doses taken over 7, 30 or 90 days
/// as one big number, what was taken and missed, your streak, the rate over
/// time, and each medicine's rate. Shares as a PDF for the doctor.
struct ReportSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @AppStorage("report.period") private var period: AdherenceReport.Period = .month
    @AppStorage("report.byMedicineIsList") private var byMedicineIsList = true

    var body: some View {
        let report = AdherenceReport(store: store, period: period)

        SettingsPageScaffold(page: .report, titleDisplayMode: .inline) {
            SectionPicker(selection: $period.animation(.snappy), title: \.title)

            if report.due == 0 {
                EmptyStateCard(period: period)
            } else {
                headline(report)
                stats(report)
                AdherenceChart(report: report)
                byMedicine(report)
            }
        }
        .toolbar {
            if report.due > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: AdherenceReportPDF(report: report, personName: personName),
                        preview: SharePreview("Adherence report", image: Image(systemName: "chart.bar.doc.horizontal"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share report as PDF")
                }
            }
        }
        .animation(.snappy, value: period)
    }

    private var personName: String? {
        let name = store.settings.userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: Headline

    /// The one number that matters, in a ring, with its counts.
    private func headline(_ report: AdherenceReport) -> some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: report.rate ?? 0, lineWidth: 10)
                Text((report.rate ?? 0).percentLabel)
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.8)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: report.rate ?? 0))
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 4) {
                Text("of doses taken")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(report.taken) of \(report.due) doses in the \(report.period.phrase)")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .groupedCard()
        .accessibilityElement(children: .combine)
    }

    /// Taken, missed and streak: a glyph and a label each, so colour never
    /// carries the meaning alone; the numbers stay in text ink.
    private func stats(_ report: AdherenceReport) -> some View {
        HStack(spacing: 10) {
            StatTile(value: report.taken, label: "Taken", symbol: "checkmark.circle.fill", tint: Urgency.healthy.tint)
            StatTile(value: report.missed, label: "Missed", symbol: "exclamationmark.circle.fill", tint: Urgency.low.tint)
            StatTile(value: report.streak, label: report.streak == 1 ? "Day streak" : "Days streak", symbol: "flame.fill", tint: AppTheme.ColorToken.accent)
        }
    }

    // MARK: By medicine

    /// Each medicine's rate, lowest first, as a list or a grid of rings.
    private func byMedicine(_ report: AdherenceReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("By medicine")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                LayoutToggle(isListView: $byMedicineIsList, buttonSize: 30)
            }
            .padding(.leading, 16)

            Group {
                if byMedicineIsList {
                    medicineList(report)
                } else {
                    medicineGrid(report)
                }
            }
            .transition(.opacity)

            Text("Lowest first, so what needs attention is on top.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(.horizontal, 16)
        }
        .animation(.smooth(duration: 0.35), value: byMedicineIsList)
    }

    private func medicineGrid(_ report: AdherenceReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(report.medicines) { entry in
                MedicineRateTile(entry: entry)
            }
        }
    }

    private func medicineList(_ report: AdherenceReport) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(report.medicines.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 14) {
                    MedicineIconView(medicine: entry.medicine, size: 36, isVibrant: true)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.medicine.name)
                                .font(.system(size: 17))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(entry.rate.percentLabel)
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                        }
                        // One series, so one hue: the accent, on the ring track.
                        GeometryReader { proxy in
                            Capsule()
                                .fill(AppTheme.ColorToken.ringTrack)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.ColorToken.accent)
                                        .frame(width: max(proxy.size.width * entry.rate, entry.rate > 0 ? 4 : 0))
                                }
                        }
                        .frame(height: 4)
                        Text("\(entry.taken) of \(entry.due) doses")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .rowDivider(index < report.medicines.count - 1, inset: 66)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
        .groupedCard()
    }
}

/// A medicine in the grid: its rate in a ring around its icon, then the
/// name and counts.
private struct MedicineRateTile: View {
    let entry: AdherenceReport.MedicineRate

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: entry.rate, lineWidth: 6)
                MedicineIconView(medicine: entry.medicine, size: 40, isVibrant: true)
            }
            .frame(width: 76, height: 76)

            VStack(spacing: 2) {
                Text(entry.rate.percentLabel)
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                Text(entry.medicine.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(entry.taken) of \(entry.due) doses")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .groupedCard()
        .accessibilityElement(children: .combine)
    }
}

/// A number with its glyph and label.
private struct StatTile: View {
    let value: Int
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .groupedCard()
        .accessibilityElement(children: .combine)
    }
}

/// Nothing was due in the period.
private struct EmptyStateCard: View {
    let period: AdherenceReport.Period

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
            Text("No doses yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Once doses are due in the \(period.phrase), you’ll see how you’re doing here.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .groupedCard()
    }
}

#Preview {
    NavigationStack { ReportSettingsView() }
        .environment(MedicineStore.preview())
}
