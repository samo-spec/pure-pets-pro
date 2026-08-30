import SwiftUI
import UIKit
import Combine

// ============================================================================
// Pure Pets Pro — Identity Gate + Pulse Command Center
// Repo-targeted replacement for the existing PPProLoginSurfaceController.swift.
//
// Backend rule:
// - This file does NOT authenticate against Firebase.
// - AdminLoginViewController remains the owner of phone OTP, Apple, Google,
//   provider-access gating, App Check handling, and root routing.
// - AdminDashboardViewController remains the owner of permissions, listeners,
//   Firebase/Firestore state, routing, subscription state, and business logic.
//
// This Swift file is presentation + an Objective-C-compatible dashboard bridge.
// Minimum UI API level used here: iOS 15.
// ============================================================================

// MARK: - Shared Pure Pets Pro design primitives

private enum PPProType {
    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }
}

private struct PPProPalette {
    let canvas: Color
    let surface: Color
    let surfaceElevated: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let accentText: Color
    let accentStrong: Color
    let accentSoft: Color
    let hairline: Color
    let shadow: Color
    let isDark: Bool

    static func resolve(_ scheme: ColorScheme) -> PPProPalette {
        let dark = scheme == .dark
        let accentUIColor = UIColor.ppPrimary
        let accentTextUIColor = UIColor.ppAccentText
        let strongUIColor = UIColor.ppPressedAction
        let foregroundUIColor = UIColor.ppSurface
        let backgroundUIColor = UIColor.ppBackground
        let elevatedUIColor = UIColor.ppElevatedSurface
        let textUIColor = UIColor.ppTextPrimary
        let secondaryUIColor = UIColor.ppTextSecondary
        let borderUIColor = UIColor.ppSurfaceBorder
        let shadowUIColor = UIColor.ppShadow

        return PPProPalette(
            canvas: Color(uiColor: backgroundUIColor),
            surface: Color(uiColor: foregroundUIColor),
            surfaceElevated: Color(uiColor: elevatedUIColor),
            text: Color(uiColor: textUIColor),
            secondary: Color(uiColor: secondaryUIColor),
            accent: Color(uiColor: accentUIColor),
            accentText: Color(uiColor: accentTextUIColor),
            accentStrong: Color(uiColor: strongUIColor),
            accentSoft: Color(uiColor: accentUIColor.withAlphaComponent(dark ? 0.15 : 0.09)),
            hairline: Color(uiColor: borderUIColor).opacity(dark ? 0.72 : 0.58),
            shadow: Color(uiColor: shadowUIColor).opacity(dark ? 0.26 : 0.07),
            isDark: dark
        )
    }
}

private struct PPProPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    func ppProMaterialSurface(
        radius: CGFloat,
        palette: PPProPalette,
        interactive: Bool = false
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(palette.hairline, lineWidth: 0.8)
            }
            .shadow(color: interactive ? palette.shadow : .clear, radius: interactive ? 18 : 0, x: 0, y: interactive ? 9 : 0)
    }
}

// ============================================================================
// MARK: - LOGIN — repository-compatible public contract
// ============================================================================

private struct ProCountry: Identifiable, Equatable {
    let id: String
    let name: String
    let localizedName: String
    let phoneCode: String
    let flag: String

