import SwiftUI
import UIKit

/// Options are immutable values captured from the server-normalized plan preview.
private struct PPSubscriptionPlanOption: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let priceLine: String
    let planHash: String
    let isPercentagePricing: Bool
    let recommended: Bool
}

private struct PPSubscriptionRequestIntent: Identifiable, Sendable {
    let id = UUID().uuidString
    let profileID: String
    let action: String
    let planID: String
    let planHash: String
    let version: Int
    let title: String
    let planTitle: String
}

/// UIKit owns selection and push/back. This view never chooses a primary plan.
@MainActor
public struct PPProviderSubscriptionStudioView: View {
    private let selectedProfileID: String?
    private let workforceOnly: Bool
    private let onSelect: (String) -> Void
    private let onApplications: (Bool) -> Void
    private let onMessage: (String, String) -> Void
    private let onClose: () -> Void

    @State private var records: [PPProviderOwnedSubscription] = []
    @State private var selectedRecord: PPProviderOwnedSubscription?
    @State private var availablePlans: [PPSubscriptionPlanOption] = []
    @State private var lifecycleState: PPProviderOnboardingState?
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var cancelObservation: (() -> Void)?
    @State private var observationGeneration = UUID()
    @State private var requestGeneration = UUID()
    @State private var boundUID = ""
    @State private var requestIntent: PPSubscriptionRequestIntent?
    @State private var requestNotes = ""
    @State private var submissionError: String?
    @State private var isSubmitting = false
    @State private var submissionGeneration = UUID()
    @State private var reviewedPayload: [String: Any]?
    @State private var pendingMessage: (title: String, body: String)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.scenePhase) private var scenePhase
    private var palette: PPProPalette { .resolve(colorScheme) }
    private var isDetail: Bool { selectedProfileID != nil }

    init(selectedProfileID: String?, workforceOnly: Bool, onSelect: @escaping (String) -> Void,
         onApplications: @escaping (Bool) -> Void, onMessage: @escaping (String, String) -> Void,
         onClose: @escaping () -> Void) {
        self.selectedProfileID = selectedProfileID
        self.workforceOnly = workforceOnly
        self.onSelect = onSelect
        self.onApplications = onApplications
        self.onMessage = onMessage
        self.onClose = onClose
    }

    public var body: some View {
        // This stack supplies the existing toolbar only. UIKit performs every
        // selection push, so there is no competing SwiftUI destination/path.
        NavigationStack {
            ZStack {
                palette.canvas.ignoresSafeArea()
                if isLoading {
                    ProgressView(text("ProSubscription_Loading"))
                        .font(PPBrandFont.medium(16, relativeTo: .body)).tint(palette.accentText)
                } else if let errorMessage {
                    recovery(errorMessage)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if isDetail {
                                if let selectedRecord { detail(selectedRecord) }
                                else { recovery(text("ProSubscriptions_Unavailable")) }
                            } else {
                                inventory
                            }
                        }
                        .frame(maxWidth: 700, alignment: .leading)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await withCheckedContinuation { continuation in
                            reloadData { continuation.resume() }
                        }
                    }
                }
            }
            .foregroundStyle(palette.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: isDetail
                              ? (layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                              : "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(text(isDetail ? "ProSubscriptions_Back" : "Close"))
                }
                ToolbarItem(placement: .principal) {
                    Text(text(isDetail ? "ProSubscriptions_DetailsTitle" : "ProSubscriptions_ListTitle"))
                        .font(PPBrandFont.bold(17, relativeTo: .headline))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { reloadData() } label: {
                        if isRefreshing { ProgressView() }
                        else { Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44) }
                    }
                    .disabled(isRefreshing || isSubmitting)
                    .accessibilityLabel(text("ProSubscriptions_Refresh"))
                }
            }
            .tint(palette.accentText)
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear { startObserving() }
        .onDisappear { stopObserving() }
        .onChange(of: PPDeliveryCompanyService.currentAccountUID()) { _, _ in
            requestIntent = nil
            reviewedPayload = nil
            startObserving()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !isSubmitting { reloadData() }
        }
        .sheet(item: $requestIntent, onDismiss: showPendingMessage) { intent in requestComposer(intent) }
        .accessibilityIdentifier(isDetail ? "pro.subscription.detail" : "pro.subscription.inventory")
    }

    private func text(_ key: String) -> String { Language.get(key, alter: nil) }
    private func title(_ record: PPProviderOwnedSubscription) -> String {
        let plan = record.profile.localizedPlanName()
        return plan.isEmpty ? text("PartnerSub_NoPlan") : plan
    }
    private func providerTitle(_ record: PPProviderOwnedSubscription) -> String {
        PPProviderApplicationManager.localizedTitle(for: record.profile.providerType)
    }
    private func status(_ record: PPProviderOwnedSubscription) -> String {
        text("PartnerSub_Status_" + record.subscriptionStatus)
    }
    private func operationTitle(_ record: PPProviderOwnedSubscription) -> String {
        let states = ["active", "setup_required", "restricted", "suspended", "reactivation_review", "offboarded",
                      "warning", "paused", "disabled", "inactive"]
        return text("ProSubscriptions_Operation_" + (states.contains(record.operationalStatus) ? record.operationalStatus : "unknown"))
    }
    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.isRTL() ? "ar" : "en")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    private func endText(_ record: PPProviderOwnedSubscription) -> String {
        if let date = record.profile.subscriptionExpiresAt() { return dateText(date) }
        return text(record.profile.billingInterval == "one_time" ? "PartnerSub_NoEnd" : "ProSubscriptions_DateNotRecorded")
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text("ProSubscriptions_ListTitle"))
                    .font(PPBrandFont.bold(30, relativeTo: .title)).accessibilityAddTraits(.isHeader)
                Text(text("ProSubscriptions_ListBody"))
                    .font(PPBrandFont.regular(17, relativeTo: .body)).foregroundStyle(palette.secondary)
            }
            if records.isEmpty {
                notice(workforceOnly ? "ProSubscriptions_WorkforceBody" : "ProSubscriptions_EmptyBody", symbol: "rectangle.stack")
                if workforceOnly { notice("ProSubscription_DriverRequirement", symbol: "person.crop.rectangle") }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(records, id: \.profile.profileID) { record in
                        Button { onSelect(record.profile.profileID) } label: { inventoryRow(record) }
                            .buttonStyle(PPProHomeControlStyle())
                            .accessibilityHint(text("ProSubscriptions_ChooseHint"))
                            .accessibilityIdentifier("pro.subscription.choose." + record.profile.profileID)
                        if record.profile.profileID != records.last?.profile.profileID {
                            Divider().padding(.leading, 70).accessibilityHidden(true)
                        }
                    }
                }
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
            }
            VStack(spacing: 4) {
                if !workforceOnly { action("ProSubscription_AddFeature", symbol: "plus.circle") { onApplications(true) } }
                action("ProSubscriptions_ViewApplications", symbol: "clock") { onApplications(false) }
            }
        }
    }

    private func inventoryRow(_ record: PPProviderOwnedSubscription) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: PPProviderApplicationManager.symbolName(for: record.profile.providerType))
                .font(.system(size: 20, weight: .medium)).foregroundStyle(palette.accentText)
                .frame(width: 42, height: 46).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(providerTitle(record)).font(PPBrandFont.medium(14, relativeTo: .subheadline)).foregroundStyle(palette.secondary)
                Text(title(record)).font(PPBrandFont.bold(21, relativeTo: .title3)).foregroundStyle(palette.text)
                Text(status(record)).font(PPBrandFont.medium(15, relativeTo: .body)).foregroundStyle(palette.text)
                if record.profile.hasManagedSubscription() {
                    Text(String(format: text("ProSubscriptions_EndFormat"), endText(record)))
                        .font(PPBrandFont.regular(14, relativeTo: .subheadline)).foregroundStyle(palette.secondary)
                }
                if record.subscriptionRequest["status"] as? String == "pending" {
                    Label(text("ProSubscriptions_RequestPending"), systemImage: "clock")
                        .font(PPBrandFont.medium(14, relativeTo: .subheadline)).foregroundStyle(palette.accentText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.secondary)
                .padding(.top, 18).accessibilityHidden(true)
        }
        .padding(18).contentShape(Rectangle())
    }

    @ViewBuilder private func detail(_ record: PPProviderOwnedSubscription) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(providerTitle(record), systemImage: PPProviderApplicationManager.symbolName(for: record.profile.providerType))
                .font(PPBrandFont.medium(16, relativeTo: .subheadline)).foregroundStyle(palette.accentText)
            Text(title(record)).font(PPBrandFont.bold(32, relativeTo: .title)).accessibilityAddTraits(.isHeader)
            if !record.displayName.isEmpty && record.displayName != record.userID {
                Text(record.displayName).font(PPBrandFont.regular(17, relativeTo: .body)).foregroundStyle(palette.secondary)
            }
        }
        VStack(spacing: 16) {
            fact("ProSubscriptions_TermStatus", value: status(record))
            if !record.currentPriceLine.isEmpty { fact("ProSubscriptions_Price", value: record.currentPriceLine, forceLTR: true) }
            if let started = record.profile.subscription["startedAt"] as? NSNumber, started.doubleValue.isFinite {
                fact("PartnerSub_TermStarts", value: dateText(Date(timeIntervalSince1970: started.doubleValue / 1000)))
            }
            fact("PartnerSub_TermEnds", value: endText(record))
            fact("PartnerSub_Operations", value: operationTitle(record))
        }
        .padding(20).background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
        if record.subscriptionStatus == "unmanaged" { notice("PartnerSub_UnmanagedHint", symbol: "info.circle") }
        selectedProfileWarnings(record)
        requestState(record)
        if record.requestActions.contains("renew") {
            action("ProSubscriptions_RequestRenewal", symbol: "arrow.clockwise") {
                prepareRequest(record, action: "renew", plan: nil)
            }
        }
        if record.requestActions.contains("change_plan") {
            VStack(alignment: .leading, spacing: 14) {
                Text(text("ProSubscriptions_ChangePlanTitle"))
                    .font(PPBrandFont.bold(21, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
                Text(text("ProSubscriptions_ReviewRequired"))
                    .font(PPBrandFont.regular(15, relativeTo: .body)).foregroundStyle(palette.secondary)
                if availablePlans.isEmpty {
                    notice("ProSubscriptions_NoPlans", symbol: "rectangle.stack")
                } else {
                    ForEach(availablePlans) { plan in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(plan.title).font(PPBrandFont.bold(20, relativeTo: .headline))
                            if plan.recommended {
                                Text(text("ProSubscriptions_Recommended")).font(PPBrandFont.medium(14, relativeTo: .subheadline)).foregroundStyle(palette.accentText)
                            }
                            if !plan.subtitle.isEmpty {
                                Text(plan.subtitle).font(PPBrandFont.regular(15, relativeTo: .body)).foregroundStyle(palette.secondary)
                            }
                            Text(plan.priceLine).font(PPBrandFont.bold(18, relativeTo: .title3))
                                .foregroundStyle(palette.accentText)
                                .environment(\.layoutDirection, .leftToRight)
                            if plan.id == record.profile.planID && ["active", "paused"].contains(record.subscriptionStatus) {
                                Text(text("ProSubscriptions_CurrentPlan")).font(PPBrandFont.medium(14, relativeTo: .subheadline)).foregroundStyle(palette.secondary)
                            } else {
                                action("ProSubscriptions_RequestPlan", symbol: "arrow.triangle.2.circlepath") {
                                    prepareRequest(record, action: "change_plan", plan: plan)
                                }
                            }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
        notice("ProSubscriptions_ReviewRequired", symbol: "checkmark.shield")
    }

    @ViewBuilder private func selectedProfileWarnings(_ record: PPProviderOwnedSubscription) -> some View {
        // Extra owner-visible documents/restrictions come only from the exact
        // canonical profile observed by the existing manager, never another type.
        if lifecycleState?.uid == boundUID,
           let profile = lifecycleState?.profilesByType.values.first(where: { $0.profileID == record.profile.profileID }) {
            if !profile.expiringDocuments(withinDays: 30).isEmpty {
                notice("ProSubscriptions_DocumentsExpiring", symbol: "doc.badge.clock")
            }
            if profile.isRestricted() { notice("ProSubscriptions_Restricted", symbol: "hand.raised") }
            if profile.areNewOrdersBlocked() { notice("ProSubscription_OrdersBlocked", symbol: "shippingbox") }
            if profile.arePayoutsBlocked() { notice("ProSubscription_PayoutsHeld", symbol: "lock") }
        }
    }

    @ViewBuilder private func requestState(_ record: PPProviderOwnedSubscription) -> some View {
        if let requestStatus = record.subscriptionRequest["status"] as? String,
           ["pending", "approved", "rejected"].contains(requestStatus) {
            VStack(alignment: .leading, spacing: 8) {
                Label(text("ProSubscriptions_RequestStatus_" + requestStatus), systemImage: "doc.text.magnifyingglass")
                    .font(PPBrandFont.bold(18, relativeTo: .headline))
                if let action = record.subscriptionRequest["action"] as? String {
                    Text(text(action == "renew" ? "ProSubscriptions_RequestRenewal" : "ProSubscriptions_RequestPlan"))
                        .font(PPBrandFont.medium(15, relativeTo: .body))
                }
                if requestStatus == "pending" {
                    Text(text("ProSubscriptions_ReviewRequired")).font(PPBrandFont.regular(15, relativeTo: .body))
                }
            }
            .foregroundStyle(palette.secondary).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func fact(_ key: String, value: String, forceLTR: Bool = false) -> some View {
        Group {
            if sizeCategory.isAccessibilityCategory {
                VStack(alignment: .leading, spacing: 5) {
                    factLabel(key); factValue(value).environment(\.layoutDirection, forceLTR ? .leftToRight : layoutDirection)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    factLabel(key); Spacer(minLength: 8)
                    factValue(value).environment(\.layoutDirection, forceLTR ? .leftToRight : layoutDirection)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
    private func factLabel(_ key: String) -> some View {
        Text(text(key)).font(PPBrandFont.regular(15, relativeTo: .body)).foregroundStyle(palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func factValue(_ value: String) -> some View {
        Text(value).font(PPBrandFont.bold(16, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
    }
    private func notice(_ key: String, symbol: String) -> some View {
        Label(text(key), systemImage: symbol).font(PPBrandFont.regular(16, relativeTo: .body))
            .foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private func action(_ key: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(text(key), systemImage: symbol).font(PPBrandFont.bold(16, relativeTo: .headline))
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
        }
        .foregroundStyle(palette.accentText).buttonStyle(PPProHomeControlStyle())
        .disabled(isSubmitting || isRefreshing)
    }
    private func recovery(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 28)).foregroundStyle(palette.accentText)
            Text(message).font(PPBrandFont.regular(18, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
            action("TryAgain", symbol: "arrow.clockwise") { reloadData() }
        }
        .padding(24).frame(maxWidth: 600, alignment: .leading)
    }

    private func startObserving() {
        stopObserving()
        // Rebinding cannot retain an in-flight mutation UI from another auth
        // session. Its server outcome is reconciled by the owned read instead.
        isSubmitting = false
        requestIntent = nil
        reviewedPayload = nil
        requestNotes = ""
        submissionError = nil
        pendingMessage = nil
        boundUID = PPDeliveryCompanyService.currentAccountUID()
        records = []; selectedRecord = nil; availablePlans = []; lifecycleState = nil
        isLoading = true; errorMessage = nil
        let generation = observationGeneration
        let uid = boundUID
        let registration = PPProviderApplicationManager.shared().observeProviderState(forCurrentUser: { state, _ in
            guard generation == observationGeneration, uid == PPDeliveryCompanyService.currentAccountUID(),
                  state?.uid == uid, state?.initialDataAuthoritative == true else { return }
            lifecycleState = state
            if !isRefreshing { reloadData() }
        })
        cancelObservation = { registration.remove() }
        reloadData()
    }
    private func stopObserving() {
        observationGeneration = UUID(); requestGeneration = UUID()
        submissionGeneration = UUID()
        cancelObservation?(); cancelObservation = nil
        isRefreshing = false
    }
    private func reloadData(completion: (() -> Void)? = nil) {
        guard !isRefreshing, !isSubmitting else { completion?(); return }
        let uid = boundUID
        guard !uid.isEmpty, uid == PPDeliveryCompanyService.currentAccountUID() else {
            records = []; selectedRecord = nil; isLoading = false
            errorMessage = text("ProSubscriptions_AccountChanged"); completion?(); return
        }
        if workforceOnly && selectedProfileID == nil {
            records = []; isLoading = false; errorMessage = nil; completion?(); return
        }
        isRefreshing = true
        requestGeneration = UUID()
        let generation = requestGeneration
        if let profileID = selectedProfileID {
            PPProviderApplicationManager.shared().fetchSubscriptionOptions(forProfileID: profileID) { record, plans, error in
                defer { completion?() }
                guard generation == requestGeneration, uid == boundUID, uid == PPDeliveryCompanyService.currentAccountUID() else { return }
                isLoading = false; isRefreshing = false
                guard let record, record.userID == uid, record.profile.profileID == profileID, error == nil else {
                    selectedRecord = nil; availablePlans = []
                    errorMessage = text("ProSubscriptions_Unavailable"); return
                }
                selectedRecord = record
                availablePlans = (plans ?? []).map { plan in
                    PPSubscriptionPlanOption(id: plan.planID, title: plan.localizedName(), subtitle: plan.localizedDescriptionText(),
                        priceLine: plan.localizedPriceLine(), planHash: plan.subscriptionPlanHash,
                        isPercentagePricing: plan.costType == .percentage, recommended: plan.recommended)
                }
                errorMessage = nil
            }
        } else {
            PPProviderApplicationManager.shared().fetchOwnedSubscriptions { subscriptions, error in
                defer { completion?() }
                guard generation == requestGeneration, uid == boundUID, uid == PPDeliveryCompanyService.currentAccountUID() else { return }
                isLoading = false; isRefreshing = false
                records = (subscriptions ?? []).filter { $0.userID == uid }
                errorMessage = error == nil ? nil : text("ProSubscription_LoadFailed")
            }
        }
    }

    private func prepareRequest(_ record: PPProviderOwnedSubscription, action: String, plan: PPSubscriptionPlanOption?) {
        guard record.userID == boundUID, boundUID == PPDeliveryCompanyService.currentAccountUID(),
              record.profile.profileID == selectedProfileID, record.requestActions.contains(action) else { return }
        requestNotes = ""; submissionError = nil; reviewedPayload = nil
        submissionGeneration = UUID()
        requestIntent = PPSubscriptionRequestIntent(profileID: record.profile.profileID, action: action,
            planID: plan?.id ?? "", planHash: plan?.planHash ?? "", version: record.version,
            title: providerTitle(record), planTitle: plan?.title ?? title(record))
    }
    private func requestComposer(_ intent: PPSubscriptionRequestIntent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(text(intent.action == "renew" ? "ProSubscriptions_RequestRenewal" : "ProSubscriptions_RequestPlan"))
                        .font(PPBrandFont.bold(28, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                    Text(intent.title).font(PPBrandFont.medium(16, relativeTo: .subheadline)).foregroundStyle(palette.secondary)
                    Text(intent.planTitle).font(PPBrandFont.bold(23, relativeTo: .title3))
                    notice("ProSubscriptions_ReviewRequired", symbol: "checkmark.shield")
                    Text(text("ProSubscriptions_Notes")).font(PPBrandFont.bold(16, relativeTo: .headline))
                    TextEditor(text: $requestNotes)
                        .font(PPBrandFont.regular(17, relativeTo: .body)).frame(minHeight: 120)
                        .padding(10).background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel(text("ProSubscriptions_Notes"))
                        .disabled(isSubmitting || reviewedPayload != nil)
                        .onChange(of: requestNotes) { _, _ in
                            while requestNotes.utf16.count > 500 { requestNotes.removeLast() }
                        }
                    Text(String(format: text("ProSubscriptions_NotesCount"), requestNotes.utf16.count))
                        .font(PPBrandFont.regular(13, relativeTo: .caption)).foregroundStyle(palette.secondary)
                    if let submissionError {
                        Label(submissionError, systemImage: "exclamationmark.circle")
                            .font(PPBrandFont.medium(16, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(24)
            }
            VStack(spacing: 8) {
                Button { submit(intent) } label: {
                    HStack {
                        if isSubmitting { ProgressView() }
                        Text(text(reviewedPayload == nil ? "ProSubscriptions_SubmitRequest" : "ProSubscriptions_RetrySameRequest"))
                            .font(PPBrandFont.bold(18, relativeTo: .headline))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                }.disabled(isSubmitting).accessibilityIdentifier("pro.subscription.request.submit")
                Button(text("Cancel")) { requestIntent = nil }.frame(minHeight: 44).disabled(isSubmitting)
            }.foregroundStyle(palette.accentText).padding(20)
        }
        .background(palette.canvas).foregroundStyle(palette.text)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .interactiveDismissDisabled(isSubmitting)
    }
    private func submit(_ intent: PPSubscriptionRequestIntent) {
        guard !isSubmitting, boundUID == PPDeliveryCompanyService.currentAccountUID(), intent.profileID == selectedProfileID else { return }
        let uid = boundUID
        let generation = submissionGeneration
        if reviewedPayload == nil {
            reviewedPayload = ["profileId": intent.profileID, "action": intent.action, "planId": intent.planID,
                "expectedPlanHash": intent.planHash, "expectedVersion": intent.version, "idempotencyKey": intent.id,
                "notes": requestNotes.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        guard let payload = reviewedPayload else { return }
        isSubmitting = true; submissionError = nil
        PPProviderApplicationManager.shared().submitSubscriptionRequest(payload) { result, error in
            guard generation == submissionGeneration, uid == boundUID, uid == PPDeliveryCompanyService.currentAccountUID() else { return }
            isSubmitting = false
            if let error, PPProviderApplicationManager.isDefinitiveSubscriptionRequestError(error as NSError) {
                pendingMessage = (text("ProSubscriptions_RequestNotAcceptedTitle"), text("ProSubscriptions_RequestNotAcceptedBody"))
                requestIntent = nil; reviewedPayload = nil
                reloadData()
                return
            }
            guard error == nil, result?["ok"] as? Bool == true else {
                submissionError = text("ProSubscriptions_RequestFailed"); return
            }
            pendingMessage = (text("ProSubscriptions_RequestSentTitle"), text("ProSubscriptions_RequestSentBody"))
            requestIntent = nil; reviewedPayload = nil
            reloadData()
        }
    }
    private func showPendingMessage() {
        guard let message = pendingMessage, boundUID == PPDeliveryCompanyService.currentAccountUID() else { return }
        pendingMessage = nil
        onMessage(message.title, message.body)
    }
}

// Existing Objective-C entry point is retained. UIKit owns every profile push.
@objc(PPProviderSubscriptionStudioHostingController)
public final class PPProviderSubscriptionStudioHostingController: UIViewController {
    @objc public var selectedSubscriptionProfileID: String?
    @objc public var workforceOnly = false
    @objc public var onSelectSubscription: ((String) -> Void)?
    @objc public var onApplications: ((Bool) -> Void)?
    @objc public var onMessage: ((String, String) -> Void)?
    private var onCloseHandler: (() -> Void)?
    private var onUpgradePlanHandler: ((PPProviderType) -> Void)?

    @objc public init(onUpgradePlan: ((PPProviderType) -> Void)? = nil, onClose: (() -> Void)? = nil) {
        onUpgradePlanHandler = onUpgradePlan
        onCloseHandler = onClose
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public override func viewDidLoad() {
        super.viewDidLoad()
        PPBrandFont.registerIfNeeded()
        view.backgroundColor = UIColor.ppBackground
        let studio = PPProviderSubscriptionStudioView(selectedProfileID: selectedSubscriptionProfileID, workforceOnly: workforceOnly,
            onSelect: { [weak self] in self?.onSelectSubscription?($0) },
            onApplications: { [weak self] in self?.onApplications?($0) },
            onMessage: { [weak self] in self?.onMessage?($0, $1) },
            onClose: { [weak self] in self?.onCloseHandler?() })
        let host = UIHostingController(rootView: studio)
        addChild(host); host.view.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
