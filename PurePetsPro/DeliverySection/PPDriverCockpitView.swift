//
//  PPDriverCockpitView.swift
//  PurePetsPro
//
//  "Next-Step Instrument" driver cockpit (NextGen v7 selected direction):
//  one owned delivery, a four-step rail and one attested action in a pinned
//  dock. Success is shown only after the backend confirms the command.
//

import SwiftUI
import UIKit

// MARK: - Labels

private func ppActionTitle(_ code: String) -> String {
    ppDriverText("DriverCockpit_Action_\(code)")
}

private func ppActionConsequence(_ action: PPDriverTaskAction, task: PPDriverTask) -> String {
    if action.code == "CONFIRM_PAYMENT", let amount = task.cash?.amount {
        return ppDriverFormat("DriverCockpit_Consequence_CONFIRM_PAYMENT_Format", ppDriverMoney(amount, currency: task.cash?.currency ?? ""))
    }
    return ppDriverText("DriverCockpit_Consequence_\(action.code)")
}

private func ppStatusText(_ status: String) -> String {
    let known: Set<String> = ["delivery_requested", "accepted_by_company", "offered", "delivery_assigned",
                              "awaiting_handover", "assigned_to_driver", "handed_over", "picked_up", "in_transit",
                              "delivered", "payment_pending", "payment_confirmed", "completed", "cancelled",
                              "failed", "returned", "rejected", "expired", "customer_unavailable",
                              "address_issue", "payment_issue", "return_required", "returning"]
    return ppDriverText(known.contains(status) ? "DriverCockpit_Status_\(status)" : "DriverCockpit_Status_unknown")
}

private func ppOrderTitle(_ task: PPDriverTask) -> String {
    task.orderNumber.isEmpty
        ? ppDriverText("DriverCockpit_Delivery_Generic")
        : ppDriverFormat("DriverCockpit_Order_Format", ppDriverIsolated("#\(task.orderNumber)"))
}

private func ppReasonText(_ reason: String) -> String {
    let known: Set<String> = ["ACCOUNT_NOT_ACTIVE", "ASSIGNMENTS_PAUSED", "OFFLINE", "PRESENCE_STALE",
                              "ON_BREAK", "OFF_SHIFT", "CAPACITY_EXCEEDED"]
    return known.contains(reason) ? ppDriverText("DriverCockpit_Reason_\(reason)") : ""
}

func ppDriverRestrictionText(_ reason: String) -> String {
    let known: Set<String> = ["WORKFORCE_DRIVER_GRANT_REQUIRED", "OFFICIAL_DELIVERY_GRANT_REQUIRED", "ROLE_NOT_RECOGNIZED"]
    return ppDriverText(known.contains(reason) ? "DriverCockpit_Restricted_\(reason)" : "DriverCockpit_NoWorkspace_Body")
}

private func ppContextTitle(_ context: PPDriverContext) -> String {
    if context.kind == .officialDriver { return ppDriverText("DriverCockpit_Context_Official") }
    let name = context.companyName.isEmpty ? context.companyID : context.companyName
    return ppDriverFormat("DriverCockpit_Context_Partner_Format", ppDriverIsolated(name))
}

private func ppTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: Language.currentLanguageCode())
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return ppDriverIsolated(formatter.string(from: date))
}

private func ppPhoneURL(_ phone: String) -> URL? {
    var digits = ""
    for character in ppDriverASCIIDigits(phone) where character.isNumber || (character == "+" && digits.isEmpty) {
        digits.append(character)
    }
    return digits.count >= 6 ? URL(string: "tel:\(digits)") : nil
}

private func ppMapsURL(_ address: PPDriverAddress) -> URL? {
    guard !address.mapQuery.isEmpty else { return nil }
    var components = URLComponents(string: "https://maps.apple.com/")
    components?.queryItems = [URLQueryItem(name: "daddr", value: address.mapQuery),
                              URLQueryItem(name: "dirflg", value: "d")]
    return components?.url
}

// MARK: - Button styles

private struct PPDriverPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AdminType.headlineBold)
            .foregroundStyle(enabled ? Color.white : AdminSurface.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, AdminSpacing.base)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous)
                    .fill(enabled ? AdminSurface.primary : AdminSurface.control)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous))
    }
}

private struct PPDriverSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AdminType.calloutBold)
            .foregroundStyle(AdminSurface.primary)
            .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.comfortable)
            .padding(.horizontal, AdminSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .fill(AdminSurface.primary.opacity(configuration.isPressed ? 0.16 : 0.09))
            )
            .contentShape(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous))
    }
}

// MARK: - Cockpit

/// One confirmed-state availability interaction for Home and the cockpit.
/// It never enables an account or overrides the dispatcher's assignment pause.
struct PPDriverAvailabilityControl: View {
    @ObservedObject var store: PPDriverCockpitStore
    @State private var confirmsGoingOffline = false

