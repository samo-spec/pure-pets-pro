//
//  PPProviderApplicationStatusStudioView.swift
//  PurePetsPro
//
//  First-Principles Category-Defining Invention: SwiftyMax NextGen V9.
//  The Authoritative Provider Onboarding Cockpit & Application Lifecycle Studio.
//  Living state radar, real-time review milestone timeline, guided setup checklist,
//  and seamless partner activation engine.
//

import SwiftUI
import UIKit
import FirebaseAuth

// MARK: - Review Milestone Token

public struct PPReviewMilestoneItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let titleAr: String
    public let titleEn: String
    public let subtitleAr: String
    public let subtitleEn: String
    public let symbol: String
    public let status: PPReviewMilestoneStatus

    public var localizedTitle: String { Language.isRTL() ? titleAr : titleEn }
    public var localizedSubtitle: String { Language.isRTL() ? subtitleAr : subtitleEn }
}

public enum PPReviewMilestoneStatus: Hashable, Sendable {
    case completed
    case inProgress
    case pending
    case warning
}

// MARK: - Main SwiftUI Status Studio View

public struct PPProviderApplicationStatusStudioView: View {
    private let onPresentApply: (PPProviderType) -> Void
    private let onTransitionToDashboard: () -> Void
    private let onClose: () -> Void

    // Observed State
    @State private var state: PPProviderOnboardingState? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isActivating: Bool = false
    @State private var activationSuccess: Bool = false

    // UI Feedback
    @State private var pulseBeacon: Bool = false
    @State private var selectedAppForDetail: PPProviderApplication? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        onPresentApply: @escaping (PPProviderType) -> Void,
        onTransitionToDashboard: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onPresentApply = onPresentApply
        self.onTransitionToDashboard = onTransitionToDashboard
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Living Fluid Ambient Background
                PPStatusBackgroundView(isUnderReview: isCurrentUnderReview)

