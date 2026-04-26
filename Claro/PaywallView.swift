import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var selectedPackage: Package?
    @State private var errorMessage: String?

    private let features: [(icon: String, text: String)] = [
        ("doc.viewfinder.fill",         "Unlimited document scans"),
        ("text.badge.checkmark",        "Full AI billing analysis"),
        ("doc.text.badge.ellipsis",     "Dispute letter generator"),
        ("chart.bar.fill",              "Spending analytics"),
        ("person.2.fill",               "Family profiles"),
        ("bell.badge.fill",             "Analysis notifications"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.claroAccent.opacity(0.15))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.claroAccent)
                            }
                            Text("Claro Pro")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Your full medical billing advocate")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.claroSubtle)
                        }
                        .padding(.top, 8)

                        // Features
                        VStack(spacing: 10) {
                            ForEach(features, id: \.text) { feature in
                                HStack(spacing: 14) {
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.claroAccent)
                                        .frame(width: 22)
                                    Text(feature.text)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.claroSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Packages
                        if let offering = subscriptions.currentOffering {
                            VStack(spacing: 10) {
                                ForEach(offering.availablePackages, id: \.identifier) { pkg in
                                    PackageCard(
                                        package: pkg,
                                        isSelected: selectedPackage?.identifier == pkg.identifier
                                    ) { selectedPackage = pkg }
                                }
                            }
                            .onAppear {
                                if selectedPackage == nil {
                                    selectedPackage = offering.annual ?? offering.monthly
                                }
                            }
                        } else {
                            ProgressView().tint(Color.claroAccent)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.claroDanger)
                                .multilineTextAlignment(.center)
                        }

                        // Subscribe button
                        Button {
                            guard let pkg = selectedPackage else { return }
                            Task {
                                do {
                                    try await subscriptions.purchase(package: pkg)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            Group {
                                if subscriptions.isPurchasing {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Subscribe")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.claroAccent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedPackage == nil || subscriptions.isPurchasing)

                        // Footer actions
                        HStack(spacing: 24) {
                            Button {
                                Task {
                                    do {
                                        try await subscriptions.restore()
                                        if subscriptions.isProUser { dismiss() }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                if subscriptions.isRestoring {
                                    ProgressView().tint(Color.claroSubtle).scaleEffect(0.8)
                                } else {
                                    Text("Restore Purchases")
                                }
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(Color.claroSubtle)
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.claroSubtle)
                            .font(.system(size: 20))
                    }
                }
            }
        }
    }
}

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    private var isAnnual: Bool { package.packageType == .annual }
    private var title: String { isAnnual ? "Annual" : "Monthly" }
    private var price: String { package.storeProduct.localizedPriceString }
    private var period: String { isAnnual ? "/ year" : "/ month" }
    private var badge: String? { isAnnual ? "Best Value" : nil }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.claroAccent : Color.claroSubtle.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.claroAccent).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.claroAccent.opacity(0.2))
                                .foregroundStyle(Color.claroAccent)
                                .clipShape(Capsule())
                        }
                    }
                    if isAnnual {
                        Text("~\(monthlyEquivalent) / month")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.claroSubtle)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(period)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.claroSubtle)
                }
            }
            .padding(16)
            .background(isSelected ? Color.claroAccent.opacity(0.08) : Color.claroSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.claroAccent.opacity(0.5) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var monthlyEquivalent: String {
        guard let price = package.storeProduct.price as Decimal?,
              price > 0 else { return "" }
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = package.storeProduct.currencyCode ?? "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly as NSDecimalNumber) ?? ""
    }
}
