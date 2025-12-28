import SwiftUI
import SwiftData
import Photos

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @State private var photoService = PhotoLibraryService.shared
    @State private var showingPermissionDenied = false
    @State private var searchText = ""
    @State private var showingSettings = false

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        Group {
            if photoService.authorizationStatus == .notDetermined {
                PermissionRequestView {
                    Task {
                        await photoService.requestAuthorization()
                    }
                }
            } else if !photoService.isAuthorized {
                PermissionDeniedView()
            } else {
                mainContent
            }
        }
        .task {
            if photoService.authorizationStatus == .notDetermined {
                _ = await photoService.requestAuthorization()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if searchText.isEmpty {
                    HomeView()
                } else {
                    SearchResultsView(searchText: searchText)
                        .padding(.top, 60)
                }

                // Floating search bar with glass effect
                VStack(spacing: 0) {
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()
                }
                .background(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 220)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.55),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct PermissionRequestView: View {
    let onRequest: () -> Void
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1),
                    Color.pink.opacity(0.05)
                ],
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)

            VStack(spacing: 32) {
                Spacer()

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 70, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 12) {
                    Text("iFauxto")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("Your photos. Your way.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    FeatureRow(icon: "folder.fill", text: "Organize folders YOUR way")
                    FeatureRow(icon: "sparkles", text: "AI-powered smart search")
                    FeatureRow(icon: "slider.horizontal.3", text: "Pro editing tools")
                }
                .padding(.vertical, 20)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: onRequest) {
                        HStack {
                            Text("Get Started")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)

                    Text("We'll need photo access. Unlike Apple,\nwe won't auto-create 47 albums.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 48)
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Photos Access Denied")
                .font(.title)
                .fontWeight(.bold)

            Text("We can't organize your photos without access.\nGo to Settings to enable it.\n\nWe promise we won't do anything weird with them. Unlike some companies, we actually tell you what we need and why.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 48)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Folder.self, UserPreferences.self], inMemory: true)
}
