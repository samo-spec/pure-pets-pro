//
//  PPMarketplaceBranchesView.swift
//  PurePetsPro
//
//  Created by Antigravity on 12/09/2026.
//  First-Principles Category-Defining Marketplace Pickup Network Studio.
//  Tailored separately for iPhone (Mobile Tactile Studio) and iPad (Desktop-Class Dual-Pane Studio).
//

import SwiftUI
import UIKit

// MARK: - Typography & Visual Design System Tokens

public enum PPBeirutiFont {
    public static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    public static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    public static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Tactile Button Style & Shimmer Animation

public struct PPTactileButtonStyle: ButtonStyle {
    public let scaleAmount: CGFloat
    public init(scaleAmount: CGFloat = 0.96) {
        self.scaleAmount = scaleAmount
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

public struct PPShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1.0
    public let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(duration: Double = 1.6) {
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.85)
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        let width = geo.size.width
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: width * 1.5)
                        .offset(x: phase * width * 1.5)
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                        phase = 1.0
                    }
                }
        }
    }
}

public extension View {
    func ppShimmer(duration: Double = 1.6) -> some View {
        modifier(PPShimmerEffect(duration: duration))
    }

    func ppTactile(scale: CGFloat = 0.96) -> some View {
        buttonStyle(PPTactileButtonStyle(scaleAmount: scale))
    }
}

// MARK: - Branch Item View Model

public struct PPMarketplaceBranchItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let nameAr: String
    public let nameEn: String
    public let address: String
    public let phone: String
    public var active: Bool
    public var defaultBranch: Bool

    public init(
        id: String,
        code: String = "",
        nameAr: String = "",
        nameEn: String = "",
        address: String = "",
        phone: String = "",
        active: Bool = true,
        defaultBranch: Bool = false
    ) {
        self.id = id
        self.code = code
        self.nameAr = nameAr
        self.nameEn = nameEn
        self.address = address
        self.phone = phone
        self.active = active
        self.defaultBranch = defaultBranch
    }

    public init(from branch: PPMarketplaceBranch) {
        self.id = branch.branchID ?? UUID().uuidString
        self.code = branch.code ?? ""
        self.nameAr = branch.nameAr ?? ""
        self.nameEn = branch.nameEn ?? ""
        self.address = branch.address ?? ""
        self.phone = branch.phone ?? ""
        self.active = branch.active
        self.defaultBranch = branch.defaultBranch
    }

    public func localizedName() -> String {
        let isRTL = Language.isRTL()
        let primary = isRTL ? nameAr : nameEn
        let secondary = isRTL ? nameEn : nameAr
        if !primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primary
        }
        if !secondary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return secondary
        }
        return code.isEmpty ? id : code
    }

    public func secondaryName() -> String? {
        let isRTL = Language.isRTL()
        let alt = isRTL ? nameEn : nameAr
        let trimmed = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var displayCode: String {
        if !code.isEmpty {
            return code
        }
        let prefix = "HUB"
        let hash = abs(id.hashValue) % 999
        return String(format: "%@-%03d", prefix, hash)
    }
}

// MARK: - Studio View Model

@MainActor
public final class PPMarketplaceBranchesViewModel: ObservableObject {
    @Published public var branches: [PPMarketplaceBranchItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var searchQuery: String = ""
    @Published public var filterMode: Int = 0 // 0: All, 1: Active, 2: Paused, 3: Default
    @Published public var selectedBranchID: String? = nil
    @Published public var selectedInspectedBranchID: String? = nil
    @Published public var showEditorSheet: Bool = false
    @Published public var branchToEdit: PPMarketplaceBranchItem? = nil
    @Published public var isSavingBranch: Bool = false
    @Published public var isTogglingActiveID: String? = nil
    @Published public var isSettingDefaultID: String? = nil
    @Published public var copiedToastAddress: String? = nil

    public let selectionMode: Bool
    public let onDismiss: @Sendable () -> Void
    public let onConfirmSelection: @Sendable (PPMarketplaceBranch) -> Void

    public init(
        selectionMode: Bool = false,
        onDismiss: @escaping @Sendable () -> Void = {},
        onConfirmSelection: @escaping @Sendable (PPMarketplaceBranch) -> Void = { _ in }
    ) {
        self.selectionMode = selectionMode
        self.onDismiss = onDismiss
        self.onConfirmSelection = onConfirmSelection
    }

    // MARK: - Filtered Branches

    public var filteredBranches: [PPMarketplaceBranchItem] {
        var list = branches

        // Filter mode
        switch filterMode {
        case 1:
            list = list.filter { $0.active }
        case 2:
            list = list.filter { !$0.active }
        case 3:
            list = list.filter { $0.defaultBranch }
        default:
            break
        }

        // Search query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.nameAr.lowercased().contains(query) ||
                $0.nameEn.lowercased().contains(query) ||
                $0.address.lowercased().contains(query) ||
                $0.phone.lowercased().contains(query) ||
                $0.code.lowercased().contains(query) ||
                $0.displayCode.lowercased().contains(query)
            }
        }

        // Sort: Default branch first, then active first, then name
        return list.sorted { a, b in
            if a.defaultBranch != b.defaultBranch {
                return a.defaultBranch && !b.defaultBranch
            }
            if a.active != b.active {
                return a.active && !b.active
            }
            return a.localizedName().localizedCaseInsensitiveCompare(b.localizedName()) == .orderedAscending
        }
    }

    public var defaultBranch: PPMarketplaceBranchItem? {
        branches.first { $0.defaultBranch }
    }

    public var activeCount: Int {
        branches.filter { $0.active }.count
    }

    public var pausedCount: Int {
        branches.filter { !$0.active }.count
    }

    public var totalCount: Int {
        branches.count
    }

    public var inspectedBranch: PPMarketplaceBranchItem? {
        if let id = selectedInspectedBranchID {
            return branches.first { $0.id == id }
        }
        return filteredBranches.first ?? branches.first
    }

    public var selectedBranchModel: PPMarketplaceBranch? {
        guard let id = selectedBranchID, let item = branches.first(where: { $0.id == id }) else { return nil }
        let branch = PPMarketplaceBranch()
        branch.branchID = item.id
        branch.code = item.code
        branch.nameAr = item.nameAr
        branch.nameEn = item.nameEn
        branch.address = item.address
        branch.phone = item.phone
        branch.active = item.active
        branch.defaultBranch = item.defaultBranch
        return branch
    }

    // MARK: - Actions

    public func loadBranches() {
        isLoading = true
        errorMessage = nil
        PPProviderMarketplaceManager.shared().listMarketplaceBranches { [weak self] rawBranches, error in
            guard let self = self else { return }
            self.isLoading = false
            if let err = error {
                self.errorMessage = err.localizedDescription
                return
            }
            let loaded = (rawBranches ?? []).map { PPMarketplaceBranchItem(from: $0) }
            self.branches = loaded

            // In selection mode, auto-select default branch if active
            if self.selectionMode && self.selectedBranchID == nil {
                if let def = loaded.first(where: { $0.defaultBranch && $0.active }) {
                    self.selectedBranchID = def.id
                } else if let firstActive = loaded.first(where: { $0.active }) {
                    self.selectedBranchID = firstActive.id
                }
            }

            // In iPad inspection mode, select default or first
            if self.selectedInspectedBranchID == nil || !loaded.contains(where: { $0.id == self.selectedInspectedBranchID }) {
                self.selectedInspectedBranchID = self.defaultBranch?.id ?? loaded.first?.id
            }
        }
    }

    public func toggleBranchActive(_ branch: PPMarketplaceBranchItem) {
        let newStatus = !branch.active
        isTogglingActiveID = branch.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        PPProviderMarketplaceManager.shared().setMarketplaceBranchID(branch.id, active: newStatus) { [weak self] success, _, error in
            guard let self = self else { return }
            self.isTogglingActiveID = nil
            if success {
                if let idx = self.branches.firstIndex(where: { $0.id == branch.id }) {
                    self.branches[idx].active = newStatus
                }
                let statusText = (newStatus ?
                    Language.get("MarketplaceBranches_ActivatedToast", alter: "تم تفعيل الفرع بنجاح") :
                    Language.get("MarketplaceBranches_DeactivatedToast", alter: "تم إيقاف الفرع مؤقتاً")) ?? ""
                PPToast.toast(statusText, style: .success, haptic: true, duration: 1.8)
            } else if let err = error {
                PPToast.toast(err.localizedDescription, style: .error, haptic: true, duration: 2.5)
            }
        }
    }

    public func setBranchAsDefault(_ branch: PPMarketplaceBranchItem) {
        guard !branch.defaultBranch else { return }
        isSettingDefaultID = branch.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        PPProviderMarketplaceManager.shared().saveMarketplaceBranch(
            withID: branch.id,
            nameAr: branch.nameAr,
            nameEn: branch.nameEn,
            address: branch.address,
            phone: branch.phone,
            isDefault: true
        ) { [weak self] success, _, error in
            guard let self = self else { return }
            self.isSettingDefaultID = nil
            if success {
                for i in 0..<self.branches.count {
                    self.branches[i].defaultBranch = (self.branches[i].id == branch.id)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                PPToast.toast(Language.get("MarketplaceBranches_SetDefaultToast", alter: "تم تعيين الفرع الافتراضي") ?? "", style: .success, haptic: true, duration: 1.8)
            } else if let err = error {
                PPToast.toast(err.localizedDescription, style: .error, haptic: true, duration: 2.5)
            }
        }
    }

    public func presentAddBranch() {
        branchToEdit = nil
        showEditorSheet = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func presentAddWithTemplate(nameAr: String, nameEn: String, address: String) {
        branchToEdit = PPMarketplaceBranchItem(
            id: "",
            code: "",
            nameAr: nameAr,
            nameEn: nameEn,
            address: address,
            phone: "+974 ",
            active: true,
            defaultBranch: branches.isEmpty
        )
        showEditorSheet = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public func presentEditBranch(_ branch: PPMarketplaceBranchItem) {
        branchToEdit = branch
        showEditorSheet = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func selectBranchForDispatch(_ branch: PPMarketplaceBranchItem) {
        guard branch.active else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            PPToast.toast(Language.get("MarketplaceBranches_CannotSelectInactive", alter: "هذا الفرع متوقف حالياً ولا يمكن اختياره") ?? "", style: .warning, haptic: true, duration: 2.0)
            return
        }
        selectedBranchID = branch.id
        selectedInspectedBranchID = branch.id
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func confirmCurrentSelection() {
        guard let model = selectedBranchModel else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onConfirmSelection(model)
        onDismiss()
    }

    public func copyAddress(_ address: String) {
        UIPasteboard.general.string = address
        copiedToastAddress = address
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        PPToast.toast(Language.get("MarketplaceBranches_AddressCopied", alter: "تم نسخ عنوان الاستلام") ?? "", style: .success, haptic: true, duration: 1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.copiedToastAddress == address {
                self?.copiedToastAddress = nil
            }
        }
    }
}

// MARK: - Master Container Screen

public struct PPMarketplaceBranchesScreen: View {
    @ObservedObject public var viewModel: PPMarketplaceBranchesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(viewModel: PPMarketplaceBranchesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                PPMarketplaceBranchesIPadView(viewModel: viewModel)
            } else {
                PPMarketplaceBranchesIPhoneView(viewModel: viewModel)
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .background(Color(uiColor: .ppBackground).ignoresSafeArea())
        .onAppear {
            viewModel.loadBranches()
        }
        .sheet(isPresented: $viewModel.showEditorSheet) {
            PPMarketplaceBranchEditorSheet(
                branch: viewModel.branchToEdit,
                onDismiss: {
                    viewModel.showEditorSheet = false
                },
                onSaved: {
                    viewModel.showEditorSheet = false
                    viewModel.loadBranches()
                }
            )
            .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        }
    }
}

// MARK: - Top Navigation Bar (Sovereign Custom Header)

public struct PPMarketplaceBranchesNavBar: View {
    let title: String
    let subtitle: String?
    let activeNodesCount: Int
    let totalNodesCount: Int
    let isSelectionMode: Bool
    let showBack: Bool
    let showAdd: Bool
    let onBack: () -> Void
    let onAdd: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        activeNodesCount: Int = 0,
        totalNodesCount: Int = 0,
        isSelectionMode: Bool = false,
        showBack: Bool = true,
        showAdd: Bool = true,
        onBack: @escaping () -> Void,
        onAdd: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.activeNodesCount = activeNodesCount
        self.totalNodesCount = totalNodesCount
        self.isSelectionMode = isSelectionMode
        self.showBack = showBack
        self.showAdd = showAdd
        self.onBack = onBack
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onBack()
                }) {
                    Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .ppCard))
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        )
                }
                .ppTactile()
                .accessibilityLabel(Language.get("Back", alter: "رجوع"))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(PPBeirutiFont.bold(20, relativeTo: .title3))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .lineLimit(1)

                    if totalNodesCount > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(activeNodesCount > 0 ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text("\(activeNodesCount)")
                                .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill((activeNodesCount > 0 ? Color.green : Color.orange).opacity(0.12))
                        )
                    }
                }

                if let sub = subtitle {
                    Text(sub)
                        .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .lineLimit(1)
                }
            }

            Spacer()

            if showAdd {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAdd()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(Language.get("MarketplaceBranches_Add", alter: "إضافة فرع"))
                            .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(uiColor: .ppPrimary),
                                        Color(uiColor: .ppPrimaryDarker ?? .ppPrimary)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(uiColor: .ppPrimary).opacity(0.32), radius: 8, x: 0, y: 4)
                    )
                }
                .ppTactile()
                .accessibilityLabel(Language.get("MarketplaceBranches_Add", alter: "إضافة فرع"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
    }
}

