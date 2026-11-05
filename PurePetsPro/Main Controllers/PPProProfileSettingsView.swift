//
//  PPProProfileSettingsView.swift
//  PurePetsPro
//
//  Category-Defining Beyond-FAANG Profile Settings & Provider Presence Command Center.
//  Reinvented from absolute first principles separately for iPhone and iPad:
//  - Sovereign Command Bar with Pro tier beacon & adaptive dirty-state save trigger
//  - Interactive Living Pro Identity Hero with avatar halo & role pill
//  - Tactile Credentials Deck with instant field validation & haptics
//  - Live Consumer Storefront Simulation Chamber mirroring the user app presence
//  - Integrated System Command Deck (Notifications, Appearance Switcher, Language, Sign Out)
//  - iPad: 2-Column Spatial Cockpit (45% Credentials & Governance, 55% Live Storefront Simulator)
//

import SwiftUI
import UIKit

// MARK: - Snapshot Model for Objective-C Bridge

@objc(PPProProfileSnapshot)
public final class PPProProfileSnapshot: NSObject {
    @objc public let displayName: String
    @objc public let email: String
    @objc public let phone: String
    @objc public let roleName: String
    @objc public let avatarURL: String?
    @objc public let coverURLs: [String]
    @objc public let workspaceTitle: String
    @objc public let statusTitle: String
    @objc public let planSummary: String
    @objc public let currentThemeKey: String
    @objc public let currentLanguageCode: String

    @objc public init(
        displayName: String,
        email: String,
        phone: String,
        roleName: String,
        avatarURL: String?,
        coverURLs: [String],
        workspaceTitle: String,
        statusTitle: String,
        planSummary: String,
        currentThemeKey: String,
        currentLanguageCode: String
    ) {
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.roleName = roleName
        self.avatarURL = avatarURL
        self.coverURLs = coverURLs
        self.workspaceTitle = workspaceTitle
        self.statusTitle = statusTitle
        self.planSummary = planSummary
        self.currentThemeKey = currentThemeKey
        self.currentLanguageCode = currentLanguageCode
        super.init()
    }
}

// MARK: - View Model

@MainActor
final class PPProProfileSettingsViewModel: ObservableObject {
    @Published var snapshot: PPProProfileSnapshot
    @Published var editedName: String
    @Published var editedEmail: String
    @Published var editedPhone: String
    @Published var isSaving: Bool = false
    @Published var showAppearanceSheet: Bool = false
    @Published var showLanguageAlert: Bool = false
    @Published var showLogoutAlert: Bool = false
    @Published var selectedCoverIndex: Int = 0

    var onSave: ((String, String, String) -> Void)?
    var onEditProviderProfile: (() -> Void)?
    var onOpenNotifications: (() -> Void)?
    var onSelectTheme: ((String) -> Void)?
    var onSelectLanguage: ((String) -> Void)?
    var onLogout: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(snapshot: PPProProfileSnapshot) {
        self.snapshot = snapshot
        self.editedName = snapshot.displayName
        self.editedEmail = snapshot.email
        self.editedPhone = snapshot.phone
    }

    func updateSnapshot(_ newSnapshot: PPProProfileSnapshot) {
        self.snapshot = newSnapshot
        if !hasEdits {
            self.editedName = newSnapshot.displayName
            self.editedEmail = newSnapshot.email
            self.editedPhone = newSnapshot.phone
        }
    }

