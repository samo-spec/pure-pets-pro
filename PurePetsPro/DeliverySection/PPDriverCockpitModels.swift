//
//  PPDriverCockpitModels.swift
//  PurePetsPro
//
//  Unified driver cockpit for official Pure Pets workforce drivers and partner
//  delivery-company drivers. One presentation model, two server authorities:
//
//  - Official fleet: getDriverDeliveryWorkspace / executeDriverDeliveryTask /
//    setDriverDeliveryAvailability (FULFILLMENT_V1 and official legacy requests).
//  - Partner company: listMyAssignedCompanyDeliveries / getCompanyDeliveryRequest /
//    updateCompanyDeliveryStatus / setCompanyDriverAvailability.
//
//  The store never shows success before the callable confirms it, keeps the
//  same command identifier for a safe retry after an uncertain network outcome,
//  and drops responses that belong to another signed-in account.
//

import Foundation
import UIKit

// MARK: - Notifications

extension Notification.Name {
    /// Posted when a driver push arrives so a visible cockpit refreshes at once.
    static let ppDriverCockpitShouldRefresh = Notification.Name("PPDriverCockpitShouldRefreshNotification")
}

// MARK: - Text helpers

func ppDriverText(_ key: String) -> String {
    Language.get(key, alter: nil)
}

func ppDriverFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: ppDriverText(key),
           locale: Locale(identifier: Language.currentLanguageCode()),
           arguments: arguments)
}

/// Bidirectional isolation for identifiers inside Arabic or English sentences.
func ppDriverIsolated(_ value: String) -> String {
    "\u{2068}\(value)\u{2069}"
}

/// Arabic-Indic and other Unicode decimal digits typed on a localized keypad
/// are converted to ASCII before they are sent for server verification.
func ppDriverASCIIDigits(_ value: String) -> String {
    var output = ""
    for character in value {
        if let digit = character.wholeNumberValue, character.isNumber, (0...9).contains(digit) {
            output.append(Character(String(digit)))
        } else if !character.isWhitespace {
            output.append(character)
        }
    }
    return output
}

func ppDriverMoney(_ amount: Double, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: Language.currentLanguageCode())
    formatter.numberStyle = .currency
    formatter.currencyCode = currency.isEmpty ? "QAR" : currency
    formatter.maximumFractionDigits = 2
    let text = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, currency)
    return ppDriverIsolated(text)
}

// MARK: - Dictionary decoding (pure, nonisolated)

private func cpDict(_ value: Any?) -> [String: Any] {
    if let dictionary = value as? [String: Any] { return dictionary }
    if let dictionary = value as? NSDictionary {
        var output: [String: Any] = [:]
        for (key, element) in dictionary {
            if let key = key as? String { output[key] = element }
        }
        return output
    }
    return [:]
}

private func cpArray(_ value: Any?) -> [Any] {
    (value as? [Any]) ?? []
}

private func cpString(_ value: Any?) -> String {
    if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
    if let number = value as? NSNumber { return number.stringValue }
    return ""
}

private func cpInt(_ value: Any?) -> Int {
    if let number = value as? NSNumber { return number.intValue }
    return Int(cpString(value)) ?? 0
}

private func cpBool(_ value: Any?) -> Bool {
    if let number = value as? NSNumber { return number.boolValue }
    return false
}

private func cpDouble(_ value: Any?) -> Double? {
    if value is NSNull { return nil }
    if let number = value as? NSNumber { return number.doubleValue }
    return Double(cpString(value))
}

private func cpDate(_ value: Any?) -> Date? {
    let dictionary = cpDict(value)
    if !dictionary.isEmpty {
        let seconds = cpDouble(dictionary["_seconds"] ?? dictionary["seconds"])
        return seconds.map { Date(timeIntervalSince1970: $0) }
    }
    let text = cpString(value)
    guard !text.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}

// MARK: - Domain values

enum PPDriverAuthority: String, Sendable {
    case fulfillmentV1 = "FULFILLMENT_V1"
    case officialCompanyRequest = "COMPANY_DELIVERY_REQUEST"
    case partnerCompanyRequest = "PARTNER_COMPANY_REQUEST"
}

enum PPDriverContextKind: String, Sendable {
    case officialDriver = "OFFICIAL_DRIVER"
    case partnerDriver = "PARTNER_DRIVER"
}

struct PPDriverPresence: Sendable, Equatable {
    let online: Bool
    let available: Bool
    let assignmentsPaused: Bool
    let revision: Int
    let activeDeliveryCount: Int
}

struct PPDriverContext: Sendable, Identifiable, Equatable {
    let id: String
    let kind: PPDriverContextKind
    let companyID: String
    let companyName: String
    let role: String
    let capabilities: [String: Bool]
    let presence: PPDriverPresence?
    let dispatcherPhone: String
}

struct PPDriverContextResolution: Sendable {
    let contexts: [PPDriverContext]
    let restrictionReason: String
}

struct PPDriverAvailability: Sendable, Equatable {
    let companyID: String
    let online: Bool
    let assignmentsPaused: Bool
    let accountActive: Bool
    let readinessReasons: [String]
    let revision: Int
    let activeDeliveryCount: Int
    let canSelfAcceptOrders: Bool
}

struct PPDriverAddress: Sendable, Equatable {
    let primary: String
    let secondary: String
    let mapQuery: String
    let phone: String
}

struct PPDriverTaskAction: Sendable, Equatable {
    /// CLAIM, PICK_UP, START_TRANSIT, DELIVER, CONFIRM_PAYMENT or COMPLETE.
    let code: String
    /// Partner company target status; empty for the official workspace.
    let toStatus: String

    /// Commands the backend accepts from a driver. Any other code from a newer
    /// server is dropped so the dock never offers an action it cannot label
    /// or execute.
    static let supportedCodes: Set<String> = ["CLAIM", "PICK_UP", "START_TRANSIT",
                                              "DELIVER", "CONFIRM_PAYMENT", "COMPLETE"]
}

struct PPDriverProof: Sendable, Equatable {
    let receiverNameRequired: Bool
    let photoRequired: Bool
    let signatureRequired: Bool
    let otpRequired: Bool

    var isEmpty: Bool { !receiverNameRequired && !photoRequired && !signatureRequired && !otpRequired }
}

struct PPDriverCash: Sendable, Equatable {
    let required: Bool
    let collected: Bool
    let amount: Double?
    let currency: String
}

/// Lifecycle position used for the step rail. Derived from the server status.
enum PPDriverStage: Int, Sendable, Comparable {
    case offer = 0
    case toPickup = 1
    case collected = 2
    case inTransit = 3
    case delivered = 4
    case settled = 5
    case closed = 6
    case ended = 7
    case unknown = 8

    init(status: String) {
        switch status {
        case "delivery_requested", "accepted_by_company", "offered": self = .offer
        case "delivery_assigned", "awaiting_handover", "assigned_to_driver": self = .toPickup
        case "handed_over", "picked_up": self = .collected
        case "in_transit": self = .inTransit
        case "delivered", "payment_pending": self = .delivered
        case "payment_confirmed": self = .settled
        case "completed": self = .closed
        case "cancelled", "failed", "returned", "rejected", "expired": self = .ended
        default: self = .unknown
        }
    }

    static func < (lhs: PPDriverStage, rhs: PPDriverStage) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Index of the first unfinished milestone: pickup, on the way, delivered, closed.
    var railIndex: Int {
        switch self {
        case .offer, .toPickup, .unknown: return 0
        case .collected: return 1
        case .inTransit: return 2
        case .delivered, .settled: return 3
        case .closed, .ended: return 4
        }
    }
}

/// A command counts as confirmed only when the server shows the task past the
/// state the command started from. Cancelled, failed or unrecognised states
/// never count as progress, even though they sort after the delivery stages.
func ppDriverStageProgressed(_ stage: PPDriverStage, from expected: PPDriverStage) -> Bool {
    stage != .unknown && stage != .ended && expected != .unknown && expected != .ended && stage > expected
}

/// Keeps one entry per task (the latest read) when pages or compatibility
/// queries return the same delivery twice.
func ppDriverUniqueTasks(_ tasks: [PPDriverTask]) -> [PPDriverTask] {
    var seen = Set<String>()
    var unique: [PPDriverTask] = []
    for task in tasks.reversed() where seen.insert(task.id).inserted {
        unique.append(task)
    }
    return unique.reversed()
}

