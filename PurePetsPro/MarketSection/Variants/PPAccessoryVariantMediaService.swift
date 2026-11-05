//
//  PPAccessoryVariantMediaService.swift
//  PurePetsPro
//
//  Per-colour media for accessory variants in Pure Pets Pro.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage

/// One image staged for a specific colour.
struct PPAccessoryVariantStagedImage: Identifiable {
    let id: UUID
    let image: UIImage
    var uploadedURL: String?
    var width: Int
    var height: Int

    init(image: UIImage) {
        self.id = UUID()
        self.image = image
        self.uploadedURL = nil
        self.width = Int(image.size.width.rounded())
        self.height = Int(image.size.height.rounded())
    }
}

/// Prepared image payload with compressed data and content type
struct PreparedAccessoryImagePayload {
    let image: UIImage
    let data: Data
    let contentType: String
    let fileExtension: String
}

/// Result of committing one colour's media.
struct PPAccessoryVariantMediaCommit {
    let productId: String
    let imageURLs: [String]
    let imageMeta: [[String: Any]]
    let orphanedURLs: [String]
}

enum PPAccessoryVariantMediaError: LocalizedError {
    case notAuthenticated
    case unpreparableImage
    case uploadFailed(underlying: Error)
    case tooManyImages(limit: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return Language.get("Variant_Media_NotAuthenticated", alter: "يجب تسجيل الدخول لتحميل الصور.")
        case .unpreparableImage:
            return Language.get("Variant_Media_BadImage", alter: "تعذر تجهيز إحدى الصور. اختر صورة أخرى.")
        case .uploadFailed:
            return Language.get("Variant_Media_UploadFailed", alter: "فشل تحميل الصور. تم الاحتفاظ باختيارك، أعد المحاولة.")
        case .tooManyImages(let limit):
            let template = Language.get("Variant_Media_TooMany", alter: "الحد الأقصى %@ صور لكل لون.")
            return String(format: template, NSNumber(value: limit))
        }
    }
}

@MainActor
final class PPAccessoryVariantMediaService {
    static let shared = PPAccessoryVariantMediaService()

    /// Matches the server's `imageURLsArray` ceiling of 12 entries.
    static let maxImagesPerVariant = 12

    private let storage = Storage.storage()

    private init() {}

    // MARK: - Image Preparation

    static func prepareAccessoryImageForUpload(_ source: UIImage) -> PreparedAccessoryImagePayload? {
        guard source.size.width > 0, source.size.height > 0 else { return nil }

        let longestEdge = max(source.size.width, source.size.height)
        let maxAllowedDimension: CGFloat = 1_800
        let scale = min(1.0, maxAllowedDimension / longestEdge)
        let targetSize = CGSize(
            width: max(1, (source.size.width * scale).rounded()),
            height: max(1, (source.size.height * scale).rounded())
        )

        let maxBytes = 8 * 1_024 * 1_024

        let hasAlpha: Bool = {
            guard let cgImage = source.cgImage else { return false }
            switch cgImage.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
                return true
            case .none, .noneSkipFirst, .noneSkipLast:
                return false
            default:
                return false
            }
        }()

        if hasAlpha {
            let transparentFormat = UIGraphicsImageRendererFormat()
            transparentFormat.scale = 1.0
            transparentFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: transparentFormat)
            let renderedImage = renderer.image { _ in
                source.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            if let pngData = renderedImage.pngData(), !pngData.isEmpty, pngData.count <= maxBytes {
                return PreparedAccessoryImagePayload(
                    image: renderedImage,
                    data: pngData,
                    contentType: "image/png",
                    fileExtension: "png"
                )
            }
        }

