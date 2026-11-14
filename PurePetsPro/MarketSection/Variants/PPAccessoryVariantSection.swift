//
//  PPAccessoryVariantSection.swift
//  PurePetsPro
//
//  Category-defining Product Options & Combinations Matrix Studio for Pure Pets Pro.
//  Bridges SwiftUI multi-axis variant management into the UIKit provider experience.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - SwiftUI Colour Bridge

extension PPAccessoryVariantColor {
    var uiColorValue: Color { Color(uiColor: uiColor) }
}

// MARK: - Predefined Colour Library

enum PPAccessoryVariantColorLibrary {
    static let entries: [PPAccessoryVariantColor] = [
        .init(identifier: "black", nameAr: "أسود", nameEn: "Black", hex: "#111111"),
        .init(identifier: "white", nameAr: "أبيض", nameEn: "White", hex: "#FFFFFF"),
        .init(identifier: "grey", nameAr: "رمادي", nameEn: "Grey", hex: "#9E9E9E"),
        .init(identifier: "beige", nameAr: "بيج", nameEn: "Beige", hex: "#D7C4A3"),
        .init(identifier: "brown", nameAr: "بني", nameEn: "Brown", hex: "#6D4C41"),
        .init(identifier: "crimson-red", nameAr: "أحمر", nameEn: "Red", hex: "#D71920"),
        .init(identifier: "rose-pink", nameAr: "وردي", nameEn: "Pink", hex: "#EC6F9C"),
        .init(identifier: "amber-orange", nameAr: "برتقالي", nameEn: "Orange", hex: "#F08A24"),
        .init(identifier: "sun-yellow", nameAr: "أصفر", nameEn: "Yellow", hex: "#F6C445"),
        .init(identifier: "forest-green", nameAr: "أخضر", nameEn: "Green", hex: "#2E7D32"),
        .init(identifier: "teal", nameAr: "أزرق مخضر", nameEn: "Teal", hex: "#00897B"),
        .init(identifier: "ocean-blue", nameAr: "أزرق", nameEn: "Blue", hex: "#1B6CA8"),
        .init(identifier: "navy", nameAr: "كحلي", nameEn: "Navy", hex: "#1A237E"),
        .init(identifier: "violet", nameAr: "بنفسجي", nameEn: "Violet", hex: "#6A3AB2"),
    ]
}

// MARK: - Failure State

struct PPAccessoryVariantFailureState {
    public let message: String
    public let recovery: PPAccessoryVariantRecovery
    public let affectedProductIds: [String]
    public let validationMessages: [String]

    public init(error: Error) {
        if let serviceError = error as? PPAccessoryVariantServiceError {
            message = serviceError.errorDescription ?? ""
            recovery = serviceError.recovery
            validationMessages = serviceError.validationMessages
            if case .server(let typed) = serviceError {
                affectedProductIds = typed.affectedProductIds
            } else {
                affectedProductIds = []
            }
            return
        }
        let typed = PPAccessoryVariantError.error(from: error as NSError)
        message = typed.message
        recovery = typed.recovery
        affectedProductIds = typed.affectedProductIds
        validationMessages = []
    }

    public init(message: String, recovery: PPAccessoryVariantRecovery) {
        self.message = message
        self.recovery = recovery
        self.affectedProductIds = []
        self.validationMessages = []
    }

    public var allowsSameCommandRetry: Bool { recovery == .retrySameCommand }
    public var preservesDraft: Bool { recovery != .fatal }

    public var actionTitle: String? {
        switch recovery {
        case .correctInput:
            return nil
        case .reloadAndCompare:
            return Language.get("Variant_Recovery_Reload", alter: "إعادة التحميل والمقارنة")
        case .retrySameCommand:
            return Language.get("Variant_Recovery_Retry", alter: "إعادة المحاولة")
        case .transferPublicListingFirst:
            return Language.get("Variant_Recovery_TransferListing", alter: "نقل العرض ثم الحفظ")
        case .treatAsApplied:
            return Language.get("Variant_Recovery_Refresh", alter: "تحديث للتحقق")
        case .permissionDenied, .fatal:
            return nil
        }
    }

    public var iconName: String {
        switch recovery {
        case .correctInput: return "exclamationmark.triangle.fill"
        case .reloadAndCompare: return "arrow.triangle.2.circlepath"
        case .retrySameCommand: return "arrow.clockwise"
        case .transferPublicListingFirst: return "arrow.left.arrow.right"
        case .treatAsApplied: return "checkmark.seal"
        case .permissionDenied: return "lock.fill"
        case .fatal: return "xmark.octagon.fill"
        }
    }

    public var tint: Color {
        switch recovery {
        case .treatAsApplied: return AdminSurface.emerald
        case .permissionDenied, .fatal: return AdminSurface.crimson
        default: return AdminSurface.amber
        }
    }
}

// MARK: - Section Model

@MainActor
final class PPAccessoryVariantSectionModel: ObservableObject {
    @Published public private(set) var baseline: PPAccessoryVariantFamily?
    @Published public var draft: PPAccessoryVariantFamily?
    @Published public var selectedProductId: String = ""
    @Published public private(set) var rootAccessory: PetAccessory?
    @Published public private(set) var rootAccessoryRevision: Int = 0
    public var onRootAccessoryUpdated: ((PetAccessory) -> Void)?

    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var validationMessages: [String] = []
    @Published public var failure: PPAccessoryVariantFailureState? {
        didSet { if failure != nil { confirmation = nil } }
    }
    @Published public var confirmation: String? {
        didSet { if confirmation != nil { failure = nil } }
    }

    @Published var stagedImages: [String: [PPAccessoryVariantStagedImage]] = [:]
    @Published public var retainedImageURLs: [String: [String]] = [:]
    @Published public private(set) var isSavingMedia = false
    @Published public private(set) var isCreatingVariant = false
    @Published public private(set) var isDissolving = false

    private var originalImageURLs: [String: [String]] = [:]
    private var imageMetadataByURL: [String: [String: Any]] = [:]
    private var pendingMediaCommandId: [String: String] = [:]
    private var pendingCommandId: String?
    @Published private var pendingSaveDraft: PPAccessoryVariantFamily?

    private var pendingVariantCreateCommandId: String?
    private var pendingVariantAttachCommandId: String?
    private var pendingVariantAttachDraft: PPAccessoryVariantFamily?
    private var pendingVariantCreationIntent: [String: String]?
    private var pendingCreatedVariantProduct: PetAccessory?

    public var canManageVariants: Bool { PPAccessoryVariantService.shared.canManageVariants }
    public var canViewCosts: Bool { true }

    public var isEditingLocked: Bool { isSaving || isCreatingVariant || isDissolving || pendingSaveDraft != nil }

    public var hasPendingStudioSave: Bool {
        pendingSaveDraft != nil || (pendingVariantCreationIntent != nil && failure?.allowsSameCommandRetry == true)
    }

    public var isDirty: Bool {
        guard let draft else { return false }
        return draft.hasChanges(comparedTo: baseline)
    }

    public var selectedVariant: PPAccessoryVariant? {
        guard let draft, !selectedProductId.isEmpty else { return nil }
        return draft.variant(forProductId: selectedProductId)
    }

    public var isLegacyUngrouped: Bool { draft?.isLegacySingleVariant ?? false }

    public var usedColorIdentifiers: Set<String> {
        Set((draft?.variants ?? []).map(\.color.identifier).filter { !$0.isEmpty })
    }

    public init() {}

    // MARK: - Load

    public func load(for accessory: PetAccessory) async {
        rootAccessory = accessory
        rootAccessoryRevision = max(1, accessory.revision)
        isLoading = true
        failure = nil
        defer { isLoading = false }
        do {
            let family = try await PPAccessoryVariantService.shared.resolveFamily(for: accessory)
            apply(loaded: family)
        } catch {
            let nsError = error as NSError
            print("[PPAccessoryVariantSection] resolveFamily failed product=\(accessory.accessoryID ?? "nil") family=\(accessory.productFamilyId ?? "<none>") error=\(nsError.localizedDescription)")
            failure = PPAccessoryVariantFailureState(error: error)
        }
    }

    public func load(for marketItem: PPProviderMarketItem) async {
        await load(for: marketItem.asPetAccessory())
    }

    public func reload() async {
        if let root = rootAccessory {
            await load(for: root)
        }
    }

    public func loadAccessory(forProductId productId: String) async throws -> PetAccessory {
        try await PPAccessoryVariantService.shared.loadProduct(productId: productId)
    }

    public func showsAssignments(for option: PPAccessoryOptionDefinition) -> Bool {
        guard let draft else { return false }
        let isNewDimension = baseline?.optionDefinitions.contains(where: { $0.id == option.id }) != true
        return isNewDimension || draft.variants.contains { variant in
            !option.values.contains { $0.id == variant.selectedOptions[option.id] }
        }
    }

    public func selectOptionValue(_ valueId: String, optionId: String, productId: String) {
        guard canManageVariants, !isEditingLocked, let draft,
              let definition = draft.optionDefinitions.first(where: { $0.id == optionId }),
              definition.values.contains(where: { $0.id == valueId }),
              let variant = draft.variant(forProductId: productId) else { return }
        if let baseline, !baseline.familyId.isEmpty,
           baseline.optionDefinitions.contains(where: { $0.id == optionId }),
           let previous = baseline.variant(forProductId: productId)?.selectedOptions[optionId], previous != valueId {
            failure = PPAccessoryVariantFailureState(message: Language.get("Options_Error_IdentityImmutable", alter: "لا يمكن تغيير قيمة خيار محفوظ لصنف موجود. أنشئ متغيرًا جديدًا للتوليفة الجديدة للحفاظ على المخزون والسجل."), recovery: .correctInput)
            return
        }
        variant.selectedOptions[optionId] = valueId
        variant.combinationKey = PPAccessoryVariantFamily.combinationKey(from: variant.selectedOptions)
        self.draft = draft
        revalidate()
    }

    private func apply(loaded family: PPAccessoryVariantFamily) {
        family.autoBindMissingOptionSelections()
        baseline = family
        let workingDraft = family.copyForEditing()
        workingDraft.autoBindMissingOptionSelections()
        draft = workingDraft
        if selectedProductId.isEmpty || family.variant(forProductId: selectedProductId) == nil {
            selectedProductId = family.defaultVariantProductId.isEmpty
                ? (family.variants.first?.productId ?? "")
                : family.defaultVariantProductId
        }
        if let root = rootAccessory, let matched = family.variant(forProductId: root.accessoryID) {
            if matched.revision > root.revision {
                root.revision = matched.revision
            }
            if !matched.barcode.isEmpty { root.barcode = matched.barcode }
            if !matched.sku.isEmpty { root.sku = matched.sku }
            root.quantity = matched.quantity
            root.isDefaultVariant = matched.isDefault
            root.variantSortOrder = matched.sortOrder
            rootAccessoryRevision = max(rootAccessoryRevision, root.revision)
        } else if let root = rootAccessory {
            rootAccessoryRevision = max(rootAccessoryRevision, root.revision)
        }
        retainedImageURLs = [:]
        originalImageURLs = [:]
        stagedImages = [:]
        imageMetadataByURL = [:]
        for variant in family.variants {
            let urls = variant.media.compactMap { $0.isUploaded ? $0.remoteURL : nil }
            retainedImageURLs[variant.productId] = urls
            originalImageURLs[variant.productId] = urls
            for media in variant.media where media.isUploaded {
                imageMetadataByURL[media.remoteURL] = media.metadataPayload()
            }
        }
        validationMessages = []
    }

    /// Only committed commands notify the parent editor. Loading or closing the
    /// studio must not replace an unsaved form with a partial family projection.
    private func publishCommittedRoot() async throws {
        guard let id = rootAccessory?.accessoryID, !id.isEmpty else { return }
        let product = try await PPAccessoryVariantService.shared.loadProduct(productId: id)
        rootAccessory = product
        rootAccessoryRevision = max(rootAccessoryRevision, product.revision)
        onRootAccessoryUpdated?(product)
    }

    private func refreshCommittedCatalog(productId: String) async throws {
        let product = try await PPAccessoryVariantService.shared.loadProduct(productId: productId)
        if let index = draft?.variants.firstIndex(where: { $0.productId == productId }), let variant = draft?.variants[index] {
            draft?.variants[index] = variant.refreshingCatalog(from: product)
        }
        if let index = baseline?.variants.firstIndex(where: { $0.productId == productId }), let variant = baseline?.variants[index] {
            baseline?.variants[index] = variant.refreshingCatalog(from: product)
        }
        if rootAccessory?.accessoryID == productId {
            rootAccessory = product
            rootAccessoryRevision = product.revision
            onRootAccessoryUpdated?(product)
        }
    }

    // MARK: - Media

    public func images(forProductId productId: String) -> [String] {
        retainedImageURLs[productId] ?? []
    }

    func staged(forProductId productId: String) -> [PPAccessoryVariantStagedImage] {
        stagedImages[productId] ?? []
    }

    public func totalImageCount(forProductId productId: String) -> Int {
        images(forProductId: productId).count + staged(forProductId: productId).count
    }

    public func canAddImage(forProductId productId: String) -> Bool {
        totalImageCount(forProductId: productId) < PPAccessoryVariantMediaService.maxImagesPerVariant
    }

    public func addImages(_ images: [UIImage], forProductId productId: String) {
        guard !images.isEmpty else { return }
        var current = stagedImages[productId] ?? []
        let room = PPAccessoryVariantMediaService.maxImagesPerVariant - totalImageCount(forProductId: productId)
        guard room > 0 else { return }
        current.append(contentsOf: images.prefix(room).map { PPAccessoryVariantStagedImage(image: $0) })
        stagedImages[productId] = current
    }

    public func removeUploadedImage(at index: Int, forProductId productId: String) {
        guard var urls = retainedImageURLs[productId], urls.indices.contains(index) else { return }
        urls.remove(at: index)
        retainedImageURLs[productId] = urls
    }

    public func removeStagedImage(id: UUID, forProductId productId: String) {
        guard var current = stagedImages[productId] else { return }
        current.removeAll { $0.id == id }
        stagedImages[productId] = current
    }

    public func makePrimaryImage(at index: Int, forProductId productId: String) {
        guard var urls = retainedImageURLs[productId], urls.indices.contains(index), index > 0 else { return }
        let url = urls.remove(at: index)
        urls.insert(url, at: 0)
        retainedImageURLs[productId] = urls
    }

