import SwiftUI
import GoogleSignInSwift

struct SignInView: View {

    @Environment(AuthenticationManager.self) private var authManager

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

                // The way in that needs no account. Google is only used for
                // the spreadsheet link, which can be connected later.
                Button("Continue without signing in") {
                    authManager.continueWithoutGoogle()
                }

                Text("Google is only needed for the Sheets link. Everything else stays on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
        .environment(AuthenticationManager())
}
