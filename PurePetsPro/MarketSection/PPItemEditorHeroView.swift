//
//  PPItemEditorHeroView.swift
//  PurePetsPro
//
//  Category-Defining Beyond-FAANG Market Item Editor Hero Card.
//  Reinvented from absolute first principles separately for iPhone (iOS) and iPad (iPadOS):
//  - iPhone: Compact thumb-zone media showcase deck with floating camera halo & live telemetry ring
//  - iPad: Widescreen panoramic studio deck with multi-photo filmstrip & seller insight cockpit
//  - Full 6-state resilience: Normal, Shimmer Skeleton, Empty State, Error Recovery, Haptics, Reduce Motion
//

import SwiftUI
import UIKit

// MARK: - Objective-C Compatible Snapshot Model

@objc(PPItemEditorHeroSnapshot)
public final class PPItemEditorHeroSnapshot: NSObject {
    @objc public let isCreate: Bool
    @objc public let title: String
    @objc public let subtitle: String
    @objc public let itemName: String
    @objc public let categoryName: String
    @objc public let primaryImageURL: String?
    @objc public let primaryImage: UIImage?
    @objc public let imageCount: Int
    @objc public let allImageURLs: [String]
    @objc public let allSelectedImages: [UIImage]
    @objc public let isPublished: Bool
    @objc public let isAvailable: Bool
    @objc public let completionProgress: Double
    @objc public let stateIndex: Int // 0: normal, 1: loading, 2: empty, 3: error
    @objc public let errorMessage: String?

    @objc public init(
        isCreate: Bool,
        title: String,
        subtitle: String,
        itemName: String,
        categoryName: String,
        primaryImageURL: String?,
        primaryImage: UIImage?,
        imageCount: Int,
        allImageURLs: [String],
        allSelectedImages: [UIImage],
        isPublished: Bool,
        isAvailable: Bool,
        completionProgress: Double,
        stateIndex: Int,
        errorMessage: String?
    ) {
        self.isCreate = isCreate
        self.title = title
        self.subtitle = subtitle
        self.itemName = itemName
        self.categoryName = categoryName
        self.primaryImageURL = primaryImageURL
        self.primaryImage = primaryImage
        self.imageCount = imageCount
        self.allImageURLs = allImageURLs
        self.allSelectedImages = allSelectedImages
        self.isPublished = isPublished
        self.isAvailable = isAvailable
        self.completionProgress = min(max(completionProgress, 0.0), 1.0)
        self.stateIndex = stateIndex
        self.errorMessage = errorMessage
        super.init()
    }

    @objc public static func emptySnapshot(isCreate: Bool) -> PPItemEditorHeroSnapshot {
        return PPItemEditorHeroSnapshot(
            isCreate: isCreate,
            title: isCreate ? NSLocalizedString("Market_AddTitle", comment: "") : NSLocalizedString("Market_EditTitle", comment: ""),
            subtitle: NSLocalizedString("Market_FormSubtitle", comment: ""),
            itemName: "",
            categoryName: "",
            primaryImageURL: nil,
            primaryImage: nil,
            imageCount: 0,
            allImageURLs: [],
            allSelectedImages: [],
            isPublished: true,
            isAvailable: true,
            completionProgress: 0.1,
            stateIndex: 2, // Empty
            errorMessage: nil
        )
    }
}

// MARK: - View Model

@MainActor
final class PPItemEditorHeroViewModel: ObservableObject {
    @Published var snapshot: PPItemEditorHeroSnapshot
    @Published var isHoveringCover: Bool = false
    @Published var isPressed: Bool = false

    var onPickImage: (() -> Void)?
    var onRemoveImageAtIndex: ((Int) -> Void)?
    var onSelectPrimaryImageAtIndex: ((Int) -> Void)?
    var onRetry: (() -> Void)?

    init(snapshot: PPItemEditorHeroSnapshot) {
        self.snapshot = snapshot
    }

    func updateSnapshot(_ newSnapshot: PPItemEditorHeroSnapshot) {
        self.snapshot = newSnapshot
    }

    func triggerImagePick() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPickImage?()
    }
}

// MARK: - Root Responsive Dispatcher

struct PPItemEditorHeroView: View {
    @ObservedObject var viewModel: PPItemEditorHeroViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                PPItemEditorHeroPadStudio(viewModel: viewModel)
            } else {
                PPItemEditorHeroPhoneDeck(viewModel: viewModel)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: viewModel.snapshot.stateIndex)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: viewModel.snapshot.imageCount)
    }
}

