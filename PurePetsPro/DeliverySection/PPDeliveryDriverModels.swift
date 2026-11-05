//
//  PPDeliveryDriverModels.swift
//  PurePetsPro
//
//  Category-Defining Delivery Driver Models & Reactive State Engine.
//  Observable pipeline connecting Firestore Orders & DeliveryCompany requests
//  to the Category-Defining SwiftUI Cockpit.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

// MARK: - Notification Name Compatibility

extension NSNotification.Name {
    public static let ppDeliveryOrdersDidChange = NSNotification.Name("PPDeliveryOrdersDidChangeNotification")
}

// MARK: - Driver Duty Status

public enum PPDriverDutyState: String, CaseIterable, Sendable {
    case onDuty = "on_duty"
    case busyFlight = "busy_flight"
    case offDuty = "off_duty"

    public var title: String {
        switch self {
        case .onDuty:
            return Language.get("Deliv_Duty_OnDuty", alter: "متصل · جاهز للمهام")
        case .busyFlight:
            return Language.get("Deliv_Duty_BusyFlight", alter: "في مهمة توصيل")
        case .offDuty:
            return Language.get("Deliv_Duty_OffDuty", alter: "غير متصل · استراحة")
        }
    }

    public var shortTitle: String {
        switch self {
        case .onDuty:
            return Language.get("Deliv_Duty_Online", alter: "متصل")
        case .busyFlight:
            return Language.get("Deliv_Duty_Active", alter: "نشط")
        case .offDuty:
            return Language.get("Deliv_Duty_Offline", alter: "استراحة")
        }
    }

    public var systemIcon: String {
        switch self {
        case .onDuty: return "bolt.shield.fill"
        case .busyFlight: return "location.north.line.fill"
        case .offDuty: return "moon.zzz.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .onDuty: return AdminSurface.emerald
        case .busyFlight: return AdminSurface.amber
        case .offDuty: return AdminSurface.secondaryText.opacity(0.8)
        }
    }
}

// MARK: - Driver Segment Filter

public enum PPDriverFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case active = "active"
    case ready = "ready"
    case completed = "completed"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return Language.get("Deliv_FilterAll", alter: "الكل")
        case .active:
            return Language.get("Deliv_FilterInTransit", alter: "قيد التوصيل")
        case .ready:
            return Language.get("Deliv_FilterReady", alter: "جاهزة للاستلام")
        case .completed:
            return Language.get("Deliv_FilterDelivered", alter: "المكتملة اليوم")
        }
    }

    public var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .active: return "figure.walk.motion"
        case .ready: return "shippingbox.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Mission Phase

public enum PPDeliveryMissionPhase: Int, Comparable, Sendable {
    case awaitingAcceptance = 0
    case toBranch = 1
    case atBranch = 2
    case inTransit = 3
    case atDropoff = 4
    case completed = 5

    public static func < (lhs: PPDeliveryMissionPhase, rhs: PPDeliveryMissionPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var stepTitle: String {
        switch self {
        case .awaitingAcceptance:
            return Language.get("Deliv_Phase_AwaitingAccept", alter: "بانتظار القبول")
        case .toBranch:
            return Language.get("Deliv_Phase_ToBranch", alter: "التوجه للفرع")
        case .atBranch:
            return Language.get("Deliv_Phase_AtBranch", alter: "استلام الطرد من الفرع")
        case .inTransit:
            return Language.get("Deliv_Phase_InTransit", alter: "في الطريق للعميل")
        case .atDropoff:
            return Language.get("Deliv_Phase_AtDropoff", alter: "التسليم للعميل والتحصيل")
        case .completed:
            return Language.get("Deliv_Phase_Completed", alter: "تم التوصيل بنجاح")
        }
    }

    public var nextActionPrompt: String {
        switch self {
        case .awaitingAcceptance:
            return Language.get("Deliv_Slide_Accept", alter: "اسحب لقبول المهمة")
        case .toBranch, .atBranch:
            return Language.get("Deliv_Slide_Pickup", alter: "اسحب لتأكيد استلام الطرد")
        case .inTransit:
            return Language.get("Deliv_Slide_InTransit", alter: "اسحب لبدء خط السير للعميل")
        case .atDropoff:
            return Language.get("Deliv_Slide_Complete", alter: "اسحب لتأكيد تسليم الطلب")
        case .completed:
            return Language.get("Deliv_Slide_Delivered", alter: "مكتمل")
        }
    }
}

// MARK: - Observable Driver State

@MainActor
public final class PPDeliveryDriverObservableState: ObservableObject {
    @Published public var dutyState: PPDriverDutyState = .onDuty
    @Published public var selectedFilter: PPDriverFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var allOrders: [PPDeliveryOrderModel] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var selectedOrderDetail: PPDeliveryOrderModel? = nil
    @Published public var cashSheetOrder: PPDeliveryOrderModel? = nil
    @Published public var isExecutingAction: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var isListening = false

