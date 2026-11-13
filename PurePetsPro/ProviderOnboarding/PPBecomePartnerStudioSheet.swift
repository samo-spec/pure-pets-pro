//
//  PPBecomePartnerStudioSheet.swift
//  PurePetsPro
//
//  First-Principles Category-Defining Invention: SwiftyMax NextGen V9.
//  The Authoritative Become a Partner & Provider Onboarding Studio Sheet.
//  Tactile archetype switching, dynamic plan selection matrix, holographic legal pass,
//  document scanning, and resilient Cloud Function submission.
//

import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import FirebaseStorage
import FirebaseAuth

// MARK: - Archetype Catalog Token

public struct PPProviderArchetypeItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let providerType: PPProviderType
    public let titleAr: String
    public let titleEn: String
    public let subtitleAr: String
    public let subtitleEn: String
    public let symbol: String
    public let badgeAr: String
    public let badgeEn: String
    public let accentColorHex: String

    public var localizedTitle: String { Language.isRTL() ? titleAr : titleEn }
    public var localizedSubtitle: String { Language.isRTL() ? subtitleAr : subtitleEn }
    public var localizedBadge: String { Language.isRTL() ? badgeAr : badgeEn }
}

public enum PPProviderArchetypeCatalog {
    public static let allItems: [PPProviderArchetypeItem] = [
        PPProviderArchetypeItem(
            id: 0,
            providerType: .deliverySubscription,
            titleAr: "مندوب توصيل مستقل",
            titleEn: "Delivery Partner",
            subtitleAr: "توصيل طلبات واشتراكات متكررة للعملاء",
            subtitleEn: "Deliver recurring pet orders & missions",
            symbol: "bicycle",
            badgeAr: "عوائد أسبوعية",
            badgeEn: "Weekly Payouts",
            accentColorHex: "#3B82F6"
        ),
        PPProviderArchetypeItem(
            id: 1,
            providerType: .service,
            titleAr: "صالونات واستضافة ورعاية",
            titleEn: "Pet Salons & Boarding",
            subtitleAr: "خدمات تزيين، إيواء، رعاية وتدريب الحيوانات",
            subtitleEn: "Grooming, daycare, boarding & training",
            symbol: "sparkles",
            badgeAr: "حجوزات فورية",
            badgeEn: "Instant Booking",
            accentColorHex: "#EC4899"
        ),
        PPProviderArchetypeItem(
            id: 2,
            providerType: .vet,
            titleAr: "طبيب أو عيادة بيطرية",
            titleEn: "Veterinary Clinic",
            subtitleAr: "استشارات طبية، جراحة، ورعاية سريرية معتمدة",
            subtitleEn: "Consultations, clinical care & diagnostics",
            symbol: "stethoscope",
            badgeAr: "اعتماد طبي",
            badgeEn: "Medical Pass",
            accentColorHex: "#10B981"
        ),
        PPProviderArchetypeItem(
            id: 3,
            providerType: .pharmacy,
            titleAr: "صيدلية بيطرية ومكملات",
            titleEn: "Veterinary Pharmacy",
            subtitleAr: "صرف أدوية ومستلزمات طبية وغذائية مرخصة",
            subtitleEn: "Dispense licensed meds & clinical supplies",
            symbol: "pills.fill",
            badgeAr: "ترخيص رسمي",
            badgeEn: "Licensed Rx",
            accentColorHex: "#8B5CF6"
        ),
        PPProviderArchetypeItem(
            id: 4,
            providerType: .marketplace,
            titleAr: "متجر ومستلزمات الحيوانات",
            titleEn: "Marketplace Merchant",
            subtitleAr: "بيع أطعمة، إكسسوارات، ومستلزمات الحيوانات في السوق",
            subtitleEn: "Sell accessories, food & lifestyle items",
            symbol: "cart.fill",
            badgeAr: "سوق متكامل",
            badgeEn: "Direct Sales",
            accentColorHex: "#F59E0B"
        ),
        PPProviderArchetypeItem(
            id: 5,
            providerType: .deliveryCompany,
            titleAr: "شركة أسطول توصيل لوجستي",
            titleEn: "Logistics Fleet Company",
            subtitleAr: "إدارة مناديب ومركبات وتوزيع لوجستي للطلبات",
            subtitleEn: "Manage delivery fleets & driver rosters",
            symbol: "shippingbox.fill",
            badgeAr: "إدارة أسطول",
            badgeEn: "Fleet Dispatch",
            accentColorHex: "#6366F1"
        )
    ]

    public static func item(for type: PPProviderType) -> PPProviderArchetypeItem? {
        allItems.first { $0.providerType == type }
    }
}

// MARK: - Country Dial Code Token

public struct PPCountryDialOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let nameAr: String
    public let nameEn: String
    public let flag: String

    public var localizedName: String { Language.isRTL() ? nameAr : nameEn }
}

public enum PPCountryDialCatalog {
    public static let defaults: [PPCountryDialOption] = [
        PPCountryDialOption(id: "QA", code: "+974", nameAr: "قطر", nameEn: "Qatar", flag: "🇶🇦"),
        PPCountryDialOption(id: "SA", code: "+966", nameAr: "السعودية", nameEn: "Saudi Arabia", flag: "🇸🇦"),
        PPCountryDialOption(id: "AE", code: "+971", nameAr: "الإمارات", nameEn: "UAE", flag: "🇦🇪"),
        PPCountryDialOption(id: "KW", code: "+965", nameAr: "الكويت", nameEn: "Kuwait", flag: "🇰🇼"),
        PPCountryDialOption(id: "BH", code: "+973", nameAr: "البحرين", nameEn: "Bahrain", flag: "🇧🇭"),
        PPCountryDialOption(id: "OM", code: "+968", nameAr: "عُمان", nameEn: "Oman", flag: "🇴🇲")
    ]
}

