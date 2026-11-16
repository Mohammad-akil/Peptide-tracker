import Foundation

/// The app's cached queries, in one place: each key, what it depends on,
/// and how it's computed. Screens read these instead of recomputing.
extension MedicineStore {
    /// Every day of `year` with doses: the calendar's colours and rates.
    func daySummaries(year: Int) -> [Date: DaySummary] {
        QueryClient.shared.query("calendar.year.\(year)", tags: [.doses, .medicines, .day]) {
            CalendarView.summaries(year: year, store: self, calendar: .current)
        }
    }

    /// The adherence report for 7, 30 or 90 days.
    func adherenceReport(_ period: AdherenceReport.Period) -> AdherenceReport {
        QueryClient.shared.query("report.\(period.rawValue)", tags: [.doses, .medicines, .day]) {
            AdherenceReport(store: self, period: period)
        }
    }

    /// Warms the cache during the splash, so the first visit to Calendar,
    /// Report or the add-medicine search is instant.
    func preload() {
        let client = QueryClient.shared
        let year = Calendar.current.component(.year, from: .now)
        client.prefetch("calendar.year.\(year)", tags: [.doses, .medicines, .day]) {
            CalendarView.summaries(year: year, store: self, calendar: .current)
        }
        for period in AdherenceReport.Period.allCases {
            client.prefetch("report.\(period.rawValue)", tags: [.doses, .medicines, .day]) {
                AdherenceReport(store: self, period: period)
            }
        }
        // The medicine catalogue parses its JSON on first use; do it now.
        _ = MedicineCatalog.all.count
    }
}
