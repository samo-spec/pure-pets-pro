//
//  PPAddEditVetStudioScreen.swift
//  PurePetsPro
//
//  First-Principles Invention: Category-Defining Clinical Credentialing Studio & Living Medical Dossier.
//  Reinvented from absolute first principles in SwiftUI with tactile archetype switching,
//  holographic clinical pass preview, multi-spectrum specialty matrix, consultation economics,
//  and resilient Firebase persistence.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Specialty Catalog Token

public struct PPSpecialtyTagItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let titleAr: String
    public let titleEn: String
    public let symbol: String

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }
}

public enum PPSpecialtyCatalog {
    public static let items: [PPSpecialtyTagItem] = [
        PPSpecialtyTagItem(id: "surgery", titleAr: "#طب_وجراحة_عامة", titleEn: "#GeneralSurgery", symbol: "cross.case.fill"),
        PPSpecialtyTagItem(id: "internal", titleAr: "#باطنية_بيطرية", titleEn: "#InternalMedicine", symbol: "stethoscope"),
        PPSpecialtyTagItem(id: "dental", titleAr: "#أسنان_وجراحة_فم", titleEn: "#DentalSurgery", symbol: "mouth.fill"),
        PPSpecialtyTagItem(id: "dermatology", titleAr: "#جلدية_وحساسية", titleEn: "#Dermatology", symbol: "allergens"),
        PPSpecialtyTagItem(id: "vaccines", titleAr: "#لقاحات_وتحصين", titleEn: "#Vaccinations", symbol: "syringe.fill"),
        PPSpecialtyTagItem(id: "emergency", titleAr: "#طوارئ_وعناية_مركزة", titleEn: "#EmergencyCare", symbol: "staroflife.fill"),
        PPSpecialtyTagItem(id: "radiology", titleAr: "#سونار_وأشعة", titleEn: "#Ultrasound", symbol: "waveform.path.ecg"),
        PPSpecialtyTagItem(id: "nutrition", titleAr: "#تغذية_علاجية", titleEn: "#ClinicalNutrition", symbol: "leaf.fill"),
        PPSpecialtyTagItem(id: "ophthalmology", titleAr: "#عيون_بيطرية", titleEn: "#Ophthalmology", symbol: "eye.fill"),
        PPSpecialtyTagItem(id: "orthopedics", titleAr: "#عظام_ومفاصل", titleEn: "#Orthopedics", symbol: "figure.walk")
    ]
}

// MARK: - Species Target Item

public struct PPSpeciesTargetItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let emoji: String
    public let titleAr: String
    public let titleEn: String

    public var localizedTitle: String {
        Language.isRTL() ? titleAr : titleEn
    }
}

public enum PPSpeciesCatalog {
    public static let items: [PPSpeciesTargetItem] = [
        PPSpeciesTargetItem(id: 1, emoji: "🐶", titleAr: "الكلاب", titleEn: "Dogs"),
        PPSpeciesTargetItem(id: 2, emoji: "🐱", titleAr: "القطط", titleEn: "Cats"),
        PPSpeciesTargetItem(id: 3, emoji: "🦜", titleAr: "الطيور", titleEn: "Birds"),
        PPSpeciesTargetItem(id: 4, emoji: "🐰", titleAr: "القوارض والأرانب", titleEn: "Small Pets"),
        PPSpeciesTargetItem(id: 5, emoji: "🐎", titleAr: "الخيول", titleEn: "Horses"),
        PPSpeciesTargetItem(id: 6, emoji: "🦎", titleAr: "حيوانات نادرة", titleEn: "Exotics")
    ]
}

// MARK: - Main Sovereign Studio Screen

public struct PPAddEditVetStudioScreen: View {
    private let vetToEdit: PPVetModel?
    private let onDismiss: () -> Void

