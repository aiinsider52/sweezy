//
//  FeatureOnboardingManager.swift
//  sweezy
//
//  Tracks which feature onboarding screens the user has seen.
//

import Foundation
import SwiftUI

/// Identifies features that have contextual onboarding
enum OnboardingFeature: String, CaseIterable {
    case dovidnyk = "feature.dovidnyk"
    case calculator = "feature.calculator"
    case roadmap = "feature.roadmap"
    case checklists = "feature.checklists"
    case guides = "feature.guides"
    case map = "feature.map"
    case jobs = "feature.jobs"
    case templates = "feature.templates"
    
    /// UserDefaults key for tracking if this onboarding was shown
    var seenKey: String { "onboarding.seen.\(rawValue)" }
    
    /// Version key - increment to re-show onboarding after major updates
    var versionKey: String { "onboarding.version.\(rawValue)" }
    
    /// Current onboarding version (increment to trigger "What's New")
    var currentVersion: Int {
        switch self {
        case .dovidnyk: return 1
        case .calculator: return 1
        case .roadmap: return 1
        case .checklists: return 1
        case .guides: return 1
        case .map: return 1
        case .jobs: return 1
        case .templates: return 1
        }
    }
}

/// Manages feature onboarding state
@MainActor
final class FeatureOnboardingManager: ObservableObject {
    static let shared = FeatureOnboardingManager()
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    /// Check if onboarding should be shown for a feature
    func shouldShowOnboarding(for feature: OnboardingFeature) -> Bool {
        let seenVersion = defaults.integer(forKey: feature.versionKey)
        return seenVersion < feature.currentVersion
    }
    
    /// Mark onboarding as seen for a feature
    func markAsSeen(_ feature: OnboardingFeature) {
        defaults.set(feature.currentVersion, forKey: feature.versionKey)
        defaults.set(true, forKey: feature.seenKey)
    }
    
    /// Reset onboarding for a feature (for testing)
    func reset(_ feature: OnboardingFeature) {
        defaults.removeObject(forKey: feature.versionKey)
        defaults.removeObject(forKey: feature.seenKey)
    }
    
    /// Reset all feature onboarding
    func resetAll() {
        OnboardingFeature.allCases.forEach { reset($0) }
    }
}

// MARK: - Onboarding Content Model

/// A single slide in the onboarding carousel
struct OnboardingSlide: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

/// Content configuration for feature onboarding
struct FeatureOnboardingContent {
    let feature: OnboardingFeature
    let slides: [OnboardingSlide]
    let buttonTitle: String
    
    /// Single-slide convenience initializer
    init(feature: OnboardingFeature, icon: String, iconColor: Color = Theme.Colors.accentTurquoise, title: String, description: String, buttonTitle: String = "onboarding.understood".localized) {
        self.feature = feature
        self.slides = [OnboardingSlide(icon: icon, iconColor: iconColor, title: title, description: description)]
        self.buttonTitle = buttonTitle
    }
    
    /// Multi-slide initializer
    init(feature: OnboardingFeature, slides: [OnboardingSlide], buttonTitle: String = "onboarding.understood".localized) {
        self.feature = feature
        self.slides = slides
        self.buttonTitle = buttonTitle
    }
}

// MARK: - Predefined Onboarding Content

extension FeatureOnboardingContent {
    
    static let dovidnyk = FeatureOnboardingContent(
        feature: .dovidnyk,
        slides: [
            OnboardingSlide(
                icon: "book.fill",
                iconColor: Theme.Colors.accentTurquoise,
                title: "onboarding.dovidnyk.title".localized,
                description: "onboarding.dovidnyk.description".localized
            ),
            OnboardingSlide(
                icon: "checklist",
                iconColor: Theme.Colors.accentCoral,
                title: "onboarding.dovidnyk.checklists.title".localized,
                description: "onboarding.dovidnyk.checklists.description".localized
            )
        ]
    )
    
    static let calculator = FeatureOnboardingContent(
        feature: .calculator,
        icon: "function",
        iconColor: Theme.Colors.info,
        title: "onboarding.calculator.title".localized,
        description: "onboarding.calculator.description".localized
    )
    
    static let roadmap = FeatureOnboardingContent(
        feature: .roadmap,
        slides: [
            OnboardingSlide(
                icon: "mountain.2.fill",
                iconColor: Theme.Colors.accentTurquoise,
                title: "onboarding.roadmap.title".localized,
                description: "onboarding.roadmap.description".localized
            ),
            OnboardingSlide(
                icon: "star.fill",
                iconColor: Theme.Colors.accent,
                title: "onboarding.roadmap.xp.title".localized,
                description: "onboarding.roadmap.xp.description".localized
            )
        ]
    )
    
    static let map = FeatureOnboardingContent(
        feature: .map,
        icon: "map.fill",
        iconColor: Theme.Colors.success,
        title: "onboarding.map.title".localized,
        description: "onboarding.map.description".localized
    )
    
    static let jobs = FeatureOnboardingContent(
        feature: .jobs,
        icon: "briefcase.fill",
        iconColor: Theme.Colors.primary,
        title: "onboarding.jobs.title".localized,
        description: "onboarding.jobs.description".localized
    )
    
    static let templates = FeatureOnboardingContent(
        feature: .templates,
        icon: "doc.text.fill",
        iconColor: Theme.Colors.warning,
        title: "onboarding.templates.title".localized,
        description: "onboarding.templates.description".localized
    )
}