    public func saveMedia(forProductId productId: String, expectedRevision: Int? = nil, color: PPAccessoryVariantColor? = nil) async {
        let variant = draft?.variant(forProductId: productId)
        guard let mediaColor = variant?.color ?? color,
              let revision = expectedRevision ?? variant?.revision else { return }
        isSavingMedia = true
        failure = nil
        confirmation = nil
        defer { isSavingMedia = false }

        let commandId = pendingMediaCommandId[productId] ?? "variant-media-\(productId)-\(UUID().uuidString)"
        pendingMediaCommandId[productId] = commandId

        var staged = stagedImages[productId] ?? []
        do {
            try await PPAccessoryVariantMediaService.shared.uploadStagedImages(
                &staged,
                productId: productId,
                colorId: mediaColor.identifier
            )
            stagedImages[productId] = staged

            let commit = PPAccessoryVariantMediaService.shared.commit(
                productId: productId,
                retainedURLs: retainedImageURLs[productId] ?? [],
                staged: staged,
                previousURLs: originalImageURLs[productId] ?? [],
                metadataByURL: imageMetadataByURL
            )
            try await PPAccessoryVariantMediaService.shared.persist(
                commit,
                commandId: commandId,
                expectedRevision: revision
            )

            await PPAccessoryVariantMediaService.shared.deleteOrphans(commit.orphanedURLs)

            pendingMediaCommandId[productId] = nil
            stagedImages[productId] = []
            retainedImageURLs[productId] = commit.imageURLs
            originalImageURLs[productId] = commit.imageURLs
            for entry in commit.imageMeta {
                if let url = entry["url"] as? String { imageMetadataByURL[url] = entry }
            }
            try await refreshCommittedCatalog(productId: productId)
            confirmation = Language.get("Variant_Media_Saved", alter: "تم حفظ صور اللون.")
        } catch let mediaError as PPAccessoryVariantMediaError {
            stagedImages[productId] = staged
            failure = PPAccessoryVariantFailureState(
                message: mediaError.errorDescription ?? "",
                recovery: .retrySameCommand
            )
        } catch {
            stagedImages[productId] = staged
            failure = PPAccessoryVariantFailureState(error: error)
            if !(failure?.allowsSameCommandRetry ?? false) { pendingMediaCommandId[productId] = nil }
        }
    }

    // MARK: - Mutations

    public func select(productId: String) {
        selectedProductId = productId
    }

    public func updateColor(_ color: PPAccessoryVariantColor, forProductId productId: String) {
        guard let draft, let index = draft.variants.firstIndex(where: { $0.productId == productId }) else { return }
        let existing = draft.variants[index]
        var updatedOptions = existing.selectedOptions
        if let colorDef = draft.optionDefinitions.first(where: { $0.isColorOption }) {
            updatedOptions[colorDef.id] = color.identifier
        }
        updatedOptions[PPAccessoryVariantContract.axisColor] = color.identifier
        let updatedKey = PPAccessoryVariantFamily.combinationKey(from: updatedOptions)
        draft.variants[index] = PPAccessoryVariant(
            productId: existing.productId,
            color: color,
            sortOrder: existing.sortOrder,
            isArchived: existing.isArchived,
            isDefault: existing.isDefault,
            sku: existing.sku,
            barcode: existing.barcode,
            primaryImageURL: existing.primaryImageURL,
            quantity: existing.quantity,
            retailPrice: existing.retailPrice,
            wholesalePrice: existing.wholesalePrice,
            costPrice: existing.costPrice,
            hasResolvedRetailPrice: existing.hasResolvedRetailPrice,
            showInAppMarket: existing.showInAppMarket,
            revision: existing.revision,
            media: existing.media,
            selectedOptions: updatedOptions,
            combinationKey: updatedKey
        )
        if draft.optionDefinitions.isEmpty {
            draft.optionDefinitions = [PPAccessoryOptionDefinition.synthesizeColorOption(fromVariants: draft.variants)]
        }
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        revalidate()
    }

    public func convertWithPresetOption(_ option: PPAccessoryOptionDefinition) {
        guard let draft else { return }
        draft.isLegacySingleVariant = false
        draft.optionDefinitions = [option]

        if let firstVariant = draft.variants.first {
            let initialColor = firstVariant.color.identifier.isEmpty
                ? PPAccessoryVariantColor.standardNeutral
                : firstVariant.color
            let defaultValId = option.values.first?.id ?? ""
            let updatedVariant = PPAccessoryVariant(
                productId: firstVariant.productId,
                color: initialColor,
                sortOrder: firstVariant.sortOrder,
                isArchived: firstVariant.isArchived,
                isDefault: true,
                sku: firstVariant.sku,
                barcode: firstVariant.barcode,
                primaryImageURL: firstVariant.primaryImageURL,
                quantity: firstVariant.quantity,
                retailPrice: firstVariant.retailPrice,
                wholesalePrice: firstVariant.wholesalePrice,
                costPrice: firstVariant.costPrice,
                hasResolvedRetailPrice: firstVariant.hasResolvedRetailPrice,
                showInAppMarket: firstVariant.showInAppMarket,
                revision: firstVariant.revision,
                media: firstVariant.media,
                selectedOptions: defaultValId.isEmpty ? [:] : [option.id: defaultValId],
                combinationKey: defaultValId.isEmpty ? "" : "\(option.id)=\(defaultValId)"
            )
            draft.variants = [updatedVariant]
        }
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        revalidate()
    }

    public func setDefault(productId: String) {
        guard let draft else { return }
        guard let target = draft.variant(forProductId: productId), !target.isArchived else { return }
        draft.defaultVariantProductId = productId
        for index in draft.variants.indices {
            draft.variants[index].isDefault = draft.variants[index].productId == productId
        }
        self.draft = draft
        revalidate()
    }

    public func setArchived(_ archived: Bool, forProductId productId: String) {
        guard let draft, let index = draft.variants.firstIndex(where: { $0.productId == productId }) else { return }
        draft.variants[index].isArchived = archived
        if archived, draft.defaultVariantProductId == productId,
           let replacement = draft.variants.first(where: { !$0.isArchived }) {
            draft.defaultVariantProductId = replacement.productId
            for i in draft.variants.indices {
                draft.variants[i].isDefault = draft.variants[i].productId == replacement.productId
            }
        }
        self.draft = draft
        revalidate()
    }

    public func toggleArchive(forProductId productId: String) {
        guard let current = draft?.variant(forProductId: productId) else { return }
        setArchived(!current.isArchived, forProductId: productId)
    }

    public func move(productId: String, by offset: Int) {
        guard let draft, let index = draft.variants.firstIndex(where: { $0.productId == productId }) else { return }
        let target = index + offset
        guard draft.variants.indices.contains(target) else { return }
        draft.variants.swapAt(index, target)
        for (position, _) in draft.variants.enumerated() {
            draft.variants[position].sortOrder = position
        }
        self.draft = draft
        revalidate()
    }

    public func removeVariant(productId: String) {
        guard let draft else { return }
        guard draft.variants.count > 1 else {
            failure = PPAccessoryVariantFailureState(
                message: Language.get("Variant_Error_CannotDeleteOnlyVariant", alter: "لا يمكن حذف المتغير الوحيد في المنتج."),
                recovery: .correctInput
            )
            return
        }
        guard let targetIndex = draft.variants.firstIndex(where: { $0.productId == productId }) else { return }
        let targetVariant = draft.variants[targetIndex]
        let isDefault = targetVariant.isDefault
        draft.variants.remove(at: targetIndex)
        for (pos, _) in draft.variants.enumerated() {
            draft.variants[pos].sortOrder = pos
        }
        if isDefault, let first = draft.variants.first {
            first.isDefault = true
            draft.defaultVariantProductId = first.productId
        }
        if selectedProductId == productId {
            selectedProductId = draft.variants.first?.productId ?? ""
        }
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        confirmation = Language.get("Variant_Delete_Confirmed", alter: "تم حذف المتغير من المجموعة بنجاح.")
        revalidate()
    }

    // MARK: - Options Mutations

    public func addOption(_ option: PPAccessoryOptionDefinition) {
        guard let draft else { return }
        guard draft.optionDefinitions.count < PPAccessoryVariantContract.maxOptionsPerFamily else { return }
        guard !draft.optionDefinitions.contains(where: { $0.id == option.id || $0.key == option.key }) else { return }
        draft.schemaVersion = PPAccessoryVariantContract.variantSchemaVersionGeneric
        draft.isLegacySingleVariant = false
        var updated = draft.optionDefinitions
        var newOption = option
        newOption.sortOrder = updated.count
        updated.append(newOption)
        draft.optionDefinitions = updated
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        revalidate()
    }

    public func removeOption(withId id: String) {
        guard let draft else { return }
        if let message = draft.optionRemovalMessage(id: id) {
            failure = PPAccessoryVariantFailureState(message: message, recovery: .correctInput)
            return
        }
        draft.schemaVersion = PPAccessoryVariantContract.variantSchemaVersionGeneric
        var updated = draft.optionDefinitions
        updated.removeAll { $0.id == id }
        for (index, opt) in updated.enumerated() { opt.sortOrder = index }
        draft.optionDefinitions = updated
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        failure = nil
        revalidate()
    }

    public func moveOptionEarlier(id: String) {
        guard let draft else { return }
        guard let index = draft.optionDefinitions.firstIndex(where: { $0.id == id }), index > 0 else { return }
        var updated = draft.optionDefinitions
        updated.swapAt(index, index - 1)
        for (i, opt) in updated.enumerated() { opt.sortOrder = i }
        draft.optionDefinitions = updated
        self.draft = draft
        revalidate()
    }

    public func moveOptionLater(id: String) {
        guard let draft else { return }
        guard let index = draft.optionDefinitions.firstIndex(where: { $0.id == id }), index < draft.optionDefinitions.count - 1 else { return }
        var updated = draft.optionDefinitions
        updated.swapAt(index, index + 1)
        for (i, opt) in updated.enumerated() { opt.sortOrder = i }
        draft.optionDefinitions = updated
        self.draft = draft
        revalidate()
    }

    public func addOptionValue(_ value: PPAccessoryOptionValue, toOptionWithId optionId: String) {
        guard let draft else { return }
        guard let optIndex = draft.optionDefinitions.firstIndex(where: { $0.id == optionId }) else { return }
        let option = draft.optionDefinitions[optIndex]
        guard option.values.count < PPAccessoryVariantContract.maxValuesPerOption else { return }
        guard !option.values.contains(where: { $0.id == value.id || $0.canonicalValue.lowercased() == value.canonicalValue.lowercased() }) else { return }
        draft.schemaVersion = PPAccessoryVariantContract.variantSchemaVersionGeneric
        var updatedValues = option.values
        var newValue = value
        newValue.sortOrder = updatedValues.count
        updatedValues.append(newValue)
        option.values = updatedValues
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        revalidate()
    }

    public func removeOptionValue(valueId: String, fromOptionWithId optionId: String) {
        guard let draft else { return }
        guard !isOptionValueInUse(valueId: valueId, optionId: optionId) else {
            failure = PPAccessoryVariantFailureState(message: Language.get("Options_Error_ValueInUse", alter: "هذه القيمة مرتبطة بصنف موجود. احتفظ بها، ويمكنك أرشفة الصنف من المصفوفة عند عدم الحاجة إليه."), recovery: .correctInput)
            return
        }
        guard let optIndex = draft.optionDefinitions.firstIndex(where: { $0.id == optionId }) else { return }
        let option = draft.optionDefinitions[optIndex]
        draft.schemaVersion = PPAccessoryVariantContract.variantSchemaVersionGeneric
        var updatedValues = option.values
        updatedValues.removeAll { $0.id == valueId }
        for (index, val) in updatedValues.enumerated() { val.sortOrder = index }
        option.values = updatedValues
        draft.autoBindMissingOptionSelections()
        self.draft = draft
        revalidate()
    }

    public func moveOptionValueEarlier(valueId: String, inOptionWithId optionId: String) {
        guard let draft else { return }
        guard let optIndex = draft.optionDefinitions.firstIndex(where: { $0.id == optionId }) else { return }
        let option = draft.optionDefinitions[optIndex]
        guard let valIndex = option.values.firstIndex(where: { $0.id == valueId }), valIndex > 0 else { return }
        var updatedValues = option.values
        updatedValues.swapAt(valIndex, valIndex - 1)
        for (i, val) in updatedValues.enumerated() { val.sortOrder = i }
        option.values = updatedValues
        self.draft = draft
        revalidate()
    }

    public func moveOptionValueLater(valueId: String, inOptionWithId optionId: String) {
        guard let draft else { return }
        guard let optIndex = draft.optionDefinitions.firstIndex(where: { $0.id == optionId }) else { return }
        let option = draft.optionDefinitions[optIndex]
        guard let valIndex = option.values.firstIndex(where: { $0.id == valueId }), valIndex < option.values.count - 1 else { return }
        var updatedValues = option.values
        updatedValues.swapAt(valIndex, valIndex + 1)
        for (i, val) in updatedValues.enumerated() { val.sortOrder = i }
        option.values = updatedValues
        self.draft = draft
        revalidate()
    }

    public func isOptionValueInUse(valueId: String, optionId: String) -> Bool {
        guard let draft else { return false }
        for variant in draft.variants {
            if variant.selectedOptions[optionId] == valueId { return true }
            if optionId == PPAccessoryVariantContract.axisColor && variant.color.identifier == valueId { return true }
        }
        return false
    }

    // MARK: - Creation and Save

