//
//  PPAdoptProControlCenterView.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Community Adoption Control Center for Pure Pets Pro.
//  Studio-crafted sanctuary interface with fluid motion, live telemetry, and direct parity with Admin.
//

import SwiftUI

@MainActor
public struct PPAdoptProControlCenterView: View {
    @StateObject private var store = PPAdoptProStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingCreateSheet = false
    @State private var selectedForDetail: PPAdoptListingModel?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AdminSurface.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        sanctuaryHeroCard
                        statusRibbon
                        speciesAndSearchBar

                        if store.isLoading && store.listings.isEmpty {
                            loadingShimmerView
                        } else if store.filteredListings.isEmpty {
                            emptyStateView
                        } else {
                            listingsGrid
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 24 : 16)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await store.refresh()
                }
            }
            .navigationTitle(Language.isRTL() ? "مكتب التبني ورعاية الحيوانات" : "Community Adoption Sanctuary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingCreateSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(Language.isRTL() ? "قائمة جديدة" : "New Listing")
                                .font(AdminType.calloutBold)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E11D48"), Color(hex: "#BE123C")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: Color(hex: "#E11D48").opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                PPAdoptProEditSheet(mode: .create)
            }
            .sheet(item: $selectedForDetail) { listing in
                PPAdoptProDetailView(listing: listing)
            }
            .overlay(alignment: .top) {
                if let message = store.errorMessage {
                    feedbackBanner(text: message, isError: true)
                } else if let message = store.successMessage {
                    feedbackBanner(text: message, isError: false)
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear {
            store.start()
        }
    }

    // MARK: - Sanctuary Hero Header

    private var sanctuaryHeroCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#E11D48").opacity(0.18), AdminSurface.primary.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "#E11D48").opacity(0.28), lineWidth: 0.8)
                        .frame(width: 56, height: 56)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "#E11D48"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(Language.isRTL() ? "إدارة التبني ورعاية الألياف" : "Adoption & Foster Sanctuary")
                            .font(AdminType.title3Bold)
                            .foregroundStyle(AdminSurface.primaryText)
                    }

                    Text(Language.isRTL()
                         ? "نشر القوائم ومراجعة طلبات الأسر والتحقق من الشروط الصحية بكل طمأنينة."
                         : "Publish listings, review applications, and ensure healthy verified placements.")
                        .font(AdminType.caption)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            // Metric Counters Bar
            HStack(spacing: 10) {
                metricPill(
                    title: Language.isRTL() ? "الإجمالي" : "Total",
                    count: store.totalCount,
                    icon: "pawprint.fill",
                    color: AdminSurface.primary
                )
                metricPill(
                    title: Language.isRTL() ? "منشور" : "Published",
                    count: store.publishedCount,
                    icon: "checkmark.seal.fill",
                    color: Color(hex: "#10B981")
                )
                metricPill(
                    title: Language.isRTL() ? "مراجعة" : "Pending",
                    count: store.pendingCount,
                    icon: "clock.badge.exclamationmark.fill",
                    color: Color(hex: "#F59E0B")
                )
                metricPill(
                    title: Language.isRTL() ? "تم التبني" : "Adopted",
                    count: store.adoptedCount,
                    icon: "house.and.flag.fill",
                    color: Color(hex: "#059669")
                )
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AdminSurface.hairline, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    private func metricPill(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(AdminType.headlineBold.monospacedDigit())
                    .foregroundStyle(AdminSurface.primaryText)
                Text(title)
                    .font(AdminType.caption2)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Status Ribbon

    private var statusRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PPAdoptListingStatus.allCases) { status in
                    let isSelected = store.statusFilter == status.rawValue
                    let countForStatus: Int = {
                        if status == .all { return store.totalCount }
                        return store.listings.filter { $0.status == status }.count
                    }()

                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
                            store.statusFilter = status.rawValue
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: status.symbol)
                                .font(.system(size: 11, weight: .semibold))
                            Text(status.localizedTitle)
                                .font(isSelected ? AdminType.calloutBold : AdminType.callout)
                            if countForStatus > 0 {
                                Text("\(countForStatus)")
                                    .font(AdminType.caption2Bold.monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.25) : status.tone.opacity(0.14), in: Capsule())
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : AdminSurface.secondaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(
                            isSelected
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [status.tone, status.tone.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(AdminSurface.surface),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? Color.clear : AdminSurface.hairline, lineWidth: 0.8)
                        )
                        .shadow(color: isSelected ? status.tone.opacity(0.28) : Color.clear, radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Species & Search Bar

    private var speciesAndSearchBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(
                    Language.isRTL() ? "ابحث باسم الأليف، السلالة، أو المدينة…" : "Search by pet name, breed, or city…",
                    text: $store.searchText
                )
                .font(AdminType.callout)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AdminSurface.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AdminSurface.hairline, lineWidth: 0.8)
            )

            // Species Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PPAdoptSpecies.allCases) { species in
                        let isSelected = store.speciesFilter == species.rawValue
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
                                store.speciesFilter = species.rawValue
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: species.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(species.localizedTitle)
                                    .font(isSelected ? AdminType.captionBold : AdminType.caption)
                            }
                            .foregroundStyle(isSelected ? Color.white : AdminSurface.secondaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                isSelected ? Color(hex: "#E11D48") : AdminSurface.surface,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? Color.clear : AdminSurface.hairline, lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Listings Grid

    private var listingsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 340 : 300), spacing: 16)],
            spacing: 16
        ) {
            ForEach(store.filteredListings) { listing in
                PPAdoptProCardView(listing: listing) {
                    selectedForDetail = listing
                }
            }
        }
    }

    // MARK: - Loading Shimmer

    private var loadingShimmerView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AdminSurface.surface)
                    .frame(height: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AdminSurface.hairline, lineWidth: 0.8)
                    )
                    .opacity(0.6)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#E11D48").opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E11D48"))
            }
            .padding(.top, 24)

            Text(Language.isRTL() ? "لا توجد قوائم تبني مطابقة" : "No Matching Adoption Listings")
                .font(AdminType.title3Bold)
                .foregroundStyle(AdminSurface.primaryText)

            Text(Language.isRTL()
                 ? "جرّب تغيير مرشح الحالة، أو نوع الأليف، أو أضف أول قائمة تبني جديدة."
                 : "Try changing the status or species filters, or create a new adoption listing.")
                .font(AdminType.callout)
                .foregroundStyle(AdminSurface.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !store.statusFilter.isEmpty || !store.speciesFilter.isEmpty || !store.searchText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.statusFilter = ""
                    store.speciesFilter = ""
                    store.searchText = ""
                } label: {
                    Text(Language.isRTL() ? "إعادة تعيين المرشحات" : "Reset Filters")
                        .font(AdminType.calloutBold)
                        .foregroundStyle(AdminSurface.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AdminSurface.primary.opacity(0.1), in: Capsule())
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Toast Banner

    private func feedbackBanner(text: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? AdminSurface.crimson : AdminSurface.emerald)
            Text(text)
                .font(AdminType.calloutBold)
                .foregroundStyle(AdminSurface.primaryText)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button {
                store.clearMessages()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .padding(14)
        .background(
            isError ? AdminSurface.crimson.opacity(0.12) : AdminSurface.emerald.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isError ? AdminSurface.crimson.opacity(0.3) : AdminSurface.emerald.opacity(0.3), lineWidth: 0.8)
        )
        .padding(16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                store.clearMessages()
            }
        }
    }
}