struct PPDriverTask: Sendable, Identifiable, Equatable {
    let taskID: String
    let authority: PPDriverAuthority
    let companyID: String
    let orderNumber: String
    let status: String
    let revision: Int
    let mine: Bool
    let actions: [PPDriverTaskAction]
    let pickup: PPDriverAddress
    let dropoff: PPDriverAddress
    let customerName: String
    let customerPhone: String
    let proof: PPDriverProof
    let cash: PPDriverCash?
    let updatedAt: Date?

    var id: String { PPDriverTask.key(authority: authority.rawValue, taskID: taskID) }
    var stage: PPDriverStage { PPDriverStage(status: status) }
    var isTerminal: Bool { stage == .closed || stage == .ended }
    var primaryAction: PPDriverTaskAction? { actions.first }
    var awaitsStoreHandover: Bool {
        mine && authority == .fulfillmentV1 && status == "delivery_assigned" && actions.isEmpty
    }

    static func key(authority: String, taskID: String) -> String { "\(authority):\(taskID)" }
}

/// Shared presentation safety for Home and the cockpit. The backend remains
/// authoritative; unsupported proof and unknown cash amounts cannot be skipped
/// by choosing the more compact Home surface.
func ppDriverActionBlockKey(_ action: PPDriverTaskAction, task: PPDriverTask,
                            canSelfAcceptOrders: Bool) -> String? {
    if action.code == "CLAIM" && !canSelfAcceptOrders {
        return "Delivery_Driver_Acceptance_Managed"
    }
    if action.code == "DELIVER" && task.authority != .fulfillmentV1 &&
        (task.proof.photoRequired || task.proof.signatureRequired) {
        return "DriverCockpit_Blocked_Proof"
    }
    let cashNeeded = action.code == "CONFIRM_PAYMENT" ||
        (action.code == "DELIVER" && task.authority != .fulfillmentV1 &&
         task.cash?.required == true && task.cash?.collected != true)
    if cashNeeded && ((task.cash?.amount ?? 0) <= 0 ||
        (action.code == "CONFIRM_PAYMENT" && (task.cash?.currency.count ?? 0) != 3)) {
        return "DriverCockpit_Blocked_Cash"
    }
    return nil
}

/// A confirmation captures the observed revision. A later refresh, reassignment,
/// or projected-action change invalidates that intent before the command writer.
func ppDriverActionSnapshotMatches(_ snapshot: PPDriverTask, current: PPDriverTask,
                                   action: PPDriverTaskAction) -> Bool {
    snapshot.id == current.id && snapshot.companyID == current.companyID &&
        snapshot.status == current.status && snapshot.revision == current.revision &&
        snapshot.mine == current.mine && snapshot.proof == current.proof && snapshot.cash == current.cash &&
        !current.isTerminal && current.actions.contains(action)
}

struct PPDriverFocusRequest: Sendable, Equatable {
    let taskID: String
    let authority: String
    let companyID: String

    var key: String { PPDriverTask.key(authority: authority, taskID: taskID) }
    var wantsPartner: Bool { authority == PPDriverAuthority.partnerCompanyRequest.rawValue }