    private var online: Bool { store.availability?.online == true }
    private var isBusy: Bool { store.isSubmitting || store.isVerifying }
    private var statusKey: String {
        if case .noWorkspace = store.phase { return "DriverAvailability_AccessRequired" }
        guard store.availability != nil, !store.isStale else { return "DriverCockpit_Presence_Unknown" }
        return online ? "DriverCockpit_Presence_Online" : "DriverCockpit_Presence_Offline"
    }
    private var hint: String {
        if case .noWorkspace(let reason) = store.phase { return ppDriverRestrictionText(reason) }
        guard let availability = store.availability, !store.isStale else {
            return ppDriverText("DriverCockpit_Presence_Unavailable")
        }
        if let reason = availability.readinessReasons.first(where: { $0 != "OFFLINE" }) {
            let text = ppReasonText(reason)
            return text.isEmpty ? ppDriverText("DriverAvailability_RestrictedHint") : text
        }
        return ppDriverText(online ? "DriverAvailability_OnlineHint" : "DriverAvailability_OfflineHint")
    }
    private var statusTint: Color {
        guard let availability = store.availability, !store.isStale else { return AdminSurface.amber }
        if availability.readinessReasons.contains(where: { $0 != "OFFLINE" }) { return AdminSurface.amber }
        return online ? AdminSurface.emerald : AdminSurface.secondaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            HStack(alignment: .top, spacing: AdminSpacing.md) {
                Image(systemName: online ? "antenna.radiowaves.left.and.right" : "power")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 44, height: 44)
                    .background(statusTint.opacity(0.1), in: RoundedRectangle(cornerRadius: AdminRadius.medium))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ppDriverText("DriverAvailability_Title"))
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.secondaryText)
                    Text(ppDriverText(statusKey))
                        .font(AdminType.headlineBold)
                        .foregroundStyle(AdminSurface.primaryText)
                    Text(hint)
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            if store.selectedContext != nil && !store.isStale {
                Label(ppDriverText(store.canSelfAcceptOrders ? "Delivery_Driver_Acceptance_Self" : "Delivery_Driver_Acceptance_Assigned"),
                      systemImage: "lock.shield")
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("driver.acceptance.mode")
            }

            Button {
                if online && (store.availability?.activeDeliveryCount ?? 0) > 0 {
                    confirmsGoingOffline = true
                } else {
                    store.setOnline(!online)
                }
            } label: {
                HStack(spacing: AdminSpacing.sm) {
                    if isBusy {
                        ProgressView().tint(AdminSurface.primary)
                    } else {
                        Image(systemName: online ? "pause.circle" : "power")
                    }
                    Text(ppDriverText(isBusy ? "DriverAvailability_Updating"
                                      : (online ? "DriverCockpit_Presence_GoOffline" : "DriverCockpit_Presence_GoOnline")))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(AdminType.calloutBold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AdminSpacing.base)
                .padding(.vertical, AdminSpacing.md)
                .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.comfortable)
                .foregroundStyle(AdminSurface.primary)
                .background(AdminSurface.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: AdminRadius.button))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canChangeAvailability)
            .opacity(store.canChangeAvailability || isBusy ? 1 : 0.5)
            .accessibilityIdentifier("driver.availability.toggle")
            .accessibilityValue(ppDriverText(statusKey))
            .accessibilityHint(ppDriverText("DriverCockpit_Presence_Accessibility"))

            if store.isStale || store.availability == nil {
                Button {
                    if store.selectedContext == nil { store.resolveContexts() }
                    else { store.refreshAvailability() }
                } label: {
                    Label(ppDriverText("DriverAvailability_CheckStatus"), systemImage: "arrow.clockwise")
                        .font(AdminType.calloutBold)
                        .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.minimum)
                }
                .foregroundStyle(AdminSurface.primary)
                .disabled(store.isSubmitting || store.isRefreshing || store.isResolvingContexts)
            }
        }
        .padding(AdminSpacing.base)
        .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        .overlay(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.5))
        .alert(ppDriverText("DriverCockpit_Offline_Confirm_Title"), isPresented: $confirmsGoingOffline) {
            Button(ppDriverText("DriverCockpit_Cancel"), role: .cancel) {}
            Button(ppDriverText("DriverCockpit_Offline_Confirm_Action")) { store.setOnline(false) }
        } message: {
            Text(ppDriverText("DriverCockpit_Offline_Confirm_Body"))
        }
    }
}

struct PPDriverCockpitView: View {
    @ObservedObject var store: PPDriverCockpitStore
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmation: PPDriverConfirmation?
    @State private var showsContextChooser = false
    @State private var showsHistory = false

