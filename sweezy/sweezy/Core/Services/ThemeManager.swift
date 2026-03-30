//
//  ThemeManager.swift
//  sweezy
//
//  Handles Light/Dark/System theme preference using @AppStorage
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var localizedName: String {
        switch self {
        case .system: return "settings.theme.system".localized
        case .light:  return "settings.theme.light".localized
        case .dark:   return "settings.theme.dark".localized
        }
    }
}

final class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedTheme: AppTheme = .dark {
        didSet { objectWillChange.send() }
    }
    
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

