//
//  PPAdminDesignCompat.swift
//  PurePetsPro
//
//  Design system tokens and components compatibility bridge for NextGen V6
//  product variant studio in Pure Pets Pro.
//

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox
import PhotosUI

// MARK: - AdminSurface Colors

public enum AdminSurface {
    public static var primary: Color { Color(uiColor: .ppPrimary) }
    public static var primaryPressed: Color { Color(uiColor: .ppPressedAction) }
    public static var primarySoft: Color { Color(uiColor: .ppPrimaryShiner) }
    public static var background: Color { Color(uiColor: .ppBackground) }
    public static var backgroundSecondary: Color { Color(uiColor: .ppSecondarySurface) }
    public static var control: Color { Color(uiColor: .ppElevatedSurface) }
    public static var container: Color { Color(uiColor: .ppElevatedSurface) }
    public static var fieldBackground: Color { Color(uiColor: .ppElevatedSurface) }
    public static var surface: Color { Color(uiColor: .ppSurface) }
    public static var card: Color { Color(uiColor: .ppSurface) }
    public static var cardElevated: Color { Color(uiColor: .ppElevatedSurface) }
    public static var amber: Color { Color(uiColor: .ppWarning) }
    public static var emerald: Color { Color(uiColor: .ppSuccess) }
    public static var crimson: Color { Color(uiColor: .ppError) }
    public static var danger: Color { Color(uiColor: .ppError) }
    public static var primaryText: Color { Color(uiColor: .ppTextPrimary) }
    public static var secondaryText: Color { Color(uiColor: .ppTextSecondary) }
    public static var hairline: Color { Color(uiColor: .ppSurfaceBorder) }
    public static var borderSubtle: Color { Color(uiColor: .ppSurfaceBorder) }
}

// MARK: - AdminCommandInk

public enum AdminCommandInk {
    public static var primary: Color { AdminSurface.primaryText }
    public static var secondary: Color { AdminSurface.secondaryText }
    public static var tertiary: Color { AdminSurface.secondaryText.opacity(0.6) }
}


// MARK: - AdminType Typography

public enum AdminType {
    private static func font(named name: String, size: CGFloat, fallbackWeight: Font.Weight, relativeTo textStyle: Font.TextStyle) -> Font {
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size, relativeTo: textStyle)
        }
        return Font.system(size: size, weight: fallbackWeight)
    }

    public static let largeTitle = font(named: "Beiruti-Bold", size: 38, fallbackWeight: .bold, relativeTo: .largeTitle)
    public static let title = font(named: "Beiruti-Bold", size: 32, fallbackWeight: .bold, relativeTo: .title)
    public static let title2 = font(named: "Beiruti-Bold", size: 24, fallbackWeight: .bold, relativeTo: .title2)
    public static let title3 = font(named: "Beiruti-Bold", size: 20, fallbackWeight: .bold, relativeTo: .title3)
    public static let title3Bold = font(named: "Beiruti-Bold", size: 20, fallbackWeight: .bold, relativeTo: .title3)
    public static let headline = font(named: "Beiruti-Bold", size: 17, fallbackWeight: .bold, relativeTo: .headline)
    public static let headlineBold = font(named: "Beiruti-Bold", size: 17, fallbackWeight: .bold, relativeTo: .headline)
    public static let subheadline = font(named: "Beiruti-Regular", size: 15, fallbackWeight: .regular, relativeTo: .subheadline)
    public static let subheadlineBold = font(named: "Beiruti-Bold", size: 15, fallbackWeight: .bold, relativeTo: .subheadline)
    public static let body = font(named: "Beiruti-Regular", size: 17, fallbackWeight: .regular, relativeTo: .body)
    public static let bodyBold = font(named: "Beiruti-Bold", size: 17, fallbackWeight: .bold, relativeTo: .body)
    public static let callout = font(named: "Beiruti-Regular", size: 16, fallbackWeight: .regular, relativeTo: .callout)
    public static let calloutBold = font(named: "Beiruti-Medium", size: 16, fallbackWeight: .medium, relativeTo: .callout)
    public static let footnote = font(named: "Beiruti-Regular", size: 14, fallbackWeight: .regular, relativeTo: .footnote)
    public static let footnoteBold = font(named: "Beiruti-Bold", size: 14, fallbackWeight: .bold, relativeTo: .footnote)
    public static let caption = font(named: "Beiruti-Regular", size: 12, fallbackWeight: .regular, relativeTo: .caption)
    public static let captionRegular = font(named: "Beiruti-Regular", size: 12, fallbackWeight: .regular, relativeTo: .caption)
    public static let caption1 = font(named: "Beiruti-Regular", size: 12, fallbackWeight: .regular, relativeTo: .caption)
    public static let caption1Bold = font(named: "Beiruti-Bold", size: 12, fallbackWeight: .bold, relativeTo: .caption)
    public static let caption2 = font(named: "Beiruti-Regular", size: 11, fallbackWeight: .regular, relativeTo: .caption2)
    public static let caption2Medium = font(named: "Beiruti-Medium", size: 11, fallbackWeight: .medium, relativeTo: .caption2)
    public static let caption2Bold = font(named: "Beiruti-Bold", size: 11, fallbackWeight: .bold, relativeTo: .caption2)
    public static let captionBold = font(named: "Beiruti-Medium", size: 13, fallbackWeight: .medium, relativeTo: .caption)
}

