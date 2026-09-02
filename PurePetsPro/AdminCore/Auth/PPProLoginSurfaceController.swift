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

enum PPProType {
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

struct PPProPalette {
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

private struct PPProOrbitArcNode: View {
    let diameter: CGFloat
    let sweep: CGFloat
    let accentColor: Color
    let isDark: Bool

    var body: some View {
        let radius = diameter / 2
        let sweepAngleRadians = sweep * 2 * .pi
        let tipX = radius * cos(sweepAngleRadians)
        let tipY = radius * sin(sweepAngleRadians)

        ZStack {
            // Arc with smooth luminous gradient leading into the node
            Circle()
                .trim(from: 0.0, to: sweep)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            accentColor.opacity(0.0),
                            accentColor.opacity(isDark ? 0.35 : 0.25),
                            accentColor.opacity(0.95)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(Double(sweep) * 360)
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )

            // Leading Node (Mathematically locked to exact arc tip)
            Circle()
                .fill(accentColor)
                .frame(width: 7.5, height: 7.5)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isDark ? 0.65 : 0.90), lineWidth: 1.2)
                }
                .shadow(color: accentColor.opacity(0.65), radius: 4, x: 0, y: 0)
                .offset(x: tipX, y: tipY)
        }
        .frame(width: diameter, height: diameter)
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

    // Temporary product switch: keep the decorative hero orbit out of the view
    // hierarchy without disturbing the login copy, layout, or authentication flow.
    private static let showsLoginHeroOrbit = false

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
            if Self.showsLoginHeroOrbit && !reduceMotion { orbiting = true }
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
                if Self.showsLoginHeroOrbit {
                    loginOrbit(side: 104)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                identityCoreCopy(compact: true)
            }
        } else {
            HStack(spacing: compact ? 18 : 32) {
                if Self.showsLoginHeroOrbit {
                    loginOrbit(side: compact ? 122 : 164)
                        .layoutPriority(1)
                }

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
        let secondaryDiameter = side * 0.74
        let coreDiameter = side * 0.54

        return ZStack {
            // Background ambient glow behind the orbit
            Circle()
                .fill(palette.accent.opacity(palette.isDark ? 0.16 : 0.08))
                .frame(width: side * 0.68, height: side * 0.68)
                .blur(radius: 12)

            // Outer orbital hairline track (crisp reference ring)
            Circle()
                .strokeBorder(palette.accent.opacity(palette.isDark ? 0.18 : 0.10), lineWidth: 1)
                .frame(width: side * 0.94, height: side * 0.94)

            // Secondary counter-harmonic orbital arc (slow, elegant ambient motion)
            Circle()
                .trim(from: 0.0, to: Self.secondaryArcSweep)
                .stroke(
                    AngularGradient(
                        colors: [
                            palette.accent.opacity(0.0),
                            palette.accent.opacity(palette.isDark ? 0.32 : 0.22),
                            palette.accent.opacity(0.0)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: secondaryDiameter, height: secondaryDiameter)
                .rotationEffect(.degrees(orbiting && !reduceMotion ? -360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: 18.0).repeatForever(autoreverses: false),
                    value: orbiting
                )

            // Primary NextGen V6 Living Orbit (Arc + Mathematically Locked Satellite Node)
            PPProOrbitArcNode(
                diameter: primaryDiameter,
                sweep: Self.primaryArcSweep,
                accentColor: palette.accent,
                isDark: palette.isDark
            )
            .rotationEffect(.degrees(orbiting && !reduceMotion ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: 12.0).repeatForever(autoreverses: false),
                value: orbiting
            )

            // Core Specular Glass Capsule
            Circle()
                .fill(palette.accentSoft)
                .frame(width: coreDiameter, height: coreDiameter)
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
        .accessibilityHidden(true)
    }

    /// Swept fractions of the two orbital arcs.
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

struct PPProCommandCapability: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let routeTag: String
    let actionCount: Int
    let isReadOnly: Bool
}

enum PPProCommandPriority: Int, Equatable {
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

struct PPProCommandDetail: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let symbolName: String
}

struct PPProCommandQuickAction: Identifiable, Equatable {
    let id: String
    let title: String
    let symbolName: String
    let isDestructive: Bool
}

struct PPProCommandActionTarget: Equatable {
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

struct PPProCommandSignal: Identifiable, Equatable {
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

struct PPProCommandCenterSnapshot: Equatable {
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
final class PPProCommandCenterStore: ObservableObject {
    @Published private(set) var snapshot: PPProCommandCenterSnapshot = .placeholder
    @Published var selectedCapabilityID = "all"
    @Published var focusedSignalID: String?

    /// Which dock lane is currently selected. Mirrors a UITabBarController's
    /// `selectedIndex`: the active destination stays selected while it is on
    /// top of the navigation stack, and reverts to `.pulse` (the root) once the
    /// user navigates back. The Objective-C navigation owner keeps this in sync
    /// via the surface controller because it — not SwiftUI — owns the stack.
    @Published var selectedDockTab: PPProDockTab = .pulse

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
    private var host: UIHostingController<PPProPulseView>?

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

    /// Syncs the dock's selected lane with whatever the Objective-C navigation
    /// owner has on top of the stack, so the custom dock behaves like a
    /// `UITabBarController`: the tapped lane stays selected while its pushed
    /// screen is visible and reverts to Pulse when the user navigates back.
    ///
    /// `identifier` is the pushed destination's `restorationIdentifier`
    /// (e.g. `PPProCommandCenterMenuMap`). Anything unrecognized — including the
    /// Pulse root itself — resolves to `.pulse`.
    @objc public func syncSelectedDockTab(forTopRestorationIdentifier identifier: String?) {
        let resolved: PPProDockTab
        switch identifier {
        case "PPProCommandCenterMenuMap": resolved = .menuMap
        case "PPProCommandCenterMore": resolved = .more
        case "PPProCommandCenterNotifications": resolved = .notifications
        default: resolved = .pulse
        }
        guard store.selectedDockTab != resolved else { return }
        if UIAccessibility.isReduceMotionEnabled {
            store.selectedDockTab = resolved
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                store.selectedDockTab = resolved
            }
        }
    }

    /// Menu Map for a host that owns its own navigation stack — the root
    /// `UITabBarController` — rather than pushing onto the dashboard's stack.
    ///
    /// Same `store`, therefore the same Objective-C-gated capability set. Only
    /// the route sink differs. This exists so the Menu tab can render the
    /// permission-derived map instead of a hand-written list.
    func makeMenuMapViewController(onRoute: @escaping (String) -> Void) -> UIViewController {
        let root = PPProMenuMapDestinationView(store: store, onRoute: onRoute)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        return controller
    }

    public func makeCommandCenterMenuMapViewController() -> UIViewController {
        let controller = makeMenuMapViewController { [weak self] route in
            guard let self else { return }
            self.delegate?.commandCenterSurface(self, didActivateRoute: route)
        }
        configurePushedDestination(
            controller,
            titleKey: "PulseCommand_Dock_MenuMap",
            restorationIdentifier: "PPProCommandCenterMenuMap"
        )
        return controller
    }

    /// More surface for a host that owns its own navigation stack. Same `store`,
    /// so the same Objective-C-gated capability set decides which entries exist.
    func makeMoreViewController(
        onRoute: @escaping (String) -> Void,
        onProfile: @escaping () -> Void
    ) -> UIViewController {
        let root = PPProMoreDestinationView(store: store, onRoute: onRoute, onProfile: onProfile)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        return controller
    }

    public func makeCommandCenterMoreViewController() -> UIViewController {
        let controller = makeMoreViewController(
            onRoute: { [weak self] route in
                guard let self else { return }
                self.delegate?.commandCenterSurface(self, didActivateRoute: route)
            },
            onProfile: { [weak self] in
                guard let self else { return }
                self.delegate?.commandCenterSurfaceDidRequestProfile(self)
            }
        )
        configurePushedDestination(
            controller,
            titleKey: "PulseCommand_Dock_More",
            restorationIdentifier: "PPProCommandCenterMore"
        )
        return controller
    }

    private func configurePushedDestination(
        _ controller: UIViewController,
        titleKey: String,
        restorationIdentifier: String
    ) {
        controller.title = Language.get(titleKey, alter: nil)
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.hidesBottomBarWhenPushed = true
        controller.restorationIdentifier = restorationIdentifier
        controller.view.backgroundColor = .systemBackground
    }

    private func installHostIfNeeded() {
        guard host == nil else { return }

        let root = PPProPulseView(
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

struct PPProCommandPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PPProCommandSurfaceModifier: ViewModifier {
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

extension View {
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

enum PPProCommandRhythm {
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
        // Dock hidden: official UITabBarController owns bottom navigation
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

                // Priority Fulfillment Card
                VStack(alignment: .leading, spacing: 14) {
                    // Top Row
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color(red: 0.306, green: 0.529, blue: 0.549))
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(localized("PriorityFulfillmentEyebrow"))
                                .font(PPProType.bold(12.5))
                                .foregroundColor(Color(red: 0.306, green: 0.529, blue: 0.549))
                            Text(localized("Fulfillment_Title"))
                                .font(PPProType.bold(20))
                                .foregroundColor(palette.text)
                        }

                        Spacer()

                        Text("جديد")
                            .font(PPProType.bold(13))
                            .foregroundColor(Color(red: 0.306, green: 0.529, blue: 0.549))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Color(red: 0.83, green: 0.90, blue: 0.91).opacity(colorScheme == .dark ? 0.35 : 1.0), in: Capsule())
                    }

                    // Subtitle
                    Text(localized("PriorityFulfillmentSubtitle"))
                        .font(PPProType.medium(14))
                        .foregroundColor(palette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Action Button
                    Button {
                        activate("fulfillmentOrders")
                    } label: {
                        HStack {
                            Text(localized("ReviewFulfillment"))
                                .font(PPProType.bold(15.5))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.306, green: 0.529, blue: 0.549), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(PPProCommandPressStyle())
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(colorScheme == .dark ? Color(red: 0.125, green: 0.176, blue: 0.192) : Color(red: 0.894, green: 0.937, blue: 0.941))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(colorScheme == .dark ? Color(red: 0.20, green: 0.28, blue: 0.30) : Color(red: 0.81, green: 0.88, blue: 0.89), lineWidth: 1)
                )

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

struct PPProSignalIcon: View {
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

struct PPProCommandFocusView: View {
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
    @Environment(\.sizeCategory) private var sizeCategory
    @AccessibilityFocusState private var isHeadingFocused: Bool

    private var focusHairline: Color {
        colorSchemeContrast == .increased ? palette.secondary.opacity(0.62) : palette.hairline
    }

    private var focusHairlineWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.2 : 0.8
    }

    /// At accessibility text sizes the action zone stops competing for one line
    /// and stacks instead, so neither the CTA nor the overflow control truncates.
    private var usesAccessibilityLayout: Bool { sizeCategory.isAccessibilityCategory }

    /// Every current primary Focus CTA is navigation into an existing, revalidated
    /// UIKit workflow. The true transition controls remain in those workflows.
    private var hasFullWorkspaceNavigation: Bool {
        !actionTarget.workspaceActionTitle.isEmpty && !actionTarget.workspaceRouteTag.isEmpty
    }

    /// The persistent bottom dock owns workspace navigation; the overflow keeps
    /// only target details and guarded/destructive secondary actions.
    private var hasOverflowActions: Bool {
        actionTarget.hasDetailsNavigation || !actionTarget.quickActions.isEmpty
    }

    private var workspacePrompt: String {
        switch signal.id {
        case "notifications": return localized("PulseCommand_AllNotificationsPrompt")
        case "fulfillment": return localized("PulseCommand_AllFulfillmentPrompt")
        case "delivery": return localized("PulseCommand_AllDeliveriesPrompt")
        case "deliveryCompany": return localized("PulseCommand_AllCompanyDeliveriesPrompt")
        case "supportChats": return localized("PulseCommand_AllSupportChatsPrompt")
        default: return localized("PulseCommand_AllWorkspacePrompt")
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            palette.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Button(action: onBack) {
                            Image(systemName: isRTL ? "chevron.right" : "chevron.left")
                                .font(.system(size: PPProGlyph.medium, weight: .bold))
                                .foregroundStyle(palette.text)
                                .frame(width: 44, height: 44)
                                .ppProCommandSurface(radius: 22, palette: palette, elevated: true)
                        }
                        .buttonStyle(PPProCommandPressStyle())
                        .accessibilityLabel(localized("PulseCommand_Back"))

                        Spacer(minLength: 0)

                        VStack(spacing: 0) {
                            Text(localized("PulseCommand_CommandFocus"))
                                .font(PPProType.bold(9, relativeTo: .caption2))
                                .tracking(isRTL ? 0 : 0.8)
                                .foregroundStyle(palette.secondary)
                            Text(capabilityTitle)
                                .font(PPProType.medium(13, relativeTo: .subheadline))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .accessibilityElement(children: .combine)

                        Spacer(minLength: 0)

                        // Balances the back control so the eyebrow stays optically
                        // centred, and carries the count when there is one.
                        Group {
                            if signal.badgeCount > 0 {
                                Text(signal.badgeCount > 99 ? "99+" : "\(signal.badgeCount)")
                                    .font(PPProType.bold(13, relativeTo: .subheadline))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 8)
                                    .frame(minWidth: 44, minHeight: 30)
                                    .background(Capsule().fill(palette.accent))
                                    .accessibilityLabel(String(
                                        format: localized("PulseCommand_CountFormat"),
                                        "\(signal.badgeCount)"
                                    ))
                            } else {
                                Color.clear.frame(width: 44, height: 1)
                            }
                        }
                    }

                    focusHero
                        .padding(.top, PPProPulseRhythm.spineGap)

                    if !actionTarget.detailRows.isEmpty {
                        focusDetails
                            .padding(.top, PPProPulseRhythm.stackGap)
                    }

                    actionZone
                        .padding(.top, PPProPulseRhythm.spineGap)
                }
                .padding(.horizontal, PPProPulseRhythm.screenMargin)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            focusWorkspaceDock
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            isHeadingFocused = true
        }
    }

    /// Hero: rank, capability, title and subtitle. The priority beacon replaces
    /// the flat icon so the focused item carries the same rank encoding as the
    /// stage it came from.
    private var focusHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 11) {
                PPProPriorityBeacon(
                    priority: signal.priority,
                    symbol: signal.symbolName,
                    // Same emphasis rule as the stage this was opened from, so a
                    // focused item does not change rank on the way in.
                    emphatic: PPProPulseScope.isActionable(signal),
                    palette: palette
                )
                .matchedGeometryEffect(id: "focus-\(signal.id)", in: namespace)

                VStack(alignment: .leading, spacing: 2) {
                    if !capabilityTitle.isEmpty {
                        Text(capabilityTitle)
                            .font(PPProType.medium(12, relativeTo: .caption))
                            .foregroundStyle(palette.accentText)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text(localized("PulseCommand_PriorityNow"))
                            .font(PPProType.bold(10, relativeTo: .caption2))
                            .tracking(isRTL ? 0 : 0.6)
                            .foregroundStyle(signal.priority.tint(palette))
                        if signal.isUnseen {
                            Text(localized("New"))
                                .font(PPProType.bold(10, relativeTo: .caption2))
                                .foregroundStyle(palette.accentText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(palette.accentSoft))
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Text(signal.title)
                .font(PPProType.bold(30, relativeTo: .largeTitle))
                .foregroundStyle(palette.text)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isHeadingFocused)

            if !signal.subtitle.isEmpty {
                Text(signal.subtitle)
                    .font(PPProType.regular(15, relativeTo: .body))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
                .stroke(focusHairline, lineWidth: focusHairlineWidth)
        }
        .overlay(alignment: .leading) {
            // Same rank edge vocabulary as the queue: rank is felt, not read.
            Capsule()
                .fill(signal.priority.tint(palette))
                .frame(width: signal.priority.edgeWidth)
                .padding(.vertical, 20)
        }
        .shadow(color: palette.shadow, radius: 22, x: 0, y: 12)
    }

    /// Action zone. The CTA keeps its 56pt target and reflows above the overflow
    /// control at accessibility sizes instead of compressing beside it.
    @ViewBuilder
    private var actionZone: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: PPProPulseRhythm.stackGap) {
                primaryCTA
                if hasOverflowActions {
                    focusMoreMenu
                }
            }
        } else {
            HStack(spacing: 10) {
                primaryCTA
                if hasOverflowActions {
                    focusMoreMenu
                }
            }
        }
    }

    private var primaryCTA: some View {
        Button(action: onExecute) {
            HStack(spacing: 10) {
                Text(primaryActionTitle)
                    .font(PPProType.bold(16, relativeTo: .headline))
                    .lineLimit(usesAccessibilityLayout ? 3 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: actionTarget.isPrimaryActionPermitted
                    ? (isRTL ? "arrow.left" : "arrow.right")
                    : "lock.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, usesAccessibilityLayout ? 14 : 0)
            .frame(minHeight: 56)
            .frame(maxWidth: usesAccessibilityLayout ? CGFloat.infinity : nil)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous))
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(!actionTarget.isPrimaryActionPermitted)
        .opacity(actionTarget.isPrimaryActionPermitted ? 1 : 0.48)
        .accessibilityLabel(primaryActionTitle)
        .accessibilityValue(actionTarget.isPrimaryActionPermitted ? "" : localized("StatusAccessDenied"))
        .accessibilityHint(localized("PulseCommand_NativeExecution_Subtitle"))
    }

    @ViewBuilder
    private var focusWorkspaceDock: some View {
        if hasFullWorkspaceNavigation {
            Button(action: onOpenWorkspace) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(width: PPProGlyph.plateMedium, height: PPProGlyph.plateMedium)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workspacePrompt)
                            .font(PPProType.medium(12, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                        Text(actionTarget.workspaceActionTitle)
                            .font(PPProType.bold(15, relativeTo: .subheadline))
                            .foregroundStyle(palette.text)
                            .lineLimit(usesAccessibilityLayout ? 2 : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                        .font(.system(size: PPProGlyph.small, weight: .bold))
                        .foregroundStyle(palette.accentText)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, PPProPulseRhythm.screenMargin)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .background(palette.surfaceElevated)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(focusHairline)
                        .frame(height: focusHairlineWidth)
                }
            }
            .buttonStyle(PPProCommandPressStyle())
            .accessibilityHint(actionTarget.workspaceActionTitle)
        }
    }

    private var focusDetails: some View {
        VStack(spacing: 0) {
            ForEach(actionTarget.detailRows) { detail in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: detail.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(width: PPProGlyph.plateSmall, height: PPProGlyph.plateSmall)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(detail.title)
                            .font(PPProType.medium(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                            .padding(.leading, usesAccessibilityLayout ? 16 : 58)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: PPProRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPProRadius.card, style: .continuous)
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
            HStack(spacing: 8) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                if usesAccessibilityLayout {
                    Text(localized("PulseCommand_TargetActions"))
                        .font(PPProType.medium(15, relativeTo: .subheadline))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, usesAccessibilityLayout ? 18 : 0)
            .frame(width: usesAccessibilityLayout ? nil : 56, height: 56)
            .frame(maxWidth: usesAccessibilityLayout ? CGFloat.infinity : nil, alignment: .leading)
            .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .stroke(focusHairline, lineWidth: focusHairlineWidth)
            }
            .shadow(color: palette.shadow, radius: 10, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous))
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

struct PPProAvatarView: View {
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


// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Pulse Redesign · Design System Scales
//
// The Pro target previously had no radius / motion / elevation / icon scale in
// Swift — those values were literals at ~100 call sites. These namespaces are
// the single Swift-side source for the redesigned surfaces. Colors still come
// from PPDesignTokens.h via PPProPalette, so there remains exactly one color
// authority.
// ═══════════════════════════════════════════════════════════════════════════

/// Continuous-curvature radius scale. Every radius in the redesign resolves here.
enum PPProRadius {
    static let chip: CGFloat = 11
    static let control: CGFloat = 14
    static let tile: CGFloat = 18
    static let card: CGFloat = 22
    static let stage: CGFloat = 28
    static let dock: CGFloat = 26
}

/// Vertical rhythm for the pulse spine. Extends PPProCommandRhythm rather than
/// competing with it: the existing sectionGap/groupGap/innerGap remain valid.
enum PPProPulseRhythm {
    static let spineGap: CGFloat = 18
    static let stackGap: CGFloat = 10
    static let hairInset: CGFloat = 14
    static let railGap: CGFloat = 10
    static let screenMargin: CGFloat = 18
}

/// Motion scale. All springs stay inside the established 0.80–0.90 damping band
/// so the redesign feels continuous with the login surface.
enum PPProMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let lensSwap = Animation.spring(response: 0.40, dampingFraction: 0.88)
    static let dockMorph = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let stageChange = Animation.spring(response: 0.46, dampingFraction: 0.86)
    static let entrance = Animation.spring(response: 0.58, dampingFraction: 0.90)

    /// Staggered entrance delay, capped so a full queue never feels slow.
    static func entranceDelay(_ index: Int) -> Double {
        min(Double(index) * 0.045, 0.27)
    }
}

/// Glyph metrics, so icon weight/geometry is consistent rather than ad hoc.
enum PPProGlyph {
    static let micro: CGFloat = 10
    static let small: CGFloat = 12
    static let medium: CGFloat = 15
    static let large: CGFloat = 18

    static let plateSmall: CGFloat = 30
    static let plateMedium: CGFloat = 38
    static let plateLarge: CGFloat = 46
}

// MARK: - Priority semantics

extension PPProCommandPriority {
    /// Ranked accent. `.elevated` is the highest rank any Objective-C signal
    /// builder actually emits today (`pp_commandSignalWithIdentifier:` clamps to
    /// 0…2, but no builder passes 2), so `.elevated` — not `.critical` — has to
    /// be the one that reads as *the* decision. Binding the strongest treatment
    /// to `.critical` made the strong branch unreachable.
    func tint(_ palette: PPProPalette) -> Color {
        switch self {
        case .critical, .elevated: return palette.accent
        default: return palette.accentText.opacity(0.55)
        }
    }

    /// Whether this rank earns the emphatic plate/edge treatment. `.critical`
    /// stays included so a future builder that emits 2 is already handled.
    var isEmphatic: Bool { self != .normal }

    /// Width of the rank edge. The former 2/3/4 scale put a single point between
    /// adjacent ranks, which is not a perceptible difference on a 34–40pt edge —
    /// "rank is felt, not read" only works if the delta is visible.
    var edgeWidth: CGFloat {
        switch self {
        case .critical: return 7
        case .elevated: return 5
        default: return 3
        }
    }
}

// MARK: - Derived pulse scope

/// The single derived model behind every region of the Pulse shell.
///
/// The previous shell computed its regions independently and they disagreed:
/// `PPProVitalsStrip` was handed `snapshot.signals.count` (unfiltered) while the
/// queue rendered `store.visibleSignals` (lens-filtered), and
/// `PPProCapabilityActionBoard` was handed `snapshot.capabilities` and
/// `snapshot.signals` — both unfiltered — so the lens rail visibly changed the
/// queue while silently doing nothing to the board or the counts. Deriving all
/// of it once, here, makes that class of disagreement unrepresentable.
///
/// Nothing is authorized, filtered for permission, or routed here.
/// `capabilities`, `signals`, `routeTag`, `isConcreteTarget` and
/// `isPrimaryActionPermitted` all arrive already decided by Objective-C, and the
/// lens remains local presentation state that never fetches.
struct PPProPulseScope {

    /// How much urgency the snapshot actually justifies.
    ///
    /// The legacy stage rendered `PulseCommand_PriorityNow`, a glowing accent
    /// dot and a full accent-gradient CTA *unconditionally* — so an account whose
    /// only signal was unread notifications (`priority = 0`, no concrete target)
    /// was shown the most alarming chrome the design system owns. Tier is derived
    /// from the target the server produced, so the chrome can no longer overstate
    /// the data.
    enum Tier: Equatable {
        /// At least one in-scope signal carries a concrete, server-permitted
        /// primary action. This is the only tier that earns full accent.
        case act
        /// Signals exist, but none is a concrete permitted action — this is
        /// reading, not deciding.
        case review
        /// Nothing in scope.
        case clear
    }

    let lensID: String
    let lens: PPProCommandCapability?
    /// Lens-scoped signals, in the store's established rank order.
    let signals: [PPProCommandSignal]
    /// The signal the stage renders. For `.act` this is the highest-ranked
    /// *actionable* signal, so the stage's CTA is always a real one.
    let leadSignal: PPProCommandSignal?
    /// Everything below the stage.
    let ledger: [PPProCommandSignal]
    let tier: Tier
    let workspaceCount: Int
    let unreadCount: Int
    /// Denominator for the ledger's proportional meter. Never zero.
    let peakBadge: Int
    /// Capabilities holding pending work, promoted out of the grid.
    let activeCapabilities: [PPProCommandCapability]
    /// Idle doors, collapsed into a quiet grid.
    let idleCapabilities: [PPProCommandCapability]

    var isScoped: Bool { lensID != "all" }
    var hasCapabilities: Bool { !activeCapabilities.isEmpty || !idleCapabilities.isEmpty }
    var capabilityCount: Int { activeCapabilities.count + idleCapabilities.count }

    /// - Parameter scopedSignals: `PPProCommandCenterStore.visibleSignals`, which
    ///   already applies the lens and the established sort. Passing it in rather
    ///   than re-deriving it keeps the store the one owner of both rules —
    ///   including the invariant that a signal with empty `capabilityIDs`
    ///   (notifications, support chats) stays visible under every lens.
    init(
        snapshot: PPProCommandCenterSnapshot,
        lensID: String,
        scopedSignals: [PPProCommandSignal]
    ) {
        self.lensID = lensID
        self.lens = snapshot.capabilities.first { $0.id == lensID }
        self.signals = scopedSignals
        self.workspaceCount = snapshot.workspaceCount
        self.unreadCount = snapshot.inboxUnreadCount + snapshot.supportUnreadCount
        self.peakBadge = max(scopedSignals.map(\.badgeCount).max() ?? 1, 1)

        // Tier and lead are decided together so the stage can never present a
        // CTA the server did not mark concrete and permitted.
        let actionable = scopedSignals.filter { Self.isActionable($0) }
        if scopedSignals.isEmpty {
            self.tier = .clear
            self.leadSignal = nil
        } else if let first = actionable.first {
            self.tier = .act
            self.leadSignal = first
        } else {
            self.tier = .review
            self.leadSignal = scopedSignals.first
        }

        let leadID = self.leadSignal?.id
        self.ledger = scopedSignals.filter { $0.id != leadID }

        // Owning a signal is a property of the capability, not of the lens, so
        // the partition reads the whole snapshot. The lens only affects order.
        func ownedWeight(_ capability: PPProCommandCapability) -> Int {
            snapshot.signals
                .filter { $0.capabilityIDs.contains(capability.id) }
                .reduce(0) { $0 + max($1.badgeCount, 1) }
        }

        var active: [PPProCommandCapability] = []
        var idle: [PPProCommandCapability] = []
        for capability in snapshot.capabilities {
            // The focused capability is always promoted, so choosing a lens has
            // a visible effect on this band instead of none.
            if capability.actionCount > 0 || ownedWeight(capability) > 0 || capability.id == lensID {
                active.append(capability)
            } else {
                idle.append(capability)
            }
        }

        self.activeCapabilities = active.sorted { lhs, rhs in
            if (lhs.id == lensID) != (rhs.id == lensID) { return lhs.id == lensID }
            let lw = ownedWeight(lhs), rw = ownedWeight(rhs)
            if lw != rw { return lw > rw }
            if lhs.actionCount != rhs.actionCount { return lhs.actionCount > rhs.actionCount }
            if lhs.isReadOnly != rhs.isReadOnly { return !lhs.isReadOnly }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        self.idleCapabilities = idle
    }

    /// A signal is actionable only when Objective-C resolved a concrete target,
    /// marked its primary action permitted, and supplied a title for it.
    static func isActionable(_ signal: PPProCommandSignal) -> Bool {
        let target = signal.actionTarget
        return target.isConcreteTarget
            && target.isPrimaryActionPermitted
            && !target.primaryActionTitle.isEmpty
    }

    /// Fraction of the scope's peak this signal represents, for the ledger meter.
    func meterFraction(_ signal: PPProCommandSignal) -> CGFloat {
        guard signal.badgeCount > 0 else { return 0 }
        return min(max(CGFloat(signal.badgeCount) / CGFloat(peakBadge), 0.18), 1.0)
    }

    func capabilityTitle(for signal: PPProCommandSignal, in snapshot: PPProCommandCenterSnapshot) -> String {
        guard let first = signal.capabilityIDs.first else { return "" }
        return snapshot.capabilities.first { $0.id == first }?.title ?? ""
    }
}

// MARK: - Vitals strip

/// The scope's three counts as one thin monospaced line.
///
/// `signalCount` is now the count of what is actually rendered below it. It used
/// to be `snapshot.signals.count`, so selecting a lens that owned no signals
/// left this line asserting a global figure the screen was not showing.
private struct PPProVitalsStrip: View {
    let workspaceCount: Int
    let signalCount: Int
    let unreadCount: Int
    let isScoped: Bool
    let palette: PPProPalette

    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    var body: some View {
        let items: [(Int, String)] = [
            (workspaceCount, localized("DashboardHero_Metric_Workspaces")),
            (signalCount, localized("PulseCommand_LiveSignal")),
            (unreadCount, localized("Unread"))
        ]

        Group {
            if sizeCategory.isAccessibilityCategory {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        vital(item.0, item.1, emphasised: isScoped && index == 1)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Circle()
                                .fill(palette.secondary.opacity(0.35))
                                .frame(width: 3, height: 3)
                                .padding(.horizontal, 9)
                        }
                        vital(item.0, item.1, emphasised: isScoped && index == 1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func vital(_ value: Int, _ title: String, emphasised: Bool) -> some View {
        HStack(spacing: 5) {
            Text(value, format: .number)
                .font(PPProType.bold(12, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(emphasised ? palette.accentText : palette.text)
            Text(title)
                .font(PPProType.regular(11, relativeTo: .caption))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Lens rail

/// Replaces the legacy prism dropdown (overlay + scrim + anchor preference key +
/// 7 geometry constants) for what is a cheap, reversible, local filter. A
/// horizontal rail keeps every lens one tap away and always visible.
private struct PPProLensRail: View {
    let capabilities: [PPProCommandCapability]
    let selectedID: String
    let palette: PPProPalette
    let isRTL: Bool
    let reduceMotion: Bool
    let onSelect: (String) -> Void

    @Namespace private var lensNamespace

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                lensChip(
                    id: "all",
                    title: localized("PulseCommand_AllCapabilities"),
                    symbol: "square.grid.2x2",
                    count: 0,
                    isReadOnly: false
                )
                ForEach(capabilities) { capability in
                    lensChip(
                        id: capability.id,
                        title: capability.title,
                        symbol: capability.symbolName,
                        count: capability.actionCount,
                        isReadOnly: capability.isReadOnly
                    )
                }
            }
            .padding(.horizontal, PPProPulseRhythm.screenMargin)
            .padding(.vertical, 2)
        }
        .accessibilityLabel(localized("PulseCommand_CapabilityPrism"))
    }

    private func lensChip(id: String, title: String, symbol: String, count: Int, isReadOnly: Bool) -> some View {
        let isSelected = selectedID == id
        return Button {
            onSelect(id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: PPProGlyph.small, weight: .semibold))
                Text(title)
                    .font(PPProType.medium(13, relativeTo: .subheadline))
                    .lineLimit(1)
                if isReadOnly {
                    Image(systemName: "eye.fill")
                        .font(.system(size: PPProGlyph.micro, weight: .bold))
                        .opacity(0.75)
                } else if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(PPProType.bold(10, relativeTo: .caption2))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.22) : palette.accentSoft)
                        )
                }
            }
            .foregroundStyle(isSelected ? Color.white : palette.text)
            .padding(.horizontal, 13)
            .frame(minHeight: 38)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.accent)
                        .matchedGeometryEffect(
                            id: reduceMotion ? "lens-static-\(id)" : "lens-active",
                            in: lensNamespace
                        )
                } else {
                    Capsule().fill(palette.surface)
                        .overlay(Capsule().stroke(palette.hairline, lineWidth: 0.8))
                }
            }
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Attention stage

/// The lead signal rendered *as* the stage, with chrome proportional to the tier
/// the snapshot actually justifies.
///
/// The previous stage applied one fixed presentation to every signal: the
/// `PulseCommand_PriorityNow` eyebrow, a glowing accent dot, an accent-gradient
/// count capsule and a full accent-gradient CTA — regardless of priority or
/// whether a concrete permitted target existed. Because no Objective-C signal
/// builder ever emits priority 2, and the notifications/support builders emit
/// priority 0 with no concrete target, the single most alarming presentation in
/// the app was in practice bound to its *least* urgent signal class: an account
/// whose only pending item was unread mail was shown maximum urgency.
///
/// Two other structural problems are fixed here. The whole card used to be one
/// button whose label happened to contain something shaped exactly like a
/// primary CTA — so the CTA was decorative and everything opened the same focus
/// sheet. And the "CTA" label degraded to a workspace title while still wearing
/// full accent. Now the context region and the action are two real, separately
/// labelled controls, and the action's appearance states which kind it is:
///
/// - `.act`   — filled accent, carries the server's `primaryActionTitle`, and
///              executes through the existing `onExecute` descriptor path.
/// - `.review`— tinted, carries the workspace title, and opens the workspace
///              through the existing workspace descriptor path.
private struct PPProAttentionStage: View {
    let signal: PPProCommandSignal
    let tier: PPProPulseScope.Tier
    let capabilityTitle: String
    let palette: PPProPalette
    let isRTL: Bool
    let reduceMotion: Bool
    let namespace: Namespace.ID
    /// Opens command focus for context, details and guarded quick actions.
    let onFocus: () -> Void
    /// `.act` only. Sends the concrete descriptor; Objective-C re-fetches the
    /// target, re-checks ownership/scope/permission/status and decides.
    let onExecute: () -> Void
    /// `.review` only. Opens the authoritative workspace for this signal.
    let onWorkspace: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    private var isAct: Bool { tier == .act }
    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    /// Eyebrow states the tier rather than asserting urgency unconditionally.
    private var eyebrow: String {
        isAct ? localized("PulseCommand_PriorityNow") : localized("PulseCommand_LiveSignal")
    }

    private var actionTitle: String {
        let target = signal.actionTarget
        if isAct { return target.primaryActionTitle }
        if !target.workspaceActionTitle.isEmpty { return target.workspaceActionTitle }
        return localized("PulseCommand_OpenExecutionWorkspace")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            contextControl
            actionControl
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stageBackground)
        .overlay(stageBorder)
        .matchedGeometryEffect(
            id: reduceMotion ? "stage-static-\(signal.id)" : "signal-\(signal.id)",
            in: namespace
        )
    }

    // MARK: Context — opens focus

    private var contextControl: some View {
        Button(action: onFocus) {
            HStack(alignment: .top, spacing: 13) {
                PPProPriorityBeacon(
                    priority: signal.priority,
                    symbol: signal.symbolName,
                    emphatic: isAct,
                    palette: palette
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(eyebrow)
                            .font(PPProType.bold(10, relativeTo: .caption2))
                            .tracking(isRTL ? 0 : 0.6)
                            .foregroundStyle(isAct ? palette.accentText : palette.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 20)
                            .background(
                                Capsule().fill(isAct ? palette.accentSoft : palette.hairline.opacity(0.5))
                            )

                        if !capabilityTitle.isEmpty && !isAccessibilitySize {
                            Text(capabilityTitle)
                                .font(PPProType.medium(10, relativeTo: .caption2))
                                .foregroundStyle(palette.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if signal.badgeCount > 0 {
                            Text(signal.badgeCount > 99 ? "99+" : "\(signal.badgeCount)")
                                .font(PPProType.bold(13, relativeTo: .subheadline))
                                .monospacedDigit()
                                .foregroundStyle(isAct ? Color.white : palette.accentText)
                                .padding(.horizontal, 9)
                                .frame(minHeight: 24)
                                .background(
                                    Capsule().fill(isAct ? palette.accent : palette.accentSoft)
                                )
                        }
                    }

                    Text(signal.title)
                        .font(PPProType.bold(19, relativeTo: .title3))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 4 : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !signal.subtitle.isEmpty {
                        Text(signal.subtitle)
                            .font(PPProType.regular(12, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineSpacing(1.5)
                            .lineLimit(isAccessibilitySize ? 6 : 3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(signal.title)
        .accessibilityHint(localized("PulseCommand_OpenFocusHint"))
    }

    // MARK: Action — executes or opens the workspace

    private var actionControl: some View {
        Button(action: isAct ? onExecute : onWorkspace) {
            HStack(spacing: 8) {
                Text(actionTitle)
                    .font(PPProType.bold(14, relativeTo: .subheadline))
                    .lineLimit(isAccessibilitySize ? 3 : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                    .font(.system(size: PPProGlyph.small, weight: .bold))
            }
            .foregroundStyle(isAct ? Color.white : palette.accentText)
            .padding(.horizontal, 15)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(isAct ? palette.accent : palette.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .strokeBorder(
                        isAct ? Color.white.opacity(0.22) : palette.accent.opacity(0.28),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(actionTitle)
    }

    // MARK: Chrome

    private var stageBackground: some View {
        RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
            .fill(palette.surfaceElevated)
            .overlay {
                // Accent wash belongs to `.act` only. `.review` stays a plain
                // surface so the two tiers are distinguishable at a glance.
                if isAct {
                    RadialGradient(
                        colors: [palette.accent.opacity(colorScheme == .dark ? 0.16 : 0.07), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 240
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous))
                }
            }
            .shadow(color: palette.shadow, radius: isAct ? 14 : 8, x: 0, y: isAct ? 6 : 3)
    }

    private var stageBorder: some View {
        RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
            .strokeBorder(
                isAct ? palette.accent.opacity(0.34) : palette.hairline,
                lineWidth: isAct ? 1.0 : 0.8
            )
    }
}

/// Rank plate for the stage.
///
/// The former beacon reserved its strong branch (gradient fill, white glyph,
/// accent shadow) for `.critical` and additionally ran a `repeatForever`
/// breathing ring. Since no Objective-C builder emits priority 2, that branch
/// and its perpetual animation were unreachable code guarding an animation that
/// could never start. Emphasis is now driven by the resolved tier — which does
/// vary — and there is no perpetual motion to gate.
private struct PPProPriorityBeacon: View {
    let priority: PPProCommandPriority
    let symbol: String
    let emphatic: Bool
    let palette: PPProPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                .fill(emphatic ? palette.accent : palette.accentSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                        .strokeBorder(
                            emphatic ? Color.white.opacity(0.28) : palette.accent.opacity(0.22),
                            lineWidth: 0.8
                        )
                )

            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(emphatic ? Color.white : palette.accentText)
        }
        .frame(width: PPProGlyph.plateLarge, height: PPProGlyph.plateLarge)
        .accessibilityHidden(true)
    }
}

// MARK: - Ledger row

/// A signal below the stage.
///
/// Replaces the queue row's two dead encodings. Depth opacity
/// (`max(1 - depth * 0.06, 0.76)`) spread 0.06–0.18 of alpha across a list that
/// can hold at most four rows — only five signal builders exist — so the
/// de-emphasis was imperceptible. And the priority edge differed by one point
/// between adjacent ranks.
///
/// The leading element is now a proportional meter: a fixed track whose filled
/// portion is this signal's `badgeCount` as a fraction of the scope's peak. That
/// varies with real data, so relative weight is visible without reading numbers,
/// and it is a quantity rather than a decoration.
private struct PPProLedgerRow: View {
    let signal: PPProCommandSignal
    let fraction: CGFloat
    let isActionable: Bool
    let palette: PPProPalette
    let isRTL: Bool
    let reduceMotion: Bool
    let namespace: Namespace.ID
    let onOpen: () -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }
    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    private var trackHeight: CGFloat { isAccessibilitySize ? 52 : 38 }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                meter

                ZStack {
                    RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous)
                        .fill(isActionable ? palette.accent : palette.accentSoft)
                    Image(systemName: signal.symbolName)
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(isActionable ? Color.white : palette.accentText)
                }
                .frame(width: PPProGlyph.plateSmall, height: PPProGlyph.plateSmall)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.title)
                        .font(PPProType.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 3 : 1)
                        .multilineTextAlignment(.leading)
                    if !signal.subtitle.isEmpty {
                        Text(signal.subtitle)
                            .font(PPProType.regular(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(isAccessibilitySize ? 3 : 1)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                if signal.badgeCount > 0 {
                    Text(signal.badgeCount > 99 ? "99+" : "\(signal.badgeCount)")
                        .font(PPProType.bold(12, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(palette.accentText)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 22)
                        .background(Capsule().fill(palette.accentSoft))
                        .accessibilityHidden(true)
                }

                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                    .font(.system(size: PPProGlyph.micro, weight: .bold))
                    .foregroundStyle(palette.secondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .ppProCommandSurface(radius: PPProRadius.tile, palette: palette)
            .matchedGeometryEffect(
                id: reduceMotion ? "ledger-static-\(signal.id)" : "signal-\(signal.id)",
                in: namespace
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(signal.title)
        .accessibilityValue(
            signal.badgeCount > 0
                ? String(format: localized("PulseCommand_CountFormat"), "\(signal.badgeCount)")
                : ""
        )
        .accessibilityHint(localized("PulseCommand_OpenFocusHint"))
    }

    /// Bottom-anchored proportional fill inside a fixed track. Anchoring the
    /// fill vertically keeps it correct in both layout directions without a
    /// manual RTL flip.
    private var meter: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(palette.hairline.opacity(0.55))
            Capsule()
                .fill(signal.priority.tint(palette))
                .frame(height: max(trackHeight * fraction, fraction > 0 ? 6 : 0))
        }
        .frame(width: signal.priority.edgeWidth, height: trackHeight)
        .animation(reduceMotion ? nil : PPProMotion.stageChange, value: fraction)
        .accessibilityHidden(true)
    }
}

// MARK: - Capability rail

// MARK: - Capability console

/// # Capability console
///
/// Third iteration, and the first two are recorded because they were both wrong
/// for the same underlying reason:
///
/// 1. *Rail of tiles* — icon + title only. A capability with pending work looked
///    identical to an idle one; `subtitle` was never drawn; ~60% dead space.
/// 2. *Stack of sections* — every capability got its own full-width crimson
///    "Open execution workspace" button and its own "No pending decisions" line.
///    With six capabilities that is six identical primary CTAs and six identical
///    idle strings. When everything shouts, nothing is primary — and the section
///    grew past a full screen height.
///
/// The essential purpose was never "render a list of capabilities". It is:
/// *which of my capabilities needs me, and how do I get into it now?*
///
/// So this is not a list. It is an **inspector**: one focused detail panel plus a
/// dense selector mosaic. Consequences that fall out of that choice:
///
/// - **Exactly one primary action exists on screen**, ever — it belongs to the
///   focused capability, not to all six.
/// - **The idle string appears once**, in the section summary, not per row.
/// - **Rank is spatial.** The mosaic is ordered by pending attention, so the
///   capability that needs work is first and carries a live load meter; idle ones
///   recede into quiet cells instead of demanding equal visual weight.
/// - **Density instead of scroll.** Six capabilities occupy one compact mosaic
///   rather than six screen-height cards.
///
/// Presentation only. Signals and counts come from the snapshot, the action emits
/// an existing `routeTag`, focus and selection are local state. No permission is
/// re-derived and no route string is invented.
private struct PPProCapabilityBoard: View {
    let capabilities: [PPProCommandCapability]
    /// Unfiltered snapshot signals, so a capability reports its own work
    /// regardless of which lens is active.
    let signals: [PPProCommandSignal]
    let selectedCapabilityID: String
    let palette: PPProPalette
    let isRTL: Bool
    let reduceMotion: Bool
    let onOpen: (String) -> Void
    let onFocusSignal: (PPProCommandSignal) -> Void
    let onSelectLens: (String) -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    /// Which capability the inspector is showing. `nil` means "follow the rank",
    /// so the busiest capability is focused on first paint without the operator
    /// choosing anything.
    @State private var inspectedID: String?

    @Namespace private var consoleNamespace

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    // MARK: Derivation

    /// Signals with no capability identity (notifications, support chats) belong
    /// to no capability — they stay queue-visible under every lens, which is the
    /// documented snapshot invariant.
    private func ownedSignals(_ capability: PPProCommandCapability) -> [PPProCommandSignal] {
        signals.filter { $0.capabilityIDs.contains(capability.id) }
    }

    /// Pending weight for ranking and for the load meter.
    private func attention(_ capability: PPProCommandCapability) -> Int {
        max(capability.actionCount, ownedSignals(capability).count)
    }

    /// Ordered by what needs the operator, not by declaration order.
    private var ranked: [PPProCommandCapability] {
        capabilities.sorted { lhs, rhs in
            let l = attention(lhs), r = attention(rhs)
            if l != r { return l > r }
            if lhs.isReadOnly != rhs.isReadOnly { return !lhs.isReadOnly }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var inspected: PPProCommandCapability? {
        if let inspectedID, let match = capabilities.first(where: { $0.id == inspectedID }) {
            return match
        }
        return ranked.first
    }

    private var totalAttention: Int {
        capabilities.reduce(0) { $0 + attention($1) }
    }

    private var peakAttention: Int {
        max(capabilities.map { attention($0) }.max() ?? 0, 1)
    }

    private var columns: [GridItem] {
        // One column at accessibility sizes; otherwise a dense adaptive mosaic.
        [GridItem(.adaptive(minimum: isAccessibilitySize ? 240 : 104), spacing: 8)]
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: PPProPulseRhythm.stackGap) {
            summary

            if let inspected {
                inspector(inspected)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ranked) { capability in
                    selectorCell(capability)
                }
            }
        }
        .padding(.horizontal, PPProPulseRhythm.screenMargin)
        .animation(reduceMotion ? nil : PPProMotion.stageChange, value: inspectedID)
    }

    /// The idle state is stated **once** here instead of once per capability.
    private var summary: some View {
        HStack(spacing: 7) {
            Text(localized("PulseCommand_EnabledCapabilities"))
                .font(PPProType.bold(14, relativeTo: .subheadline))
                .foregroundStyle(palette.text)

            Text("\(capabilities.count)")
                .font(PPProType.medium(11, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(palette.secondary)

            Spacer(minLength: 0)

            if totalAttention > 0 {
                Text(String(format: localized("PulseCommand_CountFormat"), "\(totalAttention)"))
                    .font(PPProType.bold(11, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(palette.accentText)
                    .lineLimit(1)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: PPProGlyph.micro, weight: .semibold))
                    Text(localized("PulseCommand_NoPendingDecisions"))
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Inspector — the only place a primary action exists

    private func inspector(_ capability: PPProCommandCapability) -> some View {
        let owned = ownedSignals(capability)
        let load = attention(capability)
        let isLensed = selectedCapabilityID == capability.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                        .fill(load > 0 ? palette.accent : palette.accentSoft)
                    Image(systemName: capability.symbolName)
                        .font(.system(size: PPProGlyph.large, weight: .semibold))
                        .foregroundStyle(load > 0 ? Color.white : palette.accentText)
                }
                .frame(width: PPProGlyph.plateLarge, height: PPProGlyph.plateLarge)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(capability.title)
                        .font(PPProType.bold(19, relativeTo: .title3))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !capability.subtitle.isEmpty {
                        Text(capability.subtitle)
                            .font(PPProType.regular(12, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if capability.isReadOnly {
                    Image(systemName: "eye.fill")
                        .font(.system(size: PPProGlyph.small, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .accessibilityHidden(true)
                } else if load > 0 {
                    Text(load > 99 ? "99+" : "\(load)")
                        .font(PPProType.bold(15, relativeTo: .headline))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 30, minHeight: 26)
                        .background(Capsule().fill(palette.accent))
                        .accessibilityHidden(true)
                }
            }

            // Load meter: this capability's share of everything pending. A thin
            // quantitative mark rather than another badge to read.
            if load > 0 {
                loadMeter(load)
            }

            if owned.isEmpty {
                readyRow(capability)
            } else {
                VStack(spacing: 6) {
                    ForEach(owned.prefix(3)) { signal in
                        signalRow(signal)
                    }
                }
                if owned.count > 3 {
                    Text(String(format: localized("PulseCommand_CountFormat"), "\(owned.count)"))
                        .font(PPProType.regular(10, relativeTo: .caption2))
                        .foregroundStyle(palette.secondary)
                }
            }

            actionRow(capability, owned: owned, isLensed: isLensed)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
                .stroke(load > 0 ? palette.accent.opacity(0.28) : palette.hairline,
                        lineWidth: load > 0 ? 1.2 : 0.8)
        )
        .shadow(color: palette.shadow, radius: 18, x: 0, y: 10)
    }

    private func loadMeter(_ load: Int) -> some View {
        GeometryReader { proxy in
            let fraction = min(max(CGFloat(load) / CGFloat(peakAttention), 0.08), 1)
            ZStack(alignment: isRTL ? .trailing : .leading) {
                Capsule()
                    .fill(palette.secondary.opacity(0.16))
                Capsule()
                    .fill(palette.accent)
                    .frame(width: max(proxy.size.width * fraction, 8))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func readyRow(_ capability: PPProCommandCapability) -> some View {
        HStack(spacing: 7) {
            Image(systemName: capability.isReadOnly ? "eye.fill" : "checkmark.circle.fill")
                .font(.system(size: PPProGlyph.small, weight: .semibold))
                .foregroundStyle(palette.secondary.opacity(0.7))
            Text(capability.isReadOnly
                 ? localized("DeliveryCompany_DashboardShell_Status_ReadOnly")
                 : localized("PulseCommand_NoPendingDecisions"))
                .font(PPProType.regular(11, relativeTo: .caption))
                .foregroundStyle(palette.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Tapping a signal opens command focus — the same local focus state the
    /// queue uses, not a second navigation path.
    private func signalRow(_ signal: PPProCommandSignal) -> some View {
        Button {
            onFocusSignal(signal)
        } label: {
            HStack(spacing: 9) {
                Capsule()
                    .fill(signal.priority.tint(palette))
                    .frame(width: signal.priority.edgeWidth)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 1) {
                    Text(signal.title)
                        .font(PPProType.medium(13, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 3 : 1)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !signal.subtitle.isEmpty {
                        Text(signal.subtitle)
                            .font(PPProType.regular(10, relativeTo: .caption2))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(isAccessibilitySize ? 3 : 1)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if signal.badgeCount > 0 {
                    Text(signal.badgeCount > 99 ? "99+" : "\(signal.badgeCount)")
                        .font(PPProType.bold(11, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(palette.accentText)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 20)
                        .background(Capsule().fill(palette.accentSoft))
                }

                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                    .font(.system(size: PPProGlyph.micro, weight: .bold))
                    .foregroundStyle(palette.secondary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous)
                    .fill(palette.canvas)
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(localized("PulseCommand_OpenFocusHint"))
    }

    @ViewBuilder
    private func actionRow(_ capability: PPProCommandCapability,
                           owned: [PPProCommandSignal],
                           isLensed: Bool) -> some View {
        if isAccessibilitySize {
            VStack(spacing: 8) {
                workspaceButton(capability, owned: owned)
                if !owned.isEmpty { lensButton(capability, isLensed: isLensed, wide: true) }
            }
        } else {
            HStack(spacing: 8) {
                workspaceButton(capability, owned: owned)
                if !owned.isEmpty { lensButton(capability, isLensed: isLensed, wide: false) }
            }
        }
    }

    /// Uses the server-supplied workspace title when present so the button never
    /// promises a specific action Objective-C would refuse.
    private func workspaceLabel(_ owned: [PPProCommandSignal]) -> String {
        if let title = owned.first?.actionTarget.workspaceActionTitle, !title.isEmpty {
            return title
        }
        return localized("PulseCommand_OpenExecutionWorkspace")
    }

    private func workspaceButton(_ capability: PPProCommandCapability,
                                 owned: [PPProCommandSignal]) -> some View {
        Button {
            onOpen(capability.routeTag)
        } label: {
            HStack(spacing: 8) {
                Text(workspaceLabel(owned))
                    .font(PPProType.bold(14, relativeTo: .subheadline))
                    .lineLimit(isAccessibilitySize ? 3 : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                    .font(.system(size: PPProGlyph.small, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(palette.accent)
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(capability.routeTag.isEmpty)
        .opacity(capability.routeTag.isEmpty ? 0.48 : 1)
        .accessibilityLabel(workspaceLabel(owned))
    }

    /// Narrows the shared lens to this capability without fetching and without
    /// re-entering Objective-C. Tapping while lensed returns to all capabilities.
    private func lensButton(_ capability: PPProCommandCapability,
                            isLensed: Bool,
                            wide: Bool) -> some View {
        Button {
            onSelectLens(isLensed ? "all" : capability.id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isLensed ? "scope" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: PPProGlyph.small, weight: .bold))
                if wide {
                    Text(localized("PulseCommand_CapabilityPrism"))
                        .font(PPProType.medium(13, relativeTo: .subheadline))
                        .lineLimit(2)
                }
            }
            .foregroundStyle(isLensed ? Color.white : palette.accentText)
            .padding(.horizontal, wide ? 14 : 0)
            .frame(width: wide ? nil : 46, height: 46)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(isLensed ? palette.accent : palette.accentSoft)
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(localized("PulseCommand_CapabilityPrism"))
        .accessibilityValue(capability.title)
        .accessibilityAddTraits(isLensed ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Selector mosaic — quiet, dense, no competing CTAs

    private func selectorCell(_ capability: PPProCommandCapability) -> some View {
        let isInspecting = inspected?.id == capability.id
        let load = attention(capability)

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            inspectedID = capability.id
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: capability.symbolName)
                        .font(.system(size: PPProGlyph.small, weight: .semibold))
                        .foregroundStyle(isInspecting ? palette.accentText : palette.secondary)

                    Spacer(minLength: 0)

                    if capability.isReadOnly {
                        Image(systemName: "eye.fill")
                            .font(.system(size: PPProGlyph.micro, weight: .bold))
                            .foregroundStyle(palette.secondary.opacity(0.8))
                    } else if load > 0 {
                        // Quiet quantitative mark; the inspector carries the detail.
                        Text(load > 99 ? "99+" : "\(load)")
                            .font(PPProType.bold(10, relativeTo: .caption2))
                            .monospacedDigit()
                            .foregroundStyle(palette.accentText)
                    }
                }

                Text(capability.title)
                    .font(PPProType.medium(12, relativeTo: .caption))
                    .foregroundStyle(isInspecting ? palette.text : palette.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: isAccessibilitySize ? 0 : 64, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .fill(isInspecting ? palette.accentSoft : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .stroke(isInspecting ? palette.accent.opacity(0.45) : palette.hairline,
                            lineWidth: isInspecting ? 1.2 : 0.8)
            )
            // Unread work gets a leading rank edge, the same encoding the queue
            // uses, so attention is felt in the mosaic without reading numbers.
            .overlay(alignment: isRTL ? .trailing : .leading) {
                if load > 0 {
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
            }
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(capability.title)
        .accessibilityValue(capability.isReadOnly
            ? localized("DeliveryCompany_DashboardShell_Status_ReadOnly")
            : (load > 0 ? String(format: localized("PulseCommand_CountFormat"), "\(load)") : ""))
        .accessibilityAddTraits(isInspecting ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Workspace band

/// Capabilities, where the *shape* of a cell encodes whether it holds work.
///
/// This replaces `PPProCapabilityActionBoard`, whose two ideas both failed
/// against real data:
///
/// 1. **A uniform grid of equal cards.** Its only state channel was
///    `capability.actionCount`, which Objective-C leaves permanently at 0 for
///    pharmacy, veterinary and adoption, and which marketplace and services
///    *share* (both are handed the same `fulfillmentCount`). A channel that is
///    silent for three capabilities and ambiguous for two more cannot rank
///    anything — so six capabilities rendered as six identical doors, and the
///    band answered "where can I go" instead of "where is work waiting".
///
/// 2. **A teal "secondary-priority" hero.** Its predicate selected a
///    `.normal`-priority signal with a permitted primary title, which in
///    practice means the notifications signal. Whenever notifications was not
///    already the stage signal it was rendered *twice on one screen* — once as a
///    queue row and once as this hero — under a third accent color. The signal,
///    its action and its route all remain reachable from its ledger row and
///    command focus; only the duplicate presentation is gone.
///
/// Capabilities holding pending work are promoted to full-width rows; idle doors
/// collapse into a quiet grid. An all-clear account therefore reads as calm
/// rather than as six competing cards, and a busy one is structurally loud.
///
/// No permission is evaluated here. `capabilities` is the Objective-C gated set,
/// each cell emits only its existing `routeTag`, and `isReadOnly` stays a
/// presentation hint.
private struct PPProWorkspaceBand: View {
    let activeCapabilities: [PPProCommandCapability]
    let idleCapabilities: [PPProCommandCapability]
    let signals: [PPProCommandSignal]
    let lensID: String
    let palette: PPProPalette
    let isRTL: Bool
    let onOpen: (String) -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }
    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    private var total: Int { activeCapabilities.count + idleCapabilities.count }

    private var columns: [GridItem] {
        // Idle doors go 3-up. An earlier revision of this band used 2-up with a
        // one-line subtitle, which was *taller* than the surface it replaced —
        // the opposite of the intent. For an idle door the title is the whole
        // information: the old 3-up card did render a subtitle, but at ~118pt of
        // cell width it truncated ("…وتقدّم التوصي"), so the text cost height
        // without delivering meaning. The subtitle is still shown in full on
        // promoted rows, in the Menu Map atlas, and here at accessibility sizes
        // where a single column has room for it — and it always reaches
        // VoiceOver through `accessibilityHint`.
        [GridItem(.adaptive(minimum: isAccessibilitySize ? 260 : 104), spacing: 9)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPProPulseRhythm.stackGap) {
            header

            if !activeCapabilities.isEmpty {
                VStack(spacing: 8) {
                    ForEach(activeCapabilities) { capability in
                        activeRow(capability)
                    }
                }
            }

            if !idleCapabilities.isEmpty {
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(idleCapabilities) { capability in
                        idleCell(capability)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(localized("PulseCommand_EnabledCapabilities"))
                .font(PPProType.bold(14, relativeTo: .subheadline))
                .foregroundStyle(palette.text)
                .lineLimit(2)
            Text("\(total)")
                .font(PPProType.medium(11, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(palette.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// How many live signals this capability owns. Signals with empty
    /// `capabilityIDs` — notifications and support chats — deliberately belong to
    /// no capability and are never counted here, which preserves the snapshot
    /// invariant that they are lens-independent.
    private func ownedSignals(_ capability: PPProCommandCapability) -> [PPProCommandSignal] {
        signals.filter { $0.capabilityIDs.contains(capability.id) }
    }

    // MARK: Promoted row

    private func activeRow(_ capability: PPProCommandCapability) -> some View {
        let isDisabled = capability.routeTag.isEmpty
        let owned = ownedSignals(capability)
        let isLens = capability.id == lensID
        let pending = max(capability.actionCount, owned.reduce(0) { $0 + $1.badgeCount })

        return Button {
            guard !isDisabled else { return }
            onOpen(capability.routeTag)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous)
                        .fill(pending > 0 ? palette.accent : palette.accentSoft)
                    Image(systemName: capability.symbolName)
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(pending > 0 ? Color.white : palette.accentText)
                }
                .frame(width: PPProGlyph.plateMedium, height: PPProGlyph.plateMedium)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(capability.title)
                            .font(PPProType.bold(14, relativeTo: .subheadline))
                            .foregroundStyle(palette.text)
                            .lineLimit(isAccessibilitySize ? 3 : 1)
                            .multilineTextAlignment(.leading)
                        if isLens {
                            Image(systemName: "scope")
                                .font(.system(size: PPProGlyph.micro, weight: .bold))
                                .foregroundStyle(palette.accentText)
                                .accessibilityHidden(true)
                        }
                    }
                    if !capability.subtitle.isEmpty {
                        Text(capability.subtitle)
                            .font(PPProType.regular(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(isAccessibilitySize ? 4 : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if capability.isReadOnly {
                    Image(systemName: "eye.fill")
                        .font(.system(size: PPProGlyph.small, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .accessibilityHidden(true)
                } else if pending > 0 {
                    Text(pending > 99 ? "99+" : "\(pending)")
                        .font(PPProType.bold(12, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 24)
                        .background(Capsule().fill(palette.accent))
                        .accessibilityHidden(true)
                }

                Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                    .font(.system(size: PPProGlyph.small, weight: .bold))
                    .foregroundStyle(palette.accentText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .strokeBorder(
                        pending > 0 ? palette.accent.opacity(0.30) : palette.hairline,
                        lineWidth: pending > 0 ? 1.0 : 0.8
                    )
            )
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(isDisabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(capability.title)
        .accessibilityValue(accessibilityValue(for: capability, pending: pending))
        .accessibilityHint(localized("PulseCommand_OpenExecutionWorkspace"))
    }

    // MARK: Quiet door

    private func idleCell(_ capability: PPProCommandCapability) -> some View {
        let isDisabled = capability.routeTag.isEmpty

        return Button {
            guard !isDisabled else { return }
            onOpen(capability.routeTag)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous)
                            .fill(palette.accentSoft)
                        Image(systemName: capability.symbolName)
                            .font(.system(size: PPProGlyph.small, weight: .semibold))
                            .foregroundStyle(palette.accentText)
                    }
                    .frame(width: PPProGlyph.plateSmall, height: PPProGlyph.plateSmall)
                    .accessibilityHidden(true)

                    Spacer(minLength: 0)

                    if capability.isReadOnly {
                        Image(systemName: "eye.fill")
                            .font(.system(size: PPProGlyph.micro, weight: .bold))
                            .foregroundStyle(palette.secondary)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: isRTL ? "arrow.left" : "arrow.right")
                            .font(.system(size: PPProGlyph.micro, weight: .bold))
                            .foregroundStyle(palette.secondary.opacity(0.65))
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(capability.title)
                        .font(PPProType.bold(13, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 3 : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Only where a single column gives it room to be read.
                    if isAccessibilitySize && !capability.subtitle.isEmpty {
                        Text(capability.subtitle)
                            .font(PPProType.regular(10, relativeTo: .caption2))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 0.8)
            )
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(isDisabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(capability.title)
        .accessibilityValue(accessibilityValue(for: capability, pending: 0))
        // Carries the subtitle the compact cell does not draw, so nothing is
        // lost to assistive technology.
        .accessibilityHint(
            capability.subtitle.isEmpty
                ? localized("PulseCommand_OpenExecutionWorkspace")
                : "\(capability.subtitle) \(localized("PulseCommand_OpenExecutionWorkspace"))"
        )
    }

    private func accessibilityValue(for capability: PPProCommandCapability, pending: Int) -> String {
        if capability.isReadOnly {
            return localized("DeliveryCompany_DashboardShell_Status_ReadOnly")
        }
        guard pending > 0 else { return "" }
        return String(format: localized("PulseCommand_CountFormat"), "\(pending)")
    }
}

// MARK: - Dock

/// Real tab identity, so the dock can express position. The legacy dock
/// hardcoded `active: true` on Pulse, meaning no other tab could ever appear
/// selected.
enum PPProDockTab: String, CaseIterable, Identifiable {
    case pulse
    case menuMap
    case work
    case notifications
    case more

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .pulse: return "PulseCommand_Dock_Pulse"
        case .menuMap: return "PulseCommand_Dock_MenuMap"
        case .work: return "PulseCommand_Dock_Work"
        case .notifications: return "NotificationsTitle"
        case .more: return "PulseCommand_Dock_More"
        }
    }

    var symbol: String {
        switch self {
        case .pulse: return "waveform.path.ecg"
        case .menuMap: return "square.grid.2x2.fill"
        case .work: return "bolt.fill"
        case .notifications: return "bell.fill"
        case .more: return "ellipsis"
        }
    }
}

/// Pro action dock, rendered with the Admin V6 dock grammar: an anchored
/// surface, one-pixel top separator, a quiet equal-width lane, and a selected
/// 20×3 indicator. It deliberately keeps Pro's dock actions as callbacks rather
/// than pretending each item is a persistent content tab.
private struct PPProPulseDock: View {
    let selected: PPProDockTab
    let notificationBadge: Int
    let palette: PPProPalette
    let reduceMotion: Bool
    let onSelect: (PPProDockTab) -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    var body: some View {
        VStack(spacing: 0) {
            // Admin's grounded separator replaces Pro's detached glass capsule.
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1 / UIScreen.main.scale)
                .accessibilityHidden(true)

            Group {
                if sizeCategory.isAccessibilityCategory {
                    // Wrap every tab into rows of two so no item is dropped when
                    // the tab count changes. A trailing odd item spans the row.
                    let tabs = PPProDockTab.allCases
                    let rows = stride(from: 0, to: tabs.count, by: 2).map { start in
                        Array(tabs[start..<min(start + 2, tabs.count)])
                    }
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            HStack(spacing: 0) {
                                ForEach(rows[rowIndex]) { tab in
                                    dockButton(tab)
                                }
                            }
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(PPProDockTab.allCases) { tab in
                            dockButton(tab)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, sizeCategory.isAccessibilityCategory ? 10 : 8)
        }
        .background(palette.surface.ignoresSafeArea(edges: .bottom))
    }

    private func dockButton(_ tab: PPProDockTab) -> some View {
        let isActive = tab == selected
        let badge = tab == .notifications ? notificationBadge : 0
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                // Reserve the indicator geometry for every item. This keeps
                // captions optically aligned without a matched-geometry source.
                Capsule()
                    .fill(isActive ? palette.accentStrong : Color.clear)
                    .frame(width: 20, height: 3)
                    .accessibilityHidden(true)

                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .frame(height: 20)

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(PPProType.bold(9, relativeTo: .caption2))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 14)
                            .background(Capsule().fill(palette.accent))
                            .offset(x: 12, y: -6)
                            .accessibilityHidden(true)
                    }
                }

                Text(localized(tab.titleKey))
                    .font(isActive
                        ? PPProType.bold(10, relativeTo: .caption2)
                        : PPProType.medium(10, relativeTo: .caption2))
                    .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isActive ? palette.text : palette.secondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: sizeCategory.isAccessibilityCategory ? 62 : 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPProCommandPressStyle())
        .accessibilityLabel(localized(tab.titleKey))
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}


// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Pulse Shell (redesign)
//
// One continuous pulse spine: identity → vitals → lens → the decision that
// needs answering → the ranked queue → where to work.
//
// Presentation only. Routing, permissions and data stay in
// AdminDashboardViewController.m; this view consumes the same snapshot and emits
// the same three delegate calls as the surface it replaces.
// ═══════════════════════════════════════════════════════════════════════════

struct PPProPulseView: View {
    @ObservedObject var store: PPProCommandCenterStore
    let onRoute: (String) -> Void
    let onActionTarget: (PPProCommandActionDescriptor) -> Void
    let onWorkspaceTarget: (PPProCommandActionDescriptor) -> Void
    let onProfile: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    @State private var appeared = false
    /// Set once the first-paint spinner has been up long enough that leaving it
    /// there would be dishonest. See `phase`.
    @State private var bootStalled = false

    @Namespace private var pulseNamespace

    /// How long the boot spinner is allowed to represent "still working".
    private static let bootPatience: TimeInterval = 6

    private var palette: PPProPalette { .resolve(colorScheme) }
    private var snapshot: PPProCommandCenterSnapshot { store.snapshot }
    private var isRTL: Bool { snapshot.isRTL }
    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    /// Single derived model for every region, so the counts, the stage, the
    /// ledger and the workspace band cannot contradict each other.
    private var scope: PPProPulseScope {
        PPProPulseScope(
            snapshot: snapshot,
            lensID: store.selectedCapabilityID,
            scopedSignals: store.visibleSignals
        )
    }

    // MARK: State ladder

    private enum Phase: Equatable {
        /// First paint, still within the patience window.
        case booting
        /// First paint has not resolved. Previously this state did not exist and
        /// the spinner simply stayed up forever.
        case stalled
        /// Objective-C finished and granted no capability.
        case locked
        case ready
    }

    /// The legacy gate was
    /// `isOperationalLoading && displayName.isEmpty && capabilities.isEmpty`,
    /// which is *exactly* what `pp_refreshCommandCenterSnapshot` emits on its
    /// locked / no-user path — that branch sets `isOperationalLoading = YES` with
    /// an empty name and no capabilities. So a provider with no partner access,
    /// or a locked session, fell into the spinner and could never reach
    /// `lockedState`, because `lockedState` required *not* loading. The spinner
    /// had no exit. The ladder below always terminates.
    private var phase: Phase {
        let hasNoCapabilities = snapshot.capabilities.isEmpty
        if hasNoCapabilities && !snapshot.isOperationalLoading { return .locked }
        let isFirstPaint = snapshot.isOperationalLoading
            && snapshot.displayName.isEmpty
            && hasNoCapabilities
        if isFirstPaint { return bootStalled ? .stalled : .booting }
        return .ready
    }

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()

            switch phase {
            case .booting: bootingState
            case .stalled: stalledState
            case .locked: lockedState
            case .ready: content
            }

            if let focused = store.focusedSignal {
                focusLayer(focused)
            }
        }
        // The official root UITabBarController owns bottom navigation, so this
        // surface deliberately renders no dock of its own.
        .onAppear {
            appeared = true
            guard !bootStalled else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.bootPatience) {
                bootStalled = true
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PPProPulseRhythm.spineGap) {
                commandBar
                    .padding(.horizontal, PPProPulseRhythm.screenMargin)

                // A rail of one real lens plus "all" is a control with nothing to
                // choose, so it only appears once there is a choice to make.
                if snapshot.capabilities.count > 1 {
                    PPProLensRail(
                        capabilities: snapshot.capabilities,
                        selectedID: store.selectedCapabilityID,
                        palette: palette,
                        isRTL: isRTL,
                        reduceMotion: reduceMotion,
                        onSelect: selectLens
                    )
                }

                attentionBand
                    .padding(.horizontal, PPProPulseRhythm.screenMargin)

                if scope.hasCapabilities {
                    PPProWorkspaceBand(
                        activeCapabilities: scope.activeCapabilities,
                        idleCapabilities: scope.idleCapabilities,
                        signals: snapshot.signals,
                        lensID: store.selectedCapabilityID,
                        palette: palette,
                        isRTL: isRTL,
                        onOpen: activate
                    )
                    .padding(.horizontal, PPProPulseRhythm.screenMargin)
                } else {
                    lockedNotice
                        .padding(.horizontal, PPProPulseRhythm.screenMargin)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .accessibilityHidden(store.focusedSignal != nil)
    }

    // MARK: Command bar — identity plus the scope's own counts

    private var commandBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                PPProAvatarView(
                    urlString: snapshot.avatarURLString,
                    fallback: avatarInitials
                )
                .frame(width: PPProGlyph.plateMedium, height: PPProGlyph.plateMedium)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.greeting.isEmpty ? snapshot.workspaceEyebrow : snapshot.greeting)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                    Text(snapshot.displayName)
                        .font(PPProType.bold(18, relativeTo: .title3))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.85)
                    if !snapshot.roleSummary.isEmpty {
                        Text(snapshot.roleSummary)
                            .font(PPProType.regular(10, relativeTo: .caption2))
                            .foregroundStyle(palette.secondary.opacity(0.85))
                            .lineLimit(isAccessibilitySize ? 3 : 1)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onProfile) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(palette.accentSoft))
                }
                .buttonStyle(PPProCommandPressStyle())
                .accessibilityLabel(localized("Settings"))
            }

            PPProVitalsStrip(
                workspaceCount: scope.workspaceCount,
                // The count of what is actually rendered below, not the global
                // figure. See PPProVitalsStrip.
                signalCount: scope.signals.count,
                unreadCount: scope.unreadCount,
                isScoped: scope.isScoped,
                palette: palette
            )
        }
    }

    private var avatarInitials: String {
        let parts = snapshot.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "PP" : joined
    }

    // MARK: Attention band

    @ViewBuilder
    private var attentionBand: some View {
        let scope = self.scope

        VStack(alignment: .leading, spacing: PPProPulseRhythm.stackGap) {
            if snapshot.isOperationalDegraded {
                degradedBanner
            }

            if let lead = scope.leadSignal {
                PPProAttentionStage(
                    signal: lead,
                    tier: scope.tier,
                    capabilityTitle: scope.capabilityTitle(for: lead, in: snapshot),
                    palette: palette,
                    isRTL: isRTL,
                    reduceMotion: reduceMotion,
                    namespace: pulseNamespace,
                    onFocus: { focusSignal(lead) },
                    onExecute: { onActionTarget(lead.actionTarget.makeDescriptor()) },
                    onWorkspace: { onWorkspaceTarget(lead.actionTarget.makeWorkspaceDescriptor()) }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(reduceMotion ? nil : PPProMotion.entrance, value: appeared)

                ForEach(Array(scope.ledger.enumerated()), id: \.element.id) { index, signal in
                    PPProLedgerRow(
                        signal: signal,
                        fraction: scope.meterFraction(signal),
                        isActionable: PPProPulseScope.isActionable(signal),
                        palette: palette,
                        isRTL: isRTL,
                        reduceMotion: reduceMotion,
                        namespace: pulseNamespace,
                        onOpen: { focusSignal(signal) }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        reduceMotion ? nil : PPProMotion.entrance.delay(PPProMotion.entranceDelay(index + 1)),
                        value: appeared
                    )
                }
            } else if snapshot.isOperationalLoading {
                streamingState
            } else if scope.hasCapabilities {
                allClearNotice
            }
        }
        .animation(reduceMotion ? nil : PPProMotion.lensSwap, value: store.selectedCapabilityID)
    }

    private var streamingState: some View {
        HStack(spacing: 11) {
            ProgressView().tint(palette.accentText)
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("PulseCommand_LoadingOperational"))
                    .font(PPProType.medium(14, relativeTo: .subheadline))
                    .foregroundStyle(palette.text)
                Text(localized("PulseCommand_LoadingOperationalSubtitle"))
                    .font(PPProType.regular(11, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(isAccessibilitySize ? 5 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppProCommandSurface(radius: PPProRadius.card, palette: palette)
        .accessibilityElement(children: .combine)
    }

    /// All-clear is a statement, not a control.
    ///
    /// It used to be a full-width button routing to
    /// `store.selectedCapability ?? snapshot.capabilities.first`. Under the
    /// default "all" lens `selectedCapability` is nil, so a card reading "no
    /// pending decisions" silently opened whichever capability Objective-C
    /// happened to append first — marketplace. The destination was an artifact of
    /// array order. Every real destination is one tap away in the band directly
    /// below, so this no longer pretends to be one.
    private var allClearNotice: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(palette.accentSoft)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: PPProGlyph.large, weight: .semibold))
                    .foregroundStyle(palette.accentText)
            }
            .frame(width: PPProGlyph.plateLarge, height: PPProGlyph.plateLarge)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(localized("PulseCommand_NoPendingDecisions"))
                    .font(PPProType.bold(16, relativeTo: .headline))
                    .foregroundStyle(palette.text)
                    .lineLimit(isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                // Names the lens when one is applied, so "nothing pending" is
                // scoped rather than an unqualified claim about everything.
                if let lens = scope.lens {
                    Text(lens.title)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppProCommandSurface(radius: PPProRadius.card, palette: palette)
        .accessibilityElement(children: .combine)
    }

    private var degradedBanner: some View {
        let canRetry = snapshot.canRetryOperationalData
        return Button {
            guard canRetry else { return }
            activate("__retryCommandData")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: PPProGlyph.medium, weight: .semibold))
                    .foregroundStyle(palette.accentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(localized("PulseCommand_DegradedTitle"))
                        .font(PPProType.bold(13, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localized("PulseCommand_DegradedSubtitle"))
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(isAccessibilitySize ? 6 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if canRetry {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: PPProGlyph.small, weight: .bold))
                        .foregroundStyle(palette.accentText)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: canRetry ? 44 : 0)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .fill(palette.accentSoft)
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(!canRetry)
        .accessibilityElement(children: .combine)
        .accessibilityHint(canRetry ? localized("PulseCommand_Retry") : "")
    }

    // MARK: Terminal states

    private var bootingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(palette.accentText)
                .controlSize(.large)
            Text(localized("PulseCommand_LoadingOperational"))
                .font(PPProType.medium(13, relativeTo: .subheadline))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityElement(children: .combine)
    }

    /// Reachable only because the boot spinner is now time-bounded. Offers the
    /// existing `__retryCommandData` route, which restarts the Objective-C
    /// listeners — a client-side refresh, not a mutation.
    private var stalledState: some View {
        centeredNotice(
            symbol: "arrow.triangle.2.circlepath",
            title: localized("PulseCommand_DegradedTitle"),
            message: localized("PulseCommand_DegradedSubtitle"),
            actionTitle: localized("PulseCommand_Retry"),
            action: { activate("__retryCommandData") }
        )
    }

    /// Objective-C resolved and granted nothing. Previously unreachable.
    private var lockedState: some View {
        centeredNotice(
            symbol: "lock.fill",
            title: localized("MenuMap_Locked_Title"),
            message: localized("MenuMap_Locked_Subtitle"),
            actionTitle: nil,
            action: nil
        )
    }

    /// Inline variant, for when the operator has a session but no capability.
    private var lockedNotice: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(palette.accentSoft)
                Image(systemName: "lock.fill")
                    .font(.system(size: PPProGlyph.large, weight: .semibold))
                    .foregroundStyle(palette.secondary)
            }
            .frame(width: PPProGlyph.plateLarge, height: PPProGlyph.plateLarge)
            .accessibilityHidden(true)

            Text(localized("StatusNoPartnerAccess"))
                .font(PPProType.medium(14, relativeTo: .subheadline))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppProCommandSurface(radius: PPProRadius.card, palette: palette)
        .accessibilityElement(children: .combine)
    }

    private func centeredNotice(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: PPProRadius.card, style: .continuous)
                    .fill(palette.accentSoft)
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(palette.accentText)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text(title)
                    .font(PPProType.bold(17, relativeTo: .headline))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(PPProType.regular(12, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PPProType.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 46)
                        .background(
                            Capsule().fill(palette.accent)
                        )
                }
                .buttonStyle(PPProCommandPressStyle())
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Focus layer

    private func focusLayer(_ signal: PPProCommandSignal) -> some View {
        PPProCommandFocusView(
            signal: signal,
            capabilityTitle: scope.capabilityTitle(for: signal, in: snapshot),
            actionTarget: signal.actionTarget,
            isRTL: isRTL,
            palette: palette,
            reduceMotion: reduceMotion,
            namespace: pulseNamespace,
            onBack: dismissFocus,
            onExecute: { onActionTarget(signal.actionTarget.makeDescriptor()) },
            onOpenDetails: { onActionTarget(signal.actionTarget.makeDetailsDescriptor()) },
            onOpenWorkspace: { onWorkspaceTarget(signal.actionTarget.makeWorkspaceDescriptor()) },
            onQuickAction: { action in
                onActionTarget(signal.actionTarget.makeQuickActionDescriptor(action))
            }
        )
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .opacity
        ))
        .zIndex(2)
    }

    // MARK: Behaviour

    /// Lens selection stays local presentation state: it never fetches and never
    /// re-enters Objective-C.
    private func selectLens(_ id: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(reduceMotion ? nil : PPProMotion.lensSwap) {
            store.selectedCapabilityID = id
        }
    }

    private func focusSignal(_ signal: PPProCommandSignal) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(reduceMotion ? nil : PPProMotion.stageChange) {
            store.focusedSignalID = signal.id
        }
    }

    private func dismissFocus() {
        withAnimation(reduceMotion ? nil : PPProMotion.stageChange) {
            store.focusedSignalID = nil
        }
    }

    /// Emits an existing Objective-C route tag. `pp_routeCommandCenterRoute:`
    /// re-checks it at dispatch and still requires the permission-built XLForm
    /// row to exist, so nothing here can reach an unauthorized destination.
    private func activate(_ route: String) {
        guard !route.isEmpty else { return }
        onRoute(route)
    }
}

private struct PPProMoreDestinationView: View {
    @ObservedObject var store: PPProCommandCenterStore
    let onRoute: (String) -> Void
    let onProfile: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var snapshot: PPProCommandCenterSnapshot { store.snapshot }
    private var palette: PPProPalette { .resolve(colorScheme) }

    var body: some View {
        PPProMoreView(
            capabilities: snapshot.capabilities,
            roleSummary: snapshot.roleSummary,
            palette: palette,
            isRTL: snapshot.isRTL,
            onRoute: onRoute,
            onProfile: onProfile
        )
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
    }
}

private struct PPProMenuMapDestinationView: View {
    @ObservedObject var store: PPProCommandCenterStore
    let onRoute: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: PPProCommandCenterSnapshot { store.snapshot }
    private var palette: PPProPalette { .resolve(colorScheme) }

    var body: some View {
        PPProMenuMapView(
            capabilities: snapshot.capabilities,
            displayName: snapshot.displayName,
            roleSummary: snapshot.roleSummary,
            inboxUnreadCount: snapshot.inboxUnreadCount,
            supportUnreadCount: snapshot.supportUnreadCount,
            palette: palette,
            isRTL: snapshot.isRTL,
            reduceMotion: reduceMotion,
            onRoute: onRoute
        )
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - More destination
//
// Replaces the UIAlertController action sheet. Routes remain owned by ObjC:
// this only emits route tags, and AdminDashboardViewController refuses any route
// whose XLForm row does not exist — so an unavailable destination stays
// unreachable regardless of what is listed here.
// ═══════════════════════════════════════════════════════════════════════════

private struct PPProMoreView: View {
    let capabilities: [PPProCommandCapability]
    let roleSummary: String
    let palette: PPProPalette
    let isRTL: Bool
    let onRoute: (String) -> Void
    let onProfile: () -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    /// Preserves the established More route vocabulary and title keys exactly,
    /// but each entry now appears only when the capability set Objective-C
    /// granted implies its `buildLoginForm` gate. These are equivalences read off
    /// that method, not a permission model reconstructed here:
    ///
    /// - `isAnyActiveProvider` (`AdminDashboardViewController.m:464`) is the OR of
    ///   the same seven gates that emit the seven capability descriptors, so it is
    ///   exactly `!capabilities.isEmpty`. It gates `providerSupportChats`
    ///   (`.m:487`), `profileSettings` (`.m:630`), `notificationSettings`
    ///   (`.m:637`) and `branchesManagement` (`.m:644`).
    /// - `fulfillmentOrders` (`.m:585`) sits inside
    ///   `canManageServices || canManageMarketplace`.
    /// - `deliveryCompanyMembers` has **no** XLForm row and no dispatcher
    ///   fallback, so its owning capability — `deliveryCompany` — is the only
    ///   authorization signal available for it.
    ///
    /// This is strictly narrowing: it can hide an entry, never reveal one. The
    /// destinations themselves still perform their own authorization, and the
    /// dispatcher still refuses any route whose row does not exist.
    private var entries: [Entry] {
        let ids = Set(capabilities.map(\.id))
        let hasAnyWorkspace = !capabilities.isEmpty
        let hasFulfillment = ids.contains("services") || ids.contains("marketplace")

        var result: [Entry] = []
        if hasAnyWorkspace {
            result.append(Entry(id: "providerSupportChats", title: localized("ch_provider_support_chats_title"), symbol: "bubble.left.and.bubble.right.fill"))
        }
        if hasFulfillment {
            result.append(Entry(id: "fulfillmentOrders", title: localized("Fulfillment_Title"), symbol: "shippingbox.fill"))
        }
        if hasAnyWorkspace {
            result.append(Entry(id: "branchesManagement", title: localized("MarketplaceBranches_Manage"), symbol: "building.2.fill"))
        }
        if ids.contains("deliveryCompany") {
            result.append(Entry(id: "deliveryCompanyMembers", title: localized("DeliveryCompany_Tab_Members"), symbol: "person.2.fill"))
        }
        if hasAnyWorkspace {
            result.append(Entry(id: "notificationSettings", title: localized("NotificationSettings"), symbol: "bell.badge.fill"))
            result.append(Entry(id: "profileSettings", title: localized("ProfileSettings"), symbol: "gearshape.fill"))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: PPProPulseRhythm.stackGap) {
                    if entries.isEmpty {
                        // Reachable when Objective-C granted no capability, since
                        // every More destination sits behind `isAnyActiveProvider`.
                        Text(localized("MenuMap_Locked_Subtitle"))
                            .font(PPProType.regular(13, relativeTo: .subheadline))
                            .foregroundStyle(palette.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .accessibilityAddTraits(.isStaticText)
                    } else {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                }
                .padding(.horizontal, PPProPulseRhythm.screenMargin)
                .padding(.vertical, PPProPulseRhythm.spineGap)
            }
        }
        .background(palette.canvas.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(localized("PulseCommand_Dock_More"))
                    .font(PPProType.bold(20, relativeTo: .title3))
                    .foregroundStyle(palette.text)
                if !roleSummary.isEmpty {
                    Text(roleSummary)
                        .font(PPProType.regular(11, relativeTo: .caption))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PPProPulseRhythm.screenMargin)
        .padding(.top, PPProPulseRhythm.spineGap)
        .padding(.bottom, PPProPulseRhythm.stackGap)
    }

    private func row(_ entry: Entry) -> some View {
        Button {
            if entry.id == "profileSettings" {
                onProfile()
            } else {
                onRoute(entry.id)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PPProRadius.chip, style: .continuous)
                        .fill(palette.accentSoft)
                    Image(systemName: entry.symbol)
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                }
                .frame(width: PPProGlyph.plateSmall, height: PPProGlyph.plateSmall)

                Text(entry.title)
                    .font(PPProType.medium(15, relativeTo: .subheadline))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                    .font(.system(size: PPProGlyph.micro, weight: .bold))
                    .foregroundStyle(palette.secondary.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: sizeCategory.isAccessibilityCategory ? 64 : 54)
            .ppProCommandSurface(radius: PPProRadius.tile, palette: palette)
        }
        .buttonStyle(PPProCommandPressStyle())
    }
}


// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Menu Map (خريطة القدرات)
//
// A pushed atlas of every ENABLED capability, grouped by domain
// identity. Where the Pulse board renders one uniform rose grid, the Menu Map
// gives each domain family its own accent, spine, and plate so Marketplace,
// Delivery, Pharmacy, Care, Notifications and Community each read as a distinct
// world while staying inside the Pure Pets Pro design language.
//
// Contract preservation:
//   • It renders ONLY `snapshot.capabilities` — the same ObjC-gated live set.
//     No capability is invented, hidden, or reordered by authorization here.
//   • Every entry emits its real `routeTag` through `onRoute`, which flows to
//     AdminDashboardViewController's dispatcher. No new routing, no fake data.
//   • The single Notifications entry is derived from the real inbox/support
//     unread counts and routes to the established `notificationsInbox` tag.
//   • Colors resolve through PPDesignTokens domain accents; `isReadOnly` stays
//     a presentation hint, never an authorization decision.
// ═══════════════════════════════════════════════════════════════════════════

/// Domain families. Each is a distinct visual identity built only from existing
/// PPDesignTokens accent colors, so the map never invents brand color.
private enum PPProMenuDomain: String, CaseIterable {
    case notifications
    case commerce      // marketplace / my products
    case pharmacy      // medicine & supplies
    case services      // grooming, training, cleaning…
    case care          // veterinary
    case logistics     // delivery + company deliveries
    case community     // adoption
    case workspace     // anything unmapped stays first-class, never dropped

    /// Section headline localization key.
    var titleKey: String {
        switch self {
        case .notifications: return "MenuMap_Domain_Notifications"
        case .commerce: return "MenuMap_Domain_Commerce"
        case .pharmacy: return "MenuMap_Domain_Pharmacy"
        case .services: return "MenuMap_Domain_Services"
        case .care: return "MenuMap_Domain_Care"
        case .logistics: return "MenuMap_Domain_Logistics"
        case .community: return "MenuMap_Domain_Community"
        case .workspace: return "MenuMap_Domain_Workspace"
        }
    }

    /// Short family caption above the headline.
    var eyebrowKey: String {
        switch self {
        case .notifications: return "MenuMap_Family_Signal"
        case .commerce: return "MenuMap_Family_Storefront"
        case .pharmacy: return "MenuMap_Family_Clinical"
        case .services: return "MenuMap_Family_Studio"
        case .care: return "MenuMap_Family_Medical"
        case .logistics: return "MenuMap_Family_Movement"
        case .community: return "MenuMap_Family_Belonging"
        case .workspace: return "MenuMap_Family_Operations"
        }
    }

    var symbol: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .commerce: return "bag.fill"
        case .pharmacy: return "cross.vial.fill"
        case .services: return "scissors"
        case .care: return "cross.case.fill"
        case .logistics: return "shippingbox.fill"
        case .community: return "heart.fill"
        case .workspace: return "square.grid.2x2.fill"
        }
    }

    /// The single authority color for the family — an existing token only.
    var accentUIColor: UIColor {
        switch self {
        case .notifications: return .ppPrimary
        case .commerce: return .ppQuickActionShopping
        case .pharmacy: return .ppInfo
        case .services: return .ppQuickActionServices
        case .care: return .ppCareAccent
        case .logistics: return .ppQuickActionAnimals
        case .community: return .ppAdoptionAccent
        case .workspace: return .ppQuickActionCommunity
        }
    }

    /// Rank so families read in a deliberate hierarchy: what is live and
    /// signal-bearing first, then storefront, clinical, studio, medical,
    /// movement, belonging, and finally any unmapped operations door.
    var order: Int {
        switch self {
        case .notifications: return 0
        case .commerce: return 1
        case .pharmacy: return 2
        case .services: return 3
        case .care: return 4
        case .logistics: return 5
        case .community: return 6
        case .workspace: return 7
        }
    }

    /// Maps a live capability identifier to its domain family. Unknown ids fall
    /// back to `.workspace` so a future capability is still shown, never hidden.
    static func domain(forCapabilityID id: String) -> PPProMenuDomain {
        switch id {
        case "marketplace": return .commerce
        case "pharmacy": return .pharmacy
        case "services": return .services
        case "veterinary": return .care
        case "delivery", "deliveryCompany": return .logistics
        case "adoption": return .community
        default: return .workspace
        }
    }
}

/// One rendered row inside a Menu Map section. Wraps the live capability so the
/// synthetic Notifications entry (which has no capability descriptor) can share
/// exactly the same row grammar.
private struct PPProMenuEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let routeTag: String
    let badgeCount: Int
    let isReadOnly: Bool
}

private struct PPProMenuSection: Identifiable, Equatable {
    let domain: PPProMenuDomain
    let entries: [PPProMenuEntry]
    var id: String { domain.rawValue }
}

private struct PPProMenuMapView: View {
    let capabilities: [PPProCommandCapability]
    let displayName: String
    let roleSummary: String
    let inboxUnreadCount: Int
    let supportUnreadCount: Int
    let palette: PPProPalette
    let isRTL: Bool
    let reduceMotion: Bool
    let onRoute: (String) -> Void

    @Environment(\.sizeCategory) private var sizeCategory
    @State private var appeared = false

    private func localized(_ key: String) -> String { Language.get(key, alter: nil) }
    private var isAccessibilitySize: Bool { sizeCategory.isAccessibilityCategory }

    /// Groups the live capabilities plus the synthetic Notifications entry into
    /// ordered, identity-distinct sections. Pure derivation — no side effects.
    private var sections: [PPProMenuSection] {
        var buckets: [PPProMenuDomain: [PPProMenuEntry]] = [:]

        // Synthetic Notifications entry, from the real unread signal counts.
        let notificationBadge = inboxUnreadCount + supportUnreadCount
        buckets[.notifications, default: []].append(
            PPProMenuEntry(
                id: "notificationsInbox",
                title: localized("NotificationsTitle"),
                subtitle: localized("MenuMap_Notifications_Subtitle"),
                symbolName: "bell.badge.fill",
                routeTag: "notificationsInbox",
                badgeCount: notificationBadge,
                isReadOnly: false
            )
        )

        for capability in capabilities {
            let domain = PPProMenuDomain.domain(forCapabilityID: capability.id)
            buckets[domain, default: []].append(
                PPProMenuEntry(
                    id: capability.id,
                    title: capability.title,
                    subtitle: capability.subtitle,
                    symbolName: capability.symbolName,
                    routeTag: capability.routeTag,
                    badgeCount: capability.actionCount,
                    isReadOnly: capability.isReadOnly
                )
            )
        }

        return buckets
            .map { PPProMenuSection(domain: $0.key, entries: $0.value) }
            .sorted { $0.domain.order < $1.domain.order }
    }

    /// Total addressable entries, shown as a quiet vitals count in the header.
    private var totalEntries: Int {
        sections.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: PPProPulseRhythm.spineGap) {
                    if sections.count <= 1 {
                        // Only the synthetic Notifications family exists: no
                        // provider capability is enabled for this account.
                        lockedState
                    }

                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        sectionView(section, index: index)
                    }
                }
                .padding(.horizontal, PPProPulseRhythm.screenMargin)
                .padding(.top, PPProPulseRhythm.spineGap)
                .padding(.bottom, 28)
            }
        }
        .background(palette.canvas.ignoresSafeArea())
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(PPProMotion.entrance) { appeared = true }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("MenuMap_Eyebrow"))
                        .font(PPProType.bold(10, relativeTo: .caption2))
                        .tracking(isRTL ? 0 : 0.6)
                        .foregroundStyle(palette.accentText)
                        .lineLimit(1)
                    Text(localized("MenuMap_Title"))
                        .font(PPProType.bold(22, relativeTo: .title2))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !displayName.isEmpty || !roleSummary.isEmpty {
                        Text(roleSummary.isEmpty ? displayName : roleSummary)
                            .font(PPProType.regular(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            // Quiet vitals line: how many doors, across how many families.
            HStack(spacing: 6) {
                Text("\(totalEntries)")
                    .font(PPProType.bold(12, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                Text(localized("MenuMap_ActiveEntries"))
                    .font(PPProType.regular(11, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                Text("·")
                    .foregroundStyle(palette.secondary.opacity(0.6))
                Text("\(sections.count)")
                    .font(PPProType.bold(12, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                Text(localized("MenuMap_Families"))
                    .font(PPProType.regular(11, relativeTo: .caption))
                    .foregroundStyle(palette.secondary)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, PPProPulseRhythm.screenMargin)
        .padding(.top, PPProPulseRhythm.spineGap)
        .padding(.bottom, 12)
        .background(
            palette.surface
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(palette.hairline)
                        .frame(height: 1 / UIScreen.main.scale)
                }
        )
    }

    // MARK: Section

    private func sectionView(_ section: PPProMenuSection, index: Int) -> some View {
        let accent = Color(uiColor: section.domain.accentUIColor)
        let accentSoft = Color(uiColor: section.domain.accentUIColor
            .withAlphaComponent(palette.isDark ? 0.24 : 0.12))

        return VStack(alignment: .leading, spacing: PPProPulseRhythm.stackGap) {
            sectionHeader(section, accent: accent, accentSoft: accentSoft)

            VStack(spacing: 8) {
                ForEach(section.entries) { entry in
                    entryRow(entry, accent: accent, accentSoft: accentSoft)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPProRadius.stage, style: .continuous)
                .stroke(accent.opacity(palette.isDark ? 0.32 : 0.22), lineWidth: 1)
        )
        .overlay(alignment: isRTL ? .trailing : .leading) {
            // Domain identity spine: a soft vertical accent edge.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 18)
                .opacity(0.9)
        }
        .shadow(color: palette.shadow, radius: 12, x: 0, y: 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(
            reduceMotion ? nil : PPProMotion.entrance.delay(PPProMotion.entranceDelay(index)),
            value: appeared
        )
        .accessibilityElement(children: .contain)
    }

    private func sectionHeader(
        _ section: PPProMenuSection,
        accent: Color,
        accentSoft: Color
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                    .fill(accent)
                Image(systemName: section.domain.symbol)
                    .font(.system(size: PPProGlyph.medium, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: PPProGlyph.plateMedium, height: PPProGlyph.plateMedium)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(localized(section.domain.eyebrowKey))
                    .font(PPProType.bold(9, relativeTo: .caption2))
                    .tracking(isRTL ? 0 : 0.55)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Text(localized(section.domain.titleKey))
                    .font(PPProType.bold(16, relativeTo: .headline))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            Text("\(section.entries.count)")
                .font(PPProType.bold(12, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .frame(minHeight: 24)
                .background(Capsule().fill(accentSoft))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localized(section.domain.titleKey))
        .accessibilityValue("\(section.entries.count)")
    }

    // MARK: Entry row

    private func entryRow(
        _ entry: PPProMenuEntry,
        accent: Color,
        accentSoft: Color
    ) -> some View {
        let isDisabled = entry.routeTag.isEmpty

        return Button {
            guard !isDisabled else { return }
            // Server re-checks ownership/scope/permission on the pushed screen;
            // this only emits the established route tag.
            onRoute(entry.routeTag)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PPProRadius.control, style: .continuous)
                        .fill(accentSoft)
                    Image(systemName: entry.symbolName)
                        .font(.system(size: PPProGlyph.medium, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: PPProGlyph.plateLarge, height: PPProGlyph.plateLarge)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(PPProType.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(palette.text)
                        .lineLimit(isAccessibilitySize ? 3 : 1)
                        .multilineTextAlignment(.leading)
                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(PPProType.regular(11, relativeTo: .caption))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(isAccessibilitySize ? 4 : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if entry.isReadOnly {
                    Image(systemName: "eye.fill")
                        .font(.system(size: PPProGlyph.small, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .accessibilityHidden(true)
                } else if entry.badgeCount > 0 {
                    Text(entry.badgeCount > 99 ? "99+" : "\(entry.badgeCount)")
                        .font(PPProType.bold(11, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 22)
                        .background(Capsule().fill(accent))
                        .accessibilityHidden(true)
                }

                Image(systemName: isRTL ? "chevron.left" : "chevron.right")
                    .font(.system(size: PPProGlyph.small, weight: .bold))
                    .foregroundStyle(accent.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: isAccessibilitySize ? 72 : 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .fill(palette.canvas.opacity(palette.isDark ? 0.5 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPProRadius.tile, style: .continuous)
                    .stroke(palette.hairline, lineWidth: 0.8)
            )
        }
        .buttonStyle(PPProCommandPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.title)
        .accessibilityValue(
            entry.isReadOnly
                ? localized("MenuMap_ReadOnly")
                : (entry.badgeCount > 0 ? "\(entry.badgeCount)" : "")
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Empty / locked

    private var lockedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.secondary)
            Text(localized("MenuMap_Locked_Title"))
                .font(PPProType.bold(15, relativeTo: .headline))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
            Text(localized("MenuMap_Locked_Subtitle"))
                .font(PPProType.regular(12, relativeTo: .caption))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .ppProCommandSurface(radius: PPProRadius.card, palette: palette)
        .accessibilityElement(children: .combine)
    }
}
