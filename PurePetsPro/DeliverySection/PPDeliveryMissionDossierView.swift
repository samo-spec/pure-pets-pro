//
//  PPDeliveryMissionDossierView.swift
//  PurePetsPro
//
//  "Mission Dossier" (NextGen v7 selected direction) for the delivery
//  operations cockpit. One sheet for any order opened from the Ready Missions
//  Radar or the order list: what is carried, from where to where, how it is
//  paid, where it is in its journey, and exactly one next step allowed by the
//  order model. Every step still goes through PPDeliveryManager and the server.
//

import SwiftUI
import UIKit

private func ppDossierText(_ key: String) -> String {
    Language.get(key, alter: nil)
}

private func ppDossierFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: ppDossierText(key), locale: Locale(identifier: Language.currentLanguageCode()), arguments: arguments)
}

// MARK: - Next step

/// Next step for an order, in the precedence used by
/// PPDeliveryOrderDetailViewController's action bar.
enum PPDossierAction: Equatable {
    case accept, pickup, transit, deliver, collectCash, complete

    var titleKey: String {
        switch self {
        case .accept: return "Deliv_AcceptJob"
        case .pickup: return "PickUpFromStore"
        case .transit: return "Deliv_StartTransit"
        case .deliver: return "MarkAsDelivered"
        case .collectCash: return "CollectCashPayment"
        case .complete: return "Deliv_CompleteOrder"
        }
    }

    var consequenceKey: String {
        switch self {
        case .accept: return "Deliv_Dossier_Consequence_Accept"
        case .pickup: return "Deliv_Dossier_Consequence_Pickup"
        case .transit: return "Deliv_Dossier_Consequence_Transit"
        case .deliver: return "Deliv_Dossier_Consequence_Deliver"
        case .collectCash: return "Deliv_Dossier_Consequence_Cash"
        case .complete: return "Deliv_Dossier_Consequence_Complete"
        }
    }

    var symbol: String {
        switch self {
        case .accept: return "hand.tap.fill"
        case .pickup: return "shippingbox.fill"
        case .transit: return "truck.box.fill"
        case .deliver: return "checkmark.circle.fill"
        case .collectCash: return "banknote.fill"
        case .complete: return "checkmark.seal.fill"
        }
    }
}

enum PPDossierDock: Equatable {
    case action(PPDossierAction)
    /// Localized key explaining why there is nothing to do here.
    case info(String)
}

@MainActor
func ppDossierDock(for order: PPDeliveryOrderModel,
                   currentUID: String,
                   state: PPDeliveryDriverObservableState) -> PPDossierDock {
    if order.isTerminal() { return .info("Deliv_Dossier_Closed") }
    guard state.hasLiveActionProjection(order) else { return .info("Deliv_Dossier_Wait_Sync") }
    let assignee = order.deliveryUserId ?? ""
    let mineOrUnassigned = assignee.isEmpty || assignee == currentUID
    if order.canAcceptDelivery() { return .action(.accept) }
    if order.canConfirmPackageHandover() {
        return mineOrUnassigned ? .action(.pickup) : .info("Deliv_Dossier_Wait_OtherDriver")
    }
    if order.canMarkInTransit() {
        return mineOrUnassigned ? .action(.transit) : .info("Deliv_Dossier_Wait_OtherDriver")
    }
    if order.canMarkDelivered() {
        return mineOrUnassigned ? .action(.deliver) : .info("Deliv_Dossier_Wait_OtherDriver")
    }
    if order.canCollectCashPayment() { return .action(.collectCash) }
    if order.canMarkCompleted() { return .action(.complete) }
    return .info("Deliv_Dossier_Wait_None")
}

// MARK: - Dossier

