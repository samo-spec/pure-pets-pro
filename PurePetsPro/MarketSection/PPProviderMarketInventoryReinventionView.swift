//
//  PPProviderMarketInventoryReinventionView.swift
//  PurePetsPro
//
//  SwiftyMax NextGen V10 Category-Defining First-Principles Reinvention
//  The Living Merchant Inventory & Catalog Cockpit
//
//  Reinvented from absolute first principles for Apple iOS:
//  - Eliminates cluttered, repetitive, disjointed telemetry boxes
//  - Living Atmospheric Canopy: Total Catalog Valuation, Biometric Health Radial Dial & Capital Velocity
//  - 4 Dynamic Segmental Telemetry Filters with magnetic feedback & spring transitions
//  - Intelligent Omni-Pill Taxonomy Strip with live item densities & zero text clipping
//  - High-precision tactile product cells with category-tinted spatial thumbnails
//  - Direct-manipulation stock steppers with instant "+10 Quick Restock" for depleted items
//  - Interactive Storefront Visibility Beacon with living emerald pulse and transient undo toast
//  - Integrated Smart Barcode & SKU Scanner HUD simulator
//  - Quick Stock Stepper Modal with large mechanical dial & rapid multiplier chips
//  - Full bilingual Arabic (RTL, primary) and English (LTR, secondary) support with Beiruti typography
//  - Dynamic Type adaptive (xSmall through AX5) with ViewThatFits reflow & fluid spring physics
//  - 100% backward-compatible Objective-C bridge (PPProviderMarketInventoryHostingController)
//

import SwiftUI
import UIKit

// MARK: - Reusable PurePets Font System (Beiruti Family)

public enum PPFont {
    public static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        PPBrandFont.registerIfNeeded()
        return Font.custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    public static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        PPBrandFont.registerIfNeeded()
        return Font.custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    public static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        PPBrandFont.registerIfNeeded()
        return Font.custom("Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Taxonomy & Kind Representation

public enum PPInventoryKind: Int, CaseIterable, Identifiable {
    case all = 0
    case food = 1
    case liveAnimal = 2
    case medicine = 3
    case accessory = 4

    public var id: Int { rawValue }

    public func title(isRTL: Bool) -> String {
        switch self {
        case .all:
            return isRTL ? "الكل" : "All"
        case .food:
            return isRTL ? "طعام" : "Food"
        case .liveAnimal:
            return isRTL ? "حيوانات حية" : "Live Animals"
        case .medicine:
            return isRTL ? "أدوية" : "Medicines"
        case .accessory:
            return isRTL ? "إكسسوارات" : "Accessories"
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .food: return "fork.knife"
        case .liveAnimal: return "pawprint.fill"
        case .medicine: return "cross.case.fill"
        case .accessory: return "sparkles"
        }
    }

    public var themeColor: Color {
        switch self {
        case .all: return Color(red: 0.32, green: 0.36, blue: 0.44)
        case .food: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .liveAnimal: return Color(red: 0.05, green: 0.72, blue: 0.50)
        case .medicine: return Color(red: 0.20, green: 0.58, blue: 0.95)
        case .accessory: return Color(red: 0.88, green: 0.18, blue: 0.38)
        }
    }
}

// MARK: - Stock Health Status

public enum PPStockHealth: Equatable {
    case outOfStock
    case critical(count: Int)
    case healthy(count: Int)

    public var count: Int {
        switch self {
        case .outOfStock: return 0
        case .critical(let c): return c
        case .healthy(let c): return c
        }
    }

    public func label(isRTL: Bool) -> String {
        switch self {
        case .outOfStock:
            return isRTL ? "نفد المخزون" : "Out of Stock"
        case .critical(let c):
            return isRTL ? "منخفض: \(c)" : "Low: \(c)"
        case .healthy(let c):
            return isRTL ? "متوفر: \(c)" : "In Stock: \(c)"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .outOfStock:
            return Color(red: 0.90, green: 0.15, blue: 0.25)
        case .critical:
            return Color(red: 0.95, green: 0.55, blue: 0.12)
        case .healthy:
            return Color(red: 0.05, green: 0.72, blue: 0.50)
        }
    }

    public var requiresUrgentAttention: Bool {
        switch self {
        case .outOfStock, .critical: return true
        case .healthy: return false
        }
    }
}

// MARK: - Inventory Item Domain Model

public struct PPInventoryItemModel: Identifiable, Equatable {
    public let id: String
    public var nameAr: String
    public var nameEn: String
    public var kind: PPInventoryKind
    public var price: Double
    public var originalPrice: Double?
    public var stock: Int
    public var isListedInApp: Bool
    public var hasActiveOffer: Bool
    public var imageURL: String?
    public var sku: String
    public var barcode: String?
    public var updatedAt: Date

    // Domain Specific Metadata
    public var petCategoryName: String?
    public var isLiveAnimal: Bool
    public var requiresPrescription: Bool

    public var health: PPStockHealth {
        if stock <= 0 {
            return .outOfStock
        } else if stock <= 5 {
            return .critical(count: stock)
        } else {
            return .healthy(count: stock)
        }
    }

    public var discountPercent: Int? {
        guard let orig = originalPrice, orig > price, orig > 0 else { return nil }
        return Int(round(((orig - price) / orig) * 100))
    }

    public init(
        id: String,
        nameAr: String,
        nameEn: String,
        kind: PPInventoryKind,
        price: Double,
        originalPrice: Double? = nil,
        stock: Int,
        isListedInApp: Bool = true,
        hasActiveOffer: Bool = false,
        imageURL: String? = nil,
        sku: String = "",
        barcode: String? = nil,
        updatedAt: Date = Date(),
        petCategoryName: String? = nil,
        isLiveAnimal: Bool = false,
        requiresPrescription: Bool = false
    ) {
        self.id = id
        self.nameAr = nameAr
        self.nameEn = nameEn
        self.kind = kind
        self.price = price
        self.originalPrice = originalPrice
        self.stock = stock
        self.isListedInApp = isListedInApp
        self.hasActiveOffer = hasActiveOffer
        self.imageURL = imageURL
        self.sku = sku
        self.barcode = barcode
        self.updatedAt = updatedAt
        self.petCategoryName = petCategoryName
        self.isLiveAnimal = isLiveAnimal
        self.requiresPrescription = requiresPrescription
    }
}

// MARK: - Inventory Cockpit View Model

@MainActor
public final class PPInventoryCockpitViewModel: ObservableObject {
    @Published public var items: [PPInventoryItemModel] = []
    @Published public var searchText: String = ""
    @Published public var selectedKind: PPInventoryKind = .all
    @Published public var activeFilterMetric: FilterMetric = .all
    @Published public var sortMode: SortMode = .newest
    @Published public var isBatchMode: Bool = false
    @Published public var selectedItemIDs: Set<String> = []
    @Published public var isCompactView: Bool = false
    @Published public var editingStockItem: PPInventoryItemModel? = nil
    @Published public var selectedItemForDetails: PPInventoryItemModel? = nil
    @Published public var bannerMessage: String? = nil
    @Published public var currentBranchNameAr: String = "فرع الدوحة الرئيسي"
    @Published public var currentBranchNameEn: String = "Doha Main Branch"

    public enum FilterMetric: Equatable {
        case all
        case lowStockOnly
        case activeOffersOnly
        case hiddenOnly
    }

    public enum SortMode: CaseIterable {
        case newest
        case priceHighToLow
        case priceLowToHigh
        case stockLowestFirst
        case stockHighestFirst

        public func title(isRTL: Bool) -> String {
            switch self {
            case .newest: return isRTL ? "الأحدث أولاً" : "Newest"
            case .priceHighToLow: return isRTL ? "الأعلى سعراً" : "Price: High to Low"
            case .priceLowToHigh: return isRTL ? "الأقل سعراً" : "Price: Low to High"
            case .stockLowestFirst: return isRTL ? "الأقل مخزوناً (عاجل)" : "Low Stock First"
            case .stockHighestFirst: return isRTL ? "الأعلى مخزوناً" : "High Stock First"
            }
        }
    }

    public init(mockItems: [PPInventoryItemModel]? = nil) {
        if let mock = mockItems {
            self.items = mock
        } else {
            self.loadDefaultCatalog()
        }
    }

    // MARK: - Telemetry KPI Metrics

    public var totalProductsCount: Int {
        items.count
    }

    public var totalCatalogValue: Double {
        items.reduce(0.0) { sum, item in
            sum + (item.price * Double(max(item.stock, 0)))
        }
    }

    public var activeOffersCount: Int {
        items.filter { $0.hasActiveOffer || $0.discountPercent != nil }.count
    }

    public var stockAlertsCount: Int {
        items.filter { $0.health.requiresUrgentAttention }.count
    }

    public var hiddenCount: Int {
        items.filter { !$0.isListedInApp }.count
    }

    public var healthyCount: Int {
        items.filter { $0.stock > 5 }.count
    }

    public var outOfStockCount: Int {
        items.filter { $0.stock <= 0 }.count
    }

    public var filteredItems: [PPInventoryItemModel] {
        var result = items

        // 1. Kind filter
        if selectedKind != .all {
            result = result.filter { $0.kind == selectedKind }
        }

        // 2. Metric pulse filter
        switch activeFilterMetric {
        case .all:
            break
        case .lowStockOnly:
            result = result.filter { $0.health.requiresUrgentAttention }
        case .activeOffersOnly:
            result = result.filter { $0.hasActiveOffer || $0.discountPercent != nil }
        case .hiddenOnly:
            result = result.filter { !$0.isListedInApp }
        }

        // 3. Search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.nameAr.lowercased().contains(query) ||
                item.nameEn.lowercased().contains(query) ||
                item.sku.lowercased().contains(query) ||
                (item.barcode?.lowercased().contains(query) ?? false) ||
                String(format: "%.0f", item.price).contains(query)
            }
        }

        // 4. Sorting
        switch sortMode {
        case .newest:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .priceHighToLow:
            result.sort { $0.price > $1.price }
        case .priceLowToHigh:
            result.sort { $0.price < $1.price }
        case .stockLowestFirst:
            result.sort { $0.stock < $1.stock }
        case .stockHighestFirst:
            result.sort { $0.stock > $1.stock }
        }

        return result
    }

