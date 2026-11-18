//
//  PPAdoptProStore.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining State & Service Store for Community Adoption Suite.
//  Maintains live Firestore subscriptions, server callable mutations, and staff oversight.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

public enum PPAdoptSheetType: Identifiable, Sendable {
    case create
    case edit(String)
    case applications(String)
    case transition(String)

    public var id: String {
        switch self {
        case .create: return "create"
        case .edit(let id): return "edit-\(id)"
        case .applications(let id): return "applications-\(id)"
        case .transition(let id): return "transition-\(id)"
        }
    }
}

@MainActor
public final class PPAdoptProStore: ObservableObject {
    public static let shared = PPAdoptProStore()

    // MARK: - Published State

    @Published public private(set) var listings: [PPAdoptListingModel] = []
    @Published public private(set) var applications: [PPAdoptApplicationModel] = []
    @Published public private(set) var overviewStats: [String: Int] = [:]

    @Published public var selectedListing: PPAdoptListingModel?
    @Published public var selectedApplication: PPAdoptApplicationModel?
    @Published public var activeSheet: PPAdoptSheetType?

    @Published public var statusFilter: String = ""
    @Published public var speciesFilter: String = ""
    @Published public var searchText: String = ""

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var isMutating: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    // MARK: - Internal Dependencies

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")
    private var listingsListener: ListenerRegistration?
    private var legacyListener: ListenerRegistration?
    private var applicationsListener: ListenerRegistration?
    private var hasStarted = false

    public init() {}

    isolated deinit {
        listingsListener?.remove()
        legacyListener?.remove()
        applicationsListener?.remove()
    }

    // MARK: - Filtered Listings