// MARK: - iPhone Dedicated Architecture: Mobile Tactile Deck

struct PPItemEditorHeroPhoneDeck: View {
    @ObservedObject var viewModel: PPItemEditorHeroViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isRTL = Language.isRTL()

    var body: some View {
        ZStack {
            // Ambient card background with continuous corners & frosted glow
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.ppElevatedSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    Color(UIColor.ppSurfaceBorder).opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)

            // Dynamic State Switcher
            switch viewModel.snapshot.stateIndex {
            case 1: // Loading / Shimmer
                phoneShimmerState
            case 3: // Error
                phoneErrorState
            default: // Normal or Empty
                phoneContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(viewModel.snapshot.title), \(viewModel.snapshot.subtitle)"))
        .accessibilityHint(Text(NSLocalizedString("Market_AddCoverPhoto", comment: "")))
    }

    // MARK: Normal & Empty Content
    private var phoneContent: some View {
        HStack(spacing: 16) {
            // Sovereign Media Stage (Leading)
            phoneMediaTile

            // Contextual Editorial & Live Telemetry (Trailing)
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
                // Top Telemetry Badges
                HStack(spacing: 6) {
                    // Mode Pill
                    Text(viewModel.snapshot.isCreate ? NSLocalizedString("Market_AddTitle", comment: "") : NSLocalizedString("Market_EditTitle", comment: ""))
                        .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                        .foregroundColor(Color(UIColor.ppPrimary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(UIColor.ppPrimary).opacity(0.12))
                        )

                    // Market Status Beacon
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.snapshot.isPublished ? Color(UIColor.ppSuccess) : Color(UIColor.ppWarning))
                            .frame(width: 6, height: 6)
                        Text(viewModel.snapshot.isPublished ? NSLocalizedString("Market_LiveStatus", comment: "") : NSLocalizedString("Market_DraftStatus", comment: ""))
                            .font(Font.custom("Beiruti-Medium", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(UIColor.ppTextSecondary))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(UIColor.ppBackground).opacity(0.85))
                    )

                    Spacer(minLength: 0)
                }

                // Title
                Text(viewModel.snapshot.itemName.isEmpty ? viewModel.snapshot.title : viewModel.snapshot.itemName)
                    .font(Font.custom("Beiruti-Bold", size: 19, relativeTo: .title3))
                    .foregroundColor(Color(UIColor.ppTextPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Subtitle / Guidance
                Text(viewModel.snapshot.subtitle)
                    .font(Font.custom("Beiruti-Regular", size: 12.5, relativeTo: .footnote))
                    .foregroundColor(Color(UIColor.ppTextSecondary))
                    .lineLimit(2)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)

                Spacer(minLength: 0)

                // Bottom Telemetry & Progress
                HStack(spacing: 12) {
                    // Image Counter Pill
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(UIColor.ppPrimary))
                        Text(String(format: NSLocalizedString("Market_PhotosCountFormat", comment: ""), viewModel.snapshot.imageCount))
                            .font(Font.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption2))
                            .foregroundColor(Color(UIColor.ppTextPrimary))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(UIColor.ppPrimary).opacity(0.08))
                    )

                    // Data Completeness Gauge
                    HStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .stroke(Color(UIColor.ppSurfaceBorder).opacity(0.5), lineWidth: 2.5)
                                .frame(width: 15, height: 15)
                            Circle()
                                .trim(from: 0, to: CGFloat(viewModel.snapshot.completionProgress))
                                .stroke(Color(UIColor.ppPrimary), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 15, height: 15)
                        }
                        Text("\(Int(viewModel.snapshot.completionProgress * 100))%")
                            .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(UIColor.ppTextSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
    }

    // MARK: Media Tile with Camera Badge
    private var phoneMediaTile: some View {
        Button(action: {
            viewModel.triggerImagePick()
        }) {
            ZStack(alignment: .bottomTrailing) {
                // Main Image Container
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(UIColor.ppPrimary).opacity(0.08),
                                    Color(UIColor.ppPrimary).opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)

                    if let localImage = viewModel.snapshot.primaryImage {
                        Image(uiImage: localImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else if let urlStr = viewModel.snapshot.primaryImageURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            case .failure:
                                emptyIllustration
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.ppPrimary)))
                            @unknown default:
                                emptyIllustration
                            }
                        }
                        .frame(width: 96, height: 96)
                    } else {
                        emptyIllustration
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            viewModel.snapshot.primaryImage == nil && (viewModel.snapshot.primaryImageURL?.isEmpty ?? true)
                            ? Color(UIColor.ppPrimary).opacity(0.32)
                            : Color.white.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.2, dash: viewModel.snapshot.primaryImage == nil && (viewModel.snapshot.primaryImageURL?.isEmpty ?? true) ? [4, 3] : [])
                        )
                )
                .shadow(color: Color(UIColor.ppPrimary).opacity(0.14), radius: 10, x: 0, y: 5)

                // Floating Camera Halo Badge with High-Contrast Primary Circle
                ZStack {
                    Circle()
                        .fill(Color(UIColor.ppElevatedSurface))
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)

                    Circle()
                        .fill(Color(UIColor.ppPrimary))
                        .frame(width: 28, height: 28)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(PhoneSpringButtonStyle())
    }

    private var emptyIllustration: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.ppPrimary).opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(UIColor.ppPrimary))
            }

            Text(NSLocalizedString("Market_CoverBadge", comment: ""))
                .font(Font.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                .foregroundColor(Color(UIColor.ppPrimary))
        }
        .frame(width: 96, height: 96)
    }

    // MARK: Phone Shimmer Skeleton
    private var phoneShimmerState: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                .frame(width: 90, height: 90)
                .overlay(ShimmerSweepEffect())

            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                    .frame(width: 70, height: 16)
                    .overlay(ShimmerSweepEffect())

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .overlay(ShimmerSweepEffect())

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.3))
                    .frame(width: 140, height: 14)
                    .overlay(ShimmerSweepEffect())

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.35))
                    .frame(width: 90, height: 18)
                    .overlay(ShimmerSweepEffect())
            }
        }
        .padding(14)
    }

    // MARK: Phone Error State
    private var phoneErrorState: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.ppError).opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(UIColor.ppError))
            }

            VStack(alignment: isRTL ? .trailing : .leading, spacing: 4) {
                Text(viewModel.snapshot.errorMessage ?? NSLocalizedString("Market_UploadError", comment: ""))
                    .font(Font.custom("Beiruti-Bold", size: 14, relativeTo: .body))
                    .foregroundColor(Color(UIColor.ppError))
                    .lineLimit(2)

                Button(action: {
                    viewModel.onRetry?()
                }) {
                    Text(NSLocalizedString("Market_Retry", comment: ""))
                        .font(Font.custom("Beiruti-Bold", size: 12.5, relativeTo: .caption))
                        .foregroundColor(Color(UIColor.ppPrimary))
                        .underline()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

// MARK: - iPad Dedicated Architecture: Panoramic Studio Deck

struct PPItemEditorHeroPadStudio: View {
    @ObservedObject var viewModel: PPItemEditorHeroViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isRTL = Language.isRTL()

    var body: some View {
        ZStack {
            // Panoramic widescreen card background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.ppElevatedSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color(UIColor.ppSurfaceBorder).opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)

            // Dynamic State Switcher
            switch viewModel.snapshot.stateIndex {
            case 1:
                padShimmerState
            case 3:
                padErrorState
            default:
                padContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: iPad Split Studio Content
    private var padContent: some View {
        HStack(spacing: 28) {
            // Leading Studio Canvas (Media & Filmstrip Gallery)
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // Sovereign Cover Preview
                    padCoverPreview

                    // Multi-Photo Filmstrip
                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 8) {
                        Text(NSLocalizedString("Market_SectionImages", comment: ""))
                            .font(Font.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                            .foregroundColor(Color(UIColor.ppTextSecondary))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Add Photo Tile
                                Button(action: {
                                    viewModel.triggerImagePick()
                                }) {
                                    VStack(spacing: 3) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color(UIColor.ppPrimary))
                                        Text(NSLocalizedString("Market_AddPhoto", comment: ""))
                                            .font(Font.custom("Beiruti-Medium", size: 9, relativeTo: .caption2))
                                            .foregroundColor(Color(UIColor.ppPrimary))
                                    }
                                    .frame(width: 54, height: 54)
                                    .background(Color(UIColor.ppPrimary).opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                Color(UIColor.ppPrimary).opacity(0.35),
                                                style: StrokeStyle(lineWidth: 1, dash: [3])
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .hoverEffect(.highlight)

                                // Existing Thumbnails (Remote + Local)
                                ForEach(0..<viewModel.snapshot.allImageURLs.count, id: \.self) { idx in
                                    let urlStr = viewModel.snapshot.allImageURLs[idx]
                                    padThumbnailTile(urlStr: urlStr, localImage: nil, index: idx)
                                }

                                ForEach(0..<viewModel.snapshot.allSelectedImages.count, id: \.self) { idx in
                                    let img = viewModel.snapshot.allSelectedImages[idx]
                                    let overallIdx = viewModel.snapshot.allImageURLs.count + idx
                                    padThumbnailTile(urlStr: nil, localImage: img, index: overallIdx)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(height: 58)
                    }
                }

                // Aspect Ratio & Quality Guideline
                HStack(spacing: 6) {
                    Image(systemName: "aspectratio.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(UIColor.ppPrimary))
                    Text(NSLocalizedString("Market_PhotoGuidance", comment: ""))
                        .font(Font.custom("Beiruti-Medium", size: 11.5, relativeTo: .caption2))
                        .foregroundColor(Color(UIColor.ppTextSecondary))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

            // Vertical Divider
            Rectangle()
                .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                .frame(width: 1)
                .padding(.vertical, 8)

            // Trailing Telemetry & Insight Cockpit
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                // Eyebrow & Category Beacon
                HStack(spacing: 8) {
                    Text(NSLocalizedString("Market_HeroStudioTitle", comment: ""))
                        .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                        .foregroundColor(Color(UIColor.ppPrimary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(UIColor.ppPrimary).opacity(0.12))
                        )

                    if !viewModel.snapshot.categoryName.isEmpty {
                        Text(viewModel.snapshot.categoryName)
                            .font(Font.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(UIColor.ppTextSecondary))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(UIColor.ppBackground))
                            )
                    }

                    Spacer(minLength: 0)

                    // Completion Gauge
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("Market_Completeness", comment: ""))
                            .font(Font.custom("Beiruti-Regular", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(UIColor.ppTextSecondary))
                        Text("\(Int(viewModel.snapshot.completionProgress * 100))%")
                            .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(UIColor.ppPrimary))
                    }
                }

                // Studio Title
                Text(viewModel.snapshot.itemName.isEmpty ? viewModel.snapshot.title : viewModel.snapshot.itemName)
                    .font(Font.custom("Beiruti-Bold", size: 24, relativeTo: .title2))
                    .foregroundColor(Color(UIColor.ppTextPrimary))
                    .lineLimit(1)

                // Seller Insight Card
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(UIColor.ppPrimary))
                        .padding(.top, 2)

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 2) {
                        Text(NSLocalizedString("Market_StudioTipsTitle", comment: ""))
                            .font(Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(UIColor.ppTextPrimary))
                        Text(NSLocalizedString("Market_StudioTipsBody", comment: ""))
                            .font(Font.custom("Beiruti-Regular", size: 11.5, relativeTo: .caption2))
                            .foregroundColor(Color(UIColor.ppTextSecondary))
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.ppBackground).opacity(0.85))
                )

                Spacer(minLength: 0)

                // Quick Action Bar
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.triggerImagePick()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.badge.ellipsis")
                                .font(.system(size: 13, weight: .bold))
                            Text(NSLocalizedString("Market_ReplacePhoto", comment: ""))
                                .font(Font.custom("Beiruti-Bold", size: 13, relativeTo: .subheadline))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(UIColor.ppPrimary))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
        .padding(20)
    }

    // MARK: iPad Cover Preview
    private var padCoverPreview: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.ppPrimary).opacity(0.06))
                    .frame(width: 120, height: 120)

                if let localImage = viewModel.snapshot.primaryImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if let urlStr = viewModel.snapshot.primaryImageURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        default:
                            padEmptyPlaceholder
                        }
                    }
                    .frame(width: 120, height: 120)
                } else {
                    padEmptyPlaceholder
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(UIColor.ppSurfaceBorder).opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            // Cover Star Pill
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(NSLocalizedString("Market_CoverBadge", comment: ""))
                    .font(Font.custom("Beiruti-Bold", size: 10, relativeTo: .caption2))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(UIColor.ppPrimary))
            )
            .offset(x: 8, y: -8)
        }
    }

    private var padEmptyPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(Color(UIColor.ppPrimary).opacity(0.55))
            Text(NSLocalizedString("Market_AddCoverPhoto", comment: ""))
                .font(Font.custom("Beiruti-Medium", size: 11, relativeTo: .caption2))
                .foregroundColor(Color(UIColor.ppPrimary).opacity(0.75))
        }
        .frame(width: 120, height: 120)
    }

    // MARK: Pad Thumbnail Tile
    private func padThumbnailTile(urlStr: String?, localImage: UIImage?, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = localImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let urlStr = urlStr, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(UIColor.ppBackground)
                        }
                    }
                } else {
                    Color(UIColor.ppBackground)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(index == 0 ? Color(UIColor.ppPrimary) : Color(UIColor.ppSurfaceBorder).opacity(0.6), lineWidth: index == 0 ? 1.5 : 0.8)
            )

            // Delete trigger on hover/tap
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.onRemoveImageAtIndex?(index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(UIColor.ppError))
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: 3, y: -3)
        }
        .hoverEffect(.lift)
    }

    // MARK: iPad Shimmer Skeleton
    private var padShimmerState: some View {
        HStack(spacing: 28) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                    .frame(width: 120, height: 120)
                    .overlay(ShimmerSweepEffect())

                VStack(alignment: isRTL ? .trailing : .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                        .frame(width: 60, height: 14)
                        .overlay(ShimmerSweepEffect())

                    HStack(spacing: 8) {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(UIColor.ppSurfaceBorder).opacity(0.35))
                                .frame(width: 54, height: 54)
                                .overlay(ShimmerSweepEffect())
                        }
                    }
                }
            }

            Rectangle()
                .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                .frame(width: 1)
                .padding(.vertical, 8)

            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                    .frame(width: 90, height: 18)
                    .overlay(ShimmerSweepEffect())

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .overlay(ShimmerSweepEffect())

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.ppSurfaceBorder).opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay(ShimmerSweepEffect())
            }
        }
        .padding(20)
    }

    // MARK: iPad Error State
    private var padErrorState: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.ppError).opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(UIColor.ppError))
            }

            VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
                Text(viewModel.snapshot.errorMessage ?? NSLocalizedString("Market_UploadError", comment: ""))
                    .font(Font.custom("Beiruti-Bold", size: 16, relativeTo: .body))
                    .foregroundColor(Color(UIColor.ppError))

                Button(action: {
                    viewModel.onRetry?()
                }) {
                    Text(NSLocalizedString("Market_Retry", comment: ""))
                        .font(Font.custom("Beiruti-Bold", size: 14, relativeTo: .caption))
                        .foregroundColor(Color(UIColor.ppPrimary))
                        .underline()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

// MARK: - Shimmer Sweep Visual Effect

struct ShimmerSweepEffect: View {
    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if reduceMotion {
                Color.white.opacity(0.1)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.38),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase * proxy.size.width * 2)
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1.0
                    }
                }
            }
        }
        .mask(Rectangle())
    }
}