// MARK: - Adoption Card View

public struct PPAdoptProCardView: View {
    let listing: PPAdoptListingModel
    let onSelect: () -> Void

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                mediaCover
                cardContent
                Divider().overlay(AdminSurface.hairline)
                cardFooter
            }
            .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(listing.isFeatured ? Color.orange.opacity(0.5) : AdminSurface.hairline, lineWidth: listing.isFeatured ? 1.5 : 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleCardButtonStyle())
    }

    private var mediaCover: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let url = listing.primaryMediaURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            mediaPlaceholder
                        @unknown default:
                            mediaPlaceholder
                        }
                    }
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    mediaPlaceholder
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                }

                // Vignette gradient
                LinearGradient(
                    colors: [Color.black.opacity(0.70), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 60)

                // Location badge on media
                if !listing.locationDisplay.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(listing.locationDisplay)
                            .font(AdminType.captionBold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }

            // Top Badges
            HStack {
                statusBadge
                Spacer()
                if listing.isFeatured {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(Language.isRTL() ? "مميز" : "Featured")
                            .font(AdminType.caption2Bold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.orange, in: Capsule())
                    .shadow(color: Color.orange.opacity(0.35), radius: 4, x: 0, y: 2)
                }
            }
            .padding(12)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(listing.status.tone)
                .frame(width: 7, height: 7)
            Text(listing.status.localizedTitle)
                .font(AdminType.caption2Bold)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.65), in: Capsule())
        .overlay(Capsule().stroke(listing.status.tone.opacity(0.4), lineWidth: 0.8))
    }

    private var mediaPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E11D48").opacity(0.12), AdminSurface.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: listing.species.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E11D48").opacity(0.6))
                Text(listing.species.localizedTitle)
                    .font(AdminType.caption2)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(listing.title)
                    .font(AdminType.headlineBold)
                    .foregroundStyle(AdminSurface.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if listing.ageMonths > 0 {
                    Text(String(format: Language.isRTL() ? "%d شهر" : "%d mo", listing.ageMonths))
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                }
            }

            // Tag chips
            HStack(spacing: 6) {
                chip(
                    text: listing.breed.isEmpty ? listing.species.localizedTitle : listing.breed,
                    symbol: "tag.fill",
                    color: AdminSurface.primary
                )
                if !listing.genderDisplay.isEmpty {
                    chip(
                        text: listing.genderDisplay,
                        symbol: nil,
                        color: listing.gender.lowercased().contains("male") ? Color.blue : Color.pink
                    )
                }
                if listing.isVaccinated {
                    chip(
                        text: Language.isRTL() ? "مطعم" : "Vaccinated",
                        symbol: "checkmark.shield.fill",
                        color: Color(hex: "#10B981")
                    )
                }
            }

            if !listing.descriptionText.isEmpty {
                Text(listing.descriptionText)
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            if listing.applicationCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.indigo)
                    Text(String(format: Language.isRTL() ? "%d طلبات تبني مسجلة" : "%d Applications", listing.applicationCount))
                        .font(AdminType.captionBold)
                        .foregroundStyle(Color.indigo)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
    }

    private var cardFooter: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: listing.organizationName.isEmpty ? "person.fill" : "building.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminSurface.secondaryText)
                Text(listing.publisherDisplay)
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Text(Language.isRTL() ? "الملف الكامل" : "View Dossier")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.primary)
                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AdminSurface.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AdminSurface.control.opacity(0.35))
    }

    private func chip(text: String, symbol: String?, color: Color) -> some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(AdminType.caption2Bold)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Tactile Button Style

public struct ScaleCardButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

fileprivate extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 206, 17, 85)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
