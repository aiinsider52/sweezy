import Foundation

/// Career copilot: a tailored application kit and a mock interview for one job.
enum CareerAPI {
    struct Job: Encodable {
        let title: String
        let company: String?
        let location: String?
        let description: String
        let languages: [String]
        let skills: [String]

        init(_ item: APIClient.JobItem) {
            title = item.title
            company = item.company
            location = [item.location, item.canton].compactMap { $0 }.joined(separator: ", ")
            description = String((item.description ?? item.snippet ?? "").prefix(7000))
            languages = item.languages ?? []
            skills = item.skills ?? []
        }
    }

    struct Gap: Codable, Hashable {
        let title: String
        let advice: String
    }

    struct Kit: Codable, Hashable {
        let fitScore: Int
        let verdict: String
        let strengths: [String]
        let gaps: [Gap]
        let cvSummary: String
        let coverLetter: String
        let emailSubject: String
        let emailBody: String
        let interviewQuestions: [String]
        let letterLanguage: String

        enum CodingKeys: String, CodingKey {
            case verdict, strengths, gaps
            case fitScore = "fit_score"
            case cvSummary = "cv_summary"
            case coverLetter = "cover_letter"
            case emailSubject = "email_subject"
            case emailBody = "email_body"
            case interviewQuestions = "interview_questions"
            case letterLanguage = "letter_language"
        }
    }

    struct InterviewMessage: Codable, Hashable {
        let role: String   // interviewer | candidate
        let content: String
    }

    struct InterviewTurn: Codable, Hashable {
        let feedback: String?
        let score: Int?
        let betterAnswer: String?
        let nextQuestion: String?
        let done: Bool
        let finalSummary: String?
        let overallScore: Int?
        let questionNumber: Int
        let totalQuestions: Int

        enum CodingKeys: String, CodingKey {
            case feedback, score, done
            case betterAnswer = "better_answer"
            case nextQuestion = "next_question"
            case finalSummary = "final_summary"
            case overallScore = "overall_score"
            case questionNumber = "question_number"
            case totalQuestions = "total_questions"
        }
    }

    private struct CVPayload: Encodable {
        struct Personal: Encodable { let fullName, title, email, phone, location, summary: String }
        struct Education: Encodable { let school, degree, period, details: String }
        struct Experience: Encodable { let id, role, company, period, location, achievements: String }
        struct Language: Encodable { let name, level: String }
        let personal: Personal
        let education: [Education]
        let experience: [Experience]
        let languages: [Language]
        let skills: [String]
        let hobbies: [String]

        init(_ cv: CVResume) {
            // Contact details stay on the phone; the model only needs the professional content.
            personal = Personal(fullName: cv.personal.fullName, title: cv.personal.title, email: "", phone: "",
                                location: cv.personal.location, summary: cv.personal.summary)
            education = cv.education.map { Education(school: $0.school, degree: $0.degree, period: $0.period, details: $0.details) }
            experience = cv.experience.map {
                Experience(id: $0.id.uuidString, role: $0.role, company: $0.company, period: $0.period, location: $0.location, achievements: $0.achievements)
            }
            languages = cv.languages.map { Language(name: $0.name, level: $0.level) }
            skills = cv.skills
            hobbies = []
        }
    }

    private struct KitRequest: Encodable {
        let job: Job
        let cv: CVPayload
        let letter_language: String
        let language: String
        let country: String
    }

    private struct InterviewRequest: Encodable {
        let job: Job
        let cv_summary: String
        let interview_language: String
        let language: String
        let history: [InterviewMessage]
        let total_questions: Int
    }

    static func applicationKit(job: APIClient.JobItem, cv: CVResume, letterLanguage: String) async throws -> Kit {
        try await post("ai/application-kit", context: "career-kit", body: KitRequest(
            job: Job(job), cv: CVPayload(cv), letter_language: letterLanguage,
            language: AppLanguage.current.rawValue, country: APIClient.countryCode
        ))
    }

    static func interviewTurn(
        job: APIClient.JobItem, cvSummary: String, interviewLanguage: String,
        history: [InterviewMessage], totalQuestions: Int
    ) async throws -> InterviewTurn {
        try await post("ai/interview-turn", context: "interview-turn", body: InterviewRequest(
            job: Job(job), cv_summary: String(cvSummary.prefix(1500)), interview_language: interviewLanguage,
            language: AppLanguage.current.rawValue, history: history, total_questions: totalQuestions
        ))
    }

    /// The letter language the job most likely expects: its own stated language, else the region's.
    static func defaultLetterLanguage(for job: APIClient.JobItem) -> String {
        let stated = (job.languages ?? []).joined(separator: " ").lowercased()
        if stated.contains("franz") || stated.contains("french") || stated.contains("fran") { return "fr" }
        if stated.contains("ital") { return "it" }
        if APIClient.countryCode == "CH", let canton = job.canton?.uppercased(),
           ["GE", "VD", "NE", "JU"].contains(canton) { return "fr" }
        if APIClient.countryCode == "CH", job.canton?.uppercased() == "TI" { return "it" }
        if stated.contains("english") && !stated.contains("deutsch") && !stated.contains("german") { return "en" }
        return "de"
    }

    private static func post<Body: Encodable, Result: Decodable>(_ path: String, context: String, body: Body) async throws -> Result {
        var request = URLRequest(url: APIClient.url(path), timeoutInterval: 75)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await APIClient.authorizedData(for: request, context: context)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIErrorText.error(domain: "CareerAPI", status: status, data: data)
        }
        return try JSONDecoder().decode(Result.self, from: data)
    }
}