public typealias AdminFont = AdminType

// MARK: - AdminSpacing (8pt Grid)

public enum AdminSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let base: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let screenMargin: CGFloat = 20
    public static let cardPadding: CGFloat = 16
    public static let sectionSpacing: CGFloat = 24
    public static let groupSpacing: CGFloat = 20
    public static let rowMinimumHeight: CGFloat = 52
    public static let cornerRadiusSmall: CGFloat = AdminRadius.small
    public static let cornerRadiusMedium: CGFloat = AdminRadius.medium
    public static let cornerRadiusLarge: CGFloat = AdminRadius.large
    public static let cornerRadiusCard: CGFloat = AdminRadius.card
}

// MARK: - AdminRadius

public enum AdminRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let card: CGFloat = 16
    public static let large: CGFloat = 20
    public static let hero: CGFloat = 24
    public static let pill: CGFloat = 999
    public static let button: CGFloat = 14
}

// MARK: - AdminTouchTarget

public enum AdminTouchTarget {
    public static let minimum: CGFloat = 44
    public static let comfortable: CGFloat = 48
    public static let inputField: CGFloat = 48
    public static let expanded: CGFloat = 48
}

// MARK: - AdminAnimation

public enum AdminAnimation {
    public static let fast = Animation.easeOut(duration: 0.15)
    public static let standard = Animation.spring(response: 0.3, dampingFraction: 0.75)
    public static let slow = Animation.spring(response: 0.4, dampingFraction: 0.8)
    public static let pressScale: CGFloat = 0.97

    public static let screenEntrance = Animation.spring(response: 0.46, dampingFraction: 0.86)
    public static let rowReveal = Animation.spring(response: 0.34, dampingFraction: 0.84)
    public static let filterSwap = Animation.easeOut(duration: 0.22)
    public static let disclosure = Animation.spring(response: 0.32, dampingFraction: 0.82)
    public static let rowStagger: Double = 0.035
    public static let maxStaggeredRows: Int = 6
    public static let entranceOffset: CGFloat = 10

    public static func motion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    public static func staggerDelay(index: Int, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        return Double(min(index, maxStaggeredRows)) * rowStagger
    }
}

// MARK: - AdminShadow

public enum AdminShadow {
    public static let card: (color: Color, radius: CGFloat, y: CGFloat) = (.black.opacity(0.06), 8, 2)
    public static let elevated: (color: Color, radius: CGFloat, y: CGFloat) = (.black.opacity(0.10), 16, 4)
    public static let navigation: (color: Color, radius: CGFloat, y: CGFloat) = (.black.opacity(0.04), 4, 1)
}

// MARK: - AdminStatusBadge

public struct AdminStatusBadge: View {
    public enum Status { case success, warning, error, info, neutral, processing }
    public let text: String
    public let status: Status

    public init(text: String, status: Status) {
        self.text = text
        self.status = status
    }

    public var color: Color {
        switch status {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        case .neutral: return AdminSurface.secondaryText
        case .processing: return AdminSurface.primary
        }
    }

    public var icon: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "circle.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(AdminType.captionBold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
        .accessibilityLabel(text)
    }
}

// MARK: - AdminRemoteImage