// MARK: - Qatar Municipality / City Token

public struct PPQatarCityItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameAr: String
    public let nameEn: String
    public let areas: [String]

    public var localizedName: String { Language.isRTL() ? nameAr : nameEn }
}

public enum PPQatarCityCatalog {
    public static let cities: [PPQatarCityItem] = [
        PPQatarCityItem(id: "15001", nameAr: "الدوحة", nameEn: "Doha", areas: [
            "مشيرب", "الخليج الغربي", "الدفنة", "السد", "بن محمود", "نجمة", "المنصورة", "المطار القديم", "اللؤلؤة"
        ]),
        PPQatarCityItem(id: "15004", nameAr: "الريان", nameEn: "Al Rayyan", areas: [
            "المدينة التعليمية", "الوعب", "معيذر", "الغرافة", "اللقطة", "العزيزية", "عين خالد", "أبو سدرة", "روضة القديم"
        ]),
        PPQatarCityItem(id: "15002", nameAr: "الوكرة", nameEn: "Al Wakrah", areas: [
            "مدينة الوكرة", "الوكير", "مسيعيد", "إزدان أواسيس", "المشاف", "قرية بروة", "رأس أبو فنطاس"
        ]),
        PPQatarCityItem(id: "15003", nameAr: "الخور", nameEn: "Al Khor", areas: [
            "مدينة الخور", "الذخيرة", "رأس لفان", "الغويرية", "أم بركة"
        ]),
        PPQatarCityItem(id: "15005", nameAr: "الشمال", nameEn: "Al Shamal", areas: [
            "مدينة الشمال", "الرويس", "أبو ظلوف", "فويرط", "الزبارة"
        ]),
        PPQatarCityItem(id: "15007", nameAr: "أم صلال", nameEn: "Umm Salal", areas: [
            "أم صلال علي", "أم صلال محمد", "أم العمد", "إزغوى", "الخريطيات"
        ]),
        PPQatarCityItem(id: "15006", nameAr: "الضعاين", nameEn: "Al Daayen", areas: [
            "لوسيل", "أم قرن", "روضة الحمامة", "العِب", "لعبيب", "وادي البنات", "جريان جنيحات"
        ]),
        PPQatarCityItem(id: "15008", nameAr: "الشحانية", nameEn: "Al Shahaniya", areas: [
            "مدينة الشحانية", "دخان", "أم باب", "روضة راشد", "النصرانية", "الجميلية"
        ])
    ]

    public static func city(for id: String) -> PPQatarCityItem? {
        cities.first { $0.id == id }
    }
}

// MARK: - Studio Steps

public enum PPPartnerStudioStep: Int, CaseIterable, Identifiable {
    case archetype = 0
    case plan = 1
    case identity = 2
    case credentials = 3
    case review = 4

    public var id: Int { rawValue }

    public var titleAr: String {
        switch self {
        case .archetype: return "نوع الشريك"
        case .plan: return "باقة الاشتراك"
        case .identity: return "البيانات التجارية"
        case .credentials: return "التراخيص"
        case .review: return "المراجعة والاعتماد"
        }
    }

    public var titleEn: String {
        switch self {
        case .archetype: return "Partner Type"
        case .plan: return "Plan Tier"
        case .identity: return "Commercial Info"
        case .credentials: return "Licenses"
        case .review: return "Review & Submit"
        }
    }

