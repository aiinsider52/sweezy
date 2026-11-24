import SwiftUI

/// One guide in the library list: small cover, title, and a single quiet meta line.
struct JourneyGuideCompactRow: View {
    let guide: Guide
    let imageName: String

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 58, height: 58)
                .overlay { JourneyRemoteImage(url: guide.coverURL, fallbackAsset: imageName) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    if guide.source != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(JourneyVisual.accentStrong)
                    }
                    Text(metaLine)
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var metaLine: String {
        var parts = [guide.category.localizedName, "journey.directory.reading_time_minutes".localized(with: guide.estimatedReadingTime)]
        if guide.relatedChecklistId != nil { parts.append("journey.directory.checklist_label".localized) }
        return parts.joined(separator: " · ")
    }
}

struct JourneyChecklistWorkspace: View {
    let checklists: [Checklist]
    let open: (Checklist) -> Void

    @AppStorage("checklist_progress_version") private var progressVersion = 0
    @State private var selectedCategory: ChecklistCategory?

    private var filtered: [Checklist] {
        guard let selectedCategory else { return checklists }
        return checklists.filter { $0.category == selectedCategory }
    }

    private var progress: (done: Int, total: Int, fraction: Double) {
        var done = 0
        let total = checklists.reduce(0) { $0 + $1.steps.count }
        for checklist in checklists {
            done += completedIDs(for: checklist).count
        }
        return (done, total, total == 0 ? 0 : Double(done) / Double(total))
    }

    private var nextAction: (Checklist, ChecklistStep)? {
        for checklist in checklists {
            let completed = completedIDs(for: checklist)
            if let step = checklist.steps.sorted(by: { $0.order < $1.order }).first(where: { !completed.contains($0.id) }) {
                return (checklist, step)
            }
        }
        return nil
    }

    private var visibleCategories: [ChecklistCategory] {
        var seen = Set<ChecklistCategory>()
        return checklists.compactMap { checklist in
            seen.insert(checklist.category).inserted ? checklist.category : nil
        }
    }

    var body: some View {
        let _ = progressVersion

        VStack(alignment: .leading, spacing: 18) {
            summaryCard

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    checklistFilter(title: "common.all".localized, icon: "square.grid.2x2", category: nil)
                    ForEach(visibleCategories, id: \.self) { category in
                        checklistFilter(title: category.localizedName, icon: category.iconName, category: category)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)

            // One list with hairlines instead of a stack of bordered cards.
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, checklist in
                    Button { open(checklist) } label: {
                        JourneyChecklistRow(
                            checklist: checklist,
                            completed: completedIDs(for: checklist).count
                        )
                    }
                    .buttonStyle(.plain)
                    if index < filtered.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        }
    }

    /// Overall progress and the next step in one card; tapping it opens that checklist.
    private var summaryCard: some View {
        Button {
            if let nextAction { open(nextAction.0) }
        } label: {
            HStack(spacing: 14) {
                JourneyProgressRing(done: progress.done, total: max(progress.total, 1), size: 52, lineWidth: 6, showsPercent: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("journey.directory.checklists.steps_count".localized(with: progress.done, progress.total))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                    Text(nextAction?.1.title ?? "journey.directory.checklists.keep_going".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let checklist = nextAction?.0 {
                        Text(checklist.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if nextAction != nil {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(JourneyVisual.lime, in: Circle())
                }
            }
            .padding(14)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .disabled(nextAction == nil)
    }

    private func checklistFilter(title: String, icon: String, category: ChecklistCategory?) -> some View {
        let selected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .black : (category?.swatch.ink ?? JourneyVisual.primaryText))
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(selected ? JourneyVisual.lime : Theme.Colors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func completedIDs(for checklist: Checklist) -> Set<UUID> {
        let key = AccountScopedStorage.checklistCompletedKey(for: checklist.id)
        let values = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }
}

private struct JourneyChecklistRow: View {
    let checklist: Checklist
    let completed: Int

    private var fraction: Double {
        checklist.steps.isEmpty ? 0 : Double(completed) / Double(checklist.steps.count)
    }

    var body: some View {
        HStack(spacing: 14) {
            JourneyCategoryIcon(
                symbol: checklist.category.iconName,
                swatch: checklist.category.swatch,
                size: 42
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(checklist.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text("\(checklist.estimatedDuration) · " + "journey.directory.checklists.completed_ratio".localized(with: completed, checklist.steps.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(JourneyVisual.softBorder)
                            Capsule()
                                .fill(JourneyVisual.accentStrong)
                                .frame(width: geometry.size.width * fraction)
                        }
                    }
                    .frame(width: 44, height: 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