    static func make(taskID: String?, authority: String?, companyID: String?) -> PPDriverFocusRequest? {
        let task = (taskID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let authorityValue = (authority ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !task.isEmpty, task.count <= 256, !task.contains("/"),
              PPDriverAuthority(rawValue: authorityValue) != nil else { return nil }
        let company = (companyID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return PPDriverFocusRequest(taskID: task, authority: authorityValue,
                                    companyID: company.contains("/") ? "" : company)
    }
}

struct PPDriverCommandInputs: Sendable, Equatable {
    var receiverName: String = ""
    var otp: String = ""
}

struct PPDriverNotice: Sendable, Equatable, Identifiable {
    enum Tone: Sendable { case info, success, warning, error }
    let id = UUID()
    let tone: Tone
    let text: String
}

// MARK: - Parsing

func ppParseDriverAddress(_ value: Any?) -> PPDriverAddress {
    if let rawString = value as? String, !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let clean = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        return PPDriverAddress(primary: clean, secondary: "", mapQuery: clean, phone: "")
    }
    let source = cpDict(value)
    var primary = ""
    for key in ["formattedAddress", "fullAddress", "address", "addressLine1", "locationName", "locatioName", "label"] {
        let candidate = cpString(source[key])
        if !candidate.isEmpty { primary = candidate; break }
    }
    if primary.isEmpty {
        var parts: [String] = []
        for key in ["buildingNumber", "building", "streetName", "street", "zoneNumber", "zone", "addressLine2"] {
            let part = cpString(source[key])
            if !part.isEmpty && !parts.contains(part) { parts.append(part) }
        }
        primary = parts.joined(separator: " · ")
    }
    var areaParts: [String] = []
    for key in ["area", "city", "country"] {
        let part = cpString(source[key])
        if !part.isEmpty && !areaParts.contains(part) && !primary.contains(part) { areaParts.append(part) }
    }
    var secondary = areaParts.joined(separator: " · ")
    if primary.isEmpty && !secondary.isEmpty {
        primary = secondary
        secondary = ""
    }
    var mapQuery = [primary, secondary].filter { !$0.isEmpty }.joined(separator: ", ")
    if let latitude = cpDouble(source["latitude"] ?? source["lat"]),
       let longitude = cpDouble(source["longitude"] ?? source["lng"]),
       latitude != 0 || longitude != 0 {
        mapQuery = "\(latitude),\(longitude)"
    }
    let phone = cpString(source["phoneNumber"] ?? source["phone"])
    // A named pickup branch leads; its street address moves to the second line.
    let names = cpDict(source["branchName"])
    let nameAr = cpString(names["ar"]), nameEn = cpString(names["en"])
    let branchName = Language.isRTL() ? (nameAr.isEmpty ? nameEn : nameAr) : (nameEn.isEmpty ? nameAr : nameEn)
    if !branchName.isEmpty {
        if primary.isEmpty {
            primary = branchName
        } else if branchName != primary {
            return PPDriverAddress(primary: branchName,
                                   secondary: [primary, secondary].filter { !$0.isEmpty }.joined(separator: " · "),
                                   mapQuery: mapQuery.isEmpty ? branchName : mapQuery,
                                   phone: phone.contains("*") ? "" : phone)
        }
    }
    return PPDriverAddress(primary: primary, secondary: secondary, mapQuery: mapQuery,
                           phone: phone.contains("*") ? "" : phone)
}

private func ppParseProof(_ value: Any?) -> PPDriverProof {
    let source = cpDict(value)
    return PPDriverProof(receiverNameRequired: cpBool(source["receiverNameRequired"]),
                         photoRequired: cpBool(source["photoRequired"]),
                         signatureRequired: cpBool(source["signatureRequired"]),
                         otpRequired: cpBool(source["otpRequired"]))
}

private func ppParseCash(_ value: Any?) -> PPDriverCash? {
    let source = cpDict(value)
    guard !source.isEmpty else { return nil }
    return PPDriverCash(required: cpBool(source["required"]),
                        collected: cpBool(source["collected"]),
                        amount: cpDouble(source["amount"]),
                        currency: cpString(source["currency"]).uppercased())
}

/// One row from getDriverDeliveryWorkspace (official fleet).
func ppParseOfficialTask(_ value: Any?) -> PPDriverTask? {
    let source = cpDict(value)
    let taskID = cpString(source["taskId"])
    guard !taskID.isEmpty,
          let authority = PPDriverAuthority(rawValue: cpString(source["authority"])),
          authority != .partnerCompanyRequest else { return nil }
    let actions = cpArray(source["actions"]).compactMap { raw -> PPDriverTaskAction? in
        let code = cpString(raw).uppercased()
        return PPDriverTaskAction.supportedCodes.contains(code) ? PPDriverTaskAction(code: code, toStatus: "") : nil
    }
    return PPDriverTask(taskID: taskID,
                        authority: authority,
                        companyID: cpString(source["companyId"]),
                        orderNumber: cpString(source["orderNumber"]),
                        status: cpString(source["status"]).lowercased(),
                        revision: max(0, cpInt(source["revision"])),
                        mine: cpBool(source["mine"]),
                        actions: actions,
                        pickup: ppParseDriverAddress(source["pickup"]),
                        dropoff: ppParseDriverAddress(source["dropoff"]),
                        customerName: cpString(source["customerName"]),
                        customerPhone: cpString(source["phone"]),
                        proof: ppParseProof(source["proofRequirements"]),
                        cash: ppParseCash(source["cash"]),
                        updatedAt: cpDate(source["updatedAt"]))
}

/// A partner request plus its server-computed driverTask projection.
func ppParsePartnerTask(record value: Any?, projection projectionValue: Any?) -> PPDriverTask? {
    let record = cpDict(value)
    let projection = cpDict(projectionValue)
    guard !projection.isEmpty else { return nil }
    var taskID = cpString(projection["taskId"])
    if taskID.isEmpty { taskID = cpString(record["id"]) }
    guard !taskID.isEmpty else { return nil }
    let actions = cpArray(projection["actions"]).compactMap { raw -> PPDriverTaskAction? in
        let entry = cpDict(raw)
        let code = cpString(entry["action"]).uppercased()
        let toStatus = cpString(entry["toStatus"]).lowercased()
        return !PPDriverTaskAction.supportedCodes.contains(code) || toStatus.isEmpty
            ? nil : PPDriverTaskAction(code: code, toStatus: toStatus)
    }
    let dropoff = ppParseDriverAddress(record["dropoffAddress"])
    var phone = dropoff.phone
    if phone.isEmpty {
        let candidate = cpString(record["customerPhone"])
        phone = candidate.contains("*") ? "" : candidate
    }
    var orderNumber = cpString(record["orderNumber"])
    if orderNumber.isEmpty { orderNumber = cpString(record["parentOrderNumber"]) }
    let cashSource = cpDict(projection["cash"])
    let cash: PPDriverCash? = cashSource.isEmpty ? nil : PPDriverCash(
        required: cpBool(cashSource["required"]),
        collected: cpBool(cashSource["collected"]),
        amount: cpDouble(cashSource["amount"]),
        currency: cpString(cashSource["currency"]).uppercased())
    return PPDriverTask(taskID: taskID,
                        authority: .partnerCompanyRequest,
                        companyID: cpString(projection["companyId"]),
                        orderNumber: orderNumber,
                        status: cpString(projection["status"]).lowercased(),
                        revision: max(0, cpInt(projection["revision"])),
                        mine: projection["mine"] == nil ? true : cpBool(projection["mine"]),
                        actions: actions,
                        pickup: ppParseDriverAddress(record["pickupAddress"]),
                        dropoff: dropoff,
                        customerName: cpString(record["customerName"]),
                        customerPhone: phone,
                        proof: ppParseProof(projection["proofRequirements"]),
                        cash: cash,
                        updatedAt: cpDate(record["updatedAt"]))
}

func ppParseDriverContexts(_ result: [String: Any]) -> PPDriverContextResolution {
    var contexts: [PPDriverContext] = []
    for raw in cpArray(result["contexts"]) {
        let entry = cpDict(raw)
        guard let kind = PPDriverContextKind(rawValue: cpString(entry["kind"]).uppercased()) else { continue }
        let companyID = cpString(entry["companyId"])
        guard !companyID.isEmpty else { continue }
        var capabilities: [String: Bool] = [:]
        for (key, value) in cpDict(entry["capabilities"]) { capabilities[key] = cpBool(value) }
        let presenceSource = cpDict(entry["presence"])
        let presence: PPDriverPresence? = presenceSource.isEmpty ? nil : PPDriverPresence(
            online: cpBool(presenceSource["online"]),
            available: cpBool(presenceSource["available"]),
            assignmentsPaused: cpBool(presenceSource["assignmentsPaused"]),
            revision: max(0, cpInt(presenceSource["revision"])),
            activeDeliveryCount: max(0, cpInt(presenceSource["activeDeliveryCount"])))
        let id = cpString(entry["id"]).isEmpty ? "\(kind.rawValue):\(companyID)" : cpString(entry["id"])
        contexts.append(PPDriverContext(id: id, kind: kind, companyID: companyID,
                                        companyName: cpString(entry["companyName"]),
                                        role: cpString(entry["role"]),
                                        capabilities: capabilities, presence: presence,
                                        dispatcherPhone: cpString(entry["dispatcherPhone"])))
    }
    var restrictionReason = ""
    for raw in cpArray(result["companies"]) where restrictionReason.isEmpty {
        for workspace in cpArray(cpDict(raw)["workspaces"]) {
            let entry = cpDict(workspace)
            if cpString(entry["kind"]).uppercased() == "RESTRICTED" {
                restrictionReason = cpString(entry["reason"])
                break
            }
        }
    }
    return PPDriverContextResolution(contexts: contexts, restrictionReason: restrictionReason)
}

struct PPDriverOfficialPage: Sendable {
    let tasks: [PPDriverTask]
    let availability: [PPDriverAvailability]
    let cursor: PPDriverPageCursor?
}

/// Opaque per-source cursor from getDriverDeliveryWorkspace. Exhausted sources
/// are sent back as null so the server skips them instead of restarting.
struct PPDriverPageCursor: Sendable, Equatable {
    let live: [String: String]
    let exhausted: [String]

    var payload: [String: Any] {
        var value: [String: Any] = [:]
        for (key, id) in live { value[key] = id }
        for key in exhausted { value[key] = NSNull() }
        return value
    }
}

func ppParseOfficialPage(_ result: [String: Any]) -> PPDriverOfficialPage {
    let tasks = cpArray(result["tasks"]).compactMap { ppParseOfficialTask($0) }
    let availability = cpArray(result["availability"]).compactMap { raw -> PPDriverAvailability? in
        let row = cpDict(raw)
        let companyID = cpString(row["companyId"])
        guard !companyID.isEmpty else { return nil }
        let reasons = cpArray(row["readinessReasons"]).map { cpString($0) }.filter { !$0.isEmpty }
        return PPDriverAvailability(companyID: companyID,
                                    online: cpBool(row["online"]),
                                    assignmentsPaused: cpBool(row["assignmentsPaused"]),
                                    accountActive: cpString(row["accountStatus"]).uppercased() != "SUSPENDED",
                                    readinessReasons: reasons,
                                    revision: max(0, cpInt(row["revision"])),
                                    activeDeliveryCount: max(0, cpInt(row["activeDeliveryCount"])),
                                    canSelfAcceptOrders: cpBool(row["canSelfAcceptOrders"]))
    }
    var cursor: PPDriverPageCursor?
    if cpBool(result["hasMore"]) {
        var live: [String: String] = [:]
        var exhausted: [String] = []
        for (key, value) in cpDict(result["nextCursor"]) {
            let id = cpString(value)
            if id.isEmpty { exhausted.append(key) } else { live[key] = id }
        }
        if !live.isEmpty { cursor = PPDriverPageCursor(live: live, exhausted: exhausted) }
    }
    return PPDriverOfficialPage(tasks: tasks, availability: availability, cursor: cursor)
}

func ppParseOfficialSingleTask(_ result: [String: Any]) -> PPDriverTask? {
    ppParseOfficialTask(result["task"])
}

struct PPDriverPartnerPage: Sendable {
    let active: [PPDriverTask]
    let history: [PPDriverTask]
    let nextPageToken: String?
}

func ppParsePartnerPage(_ result: [String: Any]) -> PPDriverPartnerPage {
    var active: [PPDriverTask] = []
    var history: [PPDriverTask] = []
    for raw in cpArray(result["requests"]) {
        let record = cpDict(raw)
        guard let task = ppParsePartnerTask(record: record, projection: record["driverTask"]) else { continue }
        if task.isTerminal {
            if history.count < 15 { history.append(task) }
        } else {
            active.append(task)
        }
    }
    let token = cpString(result["nextPageToken"])
    return PPDriverPartnerPage(active: active, history: history, nextPageToken: token.isEmpty ? nil : token)
}

func ppParsePartnerSingleTask(_ result: [String: Any]) -> PPDriverTask? {
    ppParsePartnerTask(record: result["request"], projection: result["driverTask"])
}

// MARK: - Failures

enum PPDriverFailure: Sendable, Equatable {
    case transport
    case changed
    case notEligible
    case denied
    case notFound
    case invalidCode
    case proofRequired
    case cashMismatch
    case rejected
    case unknown
}

struct PPDriverCallError: Error, Sendable {
    let failure: PPDriverFailure

    init(_ error: Error) {
        let nsError = error as NSError
        let details = cpDict(nsError.userInfo["details"])
        let message = nsError.localizedDescription.lowercased()
        switch cpString(details["domainCode"]) {
        case "DELIVERY_POD_REQUIRED": failure = .proofRequired; return
        case "DELIVERY_COD_MISMATCH": failure = .cashMismatch; return
        case "DELIVERY_STATE_CONFLICT", "DELIVERY_AUTHORITY_MISMATCH": failure = .changed; return
        case "DELIVERY_DRIVER_NOT_ELIGIBLE", "DELIVERY_CAPACITY_EXCEEDED": failure = .notEligible; return
        case "DELIVERY_PERMISSION_DENIED": failure = .denied; return
        case "DELIVERY_REQUEST_NOT_FOUND": failure = .notFound; return
        default: break
        }
        if PPDriverCallError.chainContainsURLError(nsError) { failure = .transport; return }
        switch nsError.code {
        case 3: failure = message.contains("otp") ? .invalidCode : .rejected
        case 5: failure = .notFound
        case 6, 10: failure = .changed
        case 9: failure = message.contains("eligible") ? .notEligible : .changed
        case 7: failure = .denied
        // Unauthenticated (16) is usually an expired token or an App Check
        // hiccup. The call was rejected before running, so it is retried like
        // a transport failure; a real sign-out is caught by isSameAccount().
        case 1, 2, 4, 13, 14, 16: failure = .transport
        default: failure = .unknown
        }
    }

    private static func chainContainsURLError(_ error: NSError) -> Bool {
        var current: NSError? = error
        var depth = 0
        while let candidate = current, depth < 8 {
            if candidate.domain == NSURLErrorDomain { return true }
            current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return false
    }
}

// MARK: - Commands

struct PPDriverCommand: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case task, availability }

    let kind: Kind
    let commandID: String
    let functionName: String
    let taskKey: String
    let taskID: String
    let authority: PPDriverAuthority?
    let actionCode: String
    let toStatus: String
    let expectedState: String
    let expectedRevision: Int
    let companyID: String
    let online: Bool
    let receiverName: String
    let otp: String
    let cashAmount: Double?
    let cashCurrency: String
    let includesLegacyCash: Bool

    var payload: [String: Any] {
        switch kind {
        case .availability:
            if functionName == "setCompanyDriverAvailability" {
                return ["companyId": companyID, "online": online, "expectedRevision": expectedRevision]
            }
            return ["companyId": companyID, "online": online, "expectedRevision": expectedRevision, "commandId": commandID]
        case .task:
            var payload: [String: Any] = ["expectedState": expectedState, "expectedRevision": expectedRevision, "commandId": commandID]
            if authority == .partnerCompanyRequest {
                payload["requestId"] = taskID
                if actionCode == "CLAIM" {
                    payload["driverUid"] = PPDeliveryCompanyService.currentAccountUID()
                } else {
                    payload["toStatus"] = toStatus
                }
                if let cashAmount, actionCode == "DELIVER" { payload["cashAmountCollected"] = cashAmount }
            } else {
                payload["taskId"] = taskID
                payload["authority"] = authority?.rawValue ?? ""
                payload["action"] = actionCode
                if actionCode == "CONFIRM_PAYMENT", let cashAmount {
                    payload["confirmedCashAmount"] = cashAmount
                    payload["confirmedCashCurrency"] = cashCurrency
                }
                if includesLegacyCash, let cashAmount {
                    payload["cashCollected"] = true
                    payload["cashAmountCollected"] = cashAmount
                }
            }
            if !receiverName.isEmpty { payload["receiverName"] = receiverName }
            if !otp.isEmpty { payload["otp"] = otp }
            return payload
        }
    }

    var successText: String {
        switch kind {
        case .availability: return ppDriverText(online ? "DriverCockpit_Success_Online" : "DriverCockpit_Success_Offline")
        case .task: return ppDriverText("DriverCockpit_Success_\(actionCode)")
        }
    }

    static func task(_ action: PPDriverTaskAction, on task: PPDriverTask, inputs: PPDriverCommandInputs) -> PPDriverCommand {
        let partner = task.authority == .partnerCompanyRequest
        let cashNeeded = action.code == "CONFIRM_PAYMENT" ||
            (action.code == "DELIVER" && task.authority != .fulfillmentV1 && (task.cash?.required ?? false) && !(task.cash?.collected ?? false))
        return PPDriverCommand(kind: .task,
                               commandID: UUID().uuidString,
                               functionName: partner ? (action.code == "CLAIM" ? "assignCompanyDeliveryDriver" : "updateCompanyDeliveryStatus") : "executeDriverDeliveryTask",
                               taskKey: task.id,
                               taskID: task.taskID,
                               authority: task.authority,
                               actionCode: action.code,
                               toStatus: action.toStatus,
                               expectedState: task.status,
                               expectedRevision: task.revision,
                               companyID: task.companyID,
                               online: false,
                               receiverName: inputs.receiverName,
                               otp: ppDriverASCIIDigits(inputs.otp),
                               cashAmount: cashNeeded ? task.cash?.amount : nil,
                               cashCurrency: task.cash?.currency ?? "",
                               includesLegacyCash: cashNeeded && action.code == "DELIVER" && task.authority == .officialCompanyRequest)
    }

    static func availability(online: Bool, context: PPDriverContext, revision: Int) -> PPDriverCommand {
        PPDriverCommand(kind: .availability,
                        commandID: UUID().uuidString,
                        functionName: context.kind == .officialDriver ? "setDriverDeliveryAvailability" : "setCompanyDriverAvailability",
                        taskKey: "",
                        taskID: "",
                        authority: nil,
                        actionCode: "",
                        toStatus: "",
                        expectedState: "",
                        expectedRevision: revision,
                        companyID: context.companyID,
                        online: online,
                        receiverName: "",
                        otp: "",
                        cashAmount: nil,
                        cashCurrency: "",
                        includesLegacyCash: false)
    }
}

// MARK: - Store

/// Single owner of driver cockpit state. Every mutation re-authorizes on the
/// server; this store only reflects confirmed results.
@MainActor
final class PPDriverCockpitStore: ObservableObject {
    enum Phase: Equatable {
        case resolving
        case signedOut
        case noWorkspace(String)
        /// Workspaces could not be loaded (network or server); not a verdict
        /// on the account.
        case loadFailed
        case choosingContext
        case accessEnded
        case ready
    }

