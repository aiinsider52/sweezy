//
//  CalculatorService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import Combine

/// Protocol for benefit calculation services
@MainActor
protocol CalculatorServiceProtocol: ObservableObject {
    func calculateBenefits(
        for profile: UserProfile,
        income: Double,
        familySize: Int,
        canton: Canton,
        rules: [BenefitRule]
    ) -> [BenefitCalculationResult]
    
    func estimateHealthInsuranceSubsidy(
        income: Double,
        familySize: Int,
        canton: Canton,
        hasChildren: Bool
    ) -> BenefitCalculationResult?
    
    func calculateTotalBenefits(results: [BenefitCalculationResult]) -> Double
    func generateRecommendations(from results: [BenefitCalculationResult]) -> [BenefitRecommendation]
}

/// Calculator service implementation
@MainActor
class CalculatorService: CalculatorServiceProtocol {
    private let localeIdentifier: String
    
    init(localeIdentifier: String = (UserDefaults.standard.string(forKey: "selected_locale") ?? Locale.current.identifier)) {
        self.localeIdentifier = localeIdentifier
    }
    
    func calculateBenefits(
        for profile: UserProfile,
        income: Double,
        familySize: Int,
        canton: Canton,
        rules: [BenefitRule]
    ) -> [BenefitCalculationResult] {
        
        // Filter rules applicable to the user's situation
        let applicableRules = rules.filter { rule in
            rule.canton == canton &&
            rule.permitTypes.contains(profile.permitType) &&
            rule.isActive
        }
        
        // Calculate benefits for each applicable rule
        let results = applicableRules.compactMap { rule in
            rule.calculateBenefit(
                income: income,
                familySize: familySize,
                hasChildren: profile.hasChildren
            )
        }
        
        // Sort by amount (highest first)
        return results.sorted { $0.amount > $1.amount }
    }
    
    func estimateHealthInsuranceSubsidy(
        income: Double,
        familySize: Int,
        canton: Canton,
        hasChildren: Bool
    ) -> BenefitCalculationResult? {
        
        // Simplified health insurance subsidy calculation
        // This is a demo implementation - real calculations would be more complex
        
        let subsidyRule = createHealthInsuranceSubsidyRule(for: canton)
        
        return subsidyRule.calculateBenefit(
            income: income,
            familySize: familySize,
            hasChildren: hasChildren
        )
    }
    
    func calculateTotalBenefits(results: [BenefitCalculationResult]) -> Double {
        return results
            .filter { $0.isEligible }
            .reduce(0) { total, result in
                total + result.amount
            }
    }
    
