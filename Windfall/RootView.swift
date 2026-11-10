import SwiftUI

struct RootView: View {

    @EnvironmentObject var authManager: AuthenticationManager

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
        .environmentObject(AuthenticationManager())
}