// MARK: - Dispatch Hub Readiness Hero (Living Logistics Telemetry Radar)

public struct PPDispatchHubHero: View {
    let totalCount: Int
    let activeCount: Int
    let defaultBranchName: String?
    let isSelectionMode: Bool
    @State private var radarPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Branded Animated Radar Beacon
                ZStack {
                    if !reduceMotion && activeCount > 0 {
                        Circle()
                            .stroke(Color(uiColor: .ppPrimary).opacity(radarPulse ? 0.0 : 0.4), lineWidth: 2)
                            .frame(width: radarPulse ? 64 : 44, height: radarPulse ? 64 : 44)
                            .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false), value: radarPulse)
                    }

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(uiColor: .ppPrimary).opacity(0.18),
                                    Color(uiColor: .ppPrimary).opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(uiColor: .ppPrimary).opacity(0.25), lineWidth: 1)
                        )

                    Image(systemName: isSelectionMode ? "shippingbox.fill" : "building.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isSelectionMode ?
                         Language.get("MarketplaceBranches_SelectEyebrow", alter: "نقطة انطلاق الشحنة") :
                         Language.get("MarketplaceBranches_Eyebrow", alter: "مصدر الطرد"))
                        .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .textCase(.uppercase)

                    Text(isSelectionMode ?
                         Language.get("MarketplaceBranches_SelectHero", alter: "أين ينتظر هذا الطرد؟") :
                         Language.get("MarketplaceBranches_Hero", alter: "شبكة نقاط الاستلام"))
                        .font(PPBeirutiFont.bold(21, relativeTo: .title3))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    Text(isSelectionMode ?
                         Language.get("MarketplaceBranches_SelectSubtitle", alter: "يظهر الفرع المحدد وعنوان الاستلام لشركات التوصيل قبل قبول الطلب.") :
                         Language.get("MarketplaceBranches_Subtitle", alter: "أضف مواقع المتاجر التي تستلم منها شركات التوصيل طرود السوق."))
                        .font(PPBeirutiFont.regular(12.5, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .background(Color(uiColor: .ppSeparator).opacity(0.4))

            // Operational Telemetry Pill Strip
            HStack(spacing: 8) {
                // Active Nodes Metric
                HStack(spacing: 6) {
                    Circle()
                        .fill(activeCount > 0 ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(String(format: Language.get("MarketplaceBranches_ActiveNodesFormat", alter: "%d/%d نشطة"), activeCount, totalCount))
                        .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .ppSurface))
                )

                // Default Hub Pill
                if let def = defaultBranchName, !def.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.orange)
                        Text(String(format: Language.get("MarketplaceBranches_DefaultHubFormat", alter: "الرئيسي: %@"), def))
                            .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .ppSurface))
                    )
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .ppCard))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(uiColor: .ppBorder).opacity(0.35), lineWidth: 1)
                )
        )
        .onAppear {
            if !reduceMotion {
                radarPulse = true
            }
        }
    }
}

// MARK: - Tactile Branch Card (Bento Design)

public struct PPMarketplaceBranchCard: View {
    let branch: PPMarketplaceBranchItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let isInspectedOnPad: Bool
    let isToggling: Bool
    let copiedToast: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleActive: () -> Void
    let onSetDefault: () -> Void
    let onCopyAddress: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Medals + Status Pill + More
            HStack(spacing: 8) {
                if isSelectionMode {
                    // Radio indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppBorder), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color(uiColor: .ppPrimary))
                                .frame(width: 12, height: 12)
                        }
                    }
                }

                // Default Hub Badge
                if branch.defaultBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(Language.get("MarketplaceBranches_Default", alter: "الفرع الافتراضي"))
                            .font(PPBeirutiFont.bold(10.5, relativeTo: .caption2))
                    }
                    .foregroundColor(Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.14))
                    )
                }

                // Active / Inactive Status Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(branch.active ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(branch.active ?
                         Language.get("MarketplaceBranches_Active", alter: "نشط") :
                         Language.get("MarketplaceBranches_Paused", alter: "متوقف"))
                        .font(PPBeirutiFont.bold(10.5, relativeTo: .caption2))
                        .foregroundColor(branch.active ? Color.green : Color.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill((branch.active ? Color.green : Color.gray).opacity(0.12))
                )

                // Branch Code Tag
                Text(branch.displayCode)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(uiColor: .ppTextTertiary ?? .ppTextSecondary))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(uiColor: .ppSurface))
                    )

                Spacer()

                // Context Menu / Edit Button
                if !isSelectionMode {
                    Menu {
                        Button(action: onEdit) {
                            Label(Language.get("Edit", alter: "تعديل"), systemImage: "pencil")
                        }

                        Button(action: onToggleActive) {
                            Label(branch.active ?
                                  Language.get("MarketplaceBranches_Deactivate", alter: "تعطيل") :
                                  Language.get("MarketplaceBranches_Activate", alter: "تفعيل"),
                                  systemImage: branch.active ? "pause.circle" : "play.circle")
                        }

                        if !branch.defaultBranch {
                            Button(action: onSetDefault) {
                                Label(Language.get("MarketplaceBranches_SetDefault", alter: "تعيين كافتراضي"), systemImage: "star")
                            }
                        }

                        Button(action: onCopyAddress) {
                            Label(Language.get("Copy", alter: "نسخ العنوان"), systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.75))
                            .frame(width: 32, height: 32)
                    }
                }
            }

            // Title & Localization
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.localizedName())
                    .font(PPBeirutiFont.bold(17, relativeTo: .headline))
                    .foregroundColor(branch.active ? Color(uiColor: .ppTextPrimary) : Color(uiColor: .ppTextSecondary))
                    .lineLimit(1)

                if let secondary = branch.secondaryName() {
                    Text(secondary)
                        .font(PPBeirutiFont.regular(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.85))
                        .lineLimit(1)
                }
            }

            // Address Row (Tap to Copy with micro-interaction)
            Button(action: onCopyAddress) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(uiColor: .ppPrimary))

                    Text(branch.address)
                        .font(PPBeirutiFont.regular(13, relativeTo: .subheadline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: copiedToast ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(copiedToast ? Color.green : Color(uiColor: .ppPrimary))
                        if copiedToast {
                            Text(Language.get("Copy", alter: "تم النسخ"))
                                .font(PPBeirutiFont.bold(10.5, relativeTo: .caption2))
                                .foregroundColor(Color.green)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((copiedToast ? Color.green : Color(uiColor: .ppPrimary)).opacity(0.10))
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .ppSurface))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Footer: Phone number & Quick Status Toggle
            HStack(spacing: 12) {
                if !branch.phone.isEmpty {
                    let cleanedPhone = branch.phone.replacingOccurrences(of: " ", with: "")
                    if let url = URL(string: "tel://\(cleanedPhone)") {
                        Link(destination: url) {
                            HStack(spacing: 5) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 10))
                                Text(branch.phone)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .ppPrimary).opacity(0.08))
                            )
                        }
                    }
                }

                Spacer()

                if !isSelectionMode {
                    Button(action: onToggleActive) {
                        HStack(spacing: 4) {
                            if isToggling {
                                ProgressView()
                                    .scaleEffect(0.65)
                            } else {
                                Image(systemName: branch.active ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10))
                            }
                            Text(branch.active ?
                                 Language.get("MarketplaceBranches_Deactivate", alter: "تعطيل") :
                                 Language.get("MarketplaceBranches_Activate", alter: "تفعيل"))
                                .font(PPBeirutiFont.bold(11.5, relativeTo: .caption))
                        }
                        .foregroundColor(branch.active ? Color.orange : Color(uiColor: .ppPrimary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill((branch.active ? Color.orange : Color(uiColor: .ppPrimary)).opacity(0.10))
                        )
                    }
                    .disabled(isToggling)
                    .ppTactile()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .ppCard))
                .shadow(
                    color: isSelected ? Color(uiColor: .ppPrimary).opacity(0.20) : Color.black.opacity(0.04),
                    radius: isSelected ? 10 : 6,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? Color(uiColor: .ppPrimary) : (isInspectedOnPad ? Color(uiColor: .ppPrimary).opacity(0.45) : Color(uiColor: .ppBorder).opacity(0.35)),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Loading Shimmer Skeleton View

public struct PPMarketplaceBranchesSkeletonView: View {
    public var body: some View {
        VStack(spacing: 14) {
            // Hero Skeleton
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .ppCard))
                .frame(height: 120)
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Circle().fill(Color(uiColor: .ppSurface)).frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .ppSurface)).frame(width: 90, height: 12)
                                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .ppSurface)).frame(width: 160, height: 16)
                            }
                            Spacer()
                        }
                        RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .ppSurface)).frame(maxWidth: .infinity, maxHeight: 12)
                    }
                    .padding(16)
                )
                .ppShimmer()

            // Card Skeletons
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .ppCard))
                    .frame(height: 140)
                    .overlay(
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .ppSurface)).frame(width: 70, height: 18)
                                RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .ppSurface)).frame(width: 50, height: 18)
                                Spacer()
                            }
                            RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: .ppSurface)).frame(width: 140, height: 16)
                            RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .ppSurface)).frame(maxWidth: .infinity, maxHeight: 38)
                        }
                        .padding(14)
                    )
                    .ppShimmer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Category-Defining Empty State View

