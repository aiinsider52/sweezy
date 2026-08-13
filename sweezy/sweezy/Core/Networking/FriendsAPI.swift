import Foundation

enum FriendsAPI {
  private static func responseError(_ data: Data, response: URLResponse?, fallback: String) -> NSError {
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let detail = payload["detail"]
    {
      if let message = detail as? String {
        return NSError(domain: "FriendsAPI", code: status, userInfo: [NSLocalizedDescriptionKey: message])
      }
      if let object = detail as? [String: Any], let message = object["message"] as? String {
        return NSError(domain: "FriendsAPI", code: status, userInfo: [NSLocalizedDescriptionKey: message])
      }
    }
    return NSError(domain: "FriendsAPI", code: status, userInfo: [NSLocalizedDescriptionKey: fallback])
  }
  private struct RequestPayload: Encodable {
    let message: String?
    let eventID: String?
    enum CodingKeys: String, CodingKey {
      case message
      case eventID = "event_id"
    }
  }
  private struct Decision: Encodable { let status: String }
  private struct Attendance: Encodable {
    let status: String
    let visibleToAttendees: Bool
    enum CodingKeys: String, CodingKey {
      case status
      case visibleToAttendees = "visible_to_attendees"
    }
  }
  private struct Report: Encodable {
    let reason: String
    let details: String?
  }
  private struct Invite: Encodable {
    let friendUserID: String
    enum CodingKeys: String, CodingKey { case friendUserID = "friend_user_id" }
  }
  private struct EventMessageBody: Encodable { let body: String }
  private struct VisitBody: Encodable { let invisible: Bool }

  private static func call<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil)
    async throws -> T
  {
    var request = URLRequest(url: APIClient.url(path))
    request.httpMethod = method
    request.timeoutInterval = 20
    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await APIClient.authorizedData(
      for: request, context: "friends_\(method.lowercased())")
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw responseError(data, response: response, fallback: "friends.error.request".localized)
    }
    return try ChatAPI.decoder.decode(T.self, from: data)
  }
  private static func empty(_ path: String, method: String) async throws {
    let _: SocialAction = try await call(path, method: method)
  }
  static func profiles(
    query: String = "", canton: String? = nil, interest: SocialInterest? = nil,
    language: String? = nil, ageBand: String? = nil, residency: String? = nil,
    maxDistanceKM: Int? = nil, nearby: Bool = false, eventID: String? = nil
  ) async throws -> SocialProfilePage {
    var c = URLComponents(url: APIClient.url("friends/profiles"), resolvingAgainstBaseURL: false)!
    c.queryItems = [
      query.isEmpty ? nil : URLQueryItem(name: "q", value: query),
      canton.map { URLQueryItem(name: "canton", value: $0) },
      interest.map { URLQueryItem(name: "interest", value: $0.rawValue) },
      language.map { URLQueryItem(name: "language", value: $0) },
      ageBand.map { URLQueryItem(name: "age_band", value: $0) },
      residency.map { URLQueryItem(name: "residency", value: $0) },
      maxDistanceKM.map { URLQueryItem(name: "max_distance_km", value: String($0)) },
      nearby ? URLQueryItem(name: "nearby", value: "true") : nil,
      eventID.map { URLQueryItem(name: "event_id", value: $0) },
      URLQueryItem(name: "per_page", value: "40"),
    ].compactMap { $0 }
    let r = URLRequest(url: c.url!)
    let (d, res) = try await APIClient.authorizedData(for: r, context: "friends_profiles")
    guard let h = res as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
      throw responseError(d, response: res, fallback: "friends.error.people".localized)
    }
    return try ChatAPI.decoder.decode(SocialProfilePage.self, from: d)
  }
  static func myProfile() async throws -> SocialProfile { try await call("friends/profile/me") }
  static func save(_ draft: SocialProfileDraft) async throws -> SocialProfile {
    try await call("friends/profile/me", method: "PUT", body: try JSONEncoder().encode(draft))
  }
  static func connections() async throws -> [FriendConnection] {
    try await call("friends/connections")
  }
  static func connect(_ id: String, message: String?, eventID: String? = nil) async throws
    -> FriendConnection
  {
    try await call(
      "friends/profiles/\(id)/connect", method: "POST",
      body: try JSONEncoder().encode(RequestPayload(message: message, eventID: eventID)))
  }
  static func decide(_ id: String, accept: Bool) async throws -> FriendConnection {
    try await call(
      "friends/connections/\(id)", method: "PATCH",
      body: try JSONEncoder().encode(Decision(status: accept ? "accepted" : "declined")))
  }
  static func events(canton: String? = nil) async throws -> [SocialEvent] {
    try await call("friends/events" + (canton.map { "?canton=\($0)" } ?? ""))
  }
  static func attend(_ id: String, status: String, visible: Bool = true) async throws
    -> SocialAction
  {
    try await call(
      "friends/events/\(id)/attendance", method: "PUT",
      body: try JSONEncoder().encode(Attendance(status: status, visibleToAttendees: visible)))
  }
  static func invite(eventID: String, friendID: String) async throws -> SocialAction {
    try await call(
      "friends/events/\(eventID)/invite", method: "POST",
      body: try JSONEncoder().encode(Invite(friendUserID: friendID)))
  }
  static func eventMessages(_ eventID: String) async throws -> [SocialEventMessage] {
    try await call("friends/events/\(eventID)/messages")
  }
  static func sendEventMessage(_ eventID: String, body: String) async throws -> SocialEventMessage {
    try await call(
      "friends/events/\(eventID)/messages", method: "POST",
      body: try JSONEncoder().encode(EventMessageBody(body: body)))
  }
  static func boostProfile() async throws -> SocialProfile {
    try await call("friends/profile/me/boost", method: "POST")
  }
  static func recordVisit(_ id: String, invisible: Bool) async throws {
    let _: SocialAction = try await call(
      "friends/profiles/\(id)/visit", method: "POST",
      body: try JSONEncoder().encode(VisitBody(invisible: invisible)))
  }
  static func visitors() async throws -> [SocialProfileVisitor] {
    try await call("friends/profile/me/visitors")
  }
  static func block(_ id: String) async throws {
    try await empty("friends/profiles/\(id)/block", method: "POST")
  }
  static func report(_ id: String) async throws {
    let _: SocialAction = try await call(
      "friends/profiles/\(id)/report", method: "POST",
      body: try JSONEncoder().encode(Report(reason: "unsafe", details: nil)))
  }
}
struct SocialAction: Codable {
  let ok: Bool?
  let message: String?
  let eventID: String?
  let status: String?
  let visibleToAttendees: Bool?
  enum CodingKeys: String, CodingKey {
    case ok, message, status
    case eventID = "event_id"
    case visibleToAttendees = "visible_to_attendees"
  }
}
