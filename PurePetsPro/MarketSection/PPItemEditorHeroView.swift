//
//  PPItemEditorHeroView.swift
//  PurePetsPro
//
//  First-Principles Invention: Category-Defining Marketplace Product Studio (SwiftyMax NextGen V9).
//  Reinvented from absolute first principles in SwiftUI separately for iPhone & iPad:
//  - Live 1:1 Holographic Customer Storefront Simulator (mirrors Qatar consumer app)
//  - Multi-Angle Visual Media Studio (5-slot filmstrip with primary cover halo & completion ring)
//  - High-Contrast Bilingual Identity Deck (Arabic Primary 🇶🇦 / English Secondary 🇬🇧)
//  - Intelligent Description Workshop with smart creative snippet injection
//  - Real-time Pricing & Promotional Economics Engine (QAR calculations & discount preview)
//  - Tactile Inventory Stock Stepper with rapid multiplier chips
//  - Animal Species & Category Horizon (Dogs, Cats, Birds, Small Pets, Aquatic, Horses)
//  - Variant Matrix Studio Doorway (Multi-axis combinations & PPAccessoryVariantStudioHostController)
//  - Storefront Catalog Visibility & Delivery Radar
//  - Full RTL/LTR localization, Dynamic Type, accessibility traits, and reduce-motion resilience.
//

import SwiftUI
import UIKit
import PhotosUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

// MARK: - Species Catalog Item

public struct PPMarketSpeciesItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let emoji: String
    public let titleAr: String
    public let titleEn: String

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }
}

public enum PPMarketSpeciesCatalog {
    public static let items: [PPMarketSpeciesItem] = [
        PPMarketSpeciesItem(id: 1, emoji: "🐶", titleAr: "الكلاب", titleEn: "Dogs"),
        PPMarketSpeciesItem(id: 2, emoji: "🐱", titleAr: "القطط", titleEn: "Cats"),
        PPMarketSpeciesItem(id: 3, emoji: "🦜", titleAr: "الطيور", titleEn: "Birds"),
        PPMarketSpeciesItem(id: 4, emoji: "🐰", titleAr: "الأرانب والقوارض", titleEn: "Small Pets"),
        PPMarketSpeciesItem(id: 5, emoji: "🐠", titleAr: "الأسماك والبحريات", titleEn: "Aquatics"),
        PPMarketSpeciesItem(id: 6, emoji: "🐎", titleAr: "الخيول والفروسية", titleEn: "Equine")
    ]
}

// MARK: - Enums for Form Options

public enum PPProductAccessKind: Int, CaseIterable, Identifiable {
    case accessory = 1
    case food = 2

    public var id: Int { rawValue }

    public var titleAr: String {
        switch self {
        case .accessory: return "مستلزمات وإكسسوارات"
        case .food: return "أطعمة وتغذية علاجية"
        }
    }

    public var titleEn: String {
        switch self {
        case .accessory: return "Accessories & Gear"
        case .food: return "Food & Nutrition"
        }
    }

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }

    public var symbol: String {
        switch self {
        case .accessory: return "bag.fill"
        case .food: return "fork.knife"
        }
    }
}

public enum PPDiscountType: String, CaseIterable, Identifiable {
    case percent = "percent"
    case fixed = "fixed"

    public var id: String { rawValue }

    public var titleAr: String {
        switch self {
        case .percent: return "نسبة مئوية (%)"
        case .fixed: return "خصم نقدي (ر.ق)"
        }
    }

    public var titleEn: String {
        switch self {
        case .percent: return "Percentage (%)"
        case .fixed: return "Fixed (QAR)"
        }
    }

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }
}

// MARK: - Main Sovereign Marketplace Product Studio Screen

public struct PPProviderMarketItemStudioScreen: View {
    public let itemToEdit: PPProviderMarketItem?
    public let initialAccessKindType: Int
    public let onDismiss: () -> Void
    public let onSaved: () -> Void

    // Product Core Attributes
    @State private var nameAr: String = ""
    @State private var nameEn: String = ""
    @State private var descAr: String = ""
    @State private var descEn: String = ""
    @State private var activeDescLangIsArabic: Bool = true

    // Commercial & Financials
    @State private var priceString: String = ""
    @State private var wholesalePriceString: String = ""
    @State private var quantity: Int = 10
    @State private var sku: String = ""
    @State private var barcode: String = ""

    // Promotion & Offers
    @State private var hasOffer: Bool = false
    @State private var discountType: PPDiscountType = .percent
    @State private var discountPercentString: String = ""
    @State private var discountAmountString: String = ""

    // Classification & Pet Matrix
    @State private var accessKindType: PPProductAccessKind = .accessory
    @State private var selectedSpeciesID: Int = 1
    @State private var selectedSpeciesName: String = "الكلاب"
    @State private var selectedSubCategoryID: Int = 0

    // Marketplace Catalog Visibility
    @State private var showInAppMarket: Bool = true
    @State private var isAvailable: Bool = true

    // Visual Media Gallery (Up to 5 images)
    @State private var cloudImageURLs: [String] = []
    @State private var localImages: [UIImage] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker: Bool = false
    @State private var showCameraPicker: Bool = false

    // Variant Family Integration
    @State private var belongsToVariantFamily: Bool = false
    @State private var variantFamilyID: String = ""
    @State private var variantCombinationLabel: String = ""

    // Persistence & Feedback
    @State private var isSaving: Bool = false
    @State private var savingStatusMessage: String = ""
    @State private var errorMessage: String? = nil
    @State private var pulseBeacon: Bool = false
    @State private var showDiscardAlert: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEditing: Bool { itemToEdit != nil }

    // Design Tokens
    private var primaryBrandPink: Color {
        Color(red: 0.88, green: 0.12, blue: 0.38)
    }

