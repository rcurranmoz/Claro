import Foundation
import RevenueCat

@Observable
final class SubscriptionService: NSObject {
    private(set) var isProUser = false
    private(set) var currentOffering: Offering?
    private(set) var isPurchasing = false
    private(set) var isRestoring = false

    static let freeScansLimit = 3
    private static let entitlementId = "Claro Lens Pro"

    func load() async {
        Purchases.shared.delegate = self
        await refresh()
    }

    func purchase(package: Package) async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await Purchases.shared.purchase(package: package)
        isProUser = result.customerInfo.entitlements[Self.entitlementId]?.isActive == true
    }

    func restore() async throws {
        isRestoring = true
        defer { isRestoring = false }
        let info = try await Purchases.shared.restorePurchases()
        isProUser = info.entitlements[Self.entitlementId]?.isActive == true
    }

    private func refresh() async {
        async let infoTask    = try? Purchases.shared.customerInfo()
        async let offerTask   = try? Purchases.shared.offerings()
        let (info, offerings) = await (infoTask, offerTask)
        isProUser        = info?.entitlements[Self.entitlementId]?.isActive == true
        currentOffering  = offerings?.current
    }
}

extension SubscriptionService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        isProUser = customerInfo.entitlements[Self.entitlementId]?.isActive == true
    }
}
