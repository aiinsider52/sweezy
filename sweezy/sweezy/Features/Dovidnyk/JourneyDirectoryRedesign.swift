import SwiftUI

struct JourneyGuideCompactRow: View {
    let guide: Guide
    let imageName: String

    var body: some View {
        HStack(spacing: 13) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Label(guide.category.localizedName, systemImage: guide.category.iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)
                        .lineLimit(1)

                    if guide.source != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
                    }
                }

                Text(guide.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    Label("\(guide.estimatedReadingTime) хв", systemImage: "clock")
                    if guide.relatedChecklistId != nil {
                        Label("чек-лист", systemImage: "checklist")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.56))
            }

            Spacer(minLength: 6)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 30, height: 30)
                .background(JourneyVisual.lime)
                .clipShape(Circle())
        }
        .padding(10)
        .background(Color.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
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

        VStack(alignment: .leading, spacing: 15) {
            progressHero

            if let nextAction {
                nextActionCard(checklist: nextAction.0, step: nextAction.1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    checklistFilter(title: "Усі", icon: "square.grid.2x2", category: nil)
                    ForEach(visibleCategories, id: \.self) { category in
                        checklistFilter(title: category.localizedName, icon: category.iconName, category: category)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)

            VStack(spacing: 10) {
                ForEach(filtered) { checklist in
                    Button { open(checklist) } label: {
                        JourneyChecklistRow(
                            checklist: checklist,
                            completed: completedIDs(for: checklist).count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var progressHero: some View {
        HStack(spacing: 17) {
            ZStack {
                Circle()
                    .stroke(.black.opacity(0.14), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(.black, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int((progress.fraction * 100).rounded()))%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("готово")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.black)
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 6) {
                Text("Твій прогрес")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("\(progress.done) з \(progress.total) кроків")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.72))
                Text(progress.done == 0 ? "Почни з одного простого кроку" : "Продовжуй — ти вже в русі")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.58))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 58, weight: .thin))
                .foregroundColor(.black.opacity(0.08))
                .padding(16)
        }
    }

    private func nextActionCard(checklist: Checklist, step: ChecklistStep) -> some View {
        Button { open(checklist) } label: {
            HStack(spacing: 13) {
                Image(systemName: checklist.category.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                    .frame(width: 46, height: 46)
                    .background(JourneyVisual.lime.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("НАСТУПНИЙ КРОК")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(step.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(checklist.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
            }
            .padding(12)
            .background(Color.black.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func checklistFilter(title: String, icon: String, category: ChecklistCategory?) -> some View {
        let selected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(selected ? .black : .white.opacity(0.76))
                .padding(.horizontal, 13)
                .frame(height: 39)
                .background(selected ? JourneyVisual.lime : Color.black.opacity(0.48))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.15), lineWidth: 1))
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
        HStack(spacing: 13) {
            Image(systemName: checklist.category.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(checklist.category.swiftUIColor)
                .frame(width: 54, height: 54)
                .background(checklist.category.swiftUIColor.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(checklist.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if checklist.isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(JourneyVisual.lime)
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    Label(checklist.estimatedDuration, systemImage: "clock")
                    Spacer()
                    Text("\(completed)/\(checklist.steps.count)")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.52))

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(checklist.category.swiftUIColor)
                            .frame(width: geometry.size.width * fraction)
                    }
                }
                .frame(height: 4)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.38))
        }
        .padding(12)
        .background(Color.black.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }
}