public struct PPMarketplaceEmptyNetworkView: View {
    let isSelectionMode: Bool
    let onAddAction: () -> Void
    let onSelectTemplate: (String, String, String) -> Void
    @State private var ringsPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 20) {
            // Concentric 3D Logistics Assembly Visual
            ZStack {
                // Outer Pulse Ring
                Circle()
                    .stroke(Color(uiColor: .ppPrimary).opacity(0.08), lineWidth: 1.5)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringsPulse ? 1.05 : 0.95)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: ringsPulse)

                // Middle Ring
                Circle()
                    .fill(Color(uiColor: .ppPrimary).opacity(0.06))
                    .frame(width: 106, height: 106)

                // Inner Core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .ppPrimary).opacity(0.18),
                                Color(uiColor: .ppPrimary).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color(uiColor: .ppPrimary).opacity(0.15), radius: 10, x: 0, y: 5)

                Image(systemName: "shippingbox.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
            }
            .padding(.top, 10)
            .onAppear {
                if !reduceMotion {
                    ringsPulse = true
                }
            }

            // Warm Narrative Text
            VStack(spacing: 6) {
                Text(Language.get("MarketplaceBranches_EmptyTitle", alter: "لا توجد فروع استلام بعد"))
                    .font(PPBeirutiFont.bold(22, relativeTo: .title2))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(Language.get("MarketplaceBranches_EmptySubtitle", alter: "أضف أول موقع متجر قبل إرسال طرد إلى شركة توصيل."))
                    .font(PPBeirutiFont.regular(13.5, relativeTo: .body))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            // 3-Step Visual Micro-Guide
            VStack(alignment: .leading, spacing: 8) {
                guideStepRow(number: "١", title: Language.get("MarketplaceBranches_EmptyGuide_Step1", alter: "أضف موقع الفرع وعنوانه الدقيق"))
                guideStepRow(number: "٢", title: Language.get("MarketplaceBranches_EmptyGuide_Step2", alter: "عيّن الفرع الافتراضي للمتجر"))
                guideStepRow(number: "٣", title: Language.get("MarketplaceBranches_EmptyGuide_Step3", alter: "وجّه مندوب التوصيل للاستلام فوراً"))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .ppSurface))
            )
            .frame(maxWidth: 340)

            // Primary Add Button
            Button(action: onAddAction) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text(Language.get("MarketplaceBranches_Add", alter: "إضافة فرع"))
                        .font(PPBeirutiFont.bold(15, relativeTo: .callout))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 240)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(uiColor: .ppPrimary),
                                    Color(uiColor: .ppPrimaryDarker ?? .ppPrimary)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.38), radius: 10, x: 0, y: 5)
                )
            }
            .ppTactile()

            // Quick Starter Templates for Qatar
            if !isSelectionMode {
                VStack(spacing: 8) {
                    Text(Language.get("MarketplaceBranches_Editor_DistrictChips_Title", alter: "نماذج سريعة للبدء"))
                        .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))

                    HStack(spacing: 8) {
                        Button(action: {
                            onSelectTemplate(
                                "فرع لوسيل الرئيسي",
                                "Lusail Marina Hub",
                                "مارينا بروميناد، برج 14، الدوحة، قطر"
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(Language.get("MarketplaceBranches_Template_Lusail", alter: "فرع لوسيل مارينا"))
                                    .font(PPBeirutiFont.medium(11.5, relativeTo: .caption2))
                            }
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .ppPrimary).opacity(0.08))
                            )
                        }
                        .ppTactile()

                        Button(action: {
                            onSelectTemplate(
                                "مستودع المنطقة الصناعية",
                                "Industrial Logistics Depot",
                                "المنطقة الصناعية، شارع 24، مستودع C-10، قطر"
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(Language.get("MarketplaceBranches_Template_Industrial", alter: "مستودع المنطقة الصناعية"))
                                    .font(PPBeirutiFont.medium(11.5, relativeTo: .caption2))
                            }
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .ppPrimary).opacity(0.08))
                            )
                        }
                        .ppTactile()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func guideStepRow(number: String, title: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(PPBeirutiFont.bold(12, relativeTo: .caption2))
                .foregroundColor(Color(uiColor: .ppPrimary))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(uiColor: .ppPrimary).opacity(0.12)))

            Text(title)
                .font(PPBeirutiFont.medium(12.5, relativeTo: .caption))
                .foregroundColor(Color(uiColor: .ppTextPrimary))

            Spacer()
        }
    }
}

// MARK: - Actionable Error & Recovery State

public struct PPMarketplaceBranchesErrorView: View {
    let message: String
    let onRetry: () -> Void

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.red)
            }

            VStack(spacing: 6) {
                Text(Language.get("MarketplaceBranches_ErrorTitle", alter: "تعذر تحميل فروع الاستلام"))
                    .font(PPBeirutiFont.bold(18, relativeTo: .headline))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))

                Text(message)
                    .font(PPBeirutiFont.regular(13, relativeTo: .caption))
                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(Language.get("MarketplaceBranches_Retry", alter: "إعادة المحاولة"))
                }
                .font(PPBeirutiFont.bold(14, relativeTo: .callout))
                .foregroundColor(Color(uiColor: .ppPrimary))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                )
            }
            .ppTactile()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - iPhone Studio Layout (`PPMarketplaceBranchesIPhoneView`)

public struct PPMarketplaceBranchesIPhoneView: View {
    @ObservedObject public var viewModel: PPMarketplaceBranchesViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Sovereign Top Nav
            PPMarketplaceBranchesNavBar(
                title: viewModel.selectionMode ?
                    Language.get("MarketplaceBranches_SelectTitle", alter: "اختر فرع الاستلام") :
                    Language.get("MarketplaceBranches_Title", alter: "فروع استلام الطرود"),
                subtitle: viewModel.selectionMode ?
                    Language.get("MarketplaceBranches_SelectSubtitleShort", alter: "تحديد نقطة استلام الطرد") :
                    Language.get("MarketplaceBranches_ManageSubtitleShort", alter: "شبكة منافذ الشحن"),
                activeNodesCount: viewModel.activeCount,
                totalNodesCount: viewModel.totalCount,
                isSelectionMode: viewModel.selectionMode,
                showBack: true,
                showAdd: !viewModel.selectionMode,
                onBack: viewModel.onDismiss,
                onAdd: viewModel.presentAddBranch
            )

            ScrollView {
                LazyVStack(spacing: 14) {
                    // Telemetry Hero Radar
                    PPDispatchHubHero(
                        totalCount: viewModel.totalCount,
                        activeCount: viewModel.activeCount,
                        defaultBranchName: viewModel.defaultBranch?.localizedName(),
                        isSelectionMode: viewModel.selectionMode
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // Search & Segmented Filter Bar (When branches exist)
                    if !viewModel.branches.isEmpty {
                        VStack(spacing: 10) {
                            // Search Box
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                                TextField(Language.get("Search", alter: "بحث عن اسم، عنوان، أو كود الفرع..."), text: $viewModel.searchQuery)
                                    .font(PPBeirutiFont.regular(14, relativeTo: .body))

                                if !viewModel.searchQuery.isEmpty {
                                    Button(action: { viewModel.searchQuery = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.3), lineWidth: 1)
                                    )
                            )

                            // Segmented Filter Chips
                            HStack(spacing: 6) {
                                filterChip(title: Language.get("All", alter: "الكل"), count: viewModel.totalCount, tag: 0)
                                filterChip(title: Language.get("MarketplaceBranches_Active", alter: "نشطة"), count: viewModel.activeCount, tag: 1)
                                filterChip(title: Language.get("MarketplaceBranches_Paused", alter: "متوقفة"), count: viewModel.pausedCount, tag: 2)
                                if viewModel.defaultBranch != nil {
                                    filterChip(title: Language.get("MarketplaceBranches_Filter_Default", alter: "الافتراضي"), count: 1, tag: 3)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Content State Management
                    if viewModel.isLoading && viewModel.branches.isEmpty {
                        PPMarketplaceBranchesSkeletonView()
                            .padding(.top, 8)
                    } else if let err = viewModel.errorMessage, viewModel.branches.isEmpty {
                        PPMarketplaceBranchesErrorView(message: err) {
                            viewModel.loadBranches()
                        }
                    } else if viewModel.branches.isEmpty {
                        PPMarketplaceEmptyNetworkView(
                            isSelectionMode: viewModel.selectionMode,
                            onAddAction: viewModel.presentAddBranch,
                            onSelectTemplate: { nameAr, nameEn, address in
                                viewModel.presentAddWithTemplate(nameAr: nameAr, nameEn: nameEn, address: address)
                            }
                        )
                        .padding(.top, 10)
                    } else if viewModel.filteredBranches.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 34, weight: .light))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                            Text(Language.get("NoResults", alter: "لا توجد فروع مطابقة للبحث"))
                                .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(viewModel.filteredBranches) { branch in
                            PPMarketplaceBranchCard(
                                branch: branch,
                                isSelected: viewModel.selectedBranchID == branch.id,
                                isSelectionMode: viewModel.selectionMode,
                                isInspectedOnPad: false,
                                isToggling: viewModel.isTogglingActiveID == branch.id,
                                copiedToast: viewModel.copiedToastAddress == branch.address,
                                onSelect: {
                                    if viewModel.selectionMode {
                                        viewModel.selectBranchForDispatch(branch)
                                    } else {
                                        viewModel.presentEditBranch(branch)
                                    }
                                },
                                onEdit: {
                                    viewModel.presentEditBranch(branch)
                                },
                                onToggleActive: {
                                    viewModel.toggleBranchActive(branch)
                                },
                                onSetDefault: {
                                    viewModel.setBranchAsDefault(branch)
                                },
                                onCopyAddress: {
                                    viewModel.copyAddress(branch.address)
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    // Bottom padding spacer for floating dock
                    Spacer()
                        .frame(height: viewModel.selectionMode ? 105 : 45)
                }
            }
            .refreshable {
                viewModel.loadBranches()
            }

            // Selection Mode Bottom Floating Dock
            if viewModel.selectionMode {
                VStack(spacing: 8) {
                    Button(action: {
                        viewModel.confirmCurrentSelection()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(Language.get("MarketplaceBranches_ConfirmPickup", alter: "استخدام فرع الاستلام المحدد"))
                                .font(PPBeirutiFont.bold(15, relativeTo: .headline))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    viewModel.selectedBranchID != nil ?
                                    LinearGradient(
                                        colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimaryDarker ?? .ppPrimary)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: Color(uiColor: .ppPrimary).opacity(viewModel.selectedBranchID != nil ? 0.35 : 0), radius: 10, x: 0, y: 5)
                        )
                    }
                    .disabled(viewModel.selectedBranchID == nil)
                    .ppTactile()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color(uiColor: .ppCard)
                        .opacity(0.96)
                        .background(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: -4)
                )
            }
        }
    }

    private func filterChip(title: String, count: Int, tag: Int) -> some View {
        Button(action: {
            viewModel.filterMode = tag
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                Text("(\(count))")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.85)
            }
            .foregroundColor(viewModel.filterMode == tag ? Color.white : Color(uiColor: .ppTextSecondary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.filterMode == tag ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurface))
            )
        }
        .ppTactile()
    }
}

// MARK: - iPad Studio Layout (`PPMarketplaceBranchesIPadView`)

public struct PPMarketplaceBranchesIPadView: View {
    @ObservedObject public var viewModel: PPMarketplaceBranchesViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Sovereign Top Bar
            PPMarketplaceBranchesNavBar(
                title: viewModel.selectionMode ?
                    Language.get("MarketplaceBranches_SelectTitle", alter: "اختر فرع الاستلام") :
                    Language.get("MarketplaceBranches_Title", alter: "فروع استلام الطرود"),
                subtitle: Language.get("MarketplaceBranches_IPadSubtitle", alter: "مركز قيادة شبكة الاستلام والتوزيع لشركاء المتجر"),
                activeNodesCount: viewModel.activeCount,
                totalNodesCount: viewModel.totalCount,
                isSelectionMode: viewModel.selectionMode,
                showBack: true,
                showAdd: true,
                onBack: viewModel.onDismiss,
                onAdd: viewModel.presentAddBranch
            )

