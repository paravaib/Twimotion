//
//  ProUpgradeView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import StoreKit

/// Pro upgrade view with pricing and benefits
struct ProUpgradeView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanType = .yearly
    @State private var showingError = false
    
    enum PlanType {
        case monthly
        case yearly
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Benefits
                    benefitsSection
                    
                    // Pricing
                    pricingSection
                    
                    // Purchase button
                    purchaseButton
                    
                    // Restore purchases
                    restoreButton
                }
                .padding(24)
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Close") {
                    dismiss()
                }
            )
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(iapManager.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Unlock Unlimited GIFs")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Create as many animated GIFs as you want, whenever you want")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pro Benefits")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                benefitRow(
                    icon: "infinity",
                    title: "Unlimited GIFs",
                    description: "Create as many GIFs as you want, no daily limits"
                )
                
                benefitRow(
                    icon: "crown.fill",
                    title: "Pro Status",
                    description: "Show your Pro status with the crown badge"
                )
                
                benefitRow(
                    icon: "watermark",
                    title: "Twimotion Branding",
                    description: "Keep the Twimotion watermark for brand recognition"
                )
                
                benefitRow(
                    icon: "clock",
                    title: "No Waiting",
                    description: "No need to wait until midnight for more GIFs"
                )
            }
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 20) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                // Monthly plan
                pricingCard(
                    product: iapManager.monthlyProduct,
                    title: "Monthly",
                    isSelected: selectedPlan == .monthly,
                    isPopular: false
                ) {
                    selectedPlan = .monthly
                }
                
                // Yearly plan
                pricingCard(
                    product: iapManager.yearlyProduct,
                    title: "Yearly",
                    isSelected: selectedPlan == .yearly,
                    isPopular: true,
                    savings: calculateSavings()
                ) {
                    selectedPlan = .yearly
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button(action: {
            Task {
                await purchaseSelectedPlan()
            }
        }) {
            HStack(spacing: 12) {
                if iapManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                
                Text(iapManager.isLoading ? "Processing..." : "Start Pro Subscription")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(iapManager.isLoading || iapManager.products.isEmpty)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button(action: {
            Task {
                await restorePurchases()
            }
        }) {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(iapManager.isLoading)
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func pricingCard(
        product: Product?,
        title: String,
        isSelected: Bool,
        isPopular: Bool,
        savings: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isPopular {
                    HStack {
                        Spacer()
                        Text("MOST POPULAR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange)
                            )
                        Spacer()
                    }
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let product = product {
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(product.displayPrice)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(product.subscription?.subscriptionPeriod.unit == .month ? "per month" : "per year")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSelected ? Color.blue : (isPopular ? Color.blue : Color(.systemGray4)),
                                    lineWidth: isSelected ? 2 : (isPopular ? 2 : 1)
                                )
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func purchaseSelectedPlan() async {
        switch selectedPlan {
        case .monthly:
            await iapManager.purchaseMonthly()
        case .yearly:
            await iapManager.purchaseYearly()
        }
        
        // Check if purchase was successful
        if iapManager.isProUser {
            dismiss()
        } else if iapManager.errorMessage != nil {
            showingError = true
        }
    }
    
    private func restorePurchases() async {
        await iapManager.restorePro()
        
        // Check if restore was successful
        if iapManager.isProUser {
            dismiss()
        } else if iapManager.errorMessage != nil {
            showingError = true
        }
    }
    
    private func calculateSavings() -> String? {
        guard let monthly = iapManager.monthlyProduct,
              let yearly = iapManager.yearlyProduct else { return nil }
        
        // Product.price is Decimal. Do Decimal math, then convert safely.
        let monthlyYearlyPrice = monthly.price * Decimal(12)
        guard monthlyYearlyPrice > 0 else { return nil }
        
        let savings = monthlyYearlyPrice - yearly.price
        guard savings > 0 else { return nil }
        
        // percentage = (savings / monthlyYearlyPrice) * 100
        let percentageDecimal = (savings as NSDecimalNumber)
            .dividing(by: monthlyYearlyPrice as NSDecimalNumber)
            .multiplying(by: 100)
        
        let percentage = Int((percentageDecimal.doubleValue).rounded())
        return "Save \(percentage)%"
    }
}

#Preview {
    ProUpgradeView()
        .environmentObject(IAPManager.shared)
}