    private var primaryAccent: Color {
        Color(red: 0.08, green: 0.72, blue: 0.65)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.14)
            : Color(UIColor.systemBackground)
    }

    private var canvasBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.08)
            : Color(UIColor.systemGroupedBackground)
    }

    private var surfaceBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.16, blue: 0.18)
            : Color(UIColor.secondarySystemGroupedBackground)
    }

    private var hairlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    // MARK: - Initializer & Seed

    public init(
        itemToEdit: PPProviderMarketItem?,
        initialAccessKindType: Int = 1,
        onDismiss: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.itemToEdit = itemToEdit
        self.initialAccessKindType = initialAccessKindType
        self.onDismiss = onDismiss
        self.onSaved = onSaved
    }

    // MARK: - Body Root

    public var body: some View {
        ZStack {
            canvasBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeaderBar

                if horizontalSizeClass == .regular {
                    padPanoramicCockpit
                } else {
                    phoneErgonomicFlow
                }

                catalystActionDock
            }

            if isSaving {
                savingHUDOverlay
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoPickerItems,
            maxSelectionCount: max(1, 5 - (cloudImageURLs.count + localImages.count)),
            matching: .images
        )
        .onChange(of: photoPickerItems) { newItems in
            handlePhotoPickerSelection(newItems)
        }
        .alert(isPresented: $showDiscardAlert) {
            Alert(
                title: Text(Language.isRTL() ? "تجاهل التغييرات؟" : "Discard Changes?"),
                message: Text(Language.isRTL() ? "لديك تعديلات غير محفوظة، هل أنت متأكد من الخروج؟" : "You have unsaved changes. Are you sure you want to discard them?"),
                primaryButton: .destructive(Text(Language.isRTL() ? "تجاهل وخروج" : "Discard"), action: onDismiss),
                secondaryButton: .cancel(Text(Language.isRTL() ? "متابعة التعديل" : "Keep Editing"))
            )
        }
        .onAppear {
            PPBrandFont.registerIfNeeded()
            seedFormFromItem()
        }
    }

    // MARK: - Seed Data

    private func seedFormFromItem() {
        if let item = itemToEdit {
            nameAr = item.name
            nameEn = item.nameEn ?? ""
            descAr = item.desc
            descEn = item.descEn ?? ""
            priceString = item.price > 0 ? String(format: "%.0f", item.price) : ""
            quantity = item.quantity >= 0 ? item.quantity : 10
            sku = item.sku ?? ""
            barcode = item.barcode ?? ""

            let wpVal = item.wholesalePrice?.doubleValue ?? 0
            if wpVal > 0 {
                wholesalePriceString = String(format: "%.0f", wpVal)
            }

            let dpVal = item.discountPercent?.doubleValue ?? 0
            let daVal = item.discountAmount?.doubleValue ?? 0
            if dpVal > 0 {
                hasOffer = true
                discountType = .percent
                discountPercentString = String(format: "%.0f", dpVal)
            } else if daVal > 0 {
                hasOffer = true
                discountType = .fixed
                discountAmountString = String(format: "%.0f", daVal)
            } else {
                hasOffer = item.hasOffer
            }

            accessKindType = PPProductAccessKind(rawValue: item.accessKindType) ?? .accessory
            selectedSpeciesID = item.petMainCategoryID > 0 ? item.petMainCategoryID : 1
            selectedSpeciesName = item.petMainCategoryName ?? "الكلاب"
            selectedSubCategoryID = item.petSubCategoryID

            showInAppMarket = item.showInAppMarket
            isAvailable = !item.noStock

            cloudImageURLs = item.imageURLsArray
            belongsToVariantFamily = item.belongsToVariantFamily
            variantFamilyID = item.productFamilyId ?? ""
            variantCombinationLabel = item.variantOptionLabel
        } else {
            accessKindType = PPProductAccessKind(rawValue: initialAccessKindType) ?? .accessory
            showInAppMarket = true
            isAvailable = true
            quantity = 15
        }
    }

    // MARK: - Navigation Header Bar

    private var navigationHeaderBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if hasUnsavedEdits {
                    showDiscardAlert = true
                } else {
                    onDismiss()
                }
            }) {
                Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: 40, height: 40)
                    .background(surfaceBackground, in: Circle())
                    .overlay(Circle().strokeBorder(hairlineColor, lineWidth: 0.75))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isEditing
                         ? (Language.isRTL() ? "تعديل منتج في السوق" : "Edit Market Item")
                         : (Language.isRTL() ? "إضافة منتج للسوق" : "Add Market Item")
                    )
                    .font(PPFont.bold(18, relativeTo: .title3))
                    .foregroundStyle(Color(UIColor.label))

                    // Live Status Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(Language.isRTL() ? "معروض بالسوق" : "Market Live")
                            .font(PPFont.bold(10.5, relativeTo: .caption2))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }

                Text(Language.isRTL()
                     ? "حافظ على دقة السجل، هذه التفاصيل تغذي عنصر السوق المباشر"
                     : "Ensure catalog accuracy; live details power instant consumer orders")
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            // Completion Telemetry Ring
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(hairlineColor, lineWidth: 2.5)
                        .frame(width: 22, height: 22)
                    Circle()
                        .trim(from: 0, to: CGFloat(completionProgress))
                        .stroke(primaryBrandPink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                }
                Text("\(Int(completionProgress * 100))%")
                    .font(PPFont.bold(11, relativeTo: .caption2))
                    .foregroundStyle(primaryBrandPink)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(primaryBrandPink.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(surfaceBackground)
        .overlay(Divider().overlay(hairlineColor), alignment: .bottom)
    }

    // MARK: - Phone Ergonomic Flow

    private var phoneErgonomicFlow: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                if let err = errorMessage {
                    errorBanner(err)
                }

                // 1. Live 1:1 Holographic Customer Storefront Card
                holographicCustomerPreviewCard

                // 2. Multi-Angle Visual Media Studio (5 photos)
                visualMediaStudioDeck

                // 3. Bilingual Brand Identity Deck
                bilingualIdentityDeck

                // 4. Description Workshop Deck
                descriptionWorkshopDeck

                // 5. Commercial Pricing & Economics Studio
                financialsEconomicsDeck

                // 6. Inventory & Warehouse Tracking
                inventoryWarehouseDeck

                // 7. Animal Species & Category Horizon
                speciesTargetDeck

                // 8. Variant Matrix Studio Gateway
                variantMatrixGatewayCard

                // 9. Marketplace Catalog Visibility & Status
                marketplaceVisibilityDeck

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    // MARK: - iPad Panoramic Cockpit

    private var padPanoramicCockpit: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Holographic Preview, Photos, Readiness
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    holographicCustomerPreviewCard
                    visualMediaStudioDeck
                    marketplaceVisibilityDeck
                    variantMatrixGatewayCard
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(width: 380)

            // Right Column: Form Configuration Decks
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if let err = errorMessage {
                        errorBanner(err)
                    }

                    bilingualIdentityDeck
                    descriptionWorkshopDeck
                    financialsEconomicsDeck
                    inventoryWarehouseDeck
                    speciesTargetDeck

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 1. Live Holographic Customer Storefront Simulator

    private var holographicCustomerPreviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Tag
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(Language.isRTL() ? "محاكاة العرض المباشر للعميل في قطر" : "Live Qatar Consumer Preview")
                        .font(PPFont.bold(11, relativeTo: .caption2))
                }
                .foregroundStyle(primaryAccent)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(quantity > 0 ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(quantity > 0
                         ? (Language.isRTL() ? "متوفر بالمخزون" : "In Stock")
                         : (Language.isRTL() ? "نفذ من المخزون" : "Out of Stock")
                    )
                    .font(PPFont.bold(10.5, relativeTo: .caption2))
                    .foregroundStyle(quantity > 0 ? Color.green : Color.red)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((quantity > 0 ? Color.green : Color.red).opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Media Hero Showcase
            ZStack(alignment: .topTrailing) {
                if let primaryLocal = localImages.first {
                    Image(uiImage: primaryLocal)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 168)
                        .clipped()
                } else if let primaryUrlStr = cloudImageURLs.first, let url = URL(string: primaryUrlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholderHeroCover
                        }
                    }
                    .frame(height: 168)
                    .clipped()
                } else {
                    placeholderHeroCover
                }

                // Discount Ribbon
                if hasOffer && calculatedDiscountPercentage > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .black))
                        Text("-\(Int(calculatedDiscountPercentage))%")
                            .font(PPFont.bold(11, relativeTo: .caption2))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(primaryBrandPink, in: Capsule())
                    .shadow(color: primaryBrandPink.opacity(0.4), radius: 4, y: 2)
                    .padding(10)
                }

                // Total Images Pill
                let totalPhotos = cloudImageURLs.count + localImages.count
                if totalPhotos > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                        Text("\(totalPhotos)")
                            .font(PPFont.bold(10, relativeTo: .caption2))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(10)
                }
            }
            .frame(height: 168)

            // Details Deck
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Category & Species Pill
                        HStack(spacing: 5) {
                            Text(accessKindType.localizedTitle)
                                .font(PPFont.bold(10.5, relativeTo: .caption2))
                                .foregroundStyle(primaryAccent)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))

                            Text("\(selectedSpeciesEmoji) \(selectedSpeciesLocalizedName)")
                                .font(PPFont.medium(10.5, relativeTo: .caption2))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }

                        // Product Title
                        Text(nameAr.isEmpty ? (Language.isRTL() ? "اسم المنتج التجاري..." : "Product Commercial Title...") : nameAr)
                            .font(PPFont.bold(15, relativeTo: .headline))
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(2)

                        if !nameEn.isEmpty {
                            Text(nameEn)
                                .font(PPFont.regular(12, relativeTo: .caption))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Pricing Column
                    VStack(alignment: .trailing, spacing: 1) {
                        if hasOffer && computedFinalPrice < (Double(priceString) ?? 0) {
                            Text("\(priceString) QAR")
                                .font(PPFont.regular(11, relativeTo: .caption2))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                                .strikethrough()

                            Text(String(format: "%.0f", computedFinalPrice))
                                .font(PPFont.bold(18, relativeTo: .title3))
                                .foregroundStyle(primaryBrandPink)

                            Text(Language.get("QAR", alter: "ر.ق QAR"))
                                .font(PPFont.bold(10, relativeTo: .caption2))
                                .foregroundStyle(primaryBrandPink)
                        } else {
                            Text(priceString.isEmpty ? "0" : priceString)
                                .font(PPFont.bold(18, relativeTo: .title3))
                                .foregroundStyle(Color(UIColor.label))

                            Text(Language.get("QAR", alter: "ر.ق QAR"))
                                .font(PPFont.bold(10, relativeTo: .caption2))
                                .foregroundStyle(primaryAccent)
                        }
                    }
                }
            }
            .padding(14)
            .background(surfaceBackground)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [primaryAccent.opacity(0.35), hairlineColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 14, y: 4)
    }

    private var placeholderHeroCover: some View {
        ZStack {
            LinearGradient(
                colors: [
                    primaryAccent.opacity(0.12),
                    primaryBrandPink.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: accessKindType.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(primaryAccent.opacity(0.7))
                Text(Language.isRTL() ? "انقر أدناه لإضافة صور للمنتج" : "Tap below to add product imagery")
                    .font(PPFont.medium(11, relativeTo: .caption2))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }
        }
        .frame(height: 168)
    }

    // MARK: - 2. Multi-Angle Visual Media Studio (5 photos)

    private var visualMediaStudioDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader(
                    title: Language.isRTL() ? "معرض صور المنتج (٥ صور كحد أقصى)" : "Product Visual Media Studio",
                    subtitle: Language.isRTL() ? "الصورة الأولى هي الغلاف الرئيسي في بطاقة العرض" : "First image acts as primary storefront cover",
                    symbol: "photo.stack.fill"
                )

                Spacer()

                // Progress Badge
                let total = cloudImageURLs.count + localImages.count
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 11))
                    Text("\(total)/5")
                        .font(PPFont.bold(11, relativeTo: .caption2))
                }
                .foregroundStyle(primaryBrandPink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(primaryBrandPink.opacity(0.10), in: Capsule())
            }

            // Photos Filmstrip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 1. Add Image Slot Button
                    if (cloudImageURLs.count + localImages.count) < 5 {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showPhotoPicker = true
                        }) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(primaryBrandPink.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "camera.badge.ellipsis")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(primaryBrandPink)
                                }

                                Text(Language.isRTL() ? "إضافة صورة" : "Add Image")
                                    .font(PPFont.bold(11, relativeTo: .caption2))
                                    .foregroundStyle(primaryBrandPink)
                            }
                            .frame(width: 96, height: 104)
                            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(primaryBrandPink.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // 2. Local Images
                    ForEach(Array(localImages.enumerated()), id: \.offset) { index, image in
                        photoThumbnailCard(
                            image: image,
                            isPrimary: (index == 0 && cloudImageURLs.isEmpty),
                            onDelete: {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                                    localImages.remove(at: index)
                                }
                            }
                        )
                    }

                    // 3. Existing Cloud URLs
                    ForEach(Array(cloudImageURLs.enumerated()), id: \.offset) { index, urlString in
                        cloudPhotoThumbnailCard(
                            urlString: urlString,
                            isPrimary: (index == 0),
                            onDelete: {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                                    cloudImageURLs.remove(at: index)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func photoThumbnailCard(image: UIImage, isPrimary: Bool, onDelete: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if isPrimary {
                Text(Language.isRTL() ? "غلاف" : "Cover")
                    .font(PPFont.bold(9, relativeTo: .caption2))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(primaryBrandPink, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onDelete()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.65))
            }
            .padding(4)
        }
        .frame(width: 96, height: 104)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isPrimary ? primaryBrandPink : hairlineColor, lineWidth: isPrimary ? 2 : 0.75)
        )
    }

    private func cloudPhotoThumbnailCard(urlString: String, isPrimary: Bool, onDelete: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 96, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if isPrimary {
                Text(Language.isRTL() ? "غلاف" : "Cover")
                    .font(PPFont.bold(9, relativeTo: .caption2))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(primaryBrandPink, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onDelete()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.65))
            }
            .padding(4)
        }
        .frame(width: 96, height: 104)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isPrimary ? primaryBrandPink : hairlineColor, lineWidth: isPrimary ? 2 : 0.75)
        )
    }

    // MARK: - 3. Bilingual Brand Identity Deck

    private var bilingualIdentityDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "الأسماء والهوية التجارية للمنتج" : "Bilingual Product Identity",
                subtitle: Language.isRTL() ? "الاسم التجاري المعتمد لبطاقة العرض بالسوق" : "Official bilingual names for the marketplace catalog",
                symbol: "tag.fill"
            )

            // Arabic Name (Required)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "الاسم باللغة العربية" : "Arabic Product Name")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Text("*")
                        .font(PPFont.bold(13))
                        .foregroundStyle(primaryBrandPink)
                    Spacer()
                    Text("🇶🇦")
                        .font(.system(size: 14))
                }

                HStack(spacing: 10) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField(
                        Language.isRTL() ? "مثال: طوق جلدي فاخر للكلاب مع مقود" : "e.g. Luxury Leather Dog Collar",
                        text: $nameAr
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))

                    if !nameAr.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.green)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(nameAr.isEmpty ? hairlineColor : primaryAccent.opacity(0.4), lineWidth: 0.75))
            }

            // English Name (Optional)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "الاسم باللغة الإنجليزية (اختياري)" : "English Product Name (Optional)")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Spacer()
                    Text("🇬🇧")
                        .font(.system(size: 14))
                }

                HStack(spacing: 10) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField(
                        "e.g. Premium Leather Dog Collar & Leash",
                        text: $nameEn
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))
                    .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 4. Description Workshop Deck

    private var descriptionWorkshopDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "الوصف ومواصفات المنتج" : "Product Narrative & Specifications",
                subtitle: Language.isRTL() ? "اشرح المنتج، الاستخدام، المقاسات، وأي تفاصيل مهمة للعميل" : "Detail dimensions, usage directions, materials, and highlights",
                symbol: "doc.text.fill"
            )

            // Language Selector Pill
            HStack(spacing: 8) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    activeDescLangIsArabic = true
                }) {
                    HStack(spacing: 4) {
                        Text("🇶🇦")
                        Text(Language.isRTL() ? "العربية" : "Arabic")
                            .font(PPFont.bold(12, relativeTo: .caption))
                    }
                    .foregroundStyle(activeDescLangIsArabic ? primaryBrandPink : Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        activeDescLangIsArabic ? primaryBrandPink.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground),
                        in: Capsule()
                    )
                    .overlay(Capsule().strokeBorder(activeDescLangIsArabic ? primaryBrandPink : hairlineColor, lineWidth: 0.75))
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    activeDescLangIsArabic = false
                }) {
                    HStack(spacing: 4) {
                        Text("🇬🇧")
                        Text(Language.isRTL() ? "الإنجليزية" : "English")
                            .font(PPFont.bold(12, relativeTo: .caption))
                    }
                    .foregroundStyle(!activeDescLangIsArabic ? primaryBrandPink : Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        !activeDescLangIsArabic ? primaryBrandPink.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground),
                        in: Capsule()
                    )
                    .overlay(Capsule().strokeBorder(!activeDescLangIsArabic ? primaryBrandPink : hairlineColor, lineWidth: 0.75))
                }
            }

            // Quick Insertion Snippet Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPromptChip(
                        title: Language.isRTL() ? "+ طريقة الاستخدام 📋" : "+ Usage Instructions 📋",
                        snippet: activeDescLangIsArabic ? "\n• طريقة الاستخدام: " : "\n• How to use: "
                    )
                    quickPromptChip(
                        title: Language.isRTL() ? "+ المميزات الرئيسية ✨" : "+ Key Highlights ✨",
                        snippet: activeDescLangIsArabic ? "\n• المميزات الرئيسية: " : "\n• Key Highlights: "
                    )
                    quickPromptChip(
                        title: Language.isRTL() ? "+ المكونات والمواد 🔬" : "+ Materials & Ingredients 🔬",
                        snippet: activeDescLangIsArabic ? "\n• المكونات والمواد: " : "\n• Materials & Ingredients: "
                    )
                    quickPromptChip(
                        title: Language.isRTL() ? "+ المقاسات والأبعاد 📏" : "+ Dimensions & Sizes 📏",
                        snippet: activeDescLangIsArabic ? "\n• المقاسات والأبعاد: " : "\n• Dimensions & Sizes: "
                    )
                    quickPromptChip(
                        title: Language.isRTL() ? "+ التخزين والصلاحية ❄️" : "+ Storage & Care ❄️",
                        snippet: activeDescLangIsArabic ? "\n• إرشادات الحفظ والتخزين: " : "\n• Storage instructions: "
                    )
                }
            }

            // Text Editor
            ZStack(alignment: .topLeading) {
                let currentText = activeDescLangIsArabic ? descAr : descEn
                if currentText.isEmpty {
                    Text(activeDescLangIsArabic
                         ? "اكتب تفاصيل المنتج، مميزاته، الفئات المناسبة له، وكيفية الاستخدام..."
                         : "Enter product specifications, suitability, and benefits..."
                    )
                    .font(PPFont.regular(13.5, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                if activeDescLangIsArabic {
                    TextEditor(text: $descAr)
                        .font(PPFont.medium(14, relativeTo: .body))
                        .foregroundStyle(Color(UIColor.label))
                        .frame(minHeight: 110)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                } else {
                    TextEditor(text: $descEn)
                        .font(PPFont.medium(14, relativeTo: .body))
                        .foregroundStyle(Color(UIColor.label))
                        .frame(minHeight: 110)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))

            // Character Counter
            HStack {
                Spacer()
                let count = (activeDescLangIsArabic ? descAr : descEn).count
                Text("\(count) / 1000")
                    .font(PPFont.medium(11, relativeTo: .caption2))
                    .foregroundStyle(count > 1000 ? Color.red : Color(UIColor.secondaryLabel))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func quickPromptChip(title: String, snippet: String) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if activeDescLangIsArabic {
                descAr = descAr.trimmingCharacters(in: .whitespaces) + snippet
            } else {
                descEn = descEn.trimmingCharacters(in: .whitespaces) + snippet
            }
        }) {
            Text(title)
                .font(PPFont.bold(11, relativeTo: .caption2))
                .foregroundStyle(primaryAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(primaryAccent.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(primaryAccent.opacity(0.25), lineWidth: 0.75))
        }
    }

    // MARK: - 5. Commercial Pricing & Economics Studio

    private var financialsEconomicsDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "التسعير والعروض الترويجية" : "Pricing & Promotional Economics",
                subtitle: Language.isRTL() ? "تحديد سعر البيع بالريال القطري والخصومات المتاحة" : "Set QAR consumer pricing and active promotional discounts",
                symbol: "dollarsign.circle.fill"
            )

            // Direct Selling Price
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "سعر البيع النهائي للعميل" : "Consumer Selling Price")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Text("*")
                        .font(PPFont.bold(13))
                        .foregroundStyle(primaryBrandPink)
                }

                HStack(spacing: 10) {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField("150", text: $priceString)
                        .keyboardType(.decimalPad)
                        .font(PPFont.bold(17, relativeTo: .headline))
                        .foregroundStyle(Color(UIColor.label))

                    Text(Language.get("QAR", alter: "ر.ق QAR"))
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundStyle(primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryAccent.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(priceString.isEmpty ? hairlineColor : primaryAccent.opacity(0.4), lineWidth: 0.75))
            }

            // Quick Pricing Stepper Chips
            HStack(spacing: 8) {
                pricingAddChip(label: "+10", delta: 10)
                pricingAddChip(label: "+25", delta: 25)
                pricingAddChip(label: "+50", delta: 50)
                pricingAddChip(label: "+100", delta: 100)
            }

            // Wholesale Price (Optional)
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "سعر الجملة / التكلفة الداخلية (اختياري)" : "Wholesale / Cost Price (Optional)")
                    .font(PPFont.bold(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.label))

                HStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .frame(width: 24)

                    TextField("95", text: $wholesalePriceString)
                        .keyboardType(.decimalPad)
                        .font(PPFont.medium(15, relativeTo: .body))
                        .foregroundStyle(Color(UIColor.label))

                    Text("QAR")
                        .font(PPFont.medium(11, relativeTo: .caption2))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // Promotional Offer Toggle
            Toggle(isOn: $hasOffer) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(primaryBrandPink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "تفعيل عرض خاص وتخفيض فوري" : "Activate Special Promotional Discount")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(UIColor.label))
                        Text(Language.isRTL() ? "يظهر شريط الخصم المباشر للعملاء في التطبيق" : "Displays an active promotional ribbon to shoppers")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: primaryBrandPink))
            .padding(.top, 4)

            // Discount Settings (When Active)
            if hasOffer {
                VStack(spacing: 10) {
                    Picker("", selection: $discountType) {
                        ForEach(PPDiscountType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if discountType == .percent {
                        HStack(spacing: 10) {
                            Text(Language.isRTL() ? "نسبة الخصم:" : "Discount %:")
                                .font(PPFont.bold(12.5, relativeTo: .caption))
                            TextField("20", text: $discountPercentString)
                                .keyboardType(.numberPad)
                                .font(PPFont.bold(16, relativeTo: .headline))
                                .foregroundStyle(primaryBrandPink)
                            Text("%")
                                .font(PPFont.bold(14))
                                .foregroundStyle(primaryBrandPink)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        HStack(spacing: 10) {
                            Text(Language.isRTL() ? "قيمة الخصم:" : "Discount Amount:")
                                .font(PPFont.bold(12.5, relativeTo: .caption))
                            TextField("30", text: $discountAmountString)
                                .keyboardType(.decimalPad)
                                .font(PPFont.bold(16, relativeTo: .headline))
                                .foregroundStyle(primaryBrandPink)
                            Text("QAR")
                                .font(PPFont.bold(12))
                                .foregroundStyle(primaryBrandPink)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // Calculated Final Price Info Box
                    HStack {
                        Text(Language.isRTL() ? "السعر بعد الخصم:" : "Final Discounted Price:")
                            .font(PPFont.medium(12, relativeTo: .caption))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                        Spacer()
                        Text("\(String(format: "%.0f", computedFinalPrice)) QAR")
                            .font(PPFont.bold(15, relativeTo: .subheadline))
                            .foregroundStyle(primaryBrandPink)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(12)
                .background(primaryBrandPink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(primaryBrandPink.opacity(0.2), lineWidth: 0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func pricingAddChip(label: String, delta: Double) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            let current = Double(priceString) ?? 0
            priceString = String(format: "%.0f", current + delta)
        }) {
            Text(label)
                .font(PPFont.bold(12, relativeTo: .caption))
                .foregroundStyle(primaryAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(primaryAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(primaryAccent.opacity(0.20), lineWidth: 0.75))
        }
    }

    // MARK: - 6. Inventory & Warehouse Tracking

    private var inventoryWarehouseDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "المخزون والرموز اللوجستية" : "Inventory & Warehouse Tracking",
                subtitle: Language.isRTL() ? "تحديد كمية المخزون المتاحة والباركود لسهولة الجرد" : "Manage stock levels, warehouse SKU, and scanner barcodes",
                symbol: "shippingbox.fill"
            )

            // Stock Stepper Row
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "الكمية المتاحة في المخزن" : "Available Stock Quantity")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Text("*")
                        .font(PPFont.bold(13))
                        .foregroundStyle(primaryBrandPink)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        if quantity > 0 { quantity -= 1 }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 44, height: 44)
                            .background(surfaceBackground, in: Circle())
                            .overlay(Circle().strokeBorder(hairlineColor, lineWidth: 0.75))
                    }

                    Text("\(quantity)")
                        .font(PPFont.bold(20, relativeTo: .title3))
                        .foregroundStyle(quantity == 0 ? Color.red : Color(UIColor.label))
                        .frame(maxWidth: .infinity)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        quantity += 1
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 44, height: 44)
                            .background(surfaceBackground, in: Circle())
                            .overlay(Circle().strokeBorder(hairlineColor, lineWidth: 0.75))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // Quick Stock Chips
            HStack(spacing: 8) {
                stockChip(label: "+5", delta: 5)
                stockChip(label: "+10", delta: 10)
                stockChip(label: "+25", delta: 25)
                stockChip(label: "+50", delta: 50)
                stockChip(label: "+100", delta: 100)
            }

            // SKU & Barcode Inputs
            HStack(spacing: 10) {
                // SKU
                VStack(alignment: .leading, spacing: 4) {
                    Text(Language.isRTL() ? "رمز التخزين SKU" : "Warehouse SKU")
                        .font(PPFont.bold(11, relativeTo: .caption2))
                        .foregroundStyle(Color(UIColor.secondaryLabel))

                    HStack(spacing: 6) {
                        Image(systemName: "barcode")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                        TextField("SKU-1024", text: $sku)
                            .font(PPFont.medium(13, relativeTo: .body))
                            .foregroundStyle(Color(UIColor.label))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
                }

                // Barcode
                VStack(alignment: .leading, spacing: 4) {
                    Text(Language.isRTL() ? "الباركود الدولي" : "Barcode")
                        .font(PPFont.bold(11, relativeTo: .caption2))
                        .foregroundStyle(Color(UIColor.secondaryLabel))

                    HStack(spacing: 6) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                        TextField("62910...", text: $barcode)
                            .font(PPFont.medium(13, relativeTo: .body))
                            .foregroundStyle(Color(UIColor.label))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func stockChip(label: String, delta: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            quantity += delta
        }) {
            Text(label)
                .font(PPFont.bold(11.5, relativeTo: .caption2))
                .foregroundStyle(primaryAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(primaryAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(primaryAccent.opacity(0.20), lineWidth: 0.75))
        }
    }

    // MARK: - 7. Animal Species & Category Horizon

    private var speciesTargetDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "تصنيف المنتج ونوع الحيوان" : "Species Targeting & Product Category",
                subtitle: Language.isRTL() ? "حدد نوع المنتج وفصيلة الحيوان المستهدفة" : "Target pet species and product classification",
                symbol: "pawprint.fill"
            )

            // Product Access Kind Picker (Accessories vs Food)
            Picker("", selection: $accessKindType) {
                ForEach(PPProductAccessKind.allCases) { kind in
                    Text(kind.localizedTitle).tag(kind)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Target Animal Species Grid
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "فصيلة الحيوان المستهدفة" : "Target Pet Species")
                    .font(PPFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.secondaryLabel))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 8)], spacing: 8) {
                    ForEach(PPMarketSpeciesCatalog.items) { item in
                        let isSelected = (selectedSpeciesID == item.id)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedSpeciesID = item.id
                                selectedSpeciesName = item.titleAr
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(item.emoji)
                                    .font(.system(size: 22))
                                Text(item.localizedTitle)
                                    .font(PPFont.bold(11, relativeTo: .caption2))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? primaryAccent.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isSelected ? primaryAccent : hairlineColor, lineWidth: isSelected ? 1.5 : 0.75)
                            )
                            .foregroundStyle(isSelected ? primaryAccent : Color(UIColor.label))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 8. Variant Matrix Studio Gateway

    private var variantMatrixGatewayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(primaryAccent.opacity(0.12))
                    Image(systemName: "slider.horizontal.2.square.on.square")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(Language.isRTL() ? "خيارات الصنف والمصفوفة" : "Product Options & Matrix Studio")
                        .font(PPFont.bold(14, relativeTo: .headline))
                        .foregroundStyle(Color(UIColor.label))
                    Text(Language.isRTL() ? "ألوان ومقاسات وأوزان الصنف مع باركود مستقل" : "Manage multi-axis colors, sizes, and variant pricing")
                        .font(PPFont.regular(11, relativeTo: .caption2))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
                Spacer()
            }

            if belongsToVariantFamily {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.green)
                    Text(Language.isRTL() ? "ينتمي هذا المنتج إلى مصفوفة خيارات معتمدة" : "This product belongs to an active option matrix")
                        .font(PPFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(Color.green)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(Language.isRTL()
                     ? "يمكنك توليد مقاسات وألوان وأوزان متعددة لهذا المنتج وتحديد سعر ومخزون خاص لكل تركيبة."
                     : "You can generate multiple sizes, colors, and weights with custom price and stock per combination.")
                    .font(PPFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }

            Button(action: openVariantStudio) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                    Text(belongsToVariantFamily
                         ? (Language.isRTL() ? "فتح استوديو الخيارات والمصفوفة" : "Open Options & Matrix Studio")
                         : (Language.isRTL() ? "تفعيل الخيارات وتجهيز الاستوديو" : "Enable Options & Open Studio")
                    )
                    .font(PPFont.bold(13, relativeTo: .subheadline))
                    Spacer()
                    Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(primaryAccent)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(primaryAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(primaryAccent.opacity(0.25), lineWidth: 0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 9. Marketplace Catalog Visibility & Status

    private var marketplaceVisibilityDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "حالة النشر والظهور في متجر بيور بيتس" : "Catalog Visibility & Storefront Radar",
                subtitle: Language.isRTL() ? "التحكم في ظهور المنتج وتوفر الطلب الفوري" : "Control live consumer visibility and instant ordering",
                symbol: "antenna.radiowaves.left.and.right"
            )

            // Market Publication Toggle
            Toggle(isOn: $showInAppMarket) {
                HStack(spacing: 10) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(primaryAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "معروض في متجر بيور بيتس" : "Live in Pure Pets Consumer App")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(UIColor.label))
                        Text(Language.isRTL() ? "يظهر لجميع العملاء في السوق الرقمي" : "Visible across consumer discovery feeds")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: primaryAccent))

            // Instant Delivery Availability Toggle
            Toggle(isOn: $isAvailable) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "متاح للطلب والتوصيل الفوري" : "Available for Instant Order & Delivery")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(UIColor.label))
                        Text(Language.isRTL() ? "يمكن للعملاء إضافته للسلة والشراء فوراً" : "Consumers can instantly add to cart and checkout")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.green))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - Catalyst Action Dock

    private var catalystActionDock: some View {
        VStack(spacing: 0) {
            Divider().overlay(hairlineColor)

            Button(action: saveMarketProduct) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView().tint(.white)
                        Text(savingStatusMessage)
                            .font(PPFont.bold(15, relativeTo: .headline))
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(isEditing
                             ? (Language.isRTL() ? "حفظ وتحديث بيانات المنتج" : "Save Product Updates")
                             : (Language.isRTL() ? "نشر وتثبيت المنتج في السوق" : "Publish Product to Market")
                        )
                        .font(PPFont.bold(16, relativeTo: .headline))
                        Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                            .font(.system(size: 12, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isFormValid
                                ? LinearGradient(colors: [primaryBrandPink, primaryBrandPink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(color: isFormValid ? primaryBrandPink.opacity(0.35) : .clear, radius: 10, y: 3)
            }
            .disabled(!isFormValid || isSaving)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(surfaceBackground.opacity(0.94).background(.ultraThinMaterial))
    }

    // MARK: - Saving HUD Overlay

    private var savingHUDOverlay: some View {
        ZStack {
            Color.black.opacity(0.40).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text(savingStatusMessage.isEmpty
                     ? (Language.isRTL() ? "جارٍ نشر المنتج في السوق..." : "Publishing to catalog...")
                     : savingStatusMessage
                )
                .font(PPFont.bold(14, relativeTo: .subheadline))
                .foregroundStyle(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }

    // MARK: - Error Banner

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.red)
            Text(text)
                .font(PPFont.medium(12.5, relativeTo: .caption))
                .foregroundStyle(Color.red)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.red)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.red.opacity(0.25), lineWidth: 0.75))
    }

    // MARK: - Section Header Reusable Primitive

    private func sectionHeader(title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(primaryAccent.opacity(0.12))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(primaryAccent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PPFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color(UIColor.label))
                Text(subtitle)
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Computed State Helpers

    private var isFormValid: Bool {
        let trimmedName = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(priceString) ?? 0
        return !trimmedName.isEmpty && price > 0
    }

    private var hasUnsavedEdits: Bool {
        if !nameAr.isEmpty || !priceString.isEmpty || !localImages.isEmpty {
            return true
        }
        return false
    }

    private var completionProgress: Double {
        var score: Double = 0.1
        if !nameAr.trimmingCharacters(in: .whitespaces).isEmpty { score += 0.25 }
        if (Double(priceString) ?? 0) > 0 { score += 0.25 }
        if !descAr.trimmingCharacters(in: .whitespaces).isEmpty { score += 0.15 }
        if (cloudImageURLs.count + localImages.count) > 0 { score += 0.25 }
        return min(score, 1.0)
    }

    private var computedFinalPrice: Double {
        let base = Double(priceString) ?? 0
        guard hasOffer && base > 0 else { return base }

        if discountType == .percent {
            let pct = Double(discountPercentString) ?? 0
            if pct > 0 {
                return max(0, base - (base * (pct / 100.0)))
            }
        } else {
            let amt = Double(discountAmountString) ?? 0
            if amt > 0 {
                return max(0, base - amt)
            }
        }
        return base
    }

    private var calculatedDiscountPercentage: Double {
        let base = Double(priceString) ?? 0
        guard hasOffer && base > 0 else { return 0 }

        if discountType == .percent {
            return Double(discountPercentString) ?? 0
        } else {
            let amt = Double(discountAmountString) ?? 0
            return (amt / base) * 100.0
        }
    }

    private var selectedSpeciesEmoji: String {
        PPMarketSpeciesCatalog.items.first(where: { $0.id == selectedSpeciesID })?.emoji ?? "🐾"
    }

    private var selectedSpeciesLocalizedName: String {
        PPMarketSpeciesCatalog.items.first(where: { $0.id == selectedSpeciesID })?.localizedTitle ?? selectedSpeciesName
    }

    // MARK: - Photo Picker Processing

    private func handlePhotoPickerSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        if (cloudImageURLs.count + localImages.count) < 5 {
                            localImages.append(image)
                        }
                    }
                }
            }
            await MainActor.run {
                photoPickerItems = []
            }
        }
    }

    // MARK: - Variant Studio Presentation

    private func openVariantStudio() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        var targetItem = itemToEdit
        if targetItem == nil {
            // Synthesize transient item
            targetItem = PPProviderMarketItem()
            targetItem?.name = nameAr
            targetItem?.nameEn = nameEn
            targetItem?.price = Double(priceString) ?? 0
            targetItem?.quantity = quantity
        }

        if let item = targetItem {
            let host = PPAccessoryVariantStudioHostController(marketItem: item)
            host.onSaved = { accessory in
                belongsToVariantFamily = true
                variantFamilyID = accessory.productFamilyId ?? ""
                variantCombinationLabel = accessory.sku ?? ""
                if accessory.price.doubleValue > 0 {
                    priceString = String(format: "%.0f", accessory.price.doubleValue)
                }
                quantity = accessory.quantity
            }
            let nav = UINavigationController(rootViewController: host)
            nav.modalPresentationStyle = .pageSheet
            rootVC.present(nav, animated: true)
        }
    }

    // MARK: - Save & Firebase Persistence Engine

    private func saveMarketProduct() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let trimmedName = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = Language.isRTL() ? "يرجى كتابة اسم المنتج باللغة العربية" : "Please enter the Arabic product name"
            return
        }

        let basePrice = Double(priceString) ?? 0
        guard basePrice > 0 else {
            errorMessage = Language.isRTL() ? "يرجى تحديد سعر بيع صحيح للمنتج" : "Please enter a valid price"
            return
        }

        isSaving = true
        errorMessage = nil
        savingStatusMessage = Language.isRTL() ? "جارٍ إعداد بيانات المنتج..." : "Preparing product payload..."

        Task {
            do {
                // 1. Upload new local images to Firebase Storage
                var finalUploadedURLs = cloudImageURLs
                if !localImages.isEmpty {
                    await MainActor.run {
                        savingStatusMessage = Language.isRTL() ? "جارٍ رفع صور المنتج السحابية..." : "Uploading product images..."
                    }
                    let newURLs = try await uploadImagesToFirebaseStorage(images: localImages)
                    finalUploadedURLs.append(contentsOf: newURLs)
                }

                // 2. Build Authoritative Fields Payload
                let dp = (discountType == .percent) ? (Double(discountPercentString) ?? 0) : 0
                let da = (discountType == .fixed) ? (Double(discountAmountString) ?? 0) : 0
                let wp = Double(wholesalePriceString) ?? 0

                var fields: [String: Any] = [
                    "name": trimmedName,
                    "nameEn": nameEn.trimmingCharacters(in: .whitespacesAndNewlines),
                    "desc": descAr,
                    "descEn": descEn,
                    "price": basePrice,
                    "finalPrice": computedFinalPrice,
                    "quantity": quantity,
                    "noStock": (quantity <= 0),
                    "petMainCategoryID": selectedSpeciesID,
                    "petMainCategoryName": selectedSpeciesLocalizedName,
                    "petSubCategoryID": selectedSubCategoryID,
                    "accessKindType": accessKindType.rawValue,
                    "showInAppMarket": showInAppMarket,
                    "hasOffer": hasOffer && (dp > 0 || da > 0),
                    "imageURLsArray": finalUploadedURLs,
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                if !sku.trimmingCharacters(in: .whitespaces).isEmpty {
                    fields["sku"] = sku.trimmingCharacters(in: .whitespaces)
                }
                if !barcode.trimmingCharacters(in: .whitespaces).isEmpty {
                    fields["barcode"] = barcode.trimmingCharacters(in: .whitespaces)
                }
                if wp > 0 {
                    fields["wholesalePrice"] = wp
                }
                if dp > 0 {
                    fields["discountPercent"] = dp
                }
                if da > 0 {
                    fields["discountAmount"] = da
                }

                // 3. Commit through PPProviderMarketplaceManager
                await MainActor.run {
                    savingStatusMessage = Language.isRTL() ? "جارٍ نشر المنتج في السوق الرقمي..." : "Publishing to catalog..."
                }

                if let existingItem = itemToEdit, !existingItem.itemID.isEmpty {
                    let itemID = existingItem.itemID
                    // Update
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        PPProviderMarketplaceManager.shared().updateMarketItem(itemID, fields: fields) { success, msg, error in
                            if success {
                                continuation.resume()
                            } else {
                                continuation.resume(throwing: error ?? NSError(domain: "PPMarket", code: 500, userInfo: [NSLocalizedDescriptionKey: msg ?? "Failed to update item"]))
                            }
                        }
                    }
                } else {
                    // Create
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        PPProviderMarketplaceManager.shared().createMarketItem(fields) { success, itemID, msg, error in
                            if success && itemID != nil {
                                continuation.resume()
                            } else {
                                continuation.resume(throwing: error ?? NSError(domain: "PPMarket", code: 500, userInfo: [NSLocalizedDescriptionKey: msg ?? "Failed to create item"]))
                            }
                        }
                    }
                }

                // Success
                await MainActor.run {
                    self.isSaving = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPToast.toast(Language.isRTL() ? "تم نشر المنتج في السوق بنجاح" : "Product published successfully", style: .success, haptic: true, duration: 2.0)
                    self.onSaved()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func uploadImagesToFirebaseStorage(images: [UIImage]) async throws -> [String] {
        guard !images.isEmpty else { return [] }
        let uid = Auth.auth().currentUser?.uid ?? "unknown_vendor"
        let storageRef = Storage.storage().reference()
        var uploadedURLs: [String] = []

        for (idx, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.82) else { continue }
            let filename = "\(uid)_\(Int(Date().timeIntervalSince1970 * 1000))_\(idx).jpg"
            let imagePath = "marketplace_items/\(uid)/images/\(filename)"
            let ref = storageRef.child(imagePath)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            metadata.customMetadata = [
                "uploaded_by": uid,
                "media_type": "marketplace_product_image"
            ]

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.putData(data, metadata: metadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            let downloadURL: URL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                ref.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PPStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing download URL"]))
                    }
                }
            }
            uploadedURLs.append(downloadURL.absoluteString)
        }
        return uploadedURLs
    }
}