struct PPDeliveryMissionDossierView: View {
    let orderID: String
    @ObservedObject var state: PPDeliveryDriverObservableState
    let onOpenRecord: ((PPDeliveryOrderModel) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cashOrder: PPDeliveryOrderModel?

    private var isRTL: Bool { Language.isRTL() }
    private var currentUID: String { PPDeliveryCompanyService.currentAccountUID() }
    private var order: PPDeliveryOrderModel? { state.allOrders.first { $0.orderId == orderID } }

    var body: some View {
        Group {
            if let order {
                dossier(order)
            } else {
                goneState
            }
        }
        .background(AdminSurface.background.ignoresSafeArea())
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.currentLanguageCode()))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $cashOrder) { order in
            PPDeliveryCashCollectionSheet(order: order, state: state)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
    }

    // MARK: Layout

    private func dossier(_ order: PPDeliveryOrderModel) -> some View {
        let dock = ppDossierDock(for: order, currentUID: currentUID, state: state)
        return ScrollView {
            VStack(alignment: .leading, spacing: AdminSpacing.base) {
                header(order)
                routeBand(order)
                journey(order)
                manifest(order)
                payment(order)
                contacts(order)
                if let onOpenRecord {
                    Button {
                        // The host closes this sheet and pushes the record from
                        // the sheet's onDismiss, so the push never races the
                        // dismissal animation.
                        onOpenRecord(order)
                    } label: {
                        HStack(spacing: AdminSpacing.sm) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ppDossierText("Deliv_Dossier_FullRecord"))
                                    .font(AdminType.subheadlineBold)
                                Text(ppDossierText("Deliv_Dossier_FullRecord_Hint"))
                                    .font(AdminType.caption1)
                                    .foregroundStyle(AdminSurface.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AdminSurface.secondaryText)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(AdminSurface.primary)
                        .padding(AdminSpacing.base)
                        .frame(minHeight: AdminTouchTarget.comfortable)
                        .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
                        .contentShape(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, AdminSpacing.screenMargin)
            .padding(.top, AdminSpacing.lg)
            .padding(.bottom, AdminSpacing.base)
        }
        .safeAreaInset(edge: .bottom) {
            actionDock(order, dock: dock)
        }
    }

    private func header(_ order: PPDeliveryOrderModel) -> some View {
        let phase = state.missionPhase(for: order)
        return HStack(alignment: .top, spacing: AdminSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(orderTitle(order))
                    .font(AdminType.title3)
                    .foregroundStyle(AdminSurface.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(order.isTerminal() ? order.displayStatus() : phase.stepTitle)
                    .font(AdminType.subheadlineBold)
                    .foregroundStyle(AdminSurface.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.formattedTotal())
                    .font(AdminType.headline)
                    .foregroundStyle(order.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                    .monospacedDigit()
                Text(ppDossierText(order.isCashOrder() ? "Deliv_PaymentCOD" : "Deliv_PaymentPrepaid"))
                    .font(AdminType.caption1)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
            .accessibilityElement(children: .combine)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AdminSurface.secondaryText)
                    .frame(width: AdminTouchTarget.minimum, height: AdminTouchTarget.minimum)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(ppDossierText("Deliv_Dossier_Close"))
        }
    }

    // MARK: Route

    private func routeBand(_ order: PPDeliveryOrderModel) -> some View {
        let toPickup = state.missionPhase(for: order) <= .atBranch
        let pickupText = order.branchName ?? order.pp_pickupLocationSummary()
        let revealed = order.pp_canRevealExactDeliveryLocation()
        let dropoffText = revealed ? order.pp_exactDeliveryLocationText() : order.pp_deliveryAreaSummary()
        return VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            stop(title: ppDossierText("Deliv_Dossier_From"), symbol: "building.2.fill",
                 text: pickupText, detail: nil, emphasized: toPickup)
            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AdminSurface.secondaryText)
                .padding(.leading, AdminSpacing.base)
                .accessibilityHidden(true)
            stop(title: ppDossierText("Deliv_Dossier_To"), symbol: "mappin.circle.fill",
                 text: dropoffText,
                 detail: revealed ? nil : ppDossierText("Deliv_ExactLocationAfterAccepting"),
                 emphasized: !toPickup)
        }
    }

    private func stop(title: String, symbol: String, text: String, detail: String?, emphasized: Bool) -> some View {
        HStack(alignment: .top, spacing: AdminSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(emphasized ? AdminSurface.primary : AdminSurface.secondaryText)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(emphasized ? AdminSurface.primary : AdminSurface.secondaryText)
                Text(text.isEmpty ? ppDossierText("Deliv_Dossier_Pending") : text)
                    .font(emphasized ? AdminType.bodyBold : AdminType.body)
                    .foregroundStyle(AdminSurface.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Label(detail, systemImage: "lock.fill")
                        .font(AdminType.caption1)
                        .foregroundStyle(AdminSurface.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AdminSpacing.md)
        .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
            .fill(emphasized ? AdminSurface.primary.opacity(0.07) : AdminSurface.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: Journey

    private struct JourneyStep: Identifiable {
        let id: String
        let date: Date?
        let done: Bool
        let exception: Bool
    }

    private func journeySteps(_ order: PPDeliveryOrderModel) -> [JourneyStep] {
        let base: [(String, Date?)] = [
            ("Deliv_Dossier_Step_Ready", order.readyAt ?? order.deliveryRequestedAt ?? order.createdAt),
            ("Deliv_Dossier_Step_Accepted", order.deliveryAcceptedAt),
            ("Deliv_Dossier_Step_PickedUp", order.pickedUpAt ?? order.shippedAt),
            ("Deliv_Dossier_Step_InTransit", order.inTransitAt),
            ("Deliv_Dossier_Step_Delivered", order.deliveredAt),
            ("Deliv_Dossier_Step_Completed", order.completedAt ?? order.paymentConfirmedAt),
        ]
        // A step counts as passed when it or any later step has a server time.
        var steps: [JourneyStep] = []
        for (index, entry) in base.enumerated() {
            let passed = base[index...].contains { $0.1 != nil }
            steps.append(JourneyStep(id: entry.0, date: entry.1, done: passed, exception: false))
        }
        if let cancelled = order.cancelledAt {
            steps.append(JourneyStep(id: "Deliv_Dossier_Step_Cancelled", date: cancelled, done: true, exception: true))
        } else if let failed = order.deliveryFailedAt {
            steps.append(JourneyStep(id: "Deliv_Dossier_Step_Failed", date: failed, done: true, exception: true))
        }
        if let returned = order.returnedToStoreAt {
            steps.append(JourneyStep(id: "Deliv_Dossier_Step_Returned", date: returned, done: true, exception: true))
        }
        return steps
    }

    private func journey(_ order: PPDeliveryOrderModel) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            sectionTitle("Deliv_Dossier_Journey")
            VStack(alignment: .leading, spacing: 0) {
                let steps = journeySteps(order)
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: AdminSpacing.md) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(step.exception ? AdminSurface.crimson
                                      : (step.done ? AdminSurface.emerald : AdminSurface.hairline))
                                .frame(width: 10, height: 10)
                                .padding(.top, 5)
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(step.done ? AdminSurface.emerald.opacity(0.4) : AdminSurface.hairline)
                                    .frame(width: 2)
                                    .frame(minHeight: 22)
                            }
                        }
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ppDossierText(step.id))
                                .font(step.done ? AdminType.subheadlineBold : AdminType.subheadline)
                                .foregroundStyle(step.done ? AdminSurface.primaryText : AdminSurface.secondaryText)
                            if let date = step.date {
                                Text(timeText(date))
                                    .font(AdminType.caption1)
                                    .foregroundStyle(AdminSurface.secondaryText)
                            }
                        }
                        .padding(.bottom, AdminSpacing.sm)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(step.done ? "" : ppDossierText("Deliv_Dossier_Step_Upcoming"))
                }
            }
            .padding(AdminSpacing.base)
            .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        }
    }

    // MARK: Manifest and payment

    private func manifest(_ order: PPDeliveryOrderModel) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            sectionTitle("Deliv_Dossier_Items")
            VStack(alignment: .leading, spacing: AdminSpacing.sm) {
                if order.items.isEmpty {
                    Text(ppDossierFormat("Deliv_ItemsCount", order.items.count))
                        .font(AdminType.body)
                        .foregroundStyle(AdminSurface.secondaryText)
                } else {
                    ForEach(Array(order.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: AdminSpacing.sm) {
                            Text("\u{2068}×\(item.quantity)\u{2069}")
                                .font(AdminType.subheadlineBold)
                                .foregroundStyle(AdminSurface.primary)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name.isEmpty ? ppDossierText("Deliv_Dossier_Item") : item.name)
                                    .font(AdminType.body)
                                    .foregroundStyle(AdminSurface.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let variant = item.variant, !variant.isEmpty {
                                    Text(variant)
                                        .font(AdminType.caption1)
                                        .foregroundStyle(AdminSurface.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(AdminSpacing.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        }
    }

    private func payment(_ order: PPDeliveryOrderModel) -> some View {
        let cash = order.isCashOrder()
        let collected = order.hasValidServerCashCollectionReceipt()
        return HStack(spacing: AdminSpacing.md) {
            Image(systemName: cash ? "banknote.fill" : "creditcard.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(cash ? AdminSurface.amber : AdminSurface.emerald)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(ppDossierText(cash ? "Deliv_PaymentCOD" : "Deliv_PaymentPrepaid"))
                    .font(AdminType.subheadlineBold)
                    .foregroundStyle(AdminSurface.primaryText)
                if cash {
                    Text(ppDossierText(collected ? "Deliv_Dossier_CashCollected" : "Deliv_Dossier_CashDue"))
                        .font(AdminType.caption1)
                        .foregroundStyle(collected ? AdminSurface.emerald : AdminSurface.amber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(order.formattedTotal())
                .font(AdminType.headline)
                .foregroundStyle(AdminSurface.primaryText)
                .monospacedDigit()
        }
        .padding(AdminSpacing.base)
        .background(RoundedRectangle(cornerRadius: AdminRadius.card, style: .continuous).fill(AdminSurface.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: Contacts

    @ViewBuilder
    private func contacts(_ order: PPDeliveryOrderModel) -> some View {
        let phoneRevealed = order.pp_canRevealCustomerPhone(forDeliveryUserID: currentUID)
        let customerPhone = phoneRevealed ? order.customerPhone : ""
        let storePhone = order.marketplaceProviderPhone ?? ""
        let toPickup = state.missionPhase(for: order) <= .atBranch
        let destination = toPickup
            ? (order.pickupAddress ?? order.pp_pickupLocationSummary())
            : (order.pp_canRevealExactDeliveryLocation() ? order.pp_exactDeliveryLocationText() : "")
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: AdminSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AdminSpacing.sm))
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            if !order.customerName.isEmpty {
                Label(order.customerName, systemImage: "person.fill")
                    .font(AdminType.subheadline)
                    .foregroundStyle(AdminSurface.primaryText)
            }
            if !phoneRevealed && !order.isTerminal() {
                Label(ppDossierText("Deliv_CustomerPhoneAfterAccepting"), systemImage: "lock.fill")
                    .font(AdminType.caption1)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
            if !destination.isEmpty || !customerPhone.isEmpty || !storePhone.isEmpty {
                layout {
                    if !destination.isEmpty && !order.isTerminal() {
                        contactButton("Deliv_Directions", symbol: "location.fill") {
                            state.openGoogleMapsNavigation(address: destination)
                        }
                    }
                    if !customerPhone.isEmpty {
                        contactButton("Deliv_Dossier_CallCustomer", symbol: "phone.fill") {
                            state.dialPhoneNumber(customerPhone)
                        }
                    }
                    if !storePhone.isEmpty {
                        contactButton("Deliv_Dossier_CallStore", symbol: "storefront.fill") {
                            state.dialPhoneNumber(storePhone)
                        }
                    }
                }
            }
        }
    }

    private func contactButton(_ key: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(ppDossierText(key), systemImage: symbol)
                .font(AdminType.calloutBold)
                .foregroundStyle(AdminSurface.primary)
                .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.comfortable)
                .padding(.horizontal, AdminSpacing.sm)
                .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .fill(AdminSurface.primary.opacity(0.09)))
                .contentShape(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Dock

    private func actionDock(_ order: PPDeliveryOrderModel, dock: PPDossierDock) -> some View {
        VStack(spacing: AdminSpacing.xs) {
            switch dock {
            case .action(let action):
                Button {
                    if action == .deliver && order.isCashOrder() && order.canCollectCashPayment() {
                        // Cash first: the existing sheet records the amount and
                        // then confirms delivery.
                        cashOrder = order
                    } else {
                        presentConfirmationAlert(for: action, on: order)
                    }
                } label: {
                    HStack(spacing: AdminSpacing.sm) {
                        if state.isExecutingAction {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: action.symbol).accessibilityHidden(true)
                        }
                        VStack(spacing: 2) {
                            Text(ppDossierText(state.isExecutingAction ? "Deliv_Dossier_Working" : action.titleKey))
                                .font(AdminType.headline)
                            if !state.isExecutingAction {
                                Text(consequence(action, order: order))
                                    .font(AdminType.caption1)
                                    .opacity(0.88)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, AdminSpacing.base)
                    .padding(.vertical, AdminSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous)
                        .fill(state.isExecutingAction ? AdminSurface.secondaryText : AdminSurface.primary))
                    .contentShape(RoundedRectangle(cornerRadius: AdminRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(state.isExecutingAction)
                .accessibilityLabel(ppDossierText(action.titleKey))
                .accessibilityHint(consequence(action, order: order))
            case .info(let key):
                Label(ppDossierText(key), systemImage: "info.circle")
                    .font(AdminType.subheadline)
                    .foregroundStyle(AdminSurface.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AdminSpacing.md)
                    .background(RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                        .fill(AdminSurface.backgroundSecondary))
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, AdminSpacing.screenMargin)
        .padding(.top, AdminSpacing.md)
        .padding(.bottom, AdminSpacing.sm)
        .background(AdminSurface.surface
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: -2)
            .ignoresSafeArea(edges: .bottom))
    }

    private func presentConfirmationAlert(for action: PPDossierAction, on order: PPDeliveryOrderModel) {
        let icon = UIImage(systemName: action.symbol)
        PPAlertHelper.showConfirmation(
            in: nil,
            title: ppDossierText(action.titleKey),
            subtitle: consequence(action, order: order),
            confirmButton: ppDossierText("Deliv_Dossier_Confirm"),
            cancelButton: ppDossierText("Deliv_Dossier_Cancel"),
            icon: icon,
            confirmBlock: { _, didConfirm in
                guard didConfirm else { return }
                Task { @MainActor in
                    perform(action, on: order)
                }
            },
            cancelBlock: nil
        )
    }

    private func perform(_ action: PPDossierAction, on order: PPDeliveryOrderModel) {
        switch action {
        case .accept: state.acceptOrder(order)
        case .pickup: state.confirmPickup(order)
        case .transit: state.markInTransit(order)
        case .deliver: state.markDelivered(order)
        case .collectCash: state.collectCash(order)
        case .complete: state.completeOrder(order)
        }
    }

    // MARK: Gone

    private var goneState: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AdminSurface.primary)
                .accessibilityHidden(true)
            Text(ppDossierText("Deliv_Dossier_Gone_Title"))
                .font(AdminType.title3)
                .foregroundStyle(AdminSurface.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(ppDossierText("Deliv_Dossier_Gone_Body"))
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(ppDossierText("Deliv_Dossier_Close")) { dismiss() }
                .font(AdminType.calloutBold)
                .frame(minHeight: AdminTouchTarget.comfortable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AdminSpacing.lg)
    }

    // MARK: Helpers

    private func sectionTitle(_ key: String) -> some View {
        Text(ppDossierText(key))
            .font(AdminType.footnoteBold)
            .foregroundStyle(AdminSurface.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func orderTitle(_ order: PPDeliveryOrderModel) -> String {
        let number = !order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.bestOrderNumber()
        return "\u{2068}\(number)\u{2069}"
    }

    private func consequence(_ action: PPDossierAction, order: PPDeliveryOrderModel) -> String {
        if action == .collectCash {
            return ppDossierFormat("Deliv_Dossier_Consequence_Cash_Format", order.formattedTotal())
        }
        return ppDossierText(action.consequenceKey)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.currentLanguageCode())
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\u{2068}\(formatter.string(from: date))\u{2069}"
    }
}
