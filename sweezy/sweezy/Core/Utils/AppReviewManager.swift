import StoreKit
import SwiftUI

enum AppReviewManager {
    private static let guidesReadKey = "app_review_guides_read_count"
    private static let checklistsCompletedKey = "app_review_checklists_completed"
    private static let hasRequestedReviewKey = "app_review_has_requested"
    private static let firstLaunchDateKey = "app_review_first_launch"
    
    static func recordGuideRead() {
        let count = UserDefaults.standard.integer(forKey: guidesReadKey) + 1
        UserDefaults.standard.set(count, forKey: guidesReadKey)
        checkAndRequestReview()
    }
    
    static func recordChecklistCompleted() {
        let count = UserDefaults.standard.integer(forKey: checklistsCompletedKey) + 1
        UserDefaults.standard.set(count, forKey: checklistsCompletedKey)
        checkAndRequestReview()
    }
    
    static func recordFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }
    }
    
    private static func checkAndRequestReview() {
        guard !UserDefaults.standard.bool(forKey: hasRequestedReviewKey) else { return }
        
        let guidesRead = UserDefaults.standard.integer(forKey: guidesReadKey)
        let checklistsCompleted = UserDefaults.standard.integer(forKey: checklistsCompletedKey)
        let daysSinceFirstLaunch = daysSinceFirstLaunch()
        
        let shouldRequest = guidesRead >= 3 || checklistsCompleted >= 1 || daysSinceFirstLaunch >= 7
        
        if shouldRequest {
            UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task { @MainActor in
                    requestReview()
                }
            }
        }
    }
    
    private static func daysSinceFirstLaunch() -> Int {
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
    }
    
    @MainActor
    private static func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}
