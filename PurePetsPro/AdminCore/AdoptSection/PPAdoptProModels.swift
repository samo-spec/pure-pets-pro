//
//  PPAdoptProModels.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Data Models for Community Adoption Suite.
//  Matches Pure Pets Admin and Pure Pets Infra canonical contracts.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Species Options

public enum PPAdoptSpecies: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case dog = "dog"
    case cat = "cat"
    case bird = "bird"
    case other = "other"

    public var id: String { rawValue }

    public var titleAr: String {
        switch self {
        case .all: return "الكل"
        case .dog: return "كلاب"
        case .cat: return "قطط"
        case .bird: return "طيور"
        case .other: return "أخرى"
        }
    }

    public var titleEn: String {
        switch self {
        case .all: return "All"
        case .dog: return "Dogs"
        case .cat: return "Cats"
        case .bird: return "Birds"
        case .other: return "Other"
        }
    }

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }

    public var symbol: String {
        switch self {
        case .all: return "pawprint.fill"
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        case .bird: return "bird.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    public static func from(raw: String) -> PPAdoptSpecies {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.contains("dog") || lowered.contains("كلب") { return .dog }
        if lowered.contains("cat") || lowered.contains("قط") { return .cat }
        if lowered.contains("bird") || lowered.contains("طير") { return .bird }
        if lowered.isEmpty { return .all }
        return .other
    }
}

// MARK: - Listing Status Options

public enum PPAdoptListingStatus: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case published = "published"
    case pendingReview = "pending_review"
    case needsChanges = "needs_changes"
    case paused = "paused"
    case applicationsClosed = "applications_closed"
    case matchInProgress = "match_in_progress"
    case adopted = "adopted"
    case rejected = "rejected"
    case archived = "archived"

    public var id: String { rawValue }

    public var titleAr: String {
        switch self {
        case .all: return "كل الحالات"
        case .published: return "منشور نشط"
        case .pendingReview: return "بانتظار المراجعة"
        case .needsChanges: return "يتطلب تعديل"
        case .paused: return "موقوف مؤقتاً"
        case .applicationsClosed: return "الطلبات مغلقة"
        case .matchInProgress: return "مطابقة جارية"
        case .adopted: return "تم التبني"
        case .rejected: return "مرفوض"
        case .archived: return "مؤرشف"
        }
    }

    public var titleEn: String {
        switch self {
        case .all: return "All Statuses"
        case .published: return "Published"
        case .pendingReview: return "Under Review"
        case .needsChanges: return "Needs Changes"
        case .paused: return "Paused"
        case .applicationsClosed: return "Applications Closed"
        case .matchInProgress: return "Match In Progress"
        case .adopted: return "Adopted"
        case .rejected: return "Rejected"
        case .archived: return "Archived"
        }
    }

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }

    public var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .published: return "checkmark.seal.fill"
        case .pendingReview: return "clock.badge.exclamationmark.fill"
        case .needsChanges: return "pencil.and.list.clipboard"
        case .paused: return "pause.circle.fill"
        case .applicationsClosed: return "lock.fill"
        case .matchInProgress: return "heart.circle.fill"
        case .adopted: return "house.and.flag.fill"
        case .rejected: return "xmark.octagon.fill"
        case .archived: return "archivebox.fill"
        }
    }

    public var tone: Color {
        switch self {
        case .all: return AdminSurface.primary
        case .published: return Color("#10B981") // Emerald
        case .pendingReview: return Color("#F59E0B") // Amber
        case .needsChanges: return Color("#8B5CF6") // Purple
        case .paused: return Color("#6B7280") // Gray
        case .applicationsClosed: return Color("#3B82F6") // Blue
        case .matchInProgress: return Color("#EC4899") // Pink
        case .adopted: return Color("#059669") // Dark green
        case .rejected: return Color("#EF4444") // Red
        case .archived: return Color("#9CA3AF") // Gray
        }
    }

    public static func from(raw: String) -> PPAdoptListingStatus {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lowered {
        case "published", "active", "available": return .published
        case "pending_review", "pending", "draft": return .pendingReview
        case "needs_changes": return .needsChanges
        case "paused", "hidden": return .paused
        case "applications_closed", "closed": return .applicationsClosed
        case "match_in_progress": return .matchInProgress
        case "adopted": return .adopted
        case "rejected": return .rejected
        case "archived": return .archived
        default: return .published
        }
    }
}

// MARK: - Adoption Listing Model

