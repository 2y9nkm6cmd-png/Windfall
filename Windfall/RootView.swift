import SwiftUI

struct RootView: View {

    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        if authManager.isSignedIn {
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