    public var localizedTitle: String { Language.isRTL() ? titleAr : titleEn }
    public var symbol: String {
        switch self {
        case .archetype: return "person.crop.circle.badge.plus"
        case .plan: return "sparkles.rectangle.stack.fill"
        case .identity: return "building.2.crop.circle.fill"
        case .credentials: return "doc.badge.gearshape.fill"
        case .review: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Main SwiftUI Studio Sheet

public struct PPBecomePartnerStudioSheet: View {
    private let state: PPProviderOnboardingState?
    private let eligibleTypes: [PPProviderType]
    private let preferredType: PPProviderType
    private let onSubmitted: () -> Void
    private let onDismiss: () -> Void

    // Navigation & Step State
    @State private var currentStep: PPPartnerStudioStep = .archetype

    // Archetype Selection
    @State private var selectedType: PPProviderType = .unspecified

    // Plans State
    @State private var availablePlans: [PPProviderPlan] = []
    @State private var selectedPlan: PPProviderPlan? = nil
    @State private var isLoadingPlans: Bool = false
    @State private var plansError: String? = nil

    // Identity Fields
    @State private var fullName: String = ""
    @State private var selectedCountryCode: String = "+974"
    @State private var phoneLocalNumber: String = ""
    @State private var email: String = ""
    @State private var businessName: String = ""
    @State private var companyName: String = ""
    @State private var legalName: String = ""
    @State private var address: String = ""
    @State private var selectedCityID: String = "15001"
    @State private var selectedAreas: Set<String> = []

    // Credentials & Documents
    @State private var licenseNumber: String = ""
    @State private var commercialRegistrationNumber: String = ""
    @State private var licenseDocURL: String = ""
    @State private var crDocURL: String = ""
    @State private var notes: String = ""

    // Media Upload & Scan State
    @State private var isUploadingLicense: Bool = false
    @State private var isUploadingCR: Bool = false
    @State private var activeDocumentTag: Int = 0
    @State private var showPhotoPicker: Bool = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showDocumentPicker: Bool = false

    // Submission & UI State
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var duplicateWarning: String? = nil
    @State private var showSuccessBanner: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        state: PPProviderOnboardingState?,
        eligibleTypes: [PPProviderType],
        preferredType: PPProviderType,
        onSubmitted: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.state = state
        self.eligibleTypes = eligibleTypes
        self.preferredType = preferredType
        self.onSubmitted = onSubmitted
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Living Fluid Background
                PPStudioBackgroundView()

                VStack(spacing: 0) {
                    // Category-Defining Top Stepper
                    PPStudioStepBar(currentStep: $currentStep)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Step Content
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case .archetype:
                                archetypeStepView
                            case .plan:
                                planStepView
                            case .identity:
                                identityStepView
                            case .credentials:
                                credentialsStepView
                            case .review:
                                reviewStepView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120) // space for floating bottom dock
                    }
                }

                // Floating Action Bar at the Bottom
                VStack {
                    Spacer()
                    bottomActionBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(currentStep.localizedTitle)
                            .font(PPBrandFont.bold(16, relativeTo: .headline))
                            .foregroundStyle(Color(.label))
                        Text(Language.isRTL() ? "خطوة \(currentStep.rawValue + 1) من 5" : "Step \(currentStep.rawValue + 1) of 5")
                            .font(PPBrandFont.medium(11, relativeTo: .caption2))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .onAppear {
                PPBrandFont.registerIfNeeded()
                setupInitialData()
            }
            .onChange(of: photoPickerItem) { newItem in
                handlePickedPhoto(newItem)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .alert(isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Alert(
                    title: Text(Language.isRTL() ? "تنبيه" : "Notice"),
                    message: Text(errorMessage ?? ""),
                    dismissButton: .default(Text(Language.isRTL() ? "حسناً" : "OK"))
                )
            }
        }
    }

    // MARK: - Initial Prefill

    private func setupInitialData() {
        if eligibleTypes.contains(preferredType) {
            selectedType = preferredType
        } else if let first = eligibleTypes.first {
            selectedType = first
        } else {
            selectedType = .deliverySubscription
        }

        if let state = state {
            fullName = state.displayName
            email = state.email
            let phone = state.phone
            if !phone.isEmpty {
                if phone.hasPrefix("+974") {
                    selectedCountryCode = "+974"
                    phoneLocalNumber = String(phone.dropFirst(4))
                } else {
                    phoneLocalNumber = phone
                }
            }

            // Check if existing application form or profile has details to prefill
            if let existingApp = state.application(for: selectedType) {
                prefillFromForm(existingApp.form)
            } else if let profile = state.profile(for: selectedType) {
                prefillFromForm(profile.form)
            }
        }

        // Load saved draft if present
        if let draft = PPProviderApplicationManager.shared().savedDraft(for: selectedType) {
            if !draft.fullName.isEmpty { fullName = draft.fullName }
            if !draft.businessName.isEmpty { businessName = draft.businessName }
            if !draft.companyName.isEmpty { companyName = draft.companyName }
            if !draft.legalName.isEmpty { legalName = draft.legalName }
            if !draft.address.isEmpty { address = draft.address }
            if !draft.city.isEmpty { selectedCityID = draft.city }
            if !draft.licenseNumber.isEmpty { licenseNumber = draft.licenseNumber }
            if !draft.commercialRegistrationNumber.isEmpty { commercialRegistrationNumber = draft.commercialRegistrationNumber }
            if !draft.licenseDocumentURL.isEmpty { licenseDocURL = draft.licenseDocumentURL }
            if !draft.commercialRegistrationDocumentURL.isEmpty { crDocURL = draft.commercialRegistrationDocumentURL }
            if !draft.notes.isEmpty { notes = draft.notes }
        }

        reloadPlansForSelectedType()
    }

    private func prefillFromForm(_ form: [AnyHashable: Any]) {
        if let name = form["fullName"] as? String, !name.isEmpty { fullName = name }
        if let bName = form["businessName"] as? String, !bName.isEmpty { businessName = bName }
        if let cName = form["companyName"] as? String, !cName.isEmpty { companyName = cName }
        if let lName = form["legalName"] as? String, !lName.isEmpty { legalName = lName }
        if let addr = form["address"] as? String, !addr.isEmpty { address = addr }
        if let city = form["city"] as? String, !city.isEmpty { selectedCityID = city }
        if let lic = form["licenseNumber"] as? String, !lic.isEmpty { licenseNumber = lic }
        if let cr = form["commercialRegistrationNumber"] as? String, !cr.isEmpty { commercialRegistrationNumber = cr }
        if let licURL = form["licenseDocumentURL"] as? String, !licURL.isEmpty { licenseDocURL = licURL }
        if let crURL = form["commercialRegistrationDocumentURL"] as? String, !crURL.isEmpty { crDocURL = crURL }
    }

    private func reloadPlansForSelectedType() {
        guard selectedType != .unspecified else { return }
        isLoadingPlans = true
        plansError = nil
        let requestedType = selectedType
        let uid = PPDeliveryCompanyService.currentAccountUID()
        // The manager's declared main-actor completion matches its main-queue
        // delivery contract, so mutable plan models remain on that actor.
        PPProviderApplicationManager.shared().fetchPlans(for: requestedType) { plans, error in
                guard selectedType == requestedType,
                      PPDeliveryCompanyService.currentAccountUID() == uid else { return }
                self.isLoadingPlans = false
                if let error = error {
                    self.plansError = error.localizedDescription
                } else if let plans = plans, !plans.isEmpty {
                    self.availablePlans = plans
                    if self.selectedPlan == nil || !plans.contains(where: { $0.planID == self.selectedPlan?.planID }) {
                        self.selectedPlan = plans.first(where: { $0.recommended }) ?? plans.first
                    }
                } else {
                    self.availablePlans = []
                    self.plansError = Language.isRTL() ? "لا توجد باقات متاحة لهذا المسار حالياً" : "No plans currently available for this category"
                }
        }
    }

    // MARK: - Step 1: Archetype Selection

    private var archetypeStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Hero Banner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Language.isRTL() ? "اختر مسار الشراكة" : "Select Partner Archetype")
                        .font(PPBrandFont.bold(22, relativeTo: .title2))
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
                Text(Language.isRTL() ? "حدد النشاط التجاري الذي يمثل خدماتك على منصة بيور بيتس لبدء التدقيق والاعتماد." : "Choose the business profile that best represents your services on Pure Pets.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.vertical, 8)

            // Archetype Cards Grid
            VStack(spacing: 12) {
                ForEach(PPProviderArchetypeCatalog.allItems) { item in
                    let isEligible = eligibleTypes.isEmpty || eligibleTypes.contains(item.providerType)
                    let isSelected = selectedType == item.providerType

                    Button {
                        guard isEligible else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedType = item.providerType
                            reloadPlansForSelectedType()
                        }
                    } label: {
                        HStack(spacing: 16) {
                            // Icon Stage
                            ZStack {
                                Circle()
                                    .fill(
                                        isSelected
                                            ? Color(hex: item.accentColorHex).opacity(0.18)
                                            : Color(.tertiarySystemFill)
                                    )
                                    .frame(width: 54, height: 54)
                                Image(systemName: item.symbol)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color(hex: item.accentColorHex)
                                            : Color(.secondaryLabel)
                                    )
                            }

                            // Text details
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(item.localizedTitle)
                                        .font(PPBrandFont.bold(16, relativeTo: .headline))
                                        .foregroundStyle(isSelected ? Color(.label) : Color(.label).opacity(0.85))

                                    Text(item.localizedBadge)
                                        .font(PPBrandFont.bold(10.5, relativeTo: .caption2))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: item.accentColorHex).opacity(0.15))
                                        .foregroundStyle(Color(hex: item.accentColorHex))
                                        .clipShape(Capsule())
                                }

