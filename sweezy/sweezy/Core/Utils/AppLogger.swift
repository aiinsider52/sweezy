//
//  AppLogger.swift
//  sweezy
//
//  Production-safe logging utility. Logs are visible in Console.app but not in user-facing UI.
//  In Release builds, debug-level logs are stripped.
//

import Foundation
import os.log

/// Production-safe logger that uses Apple's unified logging system.
/// Debug logs are automatically stripped in Release builds.
enum AppLogger {
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sweezy"
    
    // Category-specific loggers
    private static let general = Logger(subsystem: subsystem, category: "general")
    private static let network = Logger(subsystem: subsystem, category: "network")
    private static let ui = Logger(subsystem: subsystem, category: "ui")
    private static let content = Logger(subsystem: subsystem, category: "content")
    private static let auth = Logger(subsystem: subsystem, category: "auth")
    private static let notifications = Logger(subsystem: subsystem, category: "notifications")
    private static let location = Logger(subsystem: subsystem, category: "location")
    private static let deeplink = Logger(subsystem: subsystem, category: "deeplink")
    
    // MARK: - General
    
    /// Debug log (stripped in Release)
    static func debug(_ message: String) {
        #if DEBUG
        general.debug("🔍 \(message, privacy: .public)")
        #endif
    }
    
    /// Info log (always available)
    static func info(_ message: String) {
        general.info("ℹ️ \(message, privacy: .public)")
    }
    
    /// Warning log
    static func warning(_ message: String) {
        general.warning("⚠️ \(message, privacy: .public)")
    }
    
    /// Error log
    static func error(_ message: String) {
        general.error("🔴 \(message, privacy: .public)")
    }
    
    // MARK: - Category-specific logging
    
    static func network(_ message: String, level: OSLogType = .debug) {
        #if DEBUG
        if level == .debug {
            AppLogger.network.debug("🌐 \(message, privacy: .public)")
        } else {
            AppLogger.network.log(level: level, "🌐 \(message, privacy: .public)")
        }
        #else
        if level != .debug {
            AppLogger.network.log(level: level, "🌐 \(message, privacy: .public)")
        }
        #endif
    }
    
    static func ui(_ message: String) {
        #if DEBUG
        AppLogger.ui.debug("📱 \(message, privacy: .public)")
        #endif
    }
    
    static func content(_ message: String, isError: Bool = false) {
        if isError {
            AppLogger.content.error("📦 \(message, privacy: .public)")
        } else {
            #if DEBUG
            AppLogger.content.debug("📦 \(message, privacy: .public)")
            #endif
        }
    }
    
    static func auth(_ message: String, isError: Bool = false) {
        if isError {
            AppLogger.auth.error("🔐 \(message, privacy: .public)")
        } else {
            #if DEBUG
            AppLogger.auth.debug("🔐 \(message, privacy: .public)")
            #endif
        }
    }
    
    static func notification(_ message: String, isError: Bool = false) {
        if isError {
            AppLogger.notifications.error("🔔 \(message, privacy: .public)")
        } else {
            #if DEBUG
            AppLogger.notifications.debug("🔔 \(message, privacy: .public)")
            #endif
        }
    }
    
    static func location(_ message: String, isError: Bool = false) {
        if isError {
            AppLogger.location.error("📍 \(message, privacy: .public)")
        } else {
            #if DEBUG
            AppLogger.location.debug("📍 \(message, privacy: .public)")
            #endif
        }
    }
    
    static func deeplink(_ message: String) {
        #if DEBUG
        AppLogger.deeplink.debug("🔗 \(message, privacy: .public)")
        #endif
    }
}