    // MARK: - Direct Manipulation Actions

    public func adjustStock(for itemID: String, delta: Int) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let current = items[idx].stock
        let newStock = max(0, current + delta)
        items[idx].stock = newStock
        items[idx].updatedAt = Date()
        triggerHaptic(.light)
    }

    public func setExactStock(for itemID: String, newStock: Int) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].stock = max(0, newStock)
        items[idx].updatedAt = Date()
        triggerHaptic(.medium)
    }

    public func quickRestockAdd(for itemID: String, count: Int = 10) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].stock += count
        items[idx].updatedAt = Date()
        triggerNotificationHaptic(.success)
        let isRTL = Language.isRTL()
        showBanner(isRTL ? "تمت إضافة \(count) وحدات إلى المخزون بنجاح" : "Successfully added \(count) units to stock")
    }

    public func toggleVisibility(for itemID: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].isListedInApp.toggle()
        items[idx].updatedAt = Date()
        triggerSelectionHaptic()
        let isRTL = Language.isRTL()
        let stateAr = items[idx].isListedInApp ? "المنتج معروض الآن في المتجر" : "تم إخفاء المنتج من المتجر"
        let stateEn = items[idx].isListedInApp ? "Product is now live in store" : "Product hidden from store"
        showBanner(isRTL ? stateAr : stateEn)
    }

    public func toggleActiveOffer(for itemID: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].hasActiveOffer.toggle()
        if items[idx].hasActiveOffer && items[idx].originalPrice == nil {
            items[idx].originalPrice = items[idx].price * 1.25
        } else if !items[idx].hasActiveOffer {
            items[idx].originalPrice = nil
        }
        items[idx].updatedAt = Date()
        triggerNotificationHaptic(.success)
    }

    public func duplicateItem(_ item: PPInventoryItemModel) {
        var copy = item
        let newId = UUID().uuidString
        copy = PPInventoryItemModel(
            id: newId,
            nameAr: "\(item.nameAr) (نسخة)",
            nameEn: "\(item.nameEn) (Copy)",
            kind: item.kind,
            price: item.price,
            originalPrice: item.originalPrice,
            stock: item.stock,
            isListedInApp: false, // Default to draft for safety
            hasActiveOffer: item.hasActiveOffer,
            imageURL: item.imageURL,
            sku: "\(item.sku)-CPY",
            barcode: nil,
            updatedAt: Date(),
            petCategoryName: item.petCategoryName,
            isLiveAnimal: item.isLiveAnimal,
            requiresPrescription: item.requiresPrescription
        )
        items.insert(copy, at: 0)
        triggerNotificationHaptic(.success)
        showBanner(Language.isRTL() ? "تم إنشاء نسخة من المنتج بنجاح" : "Product duplicated successfully")
    }

    public func deleteItem(by id: String) {
        items.removeAll(where: { $0.id == id })
        selectedItemIDs.remove(id)
        triggerNotificationHaptic(.warning)
        showBanner(Language.isRTL() ? "تم حذف العنصر من الكتالوج" : "Product removed from catalog")
    }

    public func updateItem(_ updated: PPInventoryItemModel) {
        if let idx = items.firstIndex(where: { $0.id == updated.id }) {
            items[idx] = updated
        }
        triggerNotificationHaptic(.success)
        let isRTL = Language.isRTL()
        showBanner(isRTL ? "تم تحديث بيانات المنتج ومزامنتها بنجاح" : "Product details updated successfully")
    }

    // MARK: - Batch Operations

    public func toggleBatchSelect(for id: String) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
        triggerHaptic(.light)
    }

    public func selectAllFiltered() {
        let allIds = filteredItems.map { $0.id }
        selectedItemIDs = Set(allIds)
        triggerHaptic(.medium)
    }

    public func deselectAll() {
        selectedItemIDs.removeAll()
        triggerHaptic(.light)
    }

    public func bulkSetVisibility(listed: Bool) {
        for id in selectedItemIDs {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isListedInApp = listed
            }
        }
        triggerNotificationHaptic(.success)
        let isRTL = Language.isRTL()
        showBanner(listed ? (isRTL ? "تم تفعيل العناصر المحددة في المتجر" : "Selected items published") : (isRTL ? "تم إخفاء العناصر المحددة" : "Selected items hidden"))
        deselectAll()
        isBatchMode = false
    }

    public func bulkRestock(addUnits: Int) {
        for id in selectedItemIDs {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].stock += addUnits
            }
        }
        triggerNotificationHaptic(.success)
        let isRTL = Language.isRTL()
        showBanner(isRTL ? "تمت إضافة \(addUnits) وحدة للعناصر المحددة" : "Added \(addUnits) units to selected items")
        deselectAll()
        isBatchMode = false
    }

    public func bulkDelete() {
        items.removeAll(where: { selectedItemIDs.contains($0.id) })
        deselectAll()
        isBatchMode = false
        triggerNotificationHaptic(.warning)
        showBanner(Language.isRTL() ? "تم حذف العناصر المحددة" : "Selected items deleted")
    }

    // MARK: - Utilities

    public func showBanner(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.bannerMessage = message
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                if self?.bannerMessage == message {
                    self?.bannerMessage = nil
                }
            }
        }
    }

    public func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    public func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    public func triggerSelectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    public func updateFromMarketItems(_ marketItems: [PPProviderMarketItem]) {
        guard !marketItems.isEmpty else { return }
        self.items = marketItems.map { item in
            let kind: PPInventoryKind
            switch item.accessKindType {
            case 2: kind = .food
            case 3: kind = .liveAnimal
            case 4: kind = .medicine
            default: kind = .accessory
            }
            let isLive = (item.accessKindType == 3)
            let isRx = (item.accessKindType == 4)
            let titleAr = !item.name.isEmpty ? item.name : (item.nameEn ?? "")
            let titleEn = (item.nameEn != nil && !item.nameEn!.isEmpty) ? item.nameEn! : titleAr
            let itemId = !item.itemID.isEmpty ? item.itemID : UUID().uuidString
            return PPInventoryItemModel(
                id: itemId,
                nameAr: titleAr,
                nameEn: titleEn,
                kind: kind,
                price: item.price,
                originalPrice: item.hasOffer ? (item.price * 1.25) : nil,
                stock: Int(item.quantity),
                isListedInApp: item.showInAppMarket,
                hasActiveOffer: item.hasOffer,
                imageURL: item.imageURLsArray.first,
                sku: item.sku ?? "",
                barcode: item.barcode,
                updatedAt: item.updatedAt ?? Date(),
                petCategoryName: item.petMainCategoryName,
                isLiveAnimal: isLive,
                requiresPrescription: isRx
            )
        }
    }

    // Default Seed Data authentic to the user's real business screenshot
    private func loadDefaultCatalog() {
        var seed: [PPInventoryItemModel] = [
            // 1. Cerelac A21 Jana 800g (Food, In Stock: 8, Live in Store)
            PPInventoryItemModel(
                id: "item_cerelac_800",
                nameAr: "سيريللاك A21 جنى 800 جرام",
                nameEn: "Cerelac A21 Jana 800g",
                kind: .food,
                price: 45.0,
                originalPrice: nil,
                stock: 8,
                isListedInApp: true,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/cerelac.png",
                sku: "FOD-CRL-800",
                barcode: "629110023451",
                updatedAt: Date().addingTimeInterval(-1800),
                petCategoryName: "تغذية طيور"
            ),
            // 2. www / Pro Nail Trimmer (Accessory, Out of Stock: 0, Live in Store)
            PPInventoryItemModel(
                id: "item_nail_trimmer",
                nameAr: "كماشة أظافر الحيوانات الأليفة الاحترافية",
                nameEn: "www",
                kind: .accessory,
                price: 111.0,
                originalPrice: nil,
                stock: 0,
                isListedInApp: true,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/trimmer.png",
                sku: "ACC-TRM-111",
                barcode: "629110023452",
                updatedAt: Date().addingTimeInterval(-3600),
                petCategoryName: "عناية ونظافة"
            ),
            // 3. Cave Dog Bed (Accessory, Out of Stock: 0, Hidden)
            PPInventoryItemModel(
                id: "item_cave_bed",
                nameAr: "سرير كهف للكلاب والقطط الصغيرة",
                nameEn: "Cave Dog Bed",
                kind: .accessory,
                price: 130.0,
                originalPrice: nil,
                stock: 0,
                isListedInApp: false,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/cave_bed.png",
                sku: "ACC-BED-130",
                barcode: "629110023453",
                updatedAt: Date().addingTimeInterval(-7200),
                petCategoryName: "أسرّة وراحة"
            ),
            // 4. Bird Toys (Accessory, In Stock: 14, Live in Store)
            PPInventoryItemModel(
                id: "item_bird_toys",
                nameAr: "ألعاب وأراجيح الطيور الخشبية الملونة",
                nameEn: "Bird Toys",
                kind: .accessory,
                price: 35.0,
                originalPrice: 50.0,
                stock: 14,
                isListedInApp: true,
                hasActiveOffer: true,
                imageURL: "https://purepets.qa/media/bird_toys.png",
                sku: "ACC-TOY-035",
                barcode: "629110023454",
                updatedAt: Date().addingTimeInterval(-10800),
                petCategoryName: "ألعاب طيور"
            ),
            // 5. Royal Canin Gastrointestinal 2kg (Food, Stock: 4 - Critical Alert, Live)
            PPInventoryItemModel(
                id: "item_royal_canin",
                nameAr: "طعام رويال كانين فايبر ريسبونس للقطط 2 كغ",
                nameEn: "Royal Canin Gastrointestinal Fibre 2kg",
                kind: .food,
                price: 185.0,
                originalPrice: nil,
                stock: 4,
                isListedInApp: true,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/royal_cat.png",
                sku: "FOD-ROY-185",
                barcode: "3182550770542",
                updatedAt: Date().addingTimeInterval(-14400),
                petCategoryName: "طعام علاجي"
            ),
            // 6. Hand-Reared Dutch African Grey (Live Animal, Stock: 2, Live, Vet Checked)
            PPInventoryItemModel(
                id: "item_grey_parrot",
                nameAr: "ببغاء كاسكو هولندي أليف مفحوص بيطرياً",
                nameEn: "Hand-Reared Dutch African Grey Parrot",
                kind: .liveAnimal,
                price: 4500.0,
                originalPrice: nil,
                stock: 2,
                isListedInApp: true,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/grey_parrot.png",
                sku: "PET-GRY-450",
                barcode: "CHIP-981098234",
                updatedAt: Date().addingTimeInterval(-18000),
                petCategoryName: "طيور ناطقة",
                isLiveAnimal: true
            ),
            // 7. Veterinary Amoxicillin Oral Drops (Medicine, Stock: 1, Live, Rx)
            PPInventoryItemModel(
                id: "item_amox_drops",
                nameAr: "محلول أموكسيسيلين بيطري مضاد للالتهاب",
                nameEn: "Veterinary Amoxicillin Oral Suspension",
                kind: .medicine,
                price: 95.0,
                originalPrice: nil,
                stock: 1,
                isListedInApp: true,
                hasActiveOffer: false,
                imageURL: "https://purepets.qa/media/amox.png",
                sku: "MED-AMX-095",
                barcode: "629881122334",
                updatedAt: Date().addingTimeInterval(-21600),
                petCategoryName: "أدوية ومضادات",
                requiresPrescription: true
            )
        ]

        // Populate items to reach exact total count of 39 items with authentic business distribution
        let foodTitles: [(String, String, Double, Int, Bool)] = [
            ("طعام جاف للجراء الصغيرة بنكهة الدجاج", "Puppy Mini Starter Chicken Dry Food", 90.0, 12, true),
            ("معلبات سمك السلمون اللذيذة للقطط البالغة", "Adult Gourmet Salmon Canned Wet Food", 12.0, 48, true),
            ("مكافآت تدريب الكلاب العضوية باللحم البقري", "Organic Beef Bite Training Dog Treats", 28.0, 0, false),
            ("خلطة حبوب فاخرة للببغاوات الكبيرة 1 كغ", "Premium Big Parrot Seeds & Nut Blend 1kg", 65.0, 2, true),
            ("طعام هيلز ساينس بلان للقطط الحساسة", "Hill's Science Plan Sensitive Stomach 1.5kg", 170.0, 3, false),
            ("مكعبات التبن والفيتامينات للأرانب والهامستر", "Compressed Alfalfa Hay Cubes for Rabbits", 22.0, 16, true),
            ("طعام قطط هابي كات لتعزيز المناعة", "Happy Cat Supreme Immune Booster 4kg", 240.0, 1, false),
            ("وجبات تونا وجيلي الخفيفة للقطط", "Tuna in Jelly Light Pouches 85g", 8.0, 60, true),
            ("حليب بديل للقطط والجراء حديثة الولادة", "Mother & Babycat Instant Replacement Milk", 85.0, 0, false),
            ("طعام رطب للكلاب كبار السن مع الجلوكوزامين", "Senior Dog Joint Care Wet Food 400g", 18.0, 22, true),
            ("حبيبات الفيتامينات الكاملة للكناري والحسون", "Complete Canary Nutri-Pellets 500g", 38.0, 5, false),
            ("معجون فيتامينات ومعادن متعددة للقطط", "Multi-Vitamin Power Paste for Cats", 42.0, 0, true),
            ("طعام قطط بريت كير الخالي من الحبوب", "Brit Care Grain-Free Sensitive Cat 2kg", 145.0, 4, false),
            ("قطع عظام المضغ للكلاب لتنظيف الأسنان", "Dental Hygiene Rawhide Chews for Dogs", 32.0, 18, true),
            ("حبوب الكالسيوم والعظام للطيور والزواحف", "Pure Calcium & D3 Cuttlefish Mineral Bone", 15.0, 0, false),
            ("طعام مجفف للأسماك الذهبية وأسماك الزينة", "Golden Flake Tropical Aquarium Fish Food", 25.0, 30, true),
            ("طعام بيورليكات الطبيعي بالدجاج والديك الرومي", "PurelyCat Natural Shredded Chicken 150g", 14.0, 0, false),
            ("أعشاب النعناع البري الطبيعية المجففة", "Organic Crushed Catnip Leaves Tub", 29.0, 7, true),
            ("بسكويت بالجبن والنعناع للعناية برائحة الفم", "Fresh Breath Minty Biscuit Bites 200g", 24.0, 2, false),
            ("طعام رطب عضوي للجراء من بيورينا برو بلان", "Purina Pro Plan OptiStart Puppy 400g", 20.0, 0, false),
            ("وجبات مكافآت اللحم المجفف بالتجميد", "Freeze-Dried Raw Beef Chunks 100g", 55.0, 9, true),
            ("حبيبات الروبيان المجفف للسلاحف المائية", "Freeze-Dried River Shrimps for Turtles", 30.0, 14, false),
            ("عصيدة إنقاذ الطيور المريضة الفورية", "Emergency Critical Care Bird Formula", 75.0, 1, false),
            ("طعام جاف للكلاب الرياضية عالية النشاط", "Active Sport High-Protein Dog Kibble 15kg", 390.0, 0, false),
            ("مكافآت السوشي البحرية للقطط المدللة", "Gourmet Ocean Sushi Cat Drops 50g", 16.0, 35, true)
        ]

        let accTitles: [(String, String, Double, Int, Bool)] = [
            ("طوق جلد إيطالي فاخر مع شريحة مدمجة", "Italian Leather Collar with QR Tag", 95.0, 0, false),
            ("قفص طيور واسع مطلي بالكروم المقاوم للصدأ", "Stainless Chrome Flight Cage for Parrots", 380.0, 3, true),
            ("صندوق فضلات القطط الذكي المغلق مع فلتر", "Enclosed Cat Litter Box with Carbon Filter", 125.0, 0, false),
            ("حزام أمان للسيارة مخصص للكلاب الكبيرة", "Heavy-Duty Vehicle Seatbelt Dog Harness", 48.0, 15, true),
            ("حوض زجاجي نقي 30 لتر مع إضاءة ليد", "Ultra-Clear Glass Nano Aquarium 30L", 260.0, 0, false),
            ("لعبة الليزر التفاعلية الأوتوماتيكية للقطط", "Smart Robotic 360 Laser Toy for Cats", 85.0, 8, true),
            ("مشط إزالة الوبر والشعر الميت المتساقط", "De-Shedding Undercoat Grooming Rake", 62.0, 0, false)
        ]

        var idCount = 8
        for (ar, en, price, stock, listed) in foodTitles {
            seed.append(
                PPInventoryItemModel(
                    id: "seed_item_\(idCount)",
                    nameAr: ar,
                    nameEn: en,
                    kind: .food,
                    price: price,
                    stock: stock,
                    isListedInApp: listed,
                    hasActiveOffer: false,
                    sku: String(format: "FOD-%03d", idCount),
                    barcode: String(format: "629100%06d", idCount),
                    updatedAt: Date().addingTimeInterval(Double(-idCount * 1800)),
                    petCategoryName: "أغذية ومكملات"
                )
            )
            idCount += 1
        }

        for (ar, en, price, stock, listed) in accTitles {
            seed.append(
                PPInventoryItemModel(
                    id: "seed_item_\(idCount)",
                    nameAr: ar,
                    nameEn: en,
                    kind: .accessory,
                    price: price,
                    stock: stock,
                    isListedInApp: listed,
                    hasActiveOffer: false,
                    sku: String(format: "ACC-%03d", idCount),
                    barcode: String(format: "629100%06d", idCount),
                    updatedAt: Date().addingTimeInterval(Double(-idCount * 2200)),
                    petCategoryName: "مستلزمات وإكسسوارات"
                )
            )
            idCount += 1
        }

        self.items = seed
    }
}

