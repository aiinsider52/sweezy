//
//  CalculatorServiceTests.swift
//  sweezyTests
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import XCTest
@testable import sweezy

@MainActor
final class CalculatorServiceTests: XCTestCase {
    
    var calculatorService: CalculatorService!
    var mockProfile: UserProfile!
    
    override func setUp() {
        super.setUp()
        calculatorService = CalculatorService()
        mockProfile = UserProfile(
            fullName: "Test User",
            canton: .zurich,
            permitType: .s,
            familySize: 2,
            hasChildren: true
        )
    }
    
    override func tearDown() {
        calculatorService = nil
        mockProfile = nil
        super.tearDown()
    }
    
    func testHealthInsuranceSubsidyEligible() {
        // Given
        let lowIncome: Double = 30000
        let familySize = 2
        let canton = Canton.zurich
        let hasChildren = true
        
        // When
        let result = calculatorService.estimateHealthInsuranceSubsidy(
            income: lowIncome,
            familySize: familySize,
            canton: canton,
            hasChildren: hasChildren
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isEligible)
        XCTAssertGreaterThan(result!.amount, 0)
    }
    
    func testHealthInsuranceSubsidyNotEligible() {
        // Given
        let highIncome: Double = 100000
        let familySize = 1
        let canton = Canton.zurich
        let hasChildren = false
        
        // When
        let result = calculatorService.estimateHealthInsuranceSubsidy(
            income: highIncome,
            familySize: familySize,
            canton: canton,
            hasChildren: hasChildren
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.isEligible)
        XCTAssertEqual(result!.amount, 0)
    }
    
    func testCalculateTotalBenefits() {
        // Given
        let results = [
            BenefitCalculationResult(ruleId: UUID(), amount: 200, isEligible: true),
            BenefitCalculationResult(ruleId: UUID(), amount: 150, isEligible: true),
            BenefitCalculationResult(ruleId: UUID(), amount: 100, isEligible: false)
        ]
        
        // When
        let total = calculatorService.calculateTotalBenefits(results: results)
        
        // Then
        XCTAssertEqual(total, 350) // Only eligible benefits counted
    }
    
    func testGenerateRecommendationsWithEligibleBenefits() {
        // Given
        let results = [
            BenefitCalculationResult(ruleId: UUID(), amount: 200, isEligible: true),
            BenefitCalculationResult(ruleId: UUID(), amount: 0, isEligible: false, reason: "Income too high")
        ]
        
        // When
        let recommendations = calculatorService.generateRecommendations(from: results)
        
        // Then
        XCTAssertFalse(recommendations.isEmpty)
        
        let eligibleRecommendations = recommendations.filter { $0.type == .eligible }
        let ineligibleRecommendations = recommendations.filter { $0.type == .ineligible }
        
        XCTAssertEqual(eligibleRecommendations.count, 1)
        XCTAssertEqual(ineligibleRecommendations.count, 1)
    }
    
    func testGenerateRecommendationsWithNoBenefits() {
        // Given
        let results: [BenefitCalculationResult] = []
        
        // When
        let recommendations = calculatorService.generateRecommendations(from: results)
        
        // Then
        XCTAssertFalse(recommendations.isEmpty)
        
        let generalRecommendations = recommendations.filter { $0.type == .general }
        XCTAssertFalse(generalRecommendations.isEmpty)
    }
    
    func testFormatCurrency() {
        // Given
        let amount: Double = 1234.56
        
        // When
        let formatted = CalculatorService.formatCurrency(amount)
        
        // Then
        XCTAssertTrue(formatted.contains("1234") || formatted.contains("1'234"))
        XCTAssertTrue(formatted.contains("CHF"))
    }
    
    func testValidateIncomeValid() {
        // Given
        let validIncome: Double = 50000
        
        // When
        let result = CalculatorService.validateIncome(validIncome)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidateIncomeNegative() {
        // Given
        let negativeIncome: Double = -1000
        
        // When
        let result = CalculatorService.validateIncome(negativeIncome)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }
    
    func testValidateFamilySizeValid() {
        // Given
        let validSize = 3
        
        // When
        let result = CalculatorService.validateFamilySize(validSize)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidateFamilySizeInvalid() {
        // Given
        let invalidSize = 0
        
        // When
        let result = CalculatorService.validateFamilySize(invalidSize)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }
}