            // Dual-Pane Desktop-Class Workspace
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left Pane (420pt Sidebar): Pickup Points Directory
                    VStack(spacing: 12) {
                        // Telemetry Hero
                        PPDispatchHubHero(
                            totalCount: viewModel.totalCount,
                            activeCount: viewModel.activeCount,
                            defaultBranchName: viewModel.defaultBranch?.localizedName(),
                            isSelectionMode: viewModel.selectionMode
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Search & Filter
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                                TextField(Language.get("Search", alter: "بحث..."), text: $viewModel.searchQuery)
                                    .font(PPBeirutiFont.regular(13, relativeTo: .body))

                                if !viewModel.searchQuery.isEmpty {
                                    Button(action: { viewModel.searchQuery = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                            )

                            // Quick Filter Chips
                            HStack(spacing: 6) {
                                padFilterChip(title: Language.get("All", alter: "الكل"), count: viewModel.totalCount, tag: 0)
                                padFilterChip(title: Language.get("MarketplaceBranches_Active", alter: "نشطة"), count: viewModel.activeCount, tag: 1)
                                padFilterChip(title: Language.get("MarketplaceBranches_Paused", alter: "متوقفة"), count: viewModel.pausedCount, tag: 2)
                                if viewModel.defaultBranch != nil {
                                    padFilterChip(title: Language.get("MarketplaceBranches_Filter_Default", alter: "الافتراضي"), count: 1, tag: 3)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)

                        // Scrollable List
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                if viewModel.isLoading && viewModel.branches.isEmpty {
                                    PPMarketplaceBranchesSkeletonView()
                                } else if viewModel.branches.isEmpty {
                                    PPMarketplaceEmptyNetworkView(
                                        isSelectionMode: viewModel.selectionMode,
                                        onAddAction: viewModel.presentAddBranch,
                                        onSelectTemplate: { nameAr, nameEn, address in
                                            viewModel.presentAddWithTemplate(nameAr: nameAr, nameEn: nameEn, address: address)
                                        }
                                    )
                                } else {
                                    ForEach(viewModel.filteredBranches) { branch in
                                        PPMarketplaceBranchCard(
                                            branch: branch,
                                            isSelected: viewModel.selectedBranchID == branch.id,
                                            isSelectionMode: viewModel.selectionMode,
                                            isInspectedOnPad: viewModel.selectedInspectedBranchID == branch.id,
                                            isToggling: viewModel.isTogglingActiveID == branch.id,
                                            copiedToast: viewModel.copiedToastAddress == branch.address,
                                            onSelect: {
                                                viewModel.selectedInspectedBranchID = branch.id
                                                if viewModel.selectionMode {
                                                    viewModel.selectBranchForDispatch(branch)
                                                }
                                            },
                                            onEdit: {
                                                viewModel.presentEditBranch(branch)
                                            },
                                            onToggleActive: {
                                                viewModel.toggleBranchActive(branch)
                                            },
                                            onSetDefault: {
                                                viewModel.setBranchAsDefault(branch)
                                            },
                                            onCopyAddress: {
                                                viewModel.copyAddress(branch.address)
                                            }
                                        )
                                        .hoverEffect(.highlight)
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                    .frame(width: max(380, min(440, geometry.size.width * 0.40)))
                    .background(Color(uiColor: .ppBackground))

                    // Hairline Divider
                    Rectangle()
                        .fill(Color(uiColor: .ppSeparator).opacity(0.4))
                        .frame(width: 1)
                        .ignoresSafeArea()

                    // Right Pane: Dispatch Dossier & Live Driver Simulator
                    VStack(spacing: 0) {
                        if let branch = viewModel.inspectedBranch {
                            PPMarketplaceBranchDossierView(
                                branch: branch,
                                isSelectionMode: viewModel.selectionMode,
                                isSelectedForDispatch: viewModel.selectedBranchID == branch.id,
                                isSettingDefault: viewModel.isSettingDefaultID == branch.id,
                                onConfirmDispatch: {
                                    viewModel.selectBranchForDispatch(branch)
                                    viewModel.confirmCurrentSelection()
                                },
                                onEdit: {
                                    viewModel.presentEditBranch(branch)
                                },
                                onToggleActive: {
                                    viewModel.toggleBranchActive(branch)
                                },
                                onSetDefault: {
                                    viewModel.setBranchAsDefault(branch)
                                },
                                onCopyAddress: {
                                    viewModel.copyAddress(branch.address)
                                }
                            )
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "building.2.crop.circle")
                                    .font(.system(size: 56, weight: .light))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                Text(Language.get("MarketplaceBranches_SelectToInspect", alter: "اختر فرعاً من القائمة للاطلاع على تفاصيل شبكة التوصيل"))
                                    .font(PPBeirutiFont.medium(15, relativeTo: .body))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 320)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .ppSurface).opacity(0.45))
                }
            }
        }
        // Hardware keyboard shortcuts for iPad
        .keyboardShortcut("n", modifiers: .command)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in }
    }

    private func padFilterChip(title: String, count: Int, tag: Int) -> some View {
        Button(action: {
            viewModel.filterMode = tag
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                Text("(\(count))")
                    .font(.system(size: 9.5, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundColor(viewModel.filterMode == tag ? Color.white : Color(uiColor: .ppTextSecondary))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(viewModel.filterMode == tag ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurface))
            )
        }
        .hoverEffect(.lift)
    }
}

// MARK: - iPad Live Dispatch Dossier & Driver Simulator

public struct PPMarketplaceBranchDossierView: View {
    let branch: PPMarketplaceBranchItem
    let isSelectionMode: Bool
    let isSelectedForDispatch: Bool
    let isSettingDefault: Bool
    let onConfirmDispatch: () -> Void
    let onEdit: () -> Void
    let onToggleActive: () -> Void
    let onSetDefault: () -> Void
    let onCopyAddress: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Dossier Header Card
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(uiColor: .ppPrimary).opacity(0.18),
                                        Color(uiColor: .ppPrimary).opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 66, height: 66)

                        Image(systemName: "building.2.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if branch.defaultBranch {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(Language.get("MarketplaceBranches_Default", alter: "الفرع الافتراضي"))
                                        .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                }
                                .foregroundColor(Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                            }

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(branch.active ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(branch.active ?
                                     Language.get("MarketplaceBranches_Active", alter: "نشط") :
                                     Language.get("MarketplaceBranches_Paused", alter: "متوقف"))
                                    .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                    .foregroundColor(branch.active ? Color.green : Color.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill((branch.active ? Color.green : Color.gray).opacity(0.14)))

                            Text(branch.displayCode)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }

                        Text(branch.localizedName())
                            .font(PPBeirutiFont.bold(24, relativeTo: .title2))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        if let secondary = branch.secondaryName() {
                            Text(secondary)
                                .font(PPBeirutiFont.medium(14, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    }

                    Spacer()

                    // Quick Actions
                    HStack(spacing: 8) {
                        if !branch.defaultBranch {
                            Button(action: onSetDefault) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star")
                                    Text(Language.get("MarketplaceBranches_SetDefault", alter: "تعيين كافتراضي"))
                                }
                                .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                .foregroundColor(Color.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                            }
                            .hoverEffect(.highlight)
                        }

                        Button(action: onEdit) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                Text(Language.get("Edit", alter: "تعديل"))
                            }
                            .font(PPBeirutiFont.bold(13, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color(uiColor: .ppPrimary).opacity(0.10)))
                        }
                        .hoverEffect(.highlight)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .ppCard))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                )

                // LIVE COURIER DRIVER SIMULATOR (What the delivery driver sees on their device)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(Color(uiColor: .ppPrimary))
                        Text(Language.get("MarketplaceBranches_Editor_LiveSimulatorTitle", alter: "بطاقة السائق المباشرة"))
                            .font(PPBeirutiFont.bold(15, relativeTo: .headline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        Spacer()

                        Text(Language.get("MarketplaceBranches_Editor_VerifiedNode", alter: "نقطة استلام معتمدة"))
                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            .foregroundColor(Color.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                    }

                    // Simulated Phone Preview Frame
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(uiColor: .ppPrimary).opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(uiColor: .ppPrimary))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(branch.localizedName())
                                    .font(PPBeirutiFont.bold(15, relativeTo: .subheadline))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                Text(Language.get("MarketplaceBranches_Editor_EstimatedETA", alter: "زمن استجابة السائق المقدر: 15 دقيقة"))
                                    .font(PPBeirutiFont.medium(11, relativeTo: .caption2))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                            }
                            Spacer()
                        }

                        Divider()
                            .background(Color(uiColor: .ppSeparator).opacity(0.3))

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 13))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(branch.address)
                                .font(PPBeirutiFont.regular(13, relativeTo: .caption))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                            Spacer()
                            Button(action: onCopyAddress) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                            }
                        }

                        if !branch.phone.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.green)
                                Text(branch.phone)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .ppSurface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(uiColor: .ppPrimary).opacity(0.20), lineWidth: 1)
                            )
                    )
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .ppCard))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
                )

                // Courier Handover Specifications Bento
                VStack(alignment: .leading, spacing: 14) {
                    Text(Language.get("MarketplaceBranches_CourierHandoverDetails", alter: "إحداثيات تسليم الطرود للسائقين"))
                        .font(PPBeirutiFont.bold(15, relativeTo: .headline))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                    // Address Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(Language.get("MarketplaceBranches_Address", alter: "عنوان الاستلام الدقيق"))
                                .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                            Spacer()
                            Button(action: onCopyAddress) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text(Language.get("Copy", alter: "نسخ"))
                                }
                                .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            }
                        }

                        Text(branch.address)
                            .font(PPBeirutiFont.regular(14, relativeTo: .body))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .ppSurface))
                    )

                    // Phone Card
                    if !branch.phone.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.circle.fill")
                                    .foregroundColor(Color.green)
                                Text(Language.get("MarketplaceBranches_Phone", alter: "رقم هاتف الفرع"))
                                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                Spacer()
                            }

                            Text(branch.phone)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .ppSurface))
                        )
                    }

                    // Courier Advisory Note
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                        Text(Language.get("MarketplaceBranches_DriverNotice", alter: "سيصل مندوب التوصيل إلى هذا الموقع مباشرة عند قبول مهمة الاستلام. يرجى التأكد من جهوزية الطرود بالرقم المرجعي قبل وصول السائق."))
                            .font(PPBeirutiFont.regular(12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .ppPrimary).opacity(0.06))
                    )
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .ppCard))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
                )

                // Selection Mode Primary Commit Button
                if isSelectionMode {
                    Button(action: onConfirmDispatch) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text(Language.get("MarketplaceBranches_ConfirmPickup", alter: "استخدام فرع الاستلام المحدد"))
                                .font(PPBeirutiFont.bold(16, relativeTo: .headline))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimaryDarker ?? .ppPrimary)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(uiColor: .ppPrimary).opacity(0.35), radius: 12, x: 0, y: 6)
                        )
                    }
                    .disabled(!branch.active)
                    .hoverEffect(.lift)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Branch Role & Qatar District Models

public enum PPMarketplaceBranchRole: String, CaseIterable, Identifiable, Sendable {
    case mainHub = "main"
    case retailStore = "retail"
    case warehouse = "warehouse"
    case express = "express"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .mainHub: return Language.get("MarketplaceBranches_Editor_Role_Main", alter: "مركز رئيسي") ?? "مركز رئيسي"
        case .retailStore: return Language.get("MarketplaceBranches_Editor_Role_Showroom", alter: "معرض ومحل") ?? "معرض ومحل"
        case .warehouse: return Language.get("MarketplaceBranches_Editor_Role_Warehouse", alter: "مستودع تخزين") ?? "مستودع تخزين"
        case .express: return Language.get("MarketplaceBranches_Editor_Role_Express", alter: "تسليم سريع") ?? "تسليم سريع"
        }
    }

    public var roleDescription: String {
        switch self {
        case .mainHub: return Language.get("MarketplaceBranches_Editor_Role_Main_Desc", alter: "استلام مركزي لجميع منتجات المتجر") ?? "استلام مركزي لجميع منتجات المتجر"
        case .retailStore: return Language.get("MarketplaceBranches_Editor_Role_Showroom_Desc", alter: "استلام فوري للعملاء ومندوبي التوصيل") ?? "استلام فوري للعملاء ومندوبي التوصيل"
        case .warehouse: return Language.get("MarketplaceBranches_Editor_Role_Warehouse_Desc", alter: "تجهيز الشحنات الكبيرة وتخزين المخزون") ?? "تجهيز الشحنات الكبيرة وتخزين المخزون"
        case .express: return Language.get("MarketplaceBranches_Editor_Role_Express_Desc", alter: "نقطة شحن فائق السرعة للطلبات العاجلة") ?? "نقطة شحن فائق السرعة للطلبات العاجلة"
        }
    }

    public var icon: String {
        switch self {
        case .mainHub: return "building.2.crop.circle.fill"
        case .retailStore: return "storefront.fill"
        case .warehouse: return "shippingbox.circle.fill"
        case .express: return "bolt.shield.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .mainHub: return Color(uiColor: .ppPrimary)
        case .retailStore: return Color(red: 0.18, green: 0.49, blue: 0.88)
        case .warehouse: return Color(red: 0.38, green: 0.32, blue: 0.68)
        case .express: return Color(red: 0.94, green: 0.52, blue: 0.12)
        }
    }
}

public struct PPMarketplaceDistrictItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameAr: String
    public let nameEn: String

    public var localizedName: String {
        switch id {
        case "lusail": return Language.get("MarketplaceBranches_Editor_District_Lusail", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "pearl": return Language.get("MarketplaceBranches_Editor_District_Pearl", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "alsadd": return Language.get("MarketplaceBranches_Editor_District_AlSadd", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "westbay": return Language.get("MarketplaceBranches_Editor_District_WestBay", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "alrayyan": return Language.get("MarketplaceBranches_Editor_District_AlRayyan", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "industrial": return Language.get("MarketplaceBranches_Editor_District_Industrial", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "alwakrah": return Language.get("MarketplaceBranches_Editor_District_AlWakrah", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        case "oldairport": return Language.get("MarketplaceBranches_Editor_District_OldAirport", alter: Language.isRTL() ? nameAr : nameEn) ?? (Language.isRTL() ? nameAr : nameEn)
        default: return Language.isRTL() ? nameAr : nameEn
        }
    }
}

public let ppQatarDistricts: [PPMarketplaceDistrictItem] = [
    PPMarketplaceDistrictItem(id: "lusail", nameAr: "لوسيل", nameEn: "Lusail"),
    PPMarketplaceDistrictItem(id: "pearl", nameAr: "اللؤلؤة", nameEn: "The Pearl"),
    PPMarketplaceDistrictItem(id: "alsadd", nameAr: "السد", nameEn: "Al Sadd"),
    PPMarketplaceDistrictItem(id: "westbay", nameAr: "الخليج الغربي", nameEn: "West Bay"),
    PPMarketplaceDistrictItem(id: "alrayyan", nameAr: "الريان", nameEn: "Al Rayyan"),
    PPMarketplaceDistrictItem(id: "industrial", nameAr: "المنطقة الصناعية", nameEn: "Industrial Area"),
    PPMarketplaceDistrictItem(id: "alwakrah", nameAr: "الوكرة", nameEn: "Al Wakrah"),
    PPMarketplaceDistrictItem(id: "oldairport", nameAr: "المطار القديم", nameEn: "Old Airport")
]

// MARK: - Dashed Line Shape

private struct PPDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Live Simulated Courier Handover Card (`PPCourierWaybillSimulatorCard`)

public struct PPCourierWaybillSimulatorCard: View {
    public let nameAr: String
    public let nameEn: String
    public let address: String
    public let phone: String
    public let isDefault: Bool
    public let selectedRole: PPMarketplaceBranchRole?
    public let isCompact: Bool

    @State private var pulseBeacon: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 0) {
            // Upper Pass: Logistics Identity & Clearance Header
            VStack(alignment: .leading, spacing: 14) {
                // Fleet Clearance Header
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("🇶🇦")
                            .font(.system(size: 13))
                        Text(Language.get("MarketplaceBranches_Editor_WaybillNetwork", alter: "منظومة بيور بيتس اللوجستية") ?? "منظومة بيور بيتس اللوجستية")
                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .ppPrimary).opacity(0.10))
                    )

                    Spacer()

                    // Live Pulsing Beacon
                    HStack(spacing: 6) {
                        ZStack {
                            if !reduceMotion {
                                Circle()
                                    .fill(Color.green.opacity(0.35))
                                    .frame(width: 14, height: 14)
                                    .scaleEffect(pulseBeacon ? 1.6 : 0.8)
                                    .opacity(pulseBeacon ? 0.0 : 0.8)
                                    .animation(
                                        Animation.easeOut(duration: 1.6).repeatForever(autoreverses: false),
                                        value: pulseBeacon
                                    )
                            }

                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }

                        Text(Language.get("MarketplaceBranches_Editor_VerifiedNode", alter: "نقطة معتمدة") ?? "نقطة معتمدة")
                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.10))
                    )
                }
                .onAppear {
                    if !reduceMotion {
                        pulseBeacon = true
                    }
                }

                // Branch Hero Identity & Role Pill
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        let primaryText = Language.isRTL() ?
                            (!nameAr.isEmpty ? nameAr : (!nameEn.isEmpty ? nameEn : "")) :
                            (!nameEn.isEmpty ? nameEn : (!nameAr.isEmpty ? nameAr : ""))

                        VStack(alignment: .leading, spacing: 3) {
                            if primaryText.isEmpty {
                                Text(Language.get("MarketplaceBranches_Editor_PlaceholderLiveHub", alter: "اسم الفرع يظهر هنا مباشرة...") ?? "اسم الفرع يظهر هنا مباشرة...")
                                    .font(PPBeirutiFont.bold(isCompact ? 17 : 20, relativeTo: .headline))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.65))
                                    .italic()
                                    .multilineTextAlignment(.leading)
                            } else {
                                Text(primaryText)
                                    .font(PPBeirutiFont.bold(isCompact ? 19 : 22, relativeTo: .title3))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            // Secondary Transliteration Ribbon
                            let secondaryText = Language.isRTL() ? nameEn : nameAr
                            if !secondaryText.isEmpty {
                                HStack(spacing: 4) {
                                    Text(Language.isRTL() ? "[EN]" : "[عربي]")
                                        .font(PPBeirutiFont.bold(9, relativeTo: .caption2))
                                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    Text(secondaryText)
                                        .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }

                        Spacer()

                        // Active Role Pill
                        if let role = selectedRole {
                            HStack(spacing: 5) {
                                Image(systemName: role.icon)
                                    .font(.system(size: 11))
                                Text(role.title)
                                    .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(role.tintColor.opacity(0.14))
                            )
                            .foregroundColor(role.tintColor)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // Default Dispatch Hub Badge
                if isDefault {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(Language.get("MarketplaceBranches_DefaultLabel", alter: "استخدامه كفرع الاستلام الافتراضي") ?? "استخدامه كفرع الاستلام الافتراضي")
                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(18)

            // Perforated Ticket Notches & Dashed Boundary Line
            HStack(spacing: 0) {
                // Leading Semicircular Notch Cutout
                Circle()
                    .fill(Color(uiColor: .ppBackground))
                    .frame(width: 18, height: 18)
                    .offset(x: Language.isRTL() ? 9 : -9)

                // Dashed Waybill Tear Line
                PPDashedLine()
                    .stroke(Color(uiColor: .ppBorder).opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .frame(height: 1)

                // Trailing Semicircular Notch Cutout
                Circle()
                    .fill(Color(uiColor: .ppBackground))
                    .frame(width: 18, height: 18)
                    .offset(x: Language.isRTL() ? -9 : 9)
            }
            .frame(height: 18)
            .clipped()

            // Lower Pass: Courier Routing Coordinates & Gate Hotline
            VStack(alignment: .leading, spacing: 14) {
                // Precise Pickup Address Node
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .ppPrimary).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.get("MarketplaceBranches_Address", alter: "عنوان الاستلام الدقيق") ?? "عنوان الاستلام الدقيق")
                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                            .multilineTextAlignment(.leading)

                        if address.isEmpty {
                            Text(Language.get("MarketplaceBranches_Editor_PlaceholderLiveAddress", alter: "أدخل عنوان الاستلام الدقيق ليظهر على خريطة المندوب...") ?? "أدخل عنوان الاستلام الدقيق ليظهر على خريطة المندوب...")
                                .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.65))
                                .multilineTextAlignment(.leading)
                        } else {
                            Text(address)
                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .ppSurface))
                )

                // Driver Handover & Barcode Stub
                HStack(alignment: .center, spacing: 12) {
                    // Direct Hotline Pill
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(uiColor: .ppPrimary))
                        Text(phone.isEmpty ? "+974 -- --- ---" : (phone.hasPrefix("+") ? phone : "+974 \(phone)"))
                            .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .ppSurface))
                    )

                    Spacer()

                    // Simulated Logistics 1D Handover Barcode
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            ForEach(0..<20, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color(uiColor: .ppTextPrimary).opacity(i % 3 == 0 ? 0.8 : (i % 2 == 0 ? 0.5 : 0.25)))
                                    .frame(width: (i % 4 == 0 ? 2.5 : (i % 2 == 0 ? 1.5 : 1)), height: 16)
                            }
                        }

                        Text("#QA-DISPATCH-74")
                            .font(PPBeirutiFont.bold(8, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary).opacity(0.75))
                    }
                }

                // Estimated Driver SLA Banner
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                    Text(Language.get("MarketplaceBranches_Editor_EstimatedETA", alter: "زمن استجابة السائق المقدر: 15 دقيقة") ?? "زمن استجابة السائق المقدر: 15 دقيقة")
                        .font(PPBeirutiFont.medium(10.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .ppCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(uiColor: .ppPrimary).opacity(0.28),
                                    Color(uiColor: .ppBorder).opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Language.get("MarketplaceBranches_Editor_WaybillNetwork", alter: "منظومة بيور بيتس اللوجستية") ?? ""): \(nameAr.isEmpty ? nameEn : nameAr)")
    }
}

// MARK: - Sovereign Studio Navigation Bar (`PPMarketplaceBranchEditorNavBar`)

public struct PPMarketplaceBranchEditorNavBar: View {
    public let isEditing: Bool
    public let isValid: Bool
    public let isSubmitting: Bool
    public let onDismiss: () -> Void
    public let onSave: () -> Void

    public var body: some View {
        VStack(spacing: 8) {
            // Modal Sheet Grabber Capsule
            Capsule()
                .fill(Color(uiColor: .ppBorder).opacity(0.8))
                .frame(width: 36, height: 4)
                .padding(.top, 6)

            HStack(spacing: 12) {
                // Leading Circular Dismiss Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .ppSurface))
                                .overlay(
                                    Circle()
                                        .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                )
                        )
                }
                .accessibilityLabel(Language.get("Cancel", alter: "إلغاء") ?? "إلغاء")

                // Center Title & Live Telemetry Pill
                VStack(alignment: .center, spacing: 3) {
                    Text(Language.get("MarketplaceBranches_EditorEyebrow", alter: "موقع تسليم الطرود") ?? "موقع تسليم الطرود")
                        .font(PPBeirutiFont.bold(10.5, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .textCase(.uppercase)

                    HStack(spacing: 6) {
                        Text(isEditing ?
                             (Language.get("MarketplaceBranches_Edit", alter: "تعديل الفرع") ?? "تعديل الفرع") :
                             (Language.get("MarketplaceBranches_Add", alter: "إضافة فرع") ?? "إضافة فرع"))
                            .font(PPBeirutiFont.bold(16, relativeTo: .headline))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        // Compact Validation Telemetry Pill
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isValid ? Color.green : Color.orange)
                                .frame(width: 5, height: 5)
                            Text(isValid ?
                                 (Language.get("MarketplaceBranches_Editor_ReadyTelemetry", alter: "جاهز") ?? "جاهز") :
                                 (Language.get("MarketplaceBranches_Editor_MissingTelemetry", alter: "مطلوب") ?? "مطلوب"))
                                .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                .foregroundColor(isValid ? .green : .orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill((isValid ? Color.green : Color.orange).opacity(0.12))
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                // Trailing Save Button
                Button(action: {
                    if isValid && !isSubmitting {
                        onSave()
                    }
                }) {
                    if isSubmitting {
                        ProgressView()
                            .tint(Color(uiColor: .ppPrimary))
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isValid ? .white : Color(uiColor: .ppTextSecondary))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(
                                        isValid ?
                                        LinearGradient(
                                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(colors: [Color(uiColor: .ppSurface), Color(uiColor: .ppSurface)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.35), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color(uiColor: .ppPrimary).opacity(isValid ? 0.35 : 0), radius: 6, x: 0, y: 3)
                    }
                }
                .disabled(!isValid || isSubmitting)
                .accessibilityLabel(Language.get("Save", alter: "حفظ") ?? "حفظ")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
    }
}

// MARK: - iPhone Branch Editor View (`PPMarketplaceBranchEditorIPhoneView`)

public struct PPMarketplaceBranchEditorIPhoneView: View {
    public let originalBranch: PPMarketplaceBranchItem?
    @Binding public var nameAr: String
    @Binding public var nameEn: String
    @Binding public var address: String
    @Binding public var phone: String
    @Binding public var isDefault: Bool
    @Binding public var selectedRole: PPMarketplaceBranchRole?
    @Binding public var isSubmitting: Bool
    @Binding public var errorMessage: String?
    public let isValid: Bool
    public let onDismiss: () -> Void
    public let onSave: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Sovereign Navigation Bar
            PPMarketplaceBranchEditorNavBar(
                isEditing: originalBranch != nil,
                isValid: isValid,
                isSubmitting: isSubmitting,
                onDismiss: onDismiss,
                onSave: onSave
            )

            // Scrollable Bento Form Canvas
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Hero Anchor: Live Simulated Courier Handover Pass
                    PPCourierWaybillSimulatorCard(
                        nameAr: nameAr,
                        nameEn: nameEn,
                        address: address,
                        phone: phone,
                        isDefault: isDefault,
                        selectedRole: selectedRole,
                        isCompact: true
                    )
                    .padding(.top, 4)

                    // Error Notification Banner
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(PPBeirutiFont.medium(13, relativeTo: .subheadline))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.10))
                        )
                    }

                    // Bento Card 1: Operational Role Selector Matrix (2x2 Grid)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(Language.get("MarketplaceBranches_Editor_RoleChips_Title", alter: "نوع الفرع والنشاط اللوجستي") ?? "نوع الفرع والنشاط اللوجستي")
                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                        }