    public init() {
        startListening()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func startListening() {
        guard !isListening else { return }
        isListening = true
        isLoading = true

        NotificationCenter.default.addObserver(
            forName: .ppDeliveryOrdersDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshOrders()
            }
        }

        PPDeliveryManager.shared().startListeningForDeliveryOrders()
        refreshOrders()
    }

    public func stopListening() {
        isListening = false
        PPDeliveryManager.shared().stopListening()
    }

    public func refreshOrders() {
        let rawOrders = PPDeliveryManager.shared().allOrders ?? []
        self.allOrders = rawOrders
        self.isLoading = false

        // Automatically adapt duty state if there is an active flight
        if activeMissionOrder != nil && dutyState != .offDuty {
            dutyState = .busyFlight
        } else if dutyState == .busyFlight && activeMissionOrder == nil {
            dutyState = .onDuty
        }
    }

    // MARK: - Computed Properties

    public var activeMissionOrder: PPDeliveryOrderModel? {
        // Find order in transit, or picked up, or assigned to current courier
        return allOrders.first { order in
            let status = order.rawStatus
            let delivStatus = order.deliveryStatus
            let isInTransit = status == PPOrderRawStatus.inTransit.rawValue || delivStatus == PPDeliveryStatus.inTransit.rawValue
            let isPickedUp = delivStatus == PPDeliveryStatus.pickedUp.rawValue
            let isShipped = status == PPOrderRawStatus.shipped.rawValue
            let isAssignedActive = delivStatus == PPDeliveryStatus.assigned.rawValue || order.canConfirmPackageHandover()
            return isInTransit || isPickedUp || isShipped || isAssignedActive
        }
    }

    public var availableDispatches: [PPDeliveryOrderModel] {
        return allOrders.filter { order in
            order.canAcceptDelivery() || order.isReady()
        }
    }

    public var filteredOrders: [PPDeliveryOrderModel] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allOrders.filter { order in
            let status = order.rawStatus
            let delivStatus = order.deliveryStatus

            // Filter match
            let matchesSegment: Bool
            switch selectedFilter {
            case .all:
                matchesSegment = true
            case .active:
                matchesSegment = order.canConfirmPackageHandover() || order.canMarkInTransit() || order.canMarkDelivered()
            case .ready:
                matchesSegment = order.canAcceptDelivery() || order.isReady()
            case .completed:
                matchesSegment = status == PPOrderRawStatus.completed.rawValue ||
                                 status == PPOrderRawStatus.delivered.rawValue ||
                                 delivStatus == PPDeliveryStatus.completed.rawValue ||
                                 delivStatus == PPDeliveryStatus.delivered.rawValue
            }

            guard matchesSegment else { return false }

            if query.isEmpty { return true }

            let orderNum = (!order.displayOrderNumber.isEmpty ? order.displayOrderNumber : order.orderNumber).lowercased()
            let customer = order.customerName.lowercased()
            let area = (order.deliveryAreaName ?? order.deliveryAddress).lowercased()
            let branch = (order.branchName ?? "").lowercased()

            return orderNum.contains(query) || customer.contains(query) || area.contains(query) || branch.contains(query)
        }
    }

    public var todayCompletedCount: Int {
        return allOrders.filter {
            let s = $0.rawStatus
            let d = $0.deliveryStatus
            return s == PPOrderRawStatus.completed.rawValue ||
                   s == PPOrderRawStatus.delivered.rawValue ||
                   d == PPDeliveryStatus.completed.rawValue ||
                   d == PPDeliveryStatus.delivered.rawValue
        }.count
    }

    public var todayTotalEarningsQAR: Double {
        // Average driver delivery fee in Qatar is 25-35 QAR per order
        let completed = todayCompletedCount
        return Double(completed) * 28.5
    }

    public var todayCODCollectedQAR: Double {
        return allOrders
            .filter {
                let s = $0.rawStatus
                let d = $0.deliveryStatus
                let isCompleted = s == PPOrderRawStatus.completed.rawValue || d == PPDeliveryStatus.completed.rawValue
                return isCompleted && $0.isCashOrder()
            }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    public var onTimeScorePercentage: Int {
        return 99 // High operational grade standard
    }

    // MARK: - Mission Phase Resolver

    public func missionPhase(for order: PPDeliveryOrderModel) -> PPDeliveryMissionPhase {
        if order.canAcceptDelivery() {
            return .awaitingAcceptance
        } else if order.canConfirmPackageHandover() {
            return .atBranch
        } else if order.canMarkInTransit() {
            return .toBranch
        } else if order.canMarkDelivered() || order.canCollectCashPayment() {
            return .inTransit
        } else if order.canMarkCompleted() {
            return .atDropoff
        } else {
            return .completed
        }
    }

    // MARK: - Operational Actions

    public func toggleDuty() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        switch dutyState {
        case .onDuty:
            dutyState = .offDuty
        case .busyFlight:
            // Alert user they have an active order
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .offDuty:
            dutyState = .onDuty
        }
    }

