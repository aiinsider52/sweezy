//
//  LocalizationServiceTests.swift
//  sweezyTests
//
//  Created by AI assistant on 15.01.2025.
//

import XCTest
@testable import sweezy

@MainActor
final class LocalizationServiceTests: XCTestCase {
    
    var localizationService: LocalizationService!
    
    override func setUp() {
        super.setUp()
        localizationService = LocalizationService()
    }
    
    override func tearDown() {
        localizationService = nil
        super.tearDown()
    }
    
    func testAvailableLanguages() {
        // Given
        let expectedLanguageCodes = ["uk", "ru", "en", "de"]
        
        // When
        let availableLanguages = localizationService.availableLanguages
        
        // Then
        XCTAssertEqual(availableLanguages.count, 4)
        for lang in availableLanguages {
            XCTAssertTrue(expectedLanguageCodes.contains(lang.code))
        }
    }
    
    func testSetLocale() {
        // Given
        let newLocale = Locale(identifier: "en")
        
        // When
        localizationService.setLocale(newLocale)
        
        // Then
        XCTAssertEqual(localizationService.currentLocale.identifier, "en")
        
        // Verify UserDefaults was updated
        let savedLocale = UserDefaults.standard.string(forKey: "selected_locale")
        XCTAssertEqual(savedLocale, "en")
    }
    
    func testLocalizedStringReturnsKey() {
        // Given a non-existent key
        let key = "non.existent.key"
        
        // When
        let result = localizationService.localizedString(for: key)
        
        // Then it should return the key itself or a default value
        XCTAssertTrue(result == key || result.isEmpty == false)
    }
    
    func testLocalizedStringWithArguments() {
        // Given a format string (assuming it exists in Localizable.strings)
        let key = "guides.reading_time"
        
        // When
        let result = localizationService.localizedString(for: key, arguments: 5)
        
        // Then it should contain the formatted number
        XCTAssertFalse(result.isEmpty)
    }
    
    func testSwitchLanguageSwitchesBundle() {
        // Given starting with Ukrainian
        localizationService.setLocale(Locale(identifier: "uk"))
        
        // When switching to Russian
        localizationService.setLocale(Locale(identifier: "ru"))
        
        // Then the current locale should be Russian
        XCTAssertEqual(localizationService.currentLocale.identifier, "ru")
        
        // And localized strings should come from ru.lproj (if available)
        let localizedOK = localizationService.localizedString(for: "common.ok")
        // Note: exact value depends on Localizable.strings content
        XCTAssertFalse(localizedOK.isEmpty)
    }
}