                                Text(item.localizedSubtitle)
                                    .font(PPBrandFont.regular(12.5, relativeTo: .caption))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .lineLimit(2)
                            }

                            Spacer()

                            // Selection Pill
                            ZStack {
                                Circle()
                                    .strokeBorder(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 2 : 1)
                                    .frame(width: 24, height: 24)
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isSelected ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground).opacity(0.85))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.accentColor.opacity(0.8) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.03),
                            radius: isSelected ? 12 : 6,
                            x: 0,
                            y: isSelected ? 6 : 2
                        )
                        .opacity(isEligible ? 1.0 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEligible)
                }
            }
        }
    }

    // MARK: - Step 2: Plan Selection Matrix

    private var planStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "اختر باقة الاشتراك" : "Select Subscription Plan")
                    .font(PPBrandFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color(.label))
                Text(Language.isRTL() ? "توفر بيور بيتس نماذج مرنة تشمل الاشتراكات الشهرية ونسب العمولة المخفضة." : "Pure Pets offers flexible tiers with transparent commissions and flat rates.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.vertical, 8)

            if isLoadingPlans {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text(Language.isRTL() ? "جارٍ تحميل الباقات المتاحة..." : "Loading available plans...")
                        .font(PPBrandFont.medium(14, relativeTo: .body))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if let error = plansError, availablePlans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.red)
                    Text(error)
                        .font(PPBrandFont.medium(14, relativeTo: .body))
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                    Button(Language.isRTL() ? "إعادة المحاولة" : "Retry") {
                        reloadPlansForSelectedType()
                    }
                    .font(PPBrandFont.bold(14, relativeTo: .body))
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 14) {
                    ForEach(availablePlans, id: \.planID) { plan in
                        let isSelected = selectedPlan?.planID == plan.planID
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPlan = plan
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                // Top row: Plan Name & Recommended badge
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.localizedName())
                                            .font(PPBrandFont.bold(18, relativeTo: .title3))
                                            .foregroundStyle(Color(.label))
                                        if !plan.localizedDescriptionText().isEmpty {
                                            Text(plan.localizedDescriptionText())
                                                .font(PPBrandFont.regular(12.5, relativeTo: .caption))
                                                .foregroundStyle(Color(.secondaryLabel))
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    if plan.recommended {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                            Text(Language.isRTL() ? "الأفضل" : "Top Choice")
                                                .font(PPBrandFont.bold(11, relativeTo: .caption2))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange.opacity(0.16))
                                        .foregroundStyle(Color.orange)
                                        .clipShape(Capsule())
                                    }
                                }

                                // Pricing Pill
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    if plan.costType == .price {
                                        Text(String(format: "%.0f", plan.priceAmount))
                                            .font(PPBrandFont.bold(28, relativeTo: .title))
                                            .foregroundStyle(Color.accentColor)
                                        Text(plan.currency.isEmpty ? "QAR" : plan.currency)
                                            .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                                            .foregroundStyle(Color.accentColor.opacity(0.85))
                                        Text("/ " + (plan.billingInterval.isEmpty ? (Language.isRTL() ? "شهري" : "Monthly") : plan.billingInterval))
                                            .font(PPBrandFont.medium(13, relativeTo: .subheadline))
                                            .foregroundStyle(Color(.secondaryLabel))
                                    } else {
                                        // Percentage pricing: always LTR to prevent bidi reversal of "10% · per item"
                                        Text(String(format: "%.1f%%", plan.costValue > 0 ? plan.costValue : plan.platformCommissionRate))
                                            .font(PPBrandFont.bold(28, relativeTo: .title))
                                            .foregroundStyle(Color.accentColor)
                                            .environment(\.layoutDirection, .leftToRight)
                                        Text(Language.isRTL() ? "عمولة المنصة" : "Platform Commission")
                                            .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                    Spacer()
                                }

                                // Feature rows checklist
                                if !plan.features.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(plan.features.prefix(4)), id: \.self) { feat in
                                            HStack(spacing: 8) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(Color.green)
                                                Text(feat)
                                                    .font(PPBrandFont.regular(13, relativeTo: .body))
                                                    .foregroundStyle(Color(.label).opacity(0.85))
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(isSelected ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground).opacity(0.85))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor : (plan.recommended ? Color.orange.opacity(0.5) : Color.clear),
                                        lineWidth: isSelected ? 2.5 : 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? Color.accentColor.opacity(0.14) : Color.black.opacity(0.04),
                                radius: isSelected ? 14 : 6,
                                x: 0,
                                y: isSelected ? 6 : 2
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Identity & Commercial Details

    private var identityStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "الهوية التجارية والاتصال" : "Commercial Identity")
                    .font(PPBrandFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color(.label))
                Text(Language.isRTL() ? "بيانات الممثل التجاري المعتمد والموقع الجغرافي داخل دولة قطر." : "Authorized representative, contact and geographic operational details in Qatar.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.vertical, 8)

            // Section 1: Contact
            VStack(alignment: .leading, spacing: 14) {
                Text(Language.isRTL() ? "بيانات المسؤول المباشر" : "Authorized Person")
                    .font(PPBrandFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))

                // Full Name
                PPStudioTextField(
                    title: Language.isRTL() ? "الاسم الكامل *" : "Full Name *",
                    placeholder: Language.isRTL() ? "أدخل الاسم الثلاثي" : "Enter full legal name",
                    text: $fullName,
                    symbol: "person.fill"
                )

                // Phone with Qatar Flag Selector
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.isRTL() ? "رقم الجوال المعتمد *" : "Verified Phone *")
                        .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))

                    HStack(spacing: 8) {
                        // Country Selector Pill
                        Menu {
                            ForEach(PPCountryDialCatalog.defaults) { country in
                                Button("\(country.flag) \(country.localizedName) (\(country.code))") {
                                    selectedCountryCode = country.code
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedCountryCode)
                                    .font(PPBrandFont.bold(14, relativeTo: .subheadline))
                                    .foregroundStyle(Color(.label))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Local Phone Number
                        TextField(Language.isRTL() ? "مثال: 55123456" : "e.g. 55123456", text: $phoneLocalNumber)
                            .keyboardType(.phonePad)
                            .font(PPBrandFont.medium(15, relativeTo: .body))
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.8)
                            )
                    }
                }

                // Email
                PPStudioTextField(
                    title: Language.isRTL() ? "البريد الإلكتروني" : "Email Address",
                    placeholder: "contact@purepets.qa",
                    text: $email,
                    symbol: "envelope.fill",
                    keyboardType: .emailAddress
                )
            }

            // Section 2: Business & Legal Entity
            VStack(alignment: .leading, spacing: 14) {
                Text(Language.isRTL() ? "الكيان التجاري والمنشأة" : "Business & Entity")
                    .font(PPBrandFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))

                PPStudioTextField(
                    title: Language.isRTL() ? "اسم النشاط التجاري *" : "Business Trade Name *",
                    placeholder: Language.isRTL() ? "مثال: صيدلية بيور كير أو صالون الأليف" : "e.g. Pure Care Veterinary",
                    text: $businessName,
                    symbol: "storefront.fill"
                )

                if selectedType == .deliveryCompany || selectedType == .service {
                    PPStudioTextField(
                        title: Language.isRTL() ? "اسم الشركة المسجل" : "Registered Company Name",
                        placeholder: Language.isRTL() ? "اسم الشركة المسجل في وزارة التجارة" : "Company legal name",
                        text: $companyName,
                        symbol: "building.2.fill"
                    )

                    PPStudioTextField(
                        title: Language.isRTL() ? "الاسم القانوني للكيان" : "Legal Entity Name",
                        placeholder: Language.isRTL() ? "الكيان القانوني ذ.م.م" : "e.g. Pure Pets W.L.L",
                        text: $legalName,
                        symbol: "doc.text.fill"
                    )
                }

                PPStudioTextField(
                    title: Language.isRTL() ? "العنوان والموقع الجغرافي" : "Physical Address / Location",
                    placeholder: Language.isRTL() ? "الشارع، المنطقة، رقم المبنى" : "Street, Zone, Building No.",
                    text: $address,
                    symbol: "mappin.circle.fill"
                )
            }

            // Section 3: Qatar City & Coverage
            VStack(alignment: .leading, spacing: 14) {
                Text(Language.isRTL() ? "المدينة ومناطق التغطية في قطر" : "Qatar Municipality & Coverage")
                    .font(PPBrandFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))

                // Municipality Selector
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.isRTL() ? "البلدية / المدينة *" : "Municipality / City *")
                        .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))

                    Menu {
                        ForEach(PPQatarCityCatalog.cities) { city in
                            Button(city.localizedName) {
                                selectedCityID = city.id
                                selectedAreas.removeAll()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(PPQatarCityCatalog.city(for: selectedCityID)?.localizedName ?? (Language.isRTL() ? "اختر المدينة" : "Select City"))
                                .font(PPBrandFont.bold(15, relativeTo: .body))
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.8)
                        )
                    }
                }

                // Coverage Areas Chips
                if let activeCity = PPQatarCityCatalog.city(for: selectedCityID), !activeCity.areas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(Language.isRTL() ? "المناطق المشمولة بالخدمة" : "Service Coverage Areas")
                                .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                                .foregroundStyle(Color(.secondaryLabel))
                            Spacer()
                            Button(Language.isRTL() ? "تحديد الكل" : "Select All") {
                                selectedAreas = Set(activeCity.areas)
                            }
                            .font(PPBrandFont.bold(11.5, relativeTo: .caption2))
                        }

                        // Flow chips
                        PPWrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(activeCity.areas, id: \.self) { area in
                                let isIncluded = selectedAreas.contains(area)
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if isIncluded {
                                        selectedAreas.remove(area)
                                    } else {
                                        selectedAreas.insert(area)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: isIncluded ? "checkmark" : "plus")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(area)
                                            .font(isIncluded ? PPBrandFont.bold(12, relativeTo: .caption) : PPBrandFont.medium(12, relativeTo: .caption))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isIncluded ? Color.accentColor : Color(.tertiarySystemFill))
                                    .foregroundStyle(isIncluded ? Color.white : Color(.label))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Licenses & Credentials

    private var credentialsStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "التراخيص والمستندات الرسمية" : "Licenses & Documents")
                    .font(PPBrandFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color(.label))
                Text(Language.isRTL() ? "إرفاق السجل التجاري ورخصة المزاولة لتسريع عملية التدقيق والاعتماد." : "Attach Commercial Registration (CR) and professional practice license for faster approval.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.vertical, 8)

            // CR Card
            PPStudioDocumentUploadCard(
                title: Language.isRTL() ? "السجل التجاري (CR)" : "Commercial Registration (CR)",
                numberPlaceholder: Language.isRTL() ? "رقم السجل التجاري" : "Enter CR Number",
                number: $commercialRegistrationNumber,
                documentURL: $crDocURL,
                isUploading: isUploadingCR,
                onScanTapped: {
                    triggerDocumentScanner(forTag: 200)
                },
                onPickPhotoTapped: {
                    activeDocumentTag = 200
                    showPhotoPicker = true
                }
            )

            // License Card
            PPStudioDocumentUploadCard(
                title: Language.isRTL() ? "رخصة النشاط أو المزاولة الطبية" : "Trade / Medical License",
                numberPlaceholder: Language.isRTL() ? "رقم الترخيص الرسمي" : "Enter License Number",
                number: $licenseNumber,
                documentURL: $licenseDocURL,
                isUploading: isUploadingLicense,
                onScanTapped: {
                    triggerDocumentScanner(forTag: 100)
                },
                onPickPhotoTapped: {
                    activeDocumentTag = 100
                    showPhotoPicker = true
                }
            )

            // Notes View
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "ملاحظات تشغيلية إضافية" : "Operational Remarks & Notes")
                    .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(.secondaryLabel))

                TextEditor(text: $notes)
                    .font(PPBrandFont.regular(14, relativeTo: .body))
                    .frame(height: 90)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.8)
                    )
            }
        }
    }

    // MARK: - Step 5: Review & Holographic Pass

    private var reviewStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "مراجعة الطلب والاعتماد" : "Review & Submit")
                    .font(PPBrandFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color(.label))
                Text(Language.isRTL() ? "تأكد من صحة البيانات قبل إرسال طلب الانضمام إلى فريق اعتماد الشركاء." : "Verify all operational credentials before final submission to our review board.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.vertical, 8)

            // Holographic Partner Dossier Card
            VStack(spacing: 16) {
                // Top Header with Archetype & Badge
                HStack(spacing: 14) {
                    if let archetype = PPProviderArchetypeCatalog.item(for: selectedType) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: archetype.accentColorHex).opacity(0.18))
                                .frame(width: 50, height: 50)
                            Image(systemName: archetype.symbol)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(hex: archetype.accentColorHex))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(archetype.localizedTitle)
                                .font(PPBrandFont.bold(17, relativeTo: .headline))
                                .foregroundStyle(Color(.label))
                            Text(businessName.isEmpty ? (Language.isRTL() ? "منشأة جديدة" : "New Facility") : businessName)
                                .font(PPBrandFont.medium(13, relativeTo: .subheadline))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }

                    Spacer()

                    // Plan Pill
                    if let plan = selectedPlan {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(plan.localizedName())
                                .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                                .foregroundStyle(Color.accentColor)
                            // Price always LTR — prevents Arabic bidi reversal of "10% · per item"
                            Text(plan.localizedPriceLine())
                                .font(PPBrandFont.medium(11, relativeTo: .caption2))
                                .foregroundStyle(Color(.secondaryLabel))
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Divider()

                // Key Verification Points
                VStack(spacing: 10) {
                    PPReviewRow(title: Language.isRTL() ? "الممثل المعتمد" : "Representative", value: fullName)
                    PPReviewRow(title: Language.isRTL() ? "رقم الاتصال" : "Contact Phone", value: "\(selectedCountryCode) \(phoneLocalNumber)")
                    if !email.isEmpty {
                        PPReviewRow(title: Language.isRTL() ? "البريد الإلكتروني" : "Email", value: email)
                    }
                    if let city = PPQatarCityCatalog.city(for: selectedCityID) {
                        PPReviewRow(title: Language.isRTL() ? "المدينة ومناطق التغطية" : "City & Coverage", value: "\(city.localizedName) (\(selectedAreas.count) مناطق)")
                    }
                    if !commercialRegistrationNumber.isEmpty {
                        PPReviewRow(title: Language.isRTL() ? "السجل التجاري (CR)" : "CR Number", value: commercialRegistrationNumber, isVerified: !crDocURL.isEmpty)
                    }
                    if !licenseNumber.isEmpty {
                        PPReviewRow(title: Language.isRTL() ? "رخصة النشاط" : "License Number", value: licenseNumber, isVerified: !licenseDocURL.isEmpty)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)

            // Pre-flight check notice
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.isRTL() ? "اعتماد رسمي وفق معايير دولة قطر" : "Official Verification Standard")
                        .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                        .foregroundStyle(Color(.label))
                    Text(Language.isRTL() ? "يتم تدقيق بيانات السجل التجاري والتراخيص خلال 24 ساعة من الإرسال." : "Credentials are audited by our compliance staff within 24 business hours.")
                        .font(PPBrandFont.regular(11.5, relativeTo: .caption2))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(14)
            .background(Color(.tertiarySystemFill).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Floating Bottom Dock

    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Back button if past step 0
                if currentStep.rawValue > 0 {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if let prev = PPPartnerStudioStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = prev
                            }
                        }
                    } label: {
                        Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(.label))
                            .frame(width: 52, height: 52)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                // Primary Next / Submit Button
                Button {
                    handlePrimaryAction()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(primaryButtonTitle)
                                .font(PPBrandFont.bold(16, relativeTo: .headline))
                            Image(systemName: primaryButtonSymbol)
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || !isCurrentStepValid)
                .opacity(isCurrentStepValid ? 1.0 : 0.5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .frame(height: 0.75)
                        .foregroundStyle(Color(.separator).opacity(0.35)),
                    alignment: .top
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: -4)
        )
    }

    private var primaryButtonTitle: String {
        if currentStep == .review {
            return Language.isRTL() ? "إرسال طلب الاعتماد الآن" : "Submit Partner Application"
        } else {
            return Language.isRTL() ? "المتابعة للخطوة التالية" : "Continue"
        }
    }

    private var primaryButtonSymbol: String {
        if currentStep == .review {
            return "paperplane.fill"
        } else {
            return Language.isRTL() ? "arrow.left" : "arrow.right"
        }
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case .archetype:
            return selectedType != .unspecified
        case .plan:
            return selectedPlan != nil
        case .identity:
            let hasName = !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            let hasPhone = !phoneLocalNumber.trimmingCharacters(in: .whitespaces).isEmpty
            let hasBusinessName = selectedType != .service || !businessName.trimmingCharacters(in: .whitespaces).isEmpty
            return hasName && hasPhone && hasBusinessName
        case .credentials:
            return true // licenses are strongly encouraged but draft can save partials
        case .review:
            return !fullName.isEmpty && !phoneLocalNumber.isEmpty && selectedPlan != nil
        }
    }

    private func handlePrimaryAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentStep == .review {
            submitApplication()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if let next = PPPartnerStudioStep(rawValue: currentStep.rawValue + 1) {
                    currentStep = next
                }
            }
            saveCurrentDraftLocally()
        }
    }

    // MARK: - Save Draft & Submit

    private func buildCurrentDraft() -> PPProviderApplicationDraft {
        let draft = PPProviderApplicationDraft()
        draft.providerType = selectedType
        draft.fullName = fullName.trimmingCharacters(in: .whitespaces)

        let cleanPhone = phoneLocalNumber.trimmingCharacters(in: .whitespaces)
        if cleanPhone.hasPrefix("+") {
            draft.phone = cleanPhone
        } else {
            draft.phone = "\(selectedCountryCode)\(cleanPhone)"
        }

        draft.email = email.trimmingCharacters(in: .whitespaces)
        draft.businessName = businessName.trimmingCharacters(in: .whitespaces)
        draft.companyName = companyName.trimmingCharacters(in: .whitespaces)
        draft.legalName = legalName.trimmingCharacters(in: .whitespaces)
        draft.address = address.trimmingCharacters(in: .whitespaces)
        draft.city = selectedCityID
        draft.coverageAreas = Array(selectedAreas)
        draft.licenseNumber = licenseNumber.trimmingCharacters(in: .whitespaces)
        draft.commercialRegistrationNumber = commercialRegistrationNumber.trimmingCharacters(in: .whitespaces)
        draft.licenseDocumentURL = licenseDocURL
        draft.commercialRegistrationDocumentURL = crDocURL
        draft.notes = notes.trimmingCharacters(in: .whitespaces)
        return draft
    }

    private func saveCurrentDraftLocally() {
        let draft = buildCurrentDraft()
        PPProviderApplicationManager.shared().save(draft, for: selectedType)
    }

    private func submitApplication() {
        guard let plan = selectedPlan else {
            errorMessage = Language.isRTL() ? "يرجى اختيار باقة قبل الإرسال." : "Please select a plan before submitting."
            return
        }

        let draft = buildCurrentDraft()
        let validationError = PPProviderApplicationManager.shared().validate(draft, selectedPlan: plan)
        if let error = validationError {
            errorMessage = error.localizedDescription
            return
        }

        // Duplicate check
        if let blocking = state?.blockingApplication(for: selectedType, planID: plan.planID) {
            errorMessage = String(format: Language.isRTL() ? "يوجد لديك طلب سابق بحالة (%@). يرجى انتظار استكمال مراجعة الطلب الحالي." : "You already have an active application in status (%@).", blocking.status)
            return
        }

        isSubmitting = true
        errorMessage = nil

        PPProviderApplicationManager.shared().submitDraft(draft, selectedPlan: plan) { response, error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPProviderApplicationManager.shared().clearDraft(for: self.selectedType)
                    self.onSubmitted()
                    self.onDismiss()
                }
            }
        }
    }

    // MARK: - Document Scanner & Photo Upload

    private func triggerDocumentScanner(forTag tag: Int) {
        // Look up top view controller to present scanner
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let scanner = PPYesWeScanWrapper()
        activeDocumentTag = tag
        scanner.presentScanner(from: top, withTag: tag)
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.uploadDocumentImage(image, tag: self.activeDocumentTag)
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func uploadDocumentImage(_ image: UIImage, tag: Int) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = Language.isRTL() ? "يرجى تسجيل الدخول مجدداً لإرفاق المستندات" : "Please re-authenticate to upload credentials."
            return
        }

        let isLicense = (tag == 100)
        if isLicense {
            isUploadingLicense = true
        } else {
            isUploadingCR = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let maxDim: CGFloat = 1200.0
            var scaled = image
            if image.size.width > maxDim || image.size.height > maxDim {
                let scale = maxDim / max(image.size.width, image.size.height)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let s = UIGraphicsGetImageFromCurrentImageContext() {
                    scaled = s
                }
                UIGraphicsEndImageContext()
            }

            guard let jpegData = scaled.jpegData(compressionQuality: 0.75) else {
                DispatchQueue.main.async {
                    if isLicense { self.isUploadingLicense = false } else { self.isUploadingCR = false }
                }
                return
            }

            let suffix = isLicense ? "license" : "commercial_reg"
            let path = "provider_applications/\(user.uid)/\(suffix)_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg"

            let storageRef = Storage.storage().reference().child(path)
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"

            storageRef.putData(jpegData, metadata: meta) { _, err in
                if err != nil {
                    DispatchQueue.main.async {
                        if isLicense { self.isUploadingLicense = false } else { self.isUploadingCR = false }
                    }
                    return
                }

                storageRef.downloadURL { url, _ in
                    DispatchQueue.main.async {
                        if isLicense {
                            self.isUploadingLicense = false
                            if let abs = url?.absoluteString { self.licenseDocURL = abs }
                        } else {
                            self.isUploadingCR = false
                            if let abs = url?.absoluteString { self.crDocURL = abs }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reusable Studio Subviews

private struct PPStudioBackgroundView: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // Subtle luminous fluid orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)

                Circle()
                    .fill(Color(hex: "#10B981").opacity(0.04))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.4)
            }
        }
    }
}

