import UIKit
import UserNotifications

final class SweezyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        guard KeychainStore.get("access_token")?.isEmpty == false else { return }
        Task {
            #if DEBUG
            let environment = "sandbox"
            #else
            let environment = "production"
            #endif
            try? await ChatAPI.registerPush(token: token, environment: environment)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.notification("Remote push registration failed: \(error.localizedDescription)", isError: true)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard info["type"] as? String == "chat_message", let id = info["conversation_id"] as? String else { return }
        await MainActor.run { DeepLinkService.shared.navigate(to: .chat(id: id)) }
    }

    @MainActor
    static func registerForChatPush() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if settings.authorizationStatus == .notDetermined {
            allowed = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        }
        guard allowed else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = UserDefaults.standard.string(forKey: "apns_device_token") {
            #if DEBUG
            let environment = "sandbox"
            #else
            let environment = "production"
            #endif
            try? await ChatAPI.registerPush(token: token, environment: environment)
        }
    }
}