// MARK: - Main Reinvented Screen View (Next-Gen V10 Sovereign Cockpit)

public struct PPProviderMarketInventoryView: View {
    @ObservedObject public var viewModel: PPInventoryCockpitViewModel
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss

    public var onDismiss: (() -> Void)? = nil
    public var onAddProduct: (() -> Void)? = nil

    @State private var showingBarcodeScanner = false
    @State private var showingBranchPicker = false

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    public init(
        viewModel: PPInventoryCockpitViewModel = PPInventoryCockpitViewModel(),
        onDismiss: (() -> Void)? = nil,
        onAddProduct: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onAddProduct = onAddProduct
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background Canvas: Soft Warm Alabaster Titanium Depth
            LinearGradient(
                colors: [
                    Color(red: 0.965, green: 0.968, blue: 0.975),
                    Color(red: 0.955, green: 0.960, blue: 0.968)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Studio Navigation Header
                studioNavigationBar

                // 2. Scrollable Body
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // The Atmospheric Canopy (Hero Telemetry Radar)
                        atmosphericCanopyHero

                        // Command & Triage Horizon (Search & Category Strip)
                        commandAndTriageHorizon

                        // Batch Triage Banner (When active)
                        if viewModel.isBatchMode {
                            batchTriageControlBar
                        }

                        // Product Stream / Feed
                        productStreamSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120) // Clearance for floating tab bar or batch action deck
                }
            }

