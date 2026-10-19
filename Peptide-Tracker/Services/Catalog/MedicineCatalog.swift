import Foundation

/// One medicine in the bundled catalogue (`MedicineCatalog.json`), built by
/// `Tools/MedicineCatalog/build.py`.
struct CatalogMedicine: Decodable, Hashable, Identifiable {
    let name: String
    let type: MedicineType
    let category: String
    /// Common strengths, as on the box ("500 mg", "100 u/ml").
    let strengths: [String]
    let brands: [String]
    /// The usual amount each time, in words ("5 g (1 scoop)").
    let serving: String
    /// The same amount in the type's units, for the "Each time" stepper.
    let perDose: Int
    /// Among the most commonly taken; ranked first among equal matches.
    let popular: Bool

    var id: String { name }
}

/// A search hit: the medicine, and the brand the query matched, if it
/// matched a brand rather than the name ("ozem" → Semaglutide, Ozempic).
struct CatalogMatch: Hashable, Identifiable {
    let medicine: CatalogMedicine
    let brand: String?

    var id: String { medicine.id + (brand ?? "") }
}

/// Offline name suggestions for the Add flow, so nothing typed leaves the
/// phone. Matches the start of the name, any word in it, or a brand, and
/// forgives a typo or two ("createene" → Creatine Monohydrate).
enum MedicineCatalog {
    /// Loaded on first search and kept.
    static let all: [Entry] = load()

    struct Entry {
        let medicine: CatalogMedicine
        let key: String
        let words: [String]
        let brandKeys: [(brand: String, key: String)]
    }

    static func search(_ query: String, limit: Int = 6) -> [CatalogMatch] {
        let queryWords = words(of: query)
        let query = normalized(query)
        guard query.count >= 2 else { return [] }

        let scored = all.compactMap { entry -> (match: CatalogMatch, score: Int)? in
            guard let hit = match(entry, query: query, queryWords: queryWords) else { return nil }
            return (hit.match, hit.score + (entry.medicine.popular ? 5 : 0))
        }

        // Best score first, then the shorter (more basic) name.
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let (left, right) = (lhs.match.medicine.name, rhs.match.medicine.name)
                return left.count != right.count ? left.count < right.count : left < right
            }
            .prefix(limit)
            .map(\.match)
    }

    /// How well one entry matches, in tiers far enough apart that the
    /// popularity nudge never lifts a weaker kind of match over a better one.
    private static func match(_ entry: Entry, query: String, queryWords: [String]) -> (match: CatalogMatch, score: Int)? {
        if entry.key.hasPrefix(query) { return (CatalogMatch(medicine: entry.medicine, brand: nil), 100) }
        if entry.words.contains(where: { $0.hasPrefix(query) }) { return (CatalogMatch(medicine: entry.medicine, brand: nil), 80) }
        // "vit d": every typed word starts a word of the name.
        if queryWords.count > 1, queryWords.allSatisfy({ word in entry.words.contains { $0.hasPrefix(word) } }) {
            return (CatalogMatch(medicine: entry.medicine, brand: nil), 75)
        }
        if let brand = entry.brandKeys.first(where: { $0.key.hasPrefix(query) }) {
            return (CatalogMatch(medicine: entry.medicine, brand: brand.brand), 70)
        }
        if entry.key.contains(query) { return (CatalogMatch(medicine: entry.medicine, brand: nil), 50) }
        // Typos: compare against the start of the name and of each word.
        let allowed = query.count >= 7 ? 2 : query.count >= 4 ? 1 : 0
        guard allowed > 0 else { return nil }
        let distance = ([entry.key] + entry.words)
            .map { editDistance(query, String($0.prefix(query.count + 1))) }
            .min() ?? .max
        guard distance <= allowed else { return nil }
        return (CatalogMatch(medicine: entry.medicine, brand: nil), 30 - distance * 5)
    }

    // MARK: Plumbing

    private static func load() -> [Entry] {
        guard
            let url = Bundle.main.url(forResource: "MedicineCatalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let medicines = try? JSONDecoder().decode([CatalogMedicine].self, from: data)
        else { return [] }
        return medicines.map { medicine in
            Entry(
                medicine: medicine,
                key: normalized(medicine.name),
                words: words(of: medicine.name),
                brandKeys: medicine.brands.map { (brand: $0, key: normalized($0)) }
            )
        }
    }

    private static func words(of text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Lowercase letters and digits only: "BPC-157" and "bpc 157" match.
    private static func normalized(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// Levenshtein distance; the strings are a word long, so the simple
    /// two-row version is plenty.
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = previous
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
