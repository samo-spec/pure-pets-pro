import SwiftUI
import UIKit
import Combine

// MARK: - Country Data

private struct ProCountry: Identifiable {
    let id: String // iso code
    let name: String
    let localizedName: String
    let phoneCode: String
    let flag: String

    static var all: [ProCountry] {
        CitiesManager.shared().countryDialCodeOptions().compactMap { option in
            let iso = (option["iso"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let phoneCode = (option["value"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let englishName = (option["enName"] ?? option["name"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let arabicName = (option["arName"] ?? option["name"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !iso.isEmpty, !phoneCode.isEmpty, !englishName.isEmpty || !arabicName.isEmpty else {
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
        all.sorted { isRTL ? $0.localizedName < $1.localizedName : $0.name < $1.name }
    }
}

// MARK: - Country Picker Sheet

private struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let isRTL: Bool
    let onSelect: (ProCountry) -> Void

    @State private var searchText = ""
    @State private var countryRevision = 0

    private var filtered: [ProCountry] {
        _ = countryRevision
        let all = ProCountry.sorted(for: isRTL)
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.localizedName.contains(searchText) ||
            $0.phoneCode.contains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                                .opacity(CitiesManager.shared().isLoading ? 1 : 0)
                            Text(countryEmptyMessage)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(filtered) { country in
                            Button {
                                onSelect(country)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text(country.flag)
                                        .font(.system(size: 28))
                                        .frame(width: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isRTL ? country.localizedName : country.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(country.phoneCode)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if country.id != filtered.last?.id {
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(localized("ProviderCountryPickerTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Cancel")) { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            CitiesManager.shared().loadData()
            countryRevision += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CitiesManagerDidUpdateNotification"))) { _ in
            countryRevision += 1
        }
    }

    private var countryEmptyMessage: String {
        localized(CitiesManager.shared().isLoading ? "ProviderCountriesLoading" : "ProviderCountriesUnavailable")
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
        textField.font = UIFont(name: "Beiruti-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
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

        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = isEnabled
        uiView.textColor = .label
        uiView.tintColor = .label
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont(name: "Beiruti-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
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
            let raw = sender.text ?? ""
            // Normalize Arabic/Persian digits to English for phone pad
            let value = Self.normalizeArabicDigits(raw)
            if text.wrappedValue != value {
                text.wrappedValue = value
            }
            onChange(value)
            // Update text field in case normalization changed it
            if sender.text != value {
                sender.text = value
            }
        }
        
        private static func normalizeArabicDigits(_ input: String) -> String {
            if input.isEmpty { return input }
            let map: [String: String] = [
                "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
                "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
                "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
                "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
                "٬": ",", "٫": "."
            ]
            var result = input
            for (arabic, english) in map {
                result = result.replacingOccurrences(of: arabic, with: english)
            }
            return result
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused.wrappedValue = false
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
    @Published var phoneText: String = ""
    @Published var countryCode: String = "+974"
    @Published var isBusy: Bool = false
    @Published var isPhoneContinueEnabled: Bool = false
    @Published var showsAppleButton: Bool = true
    @Published var isRTL: Bool = Language.isRTL()
    @Published var refreshToken: UUID = UUID()
    @Published var loginFormFocusToken: Int = 0
}

@objcMembers
public final class PPProLoginSurfaceController: UIViewController {

    public weak var delegate: PPProLoginSurfaceControllerDelegate?

    public var phoneText: String = "" {
        didSet {
            if model.phoneText != phoneText {
                model.phoneText = phoneText
            }
        }
    }

    public var countryCode: String = "+974" {
        didSet {
            if model.countryCode != countryCode {
                model.countryCode = countryCode
            }
        }
    }

    public var isBusy: Bool = false {
        didSet {
            if model.isBusy != isBusy {
                model.isBusy = isBusy
            }
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
            if model.showsAppleButton != showsAppleButton {
                model.showsAppleButton = showsAppleButton
            }
        }
    }

    private let model = PPProLoginSurfaceModel()
    private var host: UIHostingController<PPLoginRoot>?

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

        let root = PPLoginRoot(
            model: model,
            onPhoneChange: { [weak self] text in
                self?.handlePhoneChange(text)
            },
            onCountryCodeTap: { [weak self] in
                guard let self else { return }
                self.delegate?.proLoginSurfaceDidRequestCountryCode(self)
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

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
        host = hostingController
    }

    public func refreshLocalizationContext() {
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        model.isRTL = Language.isRTL()
        model.refreshToken = UUID()
    }

    public func focusLoginFormCard() {
        model.loginFormFocusToken &+= 1
    }

    private func handlePhoneChange(_ text: String) {
        if phoneText != text {
            phoneText = text
        }
        delegate?.proLoginSurface(self, didChangePhoneText: text)
    }
}

private enum PPLoginToken {
    static let compactPadding: CGFloat = 22
    static let regularPadding: CGFloat = 40
    static let compactGap: CGFloat = 28
    static let regularGap: CGFloat = 64
    static let chromeRadius: CGFloat = 17
    static let heroRadius: CGFloat = 34
    static let surfaceRadius: CGFloat = 32
    static let infoRadius: CGFloat = 30
    static let inputRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 24
    static let secondaryButtonRadius: CGFloat = 21
}

private struct PPLoginPalette {
    let canvas: Color
    let surface: Color
    let surfaceAlt: Color
    let line: Color
    let cardBorder: Color
    let strongLine: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let accentShiner: Color
    let pillFill: Color
    let pillBorder: Color
    let glowTop: Color
    let glowBottom: Color
    let secondaryFill: Color
    let secondaryBorder: Color
    let primaryFill: Color
    let primaryText: Color
    let dark: Bool

    static func resolve(_ scheme: ColorScheme) -> PPLoginPalette {
        let isDark = (scheme == .dark)
        let accentUIColor = UIColor(named: "AppPrimaryClr") ?? .systemTeal
        let accentShinerUIColor = UIColor(named: "AppPrimaryClrShiner") ?? accentUIColor
        let surfaceUIColor = UIColor(named: "AppForgroundColr") ?? .secondarySystemBackground
        let canvasUIColor = UIColor.secondarySystemBackground
        let primaryTextUIColor = UIColor.label
        let secondaryTextUIColor = UIColor.secondaryLabel

        return PPLoginPalette(
            canvas: Color(uiColor: canvasUIColor),
            surface: Color(uiColor: surfaceUIColor),
            surfaceAlt: Color(uiColor: accentUIColor.withAlphaComponent(isDark ? 0.10 : 0.05)),
            line: Color(uiColor: secondaryTextUIColor.withAlphaComponent(0.10)),
            cardBorder: Color(uiColor: accentUIColor.withAlphaComponent(0.08)),
            strongLine: Color(uiColor: accentUIColor.withAlphaComponent(0.14)),
            textPrimary: Color(uiColor: primaryTextUIColor),
            textSecondary: Color(uiColor: secondaryTextUIColor.withAlphaComponent(0.92)),
            textTertiary: Color(uiColor: secondaryTextUIColor),
            accent: Color(uiColor: accentUIColor),
            accentShiner: Color(uiColor: accentShinerUIColor),
            pillFill: Color(uiColor: accentUIColor.withAlphaComponent(0.10)),
            pillBorder: Color(uiColor: accentUIColor.withAlphaComponent(0.14)),
            glowTop: Color(uiColor: accentUIColor.withAlphaComponent(0.06)),
            glowBottom: Color(uiColor: accentUIColor.withAlphaComponent(0.04)),
            secondaryFill: Color(uiColor: accentUIColor.withAlphaComponent(0.08)),
            secondaryBorder: Color(uiColor: accentUIColor.withAlphaComponent(0.10)),
            primaryFill: Color(uiColor: accentUIColor),
            primaryText: .white,
            dark: isDark
        )
    }
}

private enum PPLoginHeroIcon {
    static func image(for systemName: String, pointSize: CGFloat, weight: Font.Weight) -> some View {
        Image(systemName: systemName)
            .font(.system(size: pointSize, weight: weight))
    }
}

private extension Alignment {
    static func topTrailingForLayoutDirection(_ isRTL: Bool) -> Alignment {
        isRTL ? .topLeading : .topTrailing
    }

    static func bottomTrailingForLayoutDirection(_ isRTL: Bool) -> Alignment {
        isRTL ? .bottomLeading : .bottomTrailing
    }

    static func bottomLeadingForLayoutDirection(_ isRTL: Bool) -> Alignment {
        isRTL ? .bottomTrailing : .bottomLeading
    }

    static func topLeadingForLayoutDirection(_ isRTL: Bool) -> Alignment {
        isRTL ? .topTrailing : .topLeading
    }

    static func trailingForLayoutDirection(_ isRTL: Bool) -> Alignment {
        isRTL ? .leading : .trailing
    }
}

private enum PPTypography {
    static func wordmark(_ size: CGFloat) -> Font { .custom("Beiruti-Medium", size: size) }
    static func display(_ size: CGFloat) -> Font { .custom("Beiruti-Bold", size: size) }
    static func section(_ size: CGFloat) -> Font { .custom("Beiruti-Bold", size: size) }
    static func label(_ size: CGFloat) -> Font { .custom("Beiruti-Medium", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Beiruti-Regular", size: size) }
}

private struct PPLoginRoot: View {
    private static let loginFormAnchor = "pp-pro-login-form-anchor"
    private static let loginFormBottomAnchor = "pp-pro-login-form-bottom-anchor"

    @ObservedObject var model: PPProLoginSurfaceModel
    let onPhoneChange: (String) -> Void
    let onCountryCodeTap: () -> Void
    let onPhoneContinue: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onSupport: () -> Void
    let onLanguage: () -> Void
    let onProviderApplication: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phoneFocused = false
    @State private var heroVisible = false
    @State private var formVisible = false
    @State private var heroCardAlive = false
    @State private var formCardAlive = false
    @State private var formFocusPulse = false
    @State private var handledLoginFormFocusToken = 0
    @State private var providerCardAlive = false
    @State private var showCountryPicker = false

    private var palette: PPLoginPalette { .resolve(colorScheme) }
    private var isRTL: Bool { model.isRTL }
    private var forwardSymbolName: String { isRTL ? "arrow.left" : "arrow.right" }
    private var heroEntrySymbolName: String { "lock.shield.fill" }

    var body: some View {
        let _ = model.refreshToken

        return GeometryReader { geometry in
            let compact = geometry.size.width < 780
            let horizontalPadding = compact ? PPLoginToken.compactPadding : PPLoginToken.regularPadding
            let safeTopInset = geometry.safeAreaInsets.top
            let topInset = compact
                ? max(min(safeTopInset + 4, 58), 18)
                : max(min(safeTopInset + 6, 64), 24)
            let bottomInset = max(geometry.safeAreaInsets.bottom + 20, 26)
            let minimumHeight = max(geometry.size.height - topInset - bottomInset, 0)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        mainContent(compact: compact)
                            .frame(minHeight: minimumHeight, alignment: compact ? .top : .center)
                            .padding(.top, topInset)
                            .padding(.horizontal, horizontalPadding)

                        footer
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, compact ? 24 : 18)
                            .padding(.bottom, bottomInset)
                            .opacity(formVisible ? 1 : 0)
                            .offset(y: formVisible ? 0 : 12)

                        Color.clear
                            .frame(height: 1)
                            .id(Self.loginFormBottomAnchor)
                    }
                    .frame(maxWidth: .infinity)
                }
                .background(ambientBackground)
                .scrollDismissesKeyboardCompat()
                .onReceive(model.$loginFormFocusToken) { token in
                    guard token != 0, token != handledLoginFormFocusToken else { return }
                    handledLoginFormFocusToken = token
                    withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
                        proxy.scrollTo(Self.loginFormBottomAnchor, anchor: .bottom)
                    }
                    performLoginFormFocusMotion()
                }
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear(perform: animateEntrance)
    }

    private var ambientBackground: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()

            Circle()
                .fill(palette.glowTop)
                .frame(width: 280, height: 280)
                .offset(x: isRTL ? -60 : 60, y: -80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailingForLayoutDirection(isRTL))

            Circle()
                .fill(palette.glowBottom)
                .frame(width: 320, height: 320)
                .offset(x: isRTL ? 80 : -80, y: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeadingForLayoutDirection(isRTL))
        }
    }

    @ViewBuilder
    private func mainContent(compact: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: PPLoginToken.compactGap) {
                heroColumn(compact: true)

                providerStrip(compact: true)
                    .opacity(formVisible ? 1 : 0)
                    .offset(y: formVisible ? 0 : 24)

                authWorkspace(compact: true)
                    .id(Self.loginFormAnchor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: PPLoginToken.regularGap) {
                VStack(alignment: .leading, spacing: 24) {
                    heroColumn(compact: false)

                    providerStrip(compact: false)
                        .opacity(formVisible ? 1 : 0)
                        .offset(y: formVisible ? 0 : 24)
                }
                    .frame(maxWidth: 500, alignment: .leading)

                VStack(spacing: 0) {
                    authWorkspace(compact: false)
                        .id(Self.loginFormAnchor)
                }
                .frame(maxWidth: 500, alignment: .leading)
            }
            .frame(maxWidth: 1100, alignment: .center)
            .frame(maxWidth: .infinity)
        }
    }

    private func utilityButton(title: String, systemName: String, compact: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: compact ? 13 : 14, weight: .medium))

                Text(title)
                    .font(PPTypography.label(compact ? 13 : 14))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, compact ? 13 : 15)
            .padding(.vertical, compact ? 10 : 11)
            .background(
                RoundedRectangle(cornerRadius: PPLoginToken.chromeRadius, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPLoginToken.chromeRadius, style: .continuous)
                    .strokeBorder(palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PPLoginPressStyle())
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.48 : 1)
    }

    private func heroColumn(compact: Bool) -> some View {
        ZStack(alignment: .topLeadingForLayoutDirection(isRTL)) {
            heroCardBackground(compact: compact)

            VStack(alignment: .leading, spacing: compact ? 20 : 22) {
                heroTopRow(compact: compact)

                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("ProLoginSubtitle"))
                        .font(PPTypography.display(compact ? 31 : 42))
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(compact ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(localized("ProLoginAuthHint"))
                        .font(PPTypography.body(compact ? 15 : 16))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                complianceLedger()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: PPLoginToken.heroRadius, style: .continuous))
        .overlay(heroCardStroke(radius: PPLoginToken.heroRadius))
        .shadow(color: Color.black.opacity(palette.dark ? 0.18 : 0.05), radius: 40, x: 0, y: 20)
        .multilineTextAlignment(isRTL ? .trailing : .leading)
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 20)
        .onAppear {
            startHeroCardMotionIfNeeded()
        }
    }

    private func heroTopRow(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            heroLogoMark(compact: compact)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                utilityButton(
                    title: localized("ProLoginSupportChip"),
                    systemName: "questionmark.circle",
                    compact: true,
                    action: onSupport
                )

                utilityButton(
                    title: Language.languageVal() == 0 ? "AR" : "EN",
                    systemName: "globe",
                    compact: true,
                    action: onLanguage
                )
            }
            .layoutPriority(1)
        }
    }

    private func heroLogoMark(compact: Bool) -> some View {
        let size: CGFloat = compact ? 58 : 66

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.pillFill,
                            palette.surface.opacity(palette.dark ? 0.92 : 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .trim(from: 0.12, to: 0.72)
                .stroke(
                    AngularGradient(
                        colors: [
                            palette.accent.opacity(0.0),
                            palette.accent.opacity(0.62),
                            Color.white.opacity(palette.dark ? 0.20 : 0.70)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(heroCardAlive && !reduceMotion ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 8.4).repeatForever(autoreverses: false), value: heroCardAlive)

            Image("AD_LOGO")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                .scaleEffect(heroCardAlive && !reduceMotion ? 1.03 : 0.98)
                .animation(reduceMotion ? nil : .easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: heroCardAlive)
        }
        .frame(width: size, height: size)
        .shadow(color: palette.accent.opacity(palette.dark ? 0.12 : 0.18), radius: 16, x: 0, y: 8)
        .accessibilityHidden(true)
    }

    private func complianceLedger() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ledgerRow(
                systemName: "checkmark.shield.fill",
                title: localized("ProLoginAccessTitle"),
                detail: localized("ProLoginAccessSummary")
            )

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            ledgerRow(
                systemName: "person.2.badge.key.fill",
                title: localized("ProLoginSupportTitle"),
                detail: localized("ProLoginSupportSummary")
            )
        }
        .background(
            RoundedRectangle(cornerRadius: PPLoginToken.infoRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surface.opacity(palette.dark ? 0.80 : 0.96),
                            palette.surfaceAlt.opacity(palette.dark ? 0.55 : 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPLoginToken.infoRadius, style: .continuous)
                .strokeBorder(palette.cardBorder, lineWidth: 1)
        )
    }

    private func ledgerRow(systemName: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.pillFill)

                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 34, height: 34)
            .scaleEffect(heroCardAlive && !reduceMotion ? 1.03 : 0.98)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PPTypography.label(13))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(PPTypography.body(13))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func authWorkspace(compact: Bool) -> some View {
        ZStack {
            formCardBackground(compact: compact)

            VStack(alignment: .leading, spacing: compact ? 22 : 24) {
                workspaceHeader(compact: compact)
                phoneEntry
                continueButton
                secondaryActions
            }
            .padding(compact ? 22 : 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius, style: .continuous))
        .overlay(formCardStroke)
        .overlay(formFocusAura)
        .shadow(
            color: formFocusPulse && !reduceMotion ? palette.accent.opacity(palette.dark ? 0.16 : 0.14) : Color.black.opacity(palette.dark ? 0.18 : 0.05),
            radius: formFocusPulse && !reduceMotion ? 44 : 36,
            x: 0,
            y: formFocusPulse && !reduceMotion ? 24 : 20
        )
        .scaleEffect(formFocusPulse && !reduceMotion ? 1.012 : 1)
        .opacity(formVisible ? 1 : 0)
        .offset(y: formVisible ? 0 : 24)
        .animation(.spring(response: 0.44, dampingFraction: 0.78), value: formFocusPulse)
        .onAppear {
            startFormCardMotionIfNeeded()
        }
    }

    private func workspaceHeader(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(localized("ProLoginPhoneSectionTitle"), useAccent: true)

                Text(localized("ProLoginAuthHeading"))
                    .font(PPTypography.section(compact ? 27 : 32))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(localized("ProLoginFormSubtitle"))
                    .font(PPTypography.body(15))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.pillFill,
                                palette.surfaceAlt.opacity(palette.dark ? 0.65 : 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                PPLoginHeroIcon.image(for: heroEntrySymbolName, pointSize: 18, weight: .semibold)
                    .foregroundStyle(palette.accent)
                    .scaleEffect(formCardAlive && !reduceMotion ? 1.08 : 0.98)
            }
            .frame(width: 48, height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(palette.accent.opacity(palette.dark ? 0.18 : 0.16), lineWidth: 1)
            )
        }
    }

    private var phoneEntry: some View {
        let emphasized = phoneFocused || (formFocusPulse && !reduceMotion)
        let currentCountry = ProCountry.sorted(for: isRTL).first(where: { $0.phoneCode == model.countryCode })

        return HStack(spacing: 0) {
            Button(action: { showCountryPicker = true }) {
                HStack(spacing: 6) {
                    if let country = currentCountry {
                        Text(country.flag)
                            .font(.system(size: 22))
                    }
                    Text(model.countryCode)
                        .font(PPTypography.label(16))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 17)
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            Rectangle()
                .fill(emphasized ? palette.strongLine : palette.line)
                .frame(width: 1, height: 28)

            PPPhoneNumberTextField(
                text: Binding(
                    get: { model.phoneText },
                    set: { model.phoneText = $0 }
                ),
                isFocused: $phoneFocused,
                placeholder: localized("ProLoginPhonePlaceholder"),
                isEnabled: !model.isBusy,
                onChange: onPhoneChange
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .frame(minHeight: 56)
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(
            RoundedRectangle(cornerRadius: PPLoginToken.inputRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surfaceAlt.opacity(palette.dark ? 0.92 : 1.0),
                            palette.surface.opacity(palette.dark ? 0.84 : 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPLoginToken.inputRadius, style: .continuous)
                .strokeBorder(emphasized ? palette.strongLine : palette.cardBorder, lineWidth: emphasized ? 1.2 : 1)
        )
        .shadow(color: emphasized ? palette.accent.opacity(palette.dark ? 0.14 : 0.12) : .clear, radius: 18, x: 0, y: 8)
        .animation(.easeOut(duration: 0.18), value: phoneFocused)
        .animation(.easeOut(duration: 0.22), value: formFocusPulse)
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(isRTL: isRTL) { country in
                model.countryCode = country.phoneCode
            }
        }
    }

    private var continueButton: some View {
        let disabled = !model.isPhoneContinueEnabled || model.isBusy

        return Button(action: onPhoneContinue) {
            HStack(spacing: 12) {
                Text(localized("ProLoginContinuePhone"))
                    .font(PPTypography.label(16))
                    .lineLimit(1)

                Spacer(minLength: 12)

                if model.isBusy {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: palette.primaryText))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: forwardSymbolName)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(disabled ? palette.textSecondary : palette.primaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: PPLoginToken.buttonRadius, style: .continuous)
                        .fill(disabled ? palette.primaryFill.opacity(palette.dark ? 0.18 : 0.14) : palette.primaryFill)

                    if !disabled && !reduceMotion {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.20),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 58)
                            .rotationEffect(.degrees(isRTL ? -16 : 16))
                            .offset(x: formCardAlive ? (isRTL ? -210 : 210) : (isRTL ? 210 : -210))
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: PPLoginToken.buttonRadius, style: .continuous))
            )
        }
        .buttonStyle(PPLoginPressStyle())
        .disabled(disabled)
        .shadow(color: disabled ? .clear : palette.accent.opacity(palette.dark ? 0.16 : 0.22), radius: 18, x: 0, y: 10)
    }

    private var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            dividerLabel(localized("ProLoginOr"))

            if model.showsAppleButton {
                secondaryButton(
                    title: localized("ProLoginSignInWithApple"),
                    action: onApple,
                    leading: {
                        Image(systemName: "applelogo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                    }
                )
            }

            secondaryButton(
                title: localized("ProLoginSignInWithGoogle"),
                action: onGoogle,
                leading: {
                    Text("G")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }
            )
        }
    }

    private func dividerLabel(_ title: String) -> some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            Text(title)
                .font(PPTypography.body(12))
                .foregroundStyle(palette.textTertiary)

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
        }
    }

    private func secondaryButton<Leading: View>(
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading()
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(PPTypography.label(15))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Image(systemName: forwardSymbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [
                        palette.secondaryFill,
                        palette.surface.opacity(palette.dark ? 0.72 : 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: PPLoginToken.secondaryButtonRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPLoginToken.secondaryButtonRadius, style: .continuous)
                    .strokeBorder(palette.secondaryBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PPLoginPressStyle())
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.48 : 1)
    }

    private func heroCardBackground(compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPLoginToken.heroRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surface,
                            palette.surfaceAlt.opacity(palette.dark ? 0.78 : 0.92),
                            palette.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.glowTop.opacity(palette.dark ? 1.0 : 1.18))
                .frame(width: compact ? 190 : 226, height: compact ? 190 : 226)
                .blur(radius: 8)
                .offset(x: isRTL ? 38 : -38, y: heroCardAlive && !reduceMotion ? -52 : -34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeadingForLayoutDirection(isRTL))

            Circle()
                .fill(palette.glowBottom.opacity(palette.dark ? 0.92 : 1.08))
                .frame(width: compact ? 132 : 164, height: compact ? 132 : 164)
                .blur(radius: 10)
                .offset(x: isRTL ? -18 : 18, y: heroCardAlive && !reduceMotion ? 54 : 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailingForLayoutDirection(isRTL))

            if !reduceMotion {
                heroConstellation(compact: compact)
                    .opacity(palette.dark ? 0.26 : 0.20)
            }
        }
    }

