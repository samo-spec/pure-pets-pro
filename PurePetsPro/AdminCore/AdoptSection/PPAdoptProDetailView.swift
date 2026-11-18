//
//  PPAdoptProDetailView.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Adoption Dossier & Inspection View for Pure Pets Pro.
//  Presents rich media gallery, verified health passport, applicant queue, and authoritative transitions.
//

import SwiftUI

@MainActor
public struct PPAdoptProDetailView: View {
    let listing: PPAdoptListingModel
    @StateObject private var store = PPAdoptProStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingApplicationsSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTransitionReasonAlert = false
    @State private var pendingTransitionAction: String?
    @State private var transitionReason: String = ""

    public init(listing: PPAdoptListingModel) {
        self.listing = listing
    }

    private var currentListing: PPAdoptListingModel {
        store.listings.first(where: { $0.id == listing.id }) ?? listing
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AdminSurface.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        mediaGallerySection
                        lifecycleStatusBar
                        quickActionBar
                        petProfileCard
                        healthPassportCard
                        locationAndPublisherCard
                        applicationsPreviewCard
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(Language.isRTL() ? "ملف الأليف والتبني" : "Adoption Dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Language.isRTL() ? "إغلاق" : "Done") {
                        dismiss()
                    }
                    .font(AdminType.calloutBold)
                    .foregroundStyle(AdminSurface.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label(Language.isRTL() ? "تعديل البيانات" : "Edit Listing", systemImage: "pencil")
                        }

                        Button {
                            showingApplicationsSheet = true
                        } label: {
                            Label(Language.isRTL() ? "طلبات التبني" : "Applications", systemImage: "doc.text.fill")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(Language.isRTL() ? "حذف القائمة" : "Delete Listing", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AdminSurface.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                PPAdoptProEditSheet(mode: .edit(currentListing))
            }
            .sheet(isPresented: $showingApplicationsSheet) {
                PPAdoptProApplicationsView(listing: currentListing)
            }
            .alert(Language.isRTL() ? "حذف قائمة التبني؟" : "Delete Adoption Listing?", isPresented: $showingDeleteConfirmation) {
                Button(Language.isRTL() ? "إلغاء" : "Cancel", role: .cancel) {}
                Button(Language.isRTL() ? "تأكيد الحذف" : "Delete", role: .destructive) {
                    Task {
                        let success = await store.deleteListing(id: currentListing.id, expectedVersion: currentListing.version)
                        if success { dismiss() }
                    }
                }
            } message: {
                Text(Language.isRTL()
                     ? "سيتم أرشفة وحذف هذه القائمة ولن تظهر بعد الآن في نتائج البحث."
                     : "This listing will be archived and will no longer appear in public searches.")
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }

    // MARK: - Media Gallery

    private var mediaGallerySection: some View {
        VStack(spacing: 8) {
            if !currentListing.mediaURLs.isEmpty {
                TabView {
                    ForEach(currentListing.mediaURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure, .empty:
                                    photoPlaceholder
                                @unknown default:
                                    photoPlaceholder
                                }
                            }
                            .frame(height: 240)
                            .clipped()
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            } else {
                photoPlaceholder
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E11D48").opacity(0.15), AdminSurface.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: currentListing.species.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E11D48").opacity(0.7))
                Text(currentListing.title)
                    .font(AdminType.headline)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
    }

    // MARK: - Lifecycle Status Bar

    private var lifecycleStatusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(currentListing.status.tone)
                    .frame(width: 8, height: 8)
                Text(currentListing.status.localizedTitle)
                    .font(AdminType.calloutBold)
                    .foregroundStyle(currentListing.status.tone)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(currentListing.status.tone.opacity(0.12), in: Capsule())

            Spacer()

            Text(String(format: Language.isRTL() ? "الإصدار %d" : "v%d", currentListing.version))
                .font(AdminType.captionBold.monospacedDigit())
                .foregroundStyle(AdminSurface.secondaryText)

            if let updated = currentListing.updatedAt ?? currentListing.createdAt {
                Text(updated.formatted(date: .abbreviated, time: .shortened))
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .padding(14)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Quick Action Bar

    private var quickActionBar: some View {
        HStack(spacing: 10) {
            // Status Transitions Menu
            Menu {
                if currentListing.status != .published {
                    Button {
                        performTransition("publish")
                    } label: {
                        Label(Language.isRTL() ? "نشر كقائمة نشطة" : "Publish", systemImage: "checkmark.seal.fill")
                    }
                }

                if currentListing.status != .paused {
                    Button {
                        performTransition("pause")
                    } label: {
                        Label(Language.isRTL() ? "إيقاف مؤقت (إخفاء)" : "Pause (Hide)", systemImage: "pause.circle.fill")
                    }
                }

                if currentListing.status != .adopted {
                    Button {
                        performTransition("mark_adopted")
                    } label: {
                        Label(Language.isRTL() ? "تحديد كمتبنى" : "Mark as Adopted", systemImage: "house.and.flag.fill")
                    }
                }

                if currentListing.status != .applicationsClosed {
                    Button {
                        performTransition("close_applications")
                    } label: {
                        Label(Language.isRTL() ? "إغلاق استقبال الطلبات" : "Close Applications", systemImage: "lock.fill")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                    Text(Language.isRTL() ? "تغيير الحالة" : "Change Status")
                        .font(AdminType.calloutBold)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    LinearGradient(
                        colors: [AdminSurface.primary, AdminSurface.primaryPressed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: AdminSurface.primary.opacity(0.28), radius: 6, x: 0, y: 3)
            }

            // Edit Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingEditSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                    Text(Language.isRTL() ? "تعديل" : "Edit")
                        .font(AdminType.calloutBold)
                }
                .foregroundStyle(AdminSurface.primaryText)
                .frame(minWidth: 90, minHeight: 44)
                .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
            }
        }
    }

    private func performTransition(_ action: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            _ = await store.transitionListing(
                id: currentListing.id,
                action: action,
                reason: "Changed via Pro Adoption Workspace",
                expectedVersion: currentListing.version
            )
        }
    }

    // MARK: - Pet Profile Card

    private var petProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentListing.title)
                        .font(AdminType.title3Bold)
                        .foregroundStyle(AdminSurface.primaryText)
                    Text(currentListing.breed.isEmpty ? currentListing.species.localizedTitle : currentListing.breed)
                        .font(AdminType.callout)
                        .foregroundStyle(AdminSurface.secondaryText)
                }
                Spacer()
                if !currentListing.genderDisplay.isEmpty {
                    Text(currentListing.genderDisplay)
                        .font(AdminType.calloutBold)
                        .foregroundStyle(currentListing.gender.lowercased().contains("male") ? Color.blue : Color.pink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (currentListing.gender.lowercased().contains("male") ? Color.blue : Color.pink).opacity(0.12),
                            in: Capsule()
                        )
                }
            }

