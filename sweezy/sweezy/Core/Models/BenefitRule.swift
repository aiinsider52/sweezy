//
//  BenefitRule.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation

/// Benefit calculation rules and results
struct BenefitRule: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: BenefitCategory
    let canton: Canton
    let permitTypes: [PermitType]
    let conditions: [BenefitCondition]
    let calculationFormula: CalculationFormula
    let maxAmount: Double?
    let minAmount: Double?
    let currency: String
    let validFrom: Date
    let validUntil: Date?
    let isActive: Bool
    let officialSource: String? // URL to official information
    let lastUpdated: Date
    let language: String? // ISO 639-1 code (uk, ru, en, de)
    let verifiedAt: Date? // When rule was last verified
    let source: String? // Alternative to officialSource for consistency
    
    init(
        name: String,
        description: String,
        category: BenefitCategory,
        canton: Canton,
        permitTypes: [PermitType],
        conditions: [BenefitCondition],
        calculationFormula: CalculationFormula,
        maxAmount: Double? = nil,
        minAmount: Double? = nil,
        currency: String = "CHF",
        validFrom: Date = Date(),
        validUntil: Date? = nil,
        isActive: Bool = true,
        officialSource: String? = nil,
        language: String? = nil,
        verifiedAt: Date? = nil,
        source: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.canton = canton
        self.permitTypes = permitTypes
        self.conditions = conditions
        self.calculationFormula = calculationFormula
        self.maxAmount = maxAmount
        self.minAmount = minAmount
        self.currency = currency
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.isActive = isActive
        self.officialSource = officialSource
        self.lastUpdated = Date()
        self.language = language
        self.verifiedAt = verifiedAt
        self.source = source
    }
    
    // Be tolerant to invalid UUIDs and partial data in bundled JSON
    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, canton, permitTypes, conditions,
             calculationFormula, maxAmount, minAmount, currency,
             validFrom, validUntil, isActive, officialSource, lastUpdated,
             language, verifiedAt, source
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try? c.decode(String.self, forKey: .id),
           let parsed = UUID(uuidString: idString) {
            self.id = parsed
        } else if let parsed = try? c.decode(UUID.self, forKey: .id) {
            self.id = parsed
        } else {
            self.id = UUID()
        }
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decode(BenefitCategory.self, forKey: .category)) ?? .other
        self.canton = (try? c.decode(Canton.self, forKey: .canton)) ?? .zurich
        self.permitTypes = (try? c.decode([PermitType].self, forKey: .permitTypes)) ?? []
        self.conditions = (try? c.decode([BenefitCondition].self, forKey: .conditions)) ?? []
        self.calculationFormula = (try? c.decode(CalculationFormula.self, forKey: .calculationFormula)) ?? CalculationFormula(type: .fixed, baseAmount: 0)
        self.maxAmount = try? c.decode(Double.self, forKey: .maxAmount)
        self.minAmount = try? c.decode(Double.self, forKey: .minAmount)
        self.currency = (try? c.decode(String.self, forKey: .currency)) ?? "CHF"
        self.validFrom = (try? c.decode(Date.self, forKey: .validFrom)) ?? Date(timeIntervalSince1970: 0)
        self.validUntil = try? c.decode(Date.self, forKey: .validUntil)
        self.isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true
        self.officialSource = try? c.decode(String.self, forKey: .officialSource)
        self.lastUpdated = (try? c.decode(Date.self, forKey: .lastUpdated)) ?? Date()
        self.language = try? c.decode(String.self, forKey: .language)
        self.verifiedAt = try? c.decode(Date.self, forKey: .verifiedAt)
        self.source = try? c.decode(String.self, forKey: .source)
    }
    
    /// Check if user is eligible for this benefit
    func isEligible(for profile: UserProfile, income: Double, familySize: Int) -> Bool {
        // Check permit type
        guard permitTypes.contains(profile.permitType) else { return false }
        
        // Check if rule is active and valid
        guard isActive else { return false }
        
        let now = Date()
        guard now >= validFrom else { return false }
        
        if let validUntil = validUntil, now > validUntil {
            return false
        }
        
        // Check all conditions
        return conditions.allSatisfy { condition in
            condition.isSatisfied(income: income, familySize: familySize, hasChildren: profile.hasChildren)
        }
    }
    
    /// Calculate benefit amount
    func calculateBenefit(income: Double, familySize: Int, hasChildren: Bool) -> BenefitCalculationResult {
        guard isActive else {
            return BenefitCalculationResult(
                ruleId: id,
                amount: 0,
                isEligible: false,
                reason: "Benefit rule is not active"
            )
        }
        
        // Check conditions
        let eligibilityCheck = conditions.allSatisfy { condition in
            condition.isSatisfied(income: income, familySize: familySize, hasChildren: hasChildren)
        }
        
        guard eligibilityCheck else {
            let failedConditions = conditions.filter { !$0.isSatisfied(income: income, familySize: familySize, hasChildren: hasChildren) }
            let reason = failedConditions.map { $0.description }.joined(separator: ", ")
            return BenefitCalculationResult(
                ruleId: id,
                amount: 0,
                isEligible: false,
                reason: "Not eligible: \(reason)"
            )
        }
        
        // Calculate amount using formula
        let calculatedAmount = calculationFormula.calculate(
            income: income,
            familySize: familySize,
            hasChildren: hasChildren
        )
        
        // Apply min/max limits
        var finalAmount = calculatedAmount
        if let minAmount = minAmount {
            finalAmount = max(finalAmount, minAmount)
        }
        if let maxAmount = maxAmount {
            finalAmount = min(finalAmount, maxAmount)
        }
        
        return BenefitCalculationResult(
            ruleId: id,
            amount: finalAmount,
            isEligible: true,
            reason: nil,
            calculationDetails: calculationFormula.getCalculationDetails(
                income: income,
                familySize: familySize,
                hasChildren: hasChildren
            )
        )
    }
}

