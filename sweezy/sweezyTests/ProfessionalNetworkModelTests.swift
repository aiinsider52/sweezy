import XCTest
@testable import sweezy

final class ProfessionalNetworkModelTests: XCTestCase {
    func testDraftEncodesOnlyProfessionalFields() throws {
        var draft = ProfessionalProfileDraft()
        draft.displayName = "Anna Kovalenko"
        draft.headline = "Product Designer"
        draft.industry = "Technology"
        draft.bio = "I build accessible digital products for international teams in Switzerland."
        draft.skills = ["Figma", "Research"]
        draft.languages = ["DE", "EN"]
        draft.goals = [.partners, .events]

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])

        XCTAssertEqual(object["display_name"] as? String, "Anna Kovalenko")
        XCTAssertEqual(object["role"] as? String, "founder")
        XCTAssertEqual(object["goals"] as? [String], ["partners", "events"])
        XCTAssertNil(object["email"])
        XCTAssertNil(object["phone"])
    }

    func testRoleAndGoalLabelsRemainStable() {
        XCTAssertEqual(ProfessionalRole.founder.rawValue, "founder")
        XCTAssertEqual(ProfessionalGoal.partners.rawValue, "partners")
    }
}
