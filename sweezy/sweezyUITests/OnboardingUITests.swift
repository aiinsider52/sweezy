//
//  OnboardingUITests.swift
//  sweezyUITests
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import XCTest

final class OnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Reset onboarding state for testing
        app.launchArguments.append("--reset-onboarding")
        app.launch()
    }
    
    func testOnboardingFlow() throws {
        // Test that onboarding screens appear via accessibility IDs
        XCTAssertTrue(app.staticTexts["onboarding.page.title.1"].waitForExistence(timeout: 10))
        
        // Navigate through onboarding pages
        let nextButton = app.buttons["onboarding.nextButton"]
        if nextButton.exists {
            nextButton.tap()
            
            // Check second page
            XCTAssertTrue(app.staticTexts["onboarding.page.title.2"].waitForExistence(timeout: 10))
            
            nextButton.tap()
            
            // Check third page
            XCTAssertTrue(app.staticTexts["onboarding.page.title.3"].waitForExistence(timeout: 10))
            
            // Tap Get Started to go to language selection
            let getStartedButton = app.buttons["onboarding.getStartedButton"]
            XCTAssertTrue(getStartedButton.exists)
            getStartedButton.tap()
        }
        
        // Test language selection
        XCTAssertTrue(app.otherElements["onboarding.language.container"].waitForExistence(timeout: 10))
        
        // Select Ukrainian language (should be pre-selected)
        let ukrainianOption = app.buttons["onboarding.language.option.uk"]
        if ukrainianOption.exists {
            ukrainianOption.tap()
        }
        
        // Complete onboarding
        let finalGetStartedButton = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(finalGetStartedButton.exists)
        finalGetStartedButton.tap()
        
        // Verify we reach the main app
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 10))
    }
    
    func testSkipOnboarding() throws {
        // Test skip functionality
        let skipButton = app.buttons["onboarding.skipButton"]
        if skipButton.exists {
            skipButton.tap()
            
            // Should go directly to main app
            XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 10))
        }
    }
    
    func testLanguageSelection() throws {
        // Navigate to language selection
        let getStartedButton = app.buttons["onboarding.getStartedButton"]
        if getStartedButton.exists {
            // Navigate through onboarding pages quickly
            let nextButton = app.buttons["onboarding.nextButton"]
            if nextButton.exists {
                nextButton.tap()
                nextButton.tap()
            }
            getStartedButton.tap()
        }
        
        // Test different language selections
        let languages = ["onboarding.language.option.uk", "onboarding.language.option.ru", "onboarding.language.option.en", "onboarding.language.option.de"]
        
        for language in languages {
            let languageButton = app.buttons[language]
            if languageButton.exists {
                languageButton.tap()
                
                // Verify selection (checkmark should appear)
                XCTAssertTrue(app.images["onboarding.language.selectedIcon"].waitForExistence(timeout: 5))
                break
            }
        }
    }
    
    func testOnboardingAccessibility() throws {
        // Test VoiceOver accessibility
        XCTAssertTrue(app.staticTexts["onboarding.page.title.1"].isHittable)
        
        let nextButton = app.buttons["onboarding.nextButton"]
        if nextButton.exists {
            XCTAssertTrue(nextButton.isHittable)
            XCTAssertNotNil(nextButton.label)
        }
        
        let skipButton = app.buttons["onboarding.skipButton"]
        if skipButton.exists {
            XCTAssertTrue(skipButton.isHittable)
            XCTAssertNotNil(skipButton.label)
        }
    }
}