    @Published private(set) var phase: Phase = .resolving
    @Published private(set) var contexts: [PPDriverContext] = []
    @Published private(set) var selectedContext: PPDriverContext?
    @Published private(set) var activeTasks: [PPDriverTask] = []
    @Published private(set) var offers: [PPDriverTask] = []
    @Published private(set) var history: [PPDriverTask] = []
    @Published private(set) var historyLoaded = false
    @Published private(set) var officialAvailability: PPDriverAvailability?
    @Published private(set) var focusedTaskKey: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isResolvingContexts = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isVerifying = false
    @Published private(set) var canLoadMoreActive = false
    @Published private(set) var isLoadingMoreActive = false
    @Published private(set) var uncertainCommand: PPDriverCommand?
    @Published private(set) var lastConfirmedAt: Date?
    @Published private(set) var isStale = false
    @Published var notice: PPDriverNotice?

    let boundUID: String
    private let loadsTaskQueue: Bool
    private let loadsOffers: Bool
    private let service = PPDeliveryCompanyService.shared()
    private var started = false
    private var isVisible = false
    private var contextGeneration = 0
    private var listGeneration = 0
    private var refreshQueued = false
    private var pendingFocus: PPDriverFocusRequest?
    private var pendingVerification: PPDriverCommand?
    private var partnerCursor: String?
    /// Tasks this driver just moved on, so their disappearance is not
    /// reported as someone else's change. Entries expire after two minutes.
    private var selfResolvedAt: [String: Date] = [:]
    private var refreshTimer: Timer?
    private var observerTokens: [NSObjectProtocol] = []
    private var acceptanceObservation: NSObject?
    private var acceptanceObservationGeneration = 0
    private var acceptanceObservationNeedsRetry = false
    @Published private var liveSelfAcceptance: Bool?

    init(loadsTaskQueue: Bool = true, loadsOffers: Bool = true) {
        boundUID = PPDeliveryCompanyService.currentAccountUID()
        self.loadsTaskQueue = loadsTaskQueue
        self.loadsOffers = loadsOffers
    }