public struct AdminRemoteImage<Placeholder: View>: View {
    public let url: URL?
    public let contentMode: SwiftUI.ContentMode
    public let targetSize: CGSize?
    private let placeholder: Placeholder

    public init(
        url: URL?,
        contentMode: SwiftUI.ContentMode = .fill,
        targetSize: CGSize? = nil,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.targetSize = targetSize
        self.placeholder = placeholder()
    }

    public init(
        urlString: String?,
        contentMode: SwiftUI.ContentMode = .fill,
        targetSize: CGSize? = nil,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        if let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            self.url = URL(string: s)
        } else {
            self.url = nil
        }
        self.contentMode = contentMode
        self.targetSize = targetSize
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }
}

public extension AdminRemoteImage where Placeholder == AnyView {
    init(
        url: URL?,
        contentMode: SwiftUI.ContentMode = .fill,
        targetSize: CGSize? = nil
    ) {
        self.init(url: url, contentMode: contentMode, targetSize: targetSize) {
            AnyView(
                Color(.systemGray6)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(.tertiaryLabel))
                    )
            )
        }
    }

    init(
        urlString: String?,
        contentMode: SwiftUI.ContentMode = .fill,
        targetSize: CGSize? = nil
    ) {
        self.init(urlString: urlString, contentMode: contentMode, targetSize: targetSize) {
            AnyView(
                Color(.systemGray6)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(.tertiaryLabel))
                    )
            )
        }
    }
}

// MARK: - AdminEmptyStateView

public struct AdminEmptyStateView: View {
    public let symbol: String
    public let title: String
    public var subtitle: String?
    public var actionTitle: String?
    public var action: (() -> Void)?

    public init(symbol: String, title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AdminSurface.secondaryText.opacity(0.5))
            Text(title)
                .font(AdminType.headline)
                .foregroundColor(AdminSurface.primaryText)
                .multilineTextAlignment(.center)
            if let sub = subtitle {
                Text(sub)
                    .font(AdminType.subheadline)
                    .foregroundColor(AdminSurface.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let atitle = actionTitle, let act = action {
                Button(action: act) {
                    Text(atitle)
                        .font(AdminType.headline)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AdminSurface.primary)
                .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - AdminCard

public struct AdminCard<Content: View>: View {
    public let content: Content
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AdminSurface.hairline))
    }
}

// MARK: - AdminLoadingOverlay

public struct AdminLoadingOverlay: View {
    public var message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 12) {
                ProgressView().tint(AdminSurface.primary).scaleEffect(1.2)
                if let m = message {
                    Text(m).font(AdminType.callout).foregroundColor(AdminSurface.secondaryText)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - AdminStroke

public enum AdminStroke {
    public static let hairline: CGFloat = 0.5
    public static let thin: CGFloat = 1.0
    public static let medium: CGFloat = 1.5
}

// MARK: - Pure Pets Brand Typography

public enum PPBrandFont {
    public static func registerIfNeeded() {
        _ = _registrationToken
    }

    private static let _registrationToken: Void = {
        let fontNames = ["Beiruti-Bold", "Beiruti-Medium", "Beiruti-Regular"]
        let bundle = Bundle.main
        for name in fontNames {
            let url = bundle.url(forResource: name, withExtension: "ttf")
                ?? bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Resourses")
                ?? bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Resources")
            if let url = url {
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    if let error = error?.takeRetainedValue() {
                        let code = CFErrorGetCode(error)
                        if code != 105 {
                            print("[PPBrandFont] Registration notice for \(name): \(error)")
                        }
                    }
                }
            }
        }
    }()

    public static func bold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        registerIfNeeded()
        return Font.custom("Beiruti-Bold", size: size, relativeTo: textStyle)
    }

    public static func medium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        registerIfNeeded()
        return Font.custom("Beiruti-Medium", size: size, relativeTo: textStyle)
    }