            // Floating Banner Notification (Transient toast)
            if let banner = viewModel.bannerMessage {
                floatingToastBanner(text: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }

            // Floating Batch Action Dock (When batch items selected)
            if viewModel.isBatchMode && !viewModel.selectedItemIDs.isEmpty {
                floatingBatchDock
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(90)
            }
        }
        .sheet(item: $viewModel.editingStockItem) { item in
            quickStockStepperSheet(item: item)
        }
        .sheet(item: $viewModel.selectedItemForDetails) { item in
            PPProviderMarketItemDetailReinventionView(
                item: item,
                onSave: { updated in
                    viewModel.updateItem(updated)
                },
                onEditFullRequested: { _ in
                    viewModel.selectedItemForDetails = nil
                    onAddProduct?()
                },
                onDismiss: {
                    viewModel.selectedItemForDetails = nil
                }
            )
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            SmartBarcodeScannerSheet(
                isRTL: isRTL,
                onScannedCode: { code in
                    showingBarcodeScanner = false
                    viewModel.searchText = code
                    viewModel.triggerNotificationHaptic(.success)
                    viewModel.showBanner(isRTL ? "تم العثور على رمز: \(code)" : "Found barcode: \(code)")
                },
                onDismiss: {
                    showingBarcodeScanner = false
                }
            )
        }
        .sheet(isPresented: $showingBranchPicker) {
            BranchPickerModalSheet(
                currentBranchAr: viewModel.currentBranchNameAr,
                currentBranchEn: viewModel.currentBranchNameEn,
                isRTL: isRTL,
                onSelectBranch: { ar, en in
                    viewModel.currentBranchNameAr = ar
                    viewModel.currentBranchNameEn = en
                    showingBranchPicker = false
                    viewModel.triggerSelectionHaptic()
                    viewModel.showBanner(isRTL ? "تم التبديل إلى \(ar)" : "Switched to \(en)")
                },
                onDismiss: {
                    showingBranchPicker = false
                }
            )
        }
    }

    // MARK: - Helper Formatting & Metrics

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private func count(for kind: PPInventoryKind) -> Int {
        if kind == .all {
            return viewModel.items.count
        }
        return viewModel.items.filter { $0.kind == kind }.count
    }

    private var healthRatio: CGFloat {
        guard viewModel.totalProductsCount > 0 else { return 1.0 }
        let healthy = max(0, viewModel.totalProductsCount - viewModel.stockAlertsCount)
        return CGFloat(healthy) / CGFloat(viewModel.totalProductsCount)
    }

    // MARK: - 1. Studio Navigation Bar (Next-Gen V10 Sovereign Header)

    private var studioNavigationBar: some View {
        HStack(spacing: 12) {
            // Leading: Back / Dismiss Button
            Button(action: {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: isRTL ? "arrow.right" : "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.20))
                    .frame(width: 42, height: 42)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
            .accessibilityLabel(isRTL ? "رجوع" : "Back")

            // Center: Title & Branch Location Pill
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(isRTL ? "منتجاتي" : "My Catalog")
                        .font(PPFont.bold(22, relativeTo: .title3))
                        .foregroundColor(Color(red: 0.08, green: 0.10, blue: 0.14))

                    // Store / Branch Indicator with Living Emerald Pulse & Tappable Switcher
                    Button(action: {
                        showingBranchPicker = true
                    }) {
                        HStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.25))
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .fill(Color(red: 0.05, green: 0.72, blue: 0.50))
                                    .frame(width: 6, height: 6)
                            }

                            Text(isRTL ? viewModel.currentBranchNameAr : viewModel.currentBranchNameEn)
                                .font(PPFont.bold(11, relativeTo: .caption))
                                .foregroundColor(Color(red: 0.32, green: 0.36, blue: 0.44))

                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.50, green: 0.54, blue: 0.60))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.30), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text(isRTL ? "إدارة المخزون والعمليات والكتالوج الحي" : "Living merchant inventory & catalog telemetry")
                    .font(PPFont.medium(11.5, relativeTo: .footnote))
                    .foregroundColor(Color(red: 0.46, green: 0.50, blue: 0.56))
                    .lineLimit(1)
            }

            Spacer()

            // Trailing Actions: Add Product & Batch Mode Trigger
            HStack(spacing: 8) {
                // Batch Select Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isBatchMode.toggle()
                        if !viewModel.isBatchMode {
                            viewModel.deselectAll()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isBatchMode ? "checkmark.circle.fill" : "checklist")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(viewModel.isBatchMode ? Color.white : Color(red: 0.25, green: 0.28, blue: 0.35))
                        .frame(width: 42, height: 42)
                        .background(viewModel.isBatchMode ? Color(red: 0.88, green: 0.18, blue: 0.38) : Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(viewModel.isBatchMode ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: viewModel.isBatchMode ? Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.35) : Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                }
                .accessibilityLabel(isRTL ? "تحديد متعدد" : "Batch Select")

                // Add New Product ("+")
                Button(action: {
                    if let onAddProduct = onAddProduct {
                        onAddProduct()
                    } else {
                        viewModel.showBanner(isRTL ? "جاري فتح استوديو إضافة المنتجات..." : "Opening product editor studio...")
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.94, green: 0.22, blue: 0.42),
                                    Color(red: 0.82, green: 0.10, blue: 0.32)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color(red: 0.94, green: 0.22, blue: 0.42).opacity(0.40), radius: 10, x: 0, y: 4)
                }
                .accessibilityLabel(isRTL ? "إضافة منتج جديد" : "Add New Product")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    // MARK: - 2. The Atmospheric Canopy (Hero Telemetry Cockpit - Next-Gen V10)

    private var atmosphericCanopyHero: some View {
        VStack(spacing: 14) {
            // Main Valuation & Live Health Ring
            HStack(spacing: 14) {
                // Valuation Column
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.88, green: 0.18, blue: 0.38))
                            .frame(width: 6, height: 6)
                        Text(isRTL ? "القيمة الإجمالية للكتالوج" : "TOTAL CATALOG VALUATION")
                            .font(PPFont.bold(10.5, relativeTo: .caption))
                            .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.55))
                            .tracking(0.5)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedCurrency(viewModel.totalCatalogValue))
                            .font(PPFont.bold(30, relativeTo: .title))
                            .foregroundColor(Color(red: 0.08, green: 0.10, blue: 0.14))

                        Text(isRTL ? "ر.ق" : "QAR")
                            .font(PPFont.bold(12.5, relativeTo: .subheadline))
                            .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))
                        Text(isRTL ? "مخزون نشط ومتدفق" : "Active Flowing Stock")
                            .font(PPFont.bold(11.5, relativeTo: .caption))
                            .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))
                    }
                }

                Spacer()

                // Multi-Segment Biometric Orbital Ring
                ZStack {
                    // Outer subtle track
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 7)
                        .frame(width: 68, height: 68)

                    // Healthy Stock Arc (Emerald)
                    Circle()
                        .trim(from: 0, to: healthRatio)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.05, green: 0.72, blue: 0.50),
                                    Color(red: 0.20, green: 0.85, blue: 0.65)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 68, height: 68)

                    // Center stats
                    VStack(spacing: 0) {
                        Text("\(viewModel.totalProductsCount)")
                            .font(PPFont.bold(19, relativeTo: .headline))
                            .foregroundColor(Color(red: 0.10, green: 0.12, blue: 0.16))
                        Text(isRTL ? "عنصر" : "items")
                            .font(PPFont.bold(10, relativeTo: .caption2))
                            .foregroundColor(Color(red: 0.46, green: 0.50, blue: 0.56))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            // Specular Hairline Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.06), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Interactive Telemetry Metric Pillars (The 4 Command Pillars)
            HStack(spacing: 8) {
                // Metric 1: All Items
                telemetryFilterPill(
                    title: isRTL ? "الكل" : "All",
                    count: viewModel.totalProductsCount,
                    icon: "shippingbox.fill",
                    tint: Color(red: 0.35, green: 0.40, blue: 0.48),
                    isSelected: viewModel.activeFilterMetric == .all
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeFilterMetric = .all
                    }
                }

                // Metric 2: Urgent Stock Alert (Pulsing Amber)
                telemetryFilterPill(
                    title: isRTL ? "تنبيه المخزون" : "Stock Alert",
                    count: viewModel.stockAlertsCount,
                    icon: "exclamationmark.triangle.fill",
                    tint: Color(red: 0.95, green: 0.55, blue: 0.12),
                    isSelected: viewModel.activeFilterMetric == .lowStockOnly,
                    isAlert: viewModel.stockAlertsCount > 0
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeFilterMetric = (viewModel.activeFilterMetric == .lowStockOnly) ? .all : .lowStockOnly
                    }
                }

                // Metric 3: Active Offers
                telemetryFilterPill(
                    title: isRTL ? "عروض نشطة" : "Active Offers",
                    count: viewModel.activeOffersCount,
                    icon: "tag.fill",
                    tint: Color(red: 0.88, green: 0.18, blue: 0.38),
                    isSelected: viewModel.activeFilterMetric == .activeOffersOnly
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeFilterMetric = (viewModel.activeFilterMetric == .activeOffersOnly) ? .all : .activeOffersOnly
                    }
                }

                // Metric 4: Hidden / Drafts
                telemetryFilterPill(
                    title: isRTL ? "مخفي" : "Hidden",
                    count: viewModel.hiddenCount,
                    icon: "eye.slash.fill",
                    tint: Color(red: 0.48, green: 0.52, blue: 0.60),
                    isSelected: viewModel.activeFilterMetric == .hiddenOnly
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeFilterMetric = (viewModel.activeFilterMetric == .hiddenOnly) ? .all : .hiddenOnly
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.99, green: 0.985, blue: 0.99)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.12),
                                    Color.black.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 5)
        )
    }

    private func telemetryFilterPill(
        title: String,
        count: Int,
        icon: String,
        tint: Color,
        isSelected: Bool,
        isAlert: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? tint : (isAlert ? tint : tint.opacity(0.85)))

                    Text("\(count)")
                        .font(PPFont.bold(14.5, relativeTo: .subheadline))
                        .foregroundColor(isSelected ? tint : (isAlert ? tint : Color(red: 0.15, green: 0.18, blue: 0.22)))
                }

                Text(title)
                    .font(isSelected ? PPFont.bold(10.5, relativeTo: .caption) : PPFont.medium(10.5, relativeTo: .caption))
                    .foregroundColor(isSelected ? tint : Color(red: 0.46, green: 0.50, blue: 0.56))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.15) : (isAlert ? tint.opacity(0.08) : Color(red: 0.965, green: 0.970, blue: 0.980)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? tint.opacity(0.45) : (isAlert ? tint.opacity(0.30) : Color.clear), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 3. Command & Triage Horizon (Search & Omni-Pill Taxonomy Strip)

    private var commandAndTriageHorizon: some View {
        VStack(spacing: 10) {
            // Search Field & Quick Filters Trigger
            HStack(spacing: 10) {
                // Search Field Container
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.48, green: 0.52, blue: 0.58))

                    TextField(
                        isRTL ? "ابحث بالاسم، الفئة، السعر، أو الرمز..." : "Search by name, category, price, or SKU...",
                        text: $viewModel.searchText
                    )
                    .font(PPFont.regular(13.5, relativeTo: .body))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.20))

                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.65, green: 0.68, blue: 0.72))
                        }
                    }

                    // Barcode Scanner Shortcut Capsule
                    Button(action: {
                        showingBarcodeScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .accessibilityLabel(isRTL ? "مسح الباركود" : "Scan Barcode")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8.5)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.045), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)

                // Sort & Filter Menu Trigger
                Menu {
                    Section(header: Text(isRTL ? "ترتيب العناصر" : "Sort Catalog")) {
                        ForEach(PPInventoryCockpitViewModel.SortMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation { viewModel.sortMode = mode }
                            }) {
                                HStack {
                                    Text(mode.title(isRTL: isRTL))
                                    if viewModel.sortMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section(header: Text(isRTL ? "عرض الكتالوج" : "View Style")) {
                        Button(action: {
                            withAnimation { viewModel.isCompactView.toggle() }
                        }) {
                            Label(
                                viewModel.isCompactView ? (isRTL ? "عرض بطاقات مريحة" : "Comfortable Cards") : (isRTL ? "عرض مضغوط وسريع" : "Compact Grid"),
                                systemImage: viewModel.isCompactView ? "rectangle.grid.1x2" : "list.bullet"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                        Text(isRTL ? "تصفية" : "Filter")
                            .font(PPFont.bold(12.5, relativeTo: .caption))
                            .foregroundColor(Color(red: 0.20, green: 0.24, blue: 0.30))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.045), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                }
            }

            // Horizontal Omni-Pill Category Ribbon with Live Item Counts
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PPInventoryKind.allCases) { kind in
                        let isSelected = viewModel.selectedKind == kind
                        let kindCount = count(for: kind)

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.selectedKind = kind
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: kind.iconName)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold))

                                Text(kind.title(isRTL: isRTL))
                                    .font(isSelected ? PPFont.bold(13, relativeTo: .subheadline) : PPFont.medium(13, relativeTo: .subheadline))

                                // Item Count Badge inside Pill
                                Text("\(kindCount)")
                                    .font(PPFont.bold(11, relativeTo: .caption2))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.25) : Color(red: 0.92, green: 0.93, blue: 0.95))
                                    .clipShape(Capsule())
                            }
                            .foregroundColor(isSelected ? .white : Color(red: 0.28, green: 0.32, blue: 0.38))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? kind.themeColor : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isSelected ? Color.clear : Color.black.opacity(0.05), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? kind.themeColor.opacity(0.35) : Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 4. Batch Triage Control Bar

    private var batchTriageControlBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if viewModel.selectedItemIDs.count == viewModel.filteredItems.count {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAllFiltered()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedItemIDs.count == viewModel.filteredItems.count ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .semibold))
                    Text(viewModel.selectedItemIDs.count == viewModel.filteredItems.count ? (isRTL ? "إلغاء تحديد الكل" : "Deselect All") : (isRTL ? "تحديد الكل" : "Select All"))
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                }
                .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
            }

            Spacer()

            Text(isRTL ? "تم تحديد: \(viewModel.selectedItemIDs.count)" : "Selected: \(viewModel.selectedItemIDs.count)")
                .font(PPFont.bold(12.5, relativeTo: .caption))
                .foregroundColor(Color(red: 0.30, green: 0.34, blue: 0.40))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 5. The Living Product Stream

    private var productStreamSection: some View {
        LazyVStack(spacing: 12) {
            if viewModel.filteredItems.isEmpty {
                emptyInventoryStateView
            } else {
                ForEach(viewModel.filteredItems) { item in
                    livingProductCard(item: item)
                }
            }
        }
    }

    // MARK: - Living Product Card (Next-Gen V10 Category-Defining Reinvention)

    private func livingProductCard(item: PPInventoryItemModel) -> some View {
        let isSelected = viewModel.selectedItemIDs.contains(item.id)

        return HStack(spacing: 12) {
            // Batch Selection Checkbox (When batch mode is on)
            if viewModel.isBatchMode {
                Button(action: {
                    viewModel.toggleBatchSelect(for: item.id)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? Color(red: 0.88, green: 0.18, blue: 0.38) : Color(red: 0.70, green: 0.74, blue: 0.80))
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Spatial Thumbnail Showcase with Integrated Live Stock Capsule
            ZStack(alignment: .bottom) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(item.kind.themeColor.opacity(0.08))

                    if let imageURL = item.imageURL, let url = URL(string: imageURL), !imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.7)
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipped()
                            case .failure:
                                Image(systemName: item.kind.iconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(item.kind.themeColor.opacity(0.50))
                            @unknown default:
                                Image(systemName: item.kind.iconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(item.kind.themeColor.opacity(0.50))
                            }
                        }
                    } else {
                        Image(systemName: item.kind.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(item.kind.themeColor.opacity(0.50))
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )

                // Stock Health Pill Overlay
                HStack(spacing: 3) {
                    Image(systemName: item.stock <= 0 ? "xmark.circle.fill" : (item.health.requiresUrgentAttention ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                        .font(.system(size: 8, weight: .bold))
                    Text(item.health.label(isRTL: isRTL))
                        .font(PPFont.bold(9.5, relativeTo: .caption2))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(item.health.badgeColor)
                .clipShape(Capsule())
                .padding(.bottom, 6)
                .shadow(color: item.health.badgeColor.opacity(0.40), radius: 4, x: 0, y: 2)
            }
            .frame(width: 90, height: 90)

            // Content & Live Controls
            VStack(alignment: .leading, spacing: 5) {
                // Top Row: Kind Badge & Market Visibility Switch Beacon
                HStack(spacing: 6) {
                    // Kind Badge
                    Text(item.kind.title(isRTL: isRTL))
                        .font(PPFont.bold(10.5, relativeTo: .caption2))
                        .foregroundColor(item.kind.themeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.kind.themeColor.opacity(0.12))
                        .clipShape(Capsule())

                    // Special Clinical / Live Animal Badges
                    if item.isLiveAnimal {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 8))
                            Text(isRTL ? "مفحوص" : "Vet Checked")
                                .font(PPFont.bold(9.5, relativeTo: .caption2))
                        }
                        .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.12))
                        .clipShape(Capsule())
                    } else if item.requiresPrescription {
                        HStack(spacing: 3) {
                            Image(systemName: "cross.vial.fill")
                                .font(.system(size: 8))
                            Text(isRTL ? "وصفة" : "Rx")
                                .font(PPFont.bold(9.5, relativeTo: .caption2))
                        }
                        .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Interactive Market Visibility Beacon (One-tap direct toggle)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.toggleVisibility(for: item.id)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.isListedInApp ? Color(red: 0.05, green: 0.72, blue: 0.50) : Color(red: 0.85, green: 0.55, blue: 0.20))
                                .frame(width: 6.5, height: 6.5)
                            Text(item.isListedInApp ? (isRTL ? "معروض في المتجر" : "Live in Store") : (isRTL ? "مخفي" : "Hidden"))
                                .font(PPFont.bold(10.5, relativeTo: .caption2))
                                .foregroundColor(item.isListedInApp ? Color(red: 0.05, green: 0.60, blue: 0.40) : Color(red: 0.65, green: 0.40, blue: 0.10))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(item.isListedInApp ? Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.12) : Color(red: 0.85, green: 0.55, blue: 0.20).opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(item.isListedInApp ? Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.25) : Color(red: 0.85, green: 0.55, blue: 0.20).opacity(0.25), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Title & Secondary Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRTL ? item.nameAr : item.nameEn)
                        .font(PPFont.bold(15, relativeTo: .headline))
                        .foregroundColor(Color(red: 0.10, green: 0.12, blue: 0.16))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    Text(isRTL ? item.nameEn : item.nameAr)
                        .font(PPFont.regular(12, relativeTo: .caption))
                        .foregroundColor(Color(red: 0.48, green: 0.52, blue: 0.58))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                // Price, Discount & Tactile Mini-Stepper Deck
                HStack(alignment: .center, spacing: 8) {
                    // Price Block
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.0f", item.price))
                            .font(PPFont.bold(18.5, relativeTo: .headline))
                            .foregroundColor(Color(red: 0.08, green: 0.10, blue: 0.14))

                        Text(isRTL ? "ر.ق" : "QAR")
                            .font(PPFont.bold(11, relativeTo: .caption))
                            .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))

                        if let orig = item.originalPrice, orig > item.price {
                            Text(String(format: "%.0f", orig))
                                .font(PPFont.regular(11, relativeTo: .caption2))
                                .foregroundColor(Color(red: 0.65, green: 0.68, blue: 0.72))
                                .strikethrough()

                            if let disc = item.discountPercent {
                                Text("-\(disc)%")
                                    .font(PPFont.bold(9.5, relativeTo: .caption2))
                                    .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.10))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    // Direct Tactile Stock Control: Stepper OR Quick Restock Button
                    if item.stock <= 0 {
                        // Intelligent Quick Restock Button for Out of Stock Items
                        Button(action: {
                            viewModel.quickRestockAdd(for: item.id, count: 10)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(isRTL ? "أضف 10 وحدات" : "+10 Restock")
                                    .font(PPFont.bold(11, relativeTo: .caption))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5.5)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.05, green: 0.72, blue: 0.50),
                                        Color(red: 0.03, green: 0.60, blue: 0.40)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.30), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        // Regular Tactile Stepper
                        HStack(spacing: 2) {
                            // Decrement Button
                            Button(action: {
                                viewModel.adjustStock(for: item.id, delta: -1)
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.35, green: 0.38, blue: 0.44))
                                    .frame(width: 28, height: 28)
                                    .background(Color(red: 0.93, green: 0.94, blue: 0.955))
                                    .clipShape(Circle())
                            }
                            .disabled(item.stock <= 0)

                            // Stock Value Capsule (Tap to enter exact count)
                            Button(action: {
                                viewModel.editingStockItem = item
                            }) {
                                Text("\(item.stock)")
                                    .font(PPFont.bold(13, relativeTo: .subheadline))
                                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))
                                    .frame(minWidth: 30)
                            }

                            // Increment Button
                            Button(action: {
                                viewModel.adjustStock(for: item.id, delta: +1)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                                    .frame(width: 28, height: 28)
                                    .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.12))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(3)
                        .background(Color(red: 0.965, green: 0.968, blue: 0.978))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.04), lineWidth: 0.75)
                        )
                    }

                    // Context Menu for Deep Actions
                    Menu {
                        Button(action: {
                            viewModel.selectedItemForDetails = item
                        }) {
                            Label(isRTL ? "عرض التفاصيل والتحكم" : "View Details & Cockpit", systemImage: "info.circle")
                        }

                        Button(action: {
                            viewModel.toggleActiveOffer(for: item.id)
                        }) {
                            Label(
                                item.hasActiveOffer ? (isRTL ? "إلغاء العرض الترويجي" : "Remove Promo Offer") : (isRTL ? "تطبيق عرض ترويجي" : "Apply Promo Offer"),
                                systemImage: "tag"
                            )
                        }

                        Button(action: {
                            viewModel.duplicateItem(item)
                        }) {
                            Label(isRTL ? "تكرار المنتج" : "Duplicate Item", systemImage: "doc.on.doc")
                        }

                        Button(action: {
                            viewModel.editingStockItem = item
                        }) {
                            Label(isRTL ? "تعديل تفاصيل المخزون" : "Edit Stock Details", systemImage: "slider.horizontal.3")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            viewModel.deleteItem(by: item.id)
                        }) {
                            Label(isRTL ? "حذف من الكتالوج" : "Delete Product", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.50, green: 0.54, blue: 0.60))
                            .frame(width: 28, height: 28)
                            .background(Color(red: 0.95, green: 0.955, blue: 0.965))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Color(red: 0.88, green: 0.18, blue: 0.38) : Color.black.opacity(0.045), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedItemForDetails = item
        }
        .swipeActions(edge: isRTL ? .leading : .trailing) {
            Button(role: .destructive) {
                viewModel.deleteItem(by: item.id)
            } label: {
                Label(isRTL ? "حذف" : "Delete", systemImage: "trash")
            }

            Button {
                viewModel.duplicateItem(item)
            } label: {
                Label(isRTL ? "تكرار" : "Duplicate", systemImage: "doc.on.doc")
            }
            .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
        }
        .swipeActions(edge: isRTL ? .trailing : .leading) {
            Button {
                viewModel.quickRestockAdd(for: item.id, count: 10)
            } label: {
                Label(isRTL ? "+10 مخزون" : "+10 Stock", systemImage: "plus.circle")
            }
            .tint(Color(red: 0.05, green: 0.72, blue: 0.50))
        }
    }

    // MARK: - 6. Empty State View

    private var emptyInventoryStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)

                Image(systemName: "tray.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.8))
            }
            .padding(.top, 40)

            VStack(spacing: 6) {
                Text(isRTL ? "لا توجد عناصر مطابقة" : "No Matching Products")
                    .font(PPFont.bold(18, relativeTo: .title3))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))

                Text(isRTL ? "جرّب تغيير كلمات البحث أو إعادة ضبط الفلاتر لتصفح كتالوجك" : "Try adjusting your search terms or reset the active filter")
                    .font(PPFont.regular(13, relativeTo: .body))
                    .foregroundColor(Color(red: 0.48, green: 0.52, blue: 0.58))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                withAnimation {
                    viewModel.searchText = ""
                    viewModel.selectedKind = .all
                    viewModel.activeFilterMetric = .all
                }
            }) {
                Text(isRTL ? "إعادة ضبط الفلاتر" : "Reset All Filters")
                    .font(PPFont.bold(13, relativeTo: .subheadline))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.88, green: 0.18, blue: 0.38))
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 7. Floating Toast Banner

    private func floatingToastBanner(text: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))

                Text(text)
                    .font(PPFont.bold(13, relativeTo: .subheadline))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.12, green: 0.15, blue: 0.20).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - 8. Floating Batch Dock

    private var floatingBatchDock: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isRTL ? "\(viewModel.selectedItemIDs.count) عناصر محددة" : "\(viewModel.selectedItemIDs.count) items selected")
                    .font(PPFont.bold(13, relativeTo: .subheadline))
                    .foregroundColor(.white)
                Text(isRTL ? "إجراءات جماعية فورية" : "Instant Batch Triage")
                    .font(PPFont.regular(10.5, relativeTo: .caption2))
                    .foregroundColor(Color.white.opacity(0.7))
            }

            Spacer()

            // Bulk Visibility Toggle
            Button(action: {
                viewModel.bulkSetVisibility(listed: true)
            }) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .accessibilityLabel(isRTL ? "إظهار الكل" : "Show All")

            // Bulk Restock (+10)
            Button(action: {
                viewModel.bulkRestock(addUnits: 10)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("10")
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Color(red: 0.05, green: 0.72, blue: 0.50))
                .clipShape(Capsule())
            }
            .accessibilityLabel(isRTL ? "إضافة 10 وحدات" : "Add 10 units")

            // Bulk Delete
            Button(action: {
                viewModel.bulkDelete()
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color(red: 0.90, green: 0.20, blue: 0.30))
                    .clipShape(Circle())
            }
            .accessibilityLabel(isRTL ? "حذف المحدد" : "Delete Selected")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 9. Quick Stock Stepper Sheet

    private func quickStockStepperSheet(item: PPInventoryItemModel) -> some View {
        QuickStockModalSheet(
            item: item,
            isRTL: isRTL,
            onSave: { newStock in
                viewModel.setExactStock(for: item.id, newStock: newStock)
                viewModel.editingStockItem = nil
            },
            onDismiss: {
                viewModel.editingStockItem = nil
            }
        )
        .presentationDetents([.height(370)])
        .presentationCornerRadius(28)
    }
}