/// Benefit categories
enum BenefitCategory: String, CaseIterable, Codable, Hashable {
    case healthInsurance = "health_insurance"
    case housing = "housing"
    case childcare = "childcare"
    case education = "education"
    case transport = "transport"
    case food = "food"
    case integration = "integration"
    case emergency = "emergency"
    case legal = "legal"
    case other = "other"
    
    var localizedName: String {
        switch self {
        case .healthInsurance: return "benefit.category.health_insurance".localized
        case .housing: return "benefit.category.housing".localized
        case .childcare: return "benefit.category.childcare".localized
        case .education: return "benefit.category.education".localized
        case .transport: return "benefit.category.transport".localized
        case .food: return "benefit.category.food".localized
        case .integration: return "benefit.category.integration".localized
        case .emergency: return "benefit.category.emergency".localized
        case .legal: return "benefit.category.legal".localized
        case .other: return "benefit.category.other".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .healthInsurance: return "cross.case" // iOS 14+
        case .housing: return "house" // iOS 13+
        case .childcare: return "figure.2.and.child.holdinghands" // iOS 15+
        case .education: return "graduationcap" // iOS 13+
        case .transport: return "bus" // iOS 13+
        case .food: return "cart" // iOS 13+
        case .integration: return "person.2" // iOS 13+
        case .emergency: return "exclamationmark.triangle" // iOS 13+
            case .legal: return "hammer" // safer fallback across iOS versions
        case .other: return "ellipsis" // iOS 13+
        }
    }
    
    var color: String {
        switch self {
        case .healthInsurance: return "red"
        case .housing: return "green"
        case .childcare: return "pink"
        case .education: return "blue"
        case .transport: return "cyan"
        case .food: return "orange"
        case .integration: return "purple"
        case .emergency: return "red"
        case .legal: return "brown"
        case .other: return "gray"
        }
    }
}

/// Conditions for benefit eligibility
struct BenefitCondition: Codable, Hashable {
    let id: UUID
    let type: ConditionType
    let `operator`: ComparisonOperator
    let value: Double
    let description: String
    
    init(type: ConditionType, `operator`: ComparisonOperator, value: Double, description: String) {
        self.id = UUID()
        self.type = type
        self.`operator` = `operator`
        self.value = value
        self.description = description
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, `operator`, value, description
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try? c.decode(String.self, forKey: .id),
           let parsed = UUID(uuidString: idString) {
            self.id = parsed
        } else if let parsed = try? c.decode(UUID.self, forKey: .id) {
            self.id = parsed
        } else {
            self.id = UUID()
        }
        self.type = (try? c.decode(ConditionType.self, forKey: .type)) ?? .income
        self.`operator` = (try? c.decode(ComparisonOperator.self, forKey: .operator)) ?? .greaterThanOrEqual
        self.value = (try? c.decode(Double.self, forKey: .value)) ?? 0
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
    }
    
    /// Check if condition is satisfied
    func isSatisfied(income: Double, familySize: Int, hasChildren: Bool) -> Bool {
        let actualValue: Double
        
        switch type {
        case .income:
            actualValue = income
        case .familySize:
            actualValue = Double(familySize)
        case .hasChildren:
            actualValue = hasChildren ? 1.0 : 0.0
        case .incomePerPerson:
            actualValue = familySize > 0 ? income / Double(familySize) : income
        }
        
        return `operator`.compare(actualValue, value)
    }
}

/// Condition types
enum ConditionType: String, CaseIterable, Codable, Hashable {
    case income = "income"
    case familySize = "family_size"
    case hasChildren = "has_children"
    case incomePerPerson = "income_per_person"
    
    var localizedName: String {
        switch self {
        case .income: return "calculator.condition.income".localized
        case .familySize: return "calculator.condition.family_size".localized
        case .hasChildren: return "calculator.condition.has_children".localized
        case .incomePerPerson: return "calculator.condition.income_per_person".localized
        }
    }
}

/// Comparison operators
enum ComparisonOperator: String, CaseIterable, Codable, Hashable {
    case lessThan = "less_than"
    case lessThanOrEqual = "less_than_or_equal"
    case equal = "equal"
    case greaterThanOrEqual = "greater_than_or_equal"
    case greaterThan = "greater_than"
    case notEqual = "not_equal"
    