        let opaqueFormat = UIGraphicsImageRendererFormat()
        opaqueFormat.scale = 1.0
        opaqueFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: opaqueFormat)
        let normalizedImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        let qualityLadder: [CGFloat] = [0.82, 0.72, 0.62, 0.52]
        for quality in qualityLadder {
            if let jpegData = normalizedImage.jpegData(compressionQuality: quality),
               !jpegData.isEmpty,
               jpegData.count <= maxBytes {
                return PreparedAccessoryImagePayload(
                    image: normalizedImage,
                    data: jpegData,
                    contentType: "image/jpeg",
                    fileExtension: "jpg"
                )
            }
        }

        if let fallbackData = normalizedImage.jpegData(compressionQuality: 0.5), !fallbackData.isEmpty {
            return PreparedAccessoryImagePayload(
                image: normalizedImage,
                data: fallbackData,
                contentType: "image/jpeg",
                fileExtension: "jpg"
            )
        }

        return nil
    }

    // MARK: - Paths

    static func objectPath(
        productId: String,
        colorId: String,
        assetId: UUID,
        fileExtension: String
    ) -> String {
        let safeColor = colorId.isEmpty ? "unassigned" : colorId
        return "petAccessories/\(productId)/variants/\(safeColor)/\(assetId.uuidString).\(fileExtension)"
    }

    // MARK: - Upload

    func uploadStagedImages(
        _ staged: inout [PPAccessoryVariantStagedImage],
        productId: String,
        colorId: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw PPAccessoryVariantMediaError.notAuthenticated
        }
        guard staged.count <= Self.maxImagesPerVariant else {
            throw PPAccessoryVariantMediaError.tooManyImages(limit: Self.maxImagesPerVariant)
        }

        for index in staged.indices where staged[index].uploadedURL == nil {
            guard let payload = Self.prepareAccessoryImageForUpload(staged[index].image) else {
                throw PPAccessoryVariantMediaError.unpreparableImage
            }

            let path = Self.objectPath(
                productId: productId,
                colorId: colorId,
                assetId: staged[index].id,
                fileExtension: payload.fileExtension
            )

            let metadata = StorageMetadata()
            metadata.contentType = payload.contentType
            metadata.customMetadata = [
                "uploaded_by": uid,
                "entity_type": "accessory",
                "media_type": "image",
                "variant_color_id": colorId,
                "product_id": productId,
            ]

            do {
                let reference = storage.reference().child(path)
                try await Self.putData(payload.data, metadata: metadata, at: reference)
                let url = try await Self.downloadURL(for: reference)
                staged[index].uploadedURL = url.absoluteString
                staged[index].width = Int(payload.image.size.width.rounded())
                staged[index].height = Int(payload.image.size.height.rounded())
            } catch {
                throw PPAccessoryVariantMediaError.uploadFailed(underlying: error)
            }
        }
    }

    private static func putData(
        _ data: Data,
        metadata: StorageMetadata,
        at reference: StorageReference
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func downloadURL(for reference: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            reference.downloadURL { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: PPAccessoryVariantMediaError.uploadFailed(
                        underlying: NSError(
                            domain: "pp.variant.media",
                            code: 5,
                            userInfo: [NSLocalizedDescriptionKey: "Missing download URL."]
                        )
                    ))
                }
            }
        }
    }

    func commit(
        productId: String,
        retainedURLs: [String],
        staged: [PPAccessoryVariantStagedImage],
        previousURLs: [String],
        metadataByURL: [String: [String: Any]]
    ) -> PPAccessoryVariantMediaCommit {
        var urls = retainedURLs
        var meta: [[String: Any]] = retainedURLs.map { url in
            metadataByURL[url] ?? ["url": url]
        }

        for item in staged {
            guard let url = item.uploadedURL, !url.isEmpty else { continue }
            urls.append(url)
            var entry: [String: Any] = ["url": url]
            if item.width > 0 { entry["width"] = item.width }
            if item.height > 0 { entry["height"] = item.height }
            meta.append(entry)
        }

        let keptSet = Set(urls)
        let orphans = previousURLs.filter { !keptSet.contains($0) }

        return PPAccessoryVariantMediaCommit(
            productId: productId,
            imageURLs: urls,
            imageMeta: meta,
            orphanedURLs: orphans
        )
    }

    func persist(
        _ commit: PPAccessoryVariantMediaCommit,
        commandId: String,
        expectedRevision: Int?
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let fields: [String: Any] = [
                "imageURLsArray": commit.imageURLs,
                "imageMeta": commit.imageMeta
            ]
            PPProviderMarketplaceManager.shared().updateMarketItem(commit.productId, fields: fields) { success, message, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? NSError(
                        domain: "pp.variant.media",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: message ?? "Failed to save variant media"]
                    ))
                }
            }
        }
    }

    func deleteOrphans(_ urls: [String]) async {
        for url in urls where !url.isEmpty {
            let reference = storage.reference(forURL: url)
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                reference.delete { _ in continuation.resume() }
            }
        }
    }

    func discardStagedUploads(_ staged: [PPAccessoryVariantStagedImage]) async {
        await deleteOrphans(staged.compactMap(\.uploadedURL))
    }
}
