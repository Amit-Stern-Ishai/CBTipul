import SwiftUI

/// Branded splash screen shown briefly while the app launches and the
/// Supabase session is being restored.
struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Theme.base
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: Theme.accentFill.opacity(0.35), radius: 16, y: 10)

                Text(L10n.appTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textBright)
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