    static var all: [ProCountry] {
        CitiesManager.shared().countryDialCodeOptions().compactMap { option in
            let iso = (option["iso"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let phoneCode = (option["value"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let englishName = (option["enName"] ?? option["name"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let arabicName = (option["arName"] ?? option["name"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !iso.isEmpty,
                  !phoneCode.isEmpty,
                  !englishName.isEmpty || !arabicName.isEmpty else {
                return nil
            }

            return ProCountry(
                id: iso,
                name: englishName.isEmpty ? arabicName : englishName,
                localizedName: arabicName.isEmpty ? englishName : arabicName,
                phoneCode: phoneCode,
                flag: option["flag"] ?? ""
            )
        }
    }

    static func sorted(for isRTL: Bool) -> [ProCountry] {
        all.sorted {
            (isRTL ? $0.localizedName : $0.name)
                .localizedCaseInsensitiveCompare(isRTL ? $1.localizedName : $1.name) == .orderedAscending
        }
    }
}

private struct PPCountryPickerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme

    let isRTL: Bool
    let selectedCode: String
    let onSelect: (ProCountry) -> Void

    @State private var searchText = ""
    @State private var countryRevision = 0

    private var palette: PPProPalette { .resolve(colorScheme) }

    private var filtered: [ProCountry] {
        _ = countryRevision
        let countries = ProCountry.sorted(for: isRTL)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.localizedName.localizedCaseInsensitiveContains(query) ||
            $0.phoneCode.localizedCaseInsensitiveContains(query) ||
            $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(palette.secondary)
                    TextField(localized("PPBottomSearch_Accessibility"), text: $searchText)
                        .font(PPProType.medium(16))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        if filtered.isEmpty {
                            VStack(spacing: 10) {
                                if CitiesManager.shared().isLoading {
                                    ProgressView()
                                }
                                Text(localized(CitiesManager.shared().isLoading ? "ProviderCountriesLoading" : "ProviderCountriesUnavailable"))
                                    .font(PPProType.regular(15))
                                    .foregroundStyle(palette.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            ForEach(filtered) { country in
                                Button {
                                    onSelect(country)
                                    presentationMode.wrappedValue.dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(country.flag)
                                            .font(.system(size: 25))
                                            .frame(width: 34)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(isRTL ? country.localizedName : country.name)
                                                .font(PPProType.medium(16))
                                                .foregroundStyle(palette.text)
                                                .lineLimit(1)
                                            Text(country.phoneCode)
                                                .font(PPProType.regular(13))
                                                .foregroundStyle(palette.secondary)
                                        }

                                        Spacer(minLength: 8)

                                        if country.phoneCode == selectedCode {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(palette.accent)
                                        }
                                    }
                                    .padding(.horizontal, 17)
                                    .frame(minHeight: 58)
                                    .background(
                                        country.phoneCode == selectedCode
                                        ? palette.accentSoft
                                        : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                }
            }
            .background(palette.canvas.ignoresSafeArea())
            .navigationBarTitle(localized("ProviderCountryPickerTitle"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button(localized("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(PPProType.medium(15))
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            CitiesManager.shared().loadData()
            countryRevision &+= 1
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("CitiesManagerDidUpdateNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            countryRevision &+= 1
        }
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: nil)
    }
}

private struct PPPhoneNumberTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let isEnabled: Bool
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onChange: onChange)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = .phonePad
        textField.textContentType = .telephoneNumber
        let baseFont = UIFont(name: "Beiruti-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
        textField.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        textField.textAlignment = .left
        textField.semanticContentAttribute = .forceLeftToRight
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.clearButtonMode = .never
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        context.coordinator.onChange = onChange
        if uiView.text != text { uiView.text = text }
        uiView.isEnabled = isEnabled
        uiView.textColor = UIColor.ppTextPrimary
        uiView.tintColor = UIColor.ppPrimary
        let baseFont = UIFont(name: "Beiruti-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
        let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont, compatibleWith: uiView.traitCollection)
        uiView.font = scaledFont
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.ppTextSecondary,
                .font: scaledFont
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var onChange: (String) -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onChange: @escaping (String) -> Void) {
            self.text = text
            self.isFocused = isFocused
            self.onChange = onChange
        }

        @objc func textDidChange(_ sender: UITextField) {
            let value = Self.normalizeArabicDigits(sender.text ?? "")
            if text.wrappedValue != value { text.wrappedValue = value }
            onChange(value)
            if sender.text != value { sender.text = value }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused.wrappedValue = false
        }

        private static func normalizeArabicDigits(_ input: String) -> String {
            let map: [Character: Character] = [
                "٠":"0", "١":"1", "٢":"2", "٣":"3", "٤":"4",
                "٥":"5", "٦":"6", "٧":"7", "٨":"8", "٩":"9",
                "۰":"0", "۱":"1", "۲":"2", "۳":"3", "۴":"4",
                "۵":"5", "۶":"6", "۷":"7", "۸":"8", "۹":"9"
            ]
            return String(input.map { map[$0] ?? $0 })
        }
    }
}

@objc public protocol PPProLoginSurfaceControllerDelegate: AnyObject {
    func proLoginSurface(_ controller: PPProLoginSurfaceController, didChangePhoneText text: String)
    func proLoginSurfaceDidRequestCountryCode(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapPhoneContinue(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapApple(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapGoogle(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapSupport(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapLanguage(_ controller: PPProLoginSurfaceController)
    func proLoginSurfaceDidTapProviderApplication(_ controller: PPProLoginSurfaceController)
}

@MainActor
private final class PPProLoginSurfaceModel: ObservableObject {
    @Published var phoneText = ""
    @Published var countryCode = "+974"
    @Published var isBusy = false
    @Published var isPhoneContinueEnabled = false
    @Published var showsAppleButton = true
    @Published var isRTL = Language.isRTL()
    @Published var refreshToken = UUID()
    @Published var loginFormFocusToken = 0
}

@MainActor
@objcMembers
public final class PPProLoginSurfaceController: UIViewController {
    public weak var delegate: PPProLoginSurfaceControllerDelegate?

    public var phoneText: String = "" {
        didSet {
            if model.phoneText != phoneText { model.phoneText = phoneText }
        }
    }

    public var countryCode: String = "+974" {
        didSet {
            if model.countryCode != countryCode { model.countryCode = countryCode }
        }
    }

    public var isBusy: Bool = false {
        didSet {
            if model.isBusy != isBusy { model.isBusy = isBusy }
        }
    }

    public var isPhoneContinueEnabled: Bool = false {
        didSet {
            if model.isPhoneContinueEnabled != isPhoneContinueEnabled {
                model.isPhoneContinueEnabled = isPhoneContinueEnabled
            }
        }
    }

    public var showsAppleButton: Bool = true {
        didSet {
            if model.showsAppleButton != showsAppleButton { model.showsAppleButton = showsAppleButton }
        }
    }

    private let model = PPProLoginSurfaceModel()
    private var host: UIHostingController<PPProIdentityGateView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        CitiesManager.shared().loadData()

        model.phoneText = phoneText
        model.countryCode = countryCode
        model.isBusy = isBusy
        model.isPhoneContinueEnabled = isPhoneContinueEnabled
        model.showsAppleButton = showsAppleButton
        model.isRTL = Language.isRTL()

        let root = PPProIdentityGateView(
            model: model,
            onPhoneChange: { [weak self] text in
                guard let self else { return }
                if self.phoneText != text { self.phoneText = text }
                self.delegate?.proLoginSurface(self, didChangePhoneText: text)
            },
            onCountryChanged: { [weak self] code in
                guard let self else { return }
                // Keep the child-controller public property in sync. The Objective-C
                // host reads controller.countryCode immediately before phone auth.
                self.countryCode = code
            },
            onPhoneContinue: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapPhoneContinue(self)
            },
            onApple: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapApple(self)
            },
            onGoogle: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapGoogle(self)
            },
            onSupport: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapSupport(self)
            },
            onLanguage: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapLanguage(self)
            },
            onProviderApplication: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidTapProviderApplication(self)
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        self.host = host
    }

    public func refreshLocalizationContext() {
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        model.isRTL = Language.isRTL()
        model.refreshToken = UUID()
    }

    public func focusLoginFormCard() {
        model.loginFormFocusToken &+= 1
    }
}

private struct PPProIdentityGateView: View {
    @ObservedObject var model: PPProLoginSurfaceModel

    let onPhoneChange: (String) -> Void
    let onCountryChanged: (String) -> Void
    let onPhoneContinue: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onSupport: () -> Void
    let onLanguage: () -> Void
    let onProviderApplication: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    @State private var phoneFocused = false
    @State private var showCountryPicker = false
    @State private var appeared = false
    @State private var orbiting = false
    @State private var focusFlash = false
    @State private var handledFocusToken = 0

    private var palette: PPProPalette { .resolve(colorScheme) }
    private var isRTL: Bool { model.isRTL }

    var body: some View {
        let _ = model.refreshToken
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        identityHeader
                            .padding(.top, max(geometry.safeAreaInsets.top + 6, 18))

                        identityCore(compact: geometry.size.width < 700)

                        authenticationPanel
                            .id("authentication-panel")

                        providerAccessStrip

                        footer
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom + 18, 24))
                    }
                    .padding(.horizontal, geometry.size.width < 700 ? 18 : 36)
                    .frame(maxWidth: 840)
                    .frame(maxWidth: .infinity)
                }
                .background(ambientBackground)
                .onReceive(model.$loginFormFocusToken) { token in
                    guard token != 0, token != handledFocusToken else { return }
                    handledFocusToken = token
                    withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
                        proxy.scrollTo("authentication-panel", anchor: .center)
                    }
                    guard !reduceMotion else { return }
                    focusFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        focusFlash = false
                    }
                }
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            appeared = true
            if !reduceMotion { orbiting = true }
        }
    }

    private var ambientBackground: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()

            Circle()
                .fill(palette.accent.opacity(palette.isDark ? 0.09 : 0.075))
                .frame(width: 330, height: 330)
                .blur(radius: 2)
                .offset(x: isRTL ? -130 : 130, y: -150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isRTL ? .topLeading : .topTrailing)

            Circle()
                .fill(palette.accentStrong.opacity(palette.isDark ? 0.06 : 0.045))
                .frame(width: 280, height: 280)
                .offset(x: isRTL ? 130 : -130, y: 130)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isRTL ? .bottomTrailing : .bottomLeading)
        }
    }

    private var identityHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image("AD_LOGO")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .padding(5)
                    .background(palette.surface, in: Circle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("PulseCommand_BrandName"))
                        .font(PPProType.bold(18, relativeTo: .headline))
                        .foregroundStyle(palette.text)
                    Text(localized("ProLoginPhoneSectionTitle"))
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                compactUtility(
                    title: localized("ProLoginSupportChip"),
                    symbol: "questionmark.circle",
                    action: onSupport
                )
                compactUtility(
                    title: Language.languageVal() == 0 ? "AR" : "EN",
                    symbol: "globe",
                    action: onLanguage
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: appeared)
    }

    private func identityCore(compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(palette.surface.opacity(palette.isDark ? 0.82 : 0.90))

            identityCoreContent(compact: compact)
                .padding(compact ? 18 : 26)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(palette.hairline, lineWidth: 0.8)
        }
        .shadow(color: palette.shadow, radius: 26, x: 0, y: 14)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.90), value: appeared)
    }

    /// The orbit is a fixed-size instrument: each caller states the exact side so
    /// every ring radius, and the satellite that rides them, is derived from one
    /// constant. It previously read a `GeometryReader`, which made the geometry a
    /// function of an offered size that can still settle after the perpetual spin
    /// has started — on device the assembly was measured snapping from one radius
    /// set to another about three seconds after appearing (satellite orbit radius
    /// 175px → 134px in a single frame, then drifting for a further 0.2s) while
    /// the static core kept its exact size, because the settle landed inside the
    /// running `repeatForever` transaction.
    @ViewBuilder
    private func identityCoreContent(compact: Bool) -> some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: 18) {
                loginOrbit(side: 104)
                    .frame(maxWidth: .infinity, alignment: .center)

                identityCoreCopy(compact: true)
            }
        } else {
            HStack(spacing: compact ? 18 : 32) {
                loginOrbit(side: compact ? 122 : 164)
                    .layoutPriority(1)

                identityCoreCopy(compact: compact)
            }
        }
    }

    private func identityCoreCopy(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(localized("ProLoginSubtitle"))
                .font(PPProType.bold(compact ? 29 : 38, relativeTo: .largeTitle))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(localized("ProLoginAuthHint"))
                .font(PPProType.regular(compact ? 14 : 16))
                .foregroundStyle(palette.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if sizeCategory.isAccessibilityCategory {
                    VStack(alignment: .leading, spacing: 8) {
                        trustPill(symbol: "checkmark.shield.fill", title: localized("ProLoginAccessTitle"))
                        trustPill(symbol: "person.2.badge.key.fill", title: localized("ProLoginSupportTitle"))
                    }
                } else {
                    HStack(spacing: 8) {
                        trustPill(symbol: "checkmark.shield.fill", title: localized("ProLoginAccessTitle"))
                        trustPill(symbol: "person.2.badge.key.fill", title: localized("ProLoginSupportTitle"))
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loginOrbit(side: CGFloat) -> some View {
        let primaryDiameter = side * 0.88
        // The satellite rides the primary arc's own centreline, so one value
        // owns both and they cannot drift apart.
        let orbitRadius = primaryDiameter / 2

        return ZStack {
            // Background ambient glow behind the orbit
            Circle()
                .fill(palette.accent.opacity(palette.isDark ? 0.18 : 0.08))
                .frame(width: side * 0.62, height: side * 0.62)
                .blur(radius: 10)

            // Outer orbital hairline track
            Circle()
                .strokeBorder(palette.accent.opacity(palette.isDark ? 0.20 : 0.12), lineWidth: 1)
                .frame(width: side * 0.94, height: side * 0.94)

            // Secondary counter-harmonic orbital arc
            Circle()
                .trim(from: 0.0, to: Self.secondaryArcSweep)
                .stroke(
                    AngularGradient(
                        colors: [palette.accent.opacity(0.0), palette.accent.opacity(0.28), palette.accent.opacity(0.0)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: side * 0.74, height: side * 0.74)
                .rotationEffect(.degrees(orbiting && !reduceMotion ? -360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 14).repeatForever(autoreverses: false), value: orbiting)

            // Primary NextGen V6 Living Orbit (Arc + Leading Glowing Satellite Node)
            ZStack {
                Circle()
                    .trim(from: 0.0, to: Self.primaryArcSweep)
                    .stroke(
                        AngularGradient(
                            colors: [
                                palette.accent.opacity(0.0),
                                palette.accent.opacity(0.35),
                                palette.accent
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )

                // Satellite bead fastened to the sweep's leading tip.
                //
                // It starts where `Circle().trim` starts its path and is then
                // carried along that same path by exactly the swept fraction, so
                // the bead lands on the tip by construction. The previous
                // hard-coded `cos/sin(0.68 · 2π)` offset assumed one particular
                // path origin and direction; under the RTL environment this
                // surface always runs in, the rendered sweep and that assumption
                // disagreed and the bead orbited ~55° away from the arc it was
                // supposed to lead.
                Circle()
                    .fill(palette.accent)
                    .frame(width: 7.5, height: 7.5)
                    .shadow(color: palette.accent.opacity(0.75), radius: 5, x: 0, y: 0)
                    .offset(x: orbitRadius)
                    .frame(width: primaryDiameter, height: primaryDiameter)
                    .rotationEffect(.degrees(Double(Self.primaryArcSweep) * 360))
            }
            .frame(width: primaryDiameter, height: primaryDiameter)
            .rotationEffect(.degrees(orbiting && !reduceMotion ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 8.5).repeatForever(autoreverses: false), value: orbiting)

            // Core Specular Glass Capsule
            Circle()
                .fill(palette.accentSoft)
                .frame(width: side * 0.54, height: side * 0.54)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(palette.isDark ? 0.40 : 0.75),
                                    palette.accent.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .shadow(
                    color: Color.black.opacity(palette.isDark ? 0.22 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 3
                )

            // Center Identity Emblem
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: side * 0.22, weight: .bold))
                .foregroundStyle(palette.accent)
                .shadow(color: palette.accent.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .frame(width: side, height: side)
        // Geometry is never part of the perpetual spin: if a size or appearance
        // change does reach this subtree, it applies instantly instead of being
        // interpolated by the in-flight repeating animation.
        .transaction { transaction in
            if transaction.animation != nil, orbiting {
                transaction.animation = nil
            }
        }
        .accessibilityHidden(true)
    }

    /// Swept fractions of the two orbital arcs. The satellite reuses the primary
    /// value, so changing the sweep can never leave the bead behind.
    private static let primaryArcSweep: CGFloat = 0.68
    private static let secondaryArcSweep: CGFloat = 0.36

    private func trustPill(symbol: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(PPProType.medium(11, relativeTo: .caption))
                .lineLimit(sizeCategory.isAccessibilityCategory ? nil : 1)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 9)
        .frame(minHeight: sizeCategory.isAccessibilityCategory ? 44 : 30)
        .background(palette.accentSoft, in: Capsule())
    }

    private var authenticationPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localized("ProLoginAuthHeading"))
                        .font(PPProType.bold(27, relativeTo: .title2))
                        .foregroundStyle(palette.text)
                    Text(localized("ProLoginFormSubtitle"))
                        .font(PPProType.regular(14))
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 46, height: 46)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            phoneEntry
            continueButton

            HStack(spacing: 12) {
                Rectangle().fill(palette.hairline).frame(height: 1)
                Text(localized("ProLoginOr"))
                    .font(PPProType.regular(12, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                Rectangle().fill(palette.hairline).frame(height: 1)
            }

            VStack(spacing: 10) {
                if model.showsAppleButton {
                    identityProviderButton(
                        title: localized("ProLoginSignInWithApple"),
                        symbol: "applelogo",
                        action: onApple
                    )
                }
                identityProviderButton(
                    title: localized("ProLoginSignInWithGoogle"),
                    symbol: "g.circle.fill",
                    action: onGoogle
                )
            }
        }
        .padding(20)
        .background(palette.surface.opacity(palette.isDark ? 0.88 : 0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(focusFlash ? palette.accent.opacity(0.70) : palette.hairline, lineWidth: focusFlash ? 1.5 : 0.8)
        }
        .shadow(color: focusFlash ? palette.accent.opacity(0.13) : palette.shadow, radius: focusFlash ? 32 : 22, x: 0, y: 12)
        .scaleEffect(focusFlash && !reduceMotion ? 1.01 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.80), value: focusFlash)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(reduceMotion ? nil : .spring(response: 0.70, dampingFraction: 0.90).delay(0.06), value: appeared)
    }

    private var phoneEntry: some View {
        let currentCountry = ProCountry.sorted(for: isRTL).first(where: { $0.phoneCode == model.countryCode })
        let emphasized = phoneFocused || focusFlash

        return HStack(spacing: 0) {
            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 6) {
                    if let currentCountry {
                        Text(currentCountry.flag).font(.system(size: 22))
                    }
                    Text(model.countryCode)
                        .font(PPProType.medium(15))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.secondary)
                }
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 57)
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            Rectangle()
                .fill(emphasized ? palette.accent.opacity(0.34) : palette.hairline)
                .frame(width: 1, height: 30)

            PPPhoneNumberTextField(
                text: Binding(get: { model.phoneText }, set: { model.phoneText = $0 }),
                isFocused: $phoneFocused,
                placeholder: localized("ProLoginPhonePlaceholder"),
                isEnabled: !model.isBusy,
                onChange: onPhoneChange
            )
            .padding(.horizontal, 15)
            .frame(minHeight: 57)
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(
            palette.accentSoft.opacity(emphasized ? 1.0 : 0.65),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(emphasized ? palette.accent.opacity(0.35) : palette.hairline, lineWidth: emphasized ? 1.2 : 0.8)
        }
        .sheet(isPresented: $showCountryPicker) {
            PPCountryPickerView(isRTL: isRTL, selectedCode: model.countryCode) { country in
                model.countryCode = country.phoneCode
                onCountryChanged(country.phoneCode)
            }
        }
    }

    private var continueButton: some View {
        let disabled = !model.isPhoneContinueEnabled || model.isBusy
        return Button(action: onPhoneContinue) {
            HStack(spacing: 10) {
                Text(localized("ProLoginContinuePhone"))
                    .font(PPProType.bold(16, relativeTo: .headline))
                Spacer(minLength: 8)
                if model.isBusy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(disabled ? palette.secondary : Color.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 55)
            .background(
                disabled ? palette.accent.opacity(0.16) : palette.accent,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(PPProPressStyle())
        .disabled(disabled)
        .shadow(color: disabled ? .clear : palette.accent.opacity(0.20), radius: 18, x: 0, y: 10)
    }

    private func identityProviderButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(PPProType.medium(15))
                Spacer(minLength: 8)
                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.secondary)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(palette.accentSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(palette.hairline, lineWidth: 0.8)
            }
        }
        .buttonStyle(PPProPressStyle())
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.45 : 1)
    }

    private var providerAccessStrip: some View {
        Button(action: onProviderApplication) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("ProLoginAccessTitle"))
                        .font(PPProType.medium(14))
                        .foregroundStyle(palette.text)
                    Text(localized("ProLoginAccessSummary"))
                        .font(PPProType.regular(12))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(sizeCategory.isAccessibilityCategory ? 3 : 2)
                }

                Spacer(minLength: 8)
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(palette.secondary)
            }
            .padding(14)
            .background(palette.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.hairline, lineWidth: 0.8)
            }
        }
        .buttonStyle(PPProPressStyle())
        .disabled(model.isBusy)
    }

    private var footer: some View {
        Text(localized("PulseCommand_BrandName"))
            .font(PPProType.medium(12, relativeTo: .caption))
            .foregroundStyle(palette.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func compactUtility(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(PPProType.medium(12, relativeTo: .caption))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .ppProMaterialSurface(radius: 13, palette: palette, interactive: true)
        }
        .buttonStyle(PPProPressStyle())
        .disabled(model.isBusy)
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: nil)
    }
}

