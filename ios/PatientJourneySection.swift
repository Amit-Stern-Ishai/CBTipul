import SwiftUI

/// Consecutive recorded session types, never a measure of clinical progress.
struct PatientJourneyGroup: Identifiable {
    var sessions: [Session]
    var id: UUID { sessions[0].id }
    var type: SessionType? { sessions[0].type }
    var title: String { type.map(L10n.label(for:)) ?? L10n.sessionTypeNone }

    static func groups(from sessions: [Session], now: Date = .now, calendar: Calendar = .current) -> [Self] {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let ordered = sessions.filter { $0.date < endOfToday }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        var result: [Self] = []
        for session in ordered {
            if let last = result.indices.last, result[last].type == session.type {
                result[last].sessions.append(session)
            } else { result.append(Self(sessions: [session])) }
        }
        return result
    }
}

struct PatientJourneyRoute: Hashable, Identifiable {
    var groupID: UUID?
    var id: String { groupID?.uuidString ?? "all" }
}

struct PatientJourneySection: View {
    let patient: Patient
    var inHeader = false
    let onOpen: (UUID?) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // RTL lays chronological stages from older on the right to latest on the left.
    private var groups: [PatientJourneyGroup] { PatientJourneyGroup.groups(from: patient.sessions) }
    private var accent: Color { PatientAvatarColor.background(for: patient.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
                if inHeader {
                    Text(L10n.patientJourneyTitle)
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.headerInk)
                        .accessibilityAddTraits(.isHeader)
                } else {
                Button { onOpen(nil) } label: {
                    HStack {
                        Text(L10n.patientJourneyTitle).font(inHeader ? .subheadline.weight(.bold) : .headline)
                        Spacer()
                        Image(systemName: "chevron.forward").font(.caption)
                    }
                    .foregroundStyle(inHeader ? Theme.headerInk : Theme.textBright).frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("patient.journey.full")
                }
                if groups.isEmpty {
                    Text(L10n.patientJourneyEmpty).font(.subheadline).foregroundStyle(Theme.textBody)
                } else if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(groups.reversed())) { group in stage(group, horizontal: false) }
                    }
                } else if groups.count <= 4 {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups) { group in stage(group, horizontal: true).frame(maxWidth: .infinity) }
                    }
                } else {
                    ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            // Give scrolling a physical left origin; keep Hebrew content RTL.
                            ForEach(Array(groups.reversed())) { group in
                                stage(group, horizontal: true)
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .containerRelativeFrame(.horizontal, count: 4, spacing: 0).id(group.id)
                            }
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .defaultScrollAnchor(.leading)
                    .scrollIndicators(.hidden)
                    .onAppear { if let latest = groups.last { proxy.scrollTo(latest.id, anchor: .center) } }
                    .onChange(of: groups.map(\.id)) { _, _ in
                        if let latest = groups.last { proxy.scrollTo(latest.id, anchor: .center) }
                    }
                    .accessibilityIdentifier("patient.journey.stages")
                    }
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, inHeader ? 10 : 0)
        .padding(.vertical, inHeader ? 6 : 0)
        .background {
            if inHeader { RoundedRectangle(cornerRadius: 14).fill(Theme.isPaper ? Theme.surface : Color.black.opacity(0.16)) }
        }
        .overlay {
            if inHeader { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.headerLine, lineWidth: 1) }
        }
    }

    private func icon(for group: PatientJourneyGroup) -> String {
        switch group.type {
        case .intake: "person.crop.rectangle"
        case .psychoEducation: "graduationcap"
        case .firstPhoneCall: "phone"
        default: "doc.text"
        }
    }

    private func stage(_ group: PatientJourneyGroup, horizontal: Bool) -> some View {
        Button { onOpen(nil) } label: {
            let layout = horizontal ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                ZStack {
                    if horizontal {
                        HStack(spacing: 0) {
                            Rectangle().fill(group.id == groups.first?.id ? Color.clear : accent.opacity(0.8))
                            Rectangle().fill(group.id == groups.last?.id ? Color.clear : accent.opacity(0.8))
                        }.frame(height: 3)
                    }
                    Image(systemName: icon(for: group)).font(.system(size: horizontal ? 15 : 16, weight: .medium))
                        .frame(width: horizontal ? 26 : 36, height: horizontal ? 26 : 36)
                        .background(group.id == groups.last?.id ? accent : (Theme.isPaper ? Theme.elevated : PatientAvatarColor.headerBackground(for: patient.id)), in: Circle())
                        .foregroundStyle(group.id == groups.last?.id ? PatientAvatarColor.foreground(for: patient.id) : Theme.headerInk)
                        .overlay { Circle().strokeBorder(accent, lineWidth: group.id == groups.last?.id ? 3 : 1.5) }
                }.frame(height: horizontal ? 26 : 36).frame(maxWidth: horizontal ? .infinity : 36)
                    .accessibilityHidden(true)
                VStack(alignment: horizontal ? .center : .leading, spacing: horizontal ? 2 : 4) {
                    Text(group.title).font(.caption.weight(.semibold)).foregroundStyle(inHeader ? Theme.headerInk : Theme.textBright)
                        .multilineTextAlignment(horizontal ? .center : .leading)
                    Text(L10n.patientJourneyCount(group.sessions.count)).font(.caption).foregroundStyle(inHeader ? Theme.headerInk.opacity(0.85) : Theme.textBody)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 0)
                if !horizontal { Spacer(minLength: 0) }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(group.title + ", " + L10n.patientJourneyCount(group.sessions.count))
        .accessibilityIdentifier("patient.journey.stage." + group.id.uuidString)
    }
}

/// Latest treatment stage first, without session editing or a second session list.
struct PatientJourneyHistory: View {
    let patient: Patient
    private var groups: [PatientJourneyGroup] { Array(PatientJourneyGroup.groups(from: patient.sessions).reversed()) }
    private var accent: Color { PatientAvatarColor.background(for: patient.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(patient.displayName).font(.title2.bold()).foregroundStyle(Theme.textBright)
                if groups.isEmpty {
                    Text(L10n.patientJourneyEmpty).foregroundStyle(Theme.textBody)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 0) {
                                    Circle().fill(accent).frame(width: 16, height: 16)
                                        .overlay { Circle().strokeBorder(Theme.textBody.opacity(0.5), lineWidth: 1) }
                                    Rectangle().fill(Theme.borderDefault)
                                        .frame(width: 1).frame(maxHeight: .infinity)
                                        .opacity(group.id == groups.last?.id ? 0 : 1)
                                }.frame(width: 16).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(group.title).font(.headline).foregroundStyle(Theme.textBright)
                                    Text(L10n.patientJourneyCount(group.sessions.count))
                                        .font(.subheadline).foregroundStyle(Theme.textBody)
                                    if let first = group.sessions.first, let last = group.sessions.last {
                                        Text(first.date == last.date ? L10n.hebrewDate(first.date) :
                                                L10n.hebrewDate(first.date) + " – " + L10n.hebrewDate(last.date))
                                            .font(.caption).foregroundStyle(Theme.textBody)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 28)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("patient.journey.timeline")
        .themedScreen()
        .navigationTitle(L10n.patientJourneyTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Noninteractive boundary between the patient screen's major content groups.
struct PatientSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.borderDefault)
            .frame(height: 1)
            .padding(.top, 8)
            .accessibilityHidden(true)
    }
}
