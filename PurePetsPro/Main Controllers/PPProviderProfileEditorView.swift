//
//  PPProviderProfileEditorView.swift
//  PurePetsPro
//
//  Category-Defining Beyond-FAANG Provider Studio & Brand Showcase (NextGen V9).
//  Reinvented from absolute first principles:
//  - Living Multi-Cover Parallax Carousel with media management & delete actions
//  - Focal Portrait Studio with iridescent halo ring & instant camera cropping
//  - Tactile Brand Identity Console (Commercial Name, Phone, Category Pill)
//  - Geographic Coverage & Interactive Qatar City Selection Chamber
//  - Live Customer Storefront Mirror simulating real consumer app presence
//  - Intelligent Status Command Dock with non-blocking adaptive saving & spring elevation
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
    @FocusState private var activeField: Int?

    init(viewModel: PPProviderProfileEditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color(uiColor: .ppBackground)
                .ignoresSafeArea()

            // Ambient background lighting
            ambientLightingRims

            VStack(spacing: 0) {
                // Sovereign Navigation Bar
                sovereignNavigationBar

                // Scrollable Studio Canvas
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Living Cover Carousel & Focal Avatar Stage
                        mediaStageCard
                            .padding(.top, 4)

                        // Brand Identity Section
                        brandIdentityCard

                        // Geographic Coverage & City Selector
                        geographicPresenceCard

                        // Live Customer Storefront Mirror
                        liveStorefrontMirrorCard

                        // Breathing room for sticky footer
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Intelligent Sticky Command Dock
            VStack {
                Spacer()
                stickyCommandDock
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }

    // MARK: - Ambient Lighting

    private var ambientLightingRims: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(uiColor: .ppPrimary).opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: Language.isRTL() ? 130 : -130, y: -200)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.06), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 380, height: 380)
                .offset(x: Language.isRTL() ? -120 : 120, y: 260)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Sovereign Navigation Bar

    private var sovereignNavigationBar: some View {
        HStack(spacing: 12) {
            // Squircle Back Button
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
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

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
                    Text(Language.get("ProviderProfileEditor_Title", alter: "استوديو ملف المزود"))
                        .font(Font.custom("Beiruti-Bold", size: 19, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text("STUDIO")
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

                Text(Language.get("ProviderProfileEditor_Subtitle", alter: "تخصيص الهوية التجارية والوسائط للظهور أمام العملاء"))
                    .font(Font.custom("Beiruti-Regular", size: 12, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .ppBackground))
    }

    // MARK: - Living Cover Carousel & Focal Avatar Stage

    private var mediaStageCard: some View {
        VStack(spacing: 12) {
            // 16:9 Cover Media Vessel
            ZStack(alignment: .bottom) {
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
                                    .frame(maxWidth: .infinity, maxHeight: 195)
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
                                        Text(Language.get("Delete", alter: "حذف"))
                                            .font(Font.custom("Beiruti-Bold", size: 11))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65), in: Capsule())
                                }
                                .padding(10)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 195)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    coverFallbackGraphic
                        .frame(height: 195)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                // Vignette Gradient
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)

                // Superimposed Avatar Spotlight
                HStack(alignment: .bottom, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 82, height: 82)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)

                        if let urlStr = viewModel.snapshot.avatarURL, let url = URL(string: urlStr), !urlStr.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    avatarMonogramView
                                }
                            }
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                        } else {
                            avatarMonogramView
                        }

                        // Change Avatar Button Badge
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.onChangeAvatar?()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .ppPrimary))
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                            }
                        }
                        .offset(x: Language.isRTL() ? -26 : 26, y: 26)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.editedDisplayName.isEmpty ? viewModel.snapshot.displayName : viewModel.editedDisplayName)
                            .font(Font.custom("Beiruti-Bold", size: 18, relativeTo: .title3))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(viewModel.snapshot.providerTypeTitle.isEmpty ? Language.get("RoleProvider", alter: "مزود معتمد") : viewModel.snapshot.providerTypeTitle)
                            .font(Font.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()
                }
                .padding(14)
            }
            .frame(height: 195)

            // Add Cover Action Row
            HStack(spacing: 10) {
                // Photo Counter Pill
                HStack(spacing: 5) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .ppPrimary))

                    Text(String(format: Language.get("ProviderProfileEditor_CoverCountFormat", alter: "%lu من 5 صور غلاف"), viewModel.snapshot.coverURLs.count))
                        .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                // Add Cover Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.onAddCover?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold))

                        Text(Language.get("ProviderProfileEditor_AddCoverButton", alter: "إضافة غلاف"))
                            .font(Font.custom("Beiruti-Bold", size: 13.5, relativeTo: .callout))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color(uiColor: .ppPrimary).opacity(0.28), radius: 6, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.snapshot.coverURLs.count >= 5)
                .opacity(viewModel.snapshot.coverURLs.count >= 5 ? 0.5 : 1.0)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var coverFallbackGraphic: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .ppPrimary).opacity(0.20), Color(uiColor: .ppPrimary).opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 38))
                    .foregroundColor(Color(uiColor: .ppPrimary).opacity(0.5))

                Text(Language.get("ProviderProfileEditor_CoverHint", alter: "أضف صور غلاف جذابة لعرض متجرك للعملاء"))
                    .font(Font.custom("Beiruti-Medium", size: 13, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppPrimary).opacity(0.75))
            }
        }
    }

    private var avatarMonogramView: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .ppPrimary).opacity(0.18))
                .frame(width: 76, height: 76)

            Text(String(viewModel.snapshot.displayName.prefix(1)).uppercased())
                .font(Font.custom("Beiruti-Bold", size: 30))
                .foregroundColor(Color(uiColor: .ppPrimary))
        }
    }

    // MARK: - Brand Identity Section

    private var brandIdentityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProviderProfileEditor_IdentitySection", alter: "الهوية التجارية"))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("ProviderProfileEditor_IdentitySubtitle", alter: "اسم المنشأة والتواصل المعتمد للظهور العام أمام العملاء."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            VStack(spacing: 10) {
                // Brand Display Name Field
                studioFieldRow(
                    icon: "building.2.fill",
                    title: Language.get("ProviderProfileEditor_StoreName", alter: "اسم المنشأة / العلامة التجارية"),
                    placeholder: Language.get("ProfileDisplayName", alter: "اسم العرض التجاري"),
                    text: $viewModel.editedDisplayName,
                    tag: 0,
                    keyboard: .default
                )

                // Business Phone Field
                studioFieldRow(
                    icon: "phone.fill",
                    title: Language.get("ProviderProfileEditor_StorePhone", alter: "رقم هاتف المنشأة والتواصل"),
                    placeholder: "+974...",
                    text: $viewModel.editedPhone,
                    tag: 1,
                    keyboard: .phonePad
                )

                // Category & Provider Type Badge
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .ppPrimary).opacity(0.09))
                            .frame(width: 38, height: 38)
                        Image(systemName: "tag.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(Language.get("ProviderTypeLabel", alter: "التصنيف التجاري والنشاط"))
                            .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))

                        Text(viewModel.snapshot.providerTypeTitle.isEmpty ? Language.get("RoleProvider", alter: "مزود معتمد") : viewModel.snapshot.providerTypeTitle)
                            .font(Font.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    Spacer()

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private func studioFieldRow(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>,
        tag: Int,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .ppPrimary).opacity(0.09))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                TextField(placeholder, text: text)
                    .font(Font.custom("Beiruti-Medium", size: 15, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .keyboardType(keyboard)
                    .autocorrectionDisabled(true)
                    .focused($activeField, equals: tag)
            }

            Spacer()

            if !text.wrappedValue.isEmpty && activeField == tag {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    activeField == tag
                        ? Color(uiColor: .ppPrimary)
                        : Color(uiColor: .ppSurfaceBorder).opacity(0.5),
                    lineWidth: activeField == tag ? 1.4 : 1
                )
        )
    }

    // MARK: - Geographic Presence & City Selector

    private var geographicPresenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProviderProfileEditor_LocationSection", alter: "النطاق الجغرافي والمدينة"))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("ProviderProfileEditor_LocationSubtitle", alter: "المدينة المعتمدة لتقديم الخدمات واستلام طلبات العملاء في قطر."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            // City Selector Row
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onChangeCity?()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 38, height: 38)

                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.get("City", alter: "المدينة المعتمدة"))
                            .font(Font.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))

                        Text(viewModel.editedCityTitle.isEmpty ? Language.get("ProviderProfileEditor_ChooseCity", alter: "اختر المدينة") : viewModel.editedCityTitle)
                            .font(Font.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                            .foregroundColor(viewModel.editedCityTitle.isEmpty ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppTextPrimary))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(Language.get("Change", alter: "تغيير"))
                            .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppPrimary))

                        Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .ppPrimary).opacity(0.1), in: Capsule())
                }
                .padding(14)
                .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    // MARK: - Live Customer Storefront Mirror

    private var liveStorefrontMirrorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(uiColor: .ppPrimary))

                Text(Language.get("ProviderProfileEditor_ConsumerPreviewTitle", alter: "معاينة البطاقة في تطبيق المستخدمين"))
                    .font(Font.custom("Beiruti-Bold", size: 15, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
            }

            // Customer View Simulation Mini Card
            HStack(spacing: 12) {
                // Mini Avatar
                ZStack {
                    Circle().fill(Color(uiColor: .ppPrimary).opacity(0.15)).frame(width: 48, height: 48)
                    if let urlStr = viewModel.snapshot.avatarURL, let url = URL(string: urlStr), !urlStr.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Image(systemName: "pawprint.fill").foregroundColor(Color(uiColor: .ppPrimary))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.editedDisplayName.isEmpty ? viewModel.snapshot.displayName : viewModel.editedDisplayName)
                            .font(Font.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                            .lineLimit(1)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    HStack(spacing: 8) {
                        Text(viewModel.editedCityTitle.isEmpty ? Language.get("Qatar", alter: "قطر") : viewModel.editedCityTitle)
                            .font(Font.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))

                        Text("•")
                            .foregroundColor(Color(uiColor: .ppSurfaceBorder))

                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                            Text("5.0")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    }
                }

                Spacer()

                // Live status capsule
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text(Language.get("Active", alter: "نشط"))
                        .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.green.opacity(0.12), in: Capsule())
            }
            .padding(12)
            .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6), lineWidth: 1))
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    // MARK: - Intelligent Sticky Command Dock

    private var stickyCommandDock: some View {
        VStack(spacing: 8) {
            // Adaptive Status Guidance Banner
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.snapshot.hasActiveProfile ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                Text(
                    viewModel.snapshot.hasActiveProfile
                        ? (viewModel.snapshot.statusTitle.isEmpty
                            ? Language.get("ProviderProfileEditor_StatusActive", alter: "ملف المزود معتمد ومفعل للظهور العام للعملاء.")
                            : viewModel.snapshot.statusTitle)
                        : Language.get("ProviderProfileEditor_StatusDraft", alter: "تجهيز الهوية التجارية · يتم حفظ التعديلات في حسابك وتطبيقها تلقائيًا.")
                )
                .font(Font.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                .foregroundColor(Color(uiColor: .ppTextSecondary))
                .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Primary Illuminated Save Button
            Button {
                viewModel.saveTriggered()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text(viewModel.isSaving ? Language.get("Saving", alter: "جاري الحفظ...") : Language.get("ProviderProfileEditor_SaveButton", alter: "حفظ التعديلات"))
                        .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .callout))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    viewModel.canSave
                        ? LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color(uiColor: .ppPrimary).opacity(0.4), Color(uiColor: .ppPrimary).opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(
                    color: viewModel.canSave ? Color(uiColor: .ppPrimary).opacity(0.35) : Color.clear,
                    radius: 10,
                    y: 3
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.canSave || viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            Color(uiColor: .ppSurface)
                .opacity(0.96)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 14, y: -4)
                .ignoresSafeArea(edges: .bottom)
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
        onDismiss: @escaping () -> Void
    ) -> PPProviderProfileEditorHostController {
        let vm = PPProviderProfileEditorViewModel(snapshot: snapshot)
        vm.onSave = onSave
        vm.onChangeAvatar = onChangeAvatar
        vm.onAddCover = onAddCover
        vm.onRemoveCover = onRemoveCover
        vm.onChangeCity = onChangeCity
        vm.onDismiss = onDismiss

        return PPProviderProfileEditorHostController(viewModel: vm)
    }
}
