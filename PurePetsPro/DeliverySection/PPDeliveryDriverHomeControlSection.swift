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

    @State private var radarPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRTL: Bool { Language.isRTL() }

    public init(onOpenCockpit: @escaping () -> Void) {
        self.onOpenCockpit = onOpenCockpit
    }

    public var body: some View {
        VStack(spacing: 16) {
            // 1. Mission Control Header & Duty Switcher Capsule
            headerDeck

            // 2. Dynamic Center Content: In-Flight Mission OR Live Shift Telemetry
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
                                state.dutyState.tintColor.opacity(state.dutyState == .offDuty ? 0.03 : 0.09),
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
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    radarPulse = true
                }
            }
        }
    }

    // MARK: - Header Deck

    private var headerDeck: some View {
        HStack(alignment: .center, spacing: 12) {
            // Animated Status Orbital Beacon
            ZStack {
                // Expanding concentric radar pulse wave (when on duty)
                if state.dutyState != .offDuty && !reduceMotion {
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
                        .fill(state.dutyState == .offDuty ? AdminSurface.secondaryText.opacity(0.4) : AdminSurface.emerald)
                        .frame(width: 7, height: 7)
                }

                Text(state.dutyState.title)
                    .font(PPBrandFont.regular(12))
                    .foregroundColor(state.dutyState.tintColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Tactile Duty Toggle Switch
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    state.toggleDuty()
                }
            }) {
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
            }
            .buttonStyle(PPDeliveryTouchButtonStyle(pressedScale: 0.92))
            .accessibilityLabel(state.dutyState.title)
            .accessibilityHint(Language.get("Deliv_Accessibility_ToggleDutyHint", alter: "اضغط للتبديل بين الاتصال والاستراحة"))
        }
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

            // Pod 2: Shift Earnings (أرباح الشيفت)
            telemetryPod(
                icon: "banknote.fill",
                iconColor: AdminSurface.emerald,
                value: String(format: "%.0f %@", state.todayTotalEarningsQAR, Language.get("QAR", alter: "ر.ق")),
                title: Language.get("Deliv_Earnings", alter: "أرباح الشيفت"),
                hasAlertBadge: false
            )

            // Pod 3: Completed Stops Today (تم تسليمها)
            telemetryPod(
                icon: "checkmark.seal.fill",
                iconColor: AdminSurface.primary,
                value: "\(state.todayCompletedCount)",
                title: Language.get("Deliv_StopsToday", alter: "تم تسليمها"),
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