public struct PPAdoptListingModel: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var descriptionText: String
    public var status: PPAdoptListingStatus
    public var moderationStatus: String
    public var species: PPAdoptSpecies
    public var breed: String
    public var gender: String // "male" or "female"
    public var age: String
    public var ageMonths: Int
    public var city: String
    public var district: String
    public var mediaURLs: [String]
    public var isVaccinated: Bool
    public var isNeutered: Bool
    public var hasPassport: Bool
    public var isMicrochipped: Bool
    public var specialNeeds: String
    public var adoptionConditions: String
    public var applicationCount: Int
    public var isFeatured: Bool
    public var ownerUid: String
    public var ownerName: String
    public var ownerPhone: String
    public var organizationName: String
    public var selectedApplicationId: String?
    public var version: Int
    public var createdAt: Date?
    public var updatedAt: Date?

    public var primaryMediaURL: URL? {
        guard let first = mediaURLs.first, !first.isEmpty else { return nil }
        return URL(string: first)
    }

    public var locationDisplay: String {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDistrict = district.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCity.isEmpty && !trimmedDistrict.isEmpty {
            return "\(trimmedCity) · \(trimmedDistrict)"
        }
        return trimmedCity.isEmpty ? trimmedDistrict : trimmedCity
    }

    public var genderDisplay: String {
        let lowered = gender.lowercased()
        if lowered.contains("male") || lowered.contains("ذكر") {
            return Language.isRTL() ? "ذكر ♂" : "Male ♂"
        }
        if lowered.contains("female") || lowered.contains("أنثى") {
            return Language.isRTL() ? "أنثى ♀" : "Female ♀"
        }
        return ""
    }

    public var publisherDisplay: String {
        if !organizationName.isEmpty { return organizationName }
        if !ownerName.isEmpty { return ownerName }
        return Language.isRTL() ? "فريق التبني" : "Adoption Team"
    }

    public init(
        id: String,
        title: String,
        descriptionText: String = "",
        status: PPAdoptListingStatus = .published,
        moderationStatus: String = "",
        species: PPAdoptSpecies = .other,
        breed: String = "",
        gender: String = "",
        age: String = "",
        ageMonths: Int = 0,
        city: String = "",
        district: String = "",
        mediaURLs: [String] = [],
        isVaccinated: Bool = false,
        isNeutered: Bool = false,
        hasPassport: Bool = false,
        isMicrochipped: Bool = false,
        specialNeeds: String = "",
        adoptionConditions: String = "",
        applicationCount: Int = 0,
        isFeatured: Bool = false,
        ownerUid: String = "",
        ownerName: String = "",
        ownerPhone: String = "",
        organizationName: String = "",
        selectedApplicationId: String? = nil,
        version: Int = 1,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.status = status
        self.moderationStatus = moderationStatus
        self.species = species
        self.breed = breed
        self.gender = gender
        self.age = age
        self.ageMonths = ageMonths
        self.city = city
        self.district = district
        self.mediaURLs = mediaURLs
        self.isVaccinated = isVaccinated
        self.isNeutered = isNeutered
        self.hasPassport = hasPassport
        self.isMicrochipped = isMicrochipped
        self.specialNeeds = specialNeeds
        self.adoptionConditions = adoptionConditions
        self.applicationCount = applicationCount
        self.isFeatured = isFeatured
        self.ownerUid = ownerUid
        self.ownerName = ownerName
        self.ownerPhone = ownerPhone
        self.organizationName = organizationName
        self.selectedApplicationId = selectedApplicationId
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Initializes from canonical Firestore dictionary (supports `adoptionListings` & legacy `adopt_pets`).
    public init?(dict: [String: Any], documentID: String) {
        let pet = (dict["pet"] as? [String: Any]) ?? [:]
        let owner = (dict["owner"] as? [String: Any]) ?? [:]
        let area = (dict["area"] as? [String: Any]) ?? [:]
        let health = (dict["health"] as? [String: Any]) ?? [:]

        let titleStr = (pet["name"] as? String)
            ?? (pet["displayName"] as? String)
            ?? (dict["title"] as? String)
            ?? (dict["name"] as? String)
            ?? ""

        let descStr = (dict["description"] as? String)
            ?? (dict["details"] as? String)
            ?? (pet["description"] as? String)
            ?? ""

        let rawSpecies = (pet["species"] as? String)
            ?? (dict["species"] as? String)
            ?? (dict["kindID"] as? String)
            ?? ""

        let breedStr = (pet["breed"] as? String)
            ?? (dict["breed"] as? String)
            ?? (dict["breedName"] as? String)
            ?? ""

        let genderStr = (pet["gender"] as? String)
            ?? (dict["gender"] as? String)
            ?? ""

        let ageStr = (pet["age"] as? String)
            ?? (dict["petAge"] as? String)
            ?? (dict["age"] as? String)
            ?? ""

        let ageMonthsVal = (pet["ageMonths"] as? Int)
            ?? (dict["ageMonths"] as? Int)
            ?? 0

        let cityStr = (area["city"] as? String)
            ?? (dict["city"] as? String)
            ?? (dict["cityName"] as? String)
            ?? ""

        let districtStr = (area["district"] as? String)
            ?? (dict["district"] as? String)
            ?? ""

        var urls: [String] = []
        if let mediaList = dict["media"] as? [[String: Any]] {
            for item in mediaList {
                if let url = (item["url"] as? String) ?? (item["previewUrl"] as? String) ?? (item["thumbnailUrl"] as? String), !url.isEmpty {
                    urls.append(url)
                }
            }
        }
        if urls.isEmpty, let petMedia = pet["media"] as? [[String: Any]] {
            for item in petMedia {
                if let url = (item["url"] as? String) ?? (item["previewUrl"] as? String) ?? (item["thumbnailUrl"] as? String), !url.isEmpty {
                    urls.append(url)
                }
            }
        }
        if urls.isEmpty, let imgArr = dict["imageURLs"] as? [String] {
            urls = imgArr.filter { !$0.isEmpty }
        }
        if urls.isEmpty, let imgArr = dict["imageURLsArray"] as? [String] {
            urls = imgArr.filter { !$0.isEmpty }
        }
        if urls.isEmpty, let single = (dict["imageUrl"] as? String) ?? (dict["imageURL"] as? String), !single.isEmpty {
            urls = [single]
        }

        let rawStatus = (dict["status"] as? String)
            ?? ((dict["isAdopted"] as? Bool == true) ? "adopted" : "published")

        let modStatus = (dict["moderationStatus"] as? String) ?? ""

        let vaccinated = (health["vaccinated"] as? Bool)
            ?? (dict["isVaccinated"] as? Bool)
            ?? (dict["vaccinated"] as? Bool)
            ?? false

        let neutered = (health["neutered"] as? Bool)
            ?? (health["spayed"] as? Bool)
            ?? (dict["isNeutered"] as? Bool)
            ?? (dict["neutered"] as? Bool)
            ?? false

        let passport = (health["passport"] as? Bool)
            ?? (dict["hasPassport"] as? Bool)
            ?? (dict["passport"] as? Bool)
            ?? false

        let microchip = (health["microchipped"] as? Bool)
            ?? (dict["isMicrochipped"] as? Bool)
            ?? false

        let special = (health["specialNeeds"] as? String)
            ?? (dict["specialNeeds"] as? String)
            ?? ""

        let conditions = (dict["adoptionConditions"] as? String)
            ?? (dict["conditions"] as? String)
            ?? ""

        let appCount = (dict["applicationCount"] as? Int)
            ?? (dict["applicationsCount"] as? Int)
            ?? 0

        let featured = (dict["featured"] as? Bool)
            ?? (dict["isFeatured"] as? Bool)
            ?? false

        let ownerID = (dict["ownerUid"] as? String)
            ?? (dict["ownerId"] as? String)
            ?? (dict["ownerID"] as? String)
            ?? (dict["userID"] as? String)
            ?? ""

        let ownerNameStr = (owner["displayName"] as? String)
            ?? (dict["ownerName"] as? String)
            ?? ""

        let ownerPhoneStr = (owner["phoneNumber"] as? String)
            ?? (dict["ownerPhone"] as? String)
            ?? (dict["adopterContact"] as? String)
            ?? ""

        let orgStr = (dict["organizationName"] as? String) ?? ""
        let selectedApp = dict["selectedApplicationId"] as? String

        let ver = (dict["version"] as? Int) ?? 1

        let createdDate: Date? = {
            if let ts = dict["createdAt"] as? Timestamp { return ts.dateValue() }
            if let ts = dict["createdAt"] as? Double { return Date(timeIntervalSince1970: ts) }
            return nil
        }()

        let updatedDate: Date? = {
            if let ts = dict["updatedAt"] as? Timestamp { return ts.dateValue() }
            if let ts = dict["updatedAt"] as? Double { return Date(timeIntervalSince1970: ts) }
            return nil
        }()

        self.id = documentID
        self.title = titleStr.isEmpty ? (Language.isRTL() ? "أليف لطيف للتبني" : "Pet for Adoption") : titleStr
        self.descriptionText = descStr
        self.status = PPAdoptListingStatus.from(raw: rawStatus)
        self.moderationStatus = modStatus
        self.species = PPAdoptSpecies.from(raw: rawSpecies)
        self.breed = breedStr
        self.gender = genderStr
        self.age = ageStr
        self.ageMonths = ageMonthsVal
        self.city = cityStr
        self.district = districtStr
        self.mediaURLs = urls
        self.isVaccinated = vaccinated
        self.isNeutered = neutered
        self.hasPassport = passport
        self.isMicrochipped = microchip
        self.specialNeeds = special
        self.adoptionConditions = conditions
        self.applicationCount = appCount
        self.isFeatured = featured
        self.ownerUid = ownerID
        self.ownerName = ownerNameStr
        self.ownerPhone = ownerPhoneStr
        self.organizationName = orgStr
        self.selectedApplicationId = selectedApp
        self.version = ver
        self.createdAt = createdDate
        self.updatedAt = updatedDate
    }

    /// Exports to canonical dictionary payload
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "description": descriptionText,
            "status": status.rawValue,
            "moderationStatus": moderationStatus,
            "featured": isFeatured,
            "applicationCount": applicationCount,
            "version": version,
            "pet": [
                "name": title,
                "species": species.rawValue,
                "breed": breed,
                "gender": gender,
                "age": age,
                "ageMonths": ageMonths
            ],
            "health": [
                "vaccinated": isVaccinated,
                "neutered": isNeutered,
                "passport": hasPassport,
                "microchipped": isMicrochipped,
                "specialNeeds": specialNeeds
            ],
            "area": [
                "city": city,
                "district": district
            ],
            "adoptionConditions": adoptionConditions,
            "media": mediaURLs.map { ["url": $0, "previewUrl": $0] },
            "imageURLs": mediaURLs,
            "ownerUid": ownerUid,
            "ownerName": ownerName,
            "ownerPhone": ownerPhone,
            "organizationName": organizationName
        ]
        if let selectedApp = selectedApplicationId {
            dict["selectedApplicationId"] = selectedApp
        }
        return dict
    }
}

