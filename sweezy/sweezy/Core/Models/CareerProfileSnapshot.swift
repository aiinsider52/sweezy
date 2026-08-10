import Foundation

struct CareerProfileSnapshot: Equatable {
    let resume: CVResume?

    var completion: Int {
        guard let resume else { return 0 }

        var score = 0
        if hasText(resume.personal.fullName) { score += 10 }
        if hasText(resume.personal.title) { score += 15 }
        if hasText(resume.personal.email) || hasText(resume.personal.phone) { score += 10 }
        if hasText(resume.personal.location) { score += 5 }
        if resume.personal.summary.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 { score += 15 }
        if resume.experience.contains(where: { hasText($0.role) && hasText($0.company) }) { score += 20 }
        if resume.education.contains(where: { hasText($0.school) || hasText($0.degree) }) { score += 10 }
        if normalizedSkills.count >= 3 { score += 10 }
        if resume.languages.contains(where: { hasText($0.name) && hasText($0.level) }) { score += 5 }
        return score
    }

    var desiredPosition: String {
        guard let resume else { return "" }
        let title = resume.personal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return resume.experience
            .map(\.role)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    var normalizedSkills: [String] {
        guard let resume else { return [] }
        var seen = Set<String>()
        return resume.skills.compactMap { skill in
            let value = skill.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
    }

    var hasResume: Bool { resume != nil }
    var canMatchJobs: Bool { !desiredPosition.isEmpty || !normalizedSkills.isEmpty }

    var nextMissingSection: String? {
        guard let resume else { return "CV" }
        if !hasText(resume.personal.fullName) || !hasText(resume.personal.email) && !hasText(resume.personal.phone) {
            return "особисті дані"
        }
        if !hasText(resume.personal.title) { return "бажану посаду" }
        if resume.personal.summary.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 { return "професійний профіль" }
        if !resume.experience.contains(where: { hasText($0.role) && hasText($0.company) }) { return "досвід роботи" }
        if normalizedSkills.count < 3 { return "щонайменше 3 навички" }
        if !resume.languages.contains(where: { hasText($0.name) && hasText($0.level) }) { return "мови" }
        return nil
    }

    var inferredExperienceLevel: String? {
        guard let resume else { return nil }
        let roles = resume.experience.filter { hasText($0.role) && hasText($0.company) }.count
        switch roles {
        case 0: return nil
        case 1: return "Junior"
        case 2...3: return "Middle"
        default: return "Senior"
        }
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
