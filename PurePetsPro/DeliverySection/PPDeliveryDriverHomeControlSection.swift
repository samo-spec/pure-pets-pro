//
//  PPDeliveryDriverHomeControlSection.swift
//  PurePetsPro
//
//  Category-Defining Delivery Driver Cockpit Section for the Pro Home Screen.
//  Sculpted from absolute first principles as an alive, tactile, aerospace-grade
//  field operations deck. Fluid micro-interactions, breathing telemetry radar,
//  and reactive waypoint awareness.
//

import SwiftUI

/// Compatibility entry for older Home capabilities. No provider order store
/// exists until the authenticated account's delivery destination is resolved.
@MainActor
struct PPDeliveryHomeEntrySection: View {
    @ObservedObject var driverStore: PPDriverCockpitStore
    var isActive = true
    private enum Phase: Equatable { case checking, driver, provider, failed }
    @State private var phase = Phase.checking
    @State private var generation = 0
    let onOpenDriverCockpit: () -> Void
    let onOpenProviderCockpit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            switch phase {
            case .driver:
                PPDriverHomeAvailabilitySection(store: driverStore, isActive: isActive, onOpenCockpit: onOpenDriverCockpit)
            case .provider:
                if isActive {
                    PPDeliveryDriverHomeControlSection(onOpenCockpit: onOpenProviderCockpit)
                }
            case .checking, .failed:
                VStack(alignment: .leading, spacing: AdminSpacing.md) {
                    Label(ppDriverText("DriverCockpit_Title"), systemImage: "steeringwheel")
                        .font(AdminType.headlineBold)
                        .accessibilityAddTraits(.isHeader)
                    if phase == .checking {
                        ProgressView(ppDriverText("DriverCockpit_Loading_Tasks"))
                    } else {
                        Text(ppDriverText("DeliveryLogin_CheckFailed_Body"))
                            .font(AdminType.subheadline)
                            .foregroundStyle(AdminSurface.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(ppDriverText("TryAgain"), action: resolveEntry)
                            .font(AdminType.calloutBold)
                            .frame(minHeight: AdminTouchTarget.minimum)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AdminSpacing.base)
                .background(RoundedRectangle(cornerRadius: AdminRadius.card).fill(AdminSurface.card))
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear { if isActive { resolveEntry() } }
        .onChange(of: isActive) { _, active in
            if active && (phase == .checking || phase == .failed) { resolveEntry() }
        }
    }

    private func resolveEntry() {
        guard isActive else { return }
        generation += 1
        let requestGeneration = generation
        let requestedUID = PPDeliveryCompanyService.currentAccountUID()
        phase = .checking
        PPDeliveryCompanyService.shared().resolveDriverCockpitRequirement { requiresDriverCockpit, error in
            Task { @MainActor in
                guard requestGeneration == generation,
                      requestedUID == PPDeliveryCompanyService.currentAccountUID() else { return }
                if error != nil { phase = .failed }
                else { phase = requiresDriverCockpit ? .driver : .provider }
            }
        }
    }
}

/// Company drivers use the same canonical state/commands as the dashboard.
/// The marketplace provider presentation below remains its separate workflow.
///
/// NextGen V9 next-stop slip: assigned work replaces idle availability without
/// disclosure. The existing cockpit store and confirmation own every command;
/// the readiness controls return after a confirmed empty assigned-task read.
@MainActor
struct PPDriverHomeAvailabilitySection: View {
    @ObservedObject var store: PPDriverCockpitStore
    var isActive = true
    /// Collapsed every time the section is created.
    @State private var isExpanded = false
    @State private var confirmation: PPDriverConfirmation?
    @State private var isOnScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    let onOpenCockpit: () -> Void

    private enum Tone {
        case receiving, paused, attention, pending

        var color: Color {
            switch self {
            case .receiving: return AdminSurface.emerald
            case .paused, .pending: return AdminSurface.secondaryText
            case .attention: return AdminSurface.amber
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let task = activeTask {
                missionHeader
                if isExpanded {
                    VStack(alignment: .leading, spacing: 0) {
                        PPDriverHomeMissionSummary(task: task)
                            .padding(.top, AdminSpacing.base)
                        nextStep(for: task)
                            .padding(.top, AdminSpacing.base)
                        if let notice = store.notice, store.uncertainCommand == nil {
                            recoveryCallout(notice)
                                .padding(.top, AdminSpacing.md)
                        }
                        dashboardRow
                            .padding(.top, AdminSpacing.sm)
                    }
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    ))
                }
            } else {
                header
                if holdsAvailabilityForTaskRead {
                    if isExpanded {
                        taskReadRecovery
                            .padding(.top, AdminSpacing.md)
                        if let notice = store.notice, store.uncertainCommand == nil {
                            recoveryCallout(notice)
                                .padding(.top, AdminSpacing.md)
                        }
                        dashboardRow
                    }
                } else if isExpanded {
                    controls
                        .padding(.top, AdminSpacing.md)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        ))
                }
            }
        }
        .padding(AdminSpacing.base)
        .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        .overlay(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: activeTask?.id)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: activeTask?.stage)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: activeTask?.status)
        .sensoryFeedback(.selection, trigger: isExpanded)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.currentLanguageCode()))
        .sheet(item: $confirmation) { request in
            PPDriverConfirmSheet(task: request.task, action: request.action) { inputs in
                store.perform(request.action, on: request.task, inputs: inputs, contextID: request.contextID)
            }
            .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        }
        .onAppear {
            isOnScreen = true
            if isActive { store.start(focus: nil) }
            store.setVisible(isActive && scenePhase == .active)
            if activeTask != nil {
                isExpanded = true
            }
        }
        .onChange(of: scenePhase) { _, phase in store.setVisible(isOnScreen && isActive && phase == .active) }
        .onChange(of: isActive) { _, active in
            if active { store.start(focus: nil) }
            else { confirmation = nil }
            store.setVisible(isOnScreen && active && scenePhase == .active)
        }
        .onChange(of: activeTask?.id) { previous, current in
            if previous == nil && current != nil {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded = true
                }
            } else if previous != nil, current == nil, store.phase == .ready,
               !store.isStale, store.uncertainCommand == nil {
                isExpanded = true
            }
        }
        .onDisappear {
            isOnScreen = false
            confirmation = nil
            store.setVisible(false)
        }
    }

    // MARK: Active delivery

    private var assignedTasks: [PPDriverTask] {
        store.activeTasks.filter { $0.mine && !$0.isTerminal }
    }

    private var activeTask: PPDriverTask? {
        assignedTasks.first(where: { $0.id == store.focusedTaskKey }) ?? assignedTasks.first
    }

    /// Never present an empty/failed first page or an uncertain completion as
    /// proof that the driver is idle. Availability remains a separate mode.
    private var holdsAvailabilityForTaskRead: Bool {
        store.uncertainCommand != nil || store.isSubmitting || store.isVerifying ||
            (store.phase == .ready && (store.lastConfirmedAt == nil || store.isStale || activeCount > 0))
    }

    private var missionHeader: some View {
        HStack(alignment: .center, spacing: AdminSpacing.md) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: AdminSpacing.md) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AdminSurface.primary)
                        .frame(width: 44, height: 44)
                        .background(AdminSurface.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: AdminRadius.medium))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ppDriverText("DriverHome_ActiveDelivery"))
                            .font(AdminType.headlineBold)
                            .foregroundStyle(AdminSurface.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        if !isExpanded, let task = activeTask {
                            Text(ppOrderTitle(task))
                                .font(AdminType.caption1Bold)
                                .foregroundStyle(AdminSurface.primary)
                                .lineLimit(1)
                        } else if let context = store.selectedContext {
                            Text(contextName(context))
                                .font(AdminType.footnote)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.985, pressedOpacity: 0.94))
            .accessibilityLabel(ppDriverText("DriverHome_ActiveDelivery"))
            .accessibilityValue(ppDriverText(isExpanded ? "DriverHome_State_Expanded" : "DriverHome_State_Collapsed"))
            .accessibilityHint(ppDriverText(isExpanded ? "DriverHome_Collapse_Hint" : "DriverHome_Expand_Hint"))

            if assignedTasks.count > 1 {
                Menu {
                    ForEach(assignedTasks) { task in
                        Button { store.focus(on: task) } label: {
                            if task.id == activeTask?.id {
                                Label(ppOrderTitle(task), systemImage: "checkmark")
                            } else {
                                Text(ppOrderTitle(task))
                            }
                        }
                    }
                } label: {
                    Label(localizedCount(assignedTasks.count), systemImage: "square.stack")
                        .font(AdminType.calloutBold)
                        .foregroundStyle(AdminSurface.primary)
                        .padding(.horizontal, AdminSpacing.sm)
                        .frame(minHeight: AdminTouchTarget.minimum)
                        .background(AdminSurface.primary.opacity(0.08), in: Capsule())
                }
                .disabled(!store.canSwitchContext)
                .accessibilityLabel(ppDriverText("DriverHome_ChooseDelivery"))
                .accessibilityValue(ppDriverFormat("DriverHome_ActiveCount_Format", localizedCount(assignedTasks.count)))
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .accessibilityIdentifier("driver.home.active.header")
    }

    private var taskReadRecovery: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            if store.isRefreshing || store.isResolvingContexts || store.isSubmitting || store.isVerifying {
                ProgressView(ppDriverText("DriverCockpit_Loading_Tasks"))
                    .font(AdminType.subheadline)
            } else if store.uncertainCommand != nil {
                uncertainCommandRecovery
            } else {
                Label(ppDriverText("DriverHome_CheckAssigned"), systemImage: "arrow.clockwise.circle")
                    .font(AdminType.subheadline)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(ppDriverText("DriverCockpit_CheckLatest")) { store.refreshAvailability() }
                    .buttonStyle(PPDriverPrimaryButtonStyle())
                    .disabled(!store.canSwitchContext)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("driver.home.active.checking")
    }

    @ViewBuilder
    private func nextStep(for task: PPDriverTask) -> some View {
        if store.isSubmitting || store.isVerifying {
            Button {} label: {
                HStack(spacing: AdminSpacing.sm) {
                    ProgressView().tint(.white)
                    Text(ppDriverText("DriverCockpit_Notice_Waiting"))
                }
            }
            .buttonStyle(PPDriverPrimaryButtonStyle(enabled: false))
            .disabled(true)
        } else if store.uncertainCommand != nil {
            uncertainCommandRecovery
        } else if store.isStale {
            statusNote("DriverCockpit_Notice_Offline", symbol: "wifi.exclamationmark")
            refreshTaskButton
        } else if task.awaitsStoreHandover {
            statusNote("DriverCockpit_Wait_StoreHandover", symbol: "shippingbox")
            refreshTaskButton
        } else if let action = task.primaryAction {
            if let key = ppDriverActionBlockKey(action, task: task, canSelfAcceptOrders: store.canSelfAcceptOrders) {
                statusNote(key, symbol: "lock.shield")
            } else {
                Button { execute(action, on: task) } label: {
                    HStack(spacing: AdminSpacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ppActionTitle(action.code))
                                .font(AdminType.headlineBold)
                            Text(ppActionConsequence(action, task: task))
                                .font(AdminType.caption1)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(0.9)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        if store.isRefreshing { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.forward").accessibilityHidden(true) }
                    }
                    .padding(.vertical, AdminSpacing.xs)
                }
                .buttonStyle(PPDriverPrimaryButtonStyle(enabled: store.canPerformCurrentAction(action, on: task)))
                .disabled(!store.canPerformCurrentAction(action, on: task))
                .accessibilityLabel(ppActionTitle(action.code))
                .accessibilityHint(ppActionConsequence(action, task: task))
                .accessibilityIdentifier("driver.home.active.nextStep")
            }
        } else {
            statusNote(task.stage == .delivered || task.stage == .settled
                       ? "DriverCockpit_Wait_Dispatch" : "DriverCockpit_Wait_Generic", symbol: "clock")
            refreshTaskButton
        }
    }

    private var uncertainCommandRecovery: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            statusNote("DriverCockpit_Notice_Unconfirmed", symbol: "exclamationmark.arrow.triangle.2.circlepath")
            Button { store.retryUncertainCommand() } label: {
                Label(ppDriverText("DriverCockpit_RetrySafely"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PPDriverPrimaryButtonStyle(enabled: !store.isSubmitting && !store.isVerifying))
            .disabled(store.isSubmitting || store.isVerifying)
            .accessibilityIdentifier("driver.home.active.retry")
            Button(ppDriverText("DriverCockpit_CheckLatest")) { store.checkUncertainCommandStatus() }
                .font(AdminType.calloutBold)
                .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.minimum)
                .disabled(store.isSubmitting || store.isRefreshing || store.isResolvingContexts || store.isVerifying)
                .accessibilityIdentifier("driver.home.active.checkStatus")
        }
    }

    private var refreshTaskButton: some View {
        Button { store.refreshAvailability() } label: {
            HStack(spacing: AdminSpacing.sm) {
                if store.isRefreshing { ProgressView().tint(.white) }
                else { Image(systemName: "arrow.clockwise") }
                Text(ppDriverText("DriverCockpit_CheckLatest"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(PPDriverPrimaryButtonStyle(enabled: !store.isRefreshing))
        .disabled(store.isRefreshing || store.isResolvingContexts || !store.canSwitchContext)
    }

    private func statusNote(_ key: String, symbol: String) -> some View {
        Label(ppDriverText(key), systemImage: symbol)
            .font(AdminType.footnote)
            .foregroundStyle(AdminSurface.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func execute(_ action: PPDriverTaskAction, on task: PPDriverTask) {
        guard store.canPerformCurrentAction(action, on: task) else { return }
        if ["DELIVER", "CONFIRM_PAYMENT", "COMPLETE"].contains(action.code) {
            confirmation = PPDriverConfirmation(task: task, action: action, contextID: store.selectedContext?.id)
        } else {
            store.perform(action, on: task)
        }
    }

    // MARK: Collapsed header

    private var header: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: AdminSpacing.md) {
                beacon
                VStack(alignment: .leading, spacing: 3) {
                    Text(ppDriverText("DriverCockpit_Title"))
                        .font(AdminType.headlineBold)
                        .foregroundStyle(AdminSurface.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    statusLine
                    if dynamicTypeSize.isAccessibilitySize && activeCount > 0 {
                        activeBadge
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize && activeCount > 0 {
                    activeBadge
                }
                if store.isResolvingContexts || store.isRefreshing {
                    ProgressView()
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .frame(minHeight: AdminTouchTarget.comfortable)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.985, pressedOpacity: 0.94))
        .accessibilityLabel(ppDriverText("DriverCockpit_Title"))
        .accessibilityValue(accessibilitySummary)
        .accessibilityHint(ppDriverText(isExpanded ? "DriverHome_Collapse_Hint" : "DriverHome_Expand_Hint"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("driver.home.readiness.disclosure")
    }

    /// The readiness control's tinted tile, so both states read as one instrument.
    private var beacon: some View {
        Image(systemName: "steeringwheel")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(tone.color)
            .frame(width: 44, height: 44)
            .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(tone.color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(AdminSurface.card, lineWidth: 2))
                    .padding(3)
            }
            .accessibilityHidden(true)
    }

    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: tone == .attention ? "exclamationmark.circle.fill" : "circle.fill")
                .font(.system(size: tone == .attention ? 12 : 7, weight: .bold))
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
            Text(statusSummary)
                .font(AdminType.footnote)
                .foregroundStyle(tone == .attention ? AdminSurface.primaryText : AdminSurface.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeBadge: some View {
        Label {
            Text(localizedCount(activeCount))
        } icon: {
            Image(systemName: "shippingbox.fill")
        }
        .labelStyle(.titleAndIcon)
        .font(AdminType.captionBold)
        .foregroundStyle(AdminSurface.primary)
        .padding(.horizontal, AdminSpacing.sm)
        .padding(.vertical, 4)
        .background(AdminSurface.primary.opacity(0.1), in: Capsule())
        .accessibilityHidden(true)
    }

    // MARK: Expanded controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            Rectangle()
                .fill(AdminSurface.hairline)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if let context = store.selectedContext {
                if store.contexts.count > 1 {
                    fleetMenu(context)
                } else if !summaryIncludesFleet {
                    Text(contextName(context))
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if showsAvailabilityControl {
                PPDriverAvailabilityControl(store: store)
            } else {
                // The collapsed line already carries this message when they match.
                if ppDriverText(stateMessageKey) != statusText {
                    Text(ppDriverText(stateMessageKey))
                        .font(AdminType.subheadlineBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.phase == .loadFailed || store.phase == .accessEnded {
                    Button(ppDriverText("DriverAvailability_CheckStatus")) { store.resolveContexts() }
                        .font(AdminType.calloutBold)
                        .frame(minHeight: AdminTouchTarget.minimum)
                        .disabled(store.isResolvingContexts)
                }
            }

            if let notice = store.notice {
                recoveryCallout(notice)
            }

            dashboardRow
        }
    }

    private func fleetMenu(_ context: PPDriverContext) -> some View {
        Menu {
            ForEach(store.contexts) { choice in
                Button {
                    store.select(choice)
                } label: {
                    if choice.id == context.id {
                        Label(contextName(choice), systemImage: "checkmark")
                    } else {
                        Text(contextName(choice))
                    }
                }
            }
        } label: {
            Label(contextName(context), systemImage: "chevron.up.chevron.down")
                .font(AdminType.calloutBold)
                .frame(minHeight: AdminTouchTarget.minimum, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!store.canSwitchContext || store.isResolvingContexts)
        .accessibilityLabel(ppDriverText("DriverCockpit_SwitchWorkspace"))
        .accessibilityValue(contextName(context))
    }

    private func recoveryCallout(_ notice: PPDriverNotice) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AdminSpacing.sm) {
                Image(systemName: noticeSymbol(notice.tone))
                    .foregroundStyle(noticeColor(notice.tone))
                    .accessibilityHidden(true)
                Text(notice.text)
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminSurface.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AdminSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(noticeColor(notice.tone).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous))
    }

    private var dashboardRow: some View {
        Button(action: onOpenCockpit) {
            HStack(spacing: AdminSpacing.sm) {
                Text(ppDriverText("DriverAvailability_OpenDashboard"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AdminSpacing.sm)
                Image(systemName: "chevron.forward").accessibilityHidden(true)
            }
            .font(AdminType.calloutBold)
            .foregroundStyle(AdminSurface.primary)
            .padding(.vertical, AdminSpacing.sm)
            .frame(minHeight: AdminTouchTarget.comfortable)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isSubmitting || store.isVerifying)
        .accessibilityIdentifier("driver.availability.openDashboard")
    }

    // MARK: Derived state
    // Same confirmed-state rules as PPDriverAvailabilityControl: stale or
    // missing availability is unknown, and any readiness reason other than
    // OFFLINE is a restriction.

    private var confirmedAvailability: PPDriverAvailability? {
        store.isStale ? nil : store.availability
    }

    private var isRestricted: Bool {
        confirmedAvailability?.readinessReasons.contains(where: { $0 != "OFFLINE" }) == true
    }

    /// A pending recovery must stay visible even while the section is collapsed.
    private var needsAttention: Bool {
        if store.uncertainCommand != nil { return true }
        if let notice = store.notice, notice.tone == .warning || notice.tone == .error { return true }
        return false
    }

    private var tone: Tone {
        if needsAttention { return .attention }
        switch store.phase {
        case .resolving:
            return .pending
        case .ready:
            guard let availability = confirmedAvailability, !isRestricted else { return .attention }
            return availability.online ? .receiving : .paused
        case .noWorkspace, .loadFailed, .accessEnded, .choosingContext, .signedOut:
            return .attention
        }
    }

    private var statusText: String {
        if needsAttention { return ppDriverText("DriverHome_Attention") }
        switch store.phase {
        case .resolving: return ppDriverText("DriverCockpit_Loading_Tasks")
        case .choosingContext: return ppDriverText("DriverAvailability_ChooseWorkspace")
        case .loadFailed: return ppDriverText("DriverCockpit_Presence_Unavailable")
        case .signedOut: return ppDriverText("DriverCockpit_SignedOut_Body")
        case .accessEnded: return ppDriverText("DriverCockpit_NoWorkspace_Body")
        case .noWorkspace(let reason):
            return ppDriverText(reason.isEmpty ? "DriverCockpit_NoWorkspace_Body" : "DriverAvailability_AccessRequired")
        case .ready:
            guard let availability = confirmedAvailability else { return ppDriverText("DriverCockpit_Presence_Unknown") }
            if isRestricted { return ppDriverText("DriverHome_Restricted") }
            return ppDriverText(availability.online ? "DriverCockpit_Presence_Online" : "DriverCockpit_Presence_Offline")
        }
    }

    private var summaryIncludesFleet: Bool {
        store.phase == .ready && !needsAttention && store.selectedContext != nil
    }

    private var statusSummary: String {
        guard summaryIncludesFleet, let context = store.selectedContext else { return statusText }
        return "\(statusText) · \(contextName(context))"
    }

    private var activeCount: Int { confirmedAvailability?.activeDeliveryCount ?? 0 }

    private var accessibilitySummary: String {
        var parts = [statusText]
        if summaryIncludesFleet, let context = store.selectedContext { parts.append(contextName(context)) }
        if activeCount > 0 { parts.append(ppDriverFormat("DriverHome_ActiveCount_Format", localizedCount(activeCount))) }
        parts.append(ppDriverText(isExpanded ? "DriverHome_State_Expanded" : "DriverHome_State_Collapsed"))
        return parts.joined(separator: Language.isRTL() ? "، " : ", ")
    }

    private func localizedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: Language.currentLanguageCode())
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func noticeSymbol(_ tone: PPDriverNotice.Tone) -> String {
        switch tone {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func noticeColor(_ tone: PPDriverNotice.Tone) -> Color {
        switch tone {
        case .info: return AdminSurface.primary
        case .success: return AdminSurface.emerald
        case .warning: return AdminSurface.amber
        case .error: return AdminSurface.danger
        }
    }

    private func contextName(_ context: PPDriverContext) -> String {
        context.kind == .officialDriver ? ppDriverText("DriverCockpit_Context_Official")
            : ppDriverFormat("DriverCockpit_Context_Partner_Format", ppDriverIsolated(context.companyName.isEmpty ? context.companyID : context.companyName))
    }

    private var showsAvailabilityControl: Bool {
        if store.phase == .ready { return true }
        if case .noWorkspace(let reason) = store.phase { return !reason.isEmpty }
        return false
    }

    private var stateMessageKey: String {
        switch store.phase {
        case .resolving: return "DriverCockpit_Loading_Tasks"
        case .choosingContext: return "DriverAvailability_ChooseWorkspace"
        case .loadFailed: return "DriverCockpit_Presence_Unavailable"
        case .signedOut: return "DriverCockpit_SignedOut_Body"
        case .accessEnded: return "DriverCockpit_NoWorkspace_Body"
        case .noWorkspace: return "DriverCockpit_NoWorkspace_Body"
        case .ready: return "DriverAvailability_ChooseWorkspace"
        }
    }
}

/// Presentation only. Order, route, cash and grouped lifecycle position are
/// supplied by the same redacted task projection used in the full cockpit.
private struct PPDriverHomeMissionSummary: View {
    let task: PPDriverTask
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps = ["DriverCockpit_Step_Collect", "DriverCockpit_Step_Transit",
                         "DriverCockpit_Step_Deliver", "DriverCockpit_Step_Close"]
    private var pickupIsNext: Bool { task.stage == .offer || task.stage == .toPickup }

    var body: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.base) {
            VStack(alignment: .leading, spacing: AdminSpacing.sm) {
                Text(ppOrderTitle(task))
                    .font(AdminType.title2)
                    .foregroundStyle(AdminSurface.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Label(ppStatusText(task.status), systemImage: statusSymbol)
                    .font(AdminType.subheadlineBold)
                    .foregroundStyle(AdminSurface.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.80), value: task.status)
            }

            if task.stage != .unknown {
                progress
            }

            VStack(alignment: .leading, spacing: AdminSpacing.md) {
                routeStop(task.pickup, title: "DriverCockpit_Pickup", symbol: "shippingbox",
                          current: pickupIsNext)
                Rectangle()
                    .fill(AdminSurface.hairline)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
                routeStop(task.dropoff, title: "DriverCockpit_Dropoff", symbol: "house",
                          current: !pickupIsNext && task.stage != .unknown)
            }
            .padding(AdminSpacing.md)
            .background(AdminSurface.backgroundSecondary,
                        in: RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: pickupIsNext)

            if !task.customerName.isEmpty || task.cash?.required == true {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: AdminSpacing.sm))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: AdminSpacing.md))
                layout {
                    if !task.customerName.isEmpty {
                        Label(ppDriverIsolated(task.customerName), systemImage: "person")
                            .font(AdminType.footnote)
                            .foregroundStyle(AdminSurface.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(ppDriverFormat("DriverCockpit_Customer_Format", task.customerName))
                    }
                    if let cash = task.cash, cash.required {
                        cashSummary(cash)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("driver.home.active.order")
    }

    private var statusSymbol: String {
        switch task.stage {
        case .offer, .toPickup: return "shippingbox"
        case .collected, .inTransit: return "truck.box"
        case .delivered, .settled: return "checkmark.circle"
        default: return "info.circle"
        }
    }

    private var progress: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AdminSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: AdminSpacing.sm))
        return layout {
            ForEach(steps.indices, id: \.self) { index in
                milestone(index)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.80), value: task.stage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ppDriverFormat("DriverCockpit_Step_Accessibility_Format",
                                           task.stage.railIndex + 1, steps.count,
                                           ppDriverText(steps[min(task.stage.railIndex, steps.count - 1)])))
        .accessibilityHint(ppDriverText("DriverHome_ProgressHint"))
        .accessibilityIdentifier("driver.home.active.progress")
    }

    private func milestone(_ index: Int) -> some View {
        let isCurrent = index == task.stage.railIndex
        let isPast = index < task.stage.railIndex
        let color = isCurrent ? AdminSurface.primary : (isPast ? AdminSurface.emerald : AdminSurface.secondaryText)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: AdminSpacing.sm))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: AdminSpacing.sm))
        return layout {
            HStack(spacing: 5) {
                Image(systemName: isPast ? "checkmark.circle.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                if !dynamicTypeSize.isAccessibilitySize {
                    Capsule()
                        .fill(color.opacity(isCurrent || isPast ? 0.8 : 0.15))
                        .frame(height: 3)
                        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.80), value: task.stage)
                }
            }
            .foregroundStyle(color)
            Text(ppDriverText(steps[index]))
                .font(isCurrent ? AdminType.caption1Bold : AdminType.caption1)
                .foregroundStyle(isCurrent ? AdminSurface.primaryText : AdminSurface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routeStop(_ address: PPDriverAddress, title: String, symbol: String, current: Bool) -> some View {
        HStack(alignment: .top, spacing: AdminSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: current ? .semibold : .regular))
                .foregroundStyle(current ? AdminSurface.primary : AdminSurface.secondaryText)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(ppDriverText(title))
                    .font(AdminType.caption1Bold)
                    .foregroundStyle(current ? AdminSurface.primary : AdminSurface.secondaryText)
                Text(address.primary.isEmpty
                     ? (address.secondary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : address.secondary)
                     : ppDriverIsolated(address.primary))
                    .font(current ? AdminType.bodyBold : AdminType.subheadline)
                    .foregroundStyle(AdminSurface.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !address.primary.isEmpty && !address.secondary.isEmpty && address.primary != address.secondary {
                    Text(ppDriverIsolated(address.secondary))
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func cashSummary(_ cash: PPDriverCash) -> some View {
        let title = cash.collected ? ppDriverText("DriverCockpit_CashCollected") :
            cash.amount.map { ppDriverFormat("DriverCockpit_CashDue_Format", ppDriverMoney($0, currency: cash.currency)) }
                ?? ppDriverText("DriverCockpit_CashDue_Unknown")
        return Label(title, systemImage: "banknote")
            .font(AdminType.footnoteBold)
            .foregroundStyle(cash.collected ? AdminSurface.emerald : AdminSurface.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Reusable Tactile Scale Touch Button Style

public struct PPDeliveryTouchButtonStyle: ButtonStyle {
    public var pressedScale: CGFloat = 0.965
    public var pressedOpacity: Double = 0.92

    public init(pressedScale: CGFloat = 0.965, pressedOpacity: Double = 0.92) {
        self.pressedScale = pressedScale
        self.pressedOpacity = pressedOpacity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Category-Defining Home Cockpit Section

public struct PPDeliveryDriverHomeControlSection: View {
    @StateObject private var state = PPDeliveryDriverObservableState()
    public let onOpenCockpit: () -> Void

    @State private var isExpanded: Bool = true
    @State private var radarPulse: Bool = false
    @State private var isOnScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isRTL: Bool { Language.isRTL() }

    public init(onOpenCockpit: @escaping () -> Void) {
        self.onOpenCockpit = onOpenCockpit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Mission Control Header & Duty Switcher Capsule (Tappable expand/collapse)
            headerDeck

            // 2. Dynamic Center Content: In-Flight Mission OR Live Shift Telemetry + Action Track
            if isExpanded {
                VStack(spacing: 16) {
                    if let activeOrder = state.activeMissionOrder {
                        activeMissionDeck(activeOrder)
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .scale(scale: 0.96).combined(with: .opacity),
                                removal: .scale(scale: 0.96).combined(with: .opacity)
                            ))
                    } else {
                        telemetryDeck
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .scale(scale: 0.96).combined(with: .opacity),
                                removal: .scale(scale: 0.96).combined(with: .opacity)
                            ))
                    }

                    // 3. Category-Defining Launch Cockpit Action Track
                    cockpitLaunchTrack
                }
                .padding(.top, 16)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                ))
            }
        }
        .padding(18)
        .background(
            ZStack {
                // Frosted card foundation
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AdminSurface.card)

                // Ambient status aura
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                state.dutyState.tintColor.opacity(state.dutyState == .busyFlight ? 0.09 : 0.03),
                                Color.clear
                            ],
                            center: isRTL ? .topLeading : .topTrailing,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )

                // Specular hairline border with subtle top highlight
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                AdminSurface.hairline.opacity(0.8),
                                Color.black.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        .sensoryFeedback(.selection, trigger: isExpanded)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            isOnScreen = true
            synchronizeRadarPulse()
            if state.activeMissionOrder != nil {
                isExpanded = true
            }
        }
        .onChange(of: reduceMotion) { _, _ in synchronizeRadarPulse() }
        .onChange(of: scenePhase) { _, _ in synchronizeRadarPulse() }
        .onChange(of: state.dutyState) { _, _ in synchronizeRadarPulse() }
        .onChange(of: state.activeMissionOrder?.orderId) { previous, current in
            if previous == nil && current != nil {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded = true
                }
            }
        }
        .onDisappear {
            isOnScreen = false
            synchronizeRadarPulse()
        }
    }

    private var shouldPulse: Bool {
        isOnScreen && scenePhase == .active && !reduceMotion && state.dutyState == .busyFlight
    }

    private func synchronizeRadarPulse() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { radarPulse = false }
        guard shouldPulse else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { radarPulse = true }
    }

    // MARK: - Header Deck

    private var headerDeck: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Animated Status Orbital Beacon
                ZStack {
                    // Expanding concentric radar pulse wave (when on duty)
                    if shouldPulse {
                        Circle()
                            .stroke(state.dutyState.tintColor.opacity(0.25), lineWidth: 1.5)
                            .scaleEffect(radarPulse ? 1.4 : 0.9)
                            .opacity(radarPulse ? 0.0 : 0.6)
                            .frame(width: 38, height: 38)
                    }

                    // Outer chassis ring
                    Circle()
                        .stroke(state.dutyState.tintColor.opacity(0.28), lineWidth: 2)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(state.dutyState.tintColor.opacity(0.08))
                        )

                    // Core beacon
                    Circle()
                        .fill(state.dutyState.tintColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: state.dutyState.tintColor.opacity(0.6), radius: 4, x: 0, y: 1)
                }

                // Title & Subtitle Stack
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(Language.get("Deliv_Section_ControlTitle", alter: "مركز عمليات التوصيل الميداني"))
                            .font(PPBrandFont.bold(16))
                            .foregroundColor(AdminSurface.primaryText)
                            .lineLimit(1)

                        // Small alive status indicator
                        Circle()
                            .fill(state.dutyState == .busyFlight ? AdminSurface.amber : AdminSurface.secondaryText.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }

                    if !isExpanded, let activeOrder = state.activeMissionOrder {
                        HStack(spacing: 4) {
                            Text(Language.get("Deliv_ActiveEnRoute", alter: "مهمة جارية"))
                                .font(PPBrandFont.bold(11))
                                .foregroundColor(AdminSurface.amber)
                            Text("·")
                                .foregroundColor(AdminSurface.secondaryText)
                            Text(!activeOrder.displayOrderNumber.isEmpty ? activeOrder.displayOrderNumber : activeOrder.bestOrderNumber())
                                .font(PPBrandFont.medium(11))
                                .foregroundColor(AdminSurface.secondaryText)
                        }
                        .lineLimit(1)
                    } else {
                        Text(state.dutyState.title)
                            .font(PPBrandFont.regular(12))
                            .foregroundColor(state.dutyState.tintColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                // Read-only work state
                HStack(spacing: 5) {
                    Image(systemName: state.dutyState.systemIcon)
                        .font(.system(size: 11, weight: .bold))

                    Text(state.dutyState.shortTitle)
                        .font(PPBrandFont.bold(12))
                }
                .foregroundColor(state.dutyState.tintColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(state.dutyState.tintColor.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(state.dutyState.tintColor.opacity(0.28), lineWidth: 1)
                )

                // Animated Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AdminSurface.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 20, height: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))
        .accessibilityLabel(Language.get("Deliv_Section_ControlTitle", alter: "مركز عمليات التوصيل الميداني"))
        .accessibilityValue("\(state.dutyState.title), \(Language.get(isExpanded ? "Expanded" : "Collapsed", alter: isExpanded ? "موسّع" : "مطوي"))")
        .accessibilityHint(Language.get(isExpanded ? "Deliv_Collapse_Hint" : "Deliv_Expand_Hint", alter: isExpanded ? "اضغط لطي بطاقة التوصيل" : "اضغط لتوسيع بطاقة التوصيل"))
    }

    // MARK: - Active Mission Deck (Dynamic Waypoint Corridor)

    private func activeMissionDeck(_ order: PPDeliveryOrderModel) -> some View {
        VStack(spacing: 12) {
            // Mission Identification & Payment Banner
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(AdminSurface.amber)
                            .frame(width: 8, height: 8)

                        if !reduceMotion {
                            Circle()
                                .stroke(AdminSurface.amber.opacity(0.4), lineWidth: 2)
                                .scaleEffect(radarPulse ? 1.6 : 1.0)
                                .opacity(radarPulse ? 0.0 : 1.0)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(Language.get("Deliv_ActiveEnRoute", alter: "مهمة جارية الآن"))
                        .font(PPBrandFont.bold(13))
                        .foregroundColor(AdminSurface.amber)
                }

                Spacer()

                // Order Number Pill
                Text(!order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.bestOrderNumber())
                    .font(PPBrandFont.bold(13))
                    .foregroundColor(AdminSurface.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(AdminSurface.card.opacity(0.9))
                    )
            }

            // Spatial Waypoint Corridor
            HStack(spacing: 12) {
                // Waypoint origin / destination indicator
                VStack(spacing: 3) {
                    Circle()
                        .fill(order.canConfirmPackageHandover() ? AdminSurface.amber : AdminSurface.emerald)
                        .frame(width: 10, height: 10)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    order.canConfirmPackageHandover() ? AdminSurface.amber : AdminSurface.emerald,
                                    Color.blue
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 26)

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }

                // Waypoint Context
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.canConfirmPackageHandover()
                         ? Language.get("Deliv_Waypoint_Pickup", alter: "الاستلام من الفرع")
                         : Language.get("Deliv_Waypoint_Dropoff", alter: "التوصيل للعميل"))
                        .font(PPBrandFont.caption(11))
                        .foregroundColor(AdminSurface.secondaryText)

                    Text(order.canConfirmPackageHandover()
                         ? (order.branchName ?? Language.get("Branch", alter: "الفرع"))
                         : (!order.customerName.isEmpty ? order.customerName : Language.get("Customer", alter: "العميل")))
                        .font(PPBrandFont.bold(14))
                        .foregroundColor(AdminSurface.primaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Financial Badge (Prepaid vs COD Cash)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: order.isCashOrder() ? "banknote.fill" : "creditcard.fill")
                            .font(.system(size: 11))
                        Text(order.formattedTotal() ?? "")
                            .font(PPBrandFont.bold(13))
                            .monospacedDigit()
                    }
                    .foregroundColor(order.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(order.isCashOrder() ? AdminSurface.amber.opacity(0.12) : AdminSurface.emerald.opacity(0.12))
                    )

                    Text(order.isCashOrder() ? Language.get("Deliv_PaymentCOD", alter: "تحصيل كاش") : Language.get("Deliv_PaymentPrepaid", alter: "مدفوع مسبقاً"))
                        .font(PPBrandFont.caption(10))
                        .foregroundColor(AdminSurface.secondaryText)
                }
            }

            // Quick 1-Tap Navigation Corridor
            HStack(spacing: 8) {
                let navTarget = order.canConfirmPackageHandover()
                    ? order.pp_pickupLocationSummary()
                    : (order.pp_visibleCustomerLocationSummary().isEmpty ? order.deliveryAddress : order.pp_visibleCustomerLocationSummary())

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    state.openAppleMapsNavigation(address: navTarget)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(Language.get("Deliv_Directions", alter: "بدء الملاحة"))
                            .font(PPBrandFont.bold(12))
                    }
                    .foregroundColor(Color.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PPDeliveryTouchButtonStyle())

                let phone = order.canConfirmPackageHandover()
                    ? (order.marketplaceProviderPhone ?? "")
                    : order.customerPhone

                if !phone.isEmpty {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        state.dialPhoneNumber(phone)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(Language.get("Call", alter: "اتصال"))
                                .font(PPBrandFont.bold(12))
                        }
                        .foregroundColor(AdminSurface.emerald)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AdminSurface.emerald.opacity(0.1))
                        )
                    }
                    .buttonStyle(PPDeliveryTouchButtonStyle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AdminSurface.amber.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AdminSurface.amber.opacity(0.28), lineWidth: 1.2)
        )
    }

    // MARK: - Shift Fast Telemetry Deck (The 3 Alive Pods)

    private var telemetryDeck: some View {
        HStack(spacing: 10) {
            // Pod 1: Ready For Pickup (الطلبات الجاهزة للاستلام)
            telemetryPod(
                icon: "shippingbox.fill",
                iconColor: Color.blue,
                value: "\(state.availableDispatches.count)",
                title: Language.get("Deliv_ReadyPickup", alter: "جاهزة للاستلام"),
                hasAlertBadge: !state.availableDispatches.isEmpty
            )

            // Pod 2: In progress now (server-sourced orders)
            telemetryPod(
                icon: "figure.walk.motion",
                iconColor: AdminSurface.emerald,
                value: "\(state.inProgressCount)",
                title: Language.get("Deliv_Metric_InProgress", alter: "قيد التنفيذ"),
                hasAlertBadge: false
            )

            // Pod 3: Delivered today (server deliveredAt)
            telemetryPod(
                icon: "checkmark.seal.fill",
                iconColor: AdminSurface.primary,
                value: "\(state.todayCompletedCount)",
                title: Language.get("Deliv_Metric_DeliveredToday", alter: "سُلّمت اليوم"),
                hasAlertBadge: false
            )
        }
    }

    private func telemetryPod(
        icon: String,
        iconColor: Color,
        value: String,
        title: String,
        hasAlertBadge: Bool
    ) -> some View {
        VStack(spacing: 6) {
            // Icon & Alert Halo
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    )

                if hasAlertBadge {
                    Circle()
                        .fill(AdminSurface.amber)
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 1.5)
                        )
                        .offset(x: isRTL ? -2 : 2, y: -2)
                }
            }

            // Numeric Value with tabular figures
            Text(value)
                .font(PPBrandFont.bold(15))
                .foregroundColor(AdminSurface.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()

            // Subtitle
            Text(title)
                .font(PPBrandFont.caption(10))
                .foregroundColor(AdminSurface.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AdminSurface.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hasAlertBadge ? iconColor.opacity(0.35) : AdminSurface.hairline, lineWidth: 1)
        )
    }

    // MARK: - Category-Defining Launch Cockpit Action Track

    private var cockpitLaunchTrack: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onOpenCockpit()
        }) {
            ZStack {
                // Background Gradient
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AdminSurface.primary,
                                AdminSurface.primaryPressed
                            ],
                            startPoint: isRTL ? .trailing : .leading,
                            endPoint: isRTL ? .leading : .trailing
                        )
                    )

                // Shimmer specular highlight
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )

                // Content
                HStack(spacing: 12) {
                    // Steering Wheel Gyroscope Emblem
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 34, height: 34)

                        Image(systemName: "steeringwheel")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(Language.get("Deliv_LaunchCockpit", alter: "فتح غرفة عمليات ومسارات التوصيل"))
                        .font(PPBrandFont.bold(14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)

                    // Direction-Aware Action Chevron Capsule
                    Image(systemName: isRTL ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 52)
            .shadow(color: AdminSurface.primary.opacity(0.32), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.97))
        .accessibilityLabel(Language.get("Deliv_LaunchCockpit", alter: "فتح غرفة عمليات ومسارات التوصيل"))
        .accessibilityHint(Language.get("Deliv_Accessibility_OpenCockpitHint", alter: "يفتح خريطة المسارات وقائمة الطلبات وإدارة الشيفت"))
    }
}