    public static func regular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        registerIfNeeded()
        return Font.custom("Beiruti-Regular", size: size, relativeTo: textStyle)
    }

    public static func bold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        bold(size: size, relativeTo: textStyle)
    }

    public static func semibold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        bold(size: size, relativeTo: textStyle)
    }

    public static func semibold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        bold(size: size, relativeTo: textStyle)
    }

    public static func heavy(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        bold(size: size, relativeTo: textStyle)
    }

    public static func heavy(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        bold(size: size, relativeTo: textStyle)
    }

    public static func medium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        medium(size: size, relativeTo: textStyle)
    }

    public static func regular(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        regular(size: size, relativeTo: textStyle)
    }

    public static func caption(_ size: CGFloat = 12) -> Font {
        regular(size: size, relativeTo: .caption)
    }

    public static func headline(_ size: CGFloat = 16) -> Font {
        bold(size: size, relativeTo: .headline)
    }

    public static func subheadline(_ size: CGFloat = 14) -> Font {
        medium(size: size, relativeTo: .subheadline)
    }

    public static func title(_ size: CGFloat = 20) -> Font {
        bold(size: size, relativeTo: .title)
    }

    public static func uiFontBold(size: CGFloat) -> UIFont {
        registerIfNeeded()
        return UIFont(name: "Beiruti-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }

    public static func uiFontMedium(size: CGFloat) -> UIFont {
        registerIfNeeded()
        return UIFont(name: "Beiruti-Medium", size: size) ?? UIFont.systemFont(ofSize: size, weight: .medium)
    }

    public static func uiFontRegular(size: CGFloat) -> UIFont {
        registerIfNeeded()
        return UIFont(name: "Beiruti-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    }
}

// MARK: - English Digits & Numeric Normalization

extension String {
    public func sanitizedNumericInput(allowsDecimal: Bool = true) -> String {
        let arabicToEnglishMap: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        var result = ""
        var hasDecimalPoint = false
        for ch in self {
            if let mapped = arabicToEnglishMap[ch] {
                result.append(mapped)
            } else if ch >= "0" && ch <= "9" {
                result.append(ch)
            } else if allowsDecimal && (ch == "." || ch == "٫" || ch == "،" || ch == ",") {
                if !hasDecimalPoint {
                    result.append(".")
                    hasDecimalPoint = true
                }
            }
        }
        return result
    }

    public var normalizedEnglishDigits: String {
        sanitizedNumericInput(allowsDecimal: true)
    }

    public func normalizedEnglishDigits(allowsDecimal: Bool) -> String {
        sanitizedNumericInput(allowsDecimal: allowsDecimal)
    }

    public func normalizedEnglishAlphanumeric() -> String {
        let arabicToEnglishMap: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        var result = ""
        for char in self {
            if let mapped = arabicToEnglishMap[char] {
                result.append(mapped)
            } else if char.isASCII && (char.isLetter || char.isNumber || char == "-" || char == "_") {
                result.append(char.uppercased())
            }
        }
        return result
    }
}

extension Int {
    public var englishDigits: String {
        "\(self)".normalizedEnglishDigits(allowsDecimal: false)
    }
}

extension Double {
    public func englishDigits(decimals: Int = 2, trimZeroDecimals: Bool = false) -> String {
        let formatted = String(format: "%.*f", decimals, self)
        let normalized = formatted.normalizedEnglishDigits(allowsDecimal: true)
        if trimZeroDecimals && normalized.hasSuffix(".00") {
            return String(normalized.dropLast(3))
        }
        return normalized
    }
}

extension CGFloat {
    public func englishDigits(decimals: Int = 2, trimZeroDecimals: Bool = false) -> String {
        Double(self).englishDigits(decimals: decimals, trimZeroDecimals: trimZeroDecimals)
    }
}

extension NSNumber {
    public var englishDigits: String {
        stringValue.normalizedEnglishDigits(allowsDecimal: true)
    }
}

public struct PPEnglishAlphanumericInputModifier: ViewModifier {
    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public func body(content: Content) -> some View {
        content
            .keyboardType(.asciiCapable)
            .environment(\.layoutDirection, .leftToRight)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .onChange(of: text) { newValue in
                let normalized = newValue.normalizedEnglishAlphanumeric()
                if normalized != newValue {
                    text = normalized
                }
            }
    }
}

extension View {
    public func englishAlphanumericInput(text: Binding<String>) -> some View {
        modifier(PPEnglishAlphanumericInputModifier(text: text))
    }
}

// MARK: - Camera & Photos Permissions

@MainActor
public enum PPCameraPermissionHelper {
    public static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    public static func requestCameraAccess(
        onAuthorized: @escaping @MainActor () -> Void,
        onDenied: @escaping @MainActor (String) -> Void
    ) {
        guard isCameraAvailable else {
            let msg = Language.get(
                "Inventory_Camera_Unavailable",
                alter: "الكاميرا غير متاحة على هذا الجهاز. اختر صورة من المكتبة."
            )
            onDenied(msg)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onAuthorized()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onAuthorized()
                    } else {
                        let msg = Language.get(
                            "Inventory_CameraPermission_Message",
                            alter: "يحتاج التطبيق إذن الوصول للكاميرا لالتقاط الصور. يمكنك تفعيل الإذن من إعدادات الجهاز."
                        )
                        onDenied(msg)
                    }
                }
            }
        case .denied, .restricted:
            let msg = Language.get(
                "Inventory_CameraPermission_Message",
                alter: "يحتاج التطبيق إذن الوصول للكاميرا لالتقاط الصور. يمكنك تفعيل الإذن من إعدادات الجهاز."
            )
            onDenied(msg)
        @unknown default:
            let msg = Language.get(
                "Inventory_Camera_Unavailable",
                alter: "الكاميرا غير متاحة على هذا الجهاز. اختر صورة من المكتبة."
            )
            onDenied(msg)
        }
    }
}

