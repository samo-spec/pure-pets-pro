//
//  PPDeliveryDriverControlView.swift
//  PurePetsPro
//
//  Category-Defining SwiftUI Delivery Driver Cockpit & Mission Control Screen.
//  Tactile, alive, fluid micro-interactions, dynamic waypoint flight deck,
//  aerospace slide-to-confirm action bolt, and real-time shift telemetry.
//

import SwiftUI
import CoreLocation

// MARK: - Category-Defining Aerospace Slide-To-Confirm Action Bolt

public struct PPDeliverySlideActionTrack: View {
    public let title: String
    public let systemIcon: String
    public let tint: Color
    public let isExecuting: Bool
    public let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    @State private var didComplete: Bool = false
    @State private var pulseChevron: Bool = false
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let thumbSize: CGFloat = 52.0
    private let trackHeight: CGFloat = 62.0

    public init(
        title: String,
        systemIcon: String = "arrow.forward.circle.fill",
        tint: Color = AdminSurface.emerald,
        isExecuting: Bool = false,
        onComplete: @escaping () -> Void
    ) {
        self.title = title
        self.systemIcon = systemIcon
        self.tint = tint
        self.isExecuting = isExecuting
        self.onComplete = onComplete
    }

    private var isRTL: Bool { layoutDirection == .rightToLeft }

    private var maxTravel: CGFloat {
        max(1, trackWidth - thumbSize - 10)
    }