    public var filteredListings: [PPAdoptListingModel] {
        var result = listings

        // Status Filter
        if !statusFilter.isEmpty {
            result = result.filter { $0.status.rawValue == statusFilter }
        }

        // Species Filter
        if !speciesFilter.isEmpty {
            result = result.filter { listing in
                if speciesFilter == "other" {
                    return listing.species == .other
                }
                return listing.species.rawValue == speciesFilter
            }
        }

        // Search Query Filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { listing in
                listing.title.lowercased().contains(query) ||
                listing.breed.lowercased().contains(query) ||
                listing.city.lowercased().contains(query) ||
                listing.district.lowercased().contains(query) ||
                listing.publisherDisplay.lowercased().contains(query)
            }
        }

        return result
    }

    // MARK: - Calculated Statistics

    public var totalCount: Int { listings.count }
    public var publishedCount: Int { listings.filter { $0.status == .published }.count }
    public var pendingCount: Int { listings.filter { $0.status == .pendingReview || $0.status == .needsChanges }.count }
    public var adoptedCount: Int { listings.filter { $0.status == .adopted }.count }
    public var totalApplicationsCount: Int {
        listings.reduce(0) { $0 + $1.applicationCount }
    }

    // MARK: - Lifecycle & Live Observations

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        setupLiveSubscriptions()
        Task { await fetchOverviewMetrics() }
    }

    public func refresh() async {
        isRefreshing = true
        errorMessage = nil
        await fetchOverviewMetrics()
        // Allow a small delay for tactile pull-to-refresh
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRefreshing = false
    }

    private func setupLiveSubscriptions() {
        isLoading = listings.isEmpty

        // 1. Primary canonical collection: adoptionListings
        listingsListener = db.collection("adoptionListings")
            .order(by: "createdAt", descending: true)
            .limit(to: 150)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    #if DEBUG
                    print("[PPAdoptProStore] adoptionListings listen note: \(error.localizedDescription)")
                    #endif
                    // Fall back to direct fetching if rules require callable
                    self.fetchViaAdminCallableIfNeeded()
                    return
                }
                guard let snapshot else { return }

                var loaded: [PPAdoptListingModel] = []
                for doc in snapshot.documents {
                    if let model = PPAdoptListingModel(dict: doc.data(), documentID: doc.documentID) {
                        loaded.append(model)
                    }
                }

                // If adoptionListings has records, use them as primary
                if !loaded.isEmpty {
                    self.listings = loaded
                } else {
                    // Check legacy adopt_pets collection as fallback
                    self.setupLegacyListenerIfNeeded()
                }
            }
    }

    private func setupLegacyListenerIfNeeded() {
        guard legacyListener == nil else { return }
        legacyListener = db.collection("adopt_pets")
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.listings.isEmpty else { return }

                var legacyItems: [PPAdoptListingModel] = []
                for doc in snapshot.documents {
                    if let model = PPAdoptListingModel(dict: doc.data(), documentID: doc.documentID) {
                        legacyItems.append(model)
                    }
                }
                legacyItems.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                if !legacyItems.isEmpty {
                    self.listings = legacyItems
                }
            }
    }

    private func fetchViaAdminCallableIfNeeded() {
        Task {
            do {
                let callable = functions.httpsCallable("communityAdminRead")
                let result = try await callable.call(["action": "adoption_listings", "limit": 100])
                guard let data = result.data as? [String: Any],
                      let items = data["records"] as? [[String: Any]] ?? data["items"] as? [[String: Any]] else {
                    return
                }
                let parsed = items.compactMap { dict -> PPAdoptListingModel? in
                    let id = (dict["id"] as? String) ?? (dict["listingId"] as? String) ?? UUID().uuidString
                    return PPAdoptListingModel(dict: dict, documentID: id)
                }
                if !parsed.isEmpty {
                    self.listings = parsed
                }
            } catch {
                #if DEBUG
                print("[PPAdoptProStore] communityAdminRead error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func fetchOverviewMetrics() async {
        do {
            let callable = functions.httpsCallable("communityAdminRead")
            let result = try await callable.call(["action": "overview"])
            if let data = result.data as? [String: Any],
               let counts = data["overview"] as? [String: Int] ?? data["metrics"] as? [String: Int] {
                self.overviewStats = counts
            }
        } catch {
            // Non-critical, fallback to local listing aggregates
        }
    }

    // MARK: - Applications Management

    public func observeApplications(for listingId: String) {
        applicationsListener?.remove()
        applicationsListener = db.collection("adoptionApplications")
            .whereField("listingId", isEqualTo: listingId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("[PPAdoptProStore] Applications error: \(error.localizedDescription)")
                    #endif
                    return
                }
                guard let snapshot else { return }
                var list: [PPAdoptApplicationModel] = []
                for doc in snapshot.documents {
                    if let app = PPAdoptApplicationModel(dict: doc.data(), documentID: doc.documentID) {
                        list.append(app)
                    }
                }
                list.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                self.applications = list
            }
    }

    // MARK: - Mutations

    /// Creates a brand new adoption listing using canonical `createAdoptionListing` callable
    public func createListing(draft: PPAdoptListingDraft) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            self.errorMessage = Language.isRTL() ? "يرجى تسجيل الدخول أولاً." : "Please sign in first."
            return false
        }

        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            self.errorMessage = Language.isRTL() ? "عنوان القائمة واسم الأليف مطلوب." : "Listing title is required."
            return false
        }

        isMutating = true
        errorMessage = nil

        let commandId = "pro-adopt-create-\(UUID().uuidString.lowercased())"
        let payload: [String: Any] = [
            "commandId": commandId,
            "title": trimmedTitle,
            "description": draft.descriptionText,
            "pet": [
                "name": trimmedTitle,
                "species": draft.species.rawValue.isEmpty ? "other" : draft.species.rawValue,
                "breed": draft.breed,
                "gender": draft.gender,
                "age": draft.age,
                "ageMonths": draft.ageMonths
            ],
            "health": [
                "vaccinated": draft.isVaccinated,
                "neutered": draft.isNeutered,
                "passport": draft.hasPassport,
                "microchipped": draft.isMicrochipped,
                "specialNeeds": draft.specialNeeds
            ],
            "area": [
                "city": draft.city,
                "district": draft.district
            ],
            "adoptionConditions": draft.adoptionConditions,
            "media": draft.mediaURLs.map { ["url": $0, "previewUrl": $0] },
            "imageURLs": draft.mediaURLs,
            "ownerPhone": draft.ownerPhone,
            "organizationName": draft.organizationName,
            "visibility": 0
        ]

        do {
            let callable = functions.httpsCallable("createAdoptionListing")
            let result = try await callable.call(payload)
            isMutating = false

            if let resp = result.data as? [String: Any], resp["ok"] as? Bool == true {
                self.successMessage = Language.isRTL() ? "تم إنشاء قائمة التبني بنجاح." : "Adoption listing created successfully."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            }

            // Fallback to direct Firestore creation if callable returned alternate format
            return try await fallbackDirectCreate(draft: draft, uid: uid)
        } catch {
            #if DEBUG
            print("[PPAdoptProStore] Callable failed, trying direct persistence: \(error.localizedDescription)")
            #endif
            return await fallbackDirectCreate(draft: draft, uid: uid)
        }
    }

    private func fallbackDirectCreate(draft: PPAdoptListingDraft, uid: String) async -> Bool {
        do {
            let col = db.collection("adoptionListings")
            let doc = col.document()
            let now = FieldValue.serverTimestamp()

            var payload = PPAdoptListingModel(
                id: doc.documentID,
                title: draft.title,
                descriptionText: draft.descriptionText,
                status: .published,
                species: draft.species,
                breed: draft.breed,
                gender: draft.gender,
                age: draft.age,
                ageMonths: draft.ageMonths,
                city: draft.city,
                district: draft.district,
                mediaURLs: draft.mediaURLs,
                isVaccinated: draft.isVaccinated,
                isNeutered: draft.isNeutered,
                hasPassport: draft.hasPassport,
                isMicrochipped: draft.isMicrochipped,
                specialNeeds: draft.specialNeeds,
                adoptionConditions: draft.adoptionConditions,
                ownerUid: uid,
                ownerPhone: draft.ownerPhone,
                organizationName: draft.organizationName
            ).toDictionary()

            payload["createdAt"] = now
            payload["updatedAt"] = now
            payload["createdBy"] = uid
            payload["updatedBy"] = uid

            try await doc.setData(payload)
            isMutating = false
            self.successMessage = Language.isRTL() ? "تم إنشاء قائمة التبني بنجاح." : "Adoption listing created successfully."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            isMutating = false
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    /// Updates existing listing details
    public func updateListing(id: String, draft: PPAdoptListingDraft, expectedVersion: Int) async -> Bool {
        isMutating = true
        errorMessage = nil

        let commandId = "pro-adopt-update-\(UUID().uuidString.lowercased())"
        let payload: [String: Any] = [
            "commandId": commandId,
            "listingId": id,
            "expectedVersion": expectedVersion,
            "title": draft.title,
            "description": draft.descriptionText,
            "pet": [
                "name": draft.title,
                "species": draft.species.rawValue,
                "breed": draft.breed,
                "gender": draft.gender,
                "age": draft.age,
                "ageMonths": draft.ageMonths
            ],
            "health": [
                "vaccinated": draft.isVaccinated,
                "neutered": draft.isNeutered,
                "passport": draft.hasPassport,
                "microchipped": draft.isMicrochipped,
                "specialNeeds": draft.specialNeeds
            ],
            "area": [
                "city": draft.city,
                "district": draft.district
            ],
            "adoptionConditions": draft.adoptionConditions,
            "media": draft.mediaURLs.map { ["url": $0, "previewUrl": $0] },
            "imageURLs": draft.mediaURLs,
            "ownerPhone": draft.ownerPhone,
            "organizationName": draft.organizationName
        ]

        do {
            let callable = functions.httpsCallable("updateAdoptionListing")
            _ = try await callable.call(payload)
            isMutating = false
            self.successMessage = Language.isRTL() ? "تم تحديث بيانات القائمة بنجاح." : "Listing updated successfully."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            // Direct Firestore fallback
            do {
                let doc = db.collection("adoptionListings").document(id)
                try await doc.updateData([
                    "title": draft.title,
                    "description": draft.descriptionText,
                    "pet.name": draft.title,
                    "pet.species": draft.species.rawValue,
                    "pet.breed": draft.breed,
                    "pet.gender": draft.gender,
                    "pet.age": draft.age,
                    "pet.ageMonths": draft.ageMonths,
                    "health.vaccinated": draft.isVaccinated,
                    "health.neutered": draft.isNeutered,
                    "health.passport": draft.hasPassport,
                    "health.microchipped": draft.isMicrochipped,
                    "health.specialNeeds": draft.specialNeeds,
                    "area.city": draft.city,
                    "area.district": draft.district,
                    "adoptionConditions": draft.adoptionConditions,
                    "media": draft.mediaURLs.map { ["url": $0] },
                    "imageURLs": draft.mediaURLs,
                    "ownerPhone": draft.ownerPhone,
                    "organizationName": draft.organizationName,
                    "version": expectedVersion + 1,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                isMutating = false
                self.successMessage = Language.isRTL() ? "تم تحديث بيانات القائمة بنجاح." : "Listing updated successfully."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            } catch let directError {
                isMutating = false
                self.errorMessage = directError.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return false
            }
        }
    }

    /// Transitions listing status (published, paused, applications_closed, adopted, archived, etc.)
    public func transitionListing(id: String, action: String, reason: String = "", expectedVersion: Int) async -> Bool {
        isMutating = true
        errorMessage = nil

        let commandId = "pro-adopt-trans-\(UUID().uuidString.lowercased())"
        let payload: [String: Any] = [
            "commandId": commandId,
            "listingId": id,
            "action": action,
            "expectedVersion": expectedVersion,
            "reason": reason
        ]

        do {
            let callable = functions.httpsCallable("transitionAdoptionListing")
            _ = try await callable.call(payload)
            isMutating = false
            self.successMessage = Language.isRTL() ? "تم تغيير حالة القائمة بنجاح." : "Listing status changed successfully."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            // Direct Firestore fallback
            do {
                let doc = db.collection("adoptionListings").document(id)
                let mappedStatus: String = {
                    switch action {
                    case "publish", "make_available": return "published"
                    case "pause", "hide": return "paused"
                    case "close_applications": return "applications_closed"
                    case "mark_adopted", "adopt": return "adopted"
                    case "archive": return "archived"
                    default: return action
                    }
                }()

                try await doc.updateData([
                    "status": mappedStatus,
                    "isAdopted": mappedStatus == "adopted",
                    "statusReason": reason.isEmpty ? NSNull() : reason,
                    "version": expectedVersion + 1,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                isMutating = false
                self.successMessage = Language.isRTL() ? "تم تغيير حالة القائمة بنجاح." : "Listing status changed successfully."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            } catch let directError {
                isMutating = false
                self.errorMessage = directError.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return false
            }
        }
    }

    /// Transitions application status (under_review, approved, rejected, handover, completed)
    public func transitionApplication(id: String, action: String, reason: String = "", expectedVersion: Int) async -> Bool {
        isMutating = true
        errorMessage = nil

        let commandId = "pro-app-trans-\(UUID().uuidString.lowercased())"
        let payload: [String: Any] = [
            "commandId": commandId,
            "applicationId": id,
            "action": action,
            "expectedVersion": expectedVersion,
            "reason": reason
        ]

        do {
            let callable = functions.httpsCallable("transitionAdoptionApplication")
            _ = try await callable.call(payload)
            isMutating = false
            self.successMessage = Language.isRTL() ? "تم تحديث حالة الطلب بنجاح." : "Application status updated successfully."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            // Direct fallback
            do {
                let doc = db.collection("adoptionApplications").document(id)
                let nextStatus: String = {
                    switch action {
                    case "start_review": return "under_review"
                    case "approve": return "approved"
                    case "reject": return "rejected"
                    case "schedule_handover": return "handover"
                    case "complete": return "completed"
                    default: return action
                    }
                }()
                try await doc.updateData([
                    "status": nextStatus,
                    "statusReason": reason.isEmpty ? NSNull() : reason,
                    "version": expectedVersion + 1,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                isMutating = false
                self.successMessage = Language.isRTL() ? "تم تحديث حالة الطلب بنجاح." : "Application status updated successfully."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            } catch let directError {
                isMutating = false
                self.errorMessage = directError.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return false
            }
        }
    }

    /// Deletes or archives a listing
    public func deleteListing(id: String, expectedVersion: Int) async -> Bool {
        // Try transition to archived first
        let archived = await transitionListing(id: id, action: "archive", reason: "Deleted by staff", expectedVersion: expectedVersion)
        if archived { return true }

        // Hard delete fallback
        do {
            try await db.collection("adoptionListings").document(id).delete()
            self.successMessage = Language.isRTL() ? "تم حذف القائمة بنجاح." : "Listing deleted successfully."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
