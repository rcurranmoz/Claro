import SwiftUI

struct SpendingView: View {
    @Environment(DocumentStore.self) private var store
    private let year = Calendar.current.component(.year, from: Date())

    private var yearDocs: [HealthDocument] {
        store.activeDocuments.filter {
            Calendar.current.component(.year, from: $0.dateScanned) == year &&
            $0.analysis != nil
        }
    }
    private var totalBilled:   Double { yearDocs.compactMap { $0.analysis?.totalBilled }.reduce(0, +) }
    private var totalOwed:     Double { yearDocs.compactMap { $0.analysis?.patientOwes }.reduce(0, +) }
    private var insurancePaid: Double { max(0, totalBilled - totalOwed) }
    private var savingsPct:    Double { totalBilled > 0 ? insurancePaid / totalBilled : 0 }

    private var byType: [(type: DocumentType, owed: Double)] {
        Dictionary(grouping: yearDocs, by: \.type)
            .compactMap { type, docs -> (DocumentType, Double)? in
                let amt = docs.compactMap { $0.analysis?.patientOwes }.reduce(0, +)
                return amt > 0 ? (type, amt) : nil
            }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ZStack {
            Color.claroBackground.ignoresSafeArea()
            if yearDocs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.claroSubtle.opacity(0.4))
                    Text("No analyzed documents yet this year.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.claroSubtle)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Top stat cards
                        HStack(spacing: 12) {
                            StatCard(label: "Total Billed",    amount: totalBilled,   color: .claroSubtle)
                            StatCard(label: "You Owe",         amount: totalOwed,     color: .claroWarning)
                        }
                        HStack(spacing: 12) {
                            StatCard(label: "Insurance Paid",  amount: insurancePaid, color: .claroAccent)
                            StatCard(label: "Documents",       amount: Double(yearDocs.count),
                                     color: .cyan, isCurrency: false, suffix: "docs")
                        }

                        // Savings bar
                        CardSection(title: "Insurance Coverage") {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Covered by insurance")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.claroSubtle)
                                    Spacer()
                                    Text("\(Int(savingsPct * 100))%")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.claroAccent)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 4).fill(Color.claroAccent)
                                            .frame(width: geo.size.width * max(savingsPct, 0.02))
                                    }
                                }
                                .frame(height: 6)
                                Text("Insurance covered \(insurancePaid, format: .currency(code: "USD")) of \(totalBilled, format: .currency(code: "USD")) billed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.claroSubtle)
                            }
                        }

                        // Breakdown by type
                        if !byType.isEmpty {
                            CardSection(title: "By Document Type") {
                                VStack(spacing: 12) {
                                    ForEach(byType, id: \.type) { row in
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(row.type.accentColor.opacity(0.15))
                                                    .frame(width: 32, height: 32)
                                                Image(systemName: row.type.systemImage)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(row.type.accentColor)
                                            }
                                            Text(row.type.rawValue)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(row.owed, format: .currency(code: "USD"))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.claroWarning)
                                        }
                                    }
                                }
                            }
                        }

                        // Document list
                        CardSection(title: "All Documents") {
                            VStack(spacing: 12) {
                                ForEach(yearDocs) { doc in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text(doc.dateScanned.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.claroSubtle)
                                        }
                                        Spacer()
                                        if let owes = doc.analysis?.patientOwes {
                                            Text(owes, format: .currency(code: "USD"))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(owes > 0 ? Color.claroWarning : Color.claroAccent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("\(year) Spending")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatCard: View {
    let label: String
    let amount: Double
    let color: Color
    var isCurrency: Bool = true
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.claroSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
            if isCurrency {
                Text(amount, format: .currency(code: "USD"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(amount))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                    Text(suffix)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.claroSubtle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.claroSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