    private var progress: CGFloat {
        guard maxTravel > 0 else { return 0 }
        let current = isRTL ? -dragOffset : dragOffset
        return min(max(0, current / maxTravel), 1.0)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: isRTL ? .trailing : .leading) {
                // Background Track Chassis
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.35 + progress * 0.45),
                                        tint.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )

                // Dynamic Kinetic Fill Track
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.20 + progress * 0.25),
                                tint.opacity(0.35 + progress * 0.35)
                            ],
                            startPoint: isRTL ? .trailing : .leading,
                            endPoint: isRTL ? .leading : .trailing
                        )
                    )
                    .frame(width: max(thumbSize + 10, (isRTL ? -dragOffset : dragOffset) + thumbSize + 6))

                // Centered Label with Animated Chevrons
                HStack(spacing: 8) {
                    if isRTL {
                        Image(systemName: "chevron.backward.2")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(tint.opacity(0.85 - progress * 0.6))
                            .offset(x: reduceMotion ? 0 : (pulseChevron ? -4 : 0))
                    }

                    Text(title)
                        .font(PPBrandFont.bold(15))
                        .foregroundColor(AdminSurface.primaryText)
                        .opacity(1.0 - Double(progress) * 0.75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !isRTL {
                        Image(systemName: "chevron.forward.2")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(tint.opacity(0.85 - progress * 0.6))
                            .offset(x: reduceMotion ? 0 : (pulseChevron ? 4 : 0))
                    }
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                // Precision Tactile Thumb Bolt
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint,
                                    tint.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                        )
                        .shadow(color: tint.opacity(0.42), radius: 8, x: 0, y: 3)

                    if isExecuting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else if didComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: isRTL ? "chevron.backward" : "chevron.forward")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .padding(5)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isExecuting && !didComplete else { return }
                            let raw = isRTL ? -value.translation.width : value.translation.width
                            let bounded = min(max(0, raw), maxTravel)
                            dragOffset = isRTL ? -bounded : bounded

                            if progress > 0.3 && progress < 0.35 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else if progress > 0.65 && progress < 0.70 {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            guard !isExecuting && !didComplete else { return }
                            if progress >= 0.85 {
                                // Trigger completion
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                didComplete = true
                                dragOffset = isRTL ? -maxTravel : maxTravel
                                onComplete()

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                        didComplete = false
                                    }
                                }
                            } else {
                                // Spring back to start
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .onAppear {
                self.trackWidth = proxy.size.width
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulseChevron = true
                    }
                }
            }
            .onChange(of: proxy.size.width) { newWidth in
                self.trackWidth = newWidth
            }
        }
        .frame(height: trackHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(Language.get("Deliv_Accessibility_SlideHint", alter: "اسحب المؤشر للنهاية للتأكيد"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Live Telemetry Grid

public struct PPDeliveryTelemetryGrid: View {
    @ObservedObject var state: PPDeliveryDriverObservableState

    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // 1. Completed Stops Today
            telemetryTile(
                icon: "checkmark.seal.fill",
                iconColor: AdminSurface.emerald,
                value: "\(state.todayCompletedCount)",
                title: Language.get("Deliv_Metric_Stops", alter: "توصيلات اليوم"),
                badge: Language.get("Deliv_Metric_OnTrack", alter: "ممتاز")
            )

            // 2. Today's Shift Earnings
            telemetryTile(
                icon: "banknote.fill",
                iconColor: AdminSurface.primary,
                value: String(format: "%.0f %@", state.todayTotalEarningsQAR, Language.get("QAR", alter: "ر.ق")),
                title: Language.get("Deliv_Metric_Earnings", alter: "أرباح الشيفت"),
                badge: Language.get("Deliv_Metric_Live", alter: "مباشر")
            )

            // 3. Cash on Hand (COD to remit)
            telemetryTile(
                icon: "dollarsign.circle.fill",
                iconColor: AdminSurface.amber,
                value: String(format: "%.0f %@", state.todayCODCollectedQAR, Language.get("QAR", alter: "ر.ق")),
                title: Language.get("Deliv_Metric_CODHand", alter: "كاش في العهدة"),
                badge: Language.get("Deliv_Metric_Remit", alter: "للتحصيل")
            )

            // 4. On-Time Score Index
            telemetryTile(
                icon: "gauge.with.needle.fill",
                iconColor: Color.blue,
                value: "\(state.onTimeScorePercentage)%",
                title: Language.get("Deliv_Metric_OnTime", alter: "دقة المواعيد"),
                badge: Language.get("Deliv_Metric_Target", alter: "هدف 98%+")
            )
        }
    }

    private func telemetryTile(
        icon: String,
        iconColor: Color,
        value: String,
        title: String,
        badge: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Spacer()

                Text(badge)
                    .font(PPBrandFont.caption(10))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(iconColor.opacity(0.1))
                    )
            }

            Text(value)
                .font(PPBrandFont.bold(18))
                .foregroundColor(AdminSurface.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()

            Text(title)
                .font(PPBrandFont.regular(12))
                .foregroundColor(AdminSurface.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AdminSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AdminSurface.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Active Mission Flight Deck (The Hero Waypoint Card)

public struct PPDeliveryActiveMissionDeck: View {
    public let order: PPDeliveryOrderModel
    @ObservedObject var state: PPDeliveryDriverObservableState

    @State private var isPayloadExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase: PPDeliveryMissionPhase {
        state.missionPhase(for: order)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mission Header Badge & Payment Tag
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AdminSurface.amber.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AdminSurface.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Language.get("Deliv_ActiveMission_Title", alter: "مهمة التوصيل الحالية"))
                            .font(PPBrandFont.bold(16))
                            .foregroundColor(AdminSurface.primaryText)

                        Circle()
                            .fill(AdminSurface.emerald)
                            .frame(width: 7, height: 7)
                    }

                    Text(!order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.bestOrderNumber())
                        .font(PPBrandFont.caption(13))
                        .foregroundColor(AdminSurface.secondaryText)
                }

                Spacer()

                // Cash or Prepaid Tag
                HStack(spacing: 5) {
                    Image(systemName: order.isCashOrder() ? "banknote.fill" : "creditcard.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(order.formattedTotal() ?? "")
                        .font(PPBrandFont.bold(13))
                        .monospacedDigit()
                }
                .foregroundColor(order.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(order.isCashOrder() ? AdminSurface.amber.opacity(0.12) : AdminSurface.emerald.opacity(0.12))
                )
            }

            Divider().background(AdminSurface.hairline)

            // Dynamic Waypoints Corridor
            VStack(alignment: .leading, spacing: 14) {
                // Waypoint 1: Store / Branch Pickup
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(phase >= .inTransit ? AdminSurface.emerald : AdminSurface.amber)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )

                        Rectangle()
                            .fill(phase >= .inTransit ? AdminSurface.emerald.opacity(0.6) : AdminSurface.hairline)
                            .frame(width: 2, height: 42)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(Language.get("Deliv_Pickup_Store", alter: "نقطة الاستلام (المتجر)"))
                            .font(PPBrandFont.caption(11))
                            .foregroundColor(AdminSurface.secondaryText)

                        Text(order.branchName ?? order.pp_pickupLocationSummary() ?? Language.get("Deliv_BranchPendingAssignment", alter: "الفرع الرئيسي"))
                            .font(PPBrandFont.bold(15))
                            .foregroundColor(AdminSurface.primaryText)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                state.openAppleMapsNavigation(address: order.pp_pickupLocationSummary())
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 11))
                                    Text(Language.get("Deliv_NavToPickup", alter: "خريطة الفرع"))
                                        .font(PPBrandFont.caption(11))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AdminSurface.primary.opacity(0.1)))
                                .foregroundColor(AdminSurface.primary)
                            }
                            .buttonStyle(PPDeliveryTouchButtonStyle())

                            if let branchPhone = order.marketplaceProviderPhone, !branchPhone.isEmpty {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    state.dialPhoneNumber(branchPhone)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 11))
                                        Text(Language.get("Call", alter: "اتصال"))
                                            .font(PPBrandFont.caption(11))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(AdminSurface.emerald.opacity(0.1)))
                                    .foregroundColor(AdminSurface.emerald)
                                }
                                .buttonStyle(PPDeliveryTouchButtonStyle())
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                // Waypoint 2: Customer Dropoff
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(phase == .completed ? AdminSurface.emerald : Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(Language.get("Deliv_Dropoff_Customer", alter: "وجهة التوصيل (العميل)"))
                            .font(PPBrandFont.caption(11))
                            .foregroundColor(AdminSurface.secondaryText)

                        Text(!order.customerName.isEmpty ? order.customerName : Language.get("Customer", alter: "العميل"))
                            .font(PPBrandFont.bold(15))
                            .foregroundColor(AdminSurface.primaryText)

                        Text(order.pp_visibleCustomerLocationSummary().isEmpty ? order.deliveryAddress : order.pp_visibleCustomerLocationSummary())
                            .font(PPBrandFont.caption(12))
                            .foregroundColor(AdminSurface.secondaryText)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                state.openAppleMapsNavigation(address: order.pp_visibleCustomerLocationSummary().isEmpty ? order.deliveryAddress : order.pp_visibleCustomerLocationSummary())
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11))
                                    Text(Language.get("Deliv_Directions", alter: "الملاحة للعميل"))
                                        .font(PPBrandFont.caption(11))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                                .foregroundColor(Color.blue)
                            }
                            .buttonStyle(PPDeliveryTouchButtonStyle())

                            if !order.customerPhone.isEmpty {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    state.dialPhoneNumber(order.customerPhone)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 11))
                                        Text(Language.get("Call", alter: "اتصال"))
                                            .font(PPBrandFont.caption(11))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(AdminSurface.emerald.opacity(0.1)))
                                    .foregroundColor(AdminSurface.emerald)
                                }
                                .buttonStyle(PPDeliveryTouchButtonStyle())
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }

            // Items Payload Drawer Toggle
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPayloadExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AdminSurface.primary)

                    Text(String(format: Language.get("Deliv_ItemsInOrder", alter: "%ld أغراض في هذا الطلب"), order.items.count))
                        .font(PPBrandFont.bold(13))
                        .foregroundColor(AdminSurface.primaryText)

                    Spacer()

                    Image(systemName: isPayloadExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AdminSurface.secondaryText)
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AdminSurface.card.opacity(0.7))
                )
            }
            .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.98))

            if isPayloadExpanded, !order.items.isEmpty {
                VStack(spacing: 6) {
                    ForEach(order.items, id: \.itemID) { item in
                        HStack(spacing: 8) {
                            Text("\(item.quantity)x")
                                .font(PPBrandFont.bold(13))
                                .foregroundColor(AdminSurface.primary)

                            Text(item.name ?? "")
                                .font(PPBrandFont.medium(13))
                                .foregroundColor(AdminSurface.primaryText)
                                .lineLimit(1)

                            Spacer()

                            if let variant = item.variant, !variant.isEmpty {
                                Text(variant)
                                    .font(PPBrandFont.caption(11))
                                    .foregroundColor(AdminSurface.secondaryText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AdminSurface.card))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AdminSurface.card.opacity(0.5))
                )
            }

            // Slide Action Track: Dynamic commit for the current flight phase
            PPDeliverySlideActionTrack(
                title: slideActionTitle(for: order),
                systemIcon: "arrow.forward.circle.fill",
                tint: order.isCashOrder() && order.canCollectCashPayment() ? AdminSurface.amber : AdminSurface.emerald,
                isExecuting: state.isExecutingAction
            ) {
                executeNextStep(for: order)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AdminSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AdminSurface.primary.opacity(0.22), lineWidth: 1.5)
        )
        .shadow(color: AdminSurface.primary.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private func slideActionTitle(for order: PPDeliveryOrderModel) -> String {
        if order.canAcceptDelivery() {
            return Language.get("Deliv_Slide_Accept", alter: "اسحب لقبول المهمة")
        } else if order.canConfirmPackageHandover() {
            return Language.get("Deliv_Slide_Pickup", alter: "اسحب لتأكيد استلام الطرد")
        } else if order.canMarkInTransit() {
            return Language.get("Deliv_Slide_InTransit", alter: "اسحب لبدء خط السير للعميل")
        } else if order.isCashOrder() && order.canCollectCashPayment() {
            return Language.get("Deliv_Slide_CashDeliver", alter: "اسحب لتحصيل الكاش وتسليم الطلب")
        } else if order.canMarkDelivered() {
            return Language.get("Deliv_Slide_Complete", alter: "اسحب لتأكيد تسليم الطلب")
        } else {
            return order.displayStatus() ?? ""
        }
    }

    private func executeNextStep(for order: PPDeliveryOrderModel) {
        if order.canAcceptDelivery() {
            state.acceptOrder(order)
        } else if order.canConfirmPackageHandover() {
            state.confirmPickup(order)
        } else if order.canMarkInTransit() {
            state.markInTransit(order)
        } else if order.canMarkDelivered() || order.canCollectCashPayment() {
            state.markDelivered(order)
        }
    }
}