private struct PPStudioStepBar: View {
    @Binding var currentStep: PPPartnerStudioStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PPPartnerStudioStep.allCases) { step in
                let isActive = step.rawValue == currentStep.rawValue
                let isPast = step.rawValue < currentStep.rawValue

                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color(.tertiarySystemFill)))
                            .frame(width: 22, height: 22)
                        if isPast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(PPBrandFont.bold(11, relativeTo: .caption2))
                                .foregroundStyle(isActive ? Color.white : Color(.secondaryLabel))
                        }
                    }

                    if isActive {
                        Text(step.localizedTitle)
                            .font(PPBrandFont.bold(12, relativeTo: .caption))
                            .foregroundStyle(Color(.label))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, isActive ? 10 : 4)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                .clipShape(Capsule())

                if step.rawValue < PPPartnerStudioStep.allCases.count - 1 {
                    Rectangle()
                        .fill(isPast ? Color.green.opacity(0.5) : Color(.separator).opacity(0.4))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct PPStudioTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var symbol: String? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                .foregroundStyle(Color(.secondaryLabel))

            HStack(spacing: 10) {
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                        .frame(width: 20)
                }

                TextField(placeholder, text: $text)
                    .font(PPBrandFont.medium(15, relativeTo: .body))
                    .keyboardType(keyboardType)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.8)
            )
        }
    }
}