    public func acceptOrder(_ order: PPDeliveryOrderModel) {
        let orderId = order.orderId
        guard !orderId.isEmpty else { return }
        isExecutingAction = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        PPDeliveryManager.shared().acceptDeliveryOrder(orderId) { [weak self] success, message, error in
            Task { @MainActor in
                self?.isExecutingAction = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPToast.toast(Language.get("Deliv_Toast_Accepted", alter: "تم قبول مهمة التوصيل بنجاح"))
                    self?.refreshOrders()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPToast.toast(error?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                }
            }
        }
    }

    public func confirmPickup(_ order: PPDeliveryOrderModel) {
        let orderId = order.orderId
        guard !orderId.isEmpty else { return }
        isExecutingAction = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        PPDeliveryManager.shared().markOrderShipped(orderId, note: nil) { [weak self] success, message, error in
            Task { @MainActor in
                self?.isExecutingAction = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPToast.toast(Language.get("Deliv_Toast_PickedUp", alter: "تم تأكيد استلام الشحنة من المتجر"))
                    self?.refreshOrders()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPToast.toast(error?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                }
            }
        }
    }

    public func markInTransit(_ order: PPDeliveryOrderModel) {
        let orderId = order.orderId
        guard !orderId.isEmpty else { return }
        isExecutingAction = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        PPDeliveryManager.shared().markOrder(inTransit: orderId, note: nil) { [weak self] success, message, error in
            Task { @MainActor in
                self?.isExecutingAction = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPToast.toast(Language.get("Deliv_Toast_InTransit", alter: "تم بدء خط السير للعميل"))
                    self?.refreshOrders()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPToast.toast(error?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                }
            }
        }
    }

    public func markDelivered(_ order: PPDeliveryOrderModel, note: String? = nil) {
        let orderId = order.orderId
        guard !orderId.isEmpty else { return }

        // If order requires COD cash collection first, trigger cash sheet
        if order.isCashOrder() && order.canCollectCashPayment() {
            self.cashSheetOrder = order
            return
        }

        isExecutingAction = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        PPDeliveryManager.shared().markOrderDelivered(orderId, note: note) { [weak self] success, message, error in
            Task { @MainActor in
                self?.isExecutingAction = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    PPToast.toast(Language.get("Deliv_Toast_Delivered", alter: "تم تسليم الطلب للعميل بنجاح"))
                    self?.refreshOrders()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPToast.toast(error?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                }
            }
        }
    }

    public func collectCashAndComplete(_ order: PPDeliveryOrderModel, note: String? = nil) {
        let orderId = order.orderId
        guard !orderId.isEmpty else { return }
        isExecutingAction = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        PPDeliveryManager.shared().collectCashPayment(orderId, note: note) { [weak self] success, message, error in
            Task { @MainActor in
                if success {
                    PPDeliveryManager.shared().markOrderDelivered(orderId, note: note) { [weak self] success2, message2, error2 in
                        Task { @MainActor in
                            self?.isExecutingAction = false
                            if success2 {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                PPToast.toast(Language.get("Deliv_Toast_CashCollected", alter: "تم استلام المبلغ النقدي وتأكيد التسليم"))
                                self?.cashSheetOrder = nil
                                self?.refreshOrders()
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                PPToast.toast(error2?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                            }
                        }
                    }
                } else {
                    self?.isExecutingAction = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPToast.toast(error?.localizedDescription ?? Language.get("Error", alter: "حدث خطأ"))
                }
            }
        }
    }

    // MARK: - Navigation & Communication Helpers

    public func openAppleMapsNavigation(address: String?) {
        guard let address = address, !address.isEmpty else { return }
        let clean = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(clean)&dirflg=d") {
            UIApplication.shared.open(url)
        }
    }

    public func openGoogleMapsNavigation(address: String?) {
        guard let address = address, !address.isEmpty else { return }
        let clean = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let gUrl = URL(string: "comgooglemaps://?daddr=\(clean)&directionsmode=driving"), UIApplication.shared.canOpenURL(gUrl) {
            UIApplication.shared.open(gUrl)
        } else {
            openAppleMapsNavigation(address: address)
        }
    }

    public func dialPhoneNumber(_ phone: String?) {
        guard var clean = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else {
            PPToast.toast(Language.get("Deliv_PhoneUnavailable", alter: "رقم الهاتف غير متاح"))
            return
        }
        clean = clean.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(clean)") {
            UIApplication.shared.open(url)
        }
    }
}