    public func createAndAttachVariant(
        color: PPAccessoryVariantColor,
        selectedOptions: [String: String] = [:],
        sku: String,
        barcode: String,
        retailPrice: Double,
        wholesalePrice: Double?,
        costPrice: Double? = nil,
        quantity: Int = 0,
        images: [UIImage] = []
    ) async -> Bool {
        guard canManageVariants, !isSaving, !isCreatingVariant else { return false }
        if draft?.familyId.isEmpty == true || isDirty || pendingSaveDraft != nil {
            await save()
            guard failure == nil, !isDirty, pendingSaveDraft == nil,
                  let saved = draft, !saved.familyId.isEmpty else {
                if failure == nil, let message = validationMessages.first {
                    failure = PPAccessoryVariantFailureState(message: message, recovery: .correctInput)
                }
                return false
            }
        }
        guard let current = draft, !current.isLegacySingleVariant, !current.familyId.isEmpty else {
            failure = PPAccessoryVariantFailureState(
                message: Language.get("Variant_Add_SaveFamilyFirst", alter: "احفظ خيارات المنتج الحالي أولاً، ثم أضف متغيراً جديداً."),
                recovery: .correctInput
            )
            return false
        }
        guard color.validationMessage == nil else {
            failure = PPAccessoryVariantFailureState(message: color.validationMessage ?? "", recovery: .correctInput)
            return false
        }

        var requestedOptions: [String: String] = [:]
        if current.hasGenericOptions {
            for option in current.optionDefinitions {
                let valueId = selectedOptions[option.id] ?? selectedOptions[option.key]
                    ?? (option.isColorOption ? color.identifier : "")
                guard option.values.contains(where: { $0.id == valueId }) else {
                    failure = PPAccessoryVariantFailureState(
                        message: Language.get("Options_Error_Incomplete", alter: "اختر قيمة لكل خيار قبل إنشاء المتغير."),
                        recovery: .correctInput
                    )
                    return false
                }
                requestedOptions[option.id] = valueId
            }
            let requestedKey = PPAccessoryVariantFamily.combinationKey(from: requestedOptions)
            if current.variants.contains(where: { PPAccessoryVariantFamily.combinationKey(from: $0.selectedOptions) == requestedKey }) {
                failure = PPAccessoryVariantFailureState(
                    message: Language.get("Variant_Error_CombinationTaken", alter: "هذه التوليفة مستخدمة بالفعل في هذا المنتج."),
                    recovery: .correctInput
                )
                return false
            }
        } else {
            requestedOptions[PPAccessoryVariantContract.axisColor] = color.identifier
        }

        guard retailPrice.isFinite, retailPrice > 0, retailPrice <= 999_999_999.99,
              wholesalePrice == nil || (wholesalePrice!.isFinite && wholesalePrice! > 0 && wholesalePrice! <= 999_999_999.99),
              costPrice == nil || (costPrice!.isFinite && costPrice! >= 0 && costPrice! <= 999_999_999.99), quantity >= 0 else {
            failure = PPAccessoryVariantFailureState(
                message: Language.get("Variant_Add_InvalidPrice", alter: "أدخل سعر بيع صالحاً للمتغير الجديد."),
                recovery: .correctInput
            )
            return false
        }

        isCreatingVariant = true
        failure = nil
        confirmation = nil
        defer { isCreatingVariant = false }

        do {
            let product: PetAccessory
            if let pendingCreatedVariantProduct {
                product = pendingCreatedVariantProduct
            } else {
                guard let templateProductId = current.defaultVariantProductId.isEmpty
                    ? current.variants.first?.productId
                    : current.defaultVariantProductId else {
                    throw PPAccessoryVariantServiceError.invalidResponse
                }
                let template = try await PPAccessoryVariantService.shared.loadProduct(productId: templateProductId)
                let createCommandId = pendingVariantCreateCommandId ?? "variant-product-create-\(current.familyId)-\(UUID().uuidString)"
                pendingVariantCreateCommandId = createCommandId
                product = try await PPAccessoryVariantService.shared.createStandaloneVariantProduct(
                    template: template,
                    sku: sku,
                    barcode: barcode,
                    retailPrice: retailPrice,
                    wholesalePrice: wholesalePrice,
                    costPrice: costPrice,
                    quantity: max(0, quantity),
                    commandId: createCommandId
                )
                pendingCreatedVariantProduct = product
            }

            if !images.isEmpty, originalImageURLs[product.accessoryID] == nil {
                if staged(forProductId: product.accessoryID).isEmpty {
                    addImages(images, forProductId: product.accessoryID)
                }
                await saveMedia(forProductId: product.accessoryID, expectedRevision: product.revision, color: color)
                guard failure == nil else { return false }
            }

            let latest = try await PPAccessoryVariantService.shared.loadFamily(familyId: current.familyId)
            if latest.variant(forProductId: product.accessoryID) != nil {
                apply(loaded: latest)
                try await publishCommittedRoot()
                clearPendingVariantCreation()
                confirmation = Language.get("Variant_Add_Confirmed", alter: "تمت إضافة المتغير وحفظه.")
                return true
            }

            var finalOptions = requestedOptions
            if let colorDef = latest.optionDefinitions.first(where: { $0.isColorOption }) {
                finalOptions[colorDef.id] = color.identifier
            }
            if !latest.hasGenericOptions { finalOptions[PPAccessoryVariantContract.axisColor] = color.identifier }
            let combinationKey = PPAccessoryVariantFamily.combinationKey(from: finalOptions)

            let refreshedProduct = try await PPAccessoryVariantService.shared.loadProduct(productId: product.accessoryID)
            let nextSort = (latest.variants.map(\.sortOrder).max() ?? -1) + 1
            latest.variants.append(PPAccessoryVariant(
                productId: refreshedProduct.accessoryID,
                color: color,
                sortOrder: nextSort,
                isArchived: false,
                isDefault: latest.variants.isEmpty,
                sku: refreshedProduct.sku ?? "",
                barcode: refreshedProduct.barcode ?? "",
                primaryImageURL: PetAccessory.firstImageURL(for: refreshedProduct)?.absoluteString ?? "",
                quantity: refreshedProduct.quantity,
                retailPrice: refreshedProduct.hasResolvedSellingPrice ? refreshedProduct.finalPrice : nil,
                wholesalePrice: refreshedProduct.wholesalePrice,
                costPrice: refreshedProduct.costPrice,
                hasResolvedRetailPrice: refreshedProduct.hasResolvedSellingPrice,
                showInAppMarket: false,
                revision: refreshedProduct.revision,
                media: (refreshedProduct.imageURLsArray ?? []).map { PPAccessoryVariantMedia(remoteURL: $0) },
                selectedOptions: finalOptions,
                combinationKey: combinationKey
            ))
            latest.autoBindMissingOptionSelections()

            let attachCommandId = pendingVariantAttachCommandId ?? "variant-family-attach-\(current.familyId)-\(UUID().uuidString)"
            pendingVariantAttachCommandId = attachCommandId
            let attachDraft = pendingVariantAttachDraft ?? latest.copyForEditing()
            pendingVariantAttachDraft = attachDraft
            let attached = try await PPAccessoryVariantService.shared.saveFamily(attachDraft, commandId: attachCommandId)
            let reloaded = try await PPAccessoryVariantService.shared.loadFamily(familyId: current.familyId, minimumRevision: attached.revision)
            apply(loaded: reloaded)
            selectedProductId = refreshedProduct.accessoryID
            try await publishCommittedRoot()
            clearPendingVariantCreation()
            confirmation = Language.get("Variant_Add_Confirmed", alter: "تمت إضافة المتغير وحفظه.")
            return true
        } catch {
            let state = PPAccessoryVariantFailureState(error: error)
            failure = state
            if !state.allowsSameCommandRetry {
                pendingVariantAttachCommandId = nil
                pendingVariantAttachDraft = nil
                if pendingCreatedVariantProduct == nil {
                    pendingVariantCreateCommandId = nil
                    pendingVariantCreationIntent = nil
                }
            }
            return false
        }
    }

    public func createAndAttachCombinationVariant(
        selectedOptions: [String: String],
        color: PPAccessoryVariantColor?,
        sku: String,
        barcode: String,
        retailPrice: Double,
        wholesalePrice: Double?,
        costPrice: Double? = nil,
        quantity: Int = 0,
        images: [UIImage] = []
    ) async -> Bool {
        let resolvedColor = color ?? PPAccessoryVariantColor(
            identifier: selectedOptions["color"] ?? "standard",
            nameAr: "افتراضي",
            nameEn: "Standard",
            hex: "#7F7F7F"
        )
        return await createAndAttachVariant(
            color: resolvedColor, selectedOptions: selectedOptions,
            sku: sku, barcode: barcode, retailPrice: retailPrice,
            wholesalePrice: wholesalePrice, costPrice: costPrice,
            quantity: quantity, images: images
        )
    }

    public func applyBulkPricing(
        retailPrice: Double,
        wholesalePrice: Double?,
        costPrice: Double? = nil,
        forProductIds productIds: [String]
    ) async -> Bool {
        guard !productIds.isEmpty else { return false }
        isSaving = true
        failure = nil
        confirmation = nil
        defer { isSaving = false }

        var successCount = 0
        for productId in productIds {
            var fields: [String: Any] = [
                "price": retailPrice
            ]
            if let wholesale = wholesalePrice { fields["wholesalePrice"] = wholesale }
            if let cost = costPrice { fields["costPrice"] = cost }

            let ok: Bool = await withCheckedContinuation { continuation in
                PPProviderMarketplaceManager.shared().updateMarketItem(productId, fields: fields) { success, _, _ in
                    continuation.resume(returning: success)
                }
            }
            if ok { successCount += 1 }
        }

        if let familyId = draft?.familyId, !familyId.isEmpty {
            if let reloaded = try? await PPAccessoryVariantService.shared.loadFamily(familyId: familyId) {
                apply(loaded: reloaded)
            }
        }
        do {
            if successCount > 0 { try await publishCommittedRoot() }
        } catch {
            failure = PPAccessoryVariantFailureState(error: error)
            return false
        }
        guard successCount == productIds.count else {
            failure = PPAccessoryVariantFailureState(message: Language.get("ProInventory_BulkPartial", alter: "لم تُحفظ جميع الأسعار. راجع المتغيرات ثم أعد المحاولة."), recovery: .correctInput)
            return false
        }
        confirmation = Language.get("Variant_BulkPricing_Success", alter: "تم تحديث أسعار المتغيرات بنجاح.")
        return true
    }

    public func updateVariant(
        productId: String,
        color: PPAccessoryVariantColor,
        selectedOptions: [String: String]? = nil,
        sku: String,
        barcode: String,
        retailPrice: Double,
        wholesalePrice: Double?,
        costPrice: Double? = nil,
        quantity: Int,
        newImages: [UIImage] = [],
        retainedURLs: [String]? = nil,
        preferredPrimaryStagedImage: UIImage? = nil
    ) async -> Bool {
        guard !isSaving, !isCreatingVariant, !isDissolving, let currentDraft = draft else { return false }

        let maximumPrice = 999_999_999.99
        guard retailPrice.isFinite, retailPrice > 0, retailPrice <= maximumPrice,
              wholesalePrice == nil || (wholesalePrice!.isFinite && wholesalePrice! > 0 && wholesalePrice! <= maximumPrice),
              costPrice == nil || (costPrice!.isFinite && costPrice! >= 0 && costPrice! <= maximumPrice),
              quantity >= 0 else {
            failure = PPAccessoryVariantFailureState(message: Language.get("Variant_Add_InvalidPrice", alter: "أدخل سعر بيع صالحاً للمتغير."), recovery: .correctInput)
            return false
        }

        isSaving = true
        failure = nil
        confirmation = nil
        defer { isSaving = false }

        do {
            if !newImages.isEmpty {
                addImages(newImages, forProductId: productId)
                await saveMedia(forProductId: productId, color: color)
                guard failure == nil else { return false }
            }

            var updateFields: [String: Any] = [
                "price": retailPrice,
                "quantity": quantity
            ]
            if let wholesalePrice { updateFields["wholesalePrice"] = wholesalePrice }
            if let costPrice { updateFields["costPrice"] = costPrice }

            let success: Bool = try await withCheckedThrowingContinuation { continuation in
                PPProviderMarketplaceManager.shared().updateMarketItem(productId, fields: updateFields) { ok, msg, err in
                    if ok {
                        continuation.resume(returning: true)
                    } else if let err {
                        continuation.resume(throwing: err)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PPVariantStudio", code: -1, userInfo: [NSLocalizedDescriptionKey: msg ?? "Failed to update"]))
                    }
                }
            }
            guard success else { throw PPAccessoryVariantServiceError.invalidResponse }
            try await refreshCommittedCatalog(productId: productId)

            if let selectedOptions, let variant = draft?.variant(forProductId: productId) {
                var normalized: [String: String] = [:]
                for definition in currentDraft.optionDefinitions {
                    if definition.isColorOption {
                        normalized[definition.id] = color.identifier
                    } else if let value = selectedOptions[definition.id] ?? selectedOptions[definition.key] {
                        normalized[definition.id] = value
                    }
                }
                if !currentDraft.optionDefinitions.isEmpty {
                    variant.selectedOptions = normalized
                    variant.combinationKey = PPAccessoryVariantFamily.combinationKey(from: normalized)
                }
            }

            if isDirty {
                await save()
                guard failure == nil else { return false }
            } else if let familyId = currentDraft.familyId.isEmpty ? nil : currentDraft.familyId,
                      let reloaded = try? await PPAccessoryVariantService.shared.loadFamily(familyId: familyId) {
                apply(loaded: reloaded)
                try await publishCommittedRoot()
            }

            confirmation = Language.get("Variant_Studio_UpdateSuccess", alter: "تم حفظ وتحديث المتغير بنجاح.")
            return true
        } catch {
            failure = PPAccessoryVariantFailureState(error: error)
            return false
        }
    }

    private func clearPendingVariantCreation() {
        pendingVariantCreateCommandId = nil
        pendingVariantAttachCommandId = nil
        pendingVariantAttachDraft = nil
        pendingVariantCreationIntent = nil
        pendingCreatedVariantProduct = nil
    }

    public func revalidate() {
        draft?.autoBindMissingOptionSelections()
        var messages = draft?.validationMessages() ?? []
        if let message = draft?.identityChangeMessage(comparedTo: baseline) { messages.append(message) }
        var seen = Set<String>()
        validationMessages = messages.filter { seen.insert($0).inserted }
        if failure?.recovery == .correctInput { failure = nil }
        if isDirty { confirmation = nil }
    }

    public func discardChanges() {
        guard !isEditingLocked else { return }
        if let baseline {
            draft = baseline.copyForEditing()
            draft?.autoBindMissingOptionSelections()
        } else if let root = rootAccessory {
            let single = PPAccessoryVariantFamily.legacySingleVariant(from: root)
            apply(loaded: single)
        }
        validationMessages = []
        failure = nil
    }

    // MARK: - Save

    public func save() async {
        guard let workingDraft = pendingSaveDraft ?? draft else { return }
        if pendingSaveDraft == nil {
            workingDraft.autoBindMissingOptionSelections()
            revalidate()
            guard validationMessages.isEmpty else { return }
        }
        let draft = workingDraft.copyForEditing()

        isSaving = true
        failure = nil
        confirmation = nil
        defer { isSaving = false }

        let commandId = pendingCommandId ?? "variant-family-\(UUID().uuidString)"
        pendingCommandId = commandId
        pendingSaveDraft = draft

        do {
            let result = try await PPAccessoryVariantService.shared.saveFamily(draft, commandId: commandId)
            let reloaded = try await PPAccessoryVariantService.shared.loadFamily(familyId: result.familyId, minimumRevision: result.revision)
            apply(loaded: reloaded)
            try await publishCommittedRoot()
            pendingCommandId = nil
            pendingSaveDraft = nil
            failure = nil
            confirmation = result.idempotent
                ? Language.get("Variant_Save_AlreadyApplied", alter: "كانت هذه التغييرات محفوظة بالفعل.")
                : Language.get("Options_Save_Confirmed", alter: "تم حفظ خيارات ومتغيرات المنتج.")
        } catch {
            confirmation = nil
            let state = PPAccessoryVariantFailureState(error: error)
            if !state.allowsSameCommandRetry {
                pendingCommandId = nil
                pendingSaveDraft = nil
            }
            failure = state
            if !state.validationMessages.isEmpty { validationMessages = state.validationMessages }
        }
    }

    // MARK: - Revert to Normal Product