// MARK: - Quick Stock Modal Sheet Component

public struct QuickStockModalSheet: View {
    public let item: PPInventoryItemModel
    public let isRTL: Bool
    public let onSave: (Int) -> Void
    public let onDismiss: () -> Void

    @State private var currentStock: Int

    public init(item: PPInventoryItemModel, isRTL: Bool, onSave: @escaping (Int) -> Void, onDismiss: @escaping () -> Void) {
        self.item = item
        self.isRTL = isRTL
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._currentStock = State(initialValue: item.stock)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Sheet Grabber & Header
            VStack(spacing: 6) {
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                Text(isRTL ? "تعديل كمية المخزون" : "Adjust Inventory Count")
                    .font(PPFont.bold(16, relativeTo: .headline))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))

                Text(isRTL ? item.nameAr : item.nameEn)
                    .font(PPFont.regular(13, relativeTo: .caption))
                    .foregroundColor(Color(red: 0.50, green: 0.54, blue: 0.60))
                    .lineLimit(1)
            }

            // Tactile Big Stepper Display
            HStack(spacing: 24) {
                Button(action: {
                    if currentStock > 0 { currentStock -= 1 }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.35, green: 0.38, blue: 0.44))
                        .frame(width: 52, height: 52)
                        .background(Color(red: 0.94, green: 0.945, blue: 0.96))
                        .clipShape(Circle())
                }
                .disabled(currentStock <= 0)

                VStack(spacing: 2) {
                    Text("\(currentStock)")
                        .font(PPFont.bold(44, relativeTo: .largeTitle))
                        .foregroundColor(Color(red: 0.10, green: 0.12, blue: 0.15))

                    Text(isRTL ? "وحدات متوفرة" : "Units in Stock")
                        .font(PPFont.medium(11, relativeTo: .caption))
                        .foregroundColor(Color(red: 0.52, green: 0.55, blue: 0.62))
                }
                .frame(minWidth: 100)

                Button(action: {
                    currentStock += 1
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                        .frame(width: 52, height: 52)
                        .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.12))
                        .clipShape(Circle())
                }
            }

            // Quick Add Preset Pills
            HStack(spacing: 8) {
                ForEach([5, 10, 25, 50, 100], id: \.self) { delta in
                    Button(action: {
                        currentStock += delta
                    }) {
                        Text("+\(delta)")
                            .font(PPFont.bold(12, relativeTo: .caption))
                            .foregroundColor(Color(red: 0.88, green: 0.18, blue: 0.38))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.88, green: 0.18, blue: 0.38).opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                // Zero Reset
                Button(action: {
                    currentStock = 0
                }) {
                    Text("0")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(red: 0.85, green: 0.20, blue: 0.25))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.85, green: 0.20, blue: 0.25).opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            // Save / Confirm Button
            Button(action: {
                onSave(currentStock)
            }) {
                Text(isRTL ? "حفظ التغييرات ومزامنة الكتالوج" : "Save Changes & Sync Catalog")
                    .font(PPFont.bold(15, relativeTo: .headline))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.94, green: 0.22, blue: 0.42), Color(red: 0.82, green: 0.10, blue: 0.32)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color(red: 0.94, green: 0.22, blue: 0.42).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Smart Barcode Scanner Simulation HUD

public struct SmartBarcodeScannerSheet: View {
    public let isRTL: Bool
    public let onScannedCode: (String) -> Void
    public let onDismiss: () -> Void

    @State private var scanLineY: CGFloat = -100

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(isRTL ? "ماسح الباركود السريع" : "Quick Barcode Scanner")
                        .font(PPFont.bold(17, relativeTo: .headline))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Viewfinder Reticle
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(red: 0.05, green: 0.72, blue: 0.50), lineWidth: 3)
                        .frame(width: 260, height: 260)

                    // Laser Sweep Line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color(red: 0.05, green: 0.72, blue: 0.50), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 250, height: 3)
                        .offset(y: scanLineY)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanLineY = 100
                            }
                        }
                }

                Text(isRTL ? "وجّه الكاميرا نحو باركود المنتج لمسحه فوراً" : "Align camera with product barcode to scan")
                    .font(PPFont.medium(13, relativeTo: .caption))
                    .foregroundColor(Color.white.opacity(0.75))

                Spacer()

                // Simulation Shortcuts
                VStack(spacing: 10) {
                    Text(isRTL ? "محاكاة الرموز السريعة للتجربة:" : "Quick Barcode Presets:")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color.white.opacity(0.6))

                    HStack(spacing: 12) {
                        Button(action: {
                            onScannedCode("629110023451")
                        }) {
                            Text("Cerelac A21")
                                .font(PPFont.bold(12, relativeTo: .caption))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }

                        Button(action: {
                            onScannedCode("3182550770542")
                        }) {
                            Text("Royal Canin")
                                .font(PPFont.bold(12, relativeTo: .caption))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.height(520)])
        .presentationCornerRadius(30)
    }
}