// ============================================================================
// MARK: - PULSE COMMAND CENTER — Objective-C bridge descriptors
// ============================================================================

@objcMembers
public final class PPProCommandCapabilityDescriptor: NSObject {
    public var identifier: String = ""
    public var title: String = ""
    public var subtitle: String = ""
    public var symbolName: String = "circle.grid.2x2.fill"
    public var routeTag: String = ""
    public var actionCount: Int = 0
    public var isReadOnly: Bool = false
}

@objcMembers
public final class PPProCommandDetailDescriptor: NSObject {
    public var identifier: String = ""
    public var title: String = ""
    public var value: String = ""
    public var symbolName: String = "info.circle.fill"
}

@objcMembers
public final class PPProCommandQuickActionDescriptor: NSObject {
    public var identifier: String = ""
    public var title: String = ""
    public var symbolName: String = "bolt.fill"
    public var isDestructive: Bool = false
}

@objcMembers
public final class PPProCommandActionDescriptor: NSObject {
    // Semantic action data only. UIKit remains the owner of validation and routing.
    public var signalIdentifier: String = ""
    public var capabilityIdentifier: String = ""
    public var actionKind: String = ""
    public var entityID: String = ""
    public var requestID: String = ""
    public var orderID: String = ""
    public var fulfillmentID: String = ""
    public var companyID: String = ""
    public var expectedStatus: String = ""
    public var priorityRawValue: Int = 0
    public var primaryActionTitle: String = ""
    public var workspaceActionTitle: String = ""
    public var workspaceRouteTag: String = ""
    public var detailsActionTitle: String = ""
    public var interactionKind: String = "primary"
    public var detailRows: [PPProCommandDetailDescriptor] = []
    public var quickActions: [PPProCommandQuickActionDescriptor] = []
    public var isConcreteTarget: Bool = false
    public var isPrimaryActionPermitted: Bool = false
}

@objcMembers
public final class PPProCommandSignalDescriptor: NSObject {
    public var identifier: String = ""
    public var capabilityIdentifiers: [String] = []
    public var title: String = ""
    public var subtitle: String = ""
    public var symbolName: String = "bolt.fill"
    public var routeTag: String = ""
    public var badgeCount: Int = 0
    /// 0 = normal, 1 = elevated, 2 = critical. Production bridge currently
    /// uses 0/1 unless the backend owns a real critical-state definition.
    public var priorityRawValue: Int = 0
    public var isUnseen: Bool = false
    public var actionTarget: PPProCommandActionDescriptor?
}

@objcMembers
public final class PPProCommandCenterSnapshotDescriptor: NSObject {
    public var workspaceEyebrow: String = ""
    public var greeting: String = ""
    public var displayName: String = ""
    public var roleSummary: String = ""
    public var avatarURLString: String = ""
    public var isRTL: Bool = false
    public var workspaceCount: Int = 0
    public var actionCount: Int = 0
    public var inboxUnreadCount: Int = 0
    public var supportUnreadCount: Int = 0
    public var isOperationalLoading: Bool = true
    public var isOperationalDegraded: Bool = false
    public var canRetryOperationalData: Bool = false
    public var capabilities: [PPProCommandCapabilityDescriptor] = []
    public var signals: [PPProCommandSignalDescriptor] = []
}