    func generateRecommendations(from results: [BenefitCalculationResult]) -> [BenefitRecommendation] {
        var recommendations: [BenefitRecommendation] = []
        
        // Eligible benefits
        let eligibleBenefits = results.filter { $0.isEligible && $0.amount > 0 }
        for result in eligibleBenefits {
            let amountText = formatCurrencyLocalized(result.amount)
            recommendations.append(
                BenefitRecommendation(
                    type: .eligible,
                    title: LocalizationKeys.Calculator.eligible.localized,
                    description: String(format: LocalizationKeys.Calculator.estimatedAmount.localized, amountText),
                    priority: .high,
                    actionTitle: LocalizationKeys.Calculator.applyNow.localized,
                    benefitResultId: result.id
                )
            )
        }
        
        // Ineligible benefits with suggestions
        let ineligibleBenefits = results.filter { !$0.isEligible }
        for result in ineligibleBenefits {
            if let reason = result.reason {
                recommendations.append(
                    BenefitRecommendation(
                        type: .ineligible,
                        title: LocalizationKeys.Calculator.notEligible.localized,
                        description: reason,
                        priority: .medium,
                        actionTitle: LocalizationKeys.Calculator.learnMore.localized,
                        benefitResultId: result.id
                    )
                )
            }
        }
        
        // General recommendations
        if eligibleBenefits.isEmpty {
            recommendations.append(
                BenefitRecommendation(
                    type: .general,
                    title: LocalizationKeys.Calculator.generalTitle.localized,
                    description: LocalizationKeys.Calculator.disclaimer.localized,
                    priority: .medium,
                    actionTitle: LocalizationKeys.Common.search.localized
                )
            )
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Private Helper Methods
    
    private func createHealthInsuranceSubsidyRule(for canton: Canton) -> BenefitRule {
        // Simplified health insurance subsidy rule
        // Real implementation would load from official data sources
        
        var conditions = [
            BenefitCondition(
                type: .income,
                operator: .lessThan,
                value: getIncomeThreshold(for: canton),
                description: "Income below threshold"
            )
        ]
        // Add income per person threshold
        conditions.append(
            BenefitCondition(
                type: .incomePerPerson,
                operator: .lessThan,
                value: getIncomeThreshold(for: canton) / 2.5,
                description: "Income per person below threshold"
            )
        )
        
        let formula = CalculationFormula(
            type: .incomeBasedSliding,
            baseAmount: getMaxSubsidy(for: canton),
            parameters: [
                "max_income": getIncomeThreshold(for: canton),
                "min_subsidy": 50.0
            ]
        )
        
        return BenefitRule(
            name: "Health Insurance Subsidy",
            description: "Monthly subsidy for health insurance premiums",
            category: .healthInsurance,
            canton: canton,
            permitTypes: [.s, .b, .c, .f, .n],
            conditions: conditions,
            calculationFormula: formula,
            maxAmount: getMaxSubsidy(for: canton),
            minAmount: 50.0,
            currency: "CHF",
            officialSource: getOfficialSource(for: canton)
        )
    }
    
    private func getIncomeThreshold(for canton: Canton) -> Double {
        // Simplified income thresholds by canton
        switch canton {
        case .zurich: return 45000
        case .geneva: return 42000
        case .basel: return 44000
        case .bern: return 40000
        default: return 38000
        }
    }
    
    private func getMaxSubsidy(for canton: Canton) -> Double {
        // Simplified maximum subsidy amounts by canton
        switch canton {
        case .zurich: return 400
        case .geneva: return 380
        case .basel: return 390
        case .bern: return 350
        default: return 320
        }
    }
    
    private func getOfficialSource(for canton: Canton) -> String {
        // Official sources for health insurance subsidy information
        switch canton {
        case .zurich: return "https://www.zh.ch/de/gesundheit/gesundheitsversorgung/praemienverbilligung.html"
        case .geneva: return "https://www.ge.ch/reduire-prime-assurance-maladie"
        case .basel: return "https://www.bs.ch/nm/2021-praemienverbilligung-bs.html"
        case .bern: return "https://www.be.ch/de/start/themen/gesundheit/praemienverbilligung.html"
        default: return "https://www.bag.admin.ch/bag/de/home/versicherungen/krankenversicherung/krankenversicherung-versicherte-mit-wohnsitz-in-der-schweiz/praemienverbilligung.html"
        }
    }
}

// MARK: - Supporting Types

/// Benefit recommendation for users
struct BenefitRecommendation: Identifiable, Hashable, Equatable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let actionTitle: String
    let benefitResultId: UUID?
    
    init(
        type: RecommendationType,
        title: String,
        description: String,
        priority: Priority,
        actionTitle: String,
        benefitResultId: UUID? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionTitle = actionTitle
        self.benefitResultId = benefitResultId
    }
    
    enum RecommendationType {
        case eligible
        case ineligible
        case general
        case warning
        
        var iconName: String {
            switch self {
            case .eligible: return "checkmark.circle.fill"
            case .ineligible: return "xmark.circle.fill"
            case .general: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .eligible: return "green"
            case .ineligible: return "red"
            case .general: return "blue"
            case .warning: return "orange"
            }
        }
    }
    
    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        var localizedName: String {
            switch self {
            case .low: return "common.priority.low".localized
            case .medium: return "common.priority.medium".localized
            case .high: return "common.priority.high".localized
            case .critical: return "common.priority.critical".localized
            }
        }
    }
}

// MARK: - Calculation Utilities

extension CalculatorService {
    private func formatCurrencyLocalized(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: NSNumber(value: amount)) ?? "CHF \(amount)"
    }
    /// Format currency amount for display
    static func formatCurrency(_ amount: Double, currency: String = "CHF") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount))"
    }
    
    /// Calculate annual amount from monthly
    static func annualAmount(from monthlyAmount: Double) -> Double {
        return monthlyAmount * 12
    }
    
    /// Calculate percentage of income
    static func percentageOfIncome(amount: Double, income: Double) -> Double {
        guard income > 0 else { return 0 }
        return (amount / income) * 100
    }
    
    /// Validate income input
    static func validateIncome(_ income: Double) -> ValidationResult {
        if income < 0 {
            return .invalid("Income cannot be negative")
        }
        
        if income > 1000000 {
            return .invalid("Income seems unusually high")
        }
        
        return .valid
    }
    
    /// Validate family size input
    static func validateFamilySize(_ size: Int) -> ValidationResult {
        if size < 1 {
            return .invalid("Family size must be at least 1")
        }
        
        if size > 20 {
            return .invalid("Family size seems unusually large")
        }
        
        return .valid
    }
    
    enum ValidationResult {
        case valid
        case invalid(String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            case .invalid: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .valid: return nil
            case .invalid(let message): return message
            }
        }
    }
}

