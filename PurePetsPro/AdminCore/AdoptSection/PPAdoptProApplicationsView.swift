//
//  PPAdoptProApplicationsView.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Applications Workspace for Pure Pets Pro.
//  Enables thorough review of family questionnaires, household suitability, and verified transitions.
//

import SwiftUI

public struct PPAdoptProApplicationsView: View {
    let listing: PPAdoptListingModel
    @StateObject private var store = PPAdoptProStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatusFilter: String = ""
    @State private var selectedAppForAction: PPAdoptApplicationModel?
    @State private var pendingAction: String = ""
    @State private var transitionReason: String = ""
    @State private var showingActionAlert = false

    public init(listing: PPAdoptListingModel) {
        self.listing = listing
    }

    private var filteredApplications: [PPAdoptApplicationModel] {
        if selectedStatusFilter.isEmpty {
            return store.applications
        }
        return store.applications.filter { $0.status.lowercased() == selectedStatusFilter }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AdminSurface.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroSummaryCard
                        statusFilterRibbon

                        if store.applications.isEmpty {
                            emptyStateCard
                        } else {
                            ForEach(filteredApplications) { application in
                                applicationCard(application)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(Language.isRTL() ? "طلبات التبني المقدمة" : "Adoption Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Language.isRTL() ? "إغلاق" : "Done") {
                        dismiss()
                    }
                    .font(AdminType.calloutBold)
                    .foregroundStyle(AdminSurface.primary)
                }
            }
            .alert(
                Language.isRTL() ? "تأكيد الإجراء على الطلب" : "Confirm Application Action",
                isPresented: $showingActionAlert
            ) {
                TextField(Language.isRTL() ? "سبب أو ملاحظة القرار (اختياري)…" : "Reason / Note (optional)…", text: $transitionReason)
                Button(Language.isRTL() ? "إلغاء" : "Cancel", role: .cancel) {}
                Button(Language.isRTL() ? "تأكيد" : "Confirm") {
                    if let app = selectedAppForAction {
                        Task {
                            _ = await store.transitionApplication(
                                id: app.id,
                                action: pendingAction,
                                reason: transitionReason,
                                expectedVersion: app.version
                            )
                        }
                    }
                }
            } message: {
                Text(actionConfirmationMessage)
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear {
            store.observeApplications(for: listing.id)
        }
    }

    private var actionConfirmationMessage: String {
        switch pendingAction {
        case "approve":
            return Language.isRTL() ? "هل أنت متأكد من قبول هذا الطلب وتأهيل الأسرة لاستلام الأليف؟" : "Approve this applicant for pet placement?"
        case "reject":
            return Language.isRTL() ? "هل أنت متأكد من رفض هذا الطلب؟" : "Reject this application?"
        case "schedule_handover":
            return Language.isRTL() ? "الانتقال لمرحلة تسليم الأليف واستلام الأسرة له؟" : "Transition to physical handover stage?"
        case "complete":
            return Language.isRTL() ? "تأكيد اكتمال عملية التبني بنجاح؟" : "Mark adoption as successfully completed?"
        default:
            return Language.isRTL() ? "تأكيد تغيير حالة الطلب؟" : "Confirm status transition?"
        }
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title)
                    .font(AdminType.headlineBold)
                    .foregroundStyle(AdminSurface.primaryText)
                Text(String(format: Language.isRTL() ? "إجمالي الطلبات المسجلة: %d" : "Total Applications: %d", store.applications.count))
                    .font(AdminType.caption)
                    .foregroundStyle(AdminSurface.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }

    // MARK: - Status Filter Ribbon

    private var statusFilterRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(id: "", title: Language.isRTL() ? "الكل" : "All", count: store.applications.count)
                filterPill(id: "submitted", title: Language.isRTL() ? "جديدة" : "Submitted", count: store.applications.filter { $0.status == "submitted" }.count)
                filterPill(id: "under_review", title: Language.isRTL() ? "قيد المراجعة" : "Under Review", count: store.applications.filter { $0.status == "under_review" }.count)
                filterPill(id: "approved", title: Language.isRTL() ? "مقبولة" : "Approved", count: store.applications.filter { $0.status == "approved" }.count)
                filterPill(id: "completed", title: Language.isRTL() ? "مكتملة" : "Completed", count: store.applications.filter { $0.status == "completed" }.count)
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(id: String, title: String, count: Int) -> some View {
        let isSelected = selectedStatusFilter == id
        return Button {
            selectedStatusFilter = id
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(isSelected ? AdminType.captionBold : AdminType.caption)
                if count > 0 {
                    Text("\(count)")
                        .font(AdminType.caption2Bold.monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.indigo.opacity(0.12), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.white : AdminSurface.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? Color.indigo : AdminSurface.surface, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : AdminSurface.hairline, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Application Card

    private func applicationCard(_ application: PPAdoptApplicationModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Applicant name, Status badge
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.indigo)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(application.applicantName)
                            .font(AdminType.calloutBold)
                            .foregroundStyle(AdminSurface.primaryText)
                        if let date = application.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(AdminType.caption2)
                                .foregroundStyle(AdminSurface.secondaryText)
                        }
                    }
                }
                Spacer()
                Text(application.statusDisplay)
                    .font(AdminType.caption2Bold)
                    .foregroundStyle(application.statusTone)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(application.statusTone.opacity(0.12), in: Capsule())
            }

            // Contact Row
            if !application.applicantPhone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text(application.applicantPhone)
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.primaryText)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel://\(application.applicantPhone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(Language.isRTL() ? "اتصال" : "Call")
                            .font(AdminType.caption2Bold)
                            .foregroundStyle(Color(hex: "#10B981"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#10B981").opacity(0.1), in: Capsule())
                    }
                }
            }

            // Message
            if !application.message.isEmpty {
                Text(application.message)
                    .font(AdminType.callout)
                    .foregroundStyle(AdminSurface.primaryText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AdminSurface.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Questionnaire answers
            if !application.questionAnswers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.isRTL() ? "إجابات الاستبيان والملاءمة:" : "Questionnaire Answers:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)

                    ForEach(application.questionAnswers, id: \.self) { qa in
                        HStack(alignment: .top, spacing: 6) {
                            Text(qa.label)
                                .font(AdminType.caption)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .frame(minWidth: 90, alignment: .leading)
                            Text(qa.answer)
                                .font(AdminType.captionBold)
                                .foregroundStyle(AdminSurface.primaryText)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminSurface.control.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if !application.answers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Language.isRTL() ? "إجابات الاستبيان والملاءمة:" : "Questionnaire Answers:")
                        .font(AdminType.captionBold)
                        .foregroundStyle(AdminSurface.secondaryText)

                    ForEach(Array(application.answers.keys.sorted()), id: \.self) { key in
                        if let val = application.answers[key], !val.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Text(localizedQuestionKey(key))
                                    .font(AdminType.caption)
                                    .foregroundStyle(AdminSurface.secondaryText)
                                    .frame(minWidth: 90, alignment: .leading)
                                Text(val)
                                    .font(AdminType.captionBold)
                                    .foregroundStyle(AdminSurface.primaryText)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminSurface.control.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Divider().overlay(AdminSurface.hairline)

            // Action Buttons
            HStack(spacing: 8) {
                if application.status == "submitted" {
                    actionButton(title: Language.isRTL() ? "بدء المراجعة" : "Start Review", action: "start_review", tone: .indigo, app: application)
                }

                if application.status == "under_review" || application.status == "submitted" {
                    actionButton(title: Language.isRTL() ? "قبول الطلب" : "Approve", action: "approve", tone: Color(hex: "#10B981"), app: application)
                    actionButton(title: Language.isRTL() ? "رفض" : "Reject", action: "reject", tone: Color(hex: "#EF4444"), app: application)
                }

                if application.status == "approved" {
                    actionButton(title: Language.isRTL() ? "جدولة التسليم" : "Schedule Handover", action: "schedule_handover", tone: .blue, app: application)
                }

                if application.status == "handover" {
                    actionButton(title: Language.isRTL() ? "إتمام التبني بنجاح" : "Complete Adoption", action: "complete", tone: Color(hex: "#10B981"), app: application)
                }
            }
        }
        .padding(16)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    private func actionButton(title: String, action: String, tone: Color, app: PPAdoptApplicationModel) -> some View {
        Button {
            selectedAppForAction = app
            pendingAction = action
            transitionReason = ""
            showingActionAlert = true
        } label: {
            Text(title)
                .font(AdminType.captionBold)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(tone, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func localizedQuestionKey(_ key: String) -> String {
        switch key {
        case "householdType": return Language.isRTL() ? "نوع السكن" : "Housing"
        case "householdMembers": return Language.isRTL() ? "أفراد المنزل" : "Members"
        case "children": return Language.isRTL() ? "الأطفال" : "Children"
        case "existingPets": return Language.isRTL() ? "حيوانات أخرى" : "Pets"
        case "petExperience": return Language.isRTL() ? "الخبرة السابقة" : "Experience"
        case "dailyRoutine": return Language.isRTL() ? "الروتين اليومي" : "Routine"
        case "carePlan": return Language.isRTL() ? "خطة الرعاية" : "Care Plan"
        default: return key
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(Color.indigo.opacity(0.5))
                .padding(.top, 16)
            Text(Language.isRTL() ? "لا توجد طلبات تبني مسجلة بعد" : "No Applications Yet")
                .font(AdminType.calloutBold)
                .foregroundStyle(AdminSurface.primaryText)
            Text(Language.isRTL()
                 ? "ستظهر هنا جميع طلبات الأسر الراغبة في تبني هذا الأليف بمجرد تقديمها."
                 : "Applications submitted for this pet will appear here for review.")
                .font(AdminType.caption)
                .foregroundStyle(AdminSurface.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AdminSurface.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AdminSurface.hairline, lineWidth: 0.8))
    }
}