    @discardableResult
    public func revertToNormalProduct() async -> Bool {
        guard canManageVariants, !isEditingLocked else { return false }
        let familyId = (baseline?.familyId ?? draft?.familyId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !familyId.isEmpty {
            let retainedId = (rootAccessory?.accessoryID ?? (!selectedProductId.isEmpty ? selectedProductId : draft?.variants.first?.productId ?? "")).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !retainedId.isEmpty else { return false }

            isDissolving = true
            failure = nil
            confirmation = nil
            defer { isDissolving = false }

            do {
                try await PPAccessoryVariantService.shared.dissolveFamily(
                    familyId: familyId,
                    retainedProductId: retainedId,
                    deleteOtherVariants: true
                )

                if let reloaded = try? await PPAccessoryVariantService.shared.loadProduct(productId: retainedId) {
                    rootAccessory = reloaded
                    rootAccessoryRevision = max(rootAccessoryRevision, reloaded.revision)
                    onRootAccessoryUpdated?(reloaded)
                }

                if let root = rootAccessory {
                    let standalone = PPAccessoryVariantFamily.legacySingleVariant(from: root)
                    apply(loaded: standalone)
                }

                validationMessages = []
                confirmation = Language.get("Variant_RevertToNormal_Success", alter: "تم تحويل المنتج إلى صنف عادي وإلغاء المتغيرات بنجاح.")
                return true
            } catch {
                failure = PPAccessoryVariantFailureState(error: error)
                return false
            }
        } else {
            if let root = rootAccessory {
                let standalone = PPAccessoryVariantFamily.legacySingleVariant(from: root)
                apply(loaded: standalone)
            } else {
                discardChanges()
            }
            validationMessages = []
            failure = nil
            confirmation = Language.get("Variant_RevertToNormal_Success", alter: "تم تحويل المنتج إلى صنف عادي وإلغاء المتغيرات بنجاح.")
            return true
        }
    }
}

// MARK: - Section View (SwiftUI)

struct PPAccessoryVariantSection: View {
    @ObservedObject var model: PPAccessoryVariantSectionModel
    var onOpenVariantProduct: ((String) -> Void)?
    var onDidRevertToNormal: (() -> Void)? = nil
    var onRootAccessoryUpdated: ((PetAccessory) -> Void)? = nil

    enum VariantSectionTab: String, CaseIterable, Identifiable {
        case options
        case variants

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .options:
                return Language.get("Options_Tab_Options", alter: "الخيارات")
            case .variants:
                return Language.get("Options_Tab_Variants_Matrix", alter: "المصفوفة والمتغيرات")
            }
        }
    }

    @State private var selectedTab: VariantSectionTab = .options
    @State private var isPresentingRevertConfirmation = false

    init(model: PPAccessoryVariantSectionModel, onOpenVariantProduct: ((String) -> Void)? = nil, onDidRevertToNormal: (() -> Void)? = nil, onRootAccessoryUpdated: ((PetAccessory) -> Void)? = nil) {
        self.model = model
        self.onOpenVariantProduct = onOpenVariantProduct
        self.onDidRevertToNormal = onDidRevertToNormal
        self.onRootAccessoryUpdated = onRootAccessoryUpdated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isLoading {
                loadingState
            } else if model.isLegacyUngrouped {
                conversionInvitation
                    .disabled(model.isEditingLocked)
            } else if let draft = model.draft {
                studioHeaderDeck(for: draft)

                if selectedTab == .options {
                    PPAccessoryOptionEditorView(model: model, showHeader: false)
                        .disabled(model.isEditingLocked)
                } else {
                    PPAccessoryVariantMatrixView(
                        model: model,
                        onOpenVariantProduct: onOpenVariantProduct
                    )
                    .disabled(model.isEditingLocked)
                }
            }

            if !model.validationMessages.isEmpty {
                validationList
            }
            if let failure = model.failure {
                failureBanner(failure)
            }
            if let confirmation = model.confirmation {
                confirmationBanner(confirmation)
            }
            if model.isDirty {
                saveDock
            }
            if !model.isLegacyUngrouped && model.canManageVariants {
                revertToNormalButton
                    .padding(.top, 4)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .confirmationDialog(
            Language.get("Variant_RevertToNormal_Action", alter: "إلغاء المتغيرات والتحويل لمنتج عادي"),
            isPresented: $isPresentingRevertConfirmation,
            titleVisibility: .visible
        ) {
            Button(Language.get("Variant_RevertToNormal_Action", alter: "إلغاء المتغيرات والتحويل لمنتج عادي"), role: .destructive) {
                Task {
                    let success = await model.revertToNormalProduct()
                    if success { onDidRevertToNormal?() }
                }
            }
            Button(Language.get("Cancel", alter: "إلغاء"), role: .cancel) {}
        } message: {
            Text(Language.get(
                "Variant_RevertToNormal_Confirm_Desc",
                alter: "هل أنت متأكد من رغبتك في إلغاء مجموعة المتغيرات؟ سيتم الاحتفاظ بهذا المنتج كصنف عادي مستقل وحذف باقي المتغيرات التابعة له."
            ))
        }
    }

    // MARK: - Subviews

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AdminSurface.primary)
            Text(Language.get("Variant_Studio_Loading", alter: "جارٍ تحميل خيارات المنتج..."))
                .font(AdminType.body)
                .foregroundStyle(AdminSurface.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }

    private var conversionInvitation: some View {
        AdminCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AdminSurface.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.get("Variant_Invitation_Title", alter: "إضافة خيارات ومقاسات للمنتج"))
                            .font(AdminType.headlineBold)
                            .foregroundStyle(AdminSurface.primaryText)

                        Text(Language.get("Variant_Invitation_Subtitle", alter: "يتوفر هذا المنتج كصنف مفرد. يمكنك تحويله إلى مجموعة متعددة الخيارات (مقاسات، أوزان، ألوان، نكهات)."))
                            .font(AdminType.caption)
                            .foregroundStyle(AdminSurface.secondaryText)
                    }
                }

                Divider().overlay(AdminSurface.hairline)

                Text(Language.get("Variant_Invitation_PresetsTitle", alter: "اختر نوع الخيار لبدء التوليد:"))
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminSurface.primaryText)

                let presets = PPAccessoryOptionDefinition.standardPresets()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(presets) { preset in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                model.convertWithPresetOption(preset)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: preset.systemIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AdminSurface.primary)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(preset.localizedName)
                                        .font(AdminType.subheadlineBold)
                                        .foregroundStyle(AdminSurface.primaryText)
                                    Text("\(preset.values.count) \(Language.get("Variant_ValuesCount", alter: "قيم"))")
                                        .font(AdminType.caption2)
                                        .foregroundStyle(AdminSurface.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                                    .fill(AdminSurface.control)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                                    .strokeBorder(AdminSurface.hairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AdminSpacing.cardPadding)
        }
    }

    private func studioHeaderDeck(for draft: PPAccessoryVariantFamily) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(VariantSectionTab.allCases) { tab in
                    let isSelected = (selectedTab == tab)
                    Button {
                        guard selectedTab != tab else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .options ? "slider.horizontal.3" : "tablecells.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isSelected ? AdminSurface.primary : AdminSurface.secondaryText)

                            Text(tab.localizedTitle)
                                .font(isSelected ? AdminType.headlineBold : AdminType.headline)
                                .foregroundStyle(isSelected ? AdminSurface.primaryText : AdminSurface.secondaryText)

                            let count = (tab == .options ? draft.optionDefinitions.count : draft.variants.count)
                            Text("\(count)")
                                .font(AdminType.captionBold)
                                .foregroundStyle(isSelected ? AdminSurface.primary : AdminSurface.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(isSelected ? AdminSurface.primary.opacity(0.12) : AdminSurface.control)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                                .fill(isSelected ? AdminSurface.surface : Color.clear)
                                .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .fill(AdminSurface.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                    .strokeBorder(AdminSurface.hairline, lineWidth: 1)
            )
        }
    }

    private var validationList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.validationMessages, id: \.self) { message in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AdminSurface.amber)
                    Text(message)
                        .font(AdminType.footnote)
                        .foregroundStyle(AdminSurface.primaryText)
                }
            }
        }
        .padding(AdminSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                .fill(AdminSurface.amber.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AdminRadius.medium, style: .continuous)
                .strokeBorder(AdminSurface.amber.opacity(0.25), lineWidth: 1)
        )
    }

    private func failureBanner(_ failure: PPAccessoryVariantFailureState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: failure.iconName)
                .foregroundStyle(failure.tint)
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text(failure.message)
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminSurface.primaryText)
            }

            Spacer()

            if let action = failure.actionTitle {
                Button(action) {
                    Task {
                        if failure.recovery == .retrySameCommand {
                            await model.save()
                        } else if failure.recovery == .reloadAndCompare {
                            await model.reload()
                        }
                    }
                }
                .font(AdminType.captionBold)
                .foregroundStyle(failure.tint)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                .fill(failure.tint.opacity(0.1))
        )
    }

    private func confirmationBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AdminSurface.emerald)
                .font(.system(size: 16, weight: .bold))

            Text(message)
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminSurface.primaryText)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                .fill(AdminSurface.emerald.opacity(0.1))
        )
    }

    private var saveDock: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring()) {
                    model.discardChanges()
                }
            } label: {
                Text(Language.get("Common_Discard", alter: "تراجع"))
                    .font(AdminType.subheadlineBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                            .fill(AdminSurface.control)
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.isEditingLocked)

            Button {
                Task {
                    await model.save()
                }
            } label: {
                HStack(spacing: 6) {
                    if model.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(Language.get("Common_Save", alter: "حفظ التغييرات"))
                        .font(AdminType.subheadlineBold)
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                        .fill(AdminSurface.primary)
                )
            }
            .buttonStyle(.plain)
            .disabled(model.isEditingLocked || !model.validationMessages.isEmpty)
        }
        .padding(.top, 8)
    }

    private var revertToNormalButton: some View {
        Button {
            isPresentingRevertConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(AdminSurface.crimson)
                Text(Language.get("Variant_RevertToNormal_Action", alter: "إلغاء المتغيرات والتحويل لمنتج عادي"))
                    .font(AdminType.subheadlineBold)
                    .foregroundStyle(AdminSurface.crimson)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AdminRadius.small, style: .continuous)
                    .fill(AdminSurface.crimson.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(model.isEditingLocked)
    }
}

// MARK: - UIKit Host Controller for Presentation

@objc public final class PPAccessoryVariantStudioHostController: UIViewController {
    private let model = PPAccessoryVariantSectionModel()
    private var hostingController: UIViewController?
    private var onSavedHandler: ((PetAccessory) -> Void)?

    @objc public init(accessory: PetAccessory) {
        super.init(nibName: nil, bundle: nil)
        Task { [weak self] in
            await self?.model.load(for: accessory)
        }
    }

    @objc public init(marketItem: PPProviderMarketItem) {
        super.init(nibName: nil, bundle: nil)
        Task { [weak self] in
            await self?.model.load(for: marketItem)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc public var onSaved: ((PetAccessory) -> Void)? {
        get { onSavedHandler }
        set {
            onSavedHandler = newValue
            model.onRootAccessoryUpdated = newValue
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true
        navigationController?.isModalInPresentation = true
        view.backgroundColor = .ppBackground
        title = Language.get("Variant_Studio_Title", alter: "خيارات المنتج والمصفوفة")

        let closeItem = UIBarButtonItem(
            title: Language.get("Common_Done", alter: "تم"),
            style: .done,
            target: self,
            action: #selector(handleDone)
        )
        closeItem.tintColor = .ppPrimary
        navigationItem.rightBarButtonItem = closeItem

        let sectionView = PPAccessoryVariantSection(
            model: model,
            onDidRevertToNormal: { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            },
            onRootAccessoryUpdated: { [weak self] acc in
                self?.onSavedHandler?(acc)
            }
        )

        let scrollWrapper = ScrollView {
            sectionView
                .padding(.horizontal, AdminSpacing.screenMargin)
                .padding(.vertical, 16)
        }

        let host = UIHostingController(rootView: scrollWrapper)
        hostingController = host
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    @objc private func handleDone() {
        guard !model.isEditingLocked, !model.isSavingMedia else { return }
        let hasMediaDraft = model.stagedImages.values.contains { !$0.isEmpty }
        guard model.isDirty || hasMediaDraft else {
            dismiss(animated: true, completion: nil)
            return
        }
        PPAlertHelper.showConfirmation(
            in: self,
            title: Language.get("ProInventory_DiscardTitle", alter: "تجاهل التغييرات غير المحفوظة؟"),
            subtitle: Language
                .isRTL() ? "لديك تعديلات غير محفوظة، هل أنت متأكد من الإلغاء؟" : "You have unsaved changes. Are you sure you want to discard them?",
            confirmButton: Language.get("Discard", alter: "تجاهل"),
            cancelButton: Language.get("Cancel", alter: "إلغاء"),
            icon: UIImage(systemName: "exclamationmark.triangle.fill"),
            confirmBlock: { [weak self] _, _ in
                self?.dismiss(animated: true, completion: nil)
            },
            cancelBlock: nil
        )
    }
}

// MARK: - Variant Studio Sheet (Category-Defining Studio)

enum VariantStudioMode: Identifiable {
    case create
    case edit(PPAccessoryVariant)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let v): return "edit-\(v.productId)"
        }
    }

    var isEdit: Bool {
        switch self {
        case .create: return false
        case .edit: return true
        }
    }

    var navigationTitle: String {
        switch self {
        case .create:
            return Language.get("Variant_Studio_CreateTitle", alter: "إضافة لون جديد")
        case .edit(let v):
            return String(format: Language.get("Variant_Studio_EditTitle", alter: "استوديو اللون: %@"), v.color.localizedName)
        }
    }
}

struct PPAccessoryVariantStudioSheet: View {
    let mode: VariantStudioMode
    let usedColorIdentifiers: Set<String>
    let isSubmitting: Bool
    let existingStagedImages: [UIImage]
    let existingVariants: [PPAccessoryVariant]
    let onCreate: (PPAccessoryVariantColor, [String: String], String, String, Double, Double?, Double?, Int, [UIImage]) async -> Bool
    let onUpdate: (String, PPAccessoryVariantColor, [String: String], String, String, Double, Double?, Double?, Int, [UIImage], [String]?, UIImage?) async -> Bool
    var onOpenFullRecord: ((String) -> Void)? = nil
    var errorMessage: (() -> String?)? = nil
    var optionDefinitions: [PPAccessoryOptionDefinition] = []
    var canViewCosts: Bool = false
    var hasPendingSave: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private enum StudioField: Hashable { case retail, cost, wholesale, barcode, sku }
    @FocusState private var focusedField: StudioField?
    @State private var initialFingerprint: String?
    @State private var showsDiscardConfirmation = false
    @State private var pendingRecordID: String?
    @State private var preferredPrimaryStagedImage: UIImage?

    @State private var color: PPAccessoryVariantColor
    @State private var selectedOptions: [String: String]
    @State private var sku: String
    @State private var barcode: String
    @State private var retailPriceText: String
    @State private var costPriceText: String
    @State private var wholesaleEnabled: Bool
    @State private var wholesalePriceText: String
    @State private var quantity: Int
    @State private var stagedImages: [UIImage] = []
    @State private var retainedRemoteURLs: [String] = []
    @State private var previewMedia: PPLivePetPreviewMedia?