// MARK: - UIKit Objective-C Hosting Bridge Controller

@objc(PPProviderMarketItemStudioHostingController)
public final class PPProviderMarketItemStudioHostingController: UIViewController {
    private let itemToEdit: PPProviderMarketItem?
    private let initialAccessKindType: NSInteger
    private let onDismissHandler: (() -> Void)?
    private let onSavedHandler: (() -> Void)?
    private var hostingController: UIHostingController<PPProviderMarketItemStudioScreen>?

    @objc public init(
        marketItem: PPProviderMarketItem?,
        initialAccessKindType: NSInteger = 1,
        onDismiss: (() -> Void)? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.itemToEdit = marketItem
        self.initialAccessKindType = initialAccessKindType
        self.onDismissHandler = onDismiss
        self.onSavedHandler = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        let studioView = PPProviderMarketItemStudioScreen(
            itemToEdit: self.itemToEdit,
            initialAccessKindType: Int(self.initialAccessKindType),
            onDismiss: { [weak self] in
                if let handler = self?.onDismissHandler {
                    handler()
                } else if let nav = self?.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true, completion: nil)
                }
            },
            onSaved: { [weak self] in
                self?.onSavedHandler?()
            }
        )

        let host = UIHostingController(rootView: studioView)
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

// MARK: - Legacy Compatibility Stubs