private struct PPProCommandCapability: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let routeTag: String
    let actionCount: Int
    let isReadOnly: Bool
}

private enum PPProCommandPriority: Int, Equatable {
    case normal = 0
    case elevated = 1
    case critical = 2

    var gravityPull: CGFloat {
        switch self {
        case .normal: return 0
        case .elevated: return 14
        case .critical: return 28
        }
    }
}

private struct PPProCommandDetail: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let symbolName: String
}

private struct PPProCommandQuickAction: Identifiable, Equatable {
    let id: String
    let title: String
    let symbolName: String
    let isDestructive: Bool
}

private struct PPProCommandActionTarget: Equatable {
    let signalIdentifier: String
    let capabilityIdentifier: String
    let actionKind: String
    let entityID: String
    let requestID: String
    let orderID: String
    let fulfillmentID: String
    let companyID: String
    let expectedStatus: String
    let priorityRawValue: Int
    let primaryActionTitle: String
    let workspaceActionTitle: String
    let workspaceRouteTag: String
    let detailsActionTitle: String
    let interactionKind: String
    let detailRows: [PPProCommandDetail]
    let quickActions: [PPProCommandQuickAction]
    let isConcreteTarget: Bool
    let isPrimaryActionPermitted: Bool

    init(descriptor: PPProCommandActionDescriptor?, fallbackWorkspaceRouteTag: String) {
        let resolvedWorkspaceRouteTag = descriptor?.workspaceRouteTag.isEmpty == false
            ? descriptor?.workspaceRouteTag ?? ""
            : fallbackWorkspaceRouteTag

        signalIdentifier = descriptor?.signalIdentifier ?? ""
        capabilityIdentifier = descriptor?.capabilityIdentifier ?? ""
        actionKind = descriptor?.actionKind ?? "workspace"
        entityID = descriptor?.entityID ?? ""
        requestID = descriptor?.requestID ?? ""
        orderID = descriptor?.orderID ?? ""
        fulfillmentID = descriptor?.fulfillmentID ?? ""
        companyID = descriptor?.companyID ?? ""
        expectedStatus = descriptor?.expectedStatus ?? ""
        priorityRawValue = descriptor?.priorityRawValue ?? 0
        primaryActionTitle = descriptor?.primaryActionTitle ?? ""
        workspaceActionTitle = descriptor?.workspaceActionTitle ?? ""
        workspaceRouteTag = resolvedWorkspaceRouteTag
        detailsActionTitle = descriptor?.detailsActionTitle ?? ""
        interactionKind = descriptor?.interactionKind ?? "primary"
        detailRows = descriptor?.detailRows.compactMap { detail in
            guard !detail.identifier.isEmpty, !detail.title.isEmpty, !detail.value.isEmpty else { return nil }
            return PPProCommandDetail(
                id: detail.identifier,
                title: detail.title,
                value: detail.value,
                symbolName: detail.symbolName
            )
        } ?? []
        quickActions = descriptor?.quickActions.compactMap { action in
            guard !action.identifier.isEmpty, !action.title.isEmpty else { return nil }
            return PPProCommandQuickAction(
                id: action.identifier,
                title: action.title,
                symbolName: action.symbolName,
                isDestructive: action.isDestructive
            )
        } ?? []
        isConcreteTarget = descriptor?.isConcreteTarget ?? false
        isPrimaryActionPermitted = descriptor?.isPrimaryActionPermitted ?? !resolvedWorkspaceRouteTag.isEmpty
    }

    var hasDetailsNavigation: Bool {
        isConcreteTarget || !detailsActionTitle.isEmpty
    }

    var hasWorkspaceNavigation: Bool {
        isConcreteTarget && !workspaceActionTitle.isEmpty && !workspaceRouteTag.isEmpty
    }

    var hasFocusMenu: Bool {
        hasDetailsNavigation || hasWorkspaceNavigation || !quickActions.isEmpty
    }

    func makeDescriptor() -> PPProCommandActionDescriptor {
        let descriptor = PPProCommandActionDescriptor()
        descriptor.signalIdentifier = signalIdentifier
        descriptor.capabilityIdentifier = capabilityIdentifier
        descriptor.actionKind = actionKind
        descriptor.entityID = entityID
        descriptor.requestID = requestID
        descriptor.orderID = orderID
        descriptor.fulfillmentID = fulfillmentID
        descriptor.companyID = companyID
        descriptor.expectedStatus = expectedStatus
        descriptor.priorityRawValue = priorityRawValue
        descriptor.primaryActionTitle = primaryActionTitle
        descriptor.workspaceActionTitle = workspaceActionTitle
        descriptor.workspaceRouteTag = workspaceRouteTag
        descriptor.detailsActionTitle = detailsActionTitle
        descriptor.interactionKind = interactionKind
        descriptor.detailRows = detailRows.map { detail in
            let descriptor = PPProCommandDetailDescriptor()
            descriptor.identifier = detail.id
            descriptor.title = detail.title
            descriptor.value = detail.value
            descriptor.symbolName = detail.symbolName
            return descriptor
        }
        descriptor.quickActions = quickActions.map { action in
            let descriptor = PPProCommandQuickActionDescriptor()
            descriptor.identifier = action.id
            descriptor.title = action.title
            descriptor.symbolName = action.symbolName
            descriptor.isDestructive = action.isDestructive
            return descriptor
        }
        descriptor.isConcreteTarget = isConcreteTarget
        descriptor.isPrimaryActionPermitted = isPrimaryActionPermitted
        return descriptor
    }

    func makeWorkspaceDescriptor() -> PPProCommandActionDescriptor {
        let descriptor = makeDescriptor()
        descriptor.actionKind = "workspace"
        descriptor.interactionKind = "workspace"
        descriptor.primaryActionTitle = workspaceActionTitle
        descriptor.isConcreteTarget = false
        descriptor.isPrimaryActionPermitted = !workspaceRouteTag.isEmpty
        return descriptor
    }

    func makeDetailsDescriptor() -> PPProCommandActionDescriptor {
        let descriptor = makeDescriptor()
        descriptor.interactionKind = "details"
        descriptor.primaryActionTitle = detailsActionTitle
        return descriptor
    }

    func makeQuickActionDescriptor(_ action: PPProCommandQuickAction) -> PPProCommandActionDescriptor {
        let descriptor = makeDescriptor()
        descriptor.actionKind = action.id
        descriptor.interactionKind = "quickAction"
        descriptor.primaryActionTitle = action.title
        return descriptor
    }
}

private struct PPProCommandSignal: Identifiable, Equatable {
    let id: String
    let capabilityIDs: [String]
    let title: String
    let subtitle: String
    let symbolName: String
    let routeTag: String
    let badgeCount: Int
    let priority: PPProCommandPriority
    let isUnseen: Bool
    let actionTarget: PPProCommandActionTarget
}

private struct PPProCommandCenterSnapshot: Equatable {
    var workspaceEyebrow = ""
    var greeting = ""
    var displayName = ""
    var roleSummary = ""
    var avatarURLString = ""
    var isRTL = Language.isRTL()
    var workspaceCount = 0
    var actionCount = 0
    var inboxUnreadCount = 0
    var supportUnreadCount = 0
    var isOperationalLoading = true
    var isOperationalDegraded = false
    var canRetryOperationalData = false
    var capabilities: [PPProCommandCapability] = []
    var signals: [PPProCommandSignal] = []

    static var placeholder: PPProCommandCenterSnapshot { PPProCommandCenterSnapshot() }
}

private extension PPProCommandCenterSnapshotDescriptor {
    func makeValue() -> PPProCommandCenterSnapshot {
        PPProCommandCenterSnapshot(
            workspaceEyebrow: workspaceEyebrow,
            greeting: greeting,
            displayName: displayName,
            roleSummary: roleSummary,
            avatarURLString: avatarURLString,
            isRTL: isRTL,
            workspaceCount: workspaceCount,
            actionCount: actionCount,
            inboxUnreadCount: inboxUnreadCount,
            supportUnreadCount: supportUnreadCount,
            isOperationalLoading: isOperationalLoading,
            isOperationalDegraded: isOperationalDegraded,
            canRetryOperationalData: canRetryOperationalData,
            capabilities: capabilities.map {
                PPProCommandCapability(
                    id: $0.identifier,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    symbolName: $0.symbolName,
                    routeTag: $0.routeTag,
                    actionCount: $0.actionCount,
                    isReadOnly: $0.isReadOnly
                )
            },
            signals: Array(signals.prefix(6)).map {
                PPProCommandSignal(
                    id: $0.identifier,
                    capabilityIDs: $0.capabilityIdentifiers,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    symbolName: $0.symbolName,
                    routeTag: $0.routeTag,
                    badgeCount: $0.badgeCount,
                    priority: PPProCommandPriority(rawValue: $0.priorityRawValue) ?? .normal,
                    isUnseen: $0.isUnseen,
                    actionTarget: PPProCommandActionTarget(
                        descriptor: $0.actionTarget,
                        fallbackWorkspaceRouteTag: $0.routeTag
                    )
                )
            }
        )
    }
}

@MainActor
private final class PPProCommandCenterStore: ObservableObject {
    @Published private(set) var snapshot: PPProCommandCenterSnapshot = .placeholder
    @Published var selectedCapabilityID = "all"
    @Published var focusedSignalID: String?