                        // 2x2 Structured Role Tiles
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(PPMarketplaceBranchRole.allCases) { role in
                                let isSelected = selectedRole == role
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedRole = isSelected ? nil : role
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: role.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(isSelected ? .white : role.tintColor)
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    Circle()
                                                        .fill(isSelected ? Color.white.opacity(0.22) : role.tintColor.opacity(0.12))
                                                )

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }

                                        Text(role.title)
                                            .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                            .foregroundColor(isSelected ? .white : Color(uiColor: .ppTextPrimary))
                                            .multilineTextAlignment(.leading)

                                        Text(role.roleDescription)
                                            .font(PPBeirutiFont.medium(10.5, relativeTo: .caption2))
                                            .foregroundColor(isSelected ? Color.white.opacity(0.85) : Color(uiColor: .ppTextSecondary))
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(
                                                isSelected ?
                                                LinearGradient(
                                                    colors: [role.tintColor, role.tintColor.opacity(0.88)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ) :
                                                LinearGradient(
                                                    colors: [Color(uiColor: .ppSurface), Color(uiColor: .ppSurface)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(
                                                        isSelected ? role.tintColor : Color(uiColor: .ppBorder).opacity(0.5),
                                                        lineWidth: isSelected ? 1.5 : 1
                                                    )
                                            )
                                    )
                                    .shadow(color: isSelected ? role.tintColor.opacity(0.25) : Color.clear, radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(uiColor: .ppCard))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )

                    // Bento Card 2: Bilingual Store Identity (Arabic & English)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "character.book.closed.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(Language.get("MarketplaceBranches_EditorTitle", alter: "هوية الفرع والاسم التجاري") ?? "هوية الفرع والاسم التجاري")
                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                        }

                        // Arabic Name Field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(Language.get("MarketplaceBranches_NameAr", alter: "اسم الفرع بالعربية") ?? "اسم الفرع بالعربية")
                                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                                Spacer()

                                Text("[عربي]")
                                    .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                    .foregroundColor(Color(uiColor: .ppPrimary))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .ppPrimary).opacity(0.10))
                                    )
                            }

                            HStack(spacing: 8) {
                                TextField(Language.get("MarketplaceBranches_PlaceholderNameAr", alter: "مثال: فرع لوسيل الرئيسي") ?? "مثال: فرع لوسيل الرئيسي", text: $nameAr)
                                    .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .multilineTextAlignment(.leading)

                                if !nameAr.isEmpty {
                                    Button(action: {
                                        nameAr = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    }
                                    .accessibilityLabel(Language.get("MarketplaceBranches_Editor_ClearField", alter: "مسح الحقل") ?? "مسح الحقل")
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }

                        // English Name Field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(Language.get("MarketplaceBranches_NameEn", alter: "اسم الفرع بالإنجليزية") ?? "اسم الفرع بالإنجليزية")
                                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))

                                Spacer()

                                Text("[EN]")
                                    .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .ppSurface))
                                    )
                            }

                            HStack(spacing: 8) {
                                TextField(Language.get("MarketplaceBranches_PlaceholderNameEn", alter: "e.g. Lusail Marina Hub") ?? "e.g. Lusail Marina Hub", text: $nameEn)
                                    .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    .environment(\.layoutDirection, .leftToRight)
                                    .multilineTextAlignment(.leading)

                                if !nameEn.isEmpty {
                                    Button(action: {
                                        nameEn = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    }
                                    .accessibilityLabel(Language.get("MarketplaceBranches_Editor_ClearField", alter: "مسح الحقل") ?? "مسح الحقل")
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(uiColor: .ppCard))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )

                    // Bento Card 3: Dispatch Address & Qatar Districts Matrix
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(Language.get("MarketplaceBranches_Address", alter: "عنوان الاستلام الدقيق") ?? "عنوان الاستلام الدقيق")
                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                        }

                        // Detailed Address Input
                        HStack(spacing: 8) {
                            TextField(Language.get("MarketplaceBranches_PlaceholderAddress", alter: "الشارع، المنطقة، رقم المبنى أو علامة مميزة") ?? "الشارع، المنطقة، رقم المبنى أو علامة مميزة", text: $address)
                                .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                .multilineTextAlignment(.leading)

                            if !address.isEmpty {
                                Button(action: {
                                    address = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                                }
                                .accessibilityLabel(Language.get("MarketplaceBranches_Editor_ClearField", alter: "مسح الحقل") ?? "مسح الحقل")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .ppSurface))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                )
                        )

                        // Qatar District Selector Matrix (4x2 Responsive Grid)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Language.get("MarketplaceBranches_Editor_DistrictChips_Title", alter: "المناطق الشائعة في قطر (اضغط للإضافة):") ?? "المناطق الشائعة في قطر (اضغط للإضافة):")
                                .font(PPBeirutiFont.medium(11, relativeTo: .caption))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                                .multilineTextAlignment(.leading)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 7)], spacing: 7) {
                                ForEach(ppQatarDistricts) { district in
                                    let districtName = district.localizedName
                                    let isIncluded = address.contains(districtName)

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        if isIncluded {
                                            // Remove cleanly
                                            let cleaned = address
                                                .replacingOccurrences(of: " - \(districtName)", with: "")
                                                .replacingOccurrences(of: "\(districtName) - ", with: "")
                                                .replacingOccurrences(of: districtName, with: "")
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                            address = cleaned
                                        } else {
                                            // Append
                                            if address.isEmpty {
                                                address = districtName
                                            } else {
                                                address = "\(address) - \(districtName)"
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if isIncluded {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            Text(districtName)
                                                .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            Capsule()
                                                .fill(isIncluded ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurface))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(
                                                            isIncluded ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppBorder).opacity(0.45),
                                                            lineWidth: 1
                                                        )
                                                )
                                        )
                                        .foregroundColor(isIncluded ? .white : Color(uiColor: .ppTextPrimary))
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(uiColor: .ppCard))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )

                    // Bento Card 4: Driver Liaison Hotline & Gate Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .ppPrimary))
                            Text(Language.get("MarketplaceBranches_Phone", alter: "رقم هاتف الفرع المباشر") ?? "رقم هاتف الفرع المباشر")
                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextPrimary))

                            Spacer()

                            // Digit Counter Badge
                            let digitCount = phone.filter(\.isNumber).count
                            HStack(spacing: 3) {
                                if digitCount >= 8 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                }
                                Text(String(format: Language.get("MarketplaceBranches_Editor_DigitCount_Format", alter: "%d من ٨ أرقام") ?? "%d من ٨ أرقام", digitCount))
                                    .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                    .foregroundColor(digitCount >= 8 ? .green : Color(uiColor: .ppTextSecondary))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(digitCount >= 8 ? Color.green.opacity(0.12) : Color(uiColor: .ppSurface))
                            )
                        }

                        // Phone Input Row with Qatar Prefix
                        HStack(spacing: 8) {
                            HStack(spacing: 5) {
                                Text("🇶🇦")
                                    .font(.system(size: 13))
                                Text("+974")
                                    .font(PPBeirutiFont.bold(13, relativeTo: .callout))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                    )
                            )

                            HStack(spacing: 6) {
                                TextField(Language.get("MarketplaceBranches_PlaceholderPhone", alter: "0000 0000") ?? "0000 0000", text: $phone)
                                    .keyboardType(.phonePad)
                                    .font(PPBeirutiFont.bold(15, relativeTo: .body))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    .multilineTextAlignment(.leading)
                                    .environment(\.layoutDirection, .leftToRight)

                                if !phone.isEmpty {
                                    Button(action: {
                                        phone = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .ppSurface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }

                        Text(Language.get("MarketplaceBranches_Editor_PhoneHint", alter: "هاتف مباشر للتنسيق السريع عند وصول السائق لبوابة الاستلام") ?? "هاتف مباشر للتنسيق السريع عند وصول السائق لبوابة الاستلام")
                            .font(PPBeirutiFont.medium(11, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(uiColor: .ppCard))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )

                    // Bento Card 5: Default Dispatch Hub Toggle
                    Toggle(isOn: $isDefault) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.yellow)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(Language.get("MarketplaceBranches_DefaultLabel", alter: "استخدامه كفرع الاستلام الافتراضي") ?? "استخدامه كفرع الاستلام الافتراضي")
                                    .font(PPBeirutiFont.bold(14, relativeTo: .subheadline))
                                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    .multilineTextAlignment(.leading)

                                Text(Language.get("MarketplaceBranches_DefaultSubLabel", alter: "يتم اختياره تلقائياً عند طلب تسليم الطلبات الجديدة") ?? "يتم اختياره تلقائياً عند طلب تسليم الطلبات الجديدة")
                                    .font(PPBeirutiFont.medium(11, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color(uiColor: .ppPrimary)))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(uiColor: .ppCard))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )

                    Spacer()
                        .frame(height: 80)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }

            // Pinned Floating Dynamic Commit Dock
            VStack(spacing: 10) {
                Divider()

                HStack(spacing: 14) {
                    // Visual Readiness Check Ring
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 3)
                                .frame(width: 28, height: 28)

                            Circle()
                                .trim(from: 0, to: isValid ? 1.0 : 0.45)
                                .stroke(isValid ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValid)

                            Image(systemName: isValid ? "checkmark" : "pencil")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isValid ? .green : .orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isValid ?
                                 (Language.get("MarketplaceBranches_Editor_ReadyTelemetry", alter: "جاهز للاعتماد") ?? "جاهز للاعتماد") :
                                 (Language.get("MarketplaceBranches_Editor_MissingTelemetry", alter: "حقول مطلوبة") ?? "حقول مطلوبة"))
                                .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                .foregroundColor(isValid ? .green : .orange)
                                .multilineTextAlignment(.leading)

                            Text(isValid ?
                                 (Language.get("MarketplaceBranches_Saved", alter: "بيانات الاستلام مكتملة") ?? "بيانات الاستلام مكتملة") :
                                 (Language.get("MarketplaceBranches_Required", alter: "أضف اسم الفرع وعنوان الاستلام") ?? "أضف اسم الفرع وعنوان الاستلام"))
                                .font(PPBeirutiFont.medium(9.5, relativeTo: .caption2))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer()

                    // Primary Save Button
                    Button(action: {
                        if isValid && !isSubmitting {
                            onSave()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(Language.get("Save", alter: "حفظ الفرع") ?? "حفظ الفرع")
                                .font(PPBeirutiFont.bold(15, relativeTo: .headline))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isValid ?
                                    LinearGradient(
                                        colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimary).opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(colors: [Color.gray.opacity(0.65), Color.gray.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: Color(uiColor: .ppPrimary).opacity(isValid ? 0.35 : 0), radius: 10, x: 0, y: 5)
                        )
                    }
                    .disabled(!isValid || isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(
                Color(uiColor: .ppBackground).opacity(0.96)
                    .background(.ultraThinMaterial)
            )
        }
        .background(Color(uiColor: .ppBackground).ignoresSafeArea())
    }
}

// MARK: - iPad Dual-Pane Dispatch Studio (`PPMarketplaceBranchEditorIPadView`)

public struct PPMarketplaceBranchEditorIPadView: View {
    public let originalBranch: PPMarketplaceBranchItem?
    @Binding public var nameAr: String
    @Binding public var nameEn: String
    @Binding public var address: String
    @Binding public var phone: String
    @Binding public var isDefault: Bool
    @Binding public var selectedRole: PPMarketplaceBranchRole?
    @Binding public var isSubmitting: Bool
    @Binding public var errorMessage: String?
    public let isValid: Bool
    public let onDismiss: () -> Void
    public let onSave: () -> Void

