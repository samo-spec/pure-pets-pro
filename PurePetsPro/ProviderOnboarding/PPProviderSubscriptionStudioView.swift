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

// MARK: - Main SwiftUI Subscription Studio View

public struct PPProviderSubscriptionStudioView: View {
    private let onUpgradePlanTapped: (PPProviderType) -> Void
    private let onClose: () -> Void

    // Observed State
    @State private var state: PPProviderOnboardingState? = nil
    @State private var availablePlans: [PPProviderPlan] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

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
                        .font(.system(size: 16, weight: .bold))
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
                startObserving()
            }
        }
    }

    // MARK: - State Observation

    private func startObserving() {
        isLoading = true
        errorMessage = nil
        PPProviderApplicationManager.shared().observeProviderStateForCurrentUser { newState, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else if let newState = newState {
                    self.state = newState
                    self.errorMessage = nil
                    self.fetchPlansForActiveProfile(state: newState)
                }
            }
        }
    }

    private func refreshData() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        startObserving()
    }

    private func fetchPlansForActiveProfile(state: PPProviderOnboardingState) {
        let activeType = primaryActiveProviderType(state: state)
        guard activeType != .unspecified else { return }

        PPProviderApplicationManager.shared().fetchPlans(for: activeType) { plans, _ in
            DispatchQueue.main.async {
                if let plans = plans {
                    self.availablePlans = plans
                }
            }
        }
    }

    private func primaryActiveProviderType(state: PPProviderOnboardingState) -> PPProviderType {
        for typeNum in state.eligibleProviderTypes {
            if let type = PPProviderType(rawValue: typeNum.intValue), state.isActive(for: type) {
                return type
            }
        }
        return state.eligibleProviderTypes.first.flatMap { PPProviderType(rawValue: $0.intValue) } ?? .deliverySubscription
    }

    // MARK: - Main Scroll View

    private var mainScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Active Plan Hero Dossier
                activePlanHeroDossier

                // 2. Compliance / Expiring Documents Notice (if any)
                if let profile = activeProfile, let expiring = profile.expiringDocuments(withinDays: 30), !expiring.isEmpty {
                    expiringDocumentsWarning(docs: expiring)
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

    // MARK: - 1. Active Plan Hero Dossier

    private var activePlanHeroDossier: some View {
        let profile = activeProfile
        let planName = profile?.localizedPlanName() ?? (Language.isRTL() ? "باقة الشريك القياسية" : "Standard Partner Tier")
        let activeType = primaryActiveProviderType(state: state ?? PPProviderOnboardingState())

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
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(.label))

                        Text(Language.isRTL() ? "نشطة" : "Active")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.14))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }

                    Text(PPProviderApplicationManager.localizedTitle(for: activeType))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()
            }

            Divider()

            // Financial & Billing Breakdown
            VStack(spacing: 10) {
                if let profile = profile, profile.hasManagedSubscription() {
                    PPSubscriptionDetailRow(
                        title: Language.isRTL() ? "حالة الاشتراك" : "Subscription Status",
                        value: profile.effectiveSubscriptionStatus()
                    )
                    if let expires = profile.subscriptionExpiresAt() {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        PPSubscriptionDetailRow(
                            title: Language.isRTL() ? "تاريخ التجديد القادم" : "Next Renewal Date",
                            value: formatter.string(from: expires)
                        )
                    }
                } else if let profile = profile {
                    PPSubscriptionDetailRow(
                        title: Language.isRTL() ? "قيمة الباقة" : "Plan Fee",
                        value: profile.priceAmount > 0 ? "\(Int(profile.priceAmount)) \(profile.currency ?? "QAR") / \(profile.billingInterval ?? "")" : (Language.isRTL() ? "حسب العمولة" : "Commission Based")
                    )
                }

                PPSubscriptionDetailRow(
                    title: Language.isRTL() ? "حالة استقبال الطلبات" : "Order Receiving",
                    value: (profile?.areNewOrdersBlocked() == true) ? (Language.isRTL() ? "موقوف مؤقتاً" : "Blocked") : (Language.isRTL() ? "متاح ومستمر" : "Active")
                )

                PPSubscriptionDetailRow(
                    title: Language.isRTL() ? "التحويلات المالية" : "Payouts Status",
                    value: (profile?.arePayoutsBlocked() == true) ? (Language.isRTL() ? "معلقة" : "Held") : (Language.isRTL() ? "تسوية أسبوعية منتظمة" : "Regular Weekly Payouts")
                )
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(.label))
            }

            Text(Language.isRTL() ? "يوجد لديك مستندات رسمية تقترب من تاريخ انتهائها خلال 30 يوماً. يرجى تجديدها لتجنب إيقاف استقبال الطلبات." : "Some official credentials are near expiration. Renew them to maintain continuous operation.")
                .font(.system(size: 13, weight: .regular))
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(.label))
            }
            Text(Language.isRTL() ? "يوجد قيد نشط على هذا الحساب يمنع البيع أو التحويلات. تواصل مع الدعم لرفع القيد." : "A restriction is active on this account. Contact support to resolve.")
                .font(.system(size: 13, weight: .regular))
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
                Text(Language.isRTL() ? "باقات الترقية المتاحة" : "Available Upgrade Tiers")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                Spacer()
            }

            if availablePlans.isEmpty {
                Text(Language.isRTL() ? "لا توجد باقات ترقية بديلة حالياً." : "No alternate plans available right now.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.vertical, 8)
            } else {
                ForEach(availablePlans, id: \.planID) { plan in
                    let isCurrent = activeProfile?.planID == plan.planID

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.localizedName())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(.label))
                                if !plan.localizedDescriptionText().isEmpty {
                                    Text(plan.localizedDescriptionText())
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }

                            Spacer()

                            if isCurrent {
                                Text(Language.isRTL() ? "باقتك الحالية" : "Current Plan")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.14))
                                    .foregroundStyle(Color.green)
                                    .clipShape(Capsule())
                            } else if plan.recommended {
                                Text(Language.isRTL() ? "موصى بها" : "Recommended")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.14))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }

                        // Pricing Line
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(plan.localizedPriceLine())
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                            Spacer()

                            if !isCurrent {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    let activeType = primaryActiveProviderType(state: state ?? PPProviderOnboardingState())
                                    onUpgradePlanTapped(activeType)
                                } label: {
                                    Text(Language.isRTL() ? "ترقية الباقة" : "Upgrade")
                                        .font(.system(size: 13, weight: .bold))
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
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(Language.isRTL() ? "ضمان التسوية وشفافية العمولات" : "Platform Payout Guarantee")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(.label))
                Text(Language.isRTL() ? "تتم المعاملات المالية والتسويات بموجب لوائح مصرف قطر المركزي." : "All payouts follow Qatar Central Bank certified processing.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemFill).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.4)
            Text(Language.isRTL() ? "جارٍ تحميل تفاصيل الاشتراك..." : "Loading subscription details...")
                .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 18, weight: .bold))
            Text(error)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            Button(Language.isRTL() ? "إعادة المحاولة" : "Retry") {
                refreshData()
            }
            .font(.system(size: 14, weight: .bold))
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
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(.label))
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