    private var layoutDirection: LayoutDirection { Language.isRTL() ? .rightToLeft : .leftToRight }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(AdminSurface.hairline).frame(height: 0.5)
            content
        }
        .background(AdminSurface.background.ignoresSafeArea())
        .environment(\.layoutDirection, layoutDirection)
        .environment(\.locale, Locale(identifier: Language.currentLanguageCode()))
        .sheet(item: $confirmation) { request in
            PPDriverConfirmSheet(task: request.task, action: request.action) { inputs in
                store.perform(request.action, on: request.task, inputs: inputs)
            }
            .environment(\.layoutDirection, layoutDirection)
        }
        .sheet(isPresented: $showsContextChooser) {
            contextChooserSheet
                .environment(\.layoutDirection, layoutDirection)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: AdminSpacing.sm) {
            Button(action: onClose) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: AdminTouchTarget.minimum, height: AdminTouchTarget.minimum)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(AdminSurface.primaryText)
            .accessibilityLabel(ppDriverText("DriverCockpit_Back"))

            VStack(alignment: .leading, spacing: 2) {
                Text(ppDriverText("DriverCockpit_Title"))
                    .font(AdminType.headline)
                    .foregroundStyle(AdminSurface.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if let context = store.selectedContext {
                    Text(ppContextTitle(context))
                        .font(AdminType.caption1)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.contexts.count > 1 && store.phase == .ready {
                Button { showsContextChooser = true } label: {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: AdminTouchTarget.minimum, height: AdminTouchTarget.minimum)
                        .contentShape(Rectangle())
                }
                .disabled(!store.canSwitchContext)
                .accessibilityLabel(ppDriverText("DriverCockpit_SwitchWorkspace"))
            }

            Button { store.refresh() } label: {
                Group {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(width: AdminTouchTarget.minimum, height: AdminTouchTarget.minimum)
                .contentShape(Rectangle())
            }
            .disabled(store.isRefreshing || store.phase != .ready)
            .accessibilityLabel(ppDriverText("DriverCockpit_Refresh"))
        }
        .foregroundStyle(AdminSurface.primary)
        .padding(.horizontal, AdminSpacing.sm)
        .padding(.vertical, AdminSpacing.xs)
        .background(AdminSurface.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AdminSpacing.base) {
                switch store.phase {
                case .resolving:
                    loadingCard
                case .signedOut:
                    messageCard(symbol: "person.crop.circle.badge.exclamationmark",
                                title: ppDriverText("DriverCockpit_SignedOut_Title"),
                                body: ppDriverText("DriverCockpit_SignedOut_Body"),
                                action: nil)
                case .noWorkspace(let reason):
                    if let notice = store.notice { noticeBanner(notice) }
                    if reason.isEmpty {
                        messageCard(symbol: "person.crop.circle.badge.questionmark",
                                    title: ppDriverText("DriverCockpit_NoWorkspace_Title"),
                                    body: ppDriverRestrictionText(reason),
                                    action: (ppDriverText("DriverCockpit_CheckAgain"), { store.resolveContexts() }))
                    } else {
                        PPDriverAvailabilityControl(store: store)
                    }
                case .accessEnded:
                    messageCard(symbol: "lock.shield",
                                title: ppDriverText("DriverCockpit_AccessEnded_Title"),
                                body: ppDriverText("DriverCockpit_AccessEnded_Body"),
                                action: (ppDriverText("DriverCockpit_CheckAgain"), { store.resolveContexts() }))
                case .loadFailed:
                    if let notice = store.notice { noticeBanner(notice) }
                    messageCard(symbol: "wifi.exclamationmark",
                                title: ppDriverText("DriverCockpit_LoadFailed_Title"),
                                body: ppDriverText("DriverCockpit_LoadFailed_Body"),
                                action: (ppDriverText("DriverCockpit_CheckAgain"), { store.resolveContexts() }))
                case .choosingContext:
                    contextChoices
                case .ready:
                    readyContent
                }
            }
            .padding(.horizontal, AdminSpacing.screenMargin)
            .padding(.vertical, AdminSpacing.base)
        }
        .safeAreaInset(edge: .bottom) {
            if store.phase == .ready {
                dock
            }
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        presenceCard
        if let notice = store.notice {
            noticeBanner(notice)
        }
        syncLine
        if let task = store.focusedTask {
            PPDriverMissionCard(task: task)
                .id("\(task.id)|\(task.status)|\(task.revision)")
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: task.status)
        } else {
            idleCard
        }
        if !store.otherActiveTasks.isEmpty {
            sectionTitle(ppDriverText("DriverCockpit_Section_AlsoAssigned"))
            ForEach(store.otherActiveTasks) { task in
                taskRow(task, subtitle: ppStatusText(task.status))
            }
        }
        if !store.visibleOffers.isEmpty {
            sectionTitle(ppDriverText("DriverCockpit_Section_Offers"))
            ForEach(store.visibleOffers) { task in
                taskRow(task, subtitle: task.dropoff.secondary.isEmpty
                        ? ppDriverText("DriverCockpit_Offer_Review")
                        : ppDriverFormat("DriverCockpit_Offer_Area_Format", task.dropoff.secondary))
            }
        }
        if store.canLoadMoreActive {
            Button { store.loadMoreActive() } label: {
                HStack {
                    if store.isLoadingMoreActive { ProgressView() }
                    Text(ppDriverText("DriverCockpit_LoadMoreAssigned"))
                }
            }
            .buttonStyle(PPDriverSecondaryButtonStyle())
            .disabled(store.isLoadingMoreActive || store.isRefreshing || !store.canSwitchContext)
        }
        historySection
    }

    // MARK: Presence

    private var presenceCard: some View {
        PPDriverAvailabilityControl(store: store)
    }

    private var syncLine: some View {
        let text: String
        if let date = store.lastConfirmedAt {
            text = ppDriverFormat(store.isStale ? "DriverCockpit_Sync_Stale_Format" : "DriverCockpit_Sync_Updated_Format", ppTimeText(date))
        } else {
            text = ppDriverText(store.isRefreshing ? "DriverCockpit_Loading_Tasks" : "DriverCockpit_Sync_Never")
        }
        return Label(text, systemImage: store.isStale ? "exclamationmark.arrow.triangle.2.circlepath" : "checkmark.circle")
            .font(AdminType.caption1)
            .foregroundStyle(store.isStale ? AdminSurface.amber : AdminSurface.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: States

    private var loadingCard: some View {
        HStack(spacing: AdminSpacing.md) {
            ProgressView()
            Text(ppDriverText("DriverCockpit_Loading"))
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }

    private var idleCard: some View {
        let availability = store.availability
        let paused = availability?.assignmentsPaused ?? false
        let online = availability?.online ?? false
        let titleKey = paused ? "DriverCockpit_Idle_Paused_Title" : (online ? "DriverCockpit_Idle_Ready_Title" : "DriverCockpit_Idle_Offline_Title")
        let bodyKey = paused ? "DriverCockpit_Idle_Paused_Body" : (online ? "DriverCockpit_Idle_Ready_Body" : "DriverCockpit_Idle_Offline_Body")
        return VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            Image(systemName: paused ? "pause.circle" : (online ? "checkmark.seal" : "moon.zzz"))
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(paused ? AdminSurface.amber : AdminSurface.primary)
                .accessibilityHidden(true)
            Text(ppDriverText(titleKey))
                .font(AdminType.title3)
                .foregroundStyle(AdminSurface.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(ppDriverText(bodyKey))
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AdminSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AdminRadius.hero, style: .continuous).fill(AdminSurface.card))
        .accessibilityElement(children: .combine)
    }

    private func messageCard(symbol: String, title: String, body: String, action: (String, () -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AdminSurface.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(AdminType.title3)
                .foregroundStyle(AdminSurface.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.0, action: action.1)
                    .buttonStyle(PPDriverSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AdminSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AdminRadius.hero, style: .continuous).fill(AdminSurface.card))
    }

    private func noticeBanner(_ notice: PPDriverNotice) -> some View {
        let tint: Color
        let symbol: String
        switch notice.tone {
        case .info: tint = AdminSurface.primary; symbol = "hourglass"
        case .success: tint = AdminSurface.emerald; symbol = "checkmark.circle.fill"
        case .warning: tint = AdminSurface.amber; symbol = "exclamationmark.triangle.fill"
        case .error: tint = AdminSurface.crimson; symbol = "xmark.octagon.fill"
        }
        return HStack(alignment: .top, spacing: AdminSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(notice.text)
                .font(AdminType.subheadlineBold)
                .foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if notice.tone != .info {
                Button { store.dismissNotice() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: AdminTouchTarget.minimum, height: AdminTouchTarget.minimum)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AdminSurface.secondaryText)
                .accessibilityLabel(ppDriverText("DriverCockpit_Dismiss"))
            }
        }
        .padding(.leading, AdminSpacing.md)
        .padding(.vertical, AdminSpacing.xs)
        .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous).fill(tint.opacity(0.1)))
        .accessibilityElement(children: .contain)
    }

    // MARK: Lists

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AdminType.footnoteBold)
            .foregroundStyle(AdminSurface.secondaryText)
            .padding(.top, AdminSpacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    private func taskRow(_ task: PPDriverTask, subtitle: String) -> some View {
        Button { store.focus(on: task) } label: {
            HStack(spacing: AdminSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ppOrderTitle(task))
                        .font(AdminType.headline)
                        .foregroundStyle(AdminSurface.primaryText)
                    Text(subtitle)
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(AdminSpacing.base)
            .frame(minHeight: AdminTouchTarget.comfortable)
            .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
            .contentShape(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(ppDriverText("DriverCockpit_Row_Hint"))
    }

    @ViewBuilder
    private var historySection: some View {
        Button {
            showsHistory.toggle()
            if showsHistory && !store.historyLoaded { store.loadHistory() }
        } label: {
            HStack {
                Text(ppDriverText("DriverCockpit_Section_History"))
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                Spacer()
                Image(systemName: showsHistory ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: AdminTouchTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(ppDriverText(showsHistory ? "DriverCockpit_Expanded" : "DriverCockpit_Collapsed"))
        if showsHistory {
            if !store.historyLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if store.history.isEmpty {
                Text(ppDriverText("DriverCockpit_History_Empty"))
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminSurface.secondaryText)
            } else {
                ForEach(store.history) { task in
                    HStack {
                        Text(ppOrderTitle(task)).font(AdminType.subheadline).foregroundStyle(AdminSurface.primaryText)
                        Spacer()
                        Text(ppStatusText(task.status)).font(AdminType.caption1Bold).foregroundStyle(AdminSurface.secondaryText)
                    }
                    .padding(.vertical, AdminSpacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Contexts

    private var contextChoices: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            Text(ppDriverText("DriverCockpit_ChooseWorkspace_Title"))
                .font(AdminType.title3)
                .foregroundStyle(AdminSurface.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(ppDriverText("DriverCockpit_ChooseWorkspace_Body"))
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(store.contexts) { context in
                Button { store.select(context) } label: { contextRow(context) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var contextChooserSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AdminSpacing.md) {
                    Text(ppDriverText("DriverCockpit_ChooseWorkspace_Body"))
                        .font(AdminType.body)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(store.contexts) { context in
                        Button {
                            showsContextChooser = false
                            store.select(context)
                        } label: { contextRow(context) }
                        .buttonStyle(.plain)
                        .disabled(!store.canSwitchContext)
                    }
                }
                .padding(AdminSpacing.screenMargin)
            }
            .background(AdminSurface.background)
            .navigationTitle(ppDriverText("DriverCockpit_ChooseWorkspace_Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ppDriverText("DriverCockpit_Cancel")) { showsContextChooser = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func contextRow(_ context: PPDriverContext) -> some View {
        let selected = store.selectedContext?.id == context.id
        return HStack(spacing: AdminSpacing.md) {
            Image(systemName: context.kind == .officialDriver ? "shield.lefthalf.filled" : "building.2")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AdminSurface.primary)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(ppContextTitle(context))
                .font(AdminType.headline)
                .foregroundStyle(AdminSurface.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(AdminSurface.primary)
                    .accessibilityHidden(true)
            }
        }
        .padding(AdminSpacing.base)
        .frame(minHeight: AdminTouchTarget.comfortable)
        .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        .contentShape(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    // MARK: Dock

    private enum DockState {
        case none
        case waiting
        case uncertain
        case action(PPDriverTask, PPDriverTaskAction)
        case blocked(PPDriverTask, String)
        case informational(PPDriverTask, String)
        case awaitingStoreHandover
        case goOnline
    }

    private var dockState: DockState {
        if store.isSubmitting || store.isVerifying { return .waiting }
        if store.uncertainCommand != nil { return .uncertain }
        guard let task = store.focusedTask else {
            if let availability = store.availability, !availability.online, !availability.assignmentsPaused {
                return .goOnline
            }
            return .none
        }
        if task.awaitsStoreHandover { return .awaitingStoreHandover }
        guard let action = task.primaryAction else {
            let key: String
            if task.stage >= .delivered && task.stage != .unknown {
                key = "DriverCockpit_Wait_Dispatch"
            } else {
                key = "DriverCockpit_Wait_Generic"
            }
            return .informational(task, ppDriverText(key))
        }
        if action.code == "CLAIM" && !store.canSelfAcceptOrders {
            return .blocked(task, ppDriverText("Delivery_Driver_Acceptance_Managed"))
        }
        if action.code == "DELIVER" && task.authority != .fulfillmentV1 &&
            (task.proof.photoRequired || task.proof.signatureRequired) {
            return .blocked(task, ppDriverText("DriverCockpit_Blocked_Proof"))
        }
        let cashNeeded = action.code == "CONFIRM_PAYMENT" ||
            (action.code == "DELIVER" && task.authority != .fulfillmentV1 && (task.cash?.required ?? false) && !(task.cash?.collected ?? false))
        if cashNeeded && ((task.cash?.amount ?? 0) <= 0 || (action.code == "CONFIRM_PAYMENT" && (task.cash?.currency.count ?? 0) != 3)) {
            return .blocked(task, ppDriverText("DriverCockpit_Blocked_Cash"))
        }
        return .action(task, action)
    }

    private var dock: some View {
        VStack(spacing: AdminSpacing.sm) {
            dockPrimary
            dockSecondary
        }
        .padding(.horizontal, AdminSpacing.screenMargin)
        .padding(.top, AdminSpacing.md)
        .padding(.bottom, AdminSpacing.sm)
        .background(
            AdminSurface.surface
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var dockPrimary: some View {
        switch dockState {
        case .none:
            EmptyView()
        case .waiting:
            Button {} label: {
                HStack(spacing: AdminSpacing.sm) {
                    ProgressView()
                    Text(ppDriverText("DriverCockpit_Notice_Waiting"))
                }
            }
            .buttonStyle(PPDriverPrimaryButtonStyle(enabled: false))
            .disabled(true)
        case .uncertain:
            Button { store.retryUncertainCommand() } label: {
                Text(ppDriverText("DriverCockpit_RetrySafely"))
            }
            .buttonStyle(PPDriverPrimaryButtonStyle())
            .accessibilityHint(ppDriverText("DriverCockpit_Notice_Unconfirmed"))
            Button(ppDriverText("DriverCockpit_CheckLatest")) { store.discardUncertainCommand() }
                .buttonStyle(PPDriverSecondaryButtonStyle())
        case .action(let task, let action):
            Button {
                if ["CLAIM", "DELIVER", "CONFIRM_PAYMENT", "COMPLETE"].contains(action.code) {
                    confirmation = PPDriverConfirmation(task: task, action: action)
                } else {
                    store.perform(action, on: task)
                }
            } label: {
                VStack(spacing: 2) {
                    Text(ppActionTitle(action.code))
                    Text(ppActionConsequence(action, task: task))
                        .font(AdminType.caption1)
                        .opacity(0.88)
                }
                .padding(.vertical, AdminSpacing.xs)
            }
            .buttonStyle(PPDriverPrimaryButtonStyle())
            .accessibilityLabel(ppActionTitle(action.code))
            .accessibilityHint(ppActionConsequence(action, task: task))
        case .awaitingStoreHandover:
            Button { store.refresh() } label: {
                VStack(spacing: 4) {
                    HStack(spacing: AdminSpacing.sm) {
                        if store.isRefreshing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(ppDriverText(store.isRefreshing
                                          ? "DriverCockpit_Handover_Checking"
                                          : "DriverCockpit_Handover_Check"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(ppDriverText("DriverCockpit_Wait_StoreHandover"))
                        .font(AdminType.caption1)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(0.88)
                }
                .padding(.vertical, AdminSpacing.xs)
            }
            .buttonStyle(PPDriverPrimaryButtonStyle(enabled: !store.isRefreshing))
            .disabled(store.isRefreshing)
            .accessibilityLabel(ppDriverText("DriverCockpit_Handover_Check"))
            .accessibilityValue(ppDriverText(store.isRefreshing
                                             ? "DriverCockpit_Handover_Checking"
                                             : "DriverCockpit_Wait_StoreHandover"))
            .accessibilityHint(ppDriverText("DriverCockpit_Handover_Check_Hint"))
        case .blocked(_, let reason), .informational(_, let reason):
            Label(reason, systemImage: "info.circle")
                .font(AdminType.subheadline)
                .foregroundStyle(AdminSurface.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AdminSpacing.md)
                .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous).fill(AdminSurface.backgroundSecondary))
                .accessibilityElement(children: .combine)
            if store.selectedContext?.kind == .partnerDriver && store.dispatchPhone == nil {
                Text(ppDriverText("DriverCockpit_DispatchContactMissing"))
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(ppDriverText("DriverCockpit_Back"), action: onClose)
                    .buttonStyle(PPDriverSecondaryButtonStyle())
            }
        case .goOnline:
            Button { store.setOnline(true) } label: {
                Text(ppDriverText("DriverCockpit_Presence_GoOnline"))
            }
            .buttonStyle(PPDriverPrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private var dockSecondary: some View {
        if let task = store.focusedTask {
            let target = task.stage <= .toPickup ? task.pickup : task.dropoff
            let mapsURL = task.stage == .unknown ? nil : ppMapsURL(target)
            let customerURL = task.mine && task.stage >= .collected && task.stage != .unknown ? ppPhoneURL(task.customerPhone) : nil
            let dispatchURL = store.dispatchPhone.flatMap(ppPhoneURL)
            if mapsURL != nil || customerURL != nil || dispatchURL != nil {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: AdminSpacing.sm))
                    : AnyLayout(HStackLayout(spacing: AdminSpacing.sm))
                layout {
                    if let mapsURL {
                        Button { UIApplication.shared.open(mapsURL) } label: {
                            Label(ppDriverText("DriverCockpit_Navigate"), systemImage: "location.fill")
                        }
                        .buttonStyle(PPDriverSecondaryButtonStyle())
                        .accessibilityHint(ppDriverText(task.stage <= .toPickup ? "DriverCockpit_Pickup" : "DriverCockpit_Dropoff"))
                    }
                    if let customerURL {
                        Button { UIApplication.shared.open(customerURL) } label: {
                            Label(ppDriverText("DriverCockpit_CallCustomer"), systemImage: "phone.fill")
                        }
                        .buttonStyle(PPDriverSecondaryButtonStyle())
                    }
                    if let dispatchURL {
                        Button { UIApplication.shared.open(dispatchURL) } label: {
                            Label(ppDriverText("DriverCockpit_CallDispatch"), systemImage: "headset")
                        }
                        .buttonStyle(PPDriverSecondaryButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Mission card

private struct PPDriverMissionCard: View {
    let task: PPDriverTask

    private var emphasizesPickup: Bool { task.stage <= .toPickup }

    var body: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.base) {
            HStack(alignment: .firstTextBaseline, spacing: AdminSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ppOrderTitle(task))
                        .font(AdminType.title3)
                        .foregroundStyle(AdminSurface.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text(ppStatusText(task.status))
                        .font(AdminType.subheadlineBold)
                        .foregroundStyle(task.mine ? AdminSurface.primary : AdminSurface.amber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let cash = task.cash, cash.required {
                    cashBadge(cash)
                }
            }

            if task.mine {
                PPDriverStepRail(stage: task.stage)
            }

            if task.awaitsStoreHandover {
                VStack(alignment: .leading, spacing: AdminSpacing.sm) {
                    Label(ppDriverText("DriverCockpit_Handover_Next"), systemImage: "shippingbox")
                        .font(AdminType.calloutBold)
                        .foregroundStyle(AdminSurface.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text(ppDriverText("DriverCockpit_Handover_Instructions"))
                        .font(AdminType.subheadline)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AdminSpacing.md)
                .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .fill(AdminSurface.backgroundSecondary))
                .accessibilityElement(children: .combine)
            }

            addressBlock(title: ppDriverText("DriverCockpit_Pickup"), symbol: "shippingbox",
                         address: task.pickup, emphasized: emphasizesPickup)
            addressBlock(title: ppDriverText("DriverCockpit_Dropoff"), symbol: "house",
                         address: task.dropoff, emphasized: !emphasizesPickup)

            if task.mine && !task.customerName.isEmpty {
                Label(ppDriverIsolated(task.customerName), systemImage: "person.fill")
                    .font(AdminType.subheadline)
                    .foregroundStyle(AdminSurface.primaryText)
                    .accessibilityLabel(ppDriverFormat("DriverCockpit_Customer_Format", task.customerName))
            }

            if task.mine && !task.proof.isEmpty && task.authority != .fulfillmentV1 {
                proofRow
            }
        }
        .padding(AdminSpacing.cardPadding)
        .background(RoundedRectangle(cornerRadius: AdminRadius.hero, style: .continuous).fill(AdminSurface.card))
        .overlay(RoundedRectangle(cornerRadius: AdminRadius.hero, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }

    private func cashBadge(_ cash: PPDriverCash) -> some View {
        let text: String
        if cash.collected {
            text = ppDriverText("DriverCockpit_CashCollected")
        } else if let amount = cash.amount {
            text = ppDriverFormat("DriverCockpit_CashDue_Format", ppDriverMoney(amount, currency: cash.currency))
        } else {
            text = ppDriverText("DriverCockpit_CashDue_Unknown")
        }
        return Label(text, systemImage: "banknote")
            .font(AdminType.caption1Bold)
            .foregroundStyle(cash.collected ? AdminSurface.emerald : AdminSurface.amber)
            .padding(.horizontal, AdminSpacing.sm)
            .padding(.vertical, AdminSpacing.xs)
            .background(Capsule().fill((cash.collected ? AdminSurface.emerald : AdminSurface.amber).opacity(0.12)))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func addressBlock(title: String, symbol: String, address: PPDriverAddress, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(AdminType.footnoteBold)
                .foregroundStyle(emphasized ? AdminSurface.primary : AdminSurface.secondaryText)
            Text(address.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : address.primary)
                .font(emphasized ? AdminType.bodyBold : AdminType.body)
                .foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if !address.secondary.isEmpty {
                Text(address.secondary)
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AdminSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                .fill(emphasized ? AdminSurface.primary.opacity(0.07) : AdminSurface.backgroundSecondary)
        )
        .accessibilityElement(children: .combine)
    }

    private var proofRow: some View {
        var items: [String] = []
        if task.proof.receiverNameRequired { items.append(ppDriverText("DriverCockpit_Proof_Name")) }
        if task.proof.otpRequired { items.append(ppDriverText("DriverCockpit_Proof_OTP")) }
        if task.proof.photoRequired { items.append(ppDriverText("DriverCockpit_Proof_Photo")) }
        if task.proof.signatureRequired { items.append(ppDriverText("DriverCockpit_Proof_Signature")) }
        return VStack(alignment: .leading, spacing: 4) {
            Text(ppDriverText("DriverCockpit_Proof_Title"))
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminSurface.secondaryText)
            Text(items.joined(separator: " · "))
                .font(AdminType.subheadline)
                .foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PPDriverStepRail: View {
    let stage: PPDriverStage

    private let titles = ["DriverCockpit_Step_Collect", "DriverCockpit_Step_Transit",
                          "DriverCockpit_Step_Deliver", "DriverCockpit_Step_Close"]

    private var current: Int { min(stage.railIndex, titles.count - 1) }
    private var allDone: Bool { stage.railIndex >= titles.count }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(0..<titles.count, id: \.self) { index in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(fill(for: index))
                        .frame(height: 6)
                    Text(ppDriverText(titles[index]))
                        .font(AdminType.caption2Medium)
                        .foregroundStyle(index == current && !allDone ? AdminSurface.primaryText : AdminSurface.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ppDriverFormat("DriverCockpit_Step_Accessibility_Format",
                                           current + 1, titles.count, ppDriverText(titles[current])))
    }

    private func fill(for index: Int) -> Color {
        if allDone || index < current { return AdminSurface.emerald }
        if index == current { return AdminSurface.primary }
        return AdminSurface.hairline
    }
}

// MARK: - Confirmation

private struct PPDriverConfirmation: Identifiable {
    let id = UUID()
    let task: PPDriverTask
    let action: PPDriverTaskAction
}

private struct PPDriverConfirmSheet: View {
    let task: PPDriverTask
    let action: PPDriverTaskAction
    let onConfirm: (PPDriverCommandInputs) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var receiverName = ""
    @State private var otp = ""
    @State private var isSubmitting = false

    private var needsName: Bool {
        action.code == "DELIVER" && task.authority != .fulfillmentV1 && task.proof.receiverNameRequired
    }

    private var needsOTP: Bool {
        action.code == "DELIVER" && task.authority != .fulfillmentV1 && task.proof.otpRequired
    }

    private var cashText: String? {
        guard let cash = task.cash, let amount = cash.amount else { return nil }
        let collectsCash = action.code == "CONFIRM_PAYMENT" ||
            (action.code == "DELIVER" && task.authority != .fulfillmentV1 && cash.required && !cash.collected)
        return collectsCash ? ppDriverMoney(amount, currency: cash.currency) : nil
    }

    private var trimmedName: String { receiverName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedOTP: String { ppDriverASCIIDigits(otp) }
    private var canConfirm: Bool { (!needsName || !trimmedName.isEmpty) && (!needsOTP || normalizedOTP.count >= 4) }

    private var actionIcon: String {
        switch action.code {
        case "CLAIM": return "sparkles"
        case "PICK_UP": return "shippingbox.and.arrow.backward.fill"
        case "START_TRANSIT": return "car.fill"
        case "DELIVER": return "house.and.flag.fill"
        case "CONFIRM_PAYMENT": return "banknote.fill"
        case "COMPLETE": return "flag.checkered"
        default: return "checkmark.circle.fill"
        }
    }

    private var actionColor: Color {
        switch action.code {
        case "CLAIM": return AdminSurface.primary
        case "PICK_UP": return AdminSurface.amber
        case "START_TRANSIT": return Color.blue
        case "DELIVER": return AdminSurface.emerald
        case "CONFIRM_PAYMENT": return AdminSurface.amber
        case "COMPLETE": return AdminSurface.emerald
        default: return AdminSurface.primary
        }
    }

    private var actionStageSubtitle: String {
        switch action.code {
        case "CLAIM": return ppDriverText("DriverCockpit_Section_Offers")
        case "PICK_UP": return ppDriverText("DriverCockpit_Step_Collect")
        case "START_TRANSIT": return ppDriverText("DriverCockpit_Step_Transit")
        case "DELIVER": return ppDriverText("DriverCockpit_Step_Deliver")
        case "CONFIRM_PAYMENT": return ppDriverText("DriverCockpit_Cash_Collect_Title")
        case "COMPLETE": return ppDriverText("DriverCockpit_Step_Close")
        default: return ppActionTitle(action.code)
        }
    }

    private var hasRouteInfo: Bool {
        !task.pickup.primary.isEmpty || !task.dropoff.primary.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetTopBar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroOrderPanel

                    if hasRouteInfo {
                        flightPathCard
                    }

                    if let cashText {
                        cashVaultPlate(cashText)
                    }

                    if needsName || needsOTP {
                        verificationSection
                    }
                }
                .padding(.horizontal, AdminSpacing.screenMargin)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }

            dockCommitmentBar
        }
        .background(AdminSurface.background.ignoresSafeArea())
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var sheetTopBar: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: actionIcon)
                    .font(.system(size: 11, weight: .bold))
                Text(actionStageSubtitle)
                    .font(AdminType.caption2Bold)
            }
            .foregroundStyle(actionColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(actionColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(actionColor.opacity(0.25), lineWidth: 0.6)
            )

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(AdminSurface.control)
                    )
                    .overlay(
                        Circle().stroke(AdminSurface.hairline, lineWidth: 0.8)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(ppDriverText("DriverCockpit_Cancel"))
        }
        .padding(.horizontal, AdminSpacing.screenMargin)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var heroOrderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminSurface.primary)

                Text(ppOrderTitle(task))
                    .font(AdminType.caption1Bold)
                    .monospacedDigit()
                    .foregroundStyle(AdminSurface.primary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule().fill(AdminSurface.primary.opacity(0.08))
            )

            Text(ppActionTitle(action.code))
                .font(AdminType.title2)
                .foregroundStyle(AdminSurface.primaryText)
                .multilineTextAlignment(.leading)

            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(actionColor)
                    .frame(width: 6, height: 6)
                    .offset(y: 6)

                Text(ppActionConsequence(action, task: task))
                    .font(AdminType.callout)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .fill(AdminSurface.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .stroke(AdminSurface.hairline, lineWidth: 0.8)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flightPathCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ppDriverText("DriverCockpit_Navigate"))
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminSurface.secondaryText)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AdminSurface.primary.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdminSurface.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ppDriverText("DriverCockpit_Pickup"))
                            .font(AdminType.caption2Bold)
                            .foregroundStyle(AdminSurface.primary)

                        Text(task.pickup.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : task.pickup.primary)
                            .font(AdminType.calloutBold)
                            .foregroundStyle(AdminSurface.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !task.pickup.secondary.isEmpty {
                            Text(task.pickup.secondary)
                                .font(AdminType.caption)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Circle().fill(AdminSurface.hairline).frame(width: 2.5, height: 2.5)
                        Circle().fill(AdminSurface.hairline).frame(width: 2.5, height: 2.5)
                        Circle().fill(AdminSurface.hairline).frame(width: 2.5, height: 2.5)
                    }
                    .frame(width: 36, alignment: .center)

                    Spacer()
                }
                .padding(.vertical, 2)

                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AdminSurface.emerald.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AdminSurface.emerald)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ppDriverText("DriverCockpit_Dropoff"))
                            .font(AdminType.caption2Bold)
                            .foregroundStyle(AdminSurface.emerald)

                        Text(task.dropoff.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : task.dropoff.primary)
                            .font(AdminType.calloutBold)
                            .foregroundStyle(AdminSurface.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !task.dropoff.secondary.isEmpty {
                            Text(task.dropoff.secondary)
                                .font(AdminType.caption)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }

                        if !task.customerName.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                Text(task.customerName)
                                    .font(AdminType.caption2Bold)
                            }
                            .foregroundStyle(AdminSurface.secondaryText)
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous)
                    .fill(AdminSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous)
                    .stroke(AdminSurface.hairline, lineWidth: 0.8)
            )
        }
    }

    private func cashVaultPlate(_ cashAmountString: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AdminSurface.amber.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AdminSurface.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ppDriverText("DriverCockpit_Cash_Collect_Title"))
                        .font(AdminType.footnoteBold)
                        .foregroundStyle(AdminSurface.amber)

                    Text(cashAmountString)
                        .font(AdminType.title)
                        .monospacedDigit()
                        .foregroundStyle(AdminSurface.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous)
                .fill(AdminSurface.amber.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous)
                .stroke(AdminSurface.amber.opacity(0.35), lineWidth: 1.0)
        )
    }

    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ppDriverText("DriverCockpit_Proof_Title"))
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminSurface.secondaryText)

            if needsName {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(ppDriverText("DriverCockpit_ReceiverName"), systemImage: "person.fill")
                            .font(AdminType.footnoteBold)
                            .foregroundStyle(AdminSurface.secondaryText)

                        Spacer()

                        if !trimmedName.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AdminSurface.emerald)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(ppDriverText("DriverCockpit_ReceiverName"), text: $receiverName)
                            .font(AdminType.body)
                            .textContentType(.name)
                            .submitLabel(.done)

                        if !receiverName.isEmpty {
                            Button(action: { receiverName = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AdminSurface.secondaryText)
                            }
                        }
                    }
                    .padding(AdminSpacing.md)
                    .frame(minHeight: AdminTouchTarget.inputField)
                    .background(
                        RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                            .fill(AdminSurface.fieldBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                            .stroke(!trimmedName.isEmpty ? AdminSurface.emerald.opacity(0.5) : AdminSurface.hairline, lineWidth: 1.0)
                    )
                }
            }

            if needsOTP {
                let otpCountDisplay = String(
                    format: "%ld/4",
                    normalizedOTP.count
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(ppDriverText("DriverCockpit_OTP"), systemImage: "lock.shield.fill")
                            .font(AdminType.footnoteBold)
                            .foregroundStyle(AdminSurface.secondaryText)

                        Spacer()

                        Text(otpCountDisplay)
                            .font(AdminType.caption2Bold)
                            .monospacedDigit()
                            .foregroundStyle(normalizedOTP.count >= 4 ? AdminSurface.emerald : AdminSurface.secondaryText)

                        if normalizedOTP.count >= 4 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AdminSurface.emerald)
                        }
                    }

                    TextField(ppDriverText("DriverCockpit_OTP"), text: $otp)
                        .font(AdminType.title3Bold)
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding(AdminSpacing.md)
                        .frame(minHeight: AdminTouchTarget.inputField)
                        .background(
                            RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                                .fill(AdminSurface.fieldBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                                .stroke(normalizedOTP.count >= 4 ? AdminSurface.emerald.opacity(0.5) : AdminSurface.hairline, lineWidth: 1.0)
                        )
                }
            }
        }
    }

    private var dockCommitmentBar: some View {
        VStack(spacing: 8) {
            Button {
                guard canConfirm, !isSubmitting else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isSubmitting = true
                onConfirm(PPDriverCommandInputs(receiverName: trimmedName, otp: normalizedOTP))
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))

                        Text(cashText.map { ppDriverFormat("DriverCockpit_Confirm_Cash_Format", $0) } ?? ppActionTitle(action.code))
                            .font(AdminType.headlineBold)
                    }
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous)
                        .fill(
                            canConfirm
                                ? LinearGradient(colors: [AdminSurface.primary, AdminSurface.primaryPressed], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [AdminSurface.control, AdminSurface.control], startPoint: .top, endPoint: .bottom)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous)
                        .stroke(canConfirm ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1.0)
                )
                .shadow(color: canConfirm ? AdminSurface.primary.opacity(0.35) : Color.clear, radius: 8, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canConfirm || isSubmitting)
            .scaleEffect(canConfirm ? 1.0 : 0.98)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canConfirm)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Text(ppDriverText("DriverCockpit_Cancel"))
                    .font(AdminType.calloutBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AdminSpacing.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            AdminSurface.surface
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - UIKit host

/// Hosts the unified driver cockpit inside the existing Pro navigation stack.
/// `init` resolves the driver context itself; the focus initializer opens a
/// specific task from a notification after the backend re-authorizes it.
@objc(PPDriverCockpitHostController)
public final class PPDriverCockpitHostController: UIViewController {
    private let store: PPDriverCockpitStore
    private var initialFocus: PPDriverFocusRequest?
    private var hostingController: UIHostingController<PPDriverCockpitView>?

    @objc public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.store = PPDriverCockpitStore()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    @objc public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    @objc(initWithFocusTaskID:authority:companyID:)
    public convenience init(focusTaskID: String?, authority: String?, companyID: String?) {
        self.init(nibName: nil, bundle: nil)
        initialFocus = PPDriverFocusRequest.make(taskID: focusTaskID, authority: authority, companyID: companyID)
    }

    required init?(coder: NSCoder) {
        self.store = PPDriverCockpitStore()
        super.init(coder: coder)
    }

    /// Focuses a task in an already-open cockpit (for example from a push).
    @objc(focusWithTaskID:authority:companyID:)
    public func focus(taskID: String?, authority: String?, companyID: String?) {
        guard let request = PPDriverFocusRequest.make(taskID: taskID, authority: authority, companyID: companyID) else { return }
        store.requestFocus(request)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ppBackground
        let rootView = PPDriverCockpitView(store: store, onClose: { [weak self] in
            guard let self else { return }
            if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        })
        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        store.start(focus: initialFocus)
        initialFocus = nil
        store.setVisible(true)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store.setVisible(false)
    }
}
