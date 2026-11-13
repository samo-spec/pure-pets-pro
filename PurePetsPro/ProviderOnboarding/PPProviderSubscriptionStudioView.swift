//
//  PPProviderSubscriptionStudioView.swift
//  PurePetsPro
//
//  First-Principles Category-Defining Invention: SwiftyMax NextGen V9.
//  The Authoritative Partner Subscription & Tier Management Studio.
//  Active tier dossier, live billing cycle inspection, comparative plan matrix,
//  and seamless upgrade engine.
//

import SwiftUI
import UIKit

/// Immutable presentation values keep mutable Objective-C plan models out of
/// cross-actor SwiftUI state. Formatting remains owned by PPProviderPlan.
private struct PPSubscriptionPlanOption: Sendable {
    let planID: String
    let title: String
    let subtitle: String
    let priceLine: String
    let recommended: Bool
    /// True when the price is a percentage (e.g. "10% · per item") —
    /// numeric/symbol strings must always render LTR regardless of locale.
    let isPercentagePricing: Bool
}

// MARK: - Main SwiftUI Subscription Studio View

public struct PPProviderSubscriptionStudioView: View {
    private let onUpgradePlanTapped: (PPProviderType) -> Void
    private let onClose: () -> Void

    // Observed State
    @State private var state: PPProviderOnboardingState? = nil
    @State private var availablePlans: [PPSubscriptionPlanOption] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var cancelObservation: (() -> Void)?
    @State private var observationGeneration = UUID()
    @State private var plansProviderType: PPProviderType = .unspecified
    @State private var plansRequestGeneration = UUID()

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        onUpgradePlanTapped: @escaping (PPProviderType) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onUpgradePlanTapped = onUpgradePlanTapped
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage, state == nil {
                    errorView(error: error)
                } else {
                    mainScrollView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(Language.isRTL() ? "إدارة اشتراك الشريك" : "Subscription Management")
                        .font(PPBrandFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color(.label))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        refreshData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .onAppear {
                PPBrandFont.registerIfNeeded()
                startObserving()
            }
            .onDisappear { stopObserving() }
        }
    }

    // MARK: - State Observation

    private func startObserving() {
        stopObserving()
        let generation = observationGeneration
        let uid = PPDeliveryCompanyService.currentAccountUID()
        state = nil
        availablePlans = []
        plansProviderType = .unspecified
        isLoading = true
        errorMessage = nil
        let registration = PPProviderApplicationManager.shared().observeProviderState(forCurrentUser: { newState, error in
            DispatchQueue.main.async {
                guard generation == observationGeneration,
                      PPDeliveryCompanyService.currentAccountUID() == uid,
                      newState == nil || newState?.uid == uid else { return }
                self.isLoading = error == nil && newState?.initialDataAuthoritative != true
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.state = nil
                    self.availablePlans = []
                    self.plansProviderType = .unspecified
                    self.plansRequestGeneration = UUID()
                } else if let newState = newState, newState.initialDataAuthoritative {
                    self.state = newState
                    self.errorMessage = nil
                    self.fetchPlansForActiveProfile(state: newState)
                }
            }
        })
        cancelObservation = { registration.remove() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            guard generation == observationGeneration, isLoading,
                  PPDeliveryCompanyService.currentAccountUID() == uid else { return }
            isLoading = false
            state = nil
            availablePlans = []
            plansProviderType = .unspecified
            plansRequestGeneration = UUID()
            errorMessage = Language.get("ProSubscription_LoadFailed", alter: nil)
        }
    }

    private func stopObserving() {
        observationGeneration = UUID()
        cancelObservation?()
        cancelObservation = nil
    }

    private func refreshData() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        startObserving()
    }

    private func fetchPlansForActiveProfile(state: PPProviderOnboardingState) {
        let generation = observationGeneration
        let uid = state.uid
        let activeType = primaryActiveProviderType(state: state)
        guard activeType != plansProviderType else { return }
        plansProviderType = activeType
        plansRequestGeneration = UUID()
        let requestGeneration = plansRequestGeneration
        availablePlans = []
        guard activeType != .unspecified else { return }

        PPProviderApplicationManager.shared().fetchPlans(for: activeType) { plans, _ in
            let options = (plans ?? []).map { plan in
                PPSubscriptionPlanOption(planID: plan.planID, title: plan.localizedName(),
                                         subtitle: plan.localizedDescriptionText(),
                                         priceLine: plan.localizedPriceLine(),
                                         recommended: plan.recommended,
                                         isPercentagePricing: plan.costType == PPProviderPlanCostTypePercentage)
            }
            DispatchQueue.main.async {
                guard generation == observationGeneration,
                      requestGeneration == plansRequestGeneration,
                      plansProviderType == activeType,
                      PPDeliveryCompanyService.currentAccountUID() == uid else { return }
                self.availablePlans = options
            }
        }
    }

    private func primaryActiveProviderType(state: PPProviderOnboardingState) -> PPProviderType {
        let types: [PPProviderType] = [.marketplace, .deliveryCompany, .vet, .pharmacy, .service, .deliverySubscription]
        let enabled = types.filter { PPProviderTypeIsEnabledInProApp($0) }
        if let active = enabled.first(where: { state.isActive(for: $0) && state.profile(for: $0) != nil }) {
            return active
        }
        return enabled.first(where: { state.profile(for: $0) != nil }) ?? .unspecified
    }

    // MARK: - Main Scroll View

    private var mainScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Active Plan Hero Dossier
                activePlanHeroDossier

                // 2. Compliance / Expiring Documents Notice (if any)
                if let profile = activeProfile {
                    let expiring = profile.expiringDocuments(withinDays: 30)
                    if !expiring.isEmpty {
                        expiringDocumentsWarning(docs: expiring)
                    }
                }

                // 3. Operational Restrictions (if any)
                if let profile = activeProfile, profile.isRestricted() {
                    restrictionsWarning(profile: profile)
                }

                // 4. Available Upgrade Tiers
                availableTiersSection

                // 5. Billing Terms & Platform Guarantees
                billingGuaranteesCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var activeProfile: PPProviderProfile? {
        guard let state = state else { return nil }
        let type = primaryActiveProviderType(state: state)
        return state.profile(for: type)
    }

    private func subscriptionDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.isRTL() ? "ar" : "en")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - 1. Active Plan Hero Dossier

    private var activePlanHeroDossier: some View {
        let profile = activeProfile
        let sourcePlanName = profile?.localizedPlanName() ?? ""
        let planName = sourcePlanName.isEmpty ? Language.get("ProSubscription_Title", alter: nil) : sourcePlanName
        let activeType = primaryActiveProviderType(state: state ?? PPProviderOnboardingState())
        let status = profile.map {
            $0.hasManagedSubscription()
                ? Language.get("PartnerSub_Status_" + $0.effectiveSubscriptionStatus(), alter: nil)
                : PPProviderApplicationManager.localizedStatusTitle($0.status)
        } ?? Language.get("ProSubscription_NoProviderPlan", alter: nil)

        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(planName)
                            .font(PPBrandFont.bold(18, relativeTo: .title3))
                            .foregroundStyle(Color(.label))

                        Text(status)
                            .font(PPBrandFont.bold(11, relativeTo: .caption2))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    Text(activeType == .unspecified ? Language.get("ProSubscription_NoProviderPlan", alter: nil)
                         : PPProviderApplicationManager.localizedTitle(for: activeType))
                        .font(PPBrandFont.medium(13, relativeTo: .subheadline))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }

            Divider()

            // Financial & Billing Breakdown
            VStack(spacing: 10) {
                if let profile = profile, profile.hasManagedSubscription() {
                    PPSubscriptionDetailRow(
                        title: Language.isRTL() ? "حالة الاشتراك" : "Subscription Status",
                        value: status
                    )
                    if let expires = profile.subscriptionExpiresAt() {
                        PPSubscriptionDetailRow(
                            title: Language.isRTL() ? "تاريخ التجديد القادم" : "Next Renewal Date",
                            value: subscriptionDateText(expires)
                        )
                    }
                } else if profile != nil {
                    PPSubscriptionDetailRow(
                        title: Language.get("ProviderSubscriptionCardStatusCaption", alter: nil),
                        value: Language.get("PartnerSub_UnmanagedHint", alter: nil)
                    )
                }

                if profile?.areNewOrdersBlocked() == true {
                    Text(Language.get("ProSubscription_OrdersBlocked", alter: nil))
                }
                if profile?.arePayoutsBlocked() == true {
                    Text(Language.get("ProSubscription_PayoutsHeld", alter: nil))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.2)
        )
        .shadow(color: Color.accentColor.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    // MARK: - 2. Expiring Documents Warning

    private func expiringDocumentsWarning(docs: [[AnyHashable: Any]]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.orange)
                Text(Language.isRTL() ? "تنبيه اقتراب انتهاء التراخيص" : "License Expiry Alert")
                    .font(PPBrandFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
            }

            Text(Language.isRTL() ? "يوجد لديك مستندات رسمية تقترب من تاريخ انتهائها خلال 30 يوماً. يرجى تجديدها لتجنب إيقاف استقبال الطلبات." : "Some official credentials are near expiration. Renew them to maintain continuous operation.")
                .font(PPBrandFont.regular(13, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 3. Operational Restrictions

    private func restrictionsWarning(profile: PPProviderProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.red)
                Text(Language.isRTL() ? "تنبيه القيود التشغيلية" : "Operational Restrictions")
                    .font(PPBrandFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
            }
            Text(Language.isRTL() ? "يوجد قيد نشط على هذا الحساب يمنع البيع أو التحويلات. تواصل مع الدعم لرفع القيد." : "A restriction is active on this account. Contact support to resolve.")
                .font(PPBrandFont.regular(13, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 4. Available Tiers Section

    private var availableTiersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Language.get("ProSubscription_PlansTitle", alter: nil))
                    .font(PPBrandFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
                Spacer()
            }

            if availablePlans.isEmpty {
                Text(Language.isRTL() ? "لا توجد باقات ترقية بديلة حالياً." : "No alternate plans available right now.")
                    .font(PPBrandFont.regular(13, relativeTo: .body))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.vertical, 8)
            } else {
                ForEach(availablePlans, id: \.planID) { plan in
                    let isCurrent = activeProfile?.planID == plan.planID

                    VStack(alignment: .leading, spacing: 12) {
                        // ── Plan name + badge row ──────────────────────────
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title)
                                    .font(PPBrandFont.bold(16, relativeTo: .headline))
                                    .foregroundStyle(Color(.label))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !plan.subtitle.isEmpty {
                                    Text(plan.subtitle)
                                        .font(PPBrandFont.regular(12, relativeTo: .caption))
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if isCurrent {
                                Text(Language.isRTL() ? "باقتك الحالية" : "Current Plan")
                                    .font(PPBrandFont.bold(11, relativeTo: .caption2))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.14))
                                    .foregroundStyle(Color.green)
                                    .clipShape(Capsule())
                            } else if plan.recommended {
                                Text(Language.isRTL() ? "موصى بها" : "Recommended")
                                    .font(PPBrandFont.bold(11, relativeTo: .caption2))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.14))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }

                        // ── Price + CTA row ────────────────────────────────
                        HStack(alignment: .center, spacing: 8) {
                            // Price always LTR: percentages & numbers must
                            // never get mirrored by the Arabic bidi algorithm.
                            Text(plan.priceLine)
                                .font(PPBrandFont.bold(18, relativeTo: .title3))
                                .foregroundStyle(Color.accentColor)
                                .environment(\.layoutDirection, .leftToRight)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !isCurrent {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    let activeType = primaryActiveProviderType(state: state ?? PPProviderOnboardingState())
                                    onUpgradePlanTapped(activeType)
                                } label: {
                                    Text(Language.get("ProSubscription_ChangesAction", alter: nil))
                                        .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor)
                                        .foregroundStyle(Color.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    // MARK: - 5. Billing Guarantees

    private var billingGuaranteesCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("ProSubscription_ChangesTitle", alter: nil))
                    .font(PPBrandFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(Color(.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Language.get("ProSubscription_ChangesBody", alter: nil))
                    .font(PPBrandFont.regular(11.5, relativeTo: .caption2))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.4)
            Text(Language.isRTL() ? "جارٍ تحميل تفاصيل الاشتراك..." : "Loading subscription details...")
                .font(PPBrandFont.medium(14, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Color.red)
            Text(Language.isRTL() ? "تعذر تحميل بيانات الاشتراك" : "Failed to load subscription")
                .font(PPBrandFont.bold(18, relativeTo: .title3))
            Text(error)
                .font(PPBrandFont.regular(13.5, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            Button(Language.isRTL() ? "إعادة المحاولة" : "Retry") {
                refreshData()
            }
            .font(PPBrandFont.bold(14, relativeTo: .body))
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reusable Row

private struct PPSubscriptionDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(PPBrandFont.bold(13, relativeTo: .body))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Objective-C UIHostingController Bridge

@objc(PPProviderSubscriptionStudioHostingController)
public final class PPProviderSubscriptionStudioHostingController: UIViewController {
    private var onUpgradePlanHandler: ((PPProviderType) -> Void)?
    private var onCloseHandler: (() -> Void)?

    @objc public init(
        onUpgradePlan: ((PPProviderType) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onUpgradePlanHandler = onUpgradePlan
        self.onCloseHandler = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        let studioView = PPProviderSubscriptionStudioView(
            onUpgradePlanTapped: { [weak self] type in
                self?.onUpgradePlanHandler?(type)
            },
            onClose: { [weak self] in
                if let close = self?.onCloseHandler {
                    close()
                } else if let nav = self?.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true, completion: nil)
                }
            }
        )

        let host = UIHostingController(rootView: studioView)
        self.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }
}
