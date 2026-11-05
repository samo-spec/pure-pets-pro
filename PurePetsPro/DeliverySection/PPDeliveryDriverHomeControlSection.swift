//
//  PPDeliveryDriverHomeControlSection.swift
//  PurePetsPro
//
//  Category-Defining Delivery Driver Cockpit Section for the Home Screen.
//  Integrated directly on the Pro Home Dashboard as a tactile, living flight deck.
//

import SwiftUI

public struct PPDeliveryDriverHomeControlSection: View {
    @StateObject private var state = PPDeliveryDriverObservableState()
    public let onOpenCockpit: () -> Void

    private var isRTL: Bool { Language.isRTL() }

    public init(onOpenCockpit: @escaping () -> Void) {
        self.onOpenCockpit = onOpenCockpit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header & Duty Capsule
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(state.dutyState.tintColor.opacity(0.3), lineWidth: 2.5)
                        .frame(width: 36, height: 36)

                    Circle()
                        .fill(state.dutyState.tintColor)
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Language.get("Deliv_Section_ControlTitle", alter: "مركز عمليات التوصيل الميداني"))
                            .font(PPBrandFont.bold(15))
                            .foregroundColor(AdminSurface.primaryText)

                        Circle()
                            .fill(AdminSurface.emerald)
                            .frame(width: 6, height: 6)
                    }

                    Text(state.dutyState.title)
                        .font(PPBrandFont.caption(12))
                        .foregroundColor(state.dutyState.tintColor)
                }

                Spacer()

                // Duty Toggle Pill
                Button(action: {
                    state.toggleDuty()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: state.dutyState.systemIcon)
                            .font(.system(size: 11, weight: .bold))
                        Text(state.dutyState.shortTitle)
                            .font(PPBrandFont.bold(12))
                    }
                    .foregroundColor(state.dutyState.tintColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(state.dutyState.tintColor.opacity(0.12))
                    )
                }
            }

            // In-Flight Active Mission Card (if any)
            if let activeOrder = state.activeMissionOrder {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AdminSurface.amber)
                            Text(Language.get("Deliv_ActiveEnRoute", alter: "مهمة جارية الآن"))
                                .font(PPBrandFont.bold(13))
                                .foregroundColor(AdminSurface.amber)
                        }

                        Spacer()

                        Text(!activeOrder.displayOrderNumber.isEmpty ? activeOrder.displayOrderNumber : activeOrder.bestOrderNumber())
                            .font(PPBrandFont.bold(13))
                            .foregroundColor(AdminSurface.primaryText)
                    }

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeOrder.canConfirmPackageHandover() ? Language.get("Deliv_Waypoint_Pickup", alter: "الاستلام من الفرع") : Language.get("Deliv_Waypoint_Dropoff", alter: "التوصيل للعميل"))
                                .font(PPBrandFont.caption(11))
                                .foregroundColor(AdminSurface.secondaryText)

                            Text(activeOrder.canConfirmPackageHandover() ? (activeOrder.branchName ?? Language.get("Branch", alter: "الفرع")) : (!activeOrder.customerName.isEmpty ? activeOrder.customerName : Language.get("Customer", alter: "العميل")))
                                .font(PPBrandFont.bold(14))
                                .foregroundColor(AdminSurface.primaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Financial Pill
                        Text(activeOrder.formattedTotal() ?? "")
                            .font(PPBrandFont.bold(13))
                            .foregroundColor(activeOrder.isCashOrder() ? AdminSurface.amber : AdminSurface.emerald)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(activeOrder.isCashOrder() ? AdminSurface.amber.opacity(0.12) : AdminSurface.emerald.opacity(0.12))
                            )
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AdminSurface.amber.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AdminSurface.amber.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Shift Fast Telemetry Bar
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AdminSurface.emerald)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(state.todayCompletedCount)")
                                .font(PPBrandFont.bold(14))
                                .foregroundColor(AdminSurface.primaryText)
                            Text(Language.get("Deliv_StopsToday", alter: "تم تسليمها"))
                                .font(PPBrandFont.caption(10))
                                .foregroundColor(AdminSurface.secondaryText)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AdminSurface.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.0f %@", state.todayTotalEarningsQAR, Language.get("QAR", alter: "ر.ق")))
                                .font(PPBrandFont.bold(14))
                                .foregroundColor(AdminSurface.primaryText)
                            Text(Language.get("Deliv_Earnings", alter: "أرباح الشيفت"))
                                .font(PPBrandFont.caption(10))
                                .foregroundColor(AdminSurface.secondaryText)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.blue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(state.availableDispatches.count)")
                                .font(PPBrandFont.bold(14))
                                .foregroundColor(AdminSurface.primaryText)
                            Text(Language.get("Deliv_ReadyPickup", alter: "جاهزة للاستلام"))
                                .font(PPBrandFont.caption(10))
                                .foregroundColor(AdminSurface.secondaryText)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AdminSurface.card.opacity(0.7))
                )
            }

            // Launch Cockpit Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenCockpit()
            }) {
                HStack {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 16, weight: .semibold))

                    Text(Language.get("Deliv_LaunchCockpit", alter: "فتح غرفة عمليات ومسارات التوصيل"))
                        .font(PPBrandFont.bold(14))

                    Spacer()

                    Image(systemName: isRTL ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 18))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AdminSurface.primary)
                )
                .shadow(color: AdminSurface.primary.opacity(0.3), radius: 8, x: 0, y: 3)
            }
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
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }
}