@objc(PPItemEditorHeroSnapshot)
public final class PPItemEditorHeroSnapshot: NSObject {
    @objc public let isCreate: Bool
    @objc public let title: String
    @objc public let subtitle: String
    @objc public let itemName: String
    @objc public let categoryName: String
    @objc public let primaryImageURL: String?
    @objc public let primaryImage: UIImage?
    @objc public let imageCount: Int
    @objc public let allImageURLs: [String]
    @objc public let allSelectedImages: [UIImage]
    @objc public let isPublished: Bool
    @objc public let isAvailable: Bool
    @objc public let completionProgress: Double
    @objc public let stateIndex: Int
    @objc public let errorMessage: String?

    @objc public init(
        isCreate: Bool,
        title: String,
        subtitle: String,
        itemName: String,
        categoryName: String,
        primaryImageURL: String?,
        primaryImage: UIImage?,
        imageCount: Int,
        allImageURLs: [String],
        allSelectedImages: [UIImage],
        isPublished: Bool,
        isAvailable: Bool,
        completionProgress: Double,
        stateIndex: Int,
        errorMessage: String?
    ) {
        self.isCreate = isCreate
        self.title = title
        self.subtitle = subtitle
        self.itemName = itemName
        self.categoryName = categoryName
        self.primaryImageURL = primaryImageURL
        self.primaryImage = primaryImage
        self.imageCount = imageCount
        self.allImageURLs = allImageURLs
        self.allSelectedImages = allSelectedImages
        self.isPublished = isPublished
        self.isAvailable = isAvailable
        self.completionProgress = completionProgress
        self.stateIndex = stateIndex
        self.errorMessage = errorMessage
        super.init()
    }
}

@objc(PPItemEditorHeroHostView)
public final class PPItemEditorHeroHostView: UIView {
    @objc public var onPickImage: (() -> Void)?
    @objc public var onRemoveImageAtIndex: ((NSInteger) -> Void)?
    @objc public var onRetry: (() -> Void)?

    @objc public init(snapshot: PPItemEditorHeroSnapshot) {
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc public func updateSnapshot(_ snapshot: PPItemEditorHeroSnapshot) {}
}