    // Core Form State
    @State private var type: PPVetType = .personal
    @State private var title: String = ""
    @State private var licenseNumber: String = ""
    @State private var descriptionText: String = ""
    @State private var phone: String = ""
    @State private var whatsapp: String = ""
    @State private var vetCost: String = ""
    @State private var availableDate: Date = Date()
    @State private var petMainKindID: Int = 1
    @State private var selectedSpecialtyTags: Set<String> = []
    @State private var selectedSpeciesIDs: Set<Int> = [1, 2]
    @State private var emergency247: Bool = false
    @State private var homeVisitAvailable: Bool = false

    // Media State
    @State private var selectedImage: UIImage? = nil
    @State private var existingLogoURL: String? = nil
    @State private var showPhotoPicker: Bool = false
    @State private var photoPickerItem: PhotosPickerItem? = nil

    // UI Feedback & Persistence State
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var pulseBeacon: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(vetToEdit: PPVetModel?, onDismiss: @escaping () -> Void) {
        self.vetToEdit = vetToEdit
        self.onDismiss = onDismiss

        if let vet = vetToEdit {
            _type = State(initialValue: vet.type)
            _title = State(initialValue: vet.title)
            _descriptionText = State(initialValue: vet.descriptionText)
            _phone = State(initialValue: vet.phone)
            _whatsapp = State(initialValue: vet.whatsapp)
            _vetCost = State(initialValue: vet.vetCost > 0 ? String(format: "%.0f", vet.vetCost) : "")
            _petMainKindID = State(initialValue: vet.petMainKindID > 0 ? vet.petMainKindID : 1)
            _existingLogoURL = State(initialValue: vet.logoURL.isEmpty ? nil : vet.logoURL)
            if let date = vet.availableDate {
                _availableDate = State(initialValue: date)
            }

            // Extract tags from description
            var extractedTags: Set<String> = []
            let desc = vet.descriptionText
            for tag in PPSpecialtyCatalog.items {
                if desc.contains(tag.titleAr) || desc.contains(tag.titleEn) {
                    extractedTags.insert(tag.id)
                }
            }
            _selectedSpecialtyTags = State(initialValue: extractedTags)

            let animals = vet.animalTypes
            if !animals.isEmpty {
                let ids = Set(animals.compactMap { Int($0) })
                _selectedSpeciesIDs = State(initialValue: ids.isEmpty ? [vet.petMainKindID > 0 ? vet.petMainKindID : 1] : ids)
            } else {
                _selectedSpeciesIDs = State(initialValue: [vet.petMainKindID > 0 ? vet.petMainKindID : 1])
            }
        }
    }

    private var isEditing: Bool {
        guard let vet = vetToEdit else { return false }
        return !vet.vetID.isEmpty
    }

    private var isClinic: Bool {
        type == .company
    }

    private var primaryAccent: Color {
        isClinic ? Color(red: 0.12, green: 0.65, blue: 0.92) : Color(red: 0.08, green: 0.72, blue: 0.65)
    }