// MARK: - Interactive Button Physics

struct PhoneSpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Objective-C Bridge: PPItemEditorHeroHostView

@objc(PPItemEditorHeroHostView)
@MainActor
public final class PPItemEditorHeroHostView: UIView {
    private var hostingController: UIHostingController<PPItemEditorHeroView>?
    private let viewModel: PPItemEditorHeroViewModel

    @objc public var onPickImage: (() -> Void)? {
        didSet { viewModel.onPickImage = onPickImage }
    }

    @objc public var onRemoveImageAtIndex: ((Int) -> Void)? {
        didSet { viewModel.onRemoveImageAtIndex = onRemoveImageAtIndex }
    }

    @objc public var onSelectPrimaryImageAtIndex: ((Int) -> Void)? {
        didSet { viewModel.onSelectPrimaryImageAtIndex = onSelectPrimaryImageAtIndex }
    }

    @objc public var onRetry: (() -> Void)? {
        didSet { viewModel.onRetry = onRetry }
    }

    @objc public init(snapshot: PPItemEditorHeroSnapshot) {
        self.viewModel = PPItemEditorHeroViewModel(snapshot: snapshot)
        super.init(frame: .zero)
        setupHosting()
    }

    public override init(frame: CGRect) {
        self.viewModel = PPItemEditorHeroViewModel(snapshot: .emptySnapshot(isCreate: true))
        super.init(frame: frame)
        setupHosting()
    }

    required init?(coder: NSCoder) {
        self.viewModel = PPItemEditorHeroViewModel(snapshot: .emptySnapshot(isCreate: true))
        super.init(coder: coder)
        setupHosting()
    }

    private func setupHosting() {
        backgroundColor = .clear
        let root = PPItemEditorHeroView(viewModel: viewModel)
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.hostingController = host
    }

    @objc public func updateSnapshot(_ snapshot: PPItemEditorHeroSnapshot) {
        viewModel.updateSnapshot(snapshot)
    }
}
