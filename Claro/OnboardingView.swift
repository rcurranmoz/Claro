import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var showingInsuranceSetup = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.claroBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero
                ZStack {
                    Circle()
                        .fill(Color.claroAccent.opacity(0.08))
                        .frame(width: pulse ? 200 : 180, height: pulse ? 200 : 180)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .fill(Color.claroAccent.opacity(0.14))
                        .frame(width: pulse ? 148 : 134, height: pulse ? 148 : 134)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3), value: pulse)

                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.claroAccent)
                }
                .padding(.bottom, 40)
                .onAppear { pulse = true }

                // Headline
                VStack(spacing: 10) {
                    Text("Meet Claro.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Medical bills are confusing by design.\nWe fix that.")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.claroSubtle)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 48)

                // Feature list
                VStack(spacing: 18) {
                    FeatureRow(icon: "doc.viewfinder.fill",  color: .claroAccent,  text: "Scan any bill, EOB, or lab result")
                    FeatureRow(icon: "magnifyingglass",       color: .cyan,         text: "Catch billing errors and overcharges")
                    FeatureRow(icon: "dollarsign.circle.fill",color: .mint,         text: "See exactly what you owe and why")
                    FeatureRow(icon: "checklist",             color: Color(hex: "C084FC"), text: "Get a clear action plan")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)

                // CTAs
                VStack(spacing: 12) {
                    Button {
                        showingInsuranceSetup = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.fill")
                            Text("Set Up Insurance")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.claroAccent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        onComplete()
                    } label: {
                        Text("Start Without Insurance")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.claroSubtle)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 36)
            }
        }
        .sheet(isPresented: $showingInsuranceSetup, onDismiss: onComplete) {
            InsuranceSetupView()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.85))
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(DocumentStore())
}