    var hasEdits: Bool {
        let nameChanged = editedName.trimmingCharacters(in: .whitespacesAndNewlines) != snapshot.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailChanged = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines) != snapshot.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneChanged = editedPhone.trimmingCharacters(in: .whitespacesAndNewlines) != snapshot.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return nameChanged || emailChanged || phoneChanged
    }

    var canSave: Bool {
        !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveTriggered() {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSaving = true
        onSave?(
            editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            editedEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            editedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - Root View

public struct PPProProfileSettingsView: View {
    @ObservedObject var viewModel: PPProProfileSettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: PPProProfileSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > 640

            ZStack {
                Color(uiColor: .ppBackground)
                    .ignoresSafeArea()

                if isPad {
                    iPadProProfileSpatialCockpit(viewModel: viewModel)
                } else {
                    iPhoneProProfileSensoryDeck(viewModel: viewModel)
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }
}

// MARK: - ==========================================
// MARK: - IPHONE: SENSORY DECK ARCHITECTURE
// MARK: - ==========================================

private struct iPhoneProProfileSensoryDeck: View {
    @ObservedObject var viewModel: PPProProfileSettingsViewModel
    @FocusState private var activeField: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Sovereign Navigation Deck
            sovereignNavigationBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Luminous Pro Identity Hero
                    proIdentityHeroCard
                        .padding(.top, 8)

                    // Tactical Credentials Deck
                    credentialsDeckCard

                    // Live Consumer Storefront Simulation Chamber
                    storefrontSimulationChamber

                    // Pro System Preferences Dock
                    systemPreferencesDock

                    // Safe Bottom Breathing Space
                    Spacer().frame(height: 36)
                }
                .padding(.horizontal, 16)
            }
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

            // Title Stack with Pro Beacon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Language.get("ProfileSettings", alter: "إعدادات الملف الشخصي"))
                        .font(Font.custom("Beiruti-Bold", size: 18, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    // Pro Tier Capsule
                    Text("PRO")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color(uiColor: .ppPrimary), in: Capsule())
                }

                Text(Language.get("ProfileSettings_Eyebrow", alter: "حساب بيور بتس برو"))
                    .font(Font.custom("Beiruti-Regular", size: 12, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            Spacer()

            // Dynamic Illuminated Save Action Pill
            Button {
                viewModel.saveTriggered()
            } label: {
                HStack(spacing: 5) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.75)
                    } else if viewModel.hasEdits {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }

                    Text(Language.get("Save", alter: "حفظ"))
                        .font(Font.custom("Beiruti-Bold", size: 14, relativeTo: .callout))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    viewModel.hasEdits
                        ? Color(uiColor: .ppPrimary)
                        : Color(uiColor: .ppPrimary).opacity(0.42),
                    in: Capsule()
                )
                .shadow(
                    color: viewModel.hasEdits ? Color(uiColor: .ppPrimary).opacity(0.35) : Color.clear,
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.hasEdits || viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .ppBackground))
    }

    // MARK: - Pro Identity Hero Card

    private var proIdentityHeroCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                // Avatar Halo
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        .frame(width: 78, height: 78)

                    Circle()
                        .stroke(Color(uiColor: .ppPrimary).opacity(0.35), lineWidth: 2)
                        .frame(width: 74, height: 74)

                    if let urlStr = viewModel.snapshot.avatarURL, let url = URL(string: urlStr), !urlStr.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                avatarMonogramView
                            }
                        }
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())
                    } else {
                        avatarMonogramView
                    }

                    // Verified Badge Icon
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                                .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                        }
                    }
                    .frame(width: 76, height: 76)
                }

                // Identity Copy Stack
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(viewModel.snapshot.displayName.isEmpty ? Language.get("ProfileSettings_NoContact", alter: "لا توجد بيانات") : viewModel.snapshot.displayName)
                            .font(Font.custom("Beiruti-Bold", size: 20, relativeTo: .title3))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                            .lineLimit(1)

                        Spacer()

                        // Role Pill
                        Text(viewModel.snapshot.roleName.isEmpty ? "—" : viewModel.snapshot.roleName)
                            .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                    }

                    Text(Language.get("ProfileSettings_HeroSubtitle", alter: "واجهة حساب أهدأ وأنظف للبيانات التي تثبت حضورك كمزود."))
                        .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Contact Meta Line
                    HStack(spacing: 8) {
                        if !viewModel.snapshot.email.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 9.5))
                                Text(viewModel.snapshot.email)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }

                        if !viewModel.snapshot.email.isEmpty && !viewModel.snapshot.phone.isEmpty {
                            Text("•")
                                .foregroundColor(Color(uiColor: .ppSurfaceBorder))
                        }

                        if !viewModel.snapshot.phone.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 9.5))
                                Text(viewModel.snapshot.phone)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .monospacedDigit()
                            }
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .ppSurface),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var avatarMonogramView: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .ppPrimary).opacity(0.15))
                .frame(width: 66, height: 66)

            Text(String(viewModel.snapshot.displayName.prefix(1)).uppercased())
                .font(Font.custom("Beiruti-Bold", size: 26))
                .foregroundColor(Color(uiColor: .ppPrimary))
        }
    }

    // MARK: - Tactical Credentials Deck

    private var credentialsDeckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProfileSettings_PersonalSectionTitle", alter: "البيانات الشخصية"))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("ProfileSettings_PersonalSectionSubtitle", alter: "حدّث بيانات الحساب المعتمدة عبر جلسة برو وهوية المزود."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            VStack(spacing: 10) {
                // Field 1: Display Name
                credentialFieldRow(
                    icon: "person.fill",
                    title: Language.get("ProfileDisplayName", alter: "اسم العرض"),
                    placeholder: Language.get("ProfileDisplayName", alter: "اسم العرض"),
                    text: $viewModel.editedName,
                    tag: 0,
                    keyboard: .default,
                    autocapitalization: .words
                )

                // Field 2: Email
                credentialFieldRow(
                    icon: "envelope.fill",
                    title: Language.get("ProfileEmail", alter: "البريد الإلكتروني"),
                    placeholder: "example@pure-pets.net",
                    text: $viewModel.editedEmail,
                    tag: 1,
                    keyboard: .emailAddress,
                    autocapitalization: .never
                )

                // Field 3: Phone
                credentialFieldRow(
                    icon: "phone.fill",
                    title: Language.get("ProfilePhone", alter: "رقم الجوال"),
                    placeholder: "+974...",
                    text: $viewModel.editedPhone,
                    tag: 2,
                    keyboard: .phonePad,
                    autocapitalization: .never
                )
            }

            // Save Footnote
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(uiColor: .ppPrimary))

                Text(Language.get("ProfileSettings_SaveHint", alter: "احفظ التعديلات من الشريط العلوي. هذا القسم مخصص لهوية الحساب فقط."))
                    .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            Color(uiColor: .ppSurface),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private func credentialFieldRow(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>,
        tag: Int,
        keyboard: UIKeyboardType,
        autocapitalization: TextInputAutocapitalization
    ) -> some View {
        HStack(spacing: 12) {
            // Icon Pill
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .ppPrimary).opacity(0.09))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
            }

            // Text Stack
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                TextField(placeholder, text: text)
                    .font(Font.custom("Beiruti-Medium", size: 15, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(true)
                    .focused($activeField, equals: tag)
            }

            Spacer()

            // Clear Button when active & not empty
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
        .background(
            Color(uiColor: .ppElevatedSurface),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
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

    // MARK: - Live Consumer Storefront Simulation Chamber

    private var storefrontSimulationChamber: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProfileSettings_ProviderPreviewTitle", alter: "معاينة ملف المزود"))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("ProfileSettings_ProviderPreviewSubtitle", alter: "هذه هي الهوية العامة التي يمكن للعملاء التعرّف عليها داخل تطبيق المستخدم."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            // Customer View Simulation Card
            VStack(spacing: 0) {
                // Cover Banner with Avatar Overlay
                ZStack(alignment: .bottomLeading) {
                    // Cover Image / Fallback
                    if let firstCover = viewModel.snapshot.coverURLs.first, let url = URL(string: firstCover), !firstCover.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                coverFallbackGraphic
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        coverFallbackGraphic
                    }

                    // Scrim Gradient
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Status Pill (Top Trailing)
                    VStack {
                        HStack {
                            Spacer()
                            Text(viewModel.snapshot.statusTitle.isEmpty ? Language.get("ProfileSettings_ProviderPreviewStatusReady", alter: "جاهز") : viewModel.snapshot.statusTitle)
                                .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.45), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(12)

                    // Overlapping Avatar & Name Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.black.opacity(0.18), radius: 6, y: 2)

                            if let urlStr = viewModel.snapshot.avatarURL, let url = URL(string: urlStr), !urlStr.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: avatarMonogramView.scaleEffect(0.7)
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                            } else {
                                avatarMonogramView.scaleEffect(0.7)
                            }
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(Language.get("ProfileSettings_ProviderPreviewShownInUsersApp", alter: "ما يظهر في تطبيق المستخدم"))
                                .font(Font.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                                .foregroundColor(.white)

                            Text(viewModel.snapshot.workspaceTitle.isEmpty
                                 ? Language.get("ProfileSettings_ProviderPreviewEmpty", alter: "مساحة العمل غير محددة")
                                 : String(format: Language.get("ProfileSettings_ProviderPreviewWorkspaceFormat", alter: "مساحة العمل الأساسية: %@"), viewModel.snapshot.workspaceTitle))
                                .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(14)
                }
                .frame(height: 160)

                // Storefront Meta Strip
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // Display Name Pill
                        storefrontPill(title: Language.get("ProfileDisplayName", alter: "اسم العرض"), value: viewModel.editedName)

                        // Phone Pill
                        storefrontPill(title: Language.get("ProfilePhone", alter: "رقم الجوال"), value: viewModel.editedPhone)
                    }

                    HStack(spacing: 10) {
                        // Email Pill
                        storefrontPill(title: Language.get("ProfileEmail", alter: "البريد"), value: viewModel.editedEmail)

                        // Cover Count Pill
                        storefrontPill(
                            title: Language.get("ProfileSettings_ProviderPreviewCoverTitle", alter: "صور الغلاف"),
                            value: String(format: Language.get("ProfileSettings_ProviderPreviewCoverCountFormat", alter: "%lu صورة غلاف"), viewModel.snapshot.coverURLs.count)
                        )
                    }

                    // Plan summary line
                    if !viewModel.snapshot.planSummary.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(Color(uiColor: .ppPrimary))

                            Text(viewModel.snapshot.planSummary)
                                .font(Font.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                            Spacer()
                        }
                        .padding(.top, 2)
                    }

                    // Edit Provider Profile Studio Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.onEditProviderProfile?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 14, weight: .bold))

                            Text(Language.get("ProfileSettings_EditProviderProfile", alter: "تعديل ملف المزود"))
                                .font(Font.custom("Beiruti-Bold", size: 15, relativeTo: .callout))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.28), radius: 8, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 6)
                }
                .padding(16)
                .background(Color(uiColor: .ppElevatedSurface))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1)
            )
        }
        .padding(18)
        .background(
            Color(uiColor: .ppSurface),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var coverFallbackGraphic: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .ppPrimary).opacity(0.20), Color(uiColor: .ppPrimary).opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38))
                .foregroundColor(Color(uiColor: .ppPrimary).opacity(0.4))
        }
        .frame(height: 160)
    }

    private func storefrontPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Font.custom("Beiruti-Bold", size: 10.5, relativeTo: .caption2))
                .foregroundColor(Color(uiColor: .ppTextSecondary))

            Text(value.isEmpty ? "—" : value)
                .font(Font.custom("Beiruti-Medium", size: 13, relativeTo: .caption))
                .foregroundColor(Color(uiColor: .ppTextPrimary))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.5)))
    }

    // MARK: - Pro System Preferences Dock

    private var systemPreferencesDock: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProfileSettings_SettingsSectionTitle", alter: "الإعدادات"))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("ProfileSettings_SettingsSectionSubtitle", alter: "افتح عناصر التحكم التي تضبط تجربة برو بدون أن تزحم واجهة الملف."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            VStack(spacing: 8) {
                // Notifications Row
                preferenceNavRow(
                    icon: "bell.badge.fill",
                    color: Color.orange,
                    title: Language.get("NotificationSettings", alter: "إعدادات الإشعارات"),
                    subtitle: Language.get("NotificationSettingsSubtitle", alter: "التحكم في تنبيهات الوارد وتفضيلات فئات الإشعارات.")
                ) {
                    viewModel.onOpenNotifications?()
                }

                // Appearance 3-Way Segmented Row
                appearanceSegmentedRow

                // Language Switch Row
                preferenceNavRow(
                    icon: "globe",
                    color: Color.blue,
                    title: Language.get("ProfileSettings_LanguageTitle", alter: "اللغة"),
                    subtitle: String(format: Language.get("ProfileSettings_LanguageSubtitleFormat", alter: "لغة التطبيق الحالية: %@"),
                                     viewModel.snapshot.currentLanguageCode == "ar" ? Language.get("ProfileSettings_LanguageArabic", alter: "العربية") : Language.get("ProfileSettings_LanguageEnglish", alter: "English"))
                ) {
                    viewModel.onSelectLanguage?(viewModel.snapshot.currentLanguageCode == "ar" ? "en" : "ar")
                }

                // Secure Logout Row
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.onLogout?()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 38, height: 38)

                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Language.get("LogOut", alter: "تسجيل الخروج"))
                                .font(Font.custom("Beiruti-Bold", size: 14.5, relativeTo: .body))
                                .foregroundColor(.red)

                            Text(Language.get("ProfileSettings_LogoutSubtitle", alter: "إنهاء جلسة برو بأمان."))
                                .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .ppSurface),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private func preferenceNavRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.custom("Beiruti-Bold", size: 14.5, relativeTo: .body))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(subtitle)
                        .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.6))
            }
            .padding(12)
            .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var appearanceSegmentedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.get("AppearanceSettings", alter: "إعدادات المظهر"))
                        .font(Font.custom("Beiruti-Bold", size: 14.5, relativeTo: .body))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(Language.get("AppearanceSettingsSubtitle", alter: "التحكم في السمة ووضوح الواجهة والتفضيلات البصرية."))
                        .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(1)
                }
            }

            // Inline 3-Way Segment
            HStack(spacing: 6) {
                themeOptionPill(title: Language.get("ThemeSystem", alter: "تلقائي"), key: "system")
                themeOptionPill(title: Language.get("ThemeLight", alter: "فاتح"), key: "light")
                themeOptionPill(title: Language.get("ThemeDark", alter: "داكن"), key: "dark")
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func themeOptionPill(title: String, key: String) -> some View {
        let isSelected = viewModel.snapshot.currentThemeKey == key
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.onSelectTheme?(key)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(Font.custom(isSelected ? "Beiruti-Bold" : "Beiruti-Medium", size: 13, relativeTo: .caption))
            }
            .foregroundColor(isSelected ? .white : Color(uiColor: .ppTextPrimary))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                isSelected ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurface),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color(uiColor: .ppSurfaceBorder).opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ==========================================