    // MARK: Derived state

    var focusedTask: PPDriverTask? {
        guard let key = focusedTaskKey else { return nil }
        return activeTasks.first(where: { $0.id == key }) ?? offers.first(where: { $0.id == key })
    }

    var otherActiveTasks: [PPDriverTask] {
        activeTasks.filter { $0.id != focusedTaskKey }
    }

    var canSelfAcceptOrders: Bool {
        guard let context = selectedContext else { return false }
        if let liveSelfAcceptance { return liveSelfAcceptance }
        if context.kind == .officialDriver, let officialAvailability {
            return officialAvailability.canSelfAcceptOrders
        }
        return context.capabilities["claimOffers"] == true
    }

    var visibleOffers: [PPDriverTask] {
        canSelfAcceptOrders ? offers.filter { $0.id != focusedTaskKey } : []
    }

    /// Server-backed availability for the selected context, or nil when the
    /// backend has not provided one.
    var availability: PPDriverAvailability? {
        guard let context = selectedContext else { return nil }
        switch context.kind {
        case .officialDriver:
            return officialAvailability
        case .partnerDriver:
            guard let presence = context.presence else { return nil }
            var reasons: [String] = []
            if presence.assignmentsPaused { reasons.append("ASSIGNMENTS_PAUSED") }
            if !presence.online { reasons.append("OFFLINE") }
            return PPDriverAvailability(companyID: context.companyID, online: presence.online,
                                        assignmentsPaused: presence.assignmentsPaused, accountActive: true,
                                        readinessReasons: reasons, revision: presence.revision,
                                        activeDeliveryCount: presence.activeDeliveryCount,
                                        canSelfAcceptOrders: canSelfAcceptOrders)
        }
    }

    var dispatchPhone: String? {
        guard let context = selectedContext else { return nil }
        let phone = context.kind == .officialDriver ? Self.officialDispatchPhone : context.dispatcherPhone
        return phone.isEmpty ? nil : phone
    }

    /// Same official dispatch line the Admin driver workspace uses.
    nonisolated static let officialDispatchPhone = "+97459997720"

    // MARK: Lifecycle

    func start(focus: PPDriverFocusRequest?) {
        if let focus { pendingFocus = focus }
        if started {
            if focus != nil { applyPendingFocus() }
            return
        }
        started = true
        guard !boundUID.isEmpty else {
            phase = .signedOut
            return
        }
        resolveContexts()
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            installObservers()
            observeAcceptancePolicy()
            startTimer()
            if phase == .ready { refreshAll() }
        } else {
            stopTimer()
            acceptanceObservation = nil
            removeObservers()
        }
    }

    func requestFocus(_ request: PPDriverFocusRequest) {
        pendingFocus = request
        guard started else { return }
        switch phase {
        case .ready: applyPendingFocus()
        case .resolving: break
        default: resolveContexts()
        }
    }

    // MARK: Contexts

    func resolveContexts() {
        guard !boundUID.isEmpty else { phase = .signedOut; return }
        contextGeneration += 1
        let generation = contextGeneration
        isResolvingContexts = true
        if selectedContext == nil { phase = .resolving }
        call("getMyDeliveryCompanies", [:], parse: ppParseDriverContexts) { [weak self] outcome in
            guard let self, generation == self.contextGeneration, self.isSameAccount() else { return }
            self.isResolvingContexts = false
            switch outcome {
            case .success(let resolution):
                self.applyContexts(resolution)
            case .failure(let error):
                if error.failure == .denied {
                    self.endAccess()
                } else if self.selectedContext == nil {
                    self.phase = .loadFailed
                    self.notice = PPDriverNotice(tone: .warning, text: ppDriverText(error.failure == .transport
                        ? "DriverCockpit_Notice_Offline" : "DriverCockpit_Error_Generic"))
                } else {
                    self.isStale = true
                    self.retainUnconfirmedVerification()
                }
            }
        }
    }

    func select(_ context: PPDriverContext) {
        // Never switch under a pending or unconfirmed command.
        guard selectedContext == nil || canSwitchContext else { return }
        selectedContext = context
        liveSelfAcceptance = nil
        observeAcceptancePolicy()
        UserDefaults.standard.set(context.id, forKey: selectionKey)
        persistDashboardCompany(context)
        clearTasks()
        // Reads still in flight for the previous workspace are dropped.
        listGeneration += 1
        isRefreshing = false
        refreshQueued = false
        phase = .ready
        refresh()
    }

    func showContextChooser() {
        guard contexts.count > 1, canSwitchContext else { return }
        phase = .choosingContext
    }

    private var selectionKey: String { "PPDriverCockpit.selectedContext.\(boundUID)" }

    private func applyContexts(_ resolution: PPDriverContextResolution) {
        contexts = resolution.contexts
        guard !contexts.isEmpty else {
            clearTasks()
            selectedContext = nil
            acceptanceObservation = nil
            liveSelfAcceptance = nil
            phase = .noWorkspace(resolution.restrictionReason)
            return
        }
        if let current = selectedContext {
            if let refreshed = contexts.first(where: { $0.id == current.id }) {
                selectedContext = refreshed
                if acceptanceObservationNeedsRetry && isVisible {
                    liveSelfAcceptance = nil
                    observeAcceptancePolicy()
                }
                if phase != .ready { phase = .ready }
                refresh()
                applyPendingFocus()
            } else {
                endAccess()
            }
            return
        }
        if let focus = pendingFocus,
           let match = contexts.first(where: { ($0.kind == .partnerDriver) == focus.wantsPartner &&
               (focus.companyID.isEmpty || $0.companyID == focus.companyID) }) {
            select(match)
            return
        }
        if let saved = UserDefaults.standard.string(forKey: selectionKey),
           let match = contexts.first(where: { $0.id == saved }) {
            select(match)
            return
        }
        if contexts.count == 1, let only = contexts.first {
            select(only)
            return
        }
        phase = .choosingContext
    }

    private func persistDashboardCompany(_ context: PPDriverContext) {
        // Only an empty dashboard choice is filled, and only with the real
        // server profile: a company the user chose elsewhere (for example a
        // dispatch workspace) is never replaced or narrowed from the cockpit.
        guard service.configuredCompanyID.isEmpty, !context.companyID.isEmpty else { return }
        service.verifyAndStoreCompanyID(context.companyID) { _, _ in }
    }

    private func endAccess() {
        clearTasks()
        selectedContext = nil
        acceptanceObservation = nil
        liveSelfAcceptance = nil
        UserDefaults.standard.removeObject(forKey: selectionKey)
        phase = .accessEnded
    }

    // MARK: Refresh

    func refresh() {
        guard phase == .ready, let context = selectedContext else { return }
        if isRefreshing {
            refreshQueued = true
            return
        }
        // Only a read started after the uncertain result may verify it. Keep
        // the command itself until authoritative progress is observed, so a
        // status check cannot replace its idempotency key with a new one.
        if !isSubmitting, pendingVerification == nil, let command = uncertainCommand {
            pendingVerification = command
            isVerifying = true
        }
        isRefreshing = true
        listGeneration += 1
        let generation = listGeneration
        switch context.kind {
        case .officialDriver: refreshOfficial(context, generation)
        case .partnerDriver: refreshPartner(context, generation)
        }
    }

    func loadHistory() {
        guard let context = selectedContext else { return }
        if context.kind == .partnerDriver {
            call("listMyAssignedCompanyDeliveries", ["companyId": context.companyID, "lane": "history", "pageSize": 15],
                 parse: ppParsePartnerPage) { [weak self] outcome in
                guard let self, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
                if case .success(let page) = outcome {
                    self.history = page.history
                    self.historyLoaded = true
                } else {
                    self.notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Offline"))
                }
            }
            return
        }
        fetchOfficialLane("history", maxPages: 2) { [weak self] outcome in
            guard let self, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
            if case .success(let page) = outcome {
                // Server pages follow document order, so recency is applied here.
                self.history = Array(ppDriverUniqueTasks(page.tasks)
                    .filter { $0.mine && $0.isTerminal }
                    .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
                    .prefix(15))
                self.historyLoaded = true
            } else {
                self.notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Offline"))
            }
        }
    }