    func apply(_ snapshot: PPProCommandCenterSnapshot) {
        self.snapshot = snapshot
        if selectedCapabilityID != "all",
           !snapshot.capabilities.contains(where: { $0.id == selectedCapabilityID }) {
            selectedCapabilityID = "all"
        }
        if let focusedSignalID,
           !snapshot.signals.contains(where: { $0.id == focusedSignalID }) {
            self.focusedSignalID = nil
        }
    }

    var selectedCapability: PPProCommandCapability? {
        snapshot.capabilities.first(where: { $0.id == selectedCapabilityID })
    }

    var visibleSignals: [PPProCommandSignal] {
        let source: [PPProCommandSignal]
        if selectedCapabilityID == "all" {
            source = snapshot.signals
        } else {
            source = snapshot.signals.filter {
                $0.capabilityIDs.isEmpty || $0.capabilityIDs.contains(selectedCapabilityID)
            }
        }
        return source.sorted(by: Self.signalSort)
    }

    var focusedSignal: PPProCommandSignal? {
        guard let focusedSignalID else { return nil }
        return snapshot.signals.first(where: { $0.id == focusedSignalID })
    }

    private static func signalSort(_ lhs: PPProCommandSignal, _ rhs: PPProCommandSignal) -> Bool {
        if lhs.priority.rawValue != rhs.priority.rawValue {
            return lhs.priority.rawValue > rhs.priority.rawValue
        }
        if lhs.isUnseen != rhs.isUnseen { return lhs.isUnseen && !rhs.isUnseen }
        return lhs.badgeCount > rhs.badgeCount
    }
}

@objc public protocol PPProCommandCenterSurfaceControllerDelegate: AnyObject {
    func commandCenterSurface(_ controller: PPProCommandCenterSurfaceController, didActivateRoute route: String)
    func commandCenterSurface(_ controller: PPProCommandCenterSurfaceController, didActivateActionTarget target: PPProCommandActionDescriptor)
    func commandCenterSurfaceDidRequestProfile(_ controller: PPProCommandCenterSurfaceController)
}

@MainActor
@objcMembers
public final class PPProCommandCenterSurfaceController: UIViewController {
    public weak var delegate: PPProCommandCenterSurfaceControllerDelegate?

    private let store = PPProCommandCenterStore()
    private var host: UIHostingController<PPProCommandCenterView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installHostIfNeeded()
    }

    public func applySnapshot(_ descriptor: PPProCommandCenterSnapshotDescriptor, animated: Bool) {
        let value = descriptor.makeValue()
        if animated && !UIAccessibility.isReduceMotionEnabled {
            withAnimation(.easeInOut(duration: 0.22)) {
                store.apply(value)
            }
        } else {
            store.apply(value)
        }
    }

    public func resetToUnifiedPulseAnimated(_ animated: Bool) {
        let change = {
            self.store.selectedCapabilityID = "all"
            self.store.focusedSignalID = nil
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) { change() }
        } else {
            change()
        }
    }

    private func installHostIfNeeded() {
        guard host == nil else { return }

        let root = PPProCommandCenterView(
            store: store,
            onRoute: { [weak self] route in
                guard let self else { return }
                self.delegate?.commandCenterSurface(self, didActivateRoute: route)
            },
            onActionTarget: { [weak self] descriptor in
                guard let self else { return }
                self.delegate?.commandCenterSurface(self, didActivateActionTarget: descriptor)
            },
            onWorkspaceTarget: { [weak self] descriptor in
                guard let self else { return }
                self.delegate?.commandCenterSurface(self, didActivateActionTarget: descriptor)
            },
            onProfile: { [weak self] in
                guard let self else { return }
                self.delegate?.commandCenterSurfaceDidRequestProfile(self)
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        self.host = host
    }
}

private struct PPProCommandPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PPProCommandSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let radius: CGFloat
    let palette: PPProPalette
    let elevated: Bool
    let material: Bool

    func body(content: Content) -> some View {
        let border = colorSchemeContrast == .increased
            ? palette.secondary.opacity(0.62)
            : palette.hairline

        content
            .background {
                if material && !reduceTransparency {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.thinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(palette.surface)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8)
            }
            .shadow(color: elevated ? palette.shadow : .clear, radius: elevated ? 12 : 0, x: 0, y: elevated ? 6 : 0)
    }
}

private extension View {
    func ppProCommandSurface(
        radius: CGFloat,
        palette: PPProPalette,
        elevated: Bool = false,
        material: Bool = false
    ) -> some View {
        modifier(PPProCommandSurfaceModifier(
            radius: radius,
            palette: palette,
            elevated: elevated,
            material: material
        ))
    }
}

// MARK: - Capability prism dropdown plumbing (NextGen V6)

private struct PPProPrismAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private enum PPProPrismMetrics {
    static let verticalPadding: CGFloat = 10
    static let allRowHeight: CGFloat = 54
    static let rowHeight: CGFloat = 58
    static let dividerHeight: CGFloat = 1
    static let sectionDividerBlock: CGFloat = 13
    static let topGap: CGFloat = 10
    static let maxWidth: CGFloat = 380
}

private enum PPProCommandRhythm {
    /// Breathing room between independent command sections.
    static let sectionGap: CGFloat = 24
    /// Gap between tightly related groups inside one section.
    static let groupGap: CGFloat = 16
    /// Gap inside a section (header to content).
    static let innerGap: CGFloat = 12
}

private struct PPProCommandCenterView: View {
    @ObservedObject var store: PPProCommandCenterStore
    let onRoute: (String) -> Void
    let onActionTarget: (PPProCommandActionDescriptor) -> Void
    let onWorkspaceTarget: (PPProCommandActionDescriptor) -> Void
    let onProfile: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var focusNamespace
    @State private var isPrismExpanded: Bool = false

