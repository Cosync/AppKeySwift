//
//  AppKeyGoogleAuth.swift
//  AppKeySwift
//
//  Created by Tola Voeung on 30/10/24.
//

import Foundation
import GoogleSignIn

@available(iOS 15, *)
@MainActor public var AppKeyGAuth = AppKeyGoogleAuth.shared


@available(iOS 15, *)
@MainActor public class AppKeyGoogleAuth: ObservableObject {
    
    public static let shared = AppKeyGoogleAuth()
    
    @Published public var isLoggedIn: Bool = false
    @Published public var errorMessage: String = ""
    @Published public var idToken: String = ""
    
    public var googleClientID: String = ""
    public var givenName: String = ""
    public var familyName: String = ""
    public var email: String = ""
    public var userId: String = ""
    public var profilePicUrl: String = ""
     
   
    // Configure
    @MainActor public func configure(googleClientID: String) {
        self.googleClientID = googleClientID
    }
    
    @MainActor public func signIn(){
        clear()
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {return}

        let config = GIDConfiguration(clientID: self.googleClientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, completion: { user, error in
          
            if let err = error?.localizedDescription{
                self.errorMessage = err
            }
            else if(GIDSignIn.sharedInstance.currentUser != nil){
                self.getUserData()
            }
            else {
                self.errorMessage = "Something went wrong"
            }
        })
    }
    
    private func getUserData(){
        
        if(GIDSignIn.sharedInstance.currentUser != nil){
            
            let user = GIDSignIn.sharedInstance.currentUser
           
            guard let user = user else { return }
           
            let givenName = user.profile?.givenName
            self.familyName = user.profile?.familyName ?? ""
            let profilePicUrl = user.profile!.imageURL(withDimension: 100)!.absoluteString
            self.givenName = givenName ?? ""
            self.email = user.profile?.email ?? ""
            self.userId = user.userID ?? ""
            self.idToken = user.idToken?.tokenString ?? ""
            self.profilePicUrl = profilePicUrl
            self.isLoggedIn = true
            
        }
    }
    
    public func signOut(){
        GIDSignIn.sharedInstance.signOut()
        clear()
    }
    
    func clear(){
        self.isLoggedIn = false
        self.idToken = ""
        self.errorMessage = ""
    }
}