    private var primaryBrandPink: Color {
        Color(red: 0.94, green: 0.25, blue: 0.45)
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var surfaceBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.14)
            : Color(red: 0.98, green: 0.98, blue: 0.99)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.17, blue: 0.20)
            : Color.white
    }

    private var hairlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.06)
    }

    public var body: some View {
        ZStack {
            // Ambient Canvas
            studioAtmosphere
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Cockpit
                cockpitNavBar

                // Scrollable Studio Workspace
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Error Filament Banner
                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        // 1. Archetype Dual-Chamber Switcher
                        archetypeSelectorCard

                        // 2. Sovereign Holographic Medical Pass Preview
                        holographicPassCard

                        // 3. Identity & Accreditation Card
                        identityAccreditationCard

                        // 4. Clinical Specialty Matrix
                        specialtyMatrixCard

                        // 5. Medical Editorial Bio & Fast Prompt Chips
                        bioEditorialCard

                        // 6. Consultation Economics & Quick Steppers
                        consultationEconomicsCard

                        // 7. Direct Telehealth & 24/7 Emergency Horizon
                        telehealthContactCard

                        // 8. Target Animal Species Horizon
                        speciesTargetCard

                        // Inset for bottom floating dock
                        Color.clear.frame(height: 84)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }

            // Floating Sovereign Action Catalyst Dock
            VStack {
                Spacer()
                catalystActionDock
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // Loading / Saving HUD
            if isSaving {
                savingHUDOverlay
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = image
                    }
                }
            }
        }
    }

    // MARK: - Atmospheric Canvas

    private var studioAtmosphere: some View {
        ZStack {
            surfaceBackground

            // Top Ambient Radiance tuned to active archetype
            GeometryReader { proxy in
                let w = proxy.size.width
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryAccent.opacity(colorScheme == .dark ? 0.18 : 0.09),
                                primaryBrandPink.opacity(colorScheme == .dark ? 0.12 : 0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.75
                        )
                    )
                    .frame(width: w * 1.2, height: w * 1.2)
                    .offset(x: Language.isRTL() ? (w * 0.3) : -(w * 0.3), y: -w * 0.4)
                    .blur(radius: 35)
            }
        }
    }

    // MARK: - Cockpit Navigation Bar

    private var cockpitNavBar: some View {
        HStack(alignment: .center, spacing: 12) {
            // Dismiss Back Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            }) {
                Image(systemName: Language.isRTL() ? "arrow.right" : "arrow.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: 40, height: 40)
                    .background(cardBackground, in: Circle())
                    .overlay(Circle().strokeBorder(hairlineColor, lineWidth: 0.75))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isEditing
                     ? (Language.isRTL() ? "تعديل الملف الإكلينيكي" : "Edit Clinical Dossier")
                     : (Language.isRTL() ? "إضافة طبيب بيطري" : "Add Veterinarian")
                )
                .font(PPFont.bold(20, relativeTo: .title3))
                .foregroundStyle(Color(UIColor.label))
                .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(primaryAccent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseBeacon ? 1.25 : 0.85)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseBeacon)

                    Text(isEditing
                         ? (Language.isRTL() ? "اعتماد رسمي معتمد في قطر" : "Official Qatar Licensed Provider")
                         : (Language.isRTL() ? "تسجيل جهة وممارس بيطري جديد" : "New Clinical Practitioner Registration")
                    )
                    .font(PPFont.medium(11, relativeTo: .caption2))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }

            Spacer(minLength: 0)

            // Dynamic Archetype Pill
            HStack(spacing: 4) {
                Image(systemName: isClinic ? "building.2.fill" : "stethoscope")
                    .font(.system(size: 11, weight: .bold))
                Text(isClinic
                     ? (Language.isRTL() ? "عيادة بيطرية" : "Clinic")
                     : (Language.isRTL() ? "طبيب أخصائي" : "Specialist")
                )
                .font(PPFont.bold(11, relativeTo: .caption2))
            }
            .foregroundStyle(primaryAccent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(primaryAccent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(primaryAccent.opacity(0.24), lineWidth: 0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            surfaceBackground.opacity(0.92)
                .background(.ultraThinMaterial)
        )
        .onAppear {
            DispatchQueue.main.async {
                pulseBeacon = true
            }
        }
    }

    // MARK: - 1. Archetype Dual-Chamber Switcher

    private var archetypeSelectorCard: some View {
        HStack(spacing: 10) {
            // Chamber 1: Individual Specialist Doctor
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.76)) {
                    type = .personal
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(type == .personal ? primaryAccent : Color(UIColor.secondarySystemGroupedBackground))
                        Image(systemName: "stethoscope")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(type == .personal ? .white : Color(UIColor.secondaryLabel))
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(Language.isRTL() ? "طبيب شخصي" : "Individual Doctor")
                            .font(PPFont.bold(14, relativeTo: .subheadline))
                            .foregroundStyle(type == .personal ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                        Text(Language.isRTL() ? "ممارس مستقل معتمد" : "Licensed Specialist")
                            .font(PPFont.regular(10.5, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(type == .personal ? primaryAccent : hairlineColor, lineWidth: type == .personal ? 1.5 : 0.75)
                )
                .shadow(color: type == .personal ? primaryAccent.opacity(0.18) : .clear, radius: 8, y: 2)
            }
            .buttonStyle(PlainButtonStyle())

            // Chamber 2: Clinic / Hospital
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.76)) {
                    type = .company
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(type == .company ? primaryAccent : Color(UIColor.secondarySystemGroupedBackground))
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(type == .company ? .white : Color(UIColor.secondaryLabel))
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(Language.isRTL() ? "عيادة ومجمع" : "Clinic / Hospital")
                            .font(PPFont.bold(14, relativeTo: .subheadline))
                            .foregroundStyle(type == .company ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                        Text(Language.isRTL() ? "مركز طبي مجهز" : "Full Clinical Facility")
                            .font(PPFont.regular(10.5, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(type == .company ? primaryAccent : hairlineColor, lineWidth: type == .company ? 1.5 : 0.75)
                )
                .shadow(color: type == .company ? primaryAccent.opacity(0.18) : .clear, radius: 8, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - 2. Holographic Sovereign Medical Pass Preview

    private var holographicPassCard: some View {
        VStack(spacing: 0) {
            // Top Verification Ribbon
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.12))

                Text(Language.isRTL()
                     ? "بيور بيتس • الاعتماد الإكلينيكي المعتمد لدولة قطر"
                     : "PUREPETS ACCREDITED CLINICAL PRACTICE · QATAR"
                )
                .font(PPFont.bold(10.5, relativeTo: .caption2))
                .foregroundStyle(primaryAccent)

                Spacer(minLength: 0)

                Text(isClinic
                     ? (Language.isRTL() ? "منشأة طبية" : "FACILITY")
                     : (Language.isRTL() ? "طبيب مرخص" : "DOCTOR")
                )
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundStyle(primaryAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(primaryAccent.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(primaryAccent.opacity(0.08))

            // Pass Content Body
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Avatar Squircle with Camera Picker Trigger
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showPhotoPicker = true
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = selectedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            } else if let urlStr = existingLogoURL, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        avatarFallback
                                    }
                                }
                                .frame(width: 74, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            } else {
                                avatarFallback
                            }

                            // Camera Mini-Button
                            ZStack {
                                Circle()
                                    .fill(primaryAccent)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 3, y: 3)
                            .shadow(color: Color.black.opacity(0.15), radius: 3)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Doctor Metadata Core
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? (Language.isRTL() ? "اسم الطبيب / المركز البيطري" : "Doctor or Clinic Name")
                             : title
                        )
                        .font(PPFont.bold(18, relativeTo: .headline))
                        .foregroundStyle(Color(UIColor.label))
                        .lineLimit(2)

                        HStack(spacing: 6) {
                            // Consultation Fee Pill
                            let feeNum = Double(vetCost) ?? 0
                            HStack(spacing: 3) {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 9.5))
                                Text(feeNum > 0
                                     ? "\(Int(feeNum)) \(Language.get("QAR", alter: "ر.ق"))"
                                     : (Language.isRTL() ? "كشفية مجانية" : "Free")
                                )
                                .font(PPFont.bold(11, relativeTo: .caption2))
                            }
                            .foregroundStyle(Color(red: 0.08, green: 0.72, blue: 0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.08, green: 0.72, blue: 0.65).opacity(0.12), in: Capsule())

                            // Emergency readiness dot
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(phone.isEmpty ? Color.orange : Color.green)
                                    .frame(width: 6, height: 6)
                                Text(phone.isEmpty
                                     ? (Language.isRTL() ? "أدخل رقم الهاتف" : "Phone required")
                                     : (Language.isRTL() ? "استشارات مفعلة" : "Direct Contact")
                                )
                                .font(PPFont.medium(10.5, relativeTo: .caption2))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                            }
                        }

                        // Availability Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                            Text(dateFormatter.string(from: availableDate))
                                .font(PPFont.regular(10.5, relativeTo: .caption2))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Selected Specialties Horizontal Filament
                if !selectedSpecialtyTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(PPSpecialtyCatalog.items.filter { selectedSpecialtyTags.contains($0.id) }) { item in
                                HStack(spacing: 3) {
                                    Image(systemName: item.symbol)
                                        .font(.system(size: 8))
                                    Text(item.localizedTitle)
                                        .font(PPFont.bold(10, relativeTo: .caption2))
                                }
                                .foregroundStyle(primaryAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(primaryAccent.opacity(0.10), in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            primaryAccent.opacity(0.40),
                            hairlineColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05), radius: 12, y: 4)
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    primaryAccent.opacity(0.18),
                    primaryBrandPink.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: isClinic ? "building.2.fill" : "stethoscope")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(primaryAccent)
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: Language.isRTL() ? "ar_QA" : "en_US")
        return df
    }

    // MARK: - 3. Identity & Accreditation Card

    private var identityAccreditationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "الهوية المهنية وتصنيف الممارسة" : "Professional Identity & Accreditation",
                subtitle: Language.isRTL() ? "الاسم الرسمي المعتمد، ونمط الترخيص البيطري" : "Official licensed name and practitioner credentials",
                symbol: "person.text.rectangle.fill"
            )

            // Name Field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "اسم الطبيب / المركز البيطري المعتمد" : "Doctor / Veterinary Clinic Name")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Text("*")
                        .font(PPFont.bold(13))
                        .foregroundStyle(primaryBrandPink)
                }

                HStack(spacing: 10) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField(
                        Language.isRTL() ? "د. محمد أحمد (أو مجمع بيوربتس البيطري)" : "Dr. Name or Hospital Name",
                        text: $title
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))

                    if !title.isEmpty {
                        Button(action: { title = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // License Number Field
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "رقم الترخيص الطبي البيطري (اختياري)" : "Veterinary License Number (Optional)")
                    .font(PPFont.bold(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.label))

                HStack(spacing: 10) {
                    Image(systemName: "doc.text.badge.checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField(
                        Language.isRTL() ? "مثال: QTR-VET-8842" : "e.g. QTR-VET-8842",
                        text: $licenseNumber
                    )
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 4. Clinical Specialty Matrix

    private var specialtyMatrixCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "التخصصات الإكلينيكية والخدمات" : "Clinical Specializations",
                subtitle: Language.isRTL() ? "اختر وسوم التخصص المباشرة لعرضها للمراجعين" : "Toggle accredited clinical specialties for patient discovery",
                symbol: "cross.vial.fill"
            )

            // Flow grid of tags
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(PPSpecialtyCatalog.items) { item in
                    let isSelected = selectedSpecialtyTags.contains(item.id)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                            if isSelected {
                                selectedSpecialtyTags.remove(item.id)
                            } else {
                                selectedSpecialtyTags.insert(item.id)
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.localizedTitle)
                                .font(PPFont.bold(12, relativeTo: .caption))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .heavy))
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? primaryAccent : primaryAccent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isSelected ? primaryAccent : primaryAccent.opacity(0.22), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 5. Medical Editorial Bio & Fast Prompt Chips

    private var bioEditorialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Language.isRTL() ? "النبذة الطبية والخدمات المقدمة" : "Medical Bio & Services",
                subtitle: Language.isRTL() ? "اكتب نبذة طبية موثقة وخبرات العيادة للمراجعين" : "Write an accredited bio and clinic background",
                symbol: "text.quote"
            )

            // Fast Insertion Prompt Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    promptChip(title: Language.isRTL() ? "+ سنوات الخبرة" : "+ Years of Experience",
                               snippet: Language.isRTL() ? " خبرة إكلينيكية تمتد لأكثر من 10 سنوات في طب وجراحة الحيوانات الأليفة." : " Over 10 years of clinical experience.")
                    promptChip(title: Language.isRTL() ? "+ العمليات والتعقيم" : "+ Surgery & Spay",
                               snippet: Language.isRTL() ? " مجهز بأحدث أجهزة التخدير الآمن وعمليات التعقيم والجراحة العامة." : " Equipped with modern surgical suite.")
                    promptChip(title: Language.isRTL() ? "+ الزيارات المنزلية" : "+ Home Visits",
                               snippet: Language.isRTL() ? " تتوفر خدمة الكشف والرعاية البيطرية المنزلية للحالات الخاصة." : " Home veterinary visits available.")
                }
            }

            // Text Area
            ZStack(alignment: .topLeading) {
                if descriptionText.isEmpty {
                    Text(Language.isRTL()
                         ? "اكتب نبذة عن التخصص، المؤهلات والخبرات السابقة، والخدمات المتوفرة بالعيادة..."
                         : "Detail credentials, prior clinical experience, diagnostic tools, and hospital amenities..."
                    )
                    .font(PPFont.regular(13.5, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                TextEditor(text: $descriptionText)
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(minHeight: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))

            // Character Counter
            HStack {
                Spacer()
                Text("\(descriptionText.count) / 500")
                    .font(PPFont.medium(11, relativeTo: .caption2))
                    .foregroundStyle(descriptionText.count > 500 ? Color.red : Color(UIColor.secondaryLabel))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func promptChip(title: String, snippet: String) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if descriptionText.isEmpty {
                descriptionText = snippet.trimmingCharacters(in: .whitespaces)
            } else {
                descriptionText += snippet
            }
        }) {
            Text(title)
                .font(PPFont.bold(11, relativeTo: .caption2))
                .foregroundStyle(primaryAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(primaryAccent.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(primaryAccent.opacity(0.20), lineWidth: 0.75))
        }
    }

    // MARK: - 6. Consultation Economics & Quick Steppers

    private var consultationEconomicsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "الرسوم الاستشارية والجدول الزمني" : "Consultation Fee & Availability",
                subtitle: Language.isRTL() ? "تحديد رسوم الكشفية بالريال القطري وموعد التوفر" : "Set QAR consultation fees and appointment availability",
                symbol: "banknote.fill"
            )

            // Direct Fee Field
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "رسوم الكشفية والاستشارة (ر.ق)" : "Consultation Fee (QAR)")
                    .font(PPFont.bold(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.label))

                HStack(spacing: 10) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField("150", text: $vetCost)
                        .keyboardType(.decimalPad)
                        .font(PPFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color(UIColor.label))

                    Text(Language.get("QAR", alter: "ر.ق QAR"))
                        .font(PPFont.bold(12, relativeTo: .caption))
                        .foregroundStyle(primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryAccent.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // Quick Stepper Chip Row
            HStack(spacing: 8) {
                stepperChip(label: Language.isRTL() ? "مجاني" : "Free", delta: 0, isZero: true)
                stepperChip(label: "+25", delta: 25)
                stepperChip(label: "+50", delta: 50)
                stepperChip(label: "+100", delta: 100)
            }

            // Clinic Availability Date
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "موعد توفر الحجز في العيادة" : "Available From Date")
                    .font(PPFont.bold(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.label))

                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    DatePicker("", selection: $availableDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_US"))

                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    private func stepperChip(label: String, delta: Double, isZero: Bool = false) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if isZero {
                vetCost = "0"
            } else {
                let current = Double(vetCost) ?? 0
                vetCost = String(format: "%.0f", current + delta)
            }
        }) {
            Text(label)
                .font(PPFont.bold(12, relativeTo: .caption))
                .foregroundStyle(primaryAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(primaryAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(primaryAccent.opacity(0.20), lineWidth: 0.75))
        }
    }

    // MARK: - 7. Direct Telehealth & 24/7 Emergency Horizon

    private var telehealthContactCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "الاتصال السريع واستشارات الطوارئ" : "Direct Emergency Communications",
                subtitle: Language.isRTL() ? "أرقام الهاتف المباشر والواتساب للاستشارات السريعة" : "Direct phone line and official WhatsApp inquiries",
                symbol: "phone.circle.fill"
            )

            // Direct Phone Field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Language.isRTL() ? "رقم الهاتف المباشر للطوارئ" : "Direct Emergency Phone")
                        .font(PPFont.bold(12.5, relativeTo: .caption))
                        .foregroundStyle(Color(UIColor.label))
                    Text("*")
                        .font(PPFont.bold(13))
                        .foregroundStyle(primaryBrandPink)
                }

                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                        .frame(width: 24)

                    TextField(
                        Language.isRTL() ? "+974 XXXXXXXX" : "+974 XXXXXXXX",
                        text: $phone
                    )
                    .keyboardType(.phonePad)
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))
                    .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // WhatsApp Field
            VStack(alignment: .leading, spacing: 6) {
                Text(Language.isRTL() ? "رقم الواتساب الرسمي (اختياري)" : "Official WhatsApp Number (Optional)")
                    .font(PPFont.bold(12.5, relativeTo: .caption))
                    .foregroundStyle(Color(UIColor.label))

                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.15, green: 0.75, blue: 0.35))
                        .frame(width: 24)

                    TextField(
                        Language.isRTL() ? "+974 XXXXXXXX" : "+974 XXXXXXXX",
                        text: $whatsapp
                    )
                    .keyboardType(.phonePad)
                    .font(PPFont.medium(14, relativeTo: .body))
                    .foregroundStyle(Color(UIColor.label))
                    .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
            }

            // 24/7 Emergency Toggle
            Toggle(isOn: $emergency247) {
                HStack(spacing: 10) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "استقبال طوارئ 24 ساعة" : "24/7 Emergency Readiness")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(UIColor.label))
                        Text(Language.isRTL() ? "جاهزية للرد والتعامل مع الحالات الحرجة" : "Available for critical out-of-hours care")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.red))
            .padding(.top, 4)

            // Home Visit Toggle
            Toggle(isOn: $homeVisitAvailable) {
                HStack(spacing: 10) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(primaryAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.isRTL() ? "توفر خدمة الزيارة والكشف المنزلي" : "Home Visits Available")
                            .font(PPFont.bold(13, relativeTo: .subheadline))
                            .foregroundStyle(Color(UIColor.label))
                        Text(Language.isRTL() ? "إمكانية إرسال طبيب بيطري لمنزل العميل" : "Veterinarian can visit patient's home")
                            .font(PPFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: primaryAccent))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - 8. Target Animal Species Horizon

    private var speciesTargetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: Language.isRTL() ? "تصنيف فصائل الحيوانات المعتمدة" : "Target Animal Species",
                subtitle: Language.isRTL() ? "حدد أنواع وفصائل الحيوانات المؤهلة للاستقبال" : "Select species treated at this clinical practice",
                symbol: "pawprint.fill"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(PPSpeciesCatalog.items) { item in
                    let isSelected = selectedSpeciesIDs.contains(item.id)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                            if isSelected {
                                if selectedSpeciesIDs.count > 1 {
                                    selectedSpeciesIDs.remove(item.id)
                                }
                            } else {
                                selectedSpeciesIDs.insert(item.id)
                            }
                            if let first = selectedSpeciesIDs.first {
                                petMainKindID = first
                            }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(item.emoji)
                                .font(.system(size: 22))
                            Text(item.localizedTitle)
                                .font(PPFont.bold(11, relativeTo: .caption2))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? primaryAccent.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? primaryAccent : hairlineColor, lineWidth: isSelected ? 1.5 : 0.75)
                        )
                        .foregroundStyle(isSelected ? primaryAccent : Color(UIColor.label))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hairlineColor, lineWidth: 0.75))
    }

    // MARK: - Section Header Reusable Primitive

    private func sectionHeader(title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(primaryAccent.opacity(0.12))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(primaryAccent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PPFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color(UIColor.label))
                Text(subtitle)
                    .font(PPFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Floating Sovereign Action Catalyst Dock

    private var catalystActionDock: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(hairlineColor)

            Button(action: saveVeterinarian) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(isEditing
                             ? (Language.isRTL() ? "حفظ التحديثات الطبية" : "Save Clinical Updates")
                             : (Language.isRTL() ? "اعتماد وتسجيل الطبيب" : "Register & License Doctor")
                        )
                        .font(PPFont.bold(16, relativeTo: .headline))
                        Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                            .font(.system(size: 12, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isFormValid
                                ? LinearGradient(colors: [primaryBrandPink, primaryBrandPink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(color: isFormValid ? primaryBrandPink.opacity(0.35) : .clear, radius: 10, y: 3)
            }
            .disabled(!isFormValid || isSaving)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(
            surfaceBackground.opacity(0.92)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Saving HUD Overlay

    private var savingHUDOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text(isEditing
                     ? (Language.isRTL() ? "جارٍ تحديث الملف الطبي..." : "Updating Clinical Dossier...")
                     : (Language.isRTL() ? "جارٍ اعتماد وتسجيل الطبيب..." : "Licensing & Registering Doctor...")
                )
                .font(PPFont.bold(14, relativeTo: .subheadline))
                .foregroundStyle(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }

    // MARK: - Error Banner

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.red)
            Text(text)
                .font(PPFont.medium(12.5, relativeTo: .caption))
                .foregroundStyle(Color.red)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.red)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.red.opacity(0.25), lineWidth: 0.75))
    }

    // MARK: - Save Logic & Firebase Persistence

    private func saveVeterinarian() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errorMessage = Language.isRTL() ? "يرجى كتابة اسم الطبيب أو العيادة" : "Please enter doctor or clinic name"
            return
        }

        let model = vetToEdit != nil ? (vetToEdit!.copy() as! PPVetModel) : PPVetModel()
        model.title = trimmedTitle
        model.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        model.whatsapp = whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)

        // Synthesize description with tags if any
        var finalDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedTags = PPSpecialtyCatalog.items.filter { selectedSpecialtyTags.contains($0.id) }
        let tagsHeader = selectedTags.map(\.localizedTitle).joined(separator: " ")
        if !tagsHeader.isEmpty && !finalDesc.contains(tagsHeader) {
            finalDesc = "\(tagsHeader)\n\(finalDesc)"
        }
        model.descriptionText = finalDesc

        model.vetCost = Double(vetCost) ?? 0
        model.availableDate = availableDate
        model.petMainKindID = petMainKindID
        model.type = type
        model.animalTypes = selectedSpeciesIDs.map { String($0) }
        model.readyToContact = (!phone.isEmpty || !whatsapp.isEmpty)

        if !isEditing {
            model.canEditProfile = true
            model.canPostServices = true
            model.canPostMedicines = false
            model.verificationStatus = "pending"
        }

        isSaving = true
        errorMessage = nil

        let completionBlock: (Error?) -> Void = { error in
            Task { @MainActor in
                self.isSaving = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.onDismiss()
                    }
                }
            }
        }

        if isEditing {
            PPVetManager.shared().updateVet(model, image: selectedImage, completion: completionBlock)
        } else {
            PPVetManager.shared().addVet(model, image: selectedImage, completion: completionBlock)
        }
    }
}

// MARK: - UIKit Objective-C Hosting Bridge Controller

@objc(PPAddEditVetStudioHostingController)
public final class PPAddEditVetStudioHostingController: UIViewController {
    private let vetToEdit: PPVetModel?
    private let onDismissHandler: (() -> Void)?
    private var hostingController: UIHostingController<PPAddEditVetStudioScreen>?

    @objc public init(vetToEdit: PPVetModel?, onDismiss: (() -> Void)? = nil) {
        self.vetToEdit = vetToEdit
        self.onDismissHandler = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        let studioView = PPAddEditVetStudioScreen(
            vetToEdit: self.vetToEdit,
            onDismiss: { [weak self] in
                if let handler = self?.onDismissHandler {
                    handler()
                } else if let nav = self?.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true, completion: nil)
                }
            }
        )

        let host = UIHostingController(rootView: studioView)
        self.hostingController = host

        self.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }
}
