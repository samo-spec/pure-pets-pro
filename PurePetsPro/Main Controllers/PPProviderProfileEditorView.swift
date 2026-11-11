//
//  PPProviderProfileEditorView.swift
//  PurePetsPro
//
//  First-Principles Invention: Category-Defining Commercial Company & Facility Studio (NextGen V9).
//  Completely separated from the personal user account profile:
//  - Sovereign Studio Navigation Bar with live facility category badge
//  - Photorealistic Consumer Storefront Hologram mirroring live presence in the Qatar customer app
//  - Living Multi-Cover Parallax Carousel with media management & delete actions
//  - Focal Brand Logo Studio with iridescent halo ring & instant camera cropping
//  - Tactile Commercial Identity Console (Trade Name, Official Hotline, Classification Pill)
//  - Geographic Coverage & Interactive Qatar City Selection Chamber
//  - Dedicated Personal User Profile Bridge Card (one-tap switch to operator settings)
//  - Intelligent Sticky Command Dock with non-blocking adaptive saving & haptics
//  - iPad: 2-Column Spatial Cockpit (46% Brand Identity & Media Management, 54% Live Consumer Hologram)
//

import SwiftUI
import UIKit

// MARK: - Snapshot Model for Objective-C Bridge

@objc(PPProviderProfileEditorSnapshot)
public final class PPProviderProfileEditorSnapshot: NSObject {
    @objc public let displayName: String
    @objc public let phone: String
    @objc public let cityID: String
    @objc public let cityTitle: String
    @objc public let providerTypeTitle: String
    @objc public let avatarURL: String?
    @objc public let coverURLs: [String]
    @objc public let hasActiveProfile: Bool
    @objc public let statusTitle: String

    @objc public init(
        displayName: String,
        phone: String,
        cityID: String,
        cityTitle: String,
        providerTypeTitle: String,
        avatarURL: String?,
        coverURLs: [String],
        hasActiveProfile: Bool,
        statusTitle: String
    ) {
        self.displayName = displayName
        self.phone = phone
        self.cityID = cityID
        self.cityTitle = cityTitle
        self.providerTypeTitle = providerTypeTitle
        self.avatarURL = avatarURL
        self.coverURLs = coverURLs
        self.hasActiveProfile = hasActiveProfile
        self.statusTitle = statusTitle
        super.init()
    }
}

// MARK: - View Model

@MainActor
final class PPProviderProfileEditorViewModel: ObservableObject {
    @Published var snapshot: PPProviderProfileEditorSnapshot
    @Published var editedDisplayName: String
    @Published var editedPhone: String
    @Published var editedCityID: String
    @Published var editedCityTitle: String
    @Published var isSaving: Bool = false
    @Published var selectedCoverIndex: Int = 0

    var onSave: ((String, String, String, String?, [String]) -> Void)?
    var onChangeAvatar: (() -> Void)?
    var onAddCover: (() -> Void)?
    var onRemoveCover: ((Int) -> Void)?
    var onChangeCity: (() -> Void)?
    var onOpenUserProfile: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(snapshot: PPProviderProfileEditorSnapshot) {
        self.snapshot = snapshot
        self.editedDisplayName = snapshot.displayName
        self.editedPhone = snapshot.phone
        self.editedCityID = snapshot.cityID
        self.editedCityTitle = snapshot.cityTitle
    }

    func updateSnapshot(_ newSnapshot: PPProviderProfileEditorSnapshot) {
        let wasEditing = hasEdits
        self.snapshot = newSnapshot
        if !wasEditing {
            self.editedDisplayName = newSnapshot.displayName
            self.editedPhone = newSnapshot.phone
            self.editedCityID = newSnapshot.cityID
            self.editedCityTitle = newSnapshot.cityTitle
        } else {
            // Keep updated city title if changed via sheet
            if newSnapshot.cityID == self.editedCityID {
                self.editedCityTitle = newSnapshot.cityTitle
            }
        }
    }