    @State private var isChoosingColorFullStudio = false
    @State private var isPresentingImagePicker = false
    @State private var showStudioPhotoSourceDialog = false
    @State private var showStudioCameraPicker = false
    @State private var showStudioCameraAccessAlert = false
    @State private var studioCameraAlertMessage = ""

    private func requestStudioCamera() {
        PPCameraPermissionHelper.requestCameraAccess(
            onAuthorized: {
                showStudioCameraPicker = true
            },
            onDenied: { msg in
                studioCameraAlertMessage = msg
                showStudioCameraAccessAlert = true
            }
        )
    }
    @State private var localFailure: String?
    @State private var localSubmitting = false
    @State private var isHexCopied = false
    @State private var showsColorTools = false
    @State private var copiedField: StudioField?

    private let presetColors: [PPAccessoryVariantColor] = PPAccessoryVariantColorLibrary.entries

    init(
        mode: VariantStudioMode,
        usedColorIdentifiers: Set<String>,
        isSubmitting: Bool,
        existingStagedImages: [UIImage] = [],
        existingRetainedURLs: [String]? = nil,
        existingVariants: [PPAccessoryVariant] = [],
        onCreate: @escaping (PPAccessoryVariantColor, [String: String], String, String, Double, Double?, Double?, Int, [UIImage]) async -> Bool,
        onUpdate: @escaping (String, PPAccessoryVariantColor, [String: String], String, String, Double, Double?, Double?, Int, [UIImage], [String]?, UIImage?) async -> Bool,
        onOpenFullRecord: ((String) -> Void)? = nil,
        errorMessage: (() -> String?)? = nil,
        optionDefinitions: [PPAccessoryOptionDefinition] = [],
        canViewCosts: Bool = false,
        hasPendingSave: Bool = false
    ) {
        self.mode = mode
        self.usedColorIdentifiers = usedColorIdentifiers
        self.isSubmitting = isSubmitting
        self.existingStagedImages = existingStagedImages
        self.existingVariants = existingVariants
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onOpenFullRecord = onOpenFullRecord
        self.errorMessage = errorMessage
        self.optionDefinitions = optionDefinitions
        self.canViewCosts = canViewCosts
        self.hasPendingSave = hasPendingSave

        var initialOptions: [String: String] = [:]
        switch mode {
        case .create:
            let defaultColor = PPAccessoryVariantColorLibrary.entries.first
                ?? PPAccessoryVariantColor(identifier: "black", nameAr: "أسود", nameEn: "Black", hex: "#111111")
            _color = State(initialValue: defaultColor)
            _sku = State(initialValue: "")
            _barcode = State(initialValue: "")
            _retailPriceText = State(initialValue: "")
            _costPriceText = State(initialValue: "")
            _wholesaleEnabled = State(initialValue: false)
            _wholesalePriceText = State(initialValue: "")
            _quantity = State(initialValue: 0)
            _stagedImages = State(initialValue: [])
            _retainedRemoteURLs = State(initialValue: [])
            for def in optionDefinitions where !def.isColorOption && !def.values.isEmpty {
                if let first = def.values.first {
                    initialOptions[def.id] = first.id
                    initialOptions[def.key] = first.id
                }
            }
            _selectedOptions = State(initialValue: initialOptions)
        case .edit(let variant):
            _color = State(initialValue: variant.color)
            _sku = State(initialValue: variant.sku)
            _barcode = State(initialValue: variant.barcode)
            let retailVal = variant.retailPrice?.doubleValue ?? 0
            _retailPriceText = State(initialValue: retailVal > 0 ? String(format: "%.2f", retailVal).replacingOccurrences(of: ".00", with: "") : "")
            let costVal = canViewCosts ? variant.costPrice?.doubleValue : nil
            _costPriceText = State(initialValue: costVal.map { String(format: "%.2f", $0).replacingOccurrences(of: ".00", with: "") } ?? "")
            let wholesaleVal = variant.wholesalePrice?.doubleValue ?? 0
            _wholesaleEnabled = State(initialValue: wholesaleVal > 0)
            _wholesalePriceText = State(initialValue: wholesaleVal > 0 ? String(format: "%.2f", wholesaleVal).replacingOccurrences(of: ".00", with: "") : "")
            _quantity = State(initialValue: max(0, variant.quantity))
            _stagedImages = State(initialValue: existingStagedImages)
            let urls = existingRetainedURLs ?? variant.media.map(\.remoteURL).filter { !$0.isEmpty }
            _retainedRemoteURLs = State(initialValue: urls)
            initialOptions = variant.selectedOptions
            for def in optionDefinitions where !def.isColorOption && !def.values.isEmpty {
                let current = initialOptions[def.id] ?? initialOptions[def.key]
                if current == nil || current!.isEmpty {
                    if let first = def.values.first {
                        initialOptions[def.id] = first.id
                        initialOptions[def.key] = first.id
                    }
                }
            }
            _selectedOptions = State(initialValue: initialOptions)
        }
    }

