import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DocumentStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Environment(SubscriptionService.self) private var subscriptions
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @State private var showingAddProfile = false
    @State private var showingSignOutConfirm = false
    @State private var showingPaywall = false
    @State private var newName = ""
    @State private var newRelationship = Profile.Relationship.spouse
    @State private var biometricLabel = ""

    var body: some View {
        NavigationStack {
            Form {
                // Privacy
                Section {
                    if !biometricLabel.isEmpty {
                        Toggle(isOn: $biometricLockEnabled) {
                            Label("\(biometricLabel) Lock",
                                  systemImage: biometricLabel == "Face ID" ? "faceid" : "touchid")
                        }
                        .tint(Color.claroAccent)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(biometricLabel.isEmpty
                         ? "Biometric lock is not available on this device."
                         : "Require \(biometricLabel) when opening Claro Lens after 60 seconds in the background.")
                }

                // Family profiles
                Section {
                    // "Me" row — always present, not deletable
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.claroAccent)
                            .frame(width: 20)
                        Text("Me")
                        Spacer()
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.profiles) { profile in
                        HStack(spacing: 12) {
                            Image(systemName: profile.relationship.systemImage)
                                .foregroundStyle(profile.relationship.color)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                Text(profile.relationship.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { store.deleteProfile(store.profiles[i]) }
                    }

                    Button {
                        showingAddProfile = true
                    } label: {
                        Label("Add Family Member", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.claroAccent)
                    }
                } header: {
                    Text("Family")
                } footer: {
                    Text("Track documents and spending separately for each person. Swipe to remove.")
                }

                // Subscription
                Section("Subscription") {
                    if subscriptions.isProUser {
                        Label("Claro Pro — Active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.claroAccent)
                    } else {
                        let used = store.documents.count
                        let limit = SubscriptionService.freeScansLimit
                        LabeledContent("Free scans used", value: "\(min(used, limit)) of \(limit)")
                        Button("Upgrade to Pro") { showingPaywall = true }
                            .foregroundStyle(Color.claroAccent)
                    }
                    Button {
                        Task { try? await subscriptions.restore() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                    .foregroundStyle(Color.claroSubtle)
                }

                // About
                Section("About") {
                    LabeledContent("App", value: "Claro Lens")
                    LabeledContent("Version", value: "1.0 (4)")
                    LabeledContent("Documents", value: "\(store.documents.count)")
                    if !auth.displayName.isEmpty {
                        LabeledContent("Signed in as", value: auth.displayName)
                    }
                }

                // Account
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear { detectBiometric() }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .confirmationDialog("Sign out of Claro Lens?", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your documents will remain on this device.")
            }
            .sheet(isPresented: $showingAddProfile) {
                AddProfileSheet(
                    name: $newName,
                    relationship: $newRelationship,
                    onSave: {
                        store.addProfile(Profile(name: newName, relationship: newRelationship))
                        newName = ""
                        newRelationship = .spouse
                        showingAddProfile = false
                    },
                    onCancel: { showingAddProfile = false }
                )
            }
        }
    }

    private func detectBiometric() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        biometricLabel = ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }
}

// MARK: - Add Profile Sheet

private struct AddProfileSheet: View {
    @Binding var name: String
    @Binding var relationship: Profile.Relationship
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Relationship", selection: $relationship) {
                        ForEach(Profile.Relationship.allCases, id: \.self) { rel in
                            Label(rel.rawValue, systemImage: rel.systemImage).tag(rel)
                        }
                    }
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", action: onSave)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