    private var palette: PPProPalette { .resolve(colorScheme) }
    private var snapshot: PPProCommandCenterSnapshot { store.snapshot }
    private var isRTL: Bool { snapshot.isRTL }
    private var isInitialLoading: Bool {
        snapshot.isOperationalLoading && snapshot.displayName.isEmpty && snapshot.capabilities.isEmpty
    }
    private var usesWideComposition: Bool {
        horizontalSizeClass == .regular && !sizeCategory.isAccessibilityCategory
    }
    private var scopeActionCount: Int {
        store.selectedCapability?.actionCount ?? snapshot.actionCount
    }
    private var commandHairline: Color {
        colorSchemeContrast == .increased ? palette.secondary.opacity(0.62) : palette.hairline
    }
    private var commandHairlineWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.2 : 0.8
    }

    var body: some View {
        ZStack {
            commandBackground

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    commandHeader
                        .padding(.top, 10)

                    if isInitialLoading {
                        commandLoadingState
                            .padding(.top, 20)
                    } else {
                        if !snapshot.capabilities.isEmpty {
                            capabilityPrism
                                .padding(.top, PPProCommandRhythm.groupGap)
                        }

                        commandComposition
                            .padding(.top, PPProCommandRhythm.sectionGap)
                    }
                }
                .padding(.horizontal, usesWideComposition ? 24 : 16)
                .padding(.bottom, 32)
            }
            .accessibilityHidden(store.focusedSignal != nil || isPrismExpanded)

            if let signal = store.focusedSignal {
                focusLayer(signal)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.97).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .accessibilityAddTraits(.isModal)
                    .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.focusedSignal == nil && !isInitialLoading {
                commandDock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .overlayPreferenceValue(PPProPrismAnchorPreferenceKey.self) { anchor in
            prismOverlay(anchor: anchor)
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    private var commandBackground: some View {
        palette.canvas.ignoresSafeArea()
    }

    private var commandHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            PPProAvatarView(urlString: snapshot.avatarURLString, fallback: avatarInitials)
                .frame(width: 42, height: 42)
                .overlay {
                    Circle().stroke(commandHairline, lineWidth: commandHairlineWidth)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.greeting.isEmpty ? localized("PulseCommand_Workspace_Eyebrow") : snapshot.greeting)
                    .font(PPProType.regular(11, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                Text(snapshot.displayName.isEmpty ? localized("PulseCommand_BrandName") : snapshot.displayName)
                    .font(PPProType.bold(19, relativeTo: .title3))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: onProfile) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
                    .background(palette.surfaceElevated, in: Circle())
                    .overlay {
                        Circle().stroke(commandHairline, lineWidth: commandHairlineWidth)
                    }
                    .shadow(color: palette.shadow, radius: 8, x: 0, y: 3)
                    .contentShape(Circle())
            }
            .buttonStyle(PPProCommandPressStyle())
            .disabled(isInitialLoading)
            .accessibilityHidden(isInitialLoading)
            .accessibilityLabel(localized("ProfileSettings"))
            .accessibilityHint(localized("ProfileSettingsSubtitle"))
        }
        .frame(minHeight: 44)
    }

    private var capabilityPrism: some View {
        Button {
            togglePrism()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: store.selectedCapability?.symbolName ?? "scope")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCapabilityTitle)
                        .font(PPProType.bold(15, relativeTo: .headline))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(scopeSubtitle)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isPrismExpanded ? palette.accentText : palette.secondary)
                    .rotationEffect(.degrees(isPrismExpanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .ppProCommandSurface(radius: 18, palette: palette, material: true)
        }
        .buttonStyle(PPProCommandPressStyle())
        .anchorPreference(key: PPProPrismAnchorPreferenceKey.self, value: .bounds) { $0 }
        .accessibilityLabel(localized("PulseCommand_AllCapabilities"))
        .accessibilityValue(selectedCapabilityTitle)
        .accessibilityHint(localized("PulseCommand_CapabilityPrism_Subtitle"))
    }

    private func togglePrism() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            isPrismExpanded.toggle()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func collapsePrism() {
        guard isPrismExpanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.40, dampingFraction: 0.90)) {
            isPrismExpanded = false
        }
    }

    private func choosePrismCapability(_ identifier: String) {
        collapsePrism()
        selectCapability(identifier)
    }

    private var prismAllRowHeight: CGFloat {
        sizeCategory.isAccessibilityCategory ? 60 : PPProPrismMetrics.allRowHeight
    }

    private var prismRowHeight: CGFloat {
        sizeCategory.isAccessibilityCategory ? 66 : PPProPrismMetrics.rowHeight
    }

    private var prismPanelContentHeight: CGFloat {
        let rowCount = CGFloat(snapshot.capabilities.count)
        return PPProPrismMetrics.verticalPadding * 2
            + prismAllRowHeight
            + PPProPrismMetrics.sectionDividerBlock
            + rowCount * prismRowHeight
            + max(0, rowCount - 1) * PPProPrismMetrics.dividerHeight
    }

    @ViewBuilder
    private func prismOverlay(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if isPrismExpanded, let anchor {
                let trigger = proxy[anchor]
                let panelWidth = min(proxy.size.width - 32, PPProPrismMetrics.maxWidth)
                let availableHeight = max(260, proxy.size.height - trigger.maxY - PPProPrismMetrics.topGap - 16)
                let panelHeight = min(prismPanelContentHeight, availableHeight)

                ZStack(alignment: .top) {
                    Button {
                        collapsePrism()
                    } label: {
                        Color.black
                            .opacity(palette.isDark ? 0.42 : 0.22)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("Cancel"))
                    .transition(.opacity)

                    prismPanel
                        .frame(width: panelWidth, height: panelHeight)
                        .offset(y: trigger.maxY + PPProPrismMetrics.topGap)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityAddTraits(.isModal)
            }
        }
    }

    private var prismPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                prismRow(
                    symbol: "square.grid.2x2",
                    title: localized("PulseCommand_AllCapabilities"),
                    subtitle: "",
                    isSelected: store.selectedCapabilityID == "all",
                    badgeCount: 0,
                    isReadOnly: false,
                    rowHeight: prismAllRowHeight,
                    action: { choosePrismCapability("all") }
                )

                Rectangle()
                    .fill(commandHairline)
                    .frame(height: PPProPrismMetrics.dividerHeight)
                    .padding(.vertical, (PPProPrismMetrics.sectionDividerBlock - PPProPrismMetrics.dividerHeight) / 2)
                    .padding(.horizontal, 14)
                    .accessibilityHidden(true)

                ForEach(Array(snapshot.capabilities.enumerated()), id: \.element.id) { index, capability in
                    prismRow(
                        symbol: capability.symbolName,
                        title: capability.title,
                        subtitle: capability.subtitle,
                        isSelected: store.selectedCapabilityID == capability.id,
                        badgeCount: capability.actionCount,
                        isReadOnly: capability.isReadOnly,
                        rowHeight: prismRowHeight,
                        action: { choosePrismCapability(capability.id) }
                    )

                    if index < snapshot.capabilities.count - 1 {
                        Rectangle()
                            .fill(commandHairline)
                            .frame(height: PPProPrismMetrics.dividerHeight)
                            .padding(.leading, 62)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, PPProPrismMetrics.verticalPadding)
        }
        .ppProCommandSurface(radius: 26, palette: palette, elevated: true, material: true)
    }

    private func prismRow(
        symbol: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        badgeCount: Int,
        isReadOnly: Bool,
        rowHeight: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : palette.accentText)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? palette.accent : palette.accentSoft,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PPProType.bold(15, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(PPProType.regular(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isReadOnly {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                } else if badgeCount > 0 {
                    Text(badgeCount, format: .number)
                        .font(PPProType.bold(12, relativeTo: .caption))
                        .foregroundStyle(palette.accentText)
                        .monospacedDigit()
                        .frame(minWidth: 28, minHeight: 24)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var commandComposition: some View {
        if usesWideComposition {
            HStack(alignment: .top, spacing: PPProCommandRhythm.groupGap) {
                VStack(spacing: 0) {
                    decisionSpine
                    if !snapshot.isOperationalLoading || !store.visibleSignals.isEmpty {
                        operationHorizon
                            .padding(.top, PPProCommandRhythm.groupGap)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                capabilityLane
                    .frame(maxWidth: 420, alignment: .top)
            }
        } else {
            VStack(spacing: 0) {
                decisionSpine
                if !snapshot.isOperationalLoading || !store.visibleSignals.isEmpty {
                    operationHorizon
                        .padding(.top, PPProCommandRhythm.groupGap)
                }
                capabilityLane
                    .padding(.top, PPProCommandRhythm.sectionGap)
            }
        }
    }

    private var commandLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(palette.accentText)
                .controlSize(.large)
            Text(localized("Loading"))
                .font(PPProType.medium(15, relativeTo: .body))
                .foregroundStyle(palette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityElement(children: .combine)
    }

    private var decisionSpine: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("PulseCommand_Workspace_Eyebrow"))
                        .font(PPProType.medium(11, relativeTo: .caption))
                        .foregroundStyle(palette.accentText)
                    Text(selectedCapabilityTitle)
                        .font(PPProType.bold(22, relativeTo: .title2))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(snapshot.isOperationalLoading && store.visibleSignals.isEmpty ? "—" : "\(scopeActionCount)")
                        .font(PPProType.bold(32, relativeTo: .largeTitle))
                        .foregroundStyle(palette.text)
                        .monospacedDigit()
                    Text(pulseState)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle()
                .fill(commandHairline)
                .frame(height: 1)
                .accessibilityHidden(true)

            if snapshot.isOperationalLoading {
                operationalLoadingCommand

                if !store.visibleSignals.isEmpty {
                    Rectangle()
                        .fill(commandHairline)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                    visibleSignalRows
                }
            } else {
                if snapshot.isOperationalDegraded {
                    operationalDegradedCommand

                    if !store.visibleSignals.isEmpty {
                        Rectangle()
                            .fill(commandHairline)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }

                if !store.visibleSignals.isEmpty {
                    visibleSignalRows
                } else if !snapshot.isOperationalDegraded {
                    allClearCommand
                }
            }
        }
        .ppProCommandSurface(radius: 24, palette: palette, elevated: true)
    }

    private var operationalLoadingCommand: some View {
        HStack(alignment: .center, spacing: 13) {
            ProgressView()
                .tint(palette.accentText)
                .controlSize(.regular)
                .frame(width: 40, height: 40)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(localized("PulseCommand_LoadingOperational"))
                    .font(PPProType.bold(16, relativeTo: .headline))
                    .foregroundStyle(palette.text)
                Text(localized("PulseCommand_LoadingOperationalSubtitle"))
                    .font(PPProType.regular(12, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var operationalDegradedCommand: some View {
        if snapshot.canRetryOperationalData {
            Button { activate("__retryCommandData") } label: {
                operationalDegradedLabel
                    .contentShape(Rectangle())
            }
            .buttonStyle(PPProCommandPressStyle())
            .accessibilityLabel(localized("PulseCommand_DegradedTitle"))
            .accessibilityValue(localized("PulseCommand_DegradedSubtitle"))
            .accessibilityHint(localized("PulseCommand_Retry"))
        } else {
            operationalDegradedLabel
                .accessibilityElement(children: .combine)
        }
    }

    private var operationalDegradedLabel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accentText)
                Text(localized("PulseCommand_DegradedTitle"))
                    .font(PPProType.bold(16, relativeTo: .headline))
                    .foregroundStyle(palette.text)
            }

            Text(localized("PulseCommand_DegradedSubtitle"))
                .font(PPProType.regular(12, relativeTo: .caption))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.canRetryOperationalData {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text(localized("PulseCommand_Retry"))
                        .font(PPProType.bold(12, relativeTo: .caption))
                }
                .foregroundStyle(palette.accentText)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.accentSoft)
    }

    @ViewBuilder
    private var visibleSignalRows: some View {
        if let primary = store.visibleSignals.first {
            primarySignalRow(primary)

            ForEach(Array(store.visibleSignals.dropFirst())) { signal in
                Rectangle()
                    .fill(commandHairline)
                    .frame(height: 1)
                    .padding(.leading, 64)
                    .accessibilityHidden(true)
                secondarySignalRow(signal)
            }
        }
    }

    private func primarySignalRow(_ signal: PPProCommandSignal) -> some View {
        Button { focusSignal(signal) } label: {
            HStack(alignment: .center, spacing: 13) {
                PPProSignalIcon(signal: signal, palette: palette)
                    .matchedGeometryEffect(
                        id: reduceMotion ? "pulse-\(signal.id)" : "signal-\(signal.id)",
                        in: focusNamespace
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("PulseCommand_PriorityNow"))
                        .font(PPProType.medium(10, relativeTo: .caption2))
                        .foregroundStyle(palette.accentText)
                    Text(signal.title)
                        .font(PPProType.bold(17, relativeTo: .headline))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(signal.subtitle)
                        .font(PPProType.regular(12, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                signalTrailingMetric(signal, prominent: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .background(palette.accentSoft)
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(signal.title)
        .accessibilityValue(signalAccessibilityValue(signal, isPrimary: true))
        .accessibilityHint(localized("PulseCommand_OpenFocusHint"))
    }

    private func secondarySignalRow(_ signal: PPProCommandSignal) -> some View {
        Button { focusSignal(signal) } label: {
            HStack(alignment: .center, spacing: 13) {
                PPProSignalIcon(signal: signal, palette: palette)
                    .matchedGeometryEffect(
                        id: reduceMotion ? "pulse-\(signal.id)" : "signal-\(signal.id)",
                        in: focusNamespace
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.title)
                        .font(PPProType.medium(15, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    Text(signal.subtitle)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                signalTrailingMetric(signal, prominent: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(signal.title)
        .accessibilityValue(signalAccessibilityValue(signal, isPrimary: false))
        .accessibilityHint(localized("PulseCommand_OpenFocusHint"))
    }

    private func signalTrailingMetric(_ signal: PPProCommandSignal, prominent: Bool) -> some View {
        HStack(spacing: 8) {
            if signal.badgeCount > 0 {
                Text(signal.badgeCount > 99 ? "99+" : "\(signal.badgeCount)")
                    .font(PPProType.bold(prominent ? 14 : 12, relativeTo: .caption))
                    .foregroundStyle(palette.accentText)
                    .monospacedDigit()
                    .frame(minWidth: prominent ? 34 : 28, minHeight: prominent ? 34 : 28)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.secondary)
        }
    }

    @ViewBuilder
    private var allClearCommand: some View {
        if let capability = store.selectedCapability ?? snapshot.capabilities.first {
            Button { activate(capability.routeTag) } label: {
                HStack(spacing: 13) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(width: 40, height: 40)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("PulseCommand_NoPendingDecisions"))
                            .font(PPProType.bold(16, relativeTo: .headline))
                            .foregroundStyle(palette.text)
                        Text(capability.title)
                            .font(PPProType.regular(12, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.accentText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPProCommandPressStyle())
            .accessibilityLabel(localized("PulseCommand_NoPendingDecisions"))
            .accessibilityValue(capability.title)
            .accessibilityHint(localized("PulseCommand_OpenExecutionWorkspace"))
        } else {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 40, height: 40)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(localized("StatusNoPartnerAccess"))
                    .font(PPProType.regular(14, relativeTo: .body))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .accessibilityElement(children: .combine)
        }
    }

    private var operationHorizon: some View {
        operationHorizonContent
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(commandHairline, lineWidth: commandHairlineWidth)
        }
    }

    @ViewBuilder
    private var operationHorizonContent: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(spacing: 0) {
                horizonMetric(value: "\(snapshot.workspaceCount)", title: localized("DashboardHero_Metric_Workspaces"))
                horizonDivider
                horizonMetric(value: "\(snapshot.signals.count)", title: localized("PulseCommand_LiveSignal"))
                horizonDivider
                horizonMetric(value: "\(snapshot.inboxUnreadCount + snapshot.supportUnreadCount)", title: localized("Unread"))
            }
        } else {
            HStack(spacing: 14) {
                horizonMetric(value: "\(snapshot.workspaceCount)", title: localized("DashboardHero_Metric_Workspaces"))
                horizonMetric(value: "\(snapshot.signals.count)", title: localized("PulseCommand_LiveSignal"))
                horizonMetric(value: "\(snapshot.inboxUnreadCount + snapshot.supportUnreadCount)", title: localized("Unread"))
            }
        }
    }

    private var horizonDivider: some View {
        Rectangle()
            .fill(commandHairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func horizonMetric(value: String, title: String) -> some View {
        if sizeCategory.isAccessibilityCategory {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(PPProType.regular(15, relativeTo: .body))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                Text(value)
                    .font(PPProType.bold(22, relativeTo: .title3))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(value)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(PPProType.bold(20, relativeTo: .title3))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                Text(title)
                    .font(PPProType.regular(10, relativeTo: .caption2))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(value)
        }
    }

    @ViewBuilder
    private var capabilityLane: some View {
        if !snapshot.capabilities.isEmpty {
            VStack(alignment: .leading, spacing: PPProCommandRhythm.innerGap) {
                HStack {
                    Text(localized("PulseCommand_EnabledCapabilities"))
                        .font(PPProType.bold(15, relativeTo: .headline))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Text(snapshot.capabilities.count, format: .number)
                        .font(PPProType.medium(12))
                        .foregroundStyle(palette.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(snapshot.capabilities.enumerated()), id: \.element.id) { index, capability in
                        Button { activate(capability.routeTag) } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: capability.symbolName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.accentText)
                                    .frame(width: 36, height: 36)
                                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(capability.title)
                                        .font(PPProType.bold(15, relativeTo: .subheadline))
                                        .foregroundStyle(palette.text)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(capability.subtitle)
                                        .font(PPProType.regular(11, relativeTo: .caption))
                                        .foregroundStyle(palette.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 8)

                                if capability.isReadOnly {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(palette.secondary)
                                } else if capability.actionCount > 0 {
                                    Text(capability.actionCount, format: .number)
                                        .font(PPProType.bold(12, relativeTo: .caption))
                                        .foregroundStyle(palette.accentText)
                                        .monospacedDigit()
                                        .frame(minWidth: 28, minHeight: 28)
                                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

                                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(palette.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PPProCommandPressStyle())
                        .disabled(capability.routeTag.isEmpty)
                        .accessibilityLabel(capability.title)
                        .accessibilityValue(capabilityAccessibilityValue(capability))

                        if index < snapshot.capabilities.count - 1 {
                            Rectangle()
                                .fill(commandHairline)
                                .frame(height: 1)
                                .padding(.leading, 62)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(commandHairline, lineWidth: commandHairlineWidth)
                }
            }
        }
    }

    private func capabilityAccessibilityValue(_ capability: PPProCommandCapability) -> String {
        if capability.isReadOnly {
            return localized("DeliveryCompany_DashboardShell_Status_ReadOnly")
        }
        return capability.actionCount > 0 ? "\(capability.actionCount)" : ""
    }

    private var commandDock: some View {
        commandDockContent
        .padding(6)
        .ppProCommandSurface(radius: 22, palette: palette, elevated: true, material: true)
    }

    @ViewBuilder
    private var commandDockContent: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    pulseDockButton
                    workDockButton
                }
                HStack(spacing: 6) {
                    notificationsDockButton
                    moreDockButton
                }
            }
        } else {
            HStack(spacing: 6) {
                pulseDockButton
                workDockButton
                notificationsDockButton
                moreDockButton
            }
        }
    }

    private var pulseDockButton: some View {
        dockButton(title: localized("PulseCommand_Dock_Pulse"), symbol: "waveform.path.ecg", active: true) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.86)) {
                store.selectedCapabilityID = "all"
            }
        }
    }

    private var workDockButton: some View {
        dockButton(title: localized("PulseCommand_Dock_Work"), symbol: "bolt.fill", active: false) {
            if let signal = store.visibleSignals.first { focusSignal(signal) }
            else if let capability = store.selectedCapability ?? snapshot.capabilities.first { activate(capability.routeTag) }
        }
    }

    private var notificationsDockButton: some View {
        dockButton(
            title: localized("NotificationsTitle"),
            symbol: "bell.fill",
            active: false,
            badge: snapshot.inboxUnreadCount
        ) {
            activate("notificationsInbox")
        }
    }

    private var moreDockButton: some View {
        dockButton(title: localized("PulseCommand_Dock_More"), symbol: "ellipsis", active: false) {
            activate("__more")
        }
    }

    private func dockButton(
        title: String,
        symbol: String,
        active: Bool,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
                        .font(PPProType.medium(10, relativeTo: .caption2))
                        .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(active ? palette.accentText : palette.secondary)
                .frame(maxWidth: .infinity, minHeight: sizeCategory.isAccessibilityCategory ? 58 : 44)
                .background(active ? palette.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minHeight: 16)
                        .background(palette.accent, in: Capsule())
                        .offset(x: 1, y: -2)
                }
            }
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(title)
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
    }

    private func focusLayer(_ signal: PPProCommandSignal) -> some View {
        PPProCommandFocusView(
            signal: signal,
            capabilityTitle: capabilityTitle(for: signal),
            actionTarget: signal.actionTarget,
            isRTL: isRTL,
            palette: palette,
            reduceMotion: reduceMotion,
            namespace: focusNamespace,
            onBack: dismissFocus,
            onExecute: {
                dismissFocus()
                onActionTarget(signal.actionTarget.makeDescriptor())
            },
            onOpenDetails: {
                dismissFocus()
                onActionTarget(signal.actionTarget.makeDetailsDescriptor())
            },
            onOpenWorkspace: {
                dismissFocus()
                onWorkspaceTarget(signal.actionTarget.makeWorkspaceDescriptor())
            },
            onQuickAction: { action in
                onActionTarget(signal.actionTarget.makeQuickActionDescriptor(action))
            }
        )
    }

    private func focusSignal(_ signal: PPProCommandSignal) {
        collapsePrism()
        withAnimation(reduceMotion ? nil : .spring(response: 0.50, dampingFraction: 0.86)) {
            store.focusedSignalID = signal.id
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func selectCapability(_ identifier: String) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
            store.selectedCapabilityID = identifier
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func dismissFocus() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.88)) {
            store.focusedSignalID = nil
        }
    }

    private func activate(_ route: String) {
        guard !route.isEmpty else { return }
        onRoute(route)
    }

    private var selectedCapabilityTitle: String {
        if store.selectedCapabilityID == "all" {
            return localized("PulseCommand_AllCapabilities")
        }
        return store.selectedCapability?.title ?? localized("PulseCommand_AllCapabilities")
    }

    private var scopeSubtitle: String {
        if let capability = store.selectedCapability, !capability.subtitle.isEmpty {
            return capability.subtitle
        }
        return snapshot.roleSummary
    }

    private var pulseState: String {
        if snapshot.capabilities.isEmpty {
            return localized("StatusAccessDenied")
        }
        if snapshot.isOperationalLoading {
            return localized("PulseCommand_LoadingOperational")
        }
        if snapshot.isOperationalDegraded {
            return localized("PulseCommand_DegradedTitle")
        }
        if scopeActionCount > 0 {
            return localized("DashboardHero_Status_Action")
        }
        return snapshot.workspaceCount > 1
            ? localized("DashboardHero_Status_MultiWorkspace")
            : localized("DashboardHero_Status_Live")
    }

    private var avatarInitials: String {
        let words = snapshot.displayName
            .split(separator: " ")
            .prefix(2)
        let result = words.compactMap(\.first).map(String.init).joined()
        return result.isEmpty ? "PP" : result.uppercased()
    }

    private func capabilityTitle(for signal: PPProCommandSignal) -> String {
        guard let id = signal.capabilityIDs.first,
              let capability = snapshot.capabilities.first(where: { $0.id == id }) else {
            return snapshot.workspaceEyebrow
        }
        return capability.title
    }

    private func signalAccessibilityValue(_ signal: PPProCommandSignal, isPrimary: Bool) -> String {
        var components: [String] = []
        if isPrimary {
            components.append(localized("PulseCommand_PriorityNow"))
        }
        if signal.isUnseen {
            components.append(localized("New"))
        }
        if !signal.subtitle.isEmpty {
            components.append(signal.subtitle)
        }
        if signal.badgeCount > 0 {
            components.append(String(
                format: localized("PulseCommand_CountFormat"),
                "\(signal.badgeCount)"
            ))
        }
        return components.joined(separator: isRTL ? "، " : ", ")
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: nil)
    }
}

private struct PPProSignalIcon: View {
    let signal: PPProCommandSignal
    let palette: PPProPalette

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: signal.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(signal.priority == .critical ? Color.white : palette.accentText)
                .frame(width: 36, height: 36)
                .background(
                    signal.priority == .critical ? palette.accent : palette.accentSoft,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            if signal.isUnseen {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 7, height: 7)
                    .overlay { Circle().stroke(Color.white.opacity(0.75), lineWidth: 1) }
                    .offset(x: 2, y: -2)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PPProCommandFocusView: View {
    let signal: PPProCommandSignal
    let capabilityTitle: String
    let actionTarget: PPProCommandActionTarget
    let isRTL: Bool
    let palette: PPProPalette
    let reduceMotion: Bool
    let namespace: Namespace.ID
    let onBack: () -> Void
    let onExecute: () -> Void
    let onOpenDetails: () -> Void
    let onOpenWorkspace: () -> Void
    let onQuickAction: (PPProCommandQuickAction) -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AccessibilityFocusState private var isHeadingFocused: Bool

    @State private var showingConfirmationAlert: Bool = false
    @State private var showSuccessBanner: Bool = false

    private var focusHairline: Color {
        colorSchemeContrast == .increased ? palette.secondary.opacity(0.62) : palette.hairline
    }

    private var focusHairlineWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.2 : 0.8
    }

    var body: some View {
        ZStack(alignment: .top) {
            palette.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: isRTL ? "chevron.right" : "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(palette.text)
                                .frame(width: 44, height: 44)
                                .ppProCommandSurface(radius: 22, palette: palette, elevated: true)
                        }
                        .buttonStyle(PPProCommandPressStyle())
                        .accessibilityLabel(localized("PulseCommand_Back"))

                        Spacer()

                        VStack(spacing: 0) {
                            Text(localized("PulseCommand_CommandFocus"))
                                .font(PPProType.bold(9, relativeTo: .caption2))
                                .tracking(isRTL ? 0 : 0.8)
                                .foregroundStyle(palette.secondary)
                            Text(capabilityTitle)
                                .font(PPProType.medium(13))
                                .foregroundStyle(palette.text)
                        }

                        Spacer()

                        Text(signal.badgeCount > 0 ? "\(signal.badgeCount)" : "")
                            .font(PPProType.bold(12))
                            .foregroundStyle(palette.secondary)
                            .frame(width: 42)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 9) {
                            PPProSignalIcon(signal: signal, palette: palette)
                                .matchedGeometryEffect(id: reduceMotion ? "focus-\(signal.id)" : "signal-\(signal.id)", in: namespace)
                            Text(capabilityTitle)
                                .font(PPProType.medium(12, relativeTo: .caption))
                                .foregroundStyle(palette.accentText)
                        }

                        Text(signal.title)
                            .font(PPProType.bold(34, relativeTo: .largeTitle))
                            .foregroundStyle(palette.text)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 15)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isHeadingFocused)

                        Text(signal.subtitle)
                            .font(PPProType.regular(15, relativeTo: .body))
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 7)
                    }
                    .padding(20)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(focusHairline, lineWidth: focusHairlineWidth)
                    }
                    .shadow(color: palette.shadow, radius: 22, x: 0, y: 12)
                    .padding(.top, 18)

                    if !actionTarget.detailRows.isEmpty {
                        focusDetails
                            .padding(.top, 12)
                    }

                    HStack(spacing: 10) {
                        Button(action: { showingConfirmationAlert = true }) {
                            HStack {
                                Text(primaryActionTitle)
                                    .font(PPProType.bold(16, relativeTo: .headline))
                                Spacer()
                                Image(systemName: actionTarget.isPrimaryActionPermitted
                                    ? (isRTL ? "arrow.left" : "arrow.right")
                                    : "lock.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 56)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        }
                        .buttonStyle(PPProCommandPressStyle())
                        .disabled(!actionTarget.isPrimaryActionPermitted)
                        .opacity(actionTarget.isPrimaryActionPermitted ? 1 : 0.48)
                        .accessibilityLabel(primaryActionTitle)
                        .accessibilityValue(actionTarget.isPrimaryActionPermitted ? "" : localized("StatusAccessDenied"))

                        if actionTarget.hasFocusMenu {
                            focusMoreMenu
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }

            if showSuccessBanner {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(localized("PulseCommand_SuccessExecuted", fallback: "Action executed successfully"))
                        .font(PPProType.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Color.green, in: Capsule())
                .shadow(color: palette.shadow, radius: 16, x: 0, y: 8)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert(primaryActionTitle, isPresented: $showingConfirmationAlert) {
            Button(primaryActionTitle, role: actionTarget.actionKind == "cancel" ? .destructive : nil) {
                confirmAndExecuteCTA()
            }
            Button(localized("Cancel"), role: .cancel) {}
        } message: {
            Text(localized("PulseCommand_ConfirmCTAPrompt", fallback: "Are you sure you want to execute this action?"))
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            isHeadingFocused = true
        }
    }

    private func confirmAndExecuteCTA() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showSuccessBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            onExecute()
            onBack()
        }
    }

    private var focusDetails: some View {
        VStack(spacing: 0) {
            ForEach(actionTarget.detailRows) { detail in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: detail.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(width: 34, height: 34)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(detail.title)
                            .font(PPProType.medium(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                        Text(detail.value)
                            .font(PPProType.bold(14, relativeTo: .subheadline))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if detail.id != actionTarget.detailRows.last?.id {
                        Rectangle()
                            .fill(focusHairline)
                            .frame(height: focusHairlineWidth)
                            .padding(.leading, 62)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(focusHairline, lineWidth: focusHairlineWidth)
        }
    }

    private var focusMoreMenu: some View {
        Menu {
            if actionTarget.hasDetailsNavigation {
                Button(action: onOpenDetails) {
                    Label(
                        actionTarget.detailsActionTitle.isEmpty ? localized("PulseCommand_ViewDetails", fallback: "View details") : actionTarget.detailsActionTitle,
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
            }

            if actionTarget.hasWorkspaceNavigation {
                Button(action: onOpenWorkspace) {
                    Label(actionTarget.workspaceActionTitle, systemImage: "rectangle.stack.fill")
                }
            }

            if !actionTarget.quickActions.isEmpty {
                Divider()
                ForEach(actionTarget.quickActions) { action in
                    Button(role: action.isDestructive ? .destructive : nil) {
                        onQuickAction(action)
                    } label: {
                        Label(action.title, systemImage: action.symbolName)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(palette.text)
                .frame(width: 56, height: 56)
                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(focusHairline, lineWidth: focusHairlineWidth)
                }
                .shadow(color: palette.shadow, radius: 10, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .accessibilityLabel(localized("PulseCommand_TargetActions"))
    }

    private var primaryActionTitle: String {
        actionTarget.primaryActionTitle.isEmpty
            ? localized("PulseCommand_OpenExecutionWorkspace")
            : actionTarget.primaryActionTitle
    }

    private func localized(_ key: String, fallback: String? = nil) -> String {
        let text = Language.get(key, alter: nil)
        if text == key, let fallback = fallback {
            return fallback
        }
        return text ?? ""
    }
}

private struct PPProAvatarView: View {
    let urlString: String
    let fallback: String

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: UIColor.ppSurfaceOverlay))
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .clipShape(Circle())
    }

    private var fallbackView: some View {
        Text(fallback)
            .font(PPProType.bold(13))
            .foregroundStyle(Color(uiColor: UIColor.ppTextPrimary))
    }
}
