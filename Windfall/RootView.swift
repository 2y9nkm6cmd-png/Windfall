import SwiftUI

struct RootView: View {

    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        // Show the app if signed in to Google, or if you chose to carry on
        // without it. `||` means "or".
        if authManager.isSignedIn || authManager.isUsingWithoutGoogle {
            MainTabView()
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView()
        .environment(AuthenticationManager())
}