private struct PPStudioDocumentUploadCard: View {
    let title: String
    let numberPlaceholder: String
    @Binding var number: String
    @Binding var documentURL: String
    let isUploading: Bool
    let onScanTapped: () -> Void
    let onPickPhotoTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(PPBrandFont.bold(14, relativeTo: .subheadline))
                .foregroundStyle(Color(.label))

            TextField(numberPlaceholder, text: $number)
                .font(PPBrandFont.medium(15, relativeTo: .body))
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.8)
                )

            // Attachment Zone
            if isUploading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(Language.isRTL() ? "جارٍ رفع المستند والتدقيق..." : "Uploading document...")
                        .font(PPBrandFont.medium(13, relativeTo: .body))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if !documentURL.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "تم إرفاق المستند بنجاح" : "Document Attached")
                            .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(.label))
                        Text(Language.isRTL() ? "انقر للحذف أو إعادة الرفع" : "Tap to remove or re-upload")
                            .font(PPBrandFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    Button {
                        documentURL = ""
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.red)
                            .padding(8)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Button(action: onScanTapped) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.viewfinder.fill")
                            Text(Language.isRTL() ? "مسح ضوئي للكاميرا" : "Scan via Camera")
                                .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onPickPhotoTapped) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                            Text(Language.isRTL() ? "اختيار صورة" : "Pick Photo")
                                .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(Color(.label))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PPReviewRow: View {
    let title: String
    let value: String
    var isVerified: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(PPBrandFont.medium(13, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            HStack(spacing: 6) {
                Text(value.isEmpty ? "-" : value)
                    .font(PPBrandFont.bold(13, relativeTo: .body))
                    .foregroundStyle(Color(.label))
                if isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.green)
                }
            }
        }
    }
}