// MARK: - IPAD: SPATIAL COCKPIT ARCHITECTURE
// MARK: - ==========================================

private struct iPadProProfileSpatialCockpit: View {
    @ObservedObject var viewModel: PPProProfileSettingsViewModel
    @FocusState private var activeField: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Apex Navigation Deck
            iPadApexCommandBar

            Divider().background(Color(uiColor: .ppSurfaceBorder).opacity(0.6))

            // 2-Column Spatial Engine
            HStack(alignment: .top, spacing: 20) {
                // Leading Column (45%): Account Credentials & System Preferences
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Hero Card
                        iPadHeroIdentityCard

                        // Credentials Deck
                        iPadCredentialsEditorCard

                        // Preferences Deck
                        iPadSystemControlsCard

                        Spacer().frame(height: 32)
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity)

                // Vertical Divider
                Rectangle()
                    .fill(Color(uiColor: .ppSurfaceBorder).opacity(0.6))
                    .frame(width: 1)

                // Trailing Column (55%): Live Consumer Storefront Simulator
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        iPadStorefrontSimulatorChamber

                        Spacer().frame(height: 32)
                    }
                    .padding(20)
                }
                .frame(width: 440)
            }
        }
    }

    // MARK: - iPad Apex Command Bar

    private var iPadApexCommandBar: some View {
        HStack(spacing: 14) {
            // Back Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onDismiss?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .ppSurface))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
                    Image(systemName: Language.isRTL() ? "chevron.right" : "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Title & Breadcrumb Stack
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(Language.get("ProfileSettings", alter: "إعدادات الملف الشخصي"))
                        .font(Font.custom("Beiruti-Bold", size: 21, relativeTo: .title3))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    // Pro Active Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("PRO SUITE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                }

                Text(Language.get("ProfileSettings_Eyebrow", alter: "حساب بيور بتس برو • مساحة القيادة التشغيلية"))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            Spacer()

            // Save Action Button
            Button {
                viewModel.saveTriggered()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isSaving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(Language.get("Save", alter: "حفظ التعديلات"))
                        .font(Font.custom("Beiruti-Bold", size: 14.5, relativeTo: .callout))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    viewModel.hasEdits ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppPrimary).opacity(0.4),
                    in: Capsule()
                )
                .shadow(color: viewModel.hasEdits ? Color(uiColor: .ppPrimary).opacity(0.3) : Color.clear, radius: 8, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.hasEdits || viewModel.isSaving)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(uiColor: .ppBackground))
    }

    // MARK: - iPad Hero Identity Card

    private var iPadHeroIdentityCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                    .frame(width: 82, height: 82)

                if let urlStr = viewModel.snapshot.avatarURL, let url = URL(string: urlStr), !urlStr.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Image(systemName: "person.crop.circle.fill").font(.system(size: 60)).foregroundColor(Color(uiColor: .ppPrimary))
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(viewModel.snapshot.displayName)
                        .font(Font.custom("Beiruti-Bold", size: 21, relativeTo: .title3))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(viewModel.snapshot.roleName)
                        .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                }

                Text(Language.get("ProfileSettings_HeroSubtitle", alter: "واجهة حساب أهدأ وأنظف للبيانات التي تثبت حضورك كمزود."))
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                HStack(spacing: 10) {
                    Text(viewModel.snapshot.email).font(.system(size: 11.5)).foregroundColor(Color(uiColor: .ppTextSecondary))
                    Text("•").foregroundColor(Color(uiColor: .ppSurfaceBorder))
                    Text(viewModel.snapshot.phone).font(.system(size: 11.5)).foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6)))
    }

    // MARK: - iPad Credentials Editor Card

    private var iPadCredentialsEditorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Language.get("ProfileSettings_PersonalSectionTitle", alter: "البيانات الشخصية"))
                .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                .foregroundColor(Color(uiColor: .ppTextPrimary))

            VStack(spacing: 10) {
                iPadFieldRow(icon: "person.fill", title: Language.get("ProfileDisplayName", alter: "اسم العرض"), text: $viewModel.editedName, tag: 0)
                iPadFieldRow(icon: "envelope.fill", title: Language.get("ProfileEmail", alter: "البريد الإلكتروني"), text: $viewModel.editedEmail, tag: 1)
                iPadFieldRow(icon: "phone.fill", title: Language.get("ProfilePhone", alter: "رقم الجوال"), text: $viewModel.editedPhone, tag: 2)
            }
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6)))
    }

    private func iPadFieldRow(icon: String, title: String, text: Binding<String>, tag: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(uiColor: .ppPrimary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                TextField(title, text: text)
                    .font(Font.custom("Beiruti-Medium", size: 14.5, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .focused($activeField, equals: tag)
            }
        }
        .padding(12)
        .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(activeField == tag ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurfaceBorder).opacity(0.5))
        )
    }

    // MARK: - iPad System Controls Card

    private var iPadSystemControlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Language.get("ProfileSettings_SettingsSectionTitle", alter: "الإعدادات والنظام"))
                .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                .foregroundColor(Color(uiColor: .ppTextPrimary))

            // Appearance Selector
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.get("AppearanceSettings", alter: "إعدادات المظهر"))
                    .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                HStack(spacing: 6) {
                    iPadThemeSegment(title: Language.get("ThemeSystem", alter: "تلقائي"), key: "system")
                    iPadThemeSegment(title: Language.get("ThemeLight", alter: "فاتح"), key: "light")
                    iPadThemeSegment(title: Language.get("ThemeDark", alter: "داكن"), key: "dark")
                }
            }

            Divider().background(Color(uiColor: .ppSurfaceBorder).opacity(0.5))

            // Action Buttons Strip
            HStack(spacing: 10) {
                Button {
                    viewModel.onOpenNotifications?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge.fill")
                        Text(Language.get("NotificationSettings", alter: "الإشعارات"))
                            .font(Font.custom("Beiruti-Bold", size: 13, relativeTo: .callout))
                    }
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    viewModel.onSelectLanguage?(viewModel.snapshot.currentLanguageCode == "ar" ? "en" : "ar")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(viewModel.snapshot.currentLanguageCode == "ar" ? "English" : "العربية")
                            .font(Font.custom("Beiruti-Bold", size: 13, relativeTo: .callout))
                    }
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    viewModel.onLogout?()
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6)))
    }

    private func iPadThemeSegment(title: String, key: String) -> some View {
        let isSelected = viewModel.snapshot.currentThemeKey == key
        return Button {
            viewModel.onSelectTheme?(key)
        } label: {
            Text(title)
                .font(Font.custom(isSelected ? "Beiruti-Bold" : "Beiruti-Medium", size: 12.5, relativeTo: .caption))
                .foregroundColor(isSelected ? .white : Color(uiColor: .ppTextPrimary))
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(isSelected ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - iPad Storefront Simulator Chamber

    private var iPadStorefrontSimulatorChamber: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.get("ProfileSettings_ProviderPreviewTitle", alter: "معاينة ملف المزود في تطبيق المستخدم"))
                        .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(Language.get("ProfileSettings_ProviderPreviewSubtitle", alter: "محاكاة فورية لما يشاهده العميل داخل متجر بيور بتس."))
                        .font(Font.custom("Beiruti-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                }
                Spacer()
            }

            // Customer Phone Mockup Vessel
            VStack(spacing: 0) {
                // Hero Cover Chamber
                ZStack(alignment: .bottomLeading) {
                    if let firstCover = viewModel.snapshot.coverURLs.first, let url = URL(string: firstCover), !firstCover.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: coverMockGraphic
                            }
                        }
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        coverMockGraphic
                    }

                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Image(systemName: "pawprint.fill")
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.editedName)
                                .font(Font.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                                .foregroundColor(.white)
                            Text(viewModel.snapshot.workspaceTitle)
                                .font(Font.custom("Beiruti-Regular", size: 12, relativeTo: .caption))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(14)
                }
                .frame(height: 190)

                // Storefront Attributes Box
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        iPadPill(title: Language.get("ProfileEmail", alter: "البريد"), value: viewModel.editedEmail)
                        iPadPill(title: Language.get("ProfilePhone", alter: "الجوال"), value: viewModel.editedPhone)
                    }

                    HStack(spacing: 8) {
                        iPadPill(title: Language.get("ProfileSettings_ProviderPreviewCoverTitle", alter: "صور الغلاف"), value: "\(viewModel.snapshot.coverURLs.count)")
                        iPadPill(title: "حالة الاعتماد", value: viewModel.snapshot.statusTitle)
                    }

                    // Studio Launch Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.onEditProviderProfile?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.app.fill")
                            Text(Language.get("ProfileSettings_EditProviderProfile", alter: "تعديل ملف المزود في الوصول إلى السوق"))
                                .font(Font.custom("Beiruti-Bold", size: 14.5, relativeTo: .callout))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(uiColor: .ppPrimary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.3), radius: 6, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                }
                .padding(16)
                .background(Color(uiColor: .ppElevatedSurface))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6)))
        }
        .padding(18)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.6)))
    }

    private var coverMockGraphic: some View {
        ZStack {
            LinearGradient(colors: [Color(uiColor: .ppPrimary).opacity(0.18), Color(uiColor: .ppPrimary).opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo.artframe").font(.system(size: 34)).foregroundColor(Color(uiColor: .ppPrimary).opacity(0.4))
        }
        .frame(height: 190)
    }

    private func iPadPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Font.custom("Beiruti-Bold", size: 10)).foregroundColor(Color(uiColor: .ppTextSecondary))
            Text(value.isEmpty ? "—" : value).font(Font.custom("Beiruti-Medium", size: 12.5)).foregroundColor(Color(uiColor: .ppTextPrimary)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Hosting Bridge & Controller for Objective-C

@objc(PPProProfileSettingsHostController)
@MainActor
public final class PPProProfileSettingsHostController: UIViewController {
    private let viewModel: PPProProfileSettingsViewModel
    private var hostingController: UIHostingController<PPProProfileSettingsView>?

    init(viewModel: PPProProfileSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: PPProProfileSettingsView(viewModel: viewModel))
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

    @objc public func updateSnapshot(_ snapshot: PPProProfileSnapshot) {
        viewModel.updateSnapshot(snapshot)
    }

    @objc public func didFinishSaving() {
        viewModel.isSaving = false
    }
}

@objc(PPProProfileSettingsHostingBridge)
@MainActor
public final class PPProProfileSettingsHostingBridge: NSObject {
    @objc public static func makeViewController(
        snapshot: PPProProfileSnapshot,
        onSave: @escaping (String, String, String) -> Void,
        onEditProviderProfile: @escaping () -> Void,
        onOpenNotifications: @escaping () -> Void,
        onSelectTheme: @escaping (String) -> Void,
        onSelectLanguage: @escaping (String) -> Void,
        onLogout: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> PPProProfileSettingsHostController {
        let vm = PPProProfileSettingsViewModel(snapshot: snapshot)
        vm.onSave = onSave
        vm.onEditProviderProfile = onEditProviderProfile
        vm.onOpenNotifications = onOpenNotifications
        vm.onSelectTheme = onSelectTheme
        vm.onSelectLanguage = onSelectLanguage
        vm.onLogout = onLogout
        vm.onDismiss = onDismiss

        return PPProProfileSettingsHostController(viewModel: vm)
    }
}
