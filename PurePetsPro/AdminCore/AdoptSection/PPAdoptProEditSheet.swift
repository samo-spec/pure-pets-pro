//
//  PPAdoptProEditSheet.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Listing Creation & Editing Sheet for Pure Pets Pro.
//  Provides comprehensive traits authoring, photo gallery, health passport toggles, and server validation.
//

import SwiftUI
import PhotosUI

public enum PPAdoptEditMode: Sendable {
    case create
    case edit(PPAdoptListingModel)
}

@MainActor
public struct PPAdoptProEditSheet: View {
    let mode: PPAdoptEditMode
    @StateObject private var store = PPAdoptProStore.shared
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var draft: PPAdoptListingDraft
    @State private var newImageURLString: String = ""
    @State private var isSubmitting: Bool = false
    @State private var localErrorMessage: String?

    public init(mode: PPAdoptEditMode) {
        self.mode = mode
        switch mode {
        case .create:
            _draft = State(initialValue: PPAdoptListingDraft())
        case .edit(let listing):
            _draft = State(initialValue: PPAdoptListingDraft(from: listing))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AdminSurface.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        heroNotice
                        mediaUploadSection
                        basicInfoSection
                        healthPassportSection
                        adoptionConditionsSection
                        locationAndContactSection
                        actionFooter
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? (Language.isRTL() ? "تعديل قائمة التبني" : "Edit Adoption Listing") : (Language.isRTL() ? "إضافة أليف للتبني" : "New Adoption Pet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Language.isRTL() ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                    .font(AdminType.callout)
                    .foregroundStyle(AdminSurface.secondaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submitForm()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 20, height: 20)
                        } else {
                            Text(isEditing ? (Language.isRTL() ? "حفظ" : "Save") : (Language.isRTL() ? "نشر" : "Publish"))
                                .font(AdminType.calloutBold)
                        }
                    }
                    .disabled(isSubmitting || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray.opacity(0.4)
                            : Color(hex: "#E11D48"),
                        in: Capsule()
                    )
                }
            }
            .overlay(alignment: .top) {
                if let error = localErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AdminSurface.crimson)
                        Text(error)
                            .font(AdminType.calloutBold)
                            .foregroundStyle(AdminSurface.primaryText)
                        Spacer()
                        Button { localErrorMessage = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        }
                    }
                    .padding(14)
                    .background(AdminSurface.crimson.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(16)
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
    }

    // MARK: - Hero Notice

    private var heroNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#E11D48"))
            VStack(alignment: .leading, spacing: 3) {
                Text(isEditing ? (Language.isRTL() ? "تحديث بيانات الأليف" : "Update Pet Details") : (Language.isRTL() ? "إنشاء إعلان تبني موثق" : "Create Verified Pet Profile"))
                    .font(AdminType.calloutBold)
                    .foregroundStyle(AdminSurface.primaryText)
                Text(Language.isRTL()
                     ? "املأ التفاصيل بدقة لتمكين العائلات من اتخاذ قرار التبني المسؤول."
                     : "Provide complete details to help families adopt responsibly.")
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(hex: "#E11D48").opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: "#E11D48").opacity(0.18), lineWidth: 0.8))
    }

    // MARK: - Media Upload Section

    private var mediaUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Language.isRTL() ? "صور الأليف" : "Pet Photos", systemImage: "photo.stack.fill")
                .font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)

            if !draft.mediaURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(draft.mediaURLs.enumerated()), id: \.offset) { index, urlString in
                            ZStack(alignment: .topTrailing) {
                                if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }

                                Button {
                                    draft.mediaURLs.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.white, Color.black.opacity(0.6))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }

            // Image URL Input Row
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(Language.isRTL() ? "أدخل رابط صورة (HTTPS)…" : "Paste image URL (HTTPS)…", text: $newImageURLString)
                    .font(AdminType.callout)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Button {
                    let trimmed = newImageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    draft.mediaURLs.append(trimmed)
                    newImageURLString = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(Language.isRTL() ? "إضافة" : "Add")
                        .font(AdminType.captionBold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AdminSurface.primary, in: Capsule())
                }
                .disabled(newImageURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(Language.isRTL() ? "البيانات الأساسية للأليف" : "Basic Information", systemImage: "pawprint.fill")
                .font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)

            // Title / Name Field
            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "اسم أو عنوان القائمة *" : "Pet Name / Title *")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(Language.isRTL() ? "مثال: ميمي - قط شيرازي لطيف" : "e.g. Luna - Gentle Persian Cat", text: $draft.title)
                    .font(AdminType.callout)
                    .padding(12)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Species Picker
            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "فصيلة الأليف" : "Species")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                HStack(spacing: 8) {
                    ForEach([PPAdoptSpecies.dog, PPAdoptSpecies.cat, PPAdoptSpecies.bird, PPAdoptSpecies.other]) { sp in
                        let isSelected = draft.species == sp
                        Button {
                            draft.species = sp
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sp.symbol)
                                Text(sp.localizedTitle)
                            }
                            .font(isSelected ? AdminType.captionBold : AdminType.caption)
                            .foregroundStyle(isSelected ? Color.white : AdminSurface.secondaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(isSelected ? Color(hex: "#E11D48") : AdminSurface.control, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Breed & Gender
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Language.isRTL() ? "السلالة" : "Breed")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    TextField(Language.isRTL() ? "مثال: جولدن ريتريفر" : "e.g. Golden Retriever", text: $draft.breed)
                        .font(AdminType.callout)
                        .padding(12)
                        .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(Language.isRTL() ? "الجنس" : "Gender")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    HStack(spacing: 6) {
                        genderOption(value: "male", title: Language.isRTL() ? "ذكر ♂" : "Male ♂", color: .blue)
                        genderOption(value: "female", title: Language.isRTL() ? "أنثى ♀" : "Female ♀", color: .pink)
                    }
                }
            }

            // Age In Months
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(Language.isRTL() ? "العمر التقريبي:" : "Approximate Age:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    Spacer()
                    Text(String(format: Language.isRTL() ? "%d شهر (%g سنة)" : "%d mo (%g yrs)", draft.ageMonths, Double(draft.ageMonths) / 12.0))
                        .font(AdminType.captionBold.monospacedDigit())
                        .foregroundStyle(AdminSurface.primary)
                }
                Stepper(value: $draft.ageMonths, in: 1...240) {
                    Text(String(format: Language.isRTL() ? "%d شهر" : "%d months", draft.ageMonths))
                        .font(AdminType.callout)
                }
                .padding(8)
                .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Story / Description
            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "قصة الأليف وسلوكه" : "Pet Story & Temperament")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                TextEditor(text: $draft.descriptionText)
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    private func genderOption(value: String, title: String, color: Color) -> some View {
        let isSelected = draft.gender.lowercased() == value
        return Button {
            draft.gender = value
        } label: {
            Text(title)
                .font(isSelected ? AdminType.captionBold : AdminType.caption)
                .foregroundStyle(isSelected ? Color.white : AdminSurface.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? color : AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Health Passport Section

    private var healthPassportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(Language.isRTL() ? "الجواز الصحي والرعاية الطبية" : "Health & Medical Status", systemImage: "cross.case.fill")
                .font(AdminType.headlineBold)
                .foregroundStyle(Color(hex: "#10B981"))

            Toggle(isOn: $draft.isVaccinated) {
                Label(Language.isRTL() ? "تطعيمات مكتملة وموثقة" : "Vaccinations Up-To-Date", systemImage: "checkmark.shield.fill")
                    .font(AdminType.callout)
            }
            .tint(Color(hex: "#10B981"))

            Divider().overlay(AdminSurface.hairline)

            Toggle(isOn: $draft.isNeutered) {
                Label(Language.isRTL() ? "معقم / مخصي" : "Neutered / Spayed", systemImage: "heart.slash.fill")
                    .font(AdminType.callout)
            }
            .tint(Color(hex: "#10B981"))

            Divider().overlay(AdminSurface.hairline)

            Toggle(isOn: $draft.hasPassport) {
                Label(Language.isRTL() ? "يملك دفتر / جواز صحي" : "Pet Passport / Card", systemImage: "book.closed.fill")
                    .font(AdminType.callout)
            }
            .tint(Color(hex: "#10B981"))

            Divider().overlay(AdminSurface.hairline)

            Toggle(isOn: $draft.isMicrochipped) {
                Label(Language.isRTL() ? "مركب له شريحة إلكترونية" : "Microchipped", systemImage: "cpu.fill")
                    .font(AdminType.callout)
            }
            .tint(Color(hex: "#10B981"))

            // Special needs
            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "ملاحظات طبية أو حمية خاصة (اختياري)" : "Medical Notes / Diet (Optional)")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(Language.isRTL() ? "مثال: يحتاج طعاماً خاصاً بالحساسية" : "e.g. Hypoallergenic diet required", text: $draft.specialNeeds)
                    .font(AdminType.callout)
                    .padding(12)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Adoption Conditions Section

    private var adoptionConditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Language.isRTL() ? "شروط التبني للأسر" : "Adoption Requirements", systemImage: "checklist")
                .font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)

            TextField(
                Language.isRTL() ? "مثال: منزل بدون أطفال صغار، التعهد بعدم البيع…" : "e.g. Home with garden, no reselling commitment…",
                text: $draft.adoptionConditions
            )
            .font(AdminType.callout)
            .padding(12)
            .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Location & Contact Section

    private var locationAndContactSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(Language.isRTL() ? "الموقع وبيانات التواصل" : "Location & Contact", systemImage: "mappin.and.ellipse")
                .font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Language.isRTL() ? "المدينة" : "City")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    TextField(Language.isRTL() ? "مثال: الدوحة" : "e.g. Doha", text: $draft.city)
                        .font(AdminType.callout)
                        .padding(12)
                        .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(Language.isRTL() ? "الحي / المنطقة" : "District")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)
                    TextField(Language.isRTL() ? "مثال: الوعب" : "e.g. Al Waab", text: $draft.district)
                        .font(AdminType.callout)
                        .padding(12)
                        .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "رقم الهاتف للتواصل" : "Contact Phone")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(Language.isRTL() ? "مثال: +974 5555 1234" : "e.g. +974 5555 1234", text: $draft.ownerPhone)
                    .font(AdminType.callout)
                    .keyboardType(.phonePad)
                    .padding(12)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(Language.isRTL() ? "اسم الجمعية / المنظمة (اختياري)" : "Organization / Shelter (Optional)")
                    .font(AdminType.captionBold)
                    .foregroundStyle(AdminSurface.secondaryText)
                TextField(Language.isRTL() ? "مثال: ملجأ قطر للأليف" : "e.g. Qatar Animal Rescue", text: $draft.organizationName)
                    .font(AdminType.callout)
                    .padding(12)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Action Footer

    private var actionFooter: some View {
        Button {
            submitForm()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(isEditing ? (Language.isRTL() ? "حفظ التغييرات" : "Save Changes") : (Language.isRTL() ? "نشر قائمة التبني" : "Publish Adoption Listing"))
                    .font(AdminType.calloutBold)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E11D48"), Color(hex: "#BE123C")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color(hex: "#E11D48").opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isSubmitting || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Submission Logic

    private func submitForm() {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            localErrorMessage = Language.isRTL() ? "عنوان القائمة مطلوب." : "Title is required."
            return
        }

        isSubmitting = true
        localErrorMessage = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            switch mode {
            case .create:
                let success = await store.createListing(draft: draft)
                isSubmitting = false
                if success { dismiss() }
            case .edit(let existing):
                let success = await store.updateListing(id: existing.id, draft: draft, expectedVersion: existing.version)
                isSubmitting = false
                if success { dismiss() }
            }
        }
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