// Flow layout helper for wrapping area tags
private struct PPWrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowMaxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowMaxH + verticalSpacing
                rowMaxH = 0
            }
            rowMaxH = max(rowMaxH, size.height)
            currentX += size.width + horizontalSpacing
        }
        height = currentY + rowMaxH
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowMaxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowMaxH + verticalSpacing
                rowMaxH = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowMaxH = max(rowMaxH, size.height)
            currentX += size.width + horizontalSpacing
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Objective-C UIHostingController Bridge

@objc(PPBecomePartnerStudioHostingController)
public final class PPBecomePartnerStudioHostingController: UIViewController {
    private let state: PPProviderOnboardingState?
    private let eligibleTypes: [NSNumber]
    private let preferredType: PPProviderType
    private var onSubmittedHandler: (() -> Void)?
    private var onDismissHandler: (() -> Void)?

    @objc public init(
        state: PPProviderOnboardingState?,
        eligibleTypes: [NSNumber],
        preferredType: PPProviderType,
        onSubmitted: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.state = state
        self.eligibleTypes = eligibleTypes
        self.preferredType = preferredType
        self.onSubmittedHandler = onSubmitted
        self.onDismissHandler = onDismiss
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        let mappedTypes: [PPProviderType] = eligibleTypes.compactMap {
            PPProviderType(rawValue: $0.intValue)
        }

        let studioView = PPBecomePartnerStudioSheet(
            state: self.state,
            eligibleTypes: mappedTypes,
            preferredType: self.preferredType,
            onSubmitted: { [weak self] in
                self?.onSubmittedHandler?()
            },
            onDismiss: { [weak self] in
                if let dismiss = self?.onDismissHandler {
                    dismiss()
                } else {
                    self?.dismiss(animated: true, completion: nil)
                }
            }
        )

        let host = UIHostingController(rootView: studioView)
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
