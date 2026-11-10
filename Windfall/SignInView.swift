import SwiftUI
import GoogleSignInSwift

struct SignInView: View {

    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // App icon and name
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Windfall")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Your garden planning companion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign-in button and error
            VStack(spacing: 16) {
                GoogleSignInButton(scheme: .light, style: .wide) {
                    authManager.signIn()
                }
                .frame(height: 50)
                .frame(maxWidth: 320)

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationManager())
}
