import SwiftUI

/// Branded splash screen shown briefly while the app launches and the
/// Supabase session is being restored.
struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.accentColor.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 26)
                    )
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 10)

                Text("Therapy Notes")
                    .font(.largeTitle.bold())
            }
            .scaleEffect(isVisible ? 1 : 0.85)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashView()
}
