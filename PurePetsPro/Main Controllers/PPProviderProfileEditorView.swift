//
//  PPProviderProfileEditorView.swift
//  PurePetsPro
//
//  First-Principles Category-Defining Reinvention: Commercial Company & Facility Studio (NextGen V9).
//  Built to flagship Apple standards:
//  - Sovereign Non-Clipping Navigation Bar with live adaptive status & tactile RTL glass back button
//  - Photorealistic Qatar Consumer Storefront Hologram with artistic branded empty states & live customer simulator
//  - Integrated Visual Identity & Media Studio unifying Official Brand Logo & Multi-Cover Showcase Reel
//  - Fluid Commercial Identity Console (Trade Name, Official Hotline, Verified Classification Card)
//  - Geographic Coverage & Interactive Qatar City Selection Chamber
//  - Dedicated Personal User Profile Gateway Card (one-tap bridge to operator settings)
//  - Intelligent Floating Command Dock with radiant primary save action & certified status reassurance
//  - iPad: 2-Column Spatial Cockpit (46% Media & Identity Studio, 54% Sticky Consumer Hologram)
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
            // Keep updated city title if changed via picker sheet
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
        guard canSave, !isSaving else { return }
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
            let availableWidth = geometry.size.width

            ZStack(alignment: .top) {
                Color(uiColor: .ppBackground)
                    .ignoresSafeArea()

                // Ambient Radial Atmospheric Lighting (Bounded & Clipped)
                ambientAtmosphericLighting(width: availableWidth, height: geometry.size.height)

                VStack(spacing: 0) {
                    // Sovereign Navigation Bar
                    sovereignNavigationBar
                        .frame(width: availableWidth)

                    if isPad {
                        iPadSpatialCockpitLayout(geometry: geometry)
                            .frame(width: availableWidth)
                    } else {
                        iPhoneSensoryDeckLayout(width: availableWidth)
                    }
                }
                .frame(width: availableWidth)

                // Sticky Command Save Dock
                VStack {
                    Spacer()
                    stickyCommandDock
                        .frame(width: availableWidth)
                }
                .frame(width: availableWidth)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .frame(width: availableWidth, height: geometry.size.height, alignment: .top)
            .clipped()
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear {
            PPBrandFont.registerIfNeeded()
        }
    }

    // MARK: - Ambient Atmospheric Lighting

    private func ambientAtmosphericLighting(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(uiColor: .ppPrimary).opacity(colorScheme == .dark ? 0.16 : 0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: min(width * 0.9, 360), height: min(width * 0.9, 360))
                .offset(x: Language.isRTL() ? 60 : -60, y: -180)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(colorScheme == .dark ? 0.12 : 0.05), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: min(width * 0.8, 300), height: min(width * 0.8, 300))
                .offset(x: Language.isRTL() ? -50 : 50, y: 220)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - iPhone Sensory Deck Layout

    private func iPhoneSensoryDeckLayout(width: CGFloat) -> some View {
        let cardWidth = max(0, width - 32)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                // 1. Live Customer Storefront Hologram (Mirrors Consumer App)
                liveStorefrontMirrorCard
                    .padding(.top, 4)

                // 2. Integrated Visual Identity & Media Studio
                mediaManagementStageCard

                // 3. Commercial Brand Identity & Credentials Deck
                brandIdentityCard

                // 4. Geographic Coverage & Qatar City Selector
                geographicPresenceCard

                // 5. Dedicated Personal User Profile Bridge Card
                userProfileGatewayCard

                // Generous Breathing Space for Sticky Save Dock
                Spacer().frame(height: 96)
            }
            .frame(width: cardWidth)
            .padding(.horizontal, 16)
            .frame(width: width)
        }
        .frame(width: width)
    }

    // MARK: - iPad Spatial Cockpit Layout

    private func iPadSpatialCockpitLayout(geometry: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Leading Wing: Media Studio, Brand Identity, City & Personal Bridge (46%)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    mediaManagementStageCard
                    brandIdentityCard
                    geographicPresenceCard
                    userProfileGatewayCard
                    Spacer().frame(height: 96)
                }
                .padding(.top, 4)
            }
            .frame(width: max(geometry.size.width * 0.46, 340))

            // Trailing Wing: Live Customer Storefront Hologram (54%)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    liveStorefrontMirrorCard
                    Spacer().frame(height: 96)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Sovereign Navigation Bar (Resilient, Non-Clipping)

    private var sovereignNavigationBar: some View {
        HStack(spacing: 12) {
            // Circular Glass Back Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onDismiss?()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(uiColor: .ppSurface))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.85), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 5, y: 2)

                    Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Language.get("Back", alter: "رجوع"))

            // Title & Subtitle Stack with Badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Language.isRTL() ? "استوديو ملف المنشأة" : "Company & Facility Studio")
                        .font(PPFont.bold(17, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("FACILITY")
                        .font(.system(size: 9, weight: .black))
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
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.3), radius: 3, y: 1)
                }

                Text(Language.isRTL()
                     ? "الهوية التجارية والمعرض • دولة قطر"
                     : "Commercial brand and showcase • Qatar"
                )
                .font(PPFont.regular(11, relativeTo: .caption2))
                .foregroundColor(Color(uiColor: .ppTextSecondary))
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Trailing Adaptive Action / Status Pill
            if viewModel.hasEdits {
                Button {
                    viewModel.saveTriggered()
                } label: {
                    HStack(spacing: 5) {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text(Language.isRTL() ? "حفظ" : "Save")
                                .font(PPFont.bold(12, relativeTo: .caption))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color(uiColor: .ppPrimary).opacity(0.35), radius: 4, y: 1.5)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isSaving)
            } else if !viewModel.snapshot.providerTypeTitle.isEmpty {
                // Controlled Non-Clipping Facility Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary))
                        .frame(width: 5, height: 5)
                    Text(viewModel.snapshot.providerTypeTitle)
                        .font(PPFont.bold(10.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    // MARK: - 1. Live Customer Storefront Hologram (Mirrors Consumer App)

    private var liveStorefrontMirrorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Live Pulse Beacon
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(Language.isRTL() ? "معاينة واجهة المنشأة في تطبيق العملاء" : "Customer Storefront Simulator")
                            .font(PPFont.bold(14.5, relativeTo: .headline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text(Language.isRTL() ? "مباشر في قطر" : "LIVE QATAR")
                                .font(.system(size: 8.5, weight: .heavy))
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
                    .font(PPFont.regular(10.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                Spacer()
            }

            // Customer Perspective Showcase Vessel
            VStack(spacing: 0) {
                // 16:9 Living Cover Stage
                ZStack(alignment: .bottomLeading) {
                    let covers = viewModel.snapshot.coverURLs
                    let activeCoverUrl = covers.indices.contains(viewModel.selectedCoverIndex)
                        ? covers[viewModel.selectedCoverIndex]
                        : covers.first

                    if let activeCover = activeCoverUrl, let url = URL(string: activeCover), !activeCover.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                simulatorCoverArtisticPlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 175)
                        .clipped()
                    } else {
                        simulatorCoverArtisticPlaceholder
                            .frame(maxWidth: .infinity)
                            .frame(height: 175)
                    }

                    // Scrim Vignette Gradient for Crisp Typography
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.4), Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Top Floating Status Badges
                    VStack {
                        HStack {
                            // Operational Status Pill with Glowing Emerald Beacon
                            HStack(spacing: 5) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text(Language.isRTL() ? "مفتوح ويستقبل الطلبات" : "Open for Orders")
                                    .font(PPFont.bold(10, relativeTo: .caption2))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule().fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.black.opacity(0.55)))
                            }

                            Spacer()

                            // Rating Simulation Pill
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.yellow)
                                Text("5.0")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule().fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.black.opacity(0.55)))
                            }
                        }
                        Spacer()
                    }
                    .padding(10)

                    // Superimposed Brand Logo & Title on Cover
                    HStack(spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 54, height: 54)
                                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)

                            if let avatarStr = viewModel.snapshot.avatarURL, let url = URL(string: avatarStr), !avatarStr.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        facilityAvatarFallback
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            } else {
                                facilityAvatarFallback
                                    .frame(width: 48, height: 48)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2.5) {
                            HStack(spacing: 5) {
                                Text(viewModel.editedDisplayName.isEmpty
                                     ? (Language.isRTL() ? "اسم المنشأة التجاري" : "Commercial Trade Name")
                                     : viewModel.editedDisplayName
                                )
                                .font(PPFont.bold(15.5, relativeTo: .headline))
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
                                    .foregroundColor(.white.opacity(0.95))
                                }

                                Text("•")
                                    .foregroundColor(.white.opacity(0.5))

                                Text(viewModel.snapshot.providerTypeTitle.isEmpty
                                     ? (Language.isRTL() ? "مزود معتمد في قطر" : "Qatar Verified")
                                     : viewModel.snapshot.providerTypeTitle
                                )
                                .font(PPFont.medium(10, relativeTo: .caption2))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(11)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 175)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(uiColor: .ppElevatedSurface))
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
            )

            // Reassurance Footer Note
            HStack(spacing: 5) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(uiColor: .ppPrimary))
                Text(Language.isRTL()
                     ? "تتحدث هذه المعاينة فورياً مع كل تعديل تجريه في بيانات المنشأة."
                     : "This preview updates instantly with your edits below."
                )
                .font(PPFont.regular(10, relativeTo: .caption2))
                .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 8, y: 2)
    }

    // MARK: - Artistic Empty State for Storefront Cover

    private var simulatorCoverArtisticPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .ppPrimary).opacity(colorScheme == .dark ? 0.45 : 0.28),
                    Color.purple.opacity(colorScheme == .dark ? 0.35 : 0.18),
                    Color(uiColor: .ppBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                Text(Language.isRTL()
                     ? "صورة الغلاف تمنح متجرك حضوراً مميزاً أمام العملاء"
                     : "Cover photos give your storefront a standout presence"
                )
                .font(PPFont.medium(11.5, relativeTo: .caption))
                .foregroundColor(Color(uiColor: .ppTextPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - 2. Integrated Visual Identity & Media Studio

    private var mediaManagementStageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "الهوية البصرية ومعرض المتجر" : "Visual Identity & Showcase",
                subtitle: Language.isRTL() ? "إدارة الشعار التجاري وصور الغلاف الترويجية" : "Manage official commercial logo and promotional covers",
                symbol: "photo.stack.fill"
            )

            // A. Official Commercial Logo Module
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
                                    lineWidth: 2.2
                                )
                                .frame(width: 70, height: 70)

                            if let avatarStr = viewModel.snapshot.avatarURL, let url = URL(string: avatarStr), !avatarStr.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        facilityAvatarFallback
                                    }
                                }
                                .frame(width: 62, height: 62)
                                .clipShape(Circle())
                            } else {
                                facilityAvatarFallback
                                    .frame(width: 62, height: 62)
                            }
                        }

                        // Floating Camera Badge
                        ZStack {
                            Circle().fill(Color(uiColor: .ppPrimary))
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color(uiColor: .ppSurface), lineWidth: 2))
                        .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(Language.isRTL() ? "الشعار التجاري الرسمي للمنشأة" : "Official Commercial Logo")
                        .font(PPFont.bold(14, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(Language.isRTL()
                         ? "يظهر في بطاقات البحث والواجهة الرئيسية لمتجرك."
                         : "Appears in search results and customer storefront header."
                    )
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                    .lineLimit(2)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.onChangeAvatar?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                            Text(Language.isRTL() ? "تغيير الشعار" : "Change Logo")
                                .font(PPFont.bold(11, relativeTo: .caption2))
                        }
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color(uiColor: .ppPrimary).opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 0.8)
            )

            // B. Showcase Covers Reel
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Language.isRTL() ? "صور الغلاف الترويجية" : "Promotional Cover Photos")
                        .font(PPFont.bold(13, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Spacer()

                    Text(String(format: Language.isRTL() ? "(%d / 5 صور)" : "(%d / 5 photos)", viewModel.snapshot.coverURLs.count))
                        .font(PPFont.medium(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                }

                if !viewModel.snapshot.coverURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.snapshot.coverURLs.enumerated()), id: \.offset) { index, urlStr in
                                ZStack(alignment: .topTrailing) {
                                    if let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                coverThumbnailFallback
                                            }
                                        }
                                        .frame(width: 140, height: 86)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    } else {
                                        coverThumbnailFallback
                                            .frame(width: 140, height: 86)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }

                                    // Delete Cover Badge
                                    Button {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        viewModel.onRemoveCover?(index)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 22, height: 22)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(6)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            viewModel.selectedCoverIndex == index
                                                ? Color(uiColor: .ppPrimary)
                                                : Color(uiColor: .ppSurfaceBorder).opacity(0.8),
                                            lineWidth: viewModel.selectedCoverIndex == index ? 2 : 1
                                        )
                                )
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.selectedCoverIndex = index
                                }
                            }

                            // Add More Card if under limit
                            if viewModel.snapshot.coverURLs.count < 5 {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.onAddCover?()
                                } label: {
                                    VStack(spacing: 5) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Color(uiColor: .ppPrimary))
                                        }
                                        Text(Language.isRTL() ? "إضافة غلاف" : "Add Cover")
                                            .font(PPFont.bold(11, relativeTo: .caption2))
                                            .foregroundColor(Color(uiColor: .ppPrimary))
                                    }
                                    .frame(width: 110, height: 86)
                                    .background(Color(uiColor: .ppPrimary).opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                Color(uiColor: .ppPrimary).opacity(0.35),
                                                style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    // Welcoming Hero Add Cover Banner (No duplicate 180pt box!)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.onAddCover?()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Language.isRTL() ? "إضافة أول صورة غلاف للمنشأة" : "Add First Storefront Cover")
                                    .font(PPFont.bold(13.5, relativeTo: .subheadline))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                                Text(Language.isRTL()
                                     ? "أبعاد الغلاف الموصى بها: 16:9 لعرض جذاب أمام العملاء."
                                     : "Recommended ratio: 16:9 for optimal customer presentation."
                                )
                                .font(PPFont.regular(10.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                            }

                            Spacer(minLength: 0)

                            Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                        .padding(12)
                        .background(Color(uiColor: .ppPrimary).opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    Color(uiColor: .ppPrimary).opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 8, y: 2)
    }

    private var coverThumbnailFallback: some View {
        ZStack {
            Color(uiColor: .ppElevatedSurface)
            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundColor(Color(uiColor: .ppTextSecondary))
        }
    }

    private var facilityAvatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .ppPrimary).opacity(0.15))
            Image(systemName: "building.2.fill")
                .font(.system(size: 24))
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

            // Trade Name Input
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "الاسم التجاري المعتمد للمنشأة" : "Official Commercial Trade Name")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                    Text("*")
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                HStack(spacing: 10) {
                    Image(systemName: "building.2.fill")
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

            // Public Hotline / Phone Input
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

            // Official Classification Verified Banner
            if !viewModel.snapshot.providerTypeTitle.isEmpty {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(Language.isRTL() ? "تصنيف المنشأة المعتمد في المنصة" : "Platform Verified Classification")
                            .font(PPFont.medium(10.5, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                        Text(viewModel.snapshot.providerTypeTitle)
                            .font(PPFont.bold(12.5, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 8, y: 2)
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
                        .font(PPFont.bold(14.5, relativeTo: .body))
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
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 8, y: 2)
    }

    // MARK: - 5. Dedicated Personal User Profile Bridge Card

    private var userProfileGatewayCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.onOpenUserProfile?()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(uiColor: .ppPrimary).opacity(0.25), lineWidth: 1)
                        )

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                VStack(alignment: .leading, spacing: 2) {
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
                         ? "تعديل اسم المشغل، البريد، تفضيلات المظهر واللغة"
                         : "Manage operator credentials, theme, language and account security")
                        .font(PPFont.regular(10.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Reusable Section Header

    private func sectionHeaderView(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PPFont.bold(14.5, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                Text(subtitle)
                    .font(PPFont.regular(10.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            Spacer()
        }
    }

    // MARK: - Intelligent Sticky Command Save Dock

    private var stickyCommandDock: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(uiColor: .ppSurfaceBorder).opacity(0.7))

            if viewModel.hasEdits {
                // Active Saving Button
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
                            Text(Language.isRTL() ? "اعتماد وحفظ بيانات المنشأة" : "Save Facility Changes")
                                .font(PPFont.bold(15, relativeTo: .headline))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(
                        color: Color(uiColor: .ppPrimary).opacity(0.35),
                        radius: 8,
                        y: 3
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isSaving)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
            } else {
                // Certified & Saved Reassurance Capsule (Eliminates ugly disabled grey slab)
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)

                    Text(Language.isRTL() ? "جميع بيانات المنشأة معتمدة ومحفوظة رسمياً" : "All facility profile data is verified & saved")
                        .font(PPFont.bold(12.5, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(uiColor: .ppSurface).opacity(0.90), in: Capsule())
                .overlay(Capsule().stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 0.8))
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
        .background(
            Color(uiColor: .ppBackground).opacity(0.94)
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
        view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage

        let swiftUIView = PPProviderProfileEditorView(viewModel: viewModel)
        let host = UIHostingController(rootView: swiftUIView)
        host.view.backgroundColor = .clear
        host.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage
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