    @State private var previewMode: Int = 0 // 0: Driver HUD, 1: Logistics Waybill

    private var readinessProgress: Double {
        var score: Double = 0.0
        if !nameAr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.3 }
        if !nameEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.2 }
        if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.3 }
        if !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.2 }
        return min(score, 1.0)
    }

    public var body: some View {
        GeometryReader { geo in
            if geo.size.width < 680 {
                // Adaptive Fallback for Compact iPad (Slide Over or 1/3 Split View)
                PPMarketplaceBranchEditorIPhoneView(
                    originalBranch: originalBranch,
                    nameAr: $nameAr,
                    nameEn: $nameEn,
                    address: $address,
                    phone: $phone,
                    isDefault: $isDefault,
                    selectedRole: $selectedRole,
                    isSubmitting: $isSubmitting,
                    errorMessage: $errorMessage,
                    isValid: isValid,
                    onDismiss: onDismiss,
                    onSave: onSave
                )
            } else {
                // Full Desktop-Class Dual-Pane Studio
                VStack(spacing: 0) {
                    // iPad Top Studio Navigation & Shortcut Bar
                    HStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color(uiColor: .ppPrimary))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(Language.get("MarketplaceBranches_Editor_IPadNavTitle", alter: "استوديو فروع الاستلام والتسليم") ?? "استوديو فروع الاستلام والتسليم")
                                        .font(PPBeirutiFont.bold(19, relativeTo: .title3))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                                    // Readiness Pill
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(isValid ? Color.green : Color.orange)
                                            .frame(width: 7, height: 7)
                                        Text("\(Int(readinessProgress * 100))% \(isValid ? (Language.get("MarketplaceBranches_Editor_ReadyTelemetry", alter: "جاهز للاعتماد") ?? "جاهز للاعتماد") : (Language.get("MarketplaceBranches_Editor_MissingTelemetry", alter: "حقول مطلوبة") ?? "حقول مطلوبة"))")
                                            .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                                            .foregroundColor(isValid ? .green : .orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill((isValid ? Color.green : Color.orange).opacity(0.12))
                                    )
                                }

                                Text(Language.get("MarketplaceBranches_Editor_IPadNavSubtitle", alter: "تهيئة بيانات استلام الطرود والتكامل المباشر مع أسطول التوصيل") ?? "تهيئة بيانات استلام الطرود والتكامل المباشر مع أسطول التوصيل")
                                    .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer()

                        // Action Shortcuts Bar (⌘S & Esc)
                        HStack(spacing: 10) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDismiss()
                            }) {
                                Text(Language.get("MarketplaceBranches_Editor_CancelShortcut", alter: "إلغاء (Esc)") ?? "إلغاء (Esc)")
                                    .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(uiColor: .ppSurface))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                            )
                                    )
                            }
                            .keyboardShortcut(.escape, modifiers: [])

                            Button(action: {
                                if isValid && !isSubmitting {
                                    onSave()
                                }
                            }) {
                                HStack(spacing: 7) {
                                    if isSubmitting {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    Text(Language.get("MarketplaceBranches_Editor_SaveShortcut", alter: "حفظ الفرع (⌘S)") ?? "حفظ الفرع (⌘S)")
                                        .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isValid ? Color(uiColor: .ppPrimary) : Color.gray.opacity(0.65))
                                        .shadow(color: Color(uiColor: .ppPrimary).opacity(isValid ? 0.35 : 0), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(!isValid || isSubmitting)
                            .keyboardShortcut("s", modifiers: .command)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Color(uiColor: .ppBackground).opacity(0.96)
                            .background(.ultraThinMaterial)
                    )

                    Divider()

                    // Dual-Pane Workspace Canvas
                    HStack(alignment: .top, spacing: 24) {
                        // Left Pane: Logistics Configuration Form (~52%)
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                if let err = errorMessage {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(err)
                                            .font(PPBeirutiFont.medium(13, relativeTo: .subheadline))
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.red.opacity(0.10))
                                    )
                                }

                                // Role Matrix Section
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.grid.2x2.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppPrimary))
                                        Text(Language.get("MarketplaceBranches_Editor_RoleChips_Title", alter: "نوع الفرع والنشاط اللوجستي") ?? "نوع الفرع والنشاط اللوجستي")
                                            .font(PPBeirutiFont.bold(14, relativeTo: .headline))
                                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    }

                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                        ForEach(PPMarketplaceBranchRole.allCases) { role in
                                            let isSelected = selectedRole == role
                                            Button(action: {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                    selectedRole = isSelected ? nil : role
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Image(systemName: role.icon)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(isSelected ? .white : role.tintColor)
                                                            .frame(width: 28, height: 28)
                                                            .background(
                                                                Circle()
                                                                    .fill(isSelected ? Color.white.opacity(0.22) : role.tintColor.opacity(0.12))
                                                            )

                                                        Spacer()

                                                        if isSelected {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }

                                                    Text(role.title)
                                                        .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                                        .foregroundColor(isSelected ? .white : Color(uiColor: .ppTextPrimary))
                                                        .multilineTextAlignment(.leading)

                                                    Text(role.roleDescription)
                                                        .font(PPBeirutiFont.medium(11, relativeTo: .caption))
                                                        .foregroundColor(isSelected ? Color.white.opacity(0.85) : Color(uiColor: .ppTextSecondary))
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                .padding(14)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(isSelected ? role.tintColor : Color(uiColor: .ppSurface))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                                .stroke(isSelected ? role.tintColor : Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                                        )
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(uiColor: .ppCard))
                                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                                )

                                // Bilingual Identity Fields Section
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "character.book.closed.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppPrimary))
                                        Text(Language.get("MarketplaceBranches_EditorTitle", alter: "هوية الفرع والاسم التجاري") ?? "هوية الفرع والاسم التجاري")
                                            .font(PPBeirutiFont.bold(14, relativeTo: .headline))
                                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    }

                                    HStack(spacing: 14) {
                                        // Arabic Name
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(Language.get("MarketplaceBranches_NameAr", alter: "اسم الفرع بالعربية") ?? "اسم الفرع بالعربية")
                                                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                                Spacer()
                                                Text("[عربي]")
                                                    .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                                    .foregroundColor(Color(uiColor: .ppPrimary))
                                            }

                                            TextField(Language.get("MarketplaceBranches_PlaceholderNameAr", alter: "مثال: فرع لوسيل الرئيسي") ?? "مثال: فرع لوسيل الرئيسي", text: $nameAr)
                                                .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                                .environment(\.layoutDirection, .rightToLeft)
                                                .multilineTextAlignment(.leading)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color(uiColor: .ppSurface))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                                        )
                                                )
                                        }

                                        // English Name
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(Language.get("MarketplaceBranches_NameEn", alter: "اسم الفرع بالإنجليزية") ?? "اسم الفرع بالإنجليزية")
                                                    .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                                Spacer()
                                                Text("[EN]")
                                                    .font(PPBeirutiFont.bold(10, relativeTo: .caption2))
                                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                            }

                                            TextField(Language.get("MarketplaceBranches_PlaceholderNameEn", alter: "e.g. Lusail Marina Hub") ?? "e.g. Lusail Marina Hub", text: $nameEn)
                                                .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                                .environment(\.layoutDirection, .leftToRight)
                                                .multilineTextAlignment(.leading)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color(uiColor: .ppSurface))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                                        )
                                                )
                                        }
                                    }
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(uiColor: .ppCard))
                                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                                )

                                // Address & Qatar Districts Section
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(uiColor: .ppPrimary))
                                        Text(Language.get("MarketplaceBranches_Address", alter: "عنوان الاستلام الدقيق") ?? "عنوان الاستلام الدقيق")
                                            .font(PPBeirutiFont.bold(14, relativeTo: .headline))
                                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                                    }

                                    TextField(Language.get("MarketplaceBranches_PlaceholderAddress", alter: "الشارع، المنطقة، رقم المبنى أو علامة مميزة") ?? "الشارع، المنطقة، رقم المبنى أو علامة مميزة", text: $address)
                                        .font(PPBeirutiFont.medium(14, relativeTo: .body))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(uiColor: .ppSurface))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                                )
                                        )

                                    // District Grid
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(Language.get("MarketplaceBranches_Editor_DistrictChips_Title", alter: "المناطق الشائعة في قطر (اضغط للإضافة):") ?? "المناطق الشائعة في قطر (اضغط للإضافة):")
                                            .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                            .multilineTextAlignment(.leading)

                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                            ForEach(ppQatarDistricts) { district in
                                                let districtName = district.localizedName
                                                let isIncluded = address.contains(districtName)

                                                Button(action: {
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    if isIncluded {
                                                        address = address
                                                            .replacingOccurrences(of: " - \(districtName)", with: "")
                                                            .replacingOccurrences(of: "\(districtName) - ", with: "")
                                                            .replacingOccurrences(of: districtName, with: "")
                                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                                    } else {
                                                        address = address.isEmpty ? districtName : "\(address) - \(districtName)"
                                                    }
                                                }) {
                                                    HStack(spacing: 5) {
                                                        if isIncluded {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        Text(districtName)
                                                            .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        Capsule()
                                                            .fill(isIncluded ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppSurface))
                                                            .overlay(
                                                                Capsule()
                                                                    .stroke(isIncluded ? Color(uiColor: .ppPrimary) : Color(uiColor: .ppBorder).opacity(0.45), lineWidth: 1)
                                                            )
                                                    )
                                                    .foregroundColor(isIncluded ? .white : Color(uiColor: .ppTextPrimary))
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(uiColor: .ppCard))
                                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                                )

                                // Phone Hotline & Default Hub Row
                                HStack(spacing: 14) {
                                    // Phone Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "phone.circle.fill")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(uiColor: .ppPrimary))
                                            Text(Language.get("MarketplaceBranches_Phone", alter: "هاتف الاستلام") ?? "هاتف الاستلام")
                                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                        }

                                        HStack(spacing: 8) {
                                            Text("+974")
                                                .font(PPBeirutiFont.bold(13, relativeTo: .callout))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(Color(uiColor: .ppSurface))
                                                )

                                            TextField(Language.get("MarketplaceBranches_PlaceholderPhone", alter: "0000 0000") ?? "0000 0000", text: $phone)
                                                .keyboardType(.phonePad)
                                                .font(PPBeirutiFont.bold(14, relativeTo: .body))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                                .multilineTextAlignment(.leading)
                                                .environment(\.layoutDirection, .leftToRight)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(Color(uiColor: .ppSurface))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                .stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 1)
                                                        )
                                                )
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Default Hub Switch Card
                                    Toggle(isOn: $isDefault) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(Language.get("MarketplaceBranches_DefaultLabel", alter: "الفرع الافتراضي") ?? "الفرع الافتراضي")
                                                .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                                .foregroundColor(Color(uiColor: .ppTextPrimary))
                                                .multilineTextAlignment(.leading)

                                            Text(Language.get("MarketplaceBranches_DefaultSubLabel", alter: "استخدامه تلقائياً للشحنات") ?? "استخدامه تلقائياً للشحنات")
                                                .font(PPBeirutiFont.medium(11, relativeTo: .caption))
                                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color(uiColor: .ppPrimary)))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(uiColor: .ppSurface))
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(uiColor: .ppCard))
                                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                                )

                                // Left Pane Commit Button
                                Button(action: {
                                    if isValid && !isSubmitting {
                                        onSave()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        if isSubmitting {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16, weight: .bold))
                                        }
                                        Text(Language.get("Save", alter: "حفظ الفرع اللوجستي") ?? "حفظ الفرع اللوجستي")
                                            .font(PPBeirutiFont.bold(16, relativeTo: .headline))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(isValid ? Color(uiColor: .ppPrimary) : Color.gray.opacity(0.65))
                                            .shadow(color: Color(uiColor: .ppPrimary).opacity(isValid ? 0.35 : 0), radius: 10, x: 0, y: 5)
                                    )
                                }
                                .disabled(!isValid || isSubmitting)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 20)
                            .padding(.leading, 24)
                        }
                        .frame(width: (geo.size.width - 72) * 0.52)

                        // Right Pane: Live Courier Dispatch Terminal (~48%)
                        VStack(spacing: 16) {
                            // Section Header & View Mode Switcher
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Language.get("MarketplaceBranches_Editor_LiveSimulatorTitle", alter: "محاكي تسليم الطرود للسائقين") ?? "محاكي تسليم الطرود للسائقين")
                                        .font(PPBeirutiFont.bold(15, relativeTo: .headline))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                                    Text(Language.get("MarketplaceBranches_Editor_LiveSimulatorSubtitle", alter: "معاينة حية لما يظهر لمندوب التوصيل على هاتفه") ?? "معاينة حية لما يظهر لمندوب التوصيل على هاتفه")
                                        .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                        .foregroundColor(Color(uiColor: .ppTextSecondary))
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Picker("", selection: $previewMode) {
                                    Text(Language.get("MarketplaceBranches_Editor_DriverView", alter: "واجهة المندوب") ?? "واجهة المندوب").tag(0)
                                    Text(Language.get("MarketplaceBranches_Editor_WaybillView", alter: "بوليصة الشحن") ?? "بوليصة الشحن").tag(1)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 190)
                            }

                            // Reactive Courier Card
                            PPCourierWaybillSimulatorCard(
                                nameAr: nameAr,
                                nameEn: nameEn,
                                address: address,
                                phone: phone,
                                isDefault: isDefault,
                                selectedRole: selectedRole,
                                isCompact: false
                            )

                            // Pre-Flight Logistics Readiness Checklist
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(uiColor: .ppPrimary))
                                    Text(Language.get("MarketplaceBranches_Editor_ReadinessScore", alter: "قائمة التحقق اللوجستي للمتجر") ?? "قائمة التحقق اللوجستي للمتجر")
                                        .font(PPBeirutiFont.bold(13, relativeTo: .subheadline))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))

                                    Spacer()

                                    Text("\(Int(readinessProgress * 100))%")
                                        .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                        .foregroundColor(readinessProgress >= 1.0 ? .green : Color(uiColor: .ppPrimary))
                                }

                                // Linear Progress Bar
                                GeometryReader { progressGeo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(uiColor: .ppSurface))
                                            .frame(height: 6)

                                        Capsule()
                                            .fill(readinessProgress >= 1.0 ? Color.green : Color(uiColor: .ppPrimary))
                                            .frame(width: progressGeo.size.width * CGFloat(readinessProgress), height: 6)
                                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: readinessProgress)
                                    }
                                }
                                .frame(height: 6)

                                VStack(spacing: 8) {
                                    checklistItem(
                                        title: Language.get("MarketplaceBranches_Editor_Checklist_NameAr", alter: "اسم الفرع بالعربية للمراسلات المحلية") ?? "اسم الفرع بالعربية للمراسلات المحلية",
                                        isDone: !nameAr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                    checklistItem(
                                        title: Language.get("MarketplaceBranches_Editor_Checklist_NameEn", alter: "اسم الفرع بالإنجليزية للأنظمة اللوجستية") ?? "اسم الفرع بالإنجليزية للأنظمة اللوجستية",
                                        isDone: !nameEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                    checklistItem(
                                        title: Language.get("MarketplaceBranches_Editor_Checklist_Address", alter: "عنوان دقيق مع علامة مميزة للمندوب") ?? "عنوان دقيق مع علامة مميزة للمندوب",
                                        isDone: !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                    checklistItem(
                                        title: Language.get("MarketplaceBranches_Editor_Checklist_Phone", alter: "رقم اتصال محلي فعال للتنسيق (+974)") ?? "رقم اتصال محلي فعال للتنسيق (+974)",
                                        isDone: !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                }
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color(uiColor: .ppCard))
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                            )

                            // Courier Handover Guidance Box
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(uiColor: .ppPrimary))

                                Text(Language.get("MarketplaceBranches_DriverNotice", alter: "سيصل مندوب التوصيل إلى هذا الموقع مباشرة عند قبول مهمة الاستلام. يرجى التأكد من جهوزية الطرود بالرقم المرجعي قبل وصول السائق.") ?? "سيصل مندوب التوصيل إلى هذا الموقع مباشرة عند قبول مهمة الاستلام. يرجى التأكد من جهوزية الطرود بالرقم المرجعي قبل وصول السائق.")
                                    .font(PPBeirutiFont.medium(12, relativeTo: .caption))
                                    .foregroundColor(Color(uiColor: .ppTextSecondary))
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(uiColor: .ppPrimary).opacity(0.08))
                            )

                            Spacer()
                        }
                        .frame(width: (geo.size.width - 72) * 0.48)
                        .padding(.vertical, 20)
                        .padding(.trailing, 24)
                    }
                }
            }
        }
        .background(Color(uiColor: .ppBackground).ignoresSafeArea())
    }

    private func checklistItem(title: String, isDone: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(isDone ? .green : Color(uiColor: .ppTextSecondary))

            Text(title)
                .font(isDone ? PPBeirutiFont.bold(12, relativeTo: .caption) : PPBeirutiFont.regular(12, relativeTo: .caption))
                .foregroundColor(isDone ? Color(uiColor: .ppTextPrimary) : Color(uiColor: .ppTextSecondary))
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

// MARK: - Branch Editor Sheet Entry (`PPMarketplaceBranchEditorSheet`)

public struct PPMarketplaceBranchEditorSheet: View {
    public let originalBranch: PPMarketplaceBranchItem?
    public let onDismiss: () -> Void
    public let onSaved: () -> Void

    @State private var nameAr: String = ""
    @State private var nameEn: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var isDefault: Bool = false
    @State private var selectedRole: PPMarketplaceBranchRole? = nil
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(
        branch: PPMarketplaceBranchItem?,
        onDismiss: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.originalBranch = branch
        self.onDismiss = onDismiss
        self.onSaved = onSaved
        _nameAr = State(initialValue: branch?.nameAr ?? "")
        _nameEn = State(initialValue: branch?.nameEn ?? "")
        _address = State(initialValue: branch?.address ?? "")
        _phone = State(initialValue: branch?.phone ?? "")
        _isDefault = State(initialValue: branch?.defaultBranch ?? false)
    }

    private var isValid: Bool {
        let hasName = !nameAr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      !nameEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAddress = !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasAddress
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                PPMarketplaceBranchEditorIPadView(
                    originalBranch: originalBranch,
                    nameAr: $nameAr,
                    nameEn: $nameEn,
                    address: $address,
                    phone: $phone,
                    isDefault: $isDefault,
                    selectedRole: $selectedRole,
                    isSubmitting: $isSubmitting,
                    errorMessage: $errorMessage,
                    isValid: isValid,
                    onDismiss: onDismiss,
                    onSave: saveBranch
                )
            } else {
                PPMarketplaceBranchEditorIPhoneView(
                    originalBranch: originalBranch,
                    nameAr: $nameAr,
                    nameEn: $nameEn,
                    address: $address,
                    phone: $phone,
                    isDefault: $isDefault,
                    selectedRole: $selectedRole,
                    isSubmitting: $isSubmitting,
                    errorMessage: $errorMessage,
                    isValid: isValid,
                    onDismiss: onDismiss,
                    onSave: saveBranch
                )
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }

    private func saveBranch() {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let trimmedAr = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEn = nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        PPProviderMarketplaceManager.shared().saveMarketplaceBranch(
            withID: originalBranch?.id,
            nameAr: trimmedAr,
            nameEn: trimmedEn,
            address: trimmedAddress,
            phone: trimmedPhone,
            isDefault: isDefault
        ) { [self] success, _, error in
            self.isSubmitting = false
            if let err = error {
                self.errorMessage = err.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                PPToast.toast(Language.get("MarketplaceBranches_Saved", alter: "تم حفظ فرع الاستلام.") ?? "", style: .success, haptic: true, duration: 1.8)
                self.onSaved()
            }
        }
    }
}

// MARK: - Objective-C Hosting Bridge

@objc @MainActor
public final class PPMarketplaceBranchesHostingBridge: NSObject {
    @objc public static func makeViewController(
        selectionMode: Bool,
        onDismiss: @escaping @Sendable () -> Void,
        onConfirmSelection: @escaping @Sendable (PPMarketplaceBranch) -> Void
    ) -> UIViewController {
        let viewModel = PPMarketplaceBranchesViewModel(
            selectionMode: selectionMode,
            onDismiss: onDismiss,
            onConfirmSelection: onConfirmSelection
        )
        let screen = PPMarketplaceBranchesScreen(viewModel: viewModel)
        let host = UIHostingController(rootView: screen)
        host.view.backgroundColor = .clear
        return host
    }

    @objc public static func makeEditorViewController(
        branch: PPMarketplaceBranch?,
        onDismiss: @escaping @Sendable () -> Void,
        onSaved: @escaping @Sendable () -> Void
    ) -> UIViewController {
        let item = branch != nil ? PPMarketplaceBranchItem(from: branch!) : nil
        let sheet = PPMarketplaceBranchEditorSheet(
            branch: item,
            onDismiss: onDismiss,
            onSaved: onSaved
        )
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)

        let host = UIHostingController(rootView: sheet)
        host.view.backgroundColor = .clear
        return host
    }
}