    /// Reads an official lane, following the server cursor so assigned work on
    /// a later page is not missed. The page bound keeps one refresh cheap.
    private func fetchOfficialLane(_ lane: String,
                                   maxPages: Int,
                                   cursor: PPDriverPageCursor? = nil,
                                   collected: [PPDriverTask] = [],
                                   availability: [PPDriverAvailability] = [],
                                   completion: @escaping @Sendable @MainActor (Result<PPDriverOfficialPage, PPDriverCallError>) -> Void) {
        var payload: [String: Any] = ["lane": lane]
        if let cursor { payload["cursor"] = cursor.payload }
        call("getDriverDeliveryWorkspace", payload, parse: ppParseOfficialPage) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .failure(let error):
                completion(.failure(error))
            case .success(let page):
                let tasks = collected + page.tasks
                let firstAvailability = availability.isEmpty ? page.availability : availability
                if let next = page.cursor, maxPages > 1 {
                    self.fetchOfficialLane(lane, maxPages: maxPages - 1, cursor: next, collected: tasks,
                                           availability: firstAvailability, completion: completion)
                } else {
                    completion(.success(PPDriverOfficialPage(tasks: tasks, availability: firstAvailability, cursor: page.cursor)))
                }
            }
        }
    }

    private func refreshOfficial(_ context: PPDriverContext, _ generation: Int) {
        if !loadsTaskQueue {
            call("getDriverDeliveryWorkspace", ["availabilityOnly": true], parse: ppParseOfficialPage) { [weak self] outcome in
                guard let self, generation == self.listGeneration, self.isSameAccount() else { return }
                switch outcome {
                case .success(let page):
                    self.officialAvailability = page.availability.first(where: { $0.companyID == context.companyID })
                    self.verifyPendingCommand()
                    self.finishRefresh(failure: nil)
                case .failure(let error): self.finishRefresh(failure: error)
                }
            }
            return
        }
        fetchOfficialLane("active", maxPages: 4) { [weak self] outcome in
            guard let self, generation == self.listGeneration, self.isSameAccount() else { return }
            switch outcome {
            case .failure(let error):
                self.finishRefresh(failure: error)
            case .success(let page):
                self.officialAvailability = page.availability.first(where: { $0.companyID == context.companyID }) ?? page.availability.first
                guard self.loadsOffers && self.canSelfAcceptOrders else {
                    self.reconcile(active: ppDriverUniqueTasks(page.tasks).filter { $0.mine && !$0.isTerminal },
                                   offers: [], history: nil)
                    self.finishRefresh(failure: nil)
                    return
                }
                self.fetchOfficialLane("available", maxPages: 1) { [weak self] offersOutcome in
                    guard let self, generation == self.listGeneration, self.isSameAccount() else { return }
                    // An offers read that fails clears the list instead of
                    // showing offers that may already be gone.
                    var offers: [PPDriverTask] = []
                    if self.canSelfAcceptOrders, case .success(let offerPage) = offersOutcome {
                        offers = ppDriverUniqueTasks(offerPage.tasks).filter { !$0.mine && !$0.isTerminal }
                    }
                    self.officialAvailability = page.availability.first(where: { $0.companyID == context.companyID }) ?? page.availability.first
                    self.reconcile(active: ppDriverUniqueTasks(page.tasks).filter { $0.mine && !$0.isTerminal },
                                   offers: offers, history: nil)
                    self.finishRefresh(failure: nil)
                }
            }
        }
    }

    private func refreshPartner(_ context: PPDriverContext, _ generation: Int) {
        if !loadsTaskQueue {
            // getMyDeliveryCompanies has already refreshed this context's
            // presence. Home never fetches delivery queues just for a switch.
            verifyPendingCommand()
            finishRefresh(failure: nil)
            return
        }
        let payload: [String: Any] = ["companyId": context.companyID, "pageSize": 30, "lane": "active"]
        call("listMyAssignedCompanyDeliveries", payload, parse: ppParsePartnerPage) { [weak self] outcome in
            guard let self, generation == self.listGeneration, self.isSameAccount() else { return }
            switch outcome {
            case .failure(let error):
                self.finishRefresh(failure: error)
            case .success(let page):
                self.partnerCursor = page.nextPageToken
                self.canLoadMoreActive = page.nextPageToken != nil
                guard self.loadsOffers && self.canSelfAcceptOrders else {
                    self.reconcile(active: page.active.filter { $0.mine }, offers: [], history: nil)
                    self.finishRefresh(failure: nil)
                    return
                }
                self.call("listMyAssignedCompanyDeliveries",
                          ["companyId": context.companyID, "pageSize": 30, "lane": "available"],
                          parse: ppParsePartnerPage) { [weak self] offersOutcome in
                    guard let self, generation == self.listGeneration, self.isSameAccount() else { return }
                    var available: [PPDriverTask] = []
                    if self.canSelfAcceptOrders, case .success(let offersPage) = offersOutcome {
                        available = offersPage.active.filter { !$0.mine }
                    }
                    self.reconcile(active: page.active.filter { $0.mine }, offers: available, history: nil)
                    self.finishRefresh(failure: nil)
                }
            }
        }
    }

    func loadMoreActive() {
        guard let context = selectedContext, context.kind == .partnerDriver,
              let cursor = partnerCursor, !isRefreshing, !isLoadingMoreActive, canSwitchContext else { return }
        isLoadingMoreActive = true
        let generation = listGeneration
        call("listMyAssignedCompanyDeliveries", ["companyId": context.companyID, "lane": "active", "pageSize": 30,
                                                "nextPageToken": cursor], parse: ppParsePartnerPage) { [weak self] outcome in
            guard let self, self.isSameAccount(), generation == self.listGeneration, self.selectedContext?.id == context.id else { return }
            self.isLoadingMoreActive = false
            if case .success(let page) = outcome {
                self.partnerCursor = page.nextPageToken
                self.canLoadMoreActive = page.nextPageToken != nil
                self.reconcile(active: ppDriverUniqueTasks(self.activeTasks + page.active), offers: self.canSelfAcceptOrders ? self.offers : [], history: nil)
            } else {
                self.notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Offline"))
            }
        }
    }

    private func finishRefresh(failure: PPDriverCallError?) {
        isRefreshing = false
        isLoadingMoreActive = false
        if let failure {
            retainUnconfirmedVerification()
            switch failure.failure {
            case .denied:
                endAccess()
                return
            case .transport:
                isStale = true
                notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Offline"))
            default:
                isStale = true
            }
        } else {
            isStale = false
            lastConfirmedAt = Date()
            if notice?.text == ppDriverText("DriverCockpit_Notice_Offline") { notice = nil }
        }
        if refreshQueued {
            refreshQueued = false
            refresh()
            return
        }
        // A focus request waits for a settled list. When another refresh was
        // queued it is applied when that one finishes.
        applyPendingFocus()
    }

    private func reconcile(active: [PPDriverTask], offers newOffers: [PPDriverTask], history newHistory: [PPDriverTask]?) {
        let previousFocus = focusedTaskKey
        let previousTasks = activeTasks
        let sortedActive = active.sorted { left, right in
            if left.actions.isEmpty != right.actions.isEmpty { return !left.actions.isEmpty }
            if left.stage != right.stage { return left.stage > right.stage }
            return (left.updatedAt ?? .distantPast) > (right.updatedAt ?? .distantPast)
        }
        activeTasks = sortedActive
        offers = newOffers
        if let newHistory { history = newHistory }

        let disappeared = Set(previousTasks.map(\.id)).subtracting(sortedActive.map(\.id))
        let resolvedRecently = selfResolvedAt[previousFocus ?? ""].map { Date().timeIntervalSince($0) < 120 } ?? false
        if let previousFocus, disappeared.contains(previousFocus), !resolvedRecently,
           let previousTask = previousTasks.first(where: { $0.id == previousFocus }) {
            explainVanishedTask(previousTask, history: newHistory ?? history)
        }
        // An entry is consumed only once its task has left the list, so a
        // refresh that started before the command finished cannot use it up.
        for key in disappeared { selfResolvedAt[key] = nil }
        selfResolvedAt = selfResolvedAt.filter { Date().timeIntervalSince($0.value) < 120 }

        if let key = focusedTaskKey, sortedActive.contains(where: { $0.id == key }) || newOffers.contains(where: { $0.id == key }) {
            // Keep the driver's focus on the same delivery.
        } else {
            focusedTaskKey = sortedActive.first?.id
        }
        if let focused = focusedTask,
           previousTasks.first(where: { $0.id == focused.id })?.awaitsStoreHandover == true,
           focused.actions.contains(where: { $0.code == "PICK_UP" }) {
            let text = ppDriverText("DriverCockpit_Handover_Ready")
            notice = PPDriverNotice(tone: .info, text: text)
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        verifyPendingCommand()
    }

    /// Explains why the focused delivery left the list using server evidence:
    /// the partner history when it holds the task, otherwise one fresh read.
    private func explainVanishedTask(_ task: PPDriverTask, history: [PPDriverTask]) {
        if let closed = history.first(where: { $0.id == task.id }) {
            announce(closed.status == "cancelled" ? "DriverCockpit_Notice_Cancelled" : "DriverCockpit_Notice_Closed")
            return
        }
        guard let context = selectedContext else { return }
        readSingleTask(taskID: task.taskID, authority: task.authority, context: context) { [weak self] outcome in
            guard let self, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
            switch outcome {
            case .success(let fresh?) where fresh.isTerminal:
                self.announce(fresh.status == "cancelled" ? "DriverCockpit_Notice_Cancelled" : "DriverCockpit_Notice_Closed")
            case .success(let fresh?) where fresh.mine:
                break // Still assigned and active; the next refresh lists it again.
            case .success(let fresh?) where !fresh.mine:
                self.announce("DriverCockpit_Notice_Reassigned")
            case .success:
                self.announce("DriverCockpit_Notice_TaskUnavailable")
            case .failure(let error) where error.failure == .notFound || error.failure == .denied:
                self.announce("DriverCockpit_Notice_TaskUnavailable")
            case .failure:
                break
            }
        }
    }

    private func announce(_ key: String) {
        let text = ppDriverText(key)
        notice = PPDriverNotice(tone: .warning, text: text)
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func readSingleTask(taskID: String,
                                authority: PPDriverAuthority,
                                context: PPDriverContext,
                                completion: @escaping @Sendable @MainActor (Result<PPDriverTask?, PPDriverCallError>) -> Void) {
        if authority == .partnerCompanyRequest {
            call("getCompanyDeliveryRequest", ["requestId": taskID, "companyId": context.companyID],
                 parse: ppParsePartnerSingleTask, completion: completion)
        } else {
            call("getDriverDeliveryWorkspace", ["taskId": taskID, "authority": authority.rawValue],
                 parse: ppParseOfficialSingleTask, completion: completion)
        }
    }

    // MARK: Focus

    func focus(on task: PPDriverTask) {
        focusedTaskKey = task.id
    }

    /// Switching workspace is blocked while a command is pending or its outcome
    /// is unknown, so a late result can never land in another workspace.
    var canSwitchContext: Bool { !isSubmitting && !isVerifying && uncertainCommand == nil }

    /// Availability always starts from a fresh server revision. Task progress
    /// remains governed independently by its own projected action contract.
    var canChangeAvailability: Bool {
        phase == .ready && isSameAccount() && canSwitchContext &&
            !isRefreshing && !isResolvingContexts && !isStale && availability != nil
    }

    func refreshAvailability() {
        if selectedContext == nil { resolveContexts() } else { refreshAll() }
    }

    private func applyPendingFocus() {
        guard let focus = pendingFocus, phase == .ready, let context = selectedContext, !isRefreshing else { return }
        if focus.wantsPartner != (context.kind == .partnerDriver) ||
            (focus.wantsPartner && !focus.companyID.isEmpty && focus.companyID != context.companyID) {
            if let match = contexts.first(where: { ($0.kind == .partnerDriver) == focus.wantsPartner &&
                (focus.companyID.isEmpty || $0.companyID == focus.companyID) }), match.id != context.id {
                // Applied after the pending command settles.
                guard canSwitchContext else { return }
                select(match)
                return
            }
            pendingFocus = nil
            notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_TaskUnavailable"))
            return
        }
        if activeTasks.contains(where: { $0.id == focus.key }) || offers.contains(where: { $0.id == focus.key }) {
            focusedTaskKey = focus.key
            pendingFocus = nil
            return
        }
        pendingFocus = nil
        fetchFocusedTask(focus, context)
    }

    private func fetchFocusedTask(_ focus: PPDriverFocusRequest, _ context: PPDriverContext) {
        let handle: @Sendable @MainActor (Result<PPDriverTask?, PPDriverCallError>) -> Void = { [weak self] outcome in
            guard let self, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
            switch outcome {
            case .success(let task?) where !task.isTerminal && (task.mine || task.primaryAction?.code == "CLAIM"):
                if task.mine {
                    if !self.activeTasks.contains(where: { $0.id == task.id }) { self.activeTasks.insert(task, at: 0) }
                } else if !self.offers.contains(where: { $0.id == task.id }) {
                    self.offers.insert(task, at: 0)
                }
                self.focusedTaskKey = task.id
            case .success(let task?) where task.isTerminal:
                self.notice = PPDriverNotice(tone: .info, text: ppDriverText(task.status == "cancelled"
                    ? "DriverCockpit_Notice_Cancelled" : "DriverCockpit_Notice_Closed"))
            case .failure(let error) where error.failure == .transport:
                self.notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Offline"))
            default:
                self.notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_TaskUnavailable"))
            }
        }
        guard let authority = PPDriverAuthority(rawValue: focus.authority) else {
            notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_TaskUnavailable"))
            return
        }
        readSingleTask(taskID: focus.taskID, authority: authority, context: context, completion: handle)
    }

    // MARK: Commands

    func canPerformCurrentAction(_ action: PPDriverTaskAction, on task: PPDriverTask,
                                 contextID: String? = nil) -> Bool {
        guard canSwitchContext, phase == .ready, isSameAccount(), !isStale,
              !isRefreshing, !isResolvingContexts,
              contextID == nil || contextID == selectedContext?.id,
              let current = activeTasks.first(where: { $0.id == task.id }) ?? offers.first(where: { $0.id == task.id })
        else { return false }
        return ppDriverActionSnapshotMatches(task, current: current, action: action) &&
            ppDriverActionBlockKey(action, task: current, canSelfAcceptOrders: canSelfAcceptOrders) == nil
    }

    func perform(_ action: PPDriverTaskAction, on task: PPDriverTask,
                 inputs: PPDriverCommandInputs = PPDriverCommandInputs(), contextID: String? = nil) {
        guard canSwitchContext, phase == .ready else { return }
        guard action.code != "CLAIM" || canSelfAcceptOrders else {
            announce("Delivery_Driver_Acceptance_Managed")
            refreshAll()
            return
        }
        guard canPerformCurrentAction(action, on: task, contextID: contextID) else {
            announce("DriverCockpit_Notice_Changed")
            refreshAll()
            return
        }
        send(PPDriverCommand.task(action, on: task, inputs: inputs), isRetry: false)
    }

    func setOnline(_ online: Bool) {
        guard canChangeAvailability, let context = selectedContext, let availability else { return }
        send(PPDriverCommand.availability(online: online, context: context, revision: availability.revision), isRetry: false)
    }

    func retryUncertainCommand() {
        guard let command = uncertainCommand, !isSubmitting, !isVerifying, isSameAccount() else { return }
        send(command, isRetry: true)
    }

    func discardUncertainCommand() {
        checkUncertainCommandStatus()
    }

    func checkUncertainCommandStatus() {
        guard uncertainCommand != nil, !isSubmitting, !isVerifying, isSameAccount() else { return }
        refreshAll()
    }

    func dismissNotice() {
        notice = nil
    }

    private func refreshAll() {
        if selectedContext?.kind == .partnerDriver { resolveContexts() } else { refresh() }
    }

    private func send(_ command: PPDriverCommand, isRetry: Bool) {
        isSubmitting = true
        notice = PPDriverNotice(tone: .info, text: ppDriverText("DriverCockpit_Notice_Waiting"))
        call(command.functionName, command.payload, parse: { _ in true }) { [weak self] outcome in
            guard let self else { return }
            guard self.isSameAccount() else {
                self.isSubmitting = false
                self.phase = .signedOut
                self.clearTasks()
                return
            }
            self.isSubmitting = false
            switch outcome {
            case .success:
                self.uncertainCommand = nil
                if !command.taskKey.isEmpty { self.selfResolvedAt[command.taskKey] = Date() }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let text = command.successText
                self.notice = PPDriverNotice(tone: .success, text: text)
                UIAccessibility.post(notification: .announcement, argument: text)
                // Partner membership carries the workload count. Refresh that
                // projection after task completion too, so Home does not keep
                // the previous workload after its last assigned task closes.
                if self.selectedContext?.kind == .partnerDriver {
                    self.resolveContexts()
                } else {
                    self.refresh()
                }
            case .failure(let error):
                self.handleCommandFailure(error.failure, command: command, isRetry: isRetry)
            }
            // A focus request deferred by this command applies now (or after
            // the refresh it started).
            self.applyPendingFocus()
        }
    }

    private func handleCommandFailure(_ failure: PPDriverFailure, command: PPDriverCommand, isRetry: Bool) {
        switch failure {
        case .transport, .unknown:
            // The outcome is unknown. Keep the same command so a retry is
            // deduplicated by the backend instead of applied twice.
            uncertainCommand = command
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Unconfirmed"))
            refreshAll()
            return
        case .changed, .notEligible:
            uncertainCommand = nil
            if isRetry {
                // The earlier attempt may have succeeded; the next confirmed
                // read decides, not this error.
                pendingVerification = command
                isVerifying = true
            } else {
                let key: String
                if command.kind == .availability {
                    key = "DriverCockpit_Notice_AvailabilityChanged"
                } else {
                    key = failure == .notEligible ? "DriverCockpit_Notice_NotEligible" : "DriverCockpit_Notice_Changed"
                }
                notice = PPDriverNotice(tone: .warning, text: ppDriverText(key))
            }
            refreshAll()
        case .denied:
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .error, text: ppDriverText("DriverCockpit_Notice_Denied"))
            resolveContexts()
        case .notFound:
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_TaskUnavailable"))
            refreshAll()
        case .invalidCode:
            // A definite rejection: retrying the same command cannot succeed.
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .error, text: ppDriverText("DriverCockpit_Notice_OTPIncorrect"))
        case .proofRequired:
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .error, text: ppDriverText("DriverCockpit_Notice_ProofMissing"))
            refresh()
        case .cashMismatch:
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .error, text: ppDriverText("DriverCockpit_Notice_CashMismatch"))
            refresh()
        case .rejected:
            uncertainCommand = nil
            notice = PPDriverNotice(tone: .error, text: ppDriverText("DriverCockpit_Notice_Rejected"))
        }
        if pendingVerification == nil {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if let text = notice?.text { UIAccessibility.post(notification: .announcement, argument: text) }
        }
    }

    private func verifyPendingCommand() {
        guard let command = pendingVerification else { return }
        switch command.kind {
        case .availability:
            reportVerification(confirmed: availability?.online == command.online, endedStatus: nil,
                               unconfirmedKey: "DriverCockpit_Notice_AvailabilityChanged")
        case .task:
            let expected = PPDriverStage(status: command.expectedState)
            if let task = activeTasks.first(where: { $0.id == command.taskKey }) ?? offers.first(where: { $0.id == command.taskKey }) {
                reportVerification(confirmed: task.mine && (ppDriverStageProgressed(task.stage, from: expected) ||
                                   command.actionCode == "CLAIM"),
                                   endedStatus: nil)
            } else {
                verifyWithFreshRead(command, expected: expected)
            }
        }
    }

    /// The task left the active list after a retried command. Read it once
    /// more so the driver sees "confirmed" only when the server shows it.
    private func verifyWithFreshRead(_ command: PPDriverCommand, expected: PPDriverStage) {
        guard let context = selectedContext, let authority = command.authority, !command.taskID.isEmpty else {
            reportVerification(confirmed: false, endedStatus: nil)
            return
        }
        readSingleTask(taskID: command.taskID, authority: authority, context: context) { [weak self] outcome in
            guard let self, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
            if case .failure(let error) = outcome, error.failure == .transport || error.failure == .unknown {
                self.retainUnconfirmedVerification()
                return
            }
            if case .success(let task?) = outcome, task.mine {
                self.reportVerification(confirmed: ppDriverStageProgressed(task.stage, from: expected),
                                        endedStatus: task.stage == .ended ? task.status : nil)
            } else {
                self.reportVerification(confirmed: false, endedStatus: nil)
            }
        }
    }

    private func reportVerification(confirmed: Bool, endedStatus: String?,
                                    unconfirmedKey: String = "DriverCockpit_Notice_Changed") {
        pendingVerification = nil
        isVerifying = false
        if confirmed || endedStatus != nil {
            uncertainCommand = nil
        } else if uncertainCommand != nil {
            // An unchanged status cannot prove that a timed-out command will
            // never commit. Retain the exact retry, with visible recovery.
            notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Unconfirmed"))
            return
        }
        let key: String
        if confirmed {
            key = "DriverCockpit_Notice_Confirmed"
        } else if let endedStatus {
            key = endedStatus == "cancelled" ? "DriverCockpit_Notice_Cancelled" : "DriverCockpit_Notice_Closed"
        } else {
            key = unconfirmedKey
        }
        let text = ppDriverText(key)
        notice = PPDriverNotice(tone: confirmed ? .success : .warning, text: text)
        UINotificationFeedbackGenerator().notificationOccurred(confirmed ? .success : .warning)
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    // MARK: Helpers

    private func clearTasks() {
        activeTasks = []
        offers = []
        history = []
        historyLoaded = false
        officialAvailability = nil
        focusedTaskKey = nil
        uncertainCommand = nil
        pendingVerification = nil
        isVerifying = false
        partnerCursor = nil
        canLoadMoreActive = false
        isLoadingMoreActive = false
        selfResolvedAt = [:]
        lastConfirmedAt = nil
        isStale = false
    }

    private func retainUnconfirmedVerification() {
        guard let command = pendingVerification else { return }
        pendingVerification = nil
        isVerifying = false
        uncertainCommand = command
        notice = PPDriverNotice(tone: .warning, text: ppDriverText("DriverCockpit_Notice_Unconfirmed"))
    }

    private func isSameAccount() -> Bool {
        let matches = !boundUID.isEmpty && PPDeliveryCompanyService.currentAccountUID() == boundUID
        if !matches {
            acceptanceObservation = nil
            liveSelfAcceptance = nil
        }
        return matches
    }

    private func call<T: Sendable>(_ name: String,
                                   _ payload: [String: Any],
                                   parse: @escaping @Sendable ([String: Any]) -> T,
                                   completion: @escaping @Sendable @MainActor (Result<T, PPDriverCallError>) -> Void) {
        service.callDriverCockpitFunction(name, payload: payload) { result, error in
            let outcome: Result<T, PPDriverCallError>
            if let error {
                outcome = .failure(PPDriverCallError(error))
            } else {
                outcome = .success(parse(result ?? [:]))
            }
            Task { @MainActor in
                completion(outcome)
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func observeAcceptancePolicy() {
        acceptanceObservationGeneration += 1
        let generation = acceptanceObservationGeneration
        acceptanceObservation = nil
        acceptanceObservationNeedsRetry = false
        guard isVisible, let context = selectedContext, isSameAccount() else { return }
        acceptanceObservation = service.observeOwnDriverAcceptance(companyID: context.companyID) { [weak self] allowed, error in
            let confirmed = error == nil
            Task { @MainActor in
                guard let self, generation == self.acceptanceObservationGeneration,
                      self.isVisible, self.isSameAccount(), self.selectedContext?.id == context.id else { return }
                let changed = self.canSelfAcceptOrders != allowed
                self.acceptanceObservationNeedsRetry = !confirmed
                self.liveSelfAcceptance = allowed
                if !allowed {
                    if let focus = self.focusedTask, !focus.mine { self.focusedTaskKey = nil }
                    self.offers = []
                }
                // Membership data is read-only here. All claims are authorized
                // again inside the backend transaction, including revocation races.
                if changed && confirmed { self.resolveContexts() }
            }
        }
    }

    private func installObservers() {
        guard observerTokens.isEmpty else { return }
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                 object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.resolveContexts()
            }
        })
        observerTokens.append(center.addObserver(forName: .ppDriverCockpitShouldRefresh,
                                                 object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        })
    }

    private func removeObservers() {
        for token in observerTokens { NotificationCenter.default.removeObserver(token) }
        observerTokens.removeAll()
    }
}
