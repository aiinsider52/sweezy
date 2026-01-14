//
//  BenefitsCalculatorView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct BenefitsCalculatorView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var income: String = ""
    @State private var familySize: Int = 1
    @State private var hasChildren: Bool = false
    @State private var selectedCanton: Canton = .zurich
    @State private var selectedPermitType: PermitType = .s
    @State private var results: [BenefitCalculationResult] = []
    @State private var isCalculating: Bool = false
    @State private var showingResults: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Input form
                    inputFormSection
                    
                    // Calculate button
                    calculateButtonSection
                    
                    // Results
                    if showingResults {
                        resultsSection
                    }
                    
                    // Disclaimer
                    disclaimerSection
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("calculator.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "function")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.primaryGradient)
            
            Text("Calculate your potential benefits and subsidies in Switzerland")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var inputFormSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Income
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("calculator.income".localized)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("0", text: $income)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Family size
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("calculator.family_size".localized)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Stepper(value: $familySize, in: 1...20) {
                    Text("\(familySize) \(familySize == 1 ? "person" : "people")")
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            
            // Has children
            Toggle("calculator.has_children".localized, isOn: $hasChildren)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
            
            // Canton
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("calculator.canton".localized)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Picker("Canton", selection: $selectedCanton) {
                    ForEach(Canton.allCases, id: \.self) { canton in
                        Text(canton.localizedName).tag(canton)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Permit type
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("calculator.permit_type".localized)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Picker("Permit Type", selection: $selectedPermitType) {
                    ForEach(PermitType.allCases, id: \.self) { permit in
                        Text(permit.localizedName).tag(permit)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var calculateButtonSection: some View {
        PrimaryButton(
            "calculator.calculate".localized,
            isLoading: isCalculating,
            isDisabled: income.isEmpty || isCalculating
        ) {
            calculateBenefits()
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("calculator.results".localized)
                .font(Theme.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            
            if results.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "guides.no_results".localized,
                    subtitle: "guides.no_results_subtitle".localized
                )
            } else {
                ForEach(results) { result in
                    BenefitResultCard(result: result)
                }
            }
        }
    }
    
    private var disclaimerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Important Notice")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                
                Text("calculator.disclaimer".localized)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }
    
    private func calculateBenefits() {
        guard let incomeValue = Double(income) else { return }
        
        isCalculating = true
        
        // Simulate calculation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockProfile = UserProfile(
                fullName: "User",
                canton: selectedCanton,
                permitType: selectedPermitType,
                familySize: familySize,
                hasChildren: hasChildren
            )
            
            results = appContainer.calculatorService.calculateBenefits(
                for: mockProfile,
                income: incomeValue,
                familySize: familySize,
                canton: selectedCanton,
                rules: appContainer.contentService.benefitRules
            )
            
            isCalculating = false
            showingResults = true
        }
    }
}

struct BenefitResultCard: View {
    let result: BenefitCalculationResult
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: result.isEligible ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.isEligible ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(result.isEligible ? "calculator.eligible".localized : "calculator.not_eligible".localized)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        if result.isEligible {
                            Text("calculator.estimated_amount".localized(with: result.formattedAmount))
                                .font(Theme.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                
                if let reason = result.reason {
                    Text(reason)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                if result.isEligible {
                    PrimaryButton("calculator.apply_now".localized, style: .outline) {
                        // Handle apply action
                    }
                }
            }
        }
    }
}

struct EmptyResultsView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "doc.text.magnifyingglass",
            title: "guides.no_results".localized,
            subtitle: "guides.no_results_subtitle".localized
        )
    }
}

#Preview {
    BenefitsCalculatorView()
        .environmentObject(AppContainer())
}