// MARK: - Previews

#if DEBUG
struct PPMarketplaceBranchesView_Previews: PreviewProvider {
    static var sampleBranches: [PPMarketplaceBranchItem] {
        [
            PPMarketplaceBranchItem(
                id: "branch-1",
                code: "HUB-DOH-01",
                nameAr: "فرع لوسيل الرئيسي",
                nameEn: "Lusail Marina Hub",
                address: "شارع مارينا بروميناد، برج 14، الطابق الأرضي، الدوحة",
                phone: "+974 4411 2233",
                active: true,
                defaultBranch: true
            ),
            PPMarketplaceBranchItem(
                id: "branch-2",
                code: "HUB-WAK-02",
                nameAr: "مستودع الوكرة اللوجستي",
                nameEn: "Al Wakrah Logistics Depot",
                address: "المنطقة الصناعية، مستودع B-4، الوكرة",
                phone: "+974 4455 6677",
                active: true,
                defaultBranch: false
            ),
            PPMarketplaceBranchItem(
                id: "branch-3",
                code: "HUB-RYN-03",
                nameAr: "منفذ الريان القديم (تحت الصيانة)",
                nameEn: "Old Al Rayyan Center",
                address: "شارع الفروسية، مجمع الريان التجاري",
                phone: "+974 4488 9900",
                active: false,
                defaultBranch: false
            )
        ]
    }

    static var previews: some View {
        Group {
            // iPhone Arabic RTL Management
            let vm1 = PPMarketplaceBranchesViewModel(selectionMode: false)
            PPMarketplaceBranchesScreen(viewModel: vm1)
                .previewDevice("iPhone 15 Pro")
                .previewDisplayName("iPhone Management (AR)")
                .onAppear { vm1.branches = sampleBranches }

            // iPhone Selection Mode (English LTR)
            let vm2 = PPMarketplaceBranchesViewModel(selectionMode: true)
            PPMarketplaceBranchesScreen(viewModel: vm2)
                .previewDevice("iPhone 15 Pro")
                .previewDisplayName("iPhone Selection Mode")
                .environment(\.locale, Locale(identifier: "en"))
                .onAppear {
                    vm2.branches = sampleBranches
                    vm2.selectedBranchID = "branch-1"
                }

            // iPad Dual-Pane Studio (Arabic RTL)
            let vm3 = PPMarketplaceBranchesViewModel(selectionMode: false)
            PPMarketplaceBranchesScreen(viewModel: vm3)
                .previewDevice("iPad Pro (11-inch) (4th generation)")
                .previewDisplayName("iPad Studio (AR)")
                .onAppear {
                    vm3.branches = sampleBranches
                    vm3.selectedInspectedBranchID = "branch-1"
                }

            // Branch Editor Sheet (iPhone AR)
            PPMarketplaceBranchEditorSheet(
                branch: sampleBranches.first,
                onDismiss: {},
                onSaved: {}
            )
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("Editor Sheet - iPhone (AR)")

            // Branch Editor Sheet (iPad Dual-Pane Studio AR)
            PPMarketplaceBranchEditorSheet(
                branch: sampleBranches.first,
                onDismiss: {},
                onSaved: {}
            )
            .previewDevice("iPad Pro (11-inch) (4th generation)")
            .previewDisplayName("Editor Sheet - iPad Studio (AR)")
        }
    }
}
#endif