                if isLoading {
                    loadingCockpitView
                } else if let error = errorMessage, state == nil {
                    errorCockpitView(error: error)
                } else {
                    mainContentScrollView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(Language.isRTL() ? "حالة الشريك والاعتماد" : "Partner Status & Onboarding")
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
                startObservingState()
            }
        }
    }

    // MARK: - State Observation

    private func startObservingState() {
        isLoading = true
        errorMessage = nil
        PPProviderApplicationManager.shared().observeProviderState(forCurrentUser: { newState, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else if let newState = newState {
                    self.state = newState
                    self.errorMessage = nil

                    // If setup is complete and provider is already fully active with no review lifecycle, auto transition if appropriate
                    if self.isFullyActiveAndReady(newState) {
                        self.onTransitionToDashboard()
                    }
                }
            }
        })
    }

    private func refreshData() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        startObservingState()
    }

    private func isFullyActiveAndReady(_ state: PPProviderOnboardingState) -> Bool {
        // Active when there's an active profile and setup is not required
        guard state.initialDataAuthoritative, !state.isBlocked, !state.isSetupRequired(),
              !isCurrentUnderReview else { return false }
        return hasActiveProfile(state)
    }

    private var isCurrentUnderReview: Bool {
        guard let state = state else { return false }
        let partnerStatus = state.partnerApplicationStatus.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if partnerStatus == "pending" || partnerStatus == "under_review" || partnerStatus == "resubmitted" {
            return true
        }
        for app in state.applications {
            let s = app.status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if s == "pending" || s == "under_review" || s == "resubmitted" {
                return true
            }
        }
        return false
    }

    // MARK: - Main Scrollable Content

    private var mainContentScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Hero Radar Card
                heroRadarCard

                // 2. Lifecycle Specific Card
                if let state = state {
                    if state.isBlocked {
                        blockedStateCard
                    } else if hasChangesRequested(state) {
                        changesRequestedCard
                    } else if isCurrentUnderReview {
                        reviewTimelineCard
                    } else if state.isSetupRequired() {
                        guidedSetupCard(state: state)
                    } else if state.applications.isEmpty && state.eligibleProviderTypes().count > 0 {
                        readyToApplyCard(state: state)
                    } else if hasActiveProfile(state) {
                        activePartnerSuccessCard
                    }
                }

                // 3. Registered Account Identity Dossier
                identityDossierCard

                // 4. Applications History Deck
                if let apps = state?.applications, !apps.isEmpty {
                    applicationsHistoryDeck(apps: apps)
                }

                // 5. Contact Support Pill
                supportActionPill
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 1. Hero Radar Card

    private var heroRadarCard: some View {
        let info = heroStatusPresentationInfo()

        return VStack(spacing: 16) {
            // Animated Status Beacon
            ZStack {
                Circle()
                    .fill(info.accentColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulseBeacon ? 1.08 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: pulseBeacon
                    )

                Circle()
                    .fill(info.accentColor.opacity(0.22))
                    .frame(width: 66, height: 66)

                Image(systemName: info.symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(info.accentColor)
            }
            .onAppear { pulseBeacon = true }

            // Titles
            VStack(spacing: 6) {
                // Status Pill
                Text(info.badgeText)
                    .font(PPBrandFont.bold(11.5, relativeTo: .caption2))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(info.accentColor.opacity(0.14))
                    .foregroundStyle(info.accentColor)
                    .clipShape(Capsule())

                Text(info.headline)
                    .font(PPBrandFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)

                Text(info.subtitle)
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(info.accentColor.opacity(0.2), lineWidth: 1.2)
        )
        .shadow(color: info.accentColor.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private struct HeroPresentationInfo {
        let badgeText: String
        let headline: String
        let subtitle: String
        let symbol: String
        let accentColor: Color
    }

    private func heroStatusPresentationInfo() -> HeroPresentationInfo {
        guard let state = state else {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "جارٍ التحميل" : "Loading",
                headline: Language.isRTL() ? "جارٍ تجهيز مساحتك" : "Preparing Workspace",
                subtitle: Language.isRTL() ? "نتحقق من أهلية الحساب والاعتماد." : "Checking credentials.",
                symbol: "clock.fill",
                accentColor: .accentColor
            )
        }

        if state.isBlocked {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "الحساب مقيد" : "Restricted",
                headline: Language.isRTL() ? "التقديم غير متاح لهذا الحساب" : "Access Restricted",
                subtitle: Language.isRTL() ? "هذا الحساب مقيد حالياً من الانضمام كشريك. تواصل مع الدعم للمساعدة." : "This account is currently restricted from applying as a provider.",
                symbol: "hand.raised.fill",
                accentColor: .red
            )
        } else if hasChangesRequested(state) {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "مطلوب تعديلات" : "Action Required",
                headline: Language.isRTL() ? "مطلوب اتخاذ إجراء بشأن طلبك" : "Changes Requested",
                subtitle: Language.isRTL() ? "طلب فريق المراجعة تعديلات محددة على بياناتك أو مستنداتك المرفقة." : "Our review board requested specific corrections to your application.",
                symbol: "exclamationmark.triangle.fill",
                accentColor: .orange
            )
        } else if isCurrentUnderReview {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "قيد المراجعة" : "Under Review",
                headline: Language.isRTL() ? "طلبك قيد التدقيق والاعتماد" : "Application Under Review",
                subtitle: Language.isRTL() ? "فريق بيور بيتس يراجع بيانات السجل التجاري والتراخيص حالياً." : "Our compliance team is currently verifying your credentials.",
                symbol: "clock.badge.checkmark.fill",
                accentColor: .blue
            )
        } else if state.isSetupRequired() {
            return HeroPresentationInfo(
                badgeText: state.isReadyForActivation() ? (Language.isRTL() ? "جاهز للتفعيل" : "Ready for Launch") : (Language.isRTL() ? "إعداد الحساب" : "Setup Required"),
                headline: state.isReadyForActivation() ? (Language.isRTL() ? "حسابك جاهز للإطلاق الرسمي!" : "Ready to Launch!") : (Language.isRTL() ? "أكمل خطوات جاهزية الشريك" : "Complete Launch Checklist"),
                subtitle: Language.isRTL() ? "أكمل خطوات الإعداد لتفعيل المتجر واستقبال الحجوزات والطلبات." : "Complete the remaining steps to start receiving bookings and orders.",
                symbol: state.isReadyForActivation() ? "checkmark.seal.fill" : "checklist",
                accentColor: state.isReadyForActivation() ? .green : .accentColor
            )
        } else if hasActiveProfile(state) {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "شريك معتمد" : "Verified Partner",
                headline: Language.isRTL() ? "مرحباً بك في بيور بيتس برو" : "Welcome to Pure Pets Pro",
                subtitle: Language.isRTL() ? "حسابك نشط بالكامل ويمكنك إدارة أعمالك الآن." : "Your partner workspace is active and ready.",
                symbol: "sparkles",
                accentColor: .green
            )
        } else {
            return HeroPresentationInfo(
                badgeText: Language.isRTL() ? "جاهز للتقديم" : "Ready to Join",
                headline: Language.isRTL() ? "انضم إلى شبكة شركاء بيور بيتس" : "Join Pure Pets Network",
                subtitle: Language.isRTL() ? "اختر نوع الشريك المناسب لنشاطك، حدد باقتك وأرسل طلبك للاعتماد." : "Select your provider archetype and submit your credentials.",
                symbol: "sparkles",
                accentColor: .accentColor
            )
        }
    }

    private func hasChangesRequested(_ state: PPProviderOnboardingState) -> Bool {
        if state.partnerApplicationStatus.lowercased() == "changes_requested" { return true }
        return state.applications.contains { $0.status.lowercased() == "changes_requested" }
    }

    private func hasActiveProfile(_ state: PPProviderOnboardingState) -> Bool {
        let types: [PPProviderType] = [.marketplace, .deliveryCompany, .vet, .pharmacy, .service, .deliverySubscription]
        return types.contains { PPProviderTypeIsEnabledInProApp($0) && state.isActive(for: $0) }
    }

    // MARK: - 2. Changes Requested Banner

    private var changesRequestedCard: some View {
        let app = state?.applications.first(where: { $0.status.lowercased() == "changes_requested" })

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.orange)
                Text(Language.isRTL() ? "ملاحظات فريق التدقيق" : "Reviewer Findings")
                    .font(PPBrandFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
            }

            if let notes = app?.reviewNotes, !notes.isEmpty {
                Text(notes)
                    .font(PPBrandFont.medium(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.label).opacity(0.85))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(Language.isRTL() ? "يرجى مراجعة وتحديث صور المستندات أو البيانات غير المطابقة." : "Please review and re-upload matching credentials or corrected details.")
                    .font(PPBrandFont.regular(13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // CTA Button to re-open sheet
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let targetType = app?.providerType ?? .deliverySubscription
                onPresentApply(targetType)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text(Language.isRTL() ? "تعديل الطلب وإعادة الإرسال" : "Update & Resubmit")
                        .font(PPBrandFont.bold(15, relativeTo: .body))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.orange)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 3. Review Timeline

    private var reviewTimelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Language.isRTL() ? "مسار تدقيق واعتماد الشريك" : "Verification Milestones")
                .font(PPBrandFont.bold(16, relativeTo: .headline))
                .foregroundStyle(Color(.label))

            VStack(spacing: 12) {
                PPMilestoneRow(
                    step: 1,
                    title: Language.isRTL() ? "استلام الطلب والبيانات" : "Application Received",
                    subtitle: Language.isRTL() ? "تم تسجيل بيانات الطلب وحفظها في المنصة" : "Form & contact details saved",
                    status: .completed
                )

                PPMilestoneRow(
                    step: 2,
                    title: Language.isRTL() ? "تدقيق السجل التجاري والتراخيص" : "Credential & CR Verification",
                    subtitle: Language.isRTL() ? "جارٍ مطابقة التراخيص مع وزارة التجارة والصناعة" : "Auditing credentials with authorities",
                    status: .inProgress
                )

                PPMilestoneRow(
                    step: 3,
                    title: Language.isRTL() ? "التفعيل والاعتماد الرسمي" : "Official Launch & Activation",
                    subtitle: Language.isRTL() ? "إتاحة لوحة التحكم ومساحة استقبال الطلبات" : "Unlock orders & management cockpit",
                    status: .pending
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.blue)
                Text(Language.isRTL() ? "المدة المقدرة للمراجعة: أقل من 24 ساعة عمل." : "Estimated review time: Within 24 business hours.")
                    .font(PPBrandFont.medium(12, relativeTo: .caption))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - 4. Guided Setup Checklist

    private func guidedSetupCard(state: PPProviderOnboardingState) -> some View {
        let checklist = state.activationChecklist ?? [:]

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.isRTL() ? "خطوات الجاهزية للتشغيل" : "Launch Readiness Checklist")
                        .font(PPBrandFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color(.label))
                    Text(Language.isRTL() ? "أكمل هذه الخطوات لتفعيل المتجر وبدء استقبال العملاء." : "Complete these requirements to start receiving pet owners.")
                        .font(PPBrandFont.regular(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
            }

            VStack(spacing: 10) {
                PPChecklistTaskRow(
                    title: Language.isRTL() ? "إكمال الملف التجاري وصورة الغلاف" : "Complete Business Profile & Cover",
                    isDone: checklist["profileCompleted"] as? Bool ?? false
                ) {
                    toggleChecklistKey("profileCompleted")
                }

                PPChecklistTaskRow(
                    title: Language.isRTL() ? "تحديد ساعات العمل وأوقات التواجد" : "Set Operating Hours & Availability",
                    isDone: checklist["operatingHoursSet"] as? Bool ?? false
                ) {
                    toggleChecklistKey("operatingHoursSet")
                }

                PPChecklistTaskRow(
                    title: Language.isRTL() ? "إضافة الحساب البنكي والآيبان للتحويلات" : "Add Bank Account & IBAN Payout",
                    isDone: checklist["payoutAccountLinked"] as? Bool ?? false
                ) {
                    toggleChecklistKey("payoutAccountLinked")
                }

                PPChecklistTaskRow(
                    title: Language.isRTL() ? "إضافة أول خدمة أو منتج في المتجر" : "Add First Catalog Item or Service",
                    isDone: checklist["firstItemAdded"] as? Bool ?? false
                ) {
                    toggleChecklistKey("firstItemAdded")
                }
            }

            // Activate Partner Account CTA
            Button {
                activateAccount()
            } label: {
                HStack(spacing: 8) {
                    if isActivating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                        Text(Language.isRTL() ? "تفعيل حساب الشريك الآن" : "Activate Partner Account Now")
                            .font(PPBrandFont.bold(15, relativeTo: .body))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(state.isReadyForActivation() ? Color.green : Color.accentColor)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: (state.isReadyForActivation() ? Color.green : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isActivating)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func toggleChecklistKey(_ key: String) {
        guard let current = state?.activationChecklist?[key] as? Bool else {
            PPProviderApplicationManager.shared().updateChecklistProgress(forKey: key, completed: true) { _, _ in }
            return
        }
        PPProviderApplicationManager.shared().updateChecklistProgress(forKey: key, completed: !current) { _, _ in }
    }

    private func activateAccount() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isActivating = true
        PPProviderApplicationManager.shared().activatePartnerAccount { success, error in
            DispatchQueue.main.async {
                self.isActivating = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.activationSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.onTransitionToDashboard()
                    }
                } else if let error = error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Ready to Apply Card

    private func readyToApplyCard(state: PPProviderOnboardingState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.isRTL() ? "ابدأ رحلة الشراكة" : "Start Your Partnership")
                        .font(PPBrandFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color(.label))
                    Text(Language.isRTL() ? "قدّم طلبك الآن للانضمام إلى نخبة مزودي خدمات الحيوانات في قطر." : "Apply now to join verified pet providers across Qatar.")
                        .font(PPBrandFont.regular(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let target = state.eligibleProviderTypes().first.flatMap { PPProviderType(rawValue: $0.intValue) } ?? .deliverySubscription
                onPresentApply(target)
            } label: {
                HStack(spacing: 8) {
                    Text(Language.isRTL() ? "تقديم طلب شريك جديد" : "Apply as a Partner")
                        .font(PPBrandFont.bold(15, relativeTo: .body))
                    Image(systemName: Language.isRTL() ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.accentColor)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Active Partner Success Card

    private var activePartnerSuccessCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Language.isRTL() ? "حسابك معتمد ونشط" : "Partner Workspace Active")
                        .font(PPBrandFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color(.label))
                    Text(Language.isRTL() ? "يمكنك الدخول إلى لوحة التحكم ومتابعة العمليات اليومية." : "You can enter your operational cockpit and start serving customers.")
                        .font(PPBrandFont.regular(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
            }

            Button {
                onTransitionToDashboard()
            } label: {
                HStack(spacing: 8) {
                    Text(Language.isRTL() ? "فتح لوحة التحكم" : "Open Partner Cockpit")
                        .font(PPBrandFont.bold(15, relativeTo: .body))
                    Image(systemName: Language.isRTL() ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Blocked Card

    private var blockedStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.red)
                Text(Language.isRTL() ? "الحساب مقيد حالياً" : "Account Suspended")
                    .font(PPBrandFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
            }
            Text(Language.isRTL() ? "تم تقييد التقديم أو العمليات لهذا الحساب. يرجى التواصل مع فريق الدعم والامتثال في بيور بيتس لمعرفة التفاصيل." : "Operations and new applications are blocked. Please reach out to Pure Pets support.")
                .font(PPBrandFont.regular(13, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(18)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Identity Dossier Card

    private var identityDossierCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Language.isRTL() ? "بيانات الحساب المسجل" : "Registered Account Identity")
                    .font(PPBrandFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color(.label))
                Spacer()
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                if let name = state?.displayName, !name.isEmpty {
                    PPStatusIdentityRow(title: Language.isRTL() ? "الاسم المعتمد" : "Name", value: name)
                }
                if let phone = state?.phone, !phone.isEmpty {
                    PPStatusIdentityRow(title: Language.isRTL() ? "رقم الجوال" : "Phone", value: phone)
                }
                if let email = state?.email, !email.isEmpty {
                    PPStatusIdentityRow(title: Language.isRTL() ? "البريد الإلكتروني" : "Email", value: email)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Applications History Deck

    private func applicationsHistoryDeck(apps: [PPProviderApplication]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Language.isRTL() ? "الطلبات والمسارات المسجلة" : "Submitted Applications")
                .font(PPBrandFont.bold(15, relativeTo: .headline))
                .foregroundStyle(Color(.label))

            ForEach(apps, id: \.applicationID) { app in
                HStack(spacing: 12) {
                    // Type Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: PPProviderApplicationManager.symbolName(for: app.providerType))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(PPProviderApplicationManager.localizedTitle(for: app.providerType))
                            .font(PPBrandFont.bold(15, relativeTo: .body))
                            .foregroundStyle(Color(.label))
                        Text(app.localizedPlanName())
                            .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    // Status Badge
                    Text(PPProviderApplicationManager.localizedStatusTitle(app.status))
                        .font(PPBrandFont.bold(11, relativeTo: .caption2))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusBadgeColor(for: app.status).opacity(0.15))
                        .foregroundStyle(statusBadgeColor(for: app.status))
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func statusBadgeColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved": return .green
        case "under_review", "pending", "resubmitted": return .blue
        case "changes_requested": return .orange
        case "rejected", "blocked": return .red
        default: return .secondary
        }
    }

    // MARK: - Support Action Pill

    private var supportActionPill: some View {
        Button {
            // Open support or email
            if let url = URL(string: "https://purepets.qa/support") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "headphones")
                    .font(.system(size: 13))
                Text(Language.isRTL() ? "هل تحتاج مساعدة؟ تواصل مع دعم الشركاء" : "Need assistance? Contact Partner Support")
                    .font(PPBrandFont.medium(12.5, relativeTo: .caption))
            }
            .foregroundStyle(Color(.secondaryLabel))
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading & Error States

    private var loadingCockpitView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.4)
            Text(Language.isRTL() ? "جارٍ تحميل حالة الحساب والاعتماد..." : "Loading partner state...")
                .font(PPBrandFont.medium(14, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorCockpitView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Color.red)
            Text(Language.isRTL() ? "تعذر تحميل حالة الشريك" : "Failed to load partner status")
                .font(PPBrandFont.bold(18, relativeTo: .title3))
                .foregroundStyle(Color(.label))
            Text(error)
                .font(PPBrandFont.regular(13.5, relativeTo: .body))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(Language.isRTL() ? "إعادة المحاولة" : "Retry") {
                refreshData()
            }
            .font(PPBrandFont.bold(14, relativeTo: .body))
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subviews & Helpers

private struct PPStatusBackgroundView: View {
    let isUnderReview: Bool

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(isUnderReview ? Color.blue.opacity(0.06) : Color.accentColor.opacity(0.06))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)

                Circle()
                    .fill(Color.green.opacity(0.04))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.4)
            }
        }
    }
}

private struct PPMilestoneRow: View {
    let step: Int
    let title: String
    let subtitle: String
    let status: PPReviewMilestoneStatus

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusFillColor)
                    .frame(width: 32, height: 32)

                if status == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                } else if status == .inProgress {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Text("\(step)")
                        .font(PPBrandFont.bold(12, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PPBrandFont.bold(14, relativeTo: .body))
                    .foregroundStyle(Color(.label))
                Text(subtitle)
                    .font(PPBrandFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer()
        }
    }

    private var statusFillColor: Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .pending: return Color(.tertiarySystemFill)
        case .warning: return .orange
        }
    }
}

private struct PPChecklistTaskRow: View {
    let title: String
    let isDone: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone ? Color.green : Color(.separator))

                Text(title)
                    .font(isDone ? PPBrandFont.bold(13.5, relativeTo: .body) : PPBrandFont.medium(13.5, relativeTo: .body))
                    .foregroundStyle(isDone ? Color(.label) : Color(.label).opacity(0.85))
                    .strikethrough(isDone, color: Color(.secondaryLabel))

                Spacer()
            }
            .padding(12)
            .background(isDone ? Color.green.opacity(0.08) : Color(.tertiarySystemFill).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PPStatusIdentityRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PPBrandFont.medium(12.5, relativeTo: .caption))
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Text(value)
                .font(PPBrandFont.bold(13, relativeTo: .body))
                .foregroundStyle(Color(.label))
        }
    }
}

// MARK: - Objective-C UIHostingController Bridge

@objc(PPProviderApplicationStatusStudioHostingController)
public final class PPProviderApplicationStatusStudioHostingController: UIViewController {
    private var onPresentApplyHandler: ((PPProviderType) -> Void)?
    private var onTransitionToDashboardHandler: (() -> Void)?
    private var onCloseHandler: (() -> Void)?

    @objc public init(
        onPresentApply: ((PPProviderType) -> Void)? = nil,
        onTransitionToDashboard: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onPresentApplyHandler = onPresentApply
        self.onTransitionToDashboardHandler = onTransitionToDashboard
        self.onCloseHandler = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        let studioView = PPProviderApplicationStatusStudioView(
            onPresentApply: { [weak self] type in
                self?.onPresentApplyHandler?(type)
            },
            onTransitionToDashboard: { [weak self] in
                self?.onTransitionToDashboardHandler?()
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
