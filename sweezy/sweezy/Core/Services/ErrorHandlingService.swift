//
//  ErrorHandlingService.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import Foundation
import SwiftUI

/// Centralized error handling service
enum AppError: LocalizedError {
    case contentLoadFailed(String)
    case networkError(Error)
    case decodingError(Error)
    case fileNotFound(String)
    case invalidData
    case cacheWriteFailed
    case missingLocalization(String)
    
    var errorDescription: String? {
        switch self {
        case .contentLoadFailed(let filename):
            return "errors.content_load_failed".localized + ": \(filename)"
        case .networkError(let error):
            return "errors.network".localized + ": \(error.localizedDescription)"
        case .decodingError(let error):
            return "errors.decoding_failed".localized + ": \(error.localizedDescription)"
        case .fileNotFound(let filename):
            return "errors.file_not_found".localized + ": \(filename)"
        case .invalidData:
            return "errors.invalid_data".localized
        case .cacheWriteFailed:
            return "errors.cache_write_failed".localized
        case .missingLocalization(let key):
            return "⚠️ Missing key: \(key)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .contentLoadFailed, .fileNotFound:
            return "errors.recovery.reinstall".localized
        case .networkError:
            return "errors.recovery.check_connection".localized
        case .decodingError, .invalidData:
            return "errors.recovery.update_app".localized
        case .cacheWriteFailed:
            return "errors.recovery.free_space".localized
        case .missingLocalization:
            return "Please update the app to the latest version"
        }
    }
}

/// Error state for UI
struct ErrorState: Identifiable {
    let id = UUID()
    let error: AppError
    let timestamp: Date = Date()
    var isDismissed: Bool = false
    
    var shouldShowRetry: Bool {
        switch error {
        case .networkError, .contentLoadFailed:
            return true
        default:
            return false
        }
    }
}

/// Error handling protocol
@MainActor
protocol ErrorHandlingServiceProtocol: ObservableObject {
    var currentError: ErrorState? { get set }
    func handle(_ error: AppError)
    func clearError()
}

/// Error handling service implementation
class ErrorHandlingService: ErrorHandlingServiceProtocol {
    @Published var currentError: ErrorState?
    
    private var errorLog: [ErrorState] = []
    private let maxLogSize = 50
    
    @MainActor
    func handle(_ error: AppError) {
        let errorState = ErrorState(error: error)
        currentError = errorState
        errorLog.append(errorState)
        
        // Keep log size manageable
        if errorLog.count > maxLogSize {
            errorLog.removeFirst()
        }
        
        // Log to console in debug mode
        #if DEBUG
        print("🔴 AppError: \(error.errorDescription ?? "Unknown")")
        if let recovery = error.recoverySuggestion {
            print("💡 Recovery: \(recovery)")
        }
        #endif
    }
    
    @MainActor
    func clearError() {
        currentError = nil
    }
    
    func getRecentErrors(limit: Int = 10) -> [ErrorState] {
        Array(errorLog.suffix(limit).reversed())
    }
}

// MARK: - Error View Modifier

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorService: ErrorHandlingService
    let onRetry: (() async -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(
                "errors.title".localized,
                isPresented: .constant(errorService.currentError != nil),
                presenting: errorService.currentError
            ) { errorState in
                Button("common.ok".localized) {
                    errorService.clearError()
                }
                
                if errorState.shouldShowRetry, let onRetry = onRetry {
                    Button("common.retry".localized) {
                        errorService.clearError()
                        Task {
                            await onRetry()
                        }
                    }
                }
            } message: { errorState in
                VStack {
                    if let description = errorState.error.errorDescription {
                        Text(description)
                    }
                    if let recovery = errorState.error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func withErrorHandling(
        errorService: ErrorHandlingService,
        onRetry: (() async -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(errorService: errorService, onRetry: onRetry))
    }
}