    private func heroConstellation(compact: Bool) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? palette.accent : Color.white)
                    .frame(width: index.isMultiple(of: 2) ? 5 : 4, height: index.isMultiple(of: 2) ? 5 : 4)
                    .offset(
                        x: CGFloat([22, 74, 132, 194, 246][index]) * (compact ? 0.72 : 1.0),
                        y: CGFloat([18, 78, 36, 116, 62][index]) * (compact ? 0.78 : 1.0)
                    )
                    .scaleEffect(heroCardAlive ? 1.28 : 0.82)
                    .animation(
                        .easeInOut(duration: 4.6 + Double(index) * 0.35).repeatForever(autoreverses: true),
                        value: heroCardAlive
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeadingForLayoutDirection(isRTL))
        .allowsHitTesting(false)
    }

    private func heroCardStroke(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(palette.dark ? 0.10 : 0.58),
                        palette.accent.opacity(palette.dark ? 0.20 : 0.16),
                        palette.cardBorder
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func formCardBackground(compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surface,
                            palette.surfaceAlt.opacity(palette.dark ? 0.72 : 0.90),
                            palette.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.accent.opacity(palette.dark ? 0.12 : 0.09))
                .frame(width: compact ? 126 : 156, height: compact ? 126 : 156)
                .blur(radius: 20)
                .offset(x: isRTL ? -46 : 46, y: formCardAlive && !reduceMotion ? -34 : -18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailingForLayoutDirection(isRTL))

            Circle()
                .fill(Color.white.opacity(palette.dark ? 0.04 : 0.26))
                .frame(width: compact ? 98 : 124, height: compact ? 98 : 124)
                .blur(radius: 18)
                .offset(x: isRTL ? 26 : -26, y: formCardAlive && !reduceMotion ? 36 : 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeadingForLayoutDirection(isRTL))

            if !reduceMotion {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(palette.dark ? 0.055 : 0.18),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 72)
                    .rotationEffect(.degrees(isRTL ? -18 : 18))
                    .offset(x: formCardAlive ? (isRTL ? -260 : 260) : (isRTL ? 260 : -260))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        }
    }

    private var formCardStroke: some View {
        RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        palette.accent.opacity(palette.dark ? 0.20 : 0.16),
                        Color.white.opacity(palette.dark ? 0.08 : 0.54),
                        palette.cardBorder
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var formFocusAura: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius, style: .continuous)
                .strokeBorder(palette.accent.opacity(formFocusPulse && !reduceMotion ? 0.44 : 0.0), lineWidth: 1.6)

            RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius, style: .continuous)
                .strokeBorder(palette.accent.opacity(formFocusPulse && !reduceMotion ? 0.18 : 0.0), lineWidth: 8)
                .blur(radius: 8)
                .scaleEffect(formFocusPulse && !reduceMotion ? 1.028 : 0.99)
        }
        .allowsHitTesting(false)
    }

    private func providerStrip(compact: Bool) -> some View {
        Button(action: onProviderApplication) {
            ZStack {
                providerCardBackground(compact: compact)

                VStack(alignment: .leading, spacing: compact ? 16 : 18) {
                    HStack(alignment: .top, spacing: compact ? 14 : 18) {
                        providerAnimatedMark(compact: compact)
                            .frame(width: compact ? 76 : 88, height: compact ? 76 : 88)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(providerCardAlive && !reduceMotion ? 1.35 : 1.0)
                                    .opacity(providerCardAlive && !reduceMotion ? 0.62 : 1.0)

                                sectionLabel(localized("ProLoginProviderEyebrow"), useAccent: true)
                            }

                            Text(localized("ProLoginProviderHeadline"))
                                .font(PPTypography.section(compact ? 23 : 25))
                                .foregroundStyle(palette.textPrimary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(localized("ProLoginProviderSubtitle"))
                                .font(PPTypography.body(compact ? 14 : 15))
                                .foregroundStyle(palette.textSecondary)
                                .lineSpacing(4.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    providerFooter(compact: compact)
                    providerNote
                }
                .padding(.horizontal, compact ? 18 : 20)
                .padding(.vertical, compact ? 18 : 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius + 2, style: .continuous))
            .overlay(providerCardStroke)
            .shadow(color: Color.black.opacity(palette.dark ? 0.20 : 0.06), radius: 36, x: 0, y: 20)
        }
        .buttonStyle(PPLoginPressStyle())
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.48 : 1)
        .onAppear {
            guard !reduceMotion, !providerCardAlive else { return }
            withAnimation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true)) {
                providerCardAlive = true
            }
        }
    }

    @ViewBuilder
    private func providerFooter(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            providerBadge(title: localized("ProLoginProviderBadge"), systemName: "square.grid.2x2.fill")
            providerBadge(title: localized("ProLoginProviderSecondBadge"), systemName: "clock.badge.checkmark")

            Spacer(minLength: 8)

            providerCTA
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providerCTA: some View {
        HStack(spacing: 8) {
            Text(localized("ProLoginProviderCTA"))
                .font(PPTypography.label(14))
                .lineLimit(1)

            Image(systemName: forwardSymbolName)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(palette.primaryFill)
        )
        .shadow(color: palette.accent.opacity(palette.dark ? 0.16 : 0.22), radius: 14, x: 0, y: 8)
    }

    private var providerNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.82))
                .padding(.top, 1)

            Text(localized("ProLoginProviderNote"))
                .font(PPTypography.body(12))
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerCardBackground(compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius + 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surface,
                            palette.surfaceAlt.opacity(palette.dark ? 0.92 : 1.0),
                            palette.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(palette.accent.opacity(palette.dark ? 0.14 : 0.11))
                .frame(width: compact ? 150 : 180, height: compact ? 150 : 180)
                .blur(radius: 22)
                .offset(x: isRTL ? -56 : 56, y: providerCardAlive && !reduceMotion ? -46 : -28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailingForLayoutDirection(isRTL))

            Circle()
                .fill(Color.white.opacity(palette.dark ? 0.05 : 0.28))
                .frame(width: compact ? 118 : 138, height: compact ? 118 : 138)
                .blur(radius: 18)
                .offset(x: isRTL ? 38 : -38, y: providerCardAlive && !reduceMotion ? 42 : 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeadingForLayoutDirection(isRTL))

            if !reduceMotion {
                providerLightSweep
            }
        }
    }

    private var providerLightSweep: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(palette.dark ? 0.07 : 0.22),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 76)
            .rotationEffect(.degrees(isRTL ? -18 : 18))
            .offset(x: providerCardAlive ? (isRTL ? -260 : 260) : (isRTL ? 260 : -260))
            .blendMode(palette.dark ? .screen : .plusLighter)
            .allowsHitTesting(false)
    }

    private var providerCardStroke: some View {
        RoundedRectangle(cornerRadius: PPLoginToken.surfaceRadius + 2, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        palette.accent.opacity(palette.dark ? 0.24 : 0.20),
                        Color.white.opacity(palette.dark ? 0.10 : 0.62),
                        palette.cardBorder
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func providerAnimatedMark(compact: Bool) -> some View {
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.pillFill,
                            palette.surfaceAlt.opacity(palette.dark ? 0.58 : 0.82),
                            palette.surface.opacity(palette.dark ? 0.64 : 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "person.badge.plus")
                .font(.system(size: compact ? 24 : 27, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accentShiner)
                .scaleEffect(providerCardAlive && !reduceMotion ? 1.06 : 0.98)
        }
        .shadow(color: palette.accentShiner.opacity(palette.dark ? 0.10 : 0.14), radius: 12, x: 0, y: 7)
    }

    private func providerBadge(title: String, systemName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))

            Text(title)
                .font(PPTypography.label(11))
                .lineLimit(1)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(palette.pillFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(palette.pillBorder, lineWidth: 1)
        )
    }

    private var footer: some View {
        Text(localized("ProLoginFooter"))
            .font(PPTypography.body(12))
            .foregroundStyle(palette.textTertiary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
    }

    private func sectionLabel(_ title: String, useAccent: Bool = false) -> some View {
        Text(title)
            .font(PPTypography.label(11))
            .foregroundStyle(useAccent ? palette.accent : palette.textTertiary)
            .kerning(isRTL ? 0 : 1.1)
    }

    private func animateEntrance() {
        guard !heroVisible && !formVisible else { return }

        withAnimation(.spring(response: 0.68, dampingFraction: 0.9).delay(0.06)) {
            heroVisible = true
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.92).delay(0.12)) {
            formVisible = true
        }
    }

    private func startHeroCardMotionIfNeeded() {
        guard !reduceMotion, !heroCardAlive else { return }

        withAnimation(.easeInOut(duration: 5.6).repeatForever(autoreverses: true)) {
            heroCardAlive = true
        }
    }

    private func startFormCardMotionIfNeeded() {
        guard !reduceMotion, !formCardAlive else { return }

        withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
            formCardAlive = true
        }
    }

    private func performLoginFormFocusMotion() {
        guard !reduceMotion else {
            return
        }

        let focusToken = model.loginFormFocusToken
        withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
            formFocusPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            guard model.loginFormFocusToken == focusToken else { return }
            withAnimation(.easeOut(duration: 0.42)) {
                formFocusPulse = false
            }
        }
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: nil)
    }
}

private struct PPLoginPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