// MARK: - Incoming Dispatch Radar (Ready Deliveries Queue)

public struct PPDeliveryDispatchRadarSection: View {
    public let orders: [PPDeliveryOrderModel]
    @ObservedObject var state: PPDeliveryDriverObservableState

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AdminSurface.primary)

                    Text(Language.get("Deliv_Radar_Title", alter: "رادار المهام الجاهزة"))
                        .font(PPBrandFont.bold(16))
                        .foregroundColor(AdminSurface.primaryText)
                }

                Spacer()

                Text("\(orders.count) " + Language.get("Deliv_OrdersReady", alter: "طلب متاح"))
                    .font(PPBrandFont.caption(12))
                    .foregroundColor(AdminSurface.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AdminSurface.primary.opacity(0.12)))
            }

            ForEach(orders, id: \.orderId) { order in
                dispatchCard(order)
            }
        }
    }

    private func dispatchCard(_ order: PPDeliveryOrderModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(!order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.bestOrderNumber())
                    .font(PPBrandFont.bold(15))
                    .foregroundColor(AdminSurface.primaryText)

                Spacer()

                Text(order.formattedTotal() ?? "")
                    .font(PPBrandFont.bold(15))
                    .foregroundColor(order.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AdminSurface.secondaryText)
                    Text(order.branchName ?? Language.get("Branch", alter: "الفرع"))
                        .font(PPBrandFont.caption(12))
                        .foregroundColor(AdminSurface.secondaryText)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(AdminSurface.secondaryText.opacity(0.5))

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AdminSurface.primary)
                    Text(order.deliveryAreaName ?? order.pp_visibleCustomerLocationSummary() ?? Language.get("Customer", alter: "العميل"))
                        .font(PPBrandFont.caption(12))
                        .foregroundColor(AdminSurface.primaryText)
                        .lineLimit(1)
                }
            }

            HStack {
                Text(String(format: Language.get("Deliv_ItemsCount", alter: "%ld أغراض"), order.items.count))
                    .font(PPBrandFont.caption(11))
                    .foregroundColor(AdminSurface.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AdminSurface.cardElevated))

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    state.acceptOrder(order)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                        Text(Language.get("Deliv_AcceptJob", alter: "استلام المهمة"))
                            .font(PPBrandFont.bold(13))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AdminSurface.primary))
                    .foregroundColor(.white)
                    .shadow(color: AdminSurface.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PPDeliveryTouchButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AdminSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AdminSurface.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Cash Collection Sheet (COD Modal)

public struct PPDeliveryCashCollectionSheet: View {
    public let order: PPDeliveryOrderModel
    @ObservedObject var state: PPDeliveryDriverObservableState
    @Environment(\.dismiss) private var dismiss

    @State private var cashReceivedInput: String = ""
    @State private var deliveryNotes: String = ""

    private var targetAmount: Double {
        order.totalAmount
    }

    private var receivedAmount: Double {
        Double(cashReceivedInput) ?? targetAmount
    }

    private var changeDue: Double {
        max(0, receivedAmount - targetAmount)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Amount Spotlight
                VStack(spacing: 6) {
                    Text(Language.get("Deliv_CashCollection_Title", alter: "تحصيل الدفع عند الاستلام"))
                        .font(PPBrandFont.bold(18))
                        .foregroundColor(AdminSurface.primaryText)

                    Text(order.displayOrderNumber)
                        .font(PPBrandFont.caption(13))
                        .foregroundColor(AdminSurface.secondaryText)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AdminSurface.amber.opacity(0.12))
                            .frame(height: 78)

                        VStack(spacing: 2) {
                            Text(String(format: "%.2f %@", targetAmount, Language.get("QAR", alter: "ر.ق")))
                                .font(PPBrandFont.bold(28))
                                .foregroundColor(AdminSurface.amber)
                                .monospacedDigit()

                            Text(Language.get("Deliv_RequiredAmount", alter: "المبلغ المطلوب تحصيله نقداً"))
                                .font(PPBrandFont.caption(12))
                                .foregroundColor(AdminSurface.secondaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Quick Cash Shortcuts
                HStack(spacing: 8) {
                    cashPresetButton(title: Language.get("Exact", alter: "المبلغ بالضبط"), amount: targetAmount)
                    cashPresetButton(title: "50 " + Language.get("QAR", alter: "ر.ق"), amount: 50)
                    cashPresetButton(title: "100 " + Language.get("QAR", alter: "ر.ق"), amount: 100)
                    cashPresetButton(title: "200 " + Language.get("QAR", alter: "ر.ق"), amount: 200)
                }
                .padding(.horizontal, 16)

                // Change Calculator Pill
                if changeDue > 0 {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundColor(AdminSurface.emerald)
                        Text(Language.get("Deliv_ChangeDueToCustomer", alter: "المتبقي لإرجاعه للعميل:"))
                            .font(PPBrandFont.medium(14))
                            .foregroundColor(AdminSurface.primaryText)
                        Spacer()
                        Text(String(format: "%.2f %@", changeDue, Language.get("QAR", alter: "ر.ق")))
                            .font(PPBrandFont.bold(17))
                            .foregroundColor(AdminSurface.emerald)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AdminSurface.emerald.opacity(0.1))
                    )
                    .padding(.horizontal, 16)
                }

                // Delivery Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.get("Deliv_NotesOptional", alter: "ملاحظة التسليم (اختياري)"))
                        .font(PPBrandFont.caption(12))
                        .foregroundColor(AdminSurface.secondaryText)

                    TextField(Language.get("Deliv_NotesPlaceholder", alter: "تم التسليم عند الباب / للعميل شخصياً..."), text: $deliveryNotes)
                        .font(PPBrandFont.regular(14))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AdminSurface.cardElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AdminSurface.hairline, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)

                Spacer()

                // Confirm and Complete Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    state.collectCashAndComplete(order, note: deliveryNotes.isEmpty ? nil : deliveryNotes)
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(Language.get("Deliv_ConfirmCashAndDeliver", alter: "تأكيد التحصيل وتسليم الطلب"))
                            .font(PPBrandFont.bold(16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .fill(AdminSurface.emerald)
                    )
                    .foregroundColor(.white)
                    .shadow(color: AdminSurface.emerald.opacity(0.32), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PPDeliveryTouchButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Language.get("Cancel", alter: "إلغاء")) {
                        dismiss()
                    }
                    .font(PPBrandFont.bold(15))
                    .foregroundColor(AdminSurface.primary)
                }
            }
        }
    }

    private func cashPresetButton(title: String, amount: Double) -> some View {
        Button(action: {
            cashReceivedInput = String(format: "%.0f", amount)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .font(PPBrandFont.caption(12))
                .foregroundColor(AdminSurface.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AdminSurface.cardElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AdminSurface.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.94))
    }
}