public struct PPLivePetCameraPicker: UIViewControllerRepresentable {
    public let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onPicked: @escaping (UIImage) -> Void) {
        self.onPicked = onPicked
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PPLivePetCameraPicker

        init(parent: PPLivePetCameraPicker) {
            self.parent = parent
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.dismiss()
                return
            }
            parent.onPicked(image)
            parent.dismiss()
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - PPVariantImagePickerSheet

public struct PPVariantImagePickerSheet: UIViewControllerRepresentable {
    public let maxSelection: Int
    public let onPicked: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(maxSelection: Int, onPicked: @escaping ([UIImage]) -> Void) {
        self.maxSelection = maxSelection
        self.onPicked = onPicked
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelection
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PPVariantImagePickerSheet

        init(_ parent: PPVariantImagePickerSheet) {
            self.parent = parent
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let onPicked = parent.onPicked
            parent.dismiss()
            guard !results.isEmpty else {
                onPicked([])
                return
            }

            final class ImageAccumulator: @unchecked Sendable {
                private let lock = NSLock()
                private var slots: [UIImage?]

                init(count: Int) {
                    self.slots = Array(repeating: nil, count: count)
                }

                func set(image: UIImage, at index: Int) {
                    lock.lock()
                    if index < slots.count {
                        slots[index] = image
                    }
                    lock.unlock()
                }

                var orderedImages: [UIImage] {
                    lock.lock()
                    defer { lock.unlock() }
                    return slots.compactMap { $0 }
                }
            }

            final class AtomicGate: @unchecked Sendable {
                private let lock = NSLock()
                private var opened = false
                func openOnce() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    if opened { return false }
                    opened = true
                    return true
                }
            }

            let accumulator = ImageAccumulator(count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                group.enter()
                let provider = result.itemProvider
                let gate = AtomicGate()

                let finish: @Sendable (UIImage?) -> Void = { img in
                    guard gate.openOnce() else { return }
                    if let img = img {
                        accumulator.set(image: img, at: index)
                    }
                    group.leave()
                }

                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { [finish] object, _ in
                        if let image = object as? UIImage {
                            finish(image)
                        } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { [finish] data, _ in
                                let img = data.flatMap { UIImage(data: $0) }
                                finish(img)
                            }
                        } else {
                            finish(nil)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                    provider.loadDataRepresentation(forTypeIdentifier: "public.image") { [finish] data, _ in
                        let img = data.flatMap { UIImage(data: $0) }
                        finish(img)
                    }
                } else if provider.hasItemConformingToTypeIdentifier("public.item") {
                    provider.loadFileRepresentation(forTypeIdentifier: "public.item") { [finish] url, _ in
                        if let url = url, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                            finish(img)
                        } else {
                            finish(nil)
                        }
                    }
                } else {
                    finish(nil)
                }
            }

            group.notify(queue: .main) {
                onPicked(accumulator.orderedImages)
            }
        }
    }
}

// MARK: - Preview Media

public struct PPLivePetPreviewMedia: Identifiable {
    public enum Source {
        case local(UIImage)
        case remote(URL)
    }