// MARK: - Adoption Application Question & Answer Item

public struct PPAdoptQuestionAnswer: Hashable, Sendable {
    public let questionId: String
    public let label: String
    public let answer: String

    public init(questionId: String, label: String, answer: String) {
        self.questionId = questionId
        self.label = label
        self.answer = answer
    }
}

// MARK: - Adoption Application Model

public struct PPAdoptApplicationModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let listingId: String
    public let applicantUid: String
    public let applicantName: String
    public let applicantPhone: String
    public var status: String
    public let message: String
    public let answers: [String: String]
    public let questionAnswers: [PPAdoptQuestionAnswer]
    public let version: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    public var statusDisplay: String {
        switch status.lowercased() {
        case "submitted": return Language.isRTL() ? "طلب جديد" : "Submitted"
        case "under_review": return Language.isRTL() ? "قيد المراجعة" : "Under Review"
        case "questions": return Language.isRTL() ? "استفسارات" : "Questions"
        case "meet_and_greet": return Language.isRTL() ? "لقاء تعريفي" : "Meet & Greet"
        case "home_check": return Language.isRTL() ? "فحص المنزل" : "Home Check"
        case "approved": return Language.isRTL() ? "تمت الموافقة" : "Approved"
        case "rejected": return Language.isRTL() ? "مرفوض" : "Rejected"
        case "withdrawn": return Language.isRTL() ? "ملغي" : "Withdrawn"
        case "handover": return Language.isRTL() ? "تسليم الأليف" : "Handover"
        case "completed": return Language.isRTL() ? "مكتمل" : "Completed"
        default: return status
        }
    }

    public var statusTone: Color {
        switch status.lowercased() {
        case "submitted": return Color(hex: "#F59E0B")
        case "under_review": return Color(hex: "#8B5CF6")
        case "approved", "completed": return Color(hex: "#10B981")
        case "rejected", "withdrawn": return Color(hex: "#EF4444")
        case "meet_and_greet", "handover": return Color(hex: "#3B82F6")
        default: return Color(hex: "#6B7280")
        }
    }

    public init?(dict: [String: Any], documentID: String) {
        self.id = documentID
        self.listingId = (dict["listingId"] as? String) ?? ""
        self.applicantUid = (dict["applicantUid"] as? String) ?? (dict["userId"] as? String) ?? ""
        self.applicantName = (dict["applicantName"] as? String) ?? (dict["name"] as? String) ?? (Language.isRTL() ? "متقدم للتبني" : "Applicant")
        self.applicantPhone = (dict["applicantPhone"] as? String) ?? (dict["phone"] as? String) ?? ""
        self.status = (dict["status"] as? String) ?? "submitted"
        self.message = (dict["message"] as? String) ?? (dict["notes"] as? String) ?? ""
        self.answers = (dict["answers"] as? [String: String]) ?? [:]

        var parsedQA: [PPAdoptQuestionAnswer] = []
        if let rawList = dict["questionAnswers"] as? [[String: Any]] {
            for item in rawList {
                let preferredLabel = Language.isRTL() ? item["labelAr"] as? String : item["labelEn"] as? String
                let fallbackLabel = Language.isRTL() ? item["labelEn"] as? String : item["labelAr"] as? String
                let qId = (item["questionId"] as? String) ?? ""
                let label = [preferredLabel, fallbackLabel, qId].compactMap { $0 }.first { !$0.isEmpty } ?? qId

                let val: String
                if let selectedOptions = item["selectedOptions"] as? [[String: Any]], !selectedOptions.isEmpty {
                    let optionLabels = selectedOptions.compactMap { opt -> String? in
                        let optPref = Language.isRTL() ? opt["labelAr"] as? String : opt["labelEn"] as? String
                        let optFall = Language.isRTL() ? opt["labelEn"] as? String : opt["labelAr"] as? String
                        return [optPref, optFall, opt["id"] as? String].compactMap { $0 }.first { !$0.isEmpty }
                    }
                    val = optionLabels.joined(separator: " · ")
                } else if let answerStr = item["answer"] as? String {
                    val = answerStr
                } else if let answerArr = item["answer"] as? [String] {
                    val = answerArr.joined(separator: " · ")
                } else {
                    val = ""
                }

                if !label.isEmpty && !val.isEmpty {
                    parsedQA.append(PPAdoptQuestionAnswer(questionId: qId, label: label, answer: val))
                }
            }
        }
        self.questionAnswers = parsedQA
        self.version = (dict["version"] as? Int) ?? 1

        self.createdAt = {
            if let ts = dict["createdAt"] as? Timestamp { return ts.dateValue() }
            if let ts = dict["createdAt"] as? Double { return Date(timeIntervalSince1970: ts) }
            return nil
        }()

        self.updatedAt = {
            if let ts = dict["updatedAt"] as? Timestamp { return ts.dateValue() }
            if let ts = dict["updatedAt"] as? Double { return Date(timeIntervalSince1970: ts) }
            return nil
        }()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PPAdoptApplicationModel, rhs: PPAdoptApplicationModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Draft Model for Create / Edit Form

public struct PPAdoptListingDraft {
    public var id: String?
    public var title: String = ""
    public var descriptionText: String = ""
    public var species: PPAdoptSpecies = .dog
    public var breed: String = ""
    public var gender: String = "male" // "male" or "female"
    public var age: String = ""
    public var ageMonths: Int = 12
    public var city: String = ""
    public var district: String = ""
    public var mediaURLs: [String] = []
    public var isVaccinated: Bool = true
    public var isNeutered: Bool = false
    public var hasPassport: Bool = false
    public var isMicrochipped: Bool = false
    public var specialNeeds: String = ""
    public var adoptionConditions: String = ""
    public var status: PPAdoptListingStatus = .published
    public var ownerPhone: String = ""
    public var organizationName: String = ""

    public init() {}

    public init(from listing: PPAdoptListingModel) {
        self.id = listing.id
        self.title = listing.title
        self.descriptionText = listing.descriptionText
        self.species = listing.species
        self.breed = listing.breed
        self.gender = listing.gender
        self.age = listing.age
        self.ageMonths = listing.ageMonths
        self.city = listing.city
        self.district = listing.district
        self.mediaURLs = listing.mediaURLs
        self.isVaccinated = listing.isVaccinated
        self.isNeutered = listing.isNeutered
        self.hasPassport = listing.hasPassport
        self.isMicrochipped = listing.isMicrochipped
        self.specialNeeds = listing.specialNeeds
        self.adoptionConditions = listing.adoptionConditions
        self.status = listing.status
        self.ownerPhone = listing.ownerPhone
        self.organizationName = listing.organizationName
    }
}
