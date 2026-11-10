//
//  PPProProfileSettingsView.swift
//  PurePetsPro
//
//  First-Principles Invention: Category-Defining Personal Operator Profile & Account Governance Studio (NextGen V9).
//  Completely separated from the commercial company profile:
//  - Sovereign Command Cockpit with Pro tier beacon & adaptive dirty-state save trigger
//  - Living Operator Identity Hero with glowing avatar halo & verified clearance tags
//  - Dedicated Commercial Company & Facility Gateway Card (direct launch into Provider Studio)
//  - Tactile Personal Credentials Deck with instant inline validation & haptics
//  - Fluid 3-Way Segmented Appearance Switcher with spring sliding thumb (Auto/Light/Dark)
//  - Instant Regional Language Selection Chamber (Arabic RTL primary, English secondary)
//  - Push Notifications Channel Status Hub
//  - Sovereign Security & Safe Session Governance with dual-confirmation logout
//  - iPad: 2-Column Spatial Cockpit (42% Identity & Governance, 58% Credentials & Regional Preferences)
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
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: PPProProfileSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > 680

            ZStack {
                Color(uiColor: .ppBackground)
                    .ignoresSafeArea()

                // Ambient Radial Atmospheric Lighting
                ambientAtmosphericLighting

                if isPad {
                    iPadSpatialCockpitLayout(geometry: geometry)
                } else {
                    iPhoneSensoryDeckLayout
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .confirmationDialog(
            Language.isRTL() ? "تأكيد تسجيل الخروج" : "Confirm Sign Out",
            isPresented: $viewModel.showLogoutAlert,
            titleVisibility: .visible
        ) {
            Button(Language.isRTL() ? "تسجيل الخروج" : "Sign Out", role: .destructive) {
                viewModel.onLogout?()
            }
            Button(Language.isRTL() ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(Language.isRTL()
                 ? "هل أنت متأكد من تسجيل الخروج من جلسة المشغل الحالية في بيور بتس برو؟"
                 : "Are you sure you want to sign out from your active PurePets Pro operator session?")
        }
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
                .offset(x: Language.isRTL() ? 150 : -150, y: -240)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.05), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: Language.isRTL() ? -140 : 140, y: 320)
                .allowsHitTesting(false)
        }
    }

    // MARK: - iPhone Sensory Deck Layout

    private var iPhoneSensoryDeckLayout: some View {
        VStack(spacing: 0) {
            sovereignNavigationBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    // 1. Living Operator Identity Hero
                    operatorIdentityHeroCard
                        .padding(.top, 4)

                    // 2. Separate Company & Facility Profile Gateway Card
                    companyFacilityGatewayCard

                    // 3. Personal Credentials Deck
                    credentialsDeckCard

                    // 4. Appearance & Theme Switcher
                    appearanceSwitcherCard

                    // 5. Language & Regional Preferences
                    languagePreferencesCard

                    // 6. Push Notifications Channel Hub
                    notificationsChannelCard

                    // 7. Session Governance & Security
                    sessionSecurityCard

                    // Breathing Space
                    Spacer().frame(height: 50)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - iPad Spatial Cockpit Layout

    private func iPadSpatialCockpitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            sovereignNavigationBar

            HStack(alignment: .top, spacing: 20) {
                // Leading Column: Identity, Company Bridge & Security (40%)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        operatorIdentityHeroCard
                        companyFacilityGatewayCard
                        sessionSecurityCard
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 4)
                }
                .frame(width: max(geometry.size.width * 0.40, 320))

                // Trailing Column: Personal Credentials & Preferences (60%)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        credentialsDeckCard
                        appearanceSwitcherCard
                        languagePreferencesCard
                        notificationsChannelCard
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
        }
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

            // Title Stack with Pro Beacon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Language.isRTL() ? "الحساب والإعدادات الشخصية" : "User Profile & Account")
                        .font(PPFont.bold(18, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    // Pro Indicator
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                        Text("PRO")
                            .font(.system(size: 9.5, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color(uiColor: .ppPrimary).opacity(0.35), radius: 4, y: 1.5)
                }

                Text(Language.isRTL() ? "إدارة حساب المشغل المعتمد والتهيئة الشخصية" : "Verified Operator Identity & Personal Governance")
                    .font(PPFont.regular(11.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }

            Spacer()

            // Dynamic Adaptive Save Action Pill
            Button {
                viewModel.saveTriggered()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.75)
                    } else if viewModel.hasEdits {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }

                    Text(viewModel.hasEdits
                         ? (Language.isRTL() ? "حفظ التغييرات" : "Save")
                         : (Language.isRTL() ? "محفوظ" : "Saved")
                    )
                    .font(PPFont.bold(13, relativeTo: .callout))
                }
                .foregroundColor(viewModel.hasEdits ? .white : Color(uiColor: .ppTextSecondary))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    viewModel.hasEdits
                        ? LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(uiColor: .ppElevatedSurface), Color(uiColor: .ppElevatedSurface)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            viewModel.hasEdits
                                ? Color.white.opacity(0.2)
                                : Color(uiColor: .ppSurfaceBorder).opacity(0.6),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: viewModel.hasEdits ? Color(uiColor: .ppPrimary).opacity(0.35) : Color.clear,
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.hasEdits || viewModel.isSaving)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.hasEdits)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(uiColor: .ppBackground).opacity(0.92)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - 1. Living Operator Identity Hero

    private var operatorIdentityHeroCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Operator Avatar with Halo Ring
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary), Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 78, height: 78)

                    if let avatar = viewModel.snapshot.avatarURL, let url = URL(string: avatar), !avatar.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                avatarInitialsFallback
                            }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                    } else {
                        avatarInitialsFallback
                    }

                    // Verified Checkmark Dot
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .systemBackground))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                            }
                        }
                    }
                    .frame(width: 78, height: 78)
                }

                // Operator Text Info Stack
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(viewModel.snapshot.displayName.isEmpty
                             ? (Language.isRTL() ? "مشغل بيور بتس" : "PurePets Operator")
                             : viewModel.snapshot.displayName
                        )
                        .font(PPFont.bold(18, relativeTo: .title3))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .lineLimit(1)

                        Spacer()

                        // Role Tag
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(viewModel.snapshot.roleName.isEmpty ? (Language.isRTL() ? "مشغل معتمد" : "Operator") : viewModel.snapshot.roleName)
                                .font(PPFont.bold(10.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color(uiColor: .ppPrimary).opacity(0.24), lineWidth: 0.8))
                    }

                    Text(Language.isRTL()
                         ? "حساب المشغل الإداري المعتمد لإدارة المنظومة والعمليات."
                         : "Authorized administrative operator account for platform management."
                    )
                    .font(PPFont.regular(11.5, relativeTo: .caption2))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                    .lineLimit(2)

                    // Contact Meta Line
                    HStack(spacing: 8) {
                        if !viewModel.snapshot.phone.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                                Text(viewModel.snapshot.phone)
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }

                        if !viewModel.snapshot.phone.isEmpty && !viewModel.snapshot.email.isEmpty {
                            Text("•")
                                .foregroundColor(Color(uiColor: .ppSurfaceBorder))
                        }

                        if !viewModel.snapshot.email.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                                Text(viewModel.snapshot.email)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .ppSurface),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    private var avatarInitialsFallback: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .ppPrimary).opacity(0.14))
                .frame(width: 70, height: 70)

            let initial = viewModel.snapshot.displayName.prefix(1)
            Text(initial.isEmpty ? "P" : String(initial).uppercased())
                .font(PPFont.bold(26, relativeTo: .title2))
                .foregroundColor(Color(uiColor: .ppPrimary))
        }
    }

    // MARK: - 2. Dedicated Company & Facility Profile Gateway Card

    private var companyFacilityGatewayCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.onEditProviderProfile?()
        } label: {
            HStack(spacing: 14) {
                // Facility Plate Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary).opacity(0.18), Color.blue.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(uiColor: .ppPrimary).opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(Language.isRTL() ? "ملف المنشأة والمركز التجاري" : "Company & Facility Profile")
                            .font(PPFont.bold(15, relativeTo: .subheadline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        HStack(spacing: 3) {
                            Text(Language.isRTL() ? "مدخل مستقل" : "Separate Entry")
                                .font(PPFont.bold(9.5, relativeTo: .caption2))
                        }
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(uiColor: .ppPrimary).opacity(0.10), in: Capsule())
                    }

                    Text(Language.isRTL()
                         ? "تعديل الاسم التجاري، الشعار، صور المعرض، ونطاق الخدمة في قطر"
                         : "Manage trade name, company logo, cover showcase and Qatar location")
                        .font(PPFont.regular(11.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(14)
            .background(
                Color(uiColor: .ppSurface),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary).opacity(0.35), Color(uiColor: .ppSurfaceBorder).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color(uiColor: .ppPrimary).opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 3. Personal Credentials Deck

    private var credentialsDeckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "بيانات الاعتماد الشخصية" : "Operator Credentials",
                subtitle: Language.isRTL() ? "اسم المشغل ورقم الهاتف المسجل للجلسة" : "Your personal name and direct contact mobile",
                symbol: "person.text.rectangle.fill"
            )

            // Operator Display Name
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "اسم المشغل الكامل" : "Operator Full Name")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                    Text("*")
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }

                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .frame(width: 20)

                    TextField(
                        Language.isRTL() ? "الاسم الشخصي للمشغل" : "Operator Full Name",
                        text: $viewModel.editedName
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                    if !viewModel.editedName.isEmpty {
                        Button {
                            viewModel.editedName = ""
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

            // Mobile Number
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "رقم الهاتف الشخصي للمشغل" : "Personal Mobile Number")
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

            // Email (Read-only / Auth bound)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Language.isRTL() ? "البريد الإلكتروني المسجل" : "Registered Account Email")
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                    Spacer()
                    Text(Language.isRTL() ? "معتمد أمنياً" : "Verified")
                        .font(PPFont.medium(10, relativeTo: .caption2))
                        .foregroundColor(Color.green)
                }

                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .frame(width: 20)

                    TextField(
                        "operator@purepets.qa",
                        text: $viewModel.editedEmail
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
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

    // MARK: - 4. Appearance & Theme Switcher

    private var appearanceSwitcherCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "المظهر ونمط الواجهة" : "Appearance & Theme",
                subtitle: Language.isRTL() ? "التبديل بين الوضع الداكن، الفاتح وتلقائي النظام" : "Choose your desired visual theme",
                symbol: "circle.righthalf.filled"
            )

            HStack(spacing: 8) {
                appearanceSegmentButton(title: Language.isRTL() ? "تلقائي" : "System", key: "system", icon: "gearshape")
                appearanceSegmentButton(title: Language.isRTL() ? "نهاري" : "Light", key: "light", icon: "sun.max.fill")
                appearanceSegmentButton(title: Language.isRTL() ? "ليلي" : "Dark", key: "dark", icon: "moon.fill")
            }
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    private func appearanceSegmentButton(title: String, key: String, icon: String) -> some View {
        let isSelected = viewModel.snapshot.currentThemeKey.lowercased() == key.lowercased()

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.onSelectTheme?(key)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(PPFont.bold(13, relativeTo: .caption))
            }
            .foregroundColor(isSelected ? .white : Color(uiColor: .ppTextPrimary))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected
                    ? Color(uiColor: .ppPrimary)
                    : Color(uiColor: .ppElevatedSurface),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: isSelected ? 1.5 : 0.8)
            )
            .shadow(color: isSelected ? Color(uiColor: .ppPrimary).opacity(0.25) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 5. Language & Regional Preferences

    private var languagePreferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeaderView(
                title: Language.isRTL() ? "لغة المنظومة والمنطقة" : "Language & Region",
                subtitle: Language.isRTL() ? "اختر لغة واجهة بيور بتس برو" : "Select language for PurePets Pro",
                symbol: "globe"
            )

            HStack(spacing: 10) {
                let isArabic = Language.isRTL()

                // Arabic Option
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if !isArabic { viewModel.onSelectLanguage?("ar") }
                } label: {
                    HStack(spacing: 8) {
                        Text("🇶🇦")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("العربية")
                                .font(PPFont.bold(14, relativeTo: .body))
                            Text("قطر • RTL")
                                .font(PPFont.regular(10.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                        Spacer()
                        if isArabic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(uiColor: .ppPrimary))
                        }
                    }
                    .padding(12)
                    .background(isArabic ? Color(uiColor: .ppPrimary).opacity(0.12) : Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isArabic ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: isArabic ? 1.5 : 0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(Color(uiColor: .ppTextPrimary))

                // English Option
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if isArabic { viewModel.onSelectLanguage?("en") }
                } label: {
                    HStack(spacing: 8) {
                        Text("🇺🇸")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("English")
                                .font(PPFont.bold(14, relativeTo: .body))
                            Text("US • LTR")
                                .font(PPFont.regular(10.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                        Spacer()
                        if !isArabic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(uiColor: .ppPrimary))
                        }
                    }
                    .padding(12)
                    .background(!isArabic ? Color(uiColor: .ppPrimary).opacity(0.12) : Color(uiColor: .ppElevatedSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(!isArabic ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurfaceBorder).opacity(0.7), lineWidth: !isArabic ? 1.5 : 0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(Color(uiColor: .ppTextPrimary))
            }
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
    }

    // MARK: - 6. Push Notifications Channel Hub

    private var notificationsChannelCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.onOpenNotifications?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.isRTL() ? "قنوات الإشعارات والتنبيهات الفورية" : "Push Notification Channels")
                        .font(PPFont.bold(14, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                    Text(Language.isRTL() ? "ضبط أصوات وتنبيهات الطلبات والرسائل" : "Configure audible alerts and order alerts")
                        .font(PPFont.regular(11.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                }

                Spacer()

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
            }
            .padding(14)
            .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 7. Session Governance & Security

    private var sessionSecurityCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
                Text(Language.isRTL() ? "أمان الجلسة والسيادة الرقمية" : "Session Security & Digital Governance")
                    .font(PPFont.bold(13, relativeTo: .subheadline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                Spacer()
                Text("App Check Active")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            // Sign Out Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showLogoutAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                    Text(Language.isRTL() ? "تسجيل الخروج من برو" : "Sign Out from PurePets Pro")
                        .font(PPFont.bold(14, relativeTo: .subheadline))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.red.opacity(0.24), lineWidth: 0.8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color(uiColor: .ppSurface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 10, y: 3)
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
}

// MARK: - Hosting Controller & Bridge

@objc(PPProProfileSettingsHostController)
public final class PPProProfileSettingsHostController: UIViewController {
    private let viewModel: PPProProfileSettingsViewModel
    private var hostingController: UIHostingController<PPProProfileSettingsView>?

    init(viewModel: PPProProfileSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground

        let swiftUIView = PPProProfileSettingsView(viewModel: viewModel)
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