            Divider().overlay(AdminSurface.hairline)

            // Bio / Description
            if !currentListing.descriptionText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.isRTL() ? "قصة الأليف وسلوكه:" : "Pet Story & Temperament:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    Text(currentListing.descriptionText)
                        .font(AdminType.body)
                        .foregroundStyle(AdminSurface.primaryText)
                        .lineSpacing(4)
                }
            }

            // Trait Badges
            HStack(spacing: 8) {
                if currentListing.ageMonths > 0 {
                    traitBadge(
                        title: String(format: Language.isRTL() ? "%d شهر" : "%d mo", currentListing.ageMonths),
                        icon: "calendar",
                        color: .purple
                    )
                }
                traitBadge(
                    title: currentListing.species.localizedTitle,
                    icon: currentListing.species.symbol,
                    color: AdminSurface.primary
                )
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
    }

    private func traitBadge(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(AdminType.captionBold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
    }

    // MARK: - Health Passport Card

    private var healthPassportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                Language.isRTL() ? "الجواز الصحي والرعاية الطبية" : "Health & Medical Passport",
                systemImage: "cross.case.fill"
            )
            .font(AdminType.headlineBold)
            .foregroundStyle(Color(hex: "#10B981"))

            // Health Matrix 2x2 Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                healthCheckRow(
                    title: Language.isRTL() ? "التطعيمات" : "Vaccinations",
                    isVerified: currentListing.isVaccinated,
                    activeLabel: Language.isRTL() ? "مكتملة" : "Completed",
                    inactiveLabel: Language.isRTL() ? "غير مؤكد" : "Unverified"
                )
                healthCheckRow(
                    title: Language.isRTL() ? "التعقيم / الخصي" : "Neutered / Spayed",
                    isVerified: currentListing.isNeutered,
                    activeLabel: Language.isRTL() ? "نعم" : "Yes",
                    inactiveLabel: Language.isRTL() ? "لا" : "No"
                )
                healthCheckRow(
                    title: Language.isRTL() ? "الجواز الصحي" : "Pet Passport",
                    isVerified: currentListing.hasPassport,
                    activeLabel: Language.isRTL() ? "متوفر" : "Available",
                    inactiveLabel: Language.isRTL() ? "غير متوفر" : "None"
                )
                healthCheckRow(
                    title: Language.isRTL() ? "الشريحة الإلكترونية" : "Microchip",
                    isVerified: currentListing.isMicrochipped,
                    activeLabel: Language.isRTL() ? "مركبة" : "Fitted",
                    inactiveLabel: Language.isRTL() ? "بدون شريحة" : "None"
                )
            }

            if !currentListing.specialNeeds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Language.isRTL() ? "احتياجات رعاية خاصة:" : "Special Needs:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    Text(currentListing.specialNeeds)
                        .font(AdminType.callout)
                        .foregroundStyle(Color.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !currentListing.adoptionConditions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Language.isRTL() ? "شروط التبني المحددة:" : "Adoption Requirements:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    Text(currentListing.adoptionConditions)
                        .font(AdminType.callout)
                        .foregroundStyle(AdminSurface.primaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    private func healthCheckRow(title: String, isVerified: Bool, activeLabel: String, inactiveLabel: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isVerified ? Color(hex: "#10B981") : AdminSurface.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
                Text(isVerified ? activeLabel : inactiveLabel)
                    .font(AdminType.calloutBold)
                    .foregroundStyle(isVerified ? AdminSurface.primaryText : AdminSurface.secondaryText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isVerified ? Color(hex: "#10B981").opacity(0.08) : AdminSurface.control.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Location & Publisher Card

    private var locationAndPublisherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Language.isRTL() ? "الموقع والجهة المسؤولة" : "Location & Publisher", systemImage: "mappin.and.ellipse")
                .font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)

            if !currentListing.locationDisplay.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AdminSurface.primary)
                    Text(currentListing.locationDisplay)
                        .font(AdminType.calloutBold)
                        .foregroundStyle(AdminSurface.primaryText)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: currentListing.organizationName.isEmpty ? "person.fill" : "building.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AdminSurface.secondaryText)
                Text(currentListing.publisherDisplay)
                    .font(AdminType.callout)
                    .foregroundStyle(AdminSurface.primaryText)
            }

            if !currentListing.ownerPhone.isEmpty {
                Button {
                    if let url = URL(string: "tel://\(currentListing.ownerPhone)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(currentListing.ownerPhone)
                            .font(AdminType.calloutBold)
                        Spacer()
                        Text(Language.isRTL() ? "اتصال" : "Call")
                            .font(AdminType.captionBold)
                    }
                    .foregroundStyle(Color(hex: "#10B981"))
                    .padding(12)
                    .background(Color(hex: "#10B981").opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Applications Preview Card

    private var applicationsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(Language.isRTL() ? "طلبات التبني المقدمة" : "Adoption Applications", systemImage: "doc.text.fill")
                    .font(AdminType.headlineBold)
                    .foregroundStyle(Color.indigo)
                Spacer()
                Text("\(currentListing.applicationCount)")
                    .font(AdminType.calloutBold.monospacedDigit())
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
            }

            Text(Language.isRTL()
                 ? "راجع استمارات الأسر المتقدمة وتوافق المنزل وخطة الرعاية لاتخاذ قرار التسكين."
                 : "Review family applications, home suitability, and care routines to approve matching.")
                .font(AdminType.caption)
                .foregroundStyle(AdminSurface.secondaryText)

            Button {
                showingApplicationsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text(Language.isRTL() ? "فتح سجل الطلبات" : "Open Applications Workspace")
                        .font(AdminType.calloutBold)
                    Image(systemName: Language.isRTL() ? "arrow.left" : "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.indigo)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
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
