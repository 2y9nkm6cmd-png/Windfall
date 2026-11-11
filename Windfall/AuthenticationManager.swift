import Foundation
import Observation
import GoogleSignIn

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Holds the sign-in state for the whole app.
///
/// `@Observable` is what lets a screen redraw itself when one of these
/// values changes. It replaces the older `ObservableObject` / `@Published`
/// pair, and must match how the screens ask for it:
/// `@Environment(AuthenticationManager.self)`.
@MainActor
@Observable
final class AuthenticationManager {

    var isSignedIn: Bool = false
    var userEmail: String = ""
    var errorMessage: String? = nil

    /// True once you have chosen to use Windfall without a Google account.
    /// Only the Google Sheets link needs Google. The garden records, the
    /// journal and Eira all live on the device and work without it.
    /// The choice is remembered in UserDefaults, a small settings store,
    /// so the app does not ask again each time it opens.
    var isUsingWithoutGoogle: Bool = UserDefaults.standard.bool(forKey: "windfallWithoutGoogle")

    // The OAuth scopes we need — Sheets for data, Drive for file metadata
    private let requiredScopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive.readonly"
    ]

    init() {
        restorePreviousSignIn()
    }

    // MARK: - Restore previous session

    private func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self else { return }
            if let error {
                // Not a real failure — usually just means nobody has signed in yet.
                print("No previous sign-in restored: \(error.localizedDescription)")
                return
            }
            if let user {
                // Google may call back on a background thread. Screens must
                // only be changed from the main thread, so hop there first.
                Task { @MainActor in
                    self.isSignedIn = true
                    self.userEmail = user.profile?.email ?? ""
                }
            }
        }
    }

    // MARK: - Sign in

    func signIn() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find a window to present sign-in."
            return
        }
        presentSignIn(presenting: rootViewController)

        #elseif os(macOS)
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            errorMessage = "Could not find a window to present sign-in."
            return
        }
        presentSignIn(presenting: window)
        #endif
    }

    // Two platforms, two presenter types, one piece of completion logic.
    #if os(iOS)
    private func presentSignIn(presenting viewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: requiredScopes
        ) { [weak self] result, error in
            guard let self else { return }
            // Same hop to the main thread as in restorePreviousSignIn.
            Task { @MainActor in
                self.handleSignInResult(result, error)
            }
        }
    }
    #elseif os(macOS)
    private func presentSignIn(presenting window: NSWindow) {
        GIDSignIn.sharedInstance.signIn(
            withPresenting: window,
            hint: nil,
            additionalScopes: requiredScopes
        ) { [weak self] result, error in
            guard let self else { return }
            // Same hop to the main thread as in restorePreviousSignIn.
            Task { @MainActor in
                self.handleSignInResult(result, error)
            }
        }
    }
    #endif

    private func handleSignInResult(_ result: GIDSignInResult?, _ error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            return
        }
        guard let user = result?.user else {
            errorMessage = "Sign-in succeeded but no user was returned."
            return
        }
        isSignedIn = true
        userEmail = user.profile?.email ?? ""
        errorMessage = nil
    }

    // MARK: - Using the app without Google

    func continueWithoutGoogle() {
        isUsingWithoutGoogle = true
        UserDefaults.standard.set(true, forKey: "windfallWithoutGoogle")
    }

    // MARK: - Sign out

    /// Signs out of Google and returns to the welcome screen.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = ""
        isUsingWithoutGoogle = false
        UserDefaults.standard.set(false, forKey: "windfallWithoutGoogle")
    }

    // MARK: - Access token for API calls

    func validAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }
        try await user.refreshTokensIfNeeded()
        return user.accessToken.tokenString
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notSignedIn
    case tokenUnavailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn:       return "You are not signed in."
        case .tokenUnavailable:  return "Could not retrieve a valid access token."
        }
    }
}