    func compare(_ left: Double, _ right: Double) -> Bool {
        switch self {
        case .lessThan: return left < right
        case .lessThanOrEqual: return left <= right
        case .equal: return abs(left - right) < 0.01 // Handle floating point comparison
        case .greaterThanOrEqual: return left >= right
        case .greaterThan: return left > right
        case .notEqual: return abs(left - right) >= 0.01
        }
    }
    
    var symbol: String {
        switch self {
        case .lessThan: return "<"
        case .lessThanOrEqual: return "≤"
        case .equal: return "="
        case .greaterThanOrEqual: return "≥"
        case .greaterThan: return ">"
        case .notEqual: return "≠"
        }
    }
}

/// Calculation formulas for benefits
struct CalculationFormula: Codable, Hashable {
    let type: FormulaType
    let baseAmount: Double?
    let percentage: Double?
    let perPersonAmount: Double?
    let childBonus: Double?
    let parameters: [String: Double] // Additional parameters
    
    init(
        type: FormulaType,
        baseAmount: Double? = nil,
        percentage: Double? = nil,
        perPersonAmount: Double? = nil,
        childBonus: Double? = nil,
        parameters: [String: Double] = [:]
    ) {
        self.type = type
        self.baseAmount = baseAmount
        self.percentage = percentage
        self.perPersonAmount = perPersonAmount
        self.childBonus = childBonus
        self.parameters = parameters
    }
    
    /// Calculate benefit amount
    func calculate(income: Double, familySize: Int, hasChildren: Bool) -> Double {
        switch type {
        case .fixed:
            return baseAmount ?? 0
            
        case .percentage:
            let rate = percentage ?? 0
            return income * (rate / 100.0)
            
        case .perPerson:
            let amount = perPersonAmount ?? 0
            return amount * Double(familySize)
            
        case .incomeBasedSliding:
            // Sliding scale based on income
            let maxIncome = parameters["max_income"] ?? 100000
            let maxBenefit = baseAmount ?? 0
            
            if income >= maxIncome {
                return 0
            }
            
            let ratio = 1.0 - (income / maxIncome)
            return maxBenefit * ratio
            
        case .familySizeBased:
            let baseAmount = self.baseAmount ?? 0
            let perPersonAmount = self.perPersonAmount ?? 0
            let childBonus = hasChildren ? (self.childBonus ?? 0) : 0
            
            return baseAmount + (perPersonAmount * Double(familySize)) + childBonus
            
        case .complex:
            // Custom complex calculation
            // This would be implemented based on specific rules
            return baseAmount ?? 0
        }
    }
    
    /// Get calculation details for transparency
    func getCalculationDetails(income: Double, familySize: Int, hasChildren: Bool) -> String {
        switch type {
        case .fixed:
            return "Fixed amount: CHF \(baseAmount ?? 0)"
            
        case .percentage:
            let rate = percentage ?? 0
            let amount = calculate(income: income, familySize: familySize, hasChildren: hasChildren)
            return "\(rate)% of income (CHF \(income)) = CHF \(amount)"
            
        case .perPerson:
            let amount = perPersonAmount ?? 0
            return "CHF \(amount) × \(familySize) persons = CHF \(calculate(income: income, familySize: familySize, hasChildren: hasChildren))"
            
        case .incomeBasedSliding:
            return "Sliding scale based on income level"
            
        case .familySizeBased:
            return "Base amount + per person amount + child bonus"
            
        case .complex:
            return "Complex calculation based on multiple factors"
        }
    }
}

/// Formula types
enum FormulaType: String, CaseIterable, Codable, Hashable {
    case fixed = "fixed"
    case percentage = "percentage"
    case perPerson = "per_person"
    case incomeBasedSliding = "income_based_sliding"
    case familySizeBased = "family_size_based"
    case complex = "complex"
    
    var localizedName: String {
        switch self {
        case .fixed: return "calculator.formula.fixed".localized
        case .percentage: return "calculator.formula.percentage".localized
        case .perPerson: return "calculator.formula.per_person".localized
        case .incomeBasedSliding: return "calculator.formula.income_based_sliding".localized
        case .familySizeBased: return "calculator.formula.family_size_based".localized
        case .complex: return "calculator.formula.complex".localized
        }
    }
}

/// Benefit calculation result
struct BenefitCalculationResult: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let ruleId: UUID
    let amount: Double
    let isEligible: Bool
    let reason: String?
    let calculationDetails: String?
    let calculatedAt: Date
    
    init(
        ruleId: UUID,
        amount: Double,
        isEligible: Bool,
        reason: String? = nil,
        calculationDetails: String? = nil
    ) {
        self.id = UUID()
        self.ruleId = ruleId
        self.amount = amount
        self.isEligible = isEligible
        self.reason = reason
        self.calculationDetails = calculationDetails
        self.calculatedAt = Date()
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "selected_locale") ?? Locale.current.identifier)
        return formatter.string(from: NSNumber(value: amount)) ?? "CHF \(amount)"
    }
}