    public let id = UUID()
    public let source: Source

    public init(source: Source) {
        self.source = source
    }
}

public struct PPLivePetMediaPreview: View {
    public let media: PPLivePetPreviewMedia
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var settledScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1

    public init(media: PPLivePetPreviewMedia) {
        self.media = media
    }

    private var displayScale: CGFloat {
        min(4, max(1, settledScale * gestureScale))
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            mediaContent
                .scaledToFit()
                .scaleEffect(displayScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .updating($gestureScale) { current, state, _ in
                            state = current
                        }
                        .onEnded { finalScale in
                            settledScale = min(4, max(1, settledScale * finalScale))
                        }
                )

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(20)
            }
            .accessibilityLabel(Language.get("Close", alter: "إغلاق"))
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch media.source {
        case .local(let image):
            Image(uiImage: image).resizable()
        case .remote(let url):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                case .failure:
                    Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.white.opacity(0.4))
                case .empty:
                    ProgressView().tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Barcode Scanner Button & Camera Scanner

public struct AdminBarcodeScanButton: View {
    public let isCircle: Bool
    public let onScanned: (String) -> Void
    @State private var isShowingScanner = false

    public init(isCircle: Bool = false, onScanned: @escaping (String) -> Void) {
        self.isCircle = isCircle
        self.onScanned = onScanned
    }

    public var body: some View {
        Button {
            isShowingScanner = true
        } label: {
            if isCircle {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AdminSurface.primary)
                    .frame(width: 36, height: 36)
                    .background(AdminSurface.primarySoft, in: Circle())
                    .contentShape(Circle())
            } else {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AdminSurface.primary)
                    .frame(width: 36, height: 36)
                    .background(AdminSurface.primarySoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .accessibilityLabel(Language.get("Scan_Barcode", alter: "مسح الباركود"))
        .sheet(isPresented: $isShowingScanner) {
            PPBarcodeScannerSheet(
                onScanned: { scannedCode in
                    isShowingScanner = false
                    let trimmed = scannedCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onScanned(trimmed)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                },
                onCancel: {
                    isShowingScanner = false
                }
            )
        }
    }
}

public struct PPBarcodeScannerSheet: UIViewControllerRepresentable {
    public let onScanned: (String) -> Void
    public let onCancel: () -> Void

    public init(onScanned: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onScanned = onScanned
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let scanner = PPBarcodeScannerViewController()
        scanner.onScanned = onScanned
        scanner.onCancel = onCancel
        return UINavigationController(rootViewController: scanner)
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class PPBarcodeScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    var onScanned: (@Sendable (String) -> Void)?

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }

        let callback = self.onScanned
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            callback?(stringValue)
        }
    }
}

final class PPBarcodeScannerViewController: UIViewController {
    var onScanned: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let coordinator = PPBarcodeScannerCoordinator()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = Language.get("Scan_Barcode", alter: "مسح الباركود")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: Language.get("Cancel", alter: "إلغاء"),
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        coordinator.onScanned = { [weak self] code in
            self?.captureSession?.stopRunning()
            self?.onScanned?(code)
            self?.dismiss(animated: true)
        }
        setupCamera()
    }

    @objc private func handleCancel() {
        onCancel?()
        dismiss(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            return
        }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [
            .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93, .upce
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}

// MARK: - Sendable Conformance for Legacy Obj-C Models

extension PetAccessory: @unchecked Sendable {}
extension PPProviderMarketItem: @unchecked Sendable {}
extension PPDeliveryOrderModel: @unchecked Sendable, Identifiable {
    public var id: String {
        return self.orderId
    }
}
extension PPDeliveryOrderItem: @unchecked Sendable, Identifiable {
    public var id: String {
        return self.itemID
    }
}
extension PPDeliveryCompanyProfile: @unchecked Sendable {}
extension PPDeliveryCompanyRequest: @unchecked Sendable {}

// MARK: - AdminSquircleBackButton

public struct AdminSquircleBackButton: View {
    public var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AdminSurface.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(uiColor: .ppSurfaceBorder).opacity(0.8), lineWidth: 0.8)
                    )
                Image(
                    systemName: Language.isRTL() ? "arrow.right" : "arrow.left"
                )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AdminSurface.primaryText)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Language.get("Back", alter: "رجوع"))
    }
}