    var hasEdits: Bool {
        let nameChanged = editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) != snapshot.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneChanged = editedPhone.trimmingCharacters(in: .whitespacesAndNewlines) != snapshot.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityChanged = editedCityID != snapshot.cityID
        return nameChanged || phoneChanged || cityChanged
    }

    var canSave: Bool {
        !editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveTriggered() {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSaving = true
        onSave?(
            editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            editedPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            editedCityID,
            snapshot.avatarURL,
            snapshot.coverURLs
        )
    }
}

// MARK: - Root View

public struct PPProviderProfileEditorView: View {
    @ObservedObject var viewModel: PPProviderProfileEditorViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: PPProviderProfileEditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > 680

            ZStack {
                Color(uiColor: .ppBackground)
                    .ignoresSafeArea()

                // Ambient Radial Lighting
                ambientAtmosphericLighting

                VStack(spacing: 0) {
                    // Sovereign Navigation Bar
                    sovereignNavigationBar

                    if isPad {
                        iPadSpatialCockpitLayout(geometry: geometry)
                    } else {
                        iPhoneSensoryDeckLayout
                    }
                }

                // Sticky Command Save Dock
                VStack {
                    Spacer()
                    stickyCommandDock
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }

    // MARK: - Ambient Atmospheric Lighting

    private var ambientAtmosphericLighting: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(uiColor: .ppPrimary).opacity(colorScheme == .dark ? 0.16 : 0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 480, height: 480)
                .offset(x: Language.isRTL() ? 140 : -140, y: -220)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(colorScheme == .dark ? 0.12 : 0.05), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: Language.isRTL() ? -130 : 130, y: 300)
                .allowsHitTesting(false)
        }
    }

    // MARK: - iPhone Sensory Deck Layout

    private var iPhoneSensoryDeckLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                // 1. Live Customer Storefront Hologram (Mirrors Consumer App)
                liveStorefrontMirrorCard
                    .padding(.top, 4)

                // 2. Living Media Management Deck (Covers & Logo)
                mediaManagementStageCard

                // 3. Commercial Brand Identity & Credentials Deck
                brandIdentityCard

                // 4. Geographic Coverage & Qatar City Selector
                geographicPresenceCard

                // 5. Dedicated Personal User Profile Bridge Card
                userProfileGatewayCard

                // Breathing Room for Sticky Save Dock
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - iPad Spatial Cockpit Layout

    private func iPadSpatialCockpitLayout(geometry: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Leading Wing: Brand Identity, City, Media & User Profile Bridge (46%)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    mediaManagementStageCard
                    brandIdentityCard
                    geographicPresenceCard
                    userProfileGatewayCard
                    Spacer().frame(height: 90)
                }
                .padding(.top, 4)
            }
            .frame(width: max(geometry.size.width * 0.46, 340))

            // Trailing Wing: Live Customer Storefront Hologram (54%)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    liveStorefrontMirrorCard
                    Spacer().frame(height: 90)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Sovereign Navigation Bar

    private var sovereignNavigationBar: some View {
        HStack(spacing: 12) {
            // Circular Glass Back Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onDismiss?()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .ppSurface))
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, y: 2)

                    Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Language.get("Back", alter: "رجوع"))

            // Title Stack with Studio Badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Language.isRTL() ? "استوديو ملف المنشأة" : "Company & Facility Studio")
                        .font(PPFont.bold(18, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text("FACILITY")
                        .font(.system(size: 9.5, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary), Color.purple.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.3), radius: 4, y: 1.5)
                }

                Text(Language.isRTL()
                     ? "تخصيص الهوية التجارية، المعرض ونطاق الخدمة في دولة قطر"
                     : "Configure commercial brand, gallery showcase and Qatar coverage"
                )
                .font(PPFont.regular(11.5, relativeTo: .caption2))
                .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            Spacer()

            // Facility Classification Pill
            if !viewModel.snapshot.providerTypeTitle.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary))
                        .frame(width: 5, height: 5)
                    Text(viewModel.snapshot.providerTypeTitle)
                        .font(PPFont.bold(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(uiColor: .ppBackground).opacity(0.92)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - 1. Live Customer Storefront Hologram (Mirrors Consumer App)

    private var liveStorefrontMirrorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Live Pulse Beacon
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(Language.isRTL() ? "معاينة واجهة المنشأة في تطبيق العملاء" : "Live Storefront Customer Simulator")
                            .font(PPFont.bold(15, relativeTo: .headline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text(Language.isRTL() ? "حي ومباشر" : "LIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Text(Language.isRTL()
                         ? "محاكاة واقعية لما يظهر للعملاء في تطبيق بيور بتس قطر."
                         : "Real-time preview of how customers in Qatar see this storefront."
                    )
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                Spacer()
            }

            // Customer Perspective Showcase Vessel
            VStack(spacing: 0) {
                // 16:9 Living Cover Stage
                ZStack(alignment: .bottomLeading) {
                    if let firstCover = viewModel.snapshot.coverURLs.first, let url = URL(string: firstCover), !firstCover.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                coverFallbackGraphic
                            }
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        coverFallbackGraphic
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    // Scrim Vignette Gradient
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Top Floating Status Badges
                    VStack {
                        HStack {
                            // Online Availability Pill
                            HStack(spacing: 5) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text(Language.isRTL() ? "مفتوح ويستقبل الطلبات" : "Open for Orders")
                                    .font(PPFont.bold(10.5, relativeTo: .caption2))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55), in: Capsule())

                            Spacer()

                            // Rating Simulation Pill
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text("5.0")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(12)

                    // Superimposed Brand Logo & Title on Cover
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)

                            if let avatarStr = viewModel.snapshot.avatarURL, let url = URL(string: avatarStr), !avatarStr.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        facilityAvatarFallback
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                            } else {
                                facilityAvatarFallback
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(viewModel.editedDisplayName.isEmpty
                                     ? (Language.isRTL() ? "اسم المنشأة التجاري" : "Commercial Trade Name")
                                     : viewModel.editedDisplayName
                                )
                                .font(PPFont.bold(16, relativeTo: .headline))
                                .foregroundColor(.white)
                                .lineLimit(1)

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                            }

                            HStack(spacing: 6) {
                                if !viewModel.editedCityTitle.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 9.5))
                                        Text(viewModel.editedCityTitle)
                                            .font(PPFont.bold(10.5, relativeTo: .caption2))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                }

                                Text("•")
                                    .foregroundColor(.white.opacity(0.6))

                                Text(Language.isRTL() ? "مزود معتمد في قطر" : "Qatar Verified")
                                    .font(PPFont.medium(10, relativeTo: .caption2))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                }

                // Customer Action Bar Simulator
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                        Text(viewModel.editedPhone.isEmpty ? "+974 XXXXXXXX" : viewModel.editedPhone)
                            .font(PPFont.bold(11.5, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 11))
                        Text(Language.isRTL() ? "تصفح الخدمات والمنتجات" : "Browse Store")
                            .font(PPFont.bold(11, relativeTo: .caption2))
                    }
                    .foregroundColor(Color(uiColor: .ppPrimary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .ppElevatedSurface))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    // MARK: - 2. Living Media Management Deck

    private var mediaManagementStageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "معرض الصور والشعار التجاري" : "Showcase Covers & Brand Logo",
                subtitle: Language.isRTL() ? "إدارة صور غلاف المتجر والشعار الرسمي المعتمد" : "Manage high-resolution storefront covers and brand logo",
                symbol: "photo.on.rectangle.angled"
            )

            // Multi-Cover Carousel & Management
            VStack(spacing: 10) {
                if !viewModel.snapshot.coverURLs.isEmpty {
                    TabView(selection: $viewModel.selectedCoverIndex) {
                        ForEach(Array(viewModel.snapshot.coverURLs.enumerated()), id: \.offset) { index, urlStr in
                            ZStack(alignment: .topTrailing) {
                                if let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            coverFallbackGraphic
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: 180)
                                    .clipped()
                                } else {
                                    coverFallbackGraphic
                                }

                                // Delete Cover Pill
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    viewModel.onRemoveCover?(index)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 11))
                                        Text(Language.isRTL() ? "حذف الصورة" : "Delete")
                                            .font(PPFont.bold(11, relativeTo: .caption2))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.8), in: Capsule())
                                }
                                .padding(10)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    coverFallbackGraphic
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Add Cover Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.onAddCover?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(Language.isRTL() ? "إضافة صورة غلاف جديدة للمنشأة" : "Add Storefront Cover Photo")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                    }
                    .foregroundColor(Color(uiColor: .ppPrimary))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(uiColor: .ppPrimary).opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(uiColor: .ppPrimary).opacity(0.25), lineWidth: 0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color(uiColor: .ppSurfaceBorder))

            // Logo Studio
            HStack(spacing: 14) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.onChangeAvatar?()
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(uiColor: .ppPrimary), Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 66, height: 66)

                            if let avatarStr = viewModel.snapshot.avatarURL, let url = URL(string: avatarStr), !avatarStr.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        facilityAvatarFallback
                                    }
                                }
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                            } else {
                                facilityAvatarFallback
                            }
                        }

                        // Camera Mini Button
                        ZStack {
                            Circle().fill(Color(uiColor: .ppPrimary))
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(Language.isRTL() ? "الشعار التجاري الرسمي للمنشأة" : "Official Commercial Logo")
                        .font(PPFont.bold(14, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(Language.isRTL()
                         ? "انقر على الشعار لتغيير صورة الهوية البصرية من مكتبة الصور."
                         : "Tap logo to choose brand identity image from library."
                    )
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                    .lineLimit(2)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    private var coverFallbackGraphic: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .ppPrimary).opacity(0.25), Color.purple.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(Color(uiColor: .ppPrimary))
                Text(Language.isRTL() ? "لا توجد صور غلاف مضافة حالياً" : "No cover images uploaded yet")
                    .font(PPFont.medium(12, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
        }
    }

    private var facilityAvatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .ppPrimary).opacity(0.15))
                .frame(width: 58, height: 58)
            Image(systemName: "building.2.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(uiColor: .ppPrimary))
        }
    }

    // MARK: - 3. Commercial Brand Identity & Credentials Deck

    private var brandIdentityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "الهوية التجارية وبيانات الاتصال" : "Commercial Identity & Contact",
                subtitle: Language.isRTL() ? "الاسم التجاري المعتمد ورقم هاتف خدمة العملاء" : "Official trade name and public customer service phone",
                symbol: "briefcase.fill"
            )

            // Trade Name
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "الاسم التجاري المعتمد للمنشأة" : "Official Commercial Trade Name")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                    Text("*")
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                HStack(spacing: 10) {
                    Image(systemName: "building.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .frame(width: 20)

                    TextField(
                        Language.isRTL() ? "مثال: مجمع بيور بتس البيطري" : "e.g. PurePets Veterinary Center",
                        text: $viewModel.editedDisplayName
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                    if !viewModel.editedDisplayName.isEmpty {
                        Button {
                            viewModel.editedDisplayName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 0.8))
            }

            // Public Hotline / Phone
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "رقم الهاتف المعتمد للتواصل مع العملاء" : "Customer Support Hotline")
                    .font(PPFont.bold(12, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .frame(width: 20)

                    TextField(
                        "+974 XXXXXXXX",
                        text: $viewModel.editedPhone
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .keyboardType(.phonePad)
                    .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 0.8))
            }
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    // MARK: - 4. Geographic Coverage & Qatar City Selector

    private var geographicPresenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "نطاق التغطية والفرع الرئيسي" : "Geographic Location & Main Branch",
                subtitle: Language.isRTL() ? "المدينة وموقع الفرع الرئيسي داخل دولة قطر" : "Select operating city and delivery coverage in Qatar",
                symbol: "mappin.and.ellipse"
            )

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onChangeCity?()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.editedCityTitle.isEmpty
                             ? (Language.isRTL() ? "اختر المدينة في قطر" : "Select City in Qatar")
                             : viewModel.editedCityTitle
                        )
                        .font(PPFont.bold(15, relativeTo: .body))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                        Text(Language.isRTL() ? "انقر لاختيار المدينة ونطاق الخدمات المعتمد" : "Tap to change service coverage area")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                    }

                    Spacer()

                    Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                .padding(12)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 0.8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    // MARK: - 5. Dedicated Personal User Profile Bridge Card

    private var userProfileGatewayCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.onOpenUserProfile?()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(uiColor: .ppPrimary).opacity(0.25), lineWidth: 1)
                        )

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(Language.isRTL() ? "الحساب والإعدادات الشخصية" : "User Profile & Account")
                            .font(PPFont.bold(14, relativeTo: .subheadline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        Text(Language.isRTL() ? "مدخل مستقل" : "Separate Entry")
                            .font(PPFont.bold(9, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .ppPrimary).opacity(0.10), in: Capsule())
                    }

                    Text(Language.isRTL()
                         ? "تعديل اسم المشغل، البريد الإلكتروني، تفضيلات المظهر واللغة"
                         : "Manage operator credentials, theme, language and account security")
                        .font(PPFont.regular(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(14)
            .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Reusable Section Header

    private func sectionHeaderView(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PPFont.bold(15, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                Text(subtitle)
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            Spacer()
        }
    }

    // MARK: - Intelligent Sticky Command Dock

    private var stickyCommandDock: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(uiColor: .ppSurfaceBorder).opacity(0.7))

            Button {
                viewModel.saveTriggered()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                        Text(Language.isRTL() ? "جارٍ حفظ بيانات المنشأة..." : "Saving Facility Profile...")
                            .font(PPFont.bold(15, relativeTo: .headline))
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(viewModel.hasEdits
                             ? (Language.isRTL() ? "اعتماد وحفظ بيانات المنشأة" : "Save Facility Changes")
                             : (Language.isRTL() ? "البيانات محفوظة ومعتمدة" : "Profile Saved")
                        )
                        .font(PPFont.bold(15, relativeTo: .headline))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    viewModel.hasEdits
                        ? LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(
                    color: viewModel.hasEdits ? Color(uiColor: .ppPrimary).opacity(0.35) : Color.clear,
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.hasEdits || viewModel.isSaving)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(
            Color(uiColor: .ppBackground).opacity(0.92)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Hosting Controller & Bridge

@objc(PPProviderProfileEditorHostController)
public final class PPProviderProfileEditorHostController: UIViewController {
    private let viewModel: PPProviderProfileEditorViewModel
    private var hostingController: UIHostingController<PPProviderProfileEditorView>?

    init(viewModel: PPProviderProfileEditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground

        let swiftUIView = PPProviderProfileEditorView(viewModel: viewModel)
        let host = UIHostingController(rootView: swiftUIView)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        self.hostingController = host
    }

    @objc public func updateSnapshot(_ snapshot: PPProviderProfileEditorSnapshot) {
        viewModel.updateSnapshot(snapshot)
    }

    @objc public func didFinishSaving() {
        viewModel.isSaving = false
    }
}

@objc(PPProviderProfileEditorHostingBridge)
@MainActor
public final class PPProviderProfileEditorHostingBridge: NSObject {
    @objc public static func makeViewController(
        snapshot: PPProviderProfileEditorSnapshot,
        onSave: @escaping (String, String, String, String?, [String]) -> Void,
        onChangeAvatar: @escaping () -> Void,
        onAddCover: @escaping () -> Void,
        onRemoveCover: @escaping (Int) -> Void,
        onChangeCity: @escaping () -> Void,
        onOpenUserProfile: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) -> PPProviderProfileEditorHostController {
        let vm = PPProviderProfileEditorViewModel(snapshot: snapshot)
        vm.onSave = onSave
        vm.onChangeAvatar = onChangeAvatar
        vm.onAddCover = onAddCover
        vm.onRemoveCover = onRemoveCover
        vm.onChangeCity = onChangeCity
        vm.onOpenUserProfile = onOpenUserProfile
        vm.onDismiss = onDismiss

        return PPProviderProfileEditorHostController(viewModel: vm)
    }
}
