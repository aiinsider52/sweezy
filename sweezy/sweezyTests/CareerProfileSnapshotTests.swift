import XCTest
@testable import sweezy

final class CareerProfileSnapshotTests: XCTestCase {
    func testEmptyProfileHasNoReadinessOrMatchingInput() {
        let snapshot = CareerProfileSnapshot(resume: nil)

        XCTAssertEqual(snapshot.completion, 0)
        XCTAssertFalse(snapshot.hasResume)
        XCTAssertFalse(snapshot.canMatchJobs)
        XCTAssertEqual(snapshot.nextMissingSection, "CV")
    }

    func testCompleteResumeBuildsFullCareerProfile() {
        var resume = CVResume.empty
        resume.personal = CVPersonal(
            fullName: "Olena Kovalenko",
            title: "Product Designer",
            email: "olena@example.com",
            phone: "+41790000000",
            location: "Zürich",
            summary: "Product designer with experience building accessible digital services for international teams."
        )
        resume.experience = [CVExperience(role: "Product Designer", company: "Sweezy")]
        resume.education = [CVEducation(school: "ZHdK", degree: "Design")]
        resume.skills = ["Figma", "Research", "Design Systems", "figma"]
        resume.languages = [CVLanguage(name: "Deutsch", level: "B2")]

        let snapshot = CareerProfileSnapshot(resume: resume)

        XCTAssertEqual(snapshot.completion, 100)
        XCTAssertEqual(snapshot.desiredPosition, "Product Designer")
        XCTAssertEqual(snapshot.normalizedSkills, ["Figma", "Research", "Design Systems"])
        XCTAssertTrue(snapshot.canMatchJobs)
        XCTAssertNil(snapshot.nextMissingSection)
        XCTAssertEqual(snapshot.inferredExperienceLevel, "Junior")
    }

    func testRoleFallsBackToLatestExperience() {
        var resume = CVResume.empty
        resume.experience = [CVExperience(role: "iOS Developer", company: "Example AG")]

        XCTAssertEqual(CareerProfileSnapshot(resume: resume).desiredPosition, "iOS Developer")
    }
}