// MARK: - Category-Defining Full Delivery Driver Dashboard Screen

public struct PPDeliveryDriverControlView: View {
    @StateObject private var state = PPDeliveryDriverObservableState()
    @Environment(\.dismiss) private var dismiss

    private var isRTL: Bool { Language.isRTL() }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AdminSurface.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. Pilot Status Bar
                        pilotHeaderBar

                        // 2. Active Mission Flight Deck (if an order is en-route)
                        if let activeOrder = state.activeMissionOrder {
                            PPDeliveryActiveMissionDeck(order: activeOrder, state: state)
                        }

                        // 3. Shift Telemetry Grid
                        PPDeliveryTelemetryGrid(state: state)

                        // 4. Available Dispatches Radar
                        if !state.availableDispatches.isEmpty {
                            PPDeliveryDispatchRadarSection(orders: state.availableDispatches, state: state)
                        }

                        // 5. Omni-Filter & Search Capsule
                        filterAndSearchCapsule

                        // 6. Orders List
                        ordersListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
                .refreshable {
                    state.refreshOrders()
                }
            }
            .navigationTitle(Language.get("Deliv_Cockpit_Title", alter: "غرفة عمليات التوصيل"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        state.refreshOrders()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AdminSurface.primary)
                    }
                }
            }
            .sheet(item: $state.cashSheetOrder) { order in
                PPDeliveryCashCollectionSheet(order: order, state: state)
            }
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
    }

    // MARK: - Pilot Header Bar

    private var pilotHeaderBar: some View {
        HStack(spacing: 12) {
            // Operator status ring
            ZStack {
                Circle()
                    .stroke(state.dutyState.tintColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(state.dutyState.tintColor)
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Language.get("Deliv_Pilot_Title", alter: "كابتن التوصيل"))
                    .font(PPBrandFont.bold(16))
                    .foregroundColor(AdminSurface.primaryText)

                Text(state.dutyState.title)
                    .font(PPBrandFont.caption(12))
                    .foregroundColor(state.dutyState.tintColor)
            }

            Spacer()

            // Duty Toggle Pill
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    state.toggleDuty()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: state.dutyState.systemIcon)
                        .font(.system(size: 12, weight: .bold))

                    Text(state.dutyState.shortTitle)
                        .font(PPBrandFont.bold(13))
                }
                .foregroundColor(state.dutyState.tintColor)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(state.dutyState.tintColor.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(state.dutyState.tintColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.94))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AdminSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AdminSurface.hairline, lineWidth: 1)
        )
    }

    // MARK: - Filter and Search Capsule

    private var filterAndSearchCapsule: some View {
        VStack(spacing: 10) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AdminSurface.secondaryText)
                    .font(.system(size: 15))

                TextField(Language.get("Deliv_SearchOrders", alter: "بحث برقم الطلب، اسم العميل أو المنطقة..."), text: $state.searchQuery)
                    .font(PPBrandFont.medium(14))

                if !state.searchQuery.isEmpty {
                    Button(action: { state.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AdminSurface.secondaryText)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AdminSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AdminSurface.hairline, lineWidth: 1)
            )

            // Segmented Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PPDriverFilter.allCases) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                state.selectedFilter = filter
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 12))

                                Text(filter.title)
                                    .font(PPBrandFont.bold(13))
                            }
                            .foregroundColor(state.selectedFilter == filter ? .white : AdminSurface.primaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(state.selectedFilter == filter ? AdminSurface.primary : AdminSurface.card)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(state.selectedFilter == filter ? Color.clear : AdminSurface.hairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.94))
                    }
                }
            }
        }
    }

    // MARK: - Orders List Section

    private var ordersListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let filtered = state.filteredOrders

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AdminSurface.secondaryText.opacity(0.5))

                    Text(Language.get("Deliv_EmptyTitle", alter: "لا توجد طلبات في هذا القسم"))
                        .font(PPBrandFont.bold(15))
                        .foregroundColor(AdminSurface.primaryText)

                    Text(Language.get("Deliv_EmptySubtitle", alter: "ستظهر الطلبات الجديدة والمسارات هنا مباشرة"))
                        .font(PPBrandFont.caption(13))
                        .foregroundColor(AdminSurface.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AdminSurface.card.opacity(0.5))
                )
            } else {
                ForEach(filtered, id: \.orderId) { order in
                    orderSummaryRow(order)
                }
            }
        }
    }

    private func orderSummaryRow(_ order: PPDeliveryOrderModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(!order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.bestOrderNumber())
                    .font(PPBrandFont.bold(14))
                    .foregroundColor(AdminSurface.primaryText)

                Spacer()

                Text(order.displayStatus() ?? "")
                    .font(PPBrandFont.caption(12))
                    .foregroundColor(AdminSurface.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AdminSurface.primary.opacity(0.1)))
            }

            HStack {
                Text(!order.customerName.isEmpty ? order.customerName : Language.get("Customer", alter: "العميل"))
                    .font(PPBrandFont.medium(14))
                    .foregroundColor(AdminSurface.primaryText)

                Spacer()

                Text(order.formattedTotal() ?? "")
                    .font(PPBrandFont.bold(14))
                    .foregroundColor(order.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                    .monospacedDigit()
            }

            Text(order.pp_visibleCustomerLocationSummary().isEmpty ? order.deliveryAddress : order.pp_visibleCustomerLocationSummary())
                .font(PPBrandFont.caption(12))
                .foregroundColor(AdminSurface.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AdminSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AdminSurface.hairline, lineWidth: 1)
        )
    }
}