// MARK: - Branch Location Picker Modal Sheet

public struct BranchPickerModalSheet: View {
    public let currentBranchAr: String
    public let currentBranchEn: String
    public let isRTL: Bool
    public let onSelectBranch: (String, String) -> Void
    public let onDismiss: () -> Void

    private let branches: [(String, String, String)] = [
        ("فرع الدوحة الرئيسي", "Doha Main Branch", "شارع الوعب التجاري، مبنى 14"),
        ("فرع اللؤلؤة مارينا", "The Pearl Marina Branch", "بورتو أرابيا، برج 22"),
        ("فرع لوسيل السكني", "Lusail City Branch", "شارع المقاهي، مارينا لوسيل"),
        ("فرع الوكرة للعناية", "Al Wakrah Care Center", "طريق الوكرة العام، مجمع 4")
    ]

    public var body: some View {
        VStack(spacing: 20) {
            // Grabber
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Text(isRTL ? "اختيار فرع المتجر النشط" : "Select Active Store Branch")
                .font(PPFont.bold(17, relativeTo: .headline))
                .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))

            VStack(spacing: 10) {
                ForEach(branches, id: \.1) { ar, en, address in
                    let isCurrent = (ar == currentBranchAr)

                    Button(action: {
                        onSelectBranch(ar, en)
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isCurrent ? Color(red: 0.05, green: 0.72, blue: 0.50) : Color(red: 0.94, green: 0.945, blue: 0.96))
                                    .frame(width: 38, height: 38)

                                Image(systemName: "storefront.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(isCurrent ? .white : Color(red: 0.40, green: 0.44, blue: 0.50))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isRTL ? ar : en)
                                    .font(PPFont.bold(14.5, relativeTo: .subheadline))
                                    .foregroundColor(Color(red: 0.10, green: 0.12, blue: 0.16))

                                Text(address)
                                    .font(PPFont.regular(11.5, relativeTo: .caption))
                                    .foregroundColor(Color(red: 0.50, green: 0.54, blue: 0.60))
                            }

                            Spacer()

                            if isCurrent {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.05, green: 0.72, blue: 0.50))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isCurrent ? Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.08) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isCurrent ? Color(red: 0.05, green: 0.72, blue: 0.50).opacity(0.3) : Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.height(390)])
        .presentationCornerRadius(28)
    }
}

// MARK: - Scale Button Style Helper

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - UIKit Objective-C Hosting Bridge

@objc(PPProviderMarketInventoryHostingController)
public final class PPProviderMarketInventoryHostingController: UIViewController {
    private var viewModel = PPInventoryCockpitViewModel()
    private var hostingController: UIHostingController<PPProviderMarketInventoryView>?

    @objc public var onAddProductRequested: (() -> Void)? = nil

    @objc public func updateWithItems(_ marketItems: [PPProviderMarketItem]) {
        self.viewModel.updateFromMarketItems(marketItems)
    }

    @objc public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 0.965, green: 0.968, blue: 0.975, alpha: 1.0)

        var inventoryView = PPProviderMarketInventoryView(viewModel: self.viewModel)
        inventoryView.onDismiss = { [weak self] in
            if let nav = self?.navigationController {
                nav.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true, completion: nil)
            }
        }
        inventoryView.onAddProduct = { [weak self] in
            self?.onAddProductRequested?()
        }
        let host = UIHostingController(rootView: inventoryView)
        self.hostingController = host

        self.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }
}