    private func parsedAmount(_ text: String) -> Double? {
        let normalized = text.normalizedEnglishDigits
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.range(of: "^(?:[0-9]+(?:\\.[0-9]{0,2})?|\\.[0-9]{1,2})$", options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite,
              value >= 0, value <= 999_999_999.99 else { return nil }
        return value
    }
    private var retailPrice: Double? { parsedAmount(retailPriceText) }
    private var costPrice: Double? { canViewCosts ? parsedAmount(costPriceText) : nil }
    private var wholesalePrice: Double? { wholesaleEnabled ? parsedAmount(wholesalePriceText) : nil }

    private var hasGenericOptions: Bool {
        !optionDefinitions.filter { !$0.isColorOption && !$0.values.isEmpty }.isEmpty
    }

    private func canonicalCombination(_ options: [String: String], colorID: String) -> String {
        var canonical: [String: String] = [:]
        for definition in optionDefinitions where !definition.values.isEmpty {
            if definition.isColorOption { canonical[definition.id] = colorID }
            else if let value = options[definition.id] ?? options[definition.key] { canonical[definition.id] = value }
        }
        return PPAccessoryVariantFamily.combinationKey(from: canonical)
    }
    private var combinationConflictMessage: String? {
        guard hasGenericOptions else { return nil }
        let key = canonicalCombination(selectedOptions, colorID: color.identifier)
        for variant in existingVariants {
            if case .edit(let current) = mode, variant.productId == current.productId { continue }
            if canonicalCombination(variant.selectedOptions, colorID: variant.color.identifier) == key {
                return Language.get("Variant_Error_CombinationTaken", alter: "هذه التوليفة مستخدمة بالفعل في هذا المنتج.")
            }
        }
        return nil
    }

    private var barcodeConflictMessage: String? {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        for v in existingVariants {
            if case .edit(let current) = mode, v.productId == current.productId { continue }
            if v.barcode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == clean {
                let colorName = v.color.localizedName
                let base = Language.get("Variant_Error_DuplicateBarcodeServer", alter: "الباركود مستخدم بلون آخر. لكل لون باركود خاص.")
                return "\(base) (\(colorName))"
            }
        }
        return nil
    }

    private var skuConflictMessage: String? {
        let clean = sku.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        for v in existingVariants {
            if case .edit(let current) = mode, v.productId == current.productId { continue }
            if v.sku.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == clean {
                let colorName = v.color.localizedName
                let base = Language.get("Variant_Error_DuplicateSkuServer", alter: "رمز SKU مستخدم بلون آخر. لكل لون رمز خاص.")
                return "\(base) (\(colorName))"
            }
        }
        return nil
    }

    private struct SubmitIssue {
        let message: String
        let sectionID: String
        var field: StudioField? = nil
    }

    /// The same issue both disables Save and tells the operator how to unblock it.
    private var submitIssue: SubmitIssue? {
        if hasGenericOptions, combinationConflictMessage != nil {
            return SubmitIssue(
                message: Language.get("Variant_Studio_CombinationGuidance", alter: "هذه التوليفة مستخدمة بالفعل. غيّر أحد الخيارات، أو أغلق هذا المحرر وافتح المتغير الموجود لتعديله."),
                sectionID: "studio.identity"
            )
        }
        if !hasGenericOptions, usedColorIdentifiers.contains(color.identifier), color.identifier != originalColorID {
            return SubmitIssue(
                message: Language.get("Variant_Studio_ColorGuidance", alter: "هذا اللون مستخدم بالفعل. اختر لونًا آخر من تغيير اللون، أو أغلق هذا المحرر وافتح اللون الموجود لتعديله."),
                sectionID: "studio.identity"
            )
        }
        if barcodeConflictMessage != nil {
            return SubmitIssue(
                message: Language.get("Variant_Studio_BarcodeGuidance", alter: "الباركود مستخدم لمتغير آخر. أدخل باركودًا مختلفًا أو اضغط توليد باركود PP، ثم احفظ."),
                sectionID: "studio.identifiers", field: .barcode
            )
        }
        if skuConflictMessage != nil {
            return SubmitIssue(
                message: Language.get("Variant_Studio_SKUGuidance", alter: "رمز المنتج مستخدم لمتغير آخر. أدخل رمزًا مختلفًا أو اضغط توليد SKU، ثم احفظ."),
                sectionID: "studio.identifiers", field: .sku
            )
        }
        guard let retailPrice, retailPrice.isFinite, retailPrice > 0 else {
            return SubmitIssue(
                message: Language.get("Variant_Studio_RetailGuidance", alter: "أدخل سعر البيع أكبر من صفر وحتى 999,999,999.99 ر.ق، بمنزلتين عشريتين كحد أقصى، ثم احفظ."),
                sectionID: "studio.pricing", field: .retail
            )
        }
        if canViewCosts, !costPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, costPrice == nil {
            return SubmitIssue(
                message: Language.get("Variant_Studio_CostGuidance", alter: "أدخل تكلفة من صفر حتى 999,999,999.99 ر.ق، بمنزلتين عشريتين كحد أقصى، أو اترك حقل التكلفة الاختياري فارغًا، ثم احفظ."),
                sectionID: "studio.pricing", field: .cost
            )
        }
        if wholesaleEnabled {
            guard let wholesalePrice, wholesalePrice.isFinite, wholesalePrice > 0 else {
                return SubmitIssue(
                    message: Language.get("Variant_Studio_WholesaleGuidance", alter: "أدخل سعر الجملة أكبر من صفر وحتى 999,999,999.99 ر.ق، بمنزلتين عشريتين كحد أقصى، أو أوقف سعر جملة مستقل، ثم احفظ."),
                    sectionID: "studio.pricing", field: .wholesale
                )
            }
        }
        return nil
    }

    private var canSubmit: Bool { !busy && submitIssue == nil }

    private var busy: Bool { localSubmitting || isSubmitting }
    private var studioMotion: Animation? { AdminAnimation.motion(AdminAnimation.standard, reduceMotion: reduceMotion) }
    private var adaptiveRow: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }
    private var originalColorID: String? {
        if case .edit(let variant) = mode { return variant.color.identifier }
        return nil
    }
    private var draftFingerprint: String {
        var values = [color.identifier, color.nameAr, color.nameEn, color.hex, sku, barcode,
                      retailPriceText, costPriceText, wholesalePriceText, String(wholesaleEnabled), String(quantity)]
        values.append(contentsOf: selectedOptions.keys.sorted().map { "\($0)=\(selectedOptions[$0] ?? "")" })
        values.append(contentsOf: retainedRemoteURLs)
        values.append(contentsOf: stagedImages.map { String(describing: ObjectIdentifier($0)) })
        values.append(preferredPrimaryStagedImage.map { String(describing: ObjectIdentifier($0)) } ?? "")
        return values.joined(separator: "\u{1F}")
    }
    private var hasUnsavedChanges: Bool { initialFingerprint.map { $0 != draftFingerprint } ?? false }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let localFailure { failureBanner(localFailure).id("studio.failure") }
                        if hasPendingSave {
                            Text(Language.get("Variant_Studio_PendingHint", alter: "لم يكتمل تأكيد الحفظ. أعد المحاولة بنفس التعديلات لإكمال العملية بأمان."))
                                .font(AdminType.footnote)
                                .foregroundStyle(AdminCommandInk.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            chromaticAtelierCard
                            genericOptionsCard
                        }.modifier(PPVariantStudioPanel()).id("studio.identity")
                        photosAtelierCard.modifier(PPVariantStudioPanel())
                        stockQuantityDialCard.modifier(PPVariantStudioPanel())
                        commercePricingCard.modifier(PPVariantStudioPanel()).id("studio.pricing")
                        identifiersCard.modifier(PPVariantStudioPanel()).id("studio.identifiers")
                        if mode.isEdit, let onOpenFullRecord, case .edit(let variant) = mode {
                            deepLinkRecordButton(variant: variant, action: onOpenFullRecord)
                        }
                        safetyNoteCard
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .disabled(busy || hasPendingSave)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: localFailure) { _, failure in
                    guard let failure else { return }
                    withAnimation(studioMotion) { proxy.scrollTo("studio.failure", anchor: .top) }
                    UIAccessibility.post(notification: .announcement, argument: failure)
                }
                .background(AdminSurface.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom, spacing: 0) { studioSaveDock(proxy: proxy) }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(Language.get("Variant_Studio_Workspace", alter: "تحرير المتغير"))
                            .font(AdminType.headlineBold)
                            .foregroundStyle(AdminSurface.primaryText)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Language.get("Cancel", alter: "إلغاء")) {
                            focusedField = nil
                            if hasUnsavedChanges { showsDiscardConfirmation = true } else { dismiss() }
                        }
                        .font(AdminType.callout)
                        .foregroundStyle(AdminCommandInk.secondary)
                        .disabled(busy || hasPendingSave)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(Language.get("Done", alter: "تم")) { focusedField = nil }
                    }
                }
            }
        }
        .tint(AdminSurface.primary)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .interactiveDismissDisabled(busy || hasPendingSave || hasUnsavedChanges)
        .onAppear {
            PPBrandFont.registerIfNeeded()
            if initialFingerprint == nil { initialFingerprint = draftFingerprint }
        }
        .confirmationDialog(Language.get("Variant_Studio_DiscardTitle", alter: "تجاهل التعديلات؟"),
                            isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
            Button(Language.get("Discard", alter: "تجاهل"), role: .destructive) {
                dismiss()
                if let pendingRecordID { onOpenFullRecord?(pendingRecordID) }
            }
            Button(Language.get("Variant_Studio_KeepEditing", alter: "متابعة التعديل"), role: .cancel) { pendingRecordID = nil }
        }
        .sheet(isPresented: $isChoosingColorFullStudio) {
            PPAccessoryVariantColorEditorSheet(
                initialColor: color,
                usedIdentifiers: hasGenericOptions ? [] : usedColorIdentifiers,
                excludingIdentifier: originalColorID
            ) { chosen in
                color = chosen
                isChoosingColorFullStudio = false
            }
        }
        .confirmationDialog(
            Language.get("Inventory_PhotoSource_Title", alter: "إضافة صور"),
            isPresented: $showStudioPhotoSourceDialog,
            titleVisibility: .visible
        ) {
            Button(Language.get("Inventory_PhotoSource_Camera", alter: "التقاط بالكاميرا")) {
                requestStudioCamera()
            }
            Button(Language.get("Inventory_PhotoSource_Library", alter: "اختيار من مكتبة الصور")) {
                isPresentingImagePicker = true
            }
            Button(Language.get("Cancel", alter: "إلغاء"), role: .cancel) {}
        } message: {
            Text(Language.get("Inventory_PhotoSource_Message", alter: "اختر التقاط صورة جديدة بالكاميرا أو اختيار صور من المكتبة."))
        }
        .fullScreenCover(isPresented: $showStudioCameraPicker) {
            PPLivePetCameraPicker { image in
                withAnimation(studioMotion) {
                    if stagedImages.count < remainingImageSlots {
                        stagedImages.append(image)
                    }
                }
            }
        }
        .alert(
            Language.get("Inventory_CameraPermission_Title", alter: "السماح باستخدام الكاميرا"),
            isPresented: $showStudioCameraAccessAlert
        ) {
            Button(Language.get("LivePetIntake_OpenSettings", alter: "فتح الإعدادات")) {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            Button(Language.get("Cancel", alter: "إلغاء"), role: .cancel) {}
        } message: {
            Text(studioCameraAlertMessage.isEmpty ? Language.get("Inventory_CameraPermission_Message", alter: "يحتاج التطبيق إذن الوصول للكاميرا لالتقاط الصور. يمكنك تفعيل الإذن من إعدادات الجهاز.") : studioCameraAlertMessage)
        }
        .sheet(isPresented: $isPresentingImagePicker) {
            PPVariantImagePickerSheet(maxSelection: max(1, remainingImageSlots)) { picked in
                withAnimation(studioMotion) { stagedImages.append(contentsOf: picked.prefix(remainingImageSlots)) }
                isPresentingImagePicker = false
            }
        }
        .fullScreenCover(item: $previewMedia) { media in PPLivePetMediaPreview(media: media) }
    }

    private var studioRule: some View {
        Rectangle().fill(AdminSurface.hairline).frame(height: AdminStroke.hairline).accessibilityHidden(true)
    }

    private func sectionHeading(_ title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AdminSurface.primary)
                .frame(width: 34, height: 34)
                .background(AdminSurface.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(title).font(AdminType.headlineBold).foregroundStyle(AdminSurface.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Identity and options

    private var meaningfulColor: Bool {
        !hasGenericOptions || optionDefinitions.contains(where: \.isColorOption)
    }
    private var optionIdentity: String {
        let names = optionDefinitions.filter { !$0.isColorOption }.compactMap { definition in
            definition.values.first(where: { $0.id == (selectedOptions[definition.id] ?? selectedOptions[definition.key]) })?.localizedName
        }
        return names.isEmpty ? color.localizedName : names.joined(separator: " · ")
    }
    @ViewBuilder private var identitySpecimen: some View {
        if !meaningfulColor, let first = retainedRemoteURLs.first, let url = URL(string: first) {
            AdminRemoteImage(url: url, contentMode: .fit) { Image(systemName: "shippingbox") }
                .frame(width: 72, height: 84)
                .background(AdminSurface.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AdminSurface.primaryText.opacity(0.10)))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.uiColorValue)
                .frame(width: 62, height: 72)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AdminSurface.primaryText.opacity(0.18)))
                .accessibilityHidden(true)
        }
    }

    private var chromaticAtelierCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                identitySpecimen
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.isEdit
                         ? Language.get("Variant_Studio_Editing", alter: "تعديل هذا المتغير")
                         : Language.get("Variant_Studio_Creating", alter: "متغير جديد"))
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminCommandInk.secondary)
                    Text(meaningfulColor ? color.localizedName : optionIdentity)
                        .font(AdminType.title2)
                        .foregroundStyle(AdminSurface.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    let alternate = Language.isRTL() ? color.nameEn : color.nameAr
                    if meaningfulColor && !alternate.isEmpty {
                        Text(alternate).font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
                            .environment(\.layoutDirection, Language.isRTL() ? .leftToRight : .rightToLeft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !meaningfulColor {
                Button {
                    withAnimation(studioMotion) { showsColorTools.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(color.uiColorValue).frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(AdminSurface.primaryText.opacity(0.2)))
                        Text(Language.get("Variant_Action_EditColor", alter: "تغيير اللون")).font(AdminType.footnoteBold)
                        Spacer()
                        Image(systemName: showsColorTools ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold))
                    }.foregroundStyle(AdminCommandInk.secondary).frame(minHeight: 44)
                }.buttonStyle(PPVariantStudioPressStyle())
            }
            if meaningfulColor || showsColorTools {
            adaptiveRow {
                Button {
                    UIPasteboard.general.string = color.hex
                    UISelectionFeedbackGenerator().selectionChanged()
                    isHexCopied = true
                } label: {
                    Label(isHexCopied ? Language.get("Variant_Hex_Copied", alter: "تم النسخ") : color.hex,
                          systemImage: isHexCopied ? "checkmark" : "doc.on.doc")
                        .font(AdminType.footnoteBold)
                        .foregroundStyle(AdminCommandInk.secondary)
                        .frame(minHeight: 44)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .buttonStyle(PPVariantStudioPressStyle())
                .onChange(of: color.hex) { _, _ in isHexCopied = false }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button { isChoosingColorFullStudio = true } label: {
                    Label(Language.get("Variant_Action_EditColor", alter: "تغيير اللون"), systemImage: "slider.horizontal.3")
                        .font(AdminType.footnoteBold)
                        .frame(minHeight: 44)
                }
                .buttonStyle(PPVariantStudioPressStyle())
                .foregroundStyle(AdminSurface.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.identifier) { preset in
                        let selected = color.identifier == preset.identifier
                        let unavailable = !hasGenericOptions && usedColorIdentifiers.contains(preset.identifier)
                            && preset.identifier != originalColorID
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(studioMotion) { color = preset }
                        } label: {
                            ZStack {
                                Circle().fill(preset.uiColorValue).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(AdminSurface.primaryText.opacity(0.2), lineWidth: 1))
                                if selected || unavailable {
                                    Image(systemName: selected ? "checkmark" : "lock.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(preset.uiColor.isDarkTone ? Color.white : Color.black)
                                }
                            }
                            .frame(width: 46, height: 46)
                            .overlay(Circle().strokeBorder(selected ? AdminSurface.primary : .clear, lineWidth: 2))
                            .opacity(unavailable && !selected ? 0.4 : 1)
                            .contentShape(Circle())
                        }
                        .buttonStyle(PPVariantStudioPressStyle())
                        .disabled(unavailable)
                        .accessibilityLabel(preset.accessibilityName)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }.padding(.vertical, 2)
            }
            }
        }
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder private var genericOptionsCard: some View {
        let definitions = optionDefinitions.filter { !$0.isColorOption && !$0.values.isEmpty }
        if !definitions.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(definitions, id: \.id) { definition in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(definition.localizedName).font(AdminType.footnoteBold).foregroundStyle(AdminCommandInk.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(definition.values, id: \.id) { value in
                                    let selected = (selectedOptions[definition.id] ?? selectedOptions[definition.key]) == value.id
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation(studioMotion) {
                                            selectedOptions[definition.id] = value.id
                                            selectedOptions[definition.key] = value.id
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            if selected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                                            Text(value.localizedName).font(AdminType.footnoteBold)
                                        }
                                        .padding(.horizontal, 14).frame(minHeight: 44)
                                        .foregroundStyle(selected ? Color.white : AdminSurface.primaryText)
                                        .background(selected ? AdminSurface.primary : AdminSurface.primaryText.opacity(0.045), in: Capsule())
                                        .overlay(Capsule().strokeBorder(selected ? AdminSurface.primary : AdminSurface.primaryText.opacity(0.14), lineWidth: 1))
                                    }
                                    .buttonStyle(PPVariantStudioPressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
                        }
                    }
                }
                if let message = combinationConflictMessage { failureBanner(message) }
            }
        }
    }

    // MARK: Photos

    private var remainingImageSlots: Int {
        max(0, PPAccessoryVariantMediaService.maxImagesPerVariant - retainedRemoteURLs.count - stagedImages.count)
    }

    private var photosAtelierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            adaptiveRow {
                sectionHeading(Language.get("Variant_Studio_Photos_Heading", alter: "صور المتغير"), symbol: "photo.on.rectangle.angled")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text("\(retainedRemoteURLs.count + stagedImages.count) / \(PPAccessoryVariantMediaService.maxImagesPerVariant)")
                    .font(AdminType.captionBold).foregroundStyle(AdminCommandInk.secondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Text(Language.get("Variant_Studio_PhotoHint", alter: "الصورة الرئيسية تظهر أولاً. اضغط على النجمة لتغييرها."))
                .font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(retainedRemoteURLs.enumerated()), id: \.element) { index, url in
                        mediaTile(primary: index == 0 && preferredPrimaryStagedImage == nil,
                                  preview: {
                            if let parsed = URL(string: url) { previewMedia = PPLivePetPreviewMedia(source: .remote(parsed)) }
                        }, promote: { promoteRemoteImageToPrimary(at: index) }, remove: {
                            guard retainedRemoteURLs.indices.contains(index) else { return }
                            withAnimation(studioMotion) { retainedRemoteURLs.remove(at: index) }
                        }) {
                            AdminRemoteImage(url: URL(string: url), contentMode: .fit) {
                                Image(systemName: "photo").foregroundStyle(AdminCommandInk.tertiary)
                            }
                        }
                        .accessibilityLabel(String(format: Language.get("Variant_Media_Preview_Format", alter: "معاينة الصورة رقم %ld"), index + 1))
                    }
                    ForEach(Array(stagedImages.enumerated()), id: \.offset) { index, image in
                        let primary = preferredPrimaryStagedImage.map { $0 === image }
                            ?? (retainedRemoteURLs.isEmpty && index == 0)
                        mediaTile(primary: primary,
                                  preview: { previewMedia = PPLivePetPreviewMedia(source: .local(image)) },
                                  promote: { promoteStagedImageToPrimary(at: index) }, remove: {
                            guard stagedImages.indices.contains(index) else { return }
                            if preferredPrimaryStagedImage === image { preferredPrimaryStagedImage = nil }
                            withAnimation(studioMotion) { stagedImages.remove(at: index) }
                        }) {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                    if remainingImageSlots > 0 {
                        Button { showStudioPhotoSourceDialog = true } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "plus").font(.system(size: 25, weight: .light))
                                Text(Language.get("Variant_Studio_Photos_Add", alter: "إضافة صور"))
                                    .font(AdminType.footnoteBold).multilineTextAlignment(.center)
                            }
                            .foregroundStyle(AdminSurface.primary)
                            .frame(width: 112, height: 150)
                            .background(AdminSurface.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AdminSurface.primary.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                        }.buttonStyle(PPVariantStudioPressStyle())
                    }
                }.padding(.vertical, 2)
            }
        }
    }

    private func mediaTile<Content: View>(primary: Bool, preview: @escaping () -> Void,
                                         promote: @escaping () -> Void, remove: @escaping () -> Void,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Button(action: preview) {
                content().frame(width: 112, height: 108).clipped()
                    .background(AdminSurface.primaryText.opacity(0.04))
            }
            .buttonStyle(PPVariantStudioPressStyle())
            .accessibilityLabel(Language.get("Variant_Media_Staged_Preview", alter: "معاينة الصورة المحددة"))
            HStack(spacing: 0) {
                Button(action: promote) {
                    Image(systemName: primary ? "star.fill" : "star")
                        .foregroundStyle(primary ? AdminSurface.primary : AdminCommandInk.secondary)
                        .frame(width: 56, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Language.get("Variant_Media_MakePrimary", alter: "تعيين كصورة رئيسية"))
                .accessibilityAddTraits(primary ? .isSelected : [])
                Button(action: remove) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(AdminCommandInk.secondary)
                        .frame(width: 56, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Language.get("Variant_Media_Remove", alter: "إزالة الصورة"))
            }.font(.system(size: 16, weight: .medium)).buttonStyle(PPVariantStudioPressStyle())
                .background(primary ? AdminSurface.primary.opacity(0.07) : AdminSurface.primaryText.opacity(0.035))
        }
        .background(AdminSurface.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(primary ? AdminSurface.primary : AdminSurface.hairline, lineWidth: primary ? 1.5 : 1))
    }

    private func promoteRemoteImageToPrimary(at index: Int) {
        guard retainedRemoteURLs.indices.contains(index) else { return }
        preferredPrimaryStagedImage = nil
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(studioMotion) {
            let url = retainedRemoteURLs.remove(at: index)
            retainedRemoteURLs.insert(url, at: 0)
        }
    }
    private func promoteStagedImageToPrimary(at index: Int) {
        guard stagedImages.indices.contains(index) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(studioMotion) {
            let image = stagedImages.remove(at: index)
            stagedImages.insert(image, at: 0)
            preferredPrimaryStagedImage = image
        }
    }

    // MARK: Quantity

    private var stockQuantityDialCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(Language.get("Variant_Studio_Stock_Title", alter: "الكمية والمخزون الحالي"), symbol: "shippingbox")
            VStack(spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize { quantityReadout }
                HStack(spacing: 16) {
                    quantityButton(symbol: "minus", delta: -1)
                    if dynamicTypeSize.isAccessibilitySize { Spacer() }
                    else { quantityReadout }
                    quantityButton(symbol: "plus", delta: 1)
                }
            }
            .padding(16)
            .background(AdminSurface.primaryText.opacity(0.065), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AdminSurface.primaryText.opacity(0.12)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([1, 5, 10, 25, 50], id: \.self) { delta in
                        Button { changeQuantity(by: delta) } label: {
                            Text(verbatim: "+\(delta)").font(AdminType.subheadlineBold)
                                .frame(minWidth: 44, minHeight: 44)
                                .padding(.horizontal, 4)
                                .background(AdminSurface.primaryText.opacity(0.05), in: Capsule())
                                .overlay(Capsule().strokeBorder(AdminSurface.primaryText.opacity(0.12)))
                                .environment(\.layoutDirection, .leftToRight)
                        }.buttonStyle(PPVariantStudioPressStyle()).foregroundStyle(AdminSurface.primaryText)
                    }
                    Button { withAnimation(studioMotion) { quantity = 0 } } label: {
                        Text(Language.get("Reset", alter: "تصفير")).font(AdminType.footnoteBold)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                    }.buttonStyle(PPVariantStudioPressStyle()).foregroundStyle(AdminCommandInk.secondary).disabled(quantity == 0)
                }
            }
        }
    }
    private var quantityReadout: some View {
        VStack(spacing: 0) {
            Text(quantity.englishDigits)
                .font(AdminType.largeTitle)
                .contentTransition(.numericText())
                .foregroundStyle(AdminSurface.primaryText)
            Text(Language.get("Piece", alter: "حبة"))
                .font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Language.get("Variant_Studio_Stock_Title", alter: "الكمية والمخزون الحالي"))
        .accessibilityValue(quantity.englishDigits)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: changeQuantity(by: 1)
            case .decrement: changeQuantity(by: -1)
            @unknown default: break
            }
        }
    }
    private func changeQuantity(by delta: Int) {
        let (updated, overflow) = quantity.addingReportingOverflow(delta)
        guard !overflow else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(studioMotion) { quantity = max(0, updated) }
    }
    private func quantityButton(symbol: String, delta: Int) -> some View {
        Button { changeQuantity(by: delta) } label: {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                .frame(width: 48, height: 48)
                .background(delta > 0 ? AdminSurface.primary : AdminSurface.surface, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(delta > 0 ? Color.white : AdminSurface.primaryText)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AdminSurface.primaryText.opacity(0.08)))
                .shadow(color: Color.black.opacity(0.08), radius: 5, y: 3)
                .opacity(delta < 0 && quantity == 0 ? 0.35 : 1)
        }
        .buttonStyle(PPVariantStudioPressStyle()).disabled(delta < 0 && quantity == 0)
        .accessibilityLabel(Language.get(delta > 0 ? "Variant_Studio_IncreaseQuantity" : "Variant_Studio_DecreaseQuantity", alter: delta > 0 ? "زيادة" : "تقليل"))
    }

    // MARK: Pricing

    private var commercePricingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(Language.get("Variant_Studio_PricingHeading", alter: "التسعير"), symbol: "tag")
            priceInputField(title: Language.get("Variant_RetailPrice", alter: "سعر البيع"), text: $retailPriceText, field: .retail, prominent: true)
            if canViewCosts {
                priceInputField(title: Language.get("Price_Cost", alter: "سعر التكلفة (اختياري)"), text: $costPriceText, field: .cost)
                if mode.isEdit, costPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(Language.get("Variant_Studio_CostUnchanged", alter: "ترك الحقل فارغًا يحافظ على التكلفة المحفوظة."))
                        .font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let retail = retailPrice, let cost = costPrice, retail > 0 {
                    marginNote(amount: retail - cost, percentage: ((retail - cost) / retail) * 100)
                }
            }
            Toggle(isOn: $wholesaleEnabled.animation(studioMotion)) {
                Text(Language.get("Variant_Add_Wholesale", alter: "سعر جملة مستقل")).font(AdminType.bodyBold)
                    .foregroundStyle(AdminSurface.primaryText)
            }
            .frame(minHeight: 44)
            if wholesaleEnabled {
                priceInputField(title: Language.get("Variant_WholesalePrice", alter: "سعر الجملة"), text: $wholesalePriceText, field: .wholesale)
            }
        }
    }
    private func priceInputField(title: String, text: Binding<String>, field: StudioField, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(AdminType.footnoteBold)
                Spacer(minLength: 8)
                Image(systemName: focusedField == field ? "pencil.line" : "pencil")
                    .font(.system(size: 11, weight: .semibold)).accessibilityHidden(true)
            }.foregroundStyle(focusedField == field ? AdminSurface.primary : AdminCommandInk.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                let valueFont = prominent ? AdminType.largeTitle : AdminType.title2
                TextField(
                    title,
                    text: text,
                    prompt: Text("0.00")
                        .font(valueFont)
                        .foregroundColor(AdminCommandInk.tertiary)
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .font(valueFont)
                .foregroundStyle(AdminSurface.primaryText)
                .multilineTextAlignment(Language.isRTL() ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel(title)
                Text(Language.get("QAR", alter: "ر.ق"))
                    .font(AdminType.footnoteBold).foregroundStyle(prominent ? AdminSurface.primary : AdminCommandInk.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(prominent ? AdminSurface.primary.opacity(0.09) : AdminSurface.primaryText.opacity(0.05), in: Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(focusedField == field ? AdminSurface.primary.opacity(0.04) : AdminSurface.primaryText.opacity(prominent ? 0.055 : 0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focusedField == field ? AdminSurface.primary : AdminSurface.primaryText.opacity(0.15), lineWidth: 1.5))
            .animation(studioMotion, value: focusedField)
            if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               parsedAmount(text.wrappedValue) == nil || (field != .cost && parsedAmount(text.wrappedValue) == 0) {
                Text(Language.get(field == .cost ? "Variant_Studio_InvalidCost" : "Variant_Studio_InvalidPrice",
                                  alter: field == .cost ? "أدخل تكلفة صحيحة غير سالبة، بمنزلتين عشريتين كحد أقصى." : "أدخل سعرًا أكبر من صفر، بمنزلتين عشريتين كحد أقصى."))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.crimson)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    @ViewBuilder private func marginNote(amount: Double, percentage: Double) -> some View {
        if amount.isFinite, percentage.isFinite {
            Label(String(format: Language.get("Variant_Studio_Profit_Format", alter: "الربح: %@ (هامش الربح: %@%%)"),
                         PetAccessory.formatCurrency(NSNumber(value: amount)), String(format: "%.0f", percentage)),
                  systemImage: amount >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(AdminType.footnoteBold)
                .foregroundStyle(amount >= 0 ? AdminSurface.emerald : AdminSurface.crimson)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background((amount >= 0 ? AdminSurface.emerald : AdminSurface.crimson).opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: Product identifiers

    private var identifiersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(Language.get("Variant_Studio_IdentifiersHeading", alter: "تعريف المتغير"), symbol: "barcode")
            identifierField(title: Language.get("CatalogIntake_BarcodeLabel", alter: "الباركود"), text: $barcode, field: .barcode)
            adaptiveRow {
                Button { generatePPBarcode() } label: {
                    Label(Language.get("CatalogIntake_GeneratePPBarcode", alter: "توليد باركود PP"), systemImage: "sparkles")
                        .font(AdminType.footnoteBold).frame(minHeight: 44)
                }.buttonStyle(PPVariantStudioPressStyle())
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                AdminBarcodeScanButton { barcode = $0 }.frame(minWidth: 44, minHeight: 44)
            }.foregroundStyle(AdminSurface.primary)
            if let message = barcodeConflictMessage { failureBanner(message) }
            identifierField(title: Language.get("CatalogIntake_SKULabel", alter: "رمز المنتج (SKU)"), text: $sku, field: .sku)
            Button { generateVariantSKU() } label: {
                Label(Language.get("Generate_SKU_Auto", alter: "توليد SKU"), systemImage: "wand.and.stars")
                    .font(AdminType.footnoteBold).frame(minHeight: 44)
            }.buttonStyle(PPVariantStudioPressStyle()).foregroundStyle(AdminSurface.primary)
            if let message = skuConflictMessage { failureBanner(message) }
        }
    }
    private func identifierField(title: String, text: Binding<String>, field: StudioField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: field == .barcode ? "barcode" : "number")
                .font(AdminType.footnoteBold)
                .foregroundStyle(focusedField == field ? AdminSurface.primary : AdminCommandInk.secondary)
            VStack(spacing: 0) {
                TextField(
                    title,
                    text: text,
                    prompt: Text(title)
                        .font(AdminType.body)
                        .foregroundColor(AdminCommandInk.tertiary)
                )
                .font(AdminType.bodyBold)
                .englishAlphanumericInput(text: text)
                .focused($focusedField, equals: field)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 16).frame(minHeight: 52)
                .accessibilityLabel(title)
                if !text.wrappedValue.isEmpty {
                    studioRule
                    HStack {
                        Button {
                            UIPasteboard.general.string = text.wrappedValue
                            UISelectionFeedbackGenerator().selectionChanged()
                            copiedField = field
                        } label: {
                            Label(copiedField == field ? Language.get("Variant_Hex_Copied", alter: "تم النسخ") : Language.get("Copy", alter: "نسخ"), systemImage: copiedField == field ? "checkmark" : "doc.on.doc")
                                .font(AdminType.captionBold).frame(minHeight: 44)
                        }
                        Spacer()
                        Button { text.wrappedValue = "" } label: {
                            Label(Language.get("Clear", alter: "مسح"), systemImage: "xmark.circle")
                                .font(AdminType.captionBold).frame(minHeight: 44)
                        }
                    }.buttonStyle(PPVariantStudioPressStyle()).foregroundStyle(AdminCommandInk.secondary).padding(.horizontal, 16)
                        .background(AdminSurface.primaryText.opacity(0.035))
                }
            }
            .background(AdminSurface.primaryText.opacity(0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focusedField == field ? AdminSurface.primary : AdminSurface.primaryText.opacity(0.15), lineWidth: 1.5))
            .animation(studioMotion, value: focusedField)
            .onChange(of: text.wrappedValue) { _, _ in if copiedField == field { copiedField = nil } }
        }
    }
    private func generatePPBarcode() {
        UISelectionFeedbackGenerator().selectionChanged()
        let timestamp = Int(Date().timeIntervalSince1970) % 1_000_000_000
        barcode = String(format: "PP%09d%d", timestamp, Int.random(in: 0...9))
    }
    private func generateVariantSKU() {
        UISelectionFeedbackGenerator().selectionChanged()
        let tag = color.nameEn.filter { $0.isLetter }.prefix(3).uppercased()
        sku = "\(tag.isEmpty ? "CLR" : String(tag))-\(Int.random(in: 100...999))"
    }

    // MARK: Saving and recovery

    private func studioSaveDock(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            studioRule
            if busy {
                Text(Language.get("Variant_Studio_SavingGuidance", alter: "جارٍ حفظ هذا المتغير وتأكيد النتيجة. انتظر قبل إجراء تعديلات أخرى."))
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminCommandInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20).padding(.top, 12)
                    .frame(maxWidth: 720, alignment: .leading)
            } else if let issue = submitIssue {
                VStack(alignment: .leading, spacing: 4) {
                    Label(issue.message, systemImage: "exclamationmark.circle.fill")
                        .font(AdminType.footnoteBold)
                        .foregroundStyle(AdminSurface.crimson)
                        .fixedSize(horizontal: false, vertical: true)
                    if !hasPendingSave {
                        Button(Language.get("Variant_Studio_ReviewField", alter: "انتقل إلى الحقل المطلوب")) {
                            focusedField = issue.field
                            withAnimation(studioMotion) { proxy.scrollTo(issue.sectionID, anchor: .top) }
                        }
                        .font(AdminType.footnoteBold)
                        .foregroundStyle(AdminSurface.primary)
                        .frame(minHeight: 44)
                        .buttonStyle(PPVariantStudioPressStyle())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12)
                .frame(maxWidth: 720, alignment: .leading)
                .accessibilityIdentifier("variant.studio.saveIssue")
            } else if hasPendingSave {
                Text(Language.get("Variant_Studio_PendingHint", alter: "لم يكتمل تأكيد الحفظ. أعد المحاولة بنفس التعديلات لإكمال العملية بأمان."))
                    .font(AdminType.footnote)
                    .foregroundStyle(AdminCommandInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20).padding(.top, 12)
                    .frame(maxWidth: 720, alignment: .leading)
            }
            Button(action: submit) {
                HStack(spacing: 10) {
                    if busy { ProgressView().tint(.white) }
                    else { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)) }
                    Text(busy ? Language.get("Saving", alter: "جارٍ الحفظ...")
                         : hasPendingSave ? Language.get("Variant_Studio_ResumeSave", alter: "إكمال الحفظ")
                         : Language.get(mode.isEdit ? "Variant_Studio_Save" : "Variant_Add_Create",
                                        alter: mode.isEdit ? "حفظ التعديلات" : "إنشاء اللون"))
                        .font(AdminType.bodyBold)
                }
                .foregroundStyle(canSubmit || busy ? Color.white : AdminCommandInk.secondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                .background(canSubmit || busy ? AdminSurface.primary : AdminSurface.control,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PPVariantStudioPressStyle()).disabled(!canSubmit)
            .accessibilityIdentifier("variant.studio.save")
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: 720)
        }.frame(maxWidth: .infinity).background(AdminSurface.surface)
    }
    private func failureBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(AdminType.footnoteBold).foregroundStyle(AdminSurface.crimson)
                .fixedSize(horizontal: false, vertical: true)
            Text(Language.get("Variant_Recovery_DraftKept", alter: "تم الاحتفاظ بتعديلاتك."))
                .font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(AdminSurface.crimson.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var safetyNoteCard: some View {
        Text(Language.get("Variant_Studio_SaveScope", alter: "تُحفظ الصور والأسعار والمخزون لهذا المتغير فقط."))
            .font(AdminType.footnote).foregroundStyle(AdminCommandInk.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func deepLinkRecordButton(variant: PPAccessoryVariant, action: @escaping (String) -> Void) -> some View {
        Button {
            focusedField = nil
            if hasUnsavedChanges {
                pendingRecordID = variant.productId
                showsDiscardConfirmation = true
            } else { dismiss(); action(variant.productId) }
        } label: {
            HStack(spacing: 12) {
                Text(Language.get("Variant_Studio_OpenFullRecord", alter: "فتح السجل الكامل في إدارة الأصناف"))
                    .font(AdminType.footnoteBold).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward").flipsForRightToLeftLayoutDirection(true)
            }.foregroundStyle(AdminSurface.primary).frame(minHeight: 48)
        }.buttonStyle(PPVariantStudioPressStyle())
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit, let retailPrice else { return }
        focusedField = nil
        localSubmitting = true
        localFailure = nil
        Task { @MainActor in
            let success: Bool
            switch mode {
            case .create:
                success = await onCreate(
                    color,
                    selectedOptions,
                    sku,
                    barcode,
                    retailPrice,
                    costPrice,
                    wholesalePrice,
                    quantity,
                    stagedImages
                )
            case .edit(let variant):
                success = await onUpdate(
                    variant.productId,
                    color,
                    selectedOptions,
                    sku,
                    barcode,
                    retailPrice,
                    costPrice,
                    wholesalePrice,
                    quantity,
                    stagedImages,
                    retainedRemoteURLs,
                    preferredPrimaryStagedImage
                )
            }
            localSubmitting = false
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } else {
                localFailure = errorMessage?() ?? Language.get(
                    "Variant_Studio_SaveFailed",
                    alter: "تعذر حفظ التعديلات. لم يتم فقدان أي بيانات، يرجى المحاولة مرة أخرى."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

private struct PPVariantStudioPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AdminSurface.primaryText.opacity(0.09), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.025), radius: 12, y: 5)
    }
}

private struct PPVariantStudioPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Colour editor sheet (Category-Defining Atelier)

struct PPAccessoryVariantColorEditorSheet: View {
    let initialColor: PPAccessoryVariantColor?
    let usedIdentifiers: Set<String>
    /// The colour currently assigned to the variant being edited, which must not
    /// count as a duplicate of itself.
    let excludingIdentifier: String?
    let onPick: (PPAccessoryVariantColor) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nameAr: String = ""
    @State private var nameEn: String = ""
    @State private var hex: String = "#CCCCCC"
    @State private var identifier: String = ""
    @State private var isCustom = false
    @State private var selectedSwiftUIColor: Color = .gray
    @State private var isHexCopied = false

    private let neutralsIds: Set<String> = ["black", "white", "grey", "beige", "brown"]
    private let warmIds: Set<String> = ["crimson-red", "rose-pink", "amber-orange", "sun-yellow"]
    private let coolIds: Set<String> = ["forest-green", "teal", "ocean-blue", "navy", "violet"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroStageCard
                    paletteGroupsSection
                    customStudioSection

                    if let problem {
                        conflictWarningBanner(problem)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AdminSurface.background.ignoresSafeArea())
            .navigationTitle(Language.get("Variant_ChooseColor", alter: "اختيار اللون"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(Language.get("Variant_ChooseColor", alter: "اختيار اللون"))
                        .font(PPBrandFont.bold(size: 18, relativeTo: .headline))
                        .foregroundStyle(AdminCommandInk.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(Language.get("Cancel", alter: "إلغاء")) {
                        dismiss()
                    }
                    .font(AdminType.callout)
                    .foregroundStyle(AdminCommandInk.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        onPick(previewColor)
                        dismiss()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                            Text(Language.get("Done", alter: "تم"))
                                .font(AdminType.calloutBold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(problem == nil ? AdminSurface.primary : AdminSurface.primary.opacity(0.35))
                        )
                        .foregroundStyle(.white)
                    }
                    .disabled(problem != nil)
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear(perform: seed)
    }

    private func seed() {
        if let initialColor, !initialColor.identifier.isEmpty {
            nameAr = initialColor.nameAr
            nameEn = initialColor.nameEn
            hex = initialColor.hex
            identifier = initialColor.identifier
            selectedSwiftUIColor = initialColor.uiColorValue
        } else if let firstPreset = PPAccessoryVariantColorLibrary.entries.first {
            nameAr = firstPreset.nameAr
            nameEn = firstPreset.nameEn
            hex = firstPreset.hex
            identifier = firstPreset.identifier
            selectedSwiftUIColor = firstPreset.uiColorValue
        }
    }

    // MARK: - Hero Swatch Stage Card

    private var heroStageCard: some View {
        VStack(spacing: 14) {
            // Dimensional Glowing Swatch
            ZStack {
                // Dynamic Breathing Ambient Glow
                Circle()
                    .fill(previewColor.uiColorValue)
                    .frame(width: 88, height: 88)
                    .blur(radius: 22)
                    .opacity(0.42)

                // Tactile Color Disc
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                previewColor.uiColorValue,
                                previewColor.uiColorValue.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle().strokeBorder(
                            previewColor.requiresContrastBorder
                                ? AdminSurface.primaryText.opacity(0.40)
                                : Color.white.opacity(0.25),
                            lineWidth: previewColor.requiresContrastBorder ? 1.5 : 1
                        )
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(previewColor.uiColor.isDarkTone ? Color.white.opacity(0.90) : Color.black.opacity(0.70))
                    )
            }
            .padding(.top, 4)

            // Dynamic Bilingual Title Header
            VStack(spacing: 4) {
                Text(previewColor.localizedName.isEmpty ? Language.get("Variant_Custom", alter: "لون مخصص") : previewColor.localizedName)
                    .font(AdminType.title3Bold)
                    .foregroundStyle(AdminSurface.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                if !previewColor.nameEn.isEmpty && Language.isRTL() {
                    Text(previewColor.nameEn)
                        .font(AdminType.caption)
                        .foregroundStyle(AdminCommandInk.secondary)
                        .lineLimit(1)
                } else if !previewColor.nameAr.isEmpty && !Language.isRTL() {
                    Text(previewColor.nameAr)
                        .font(AdminType.caption)
                        .foregroundStyle(AdminCommandInk.secondary)
                        .lineLimit(1)
                }
            }

            // Hex & Contrast Indicators
            HStack(spacing: 8) {
                // Hex Capsule with tap-to-copy
                Button {
                    UIPasteboard.general.string = previewColor.hex
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHexCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { isHexCopied = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isHexCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isHexCopied ? Language.get("Variant_Hex_Copied", alter: "تم نسخ رمز اللون") : previewColor.hex)
                            .font(AdminType.caption2.monospaced())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AdminSurface.control, in: Capsule())
                    .foregroundStyle(isHexCopied ? AdminSurface.emerald : AdminSurface.primaryText)
                }
                .buttonStyle(.plain)

                // Live Contrast Status
                HStack(spacing: 4) {
                    Image(systemName: previewColor.requiresContrastBorder ? "eye.trianglebadge.exclamationmark" : "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(previewColor.requiresContrastBorder ? AdminSurface.amber : AdminSurface.emerald)
                    Text(previewColor.requiresContrastBorder
                         ? Language.get("Variant_Contrast_Attention", alter: "قد يحتاج لإطار تباين")
                         : Language.get("Variant_Contrast_Optimal", alter: "تباين ممتاز (مقروء بوضوح)"))
                        .font(AdminType.caption2)
                        .foregroundStyle(AdminCommandInk.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(AdminSurface.control, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AdminSurface.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AdminSurface.hairline, lineWidth: 1)
        )
    }

    // MARK: - Harmonized Palettes Section

    private var paletteGroupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    Language.get("Variant_Preset_Palettes", alter: "المجموعات اللونية المتناسقة"),
                    systemImage: "paintpalette.fill"
                )
                .font(AdminType.subheadlineBold)
                .foregroundStyle(AdminSurface.primaryText)

                Spacer()
            }

            paletteGroupRow(
                title: Language.get("Variant_Palette_Neutrals", alter: "الأساسيات والمحايدة"),
                entries: PPAccessoryVariantColorLibrary.entries.filter { neutralsIds.contains($0.identifier) }
            )

            paletteGroupRow(
                title: Language.get("Variant_Palette_Warm", alter: "الدرجات الدافئة والحيوية"),
                entries: PPAccessoryVariantColorLibrary.entries.filter { warmIds.contains($0.identifier) }
            )

            paletteGroupRow(
                title: Language.get("Variant_Palette_Cool", alter: "الدرجات الباردة والعميقة"),
                entries: PPAccessoryVariantColorLibrary.entries.filter { coolIds.contains($0.identifier) }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AdminSurface.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AdminSurface.hairline, lineWidth: 1)
        )
    }

    private func paletteGroupRow(title: String, entries: [PPAccessoryVariantColor]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AdminType.caption2Bold)
                .foregroundStyle(AdminCommandInk.secondary)
                .padding(.horizontal, 2)

            HStack(spacing: 12) {
                ForEach(entries, id: \.identifier) { entry in
                    atelierChip(entry)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func atelierChip(_ entry: PPAccessoryVariantColor) -> some View {
        let isSelected = (previewColor.identifier == entry.identifier) ||
            (!isCustom && hex.uppercased() == entry.hex.uppercased())
        let isTaken = usedIdentifiers.contains(entry.identifier) && entry.identifier != excludingIdentifier

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                nameAr = entry.nameAr
                nameEn = entry.nameEn
                hex = entry.hex
                identifier = entry.identifier
                isCustom = false
                selectedSwiftUIColor = entry.uiColorValue
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Outer animated selection ring
                    Circle()
                        .strokeBorder(
                            isSelected ? AdminSurface.primary : Color.clear,
                            lineWidth: 2.5
                        )
                        .frame(width: 48, height: 48)

                    // Color Disc
                    Circle()
                        .fill(entry.uiColorValue)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().strokeBorder(
                                entry.requiresContrastBorder
                                    ? AdminSurface.primaryText.opacity(0.35)
                                    : Color.clear,
                                lineWidth: 1
                            )
                        )
                        .shadow(color: Color.black.opacity(isSelected ? 0.20 : 0.06), radius: isSelected ? 4 : 2, x: 0, y: 1)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(entry.uiColor.isDarkTone ? Color.white : Color.black.opacity(0.85))
                    }

                    if isTaken {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .scaleEffect(isSelected ? 1.08 : 1.0)

                Text(entry.localizedName)
                    .font(isSelected ? AdminType.caption2Bold : AdminType.caption2)
                    .foregroundStyle(isSelected ? AdminSurface.primary : AdminSurface.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 54)
            }
            .frame(minWidth: 48)
            .opacity(isTaken ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
        .accessibilityLabel(
            isTaken
                ? "\(entry.accessibilityName), \(Language.get("Variant_AlreadyUsed", alter: "مستخدم بالفعل"))"
                : entry.accessibilityName
        )
    }

    // MARK: - Custom Color Studio Deck

    private var customStudioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    Language.get("Variant_Custom_Section", alter: "استوديو التخصيص والمسميات"),
                    systemImage: "slider.horizontal.3"
                )
                .font(AdminType.subheadlineBold)
                .foregroundStyle(AdminSurface.primaryText)
                Spacer()
            }

            spectrumPickerRow
            hexInputRow
            Divider().padding(.vertical, 2)
            bilingualNameFields
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AdminSurface.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AdminSurface.hairline, lineWidth: 1)
        )
    }

    private var spectrumPickerRow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 42)
                .opacity(0.85)

            HStack {
                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(Language.get("Variant_Spectrum_Picker", alter: "لوحة الألوان التفاعلية"))
                    .font(AdminType.caption1Bold)
                    .foregroundStyle(.white)
                Spacer()
                ColorPicker("", selection: $selectedSwiftUIColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: selectedSwiftUIColor) { newColor in
                        handleColorPickerChange(newColor)
                    }
            }
            .padding(.horizontal, 14)
        }
    }

    private func handleColorPickerChange(_ newColor: Color) {
        let derived = UIColor(newColor).purePetsHex
        hex = derived
        isCustom = true
        for entry in PPAccessoryVariantColorLibrary.entries {
            if entry.hex.caseInsensitiveCompare(derived) == .orderedSame {
                nameAr = entry.nameAr
                nameEn = entry.nameEn
                identifier = entry.identifier
                break
            }
        }
    }

    private var hexDigitsBinding: Binding<String> {
        Binding(
            get: {
                hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
            },
            set: { newVal in
                let cleaned = newVal.filter { "0123456789ABCDEFabcdef".contains($0) }.uppercased()
                let formatted = "#" + String(cleaned.prefix(6))
                hex = formatted
                isCustom = true
                if formatted.count == 7 {
                    let temp = PPAccessoryVariantColor(identifier: "temp", nameAr: "", nameEn: "", hex: formatted)
                    selectedSwiftUIColor = temp.uiColorValue
                }
            }
        )
    }

    private var hexInputRow: some View {
        HStack {
            Text(Language.get("Variant_Hex", alter: "قيمة اللون"))
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminCommandInk.secondary)

            Spacer()

            HStack(spacing: 6) {
                Text("#")
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminCommandInk.tertiary)

                TextField(
                    "RRGGBB",
                    text: hexDigitsBinding,
                    prompt: Text("RRGGBB")
                        .font(AdminType.footnote)
                        .foregroundColor(AdminCommandInk.tertiary)
                )
                .font(AdminType.footnoteBold)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .frame(width: 76)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(PPAccessoryVariantColor.isValidHex(hex) ? AdminSurface.hairline : AdminSurface.crimson, lineWidth: 1)
            )
        }
    }

    private var bilingualNameFields: some View {
        VStack(spacing: 12) {
            arabicNameField
            englishNameField
        }
    }

    private var arabicNameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Language.get("Variant_NameAr", alter: "الاسم بالعربية"))
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminCommandInk.secondary)
                Spacer()
                Text("\(nameAr.count)/300")
                    .font(AdminType.caption1)
                    .foregroundStyle(nameAr.count > 300 ? AdminSurface.crimson : AdminCommandInk.tertiary)
            }

            HStack {
                TextField(
                    Language.get("Variant_NameAr", alter: "الاسم بالعربية"),
                    text: $nameAr,
                    prompt: Text(Language.get("Variant_NameAr", alter: "الاسم بالعربية"))
                        .font(AdminType.callout)
                        .foregroundColor(AdminCommandInk.tertiary)
                )
                .font(AdminType.calloutBold)
                .multilineTextAlignment(Language.isRTL() ? .leading : .trailing)
                .onChange(of: nameAr) { _ in isCustom = true }

                if !nameAr.isEmpty {
                    Button {
                        nameAr = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AdminCommandInk.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var englishNameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Language.get("Variant_NameEn", alter: "الاسم بالإنجليزية"))
                    .font(AdminType.footnoteBold)
                    .foregroundStyle(AdminCommandInk.secondary)
                Spacer()
                Text("\(nameEn.count)/300")
                    .font(AdminType.caption1)
                    .foregroundStyle(nameEn.count > 300 ? AdminSurface.crimson : AdminCommandInk.tertiary)
            }

            HStack {
                TextField(
                    Language.get("Variant_NameEn", alter: "الاسم بالإنجليزية"),
                    text: $nameEn,
                    prompt: Text(Language.get("Variant_NameEn", alter: "الاسم بالإنجليزية"))
                        .font(AdminType.callout)
                        .foregroundColor(AdminCommandInk.tertiary)
                )
                .font(AdminType.calloutBold)
                .multilineTextAlignment(Language.isRTL() ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)
                .onChange(of: nameEn) { _ in isCustom = true }

                if !nameEn.isEmpty {
                    Button {
                        nameEn = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AdminCommandInk.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Conflict Warning Banner

    private func conflictWarningBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AdminSurface.amber)
            Text(message)
                .font(AdminType.footnoteBold)
                .foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(AdminSurface.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AdminSurface.amber.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// The colour that would be produced by the current fields. A custom colour
    /// derives a stable identifier so the operator never has to invent one.
    private var previewColor: PPAccessoryVariantColor {
        let resolvedIdentifier: String
        if isCustom || identifier.isEmpty {
            resolvedIdentifier = PPAccessoryVariantColor.derivedIdentifier(fromName: nameEn, hex: hex)
        } else {
            resolvedIdentifier = identifier
        }
        return PPAccessoryVariantColor(
            identifier: resolvedIdentifier,
            nameAr: nameAr,
            nameEn: nameEn,
            hex: hex
        )
    }

    private var problem: String? {
        let candidate = previewColor
        if let message = candidate.validationMessage { return message }
        if usedIdentifiers.contains(candidate.identifier),
           candidate.identifier != excludingIdentifier {
            return Language.get("Variant_Error_ColorTaken", alter: "هذا اللون مستخدم بالفعل في هذا المنتج.")
        }
        return nil
    }
}

// MARK: - Atelier Color Extensions

fileprivate extension UIColor {
    var purePetsHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            let rgb = (Int(round(r * 255)) << 16) | (Int(round(g * 255)) << 8) | Int(round(b * 255))
            return String(format: "#%06X", rgb)
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &a) {
            let val = Int(round(white * 255))
            let rgb = (val << 16) | (val << 8) | val
            return String(format: "#%06X", rgb)
        }
        return "#CCCCCC"
    }

    var isDarkTone: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return luminance < 0.55
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &a) {
            return white < 0.55
        }
        return false
    }
}


// MARK: - Image picker
//
// PPVariantImagePickerSheet is provided by PPAdminDesignCompat.swift for module-wide accessibility.
