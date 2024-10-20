//
//  AKPasskeysManager.swift
//  appkey
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
//  Created by Tola Voeung on 8/10/24.
//

import Foundation
import AuthenticationServices
import SwiftUI
import os

@available(macOS 13.0, *)
public class AKPasskeysManager:NSObject, ObservableObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    static let shared = AKPasskeysManager()
    var authenticationAnchor: ASPresentationAnchor?
    @Published var attestationResponse: String?
    @Published var assertionnResponse: String?
    @Published var verifcationResponse: String?
    @Published var status: String?
    @Published var errorResponse: String?
    var attestation: AKAttestation?
    var assertion: AKAssertion?
    let logger = Logger()
    
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        
        guard let authorizationError = error as? ASAuthorizationError else {
            logger.log("Unexpected authorization error: \(error.localizedDescription)")
            
            errorResponse = error.localizedDescription
            
            return
        }
        
        if authorizationError.code == .canceled {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            logger.log("Request canceled.")
            logger.log("Error: \((error as NSError).userInfo)")
            let error = (error as NSError).userInfo
            errorResponse = error["NSLocalizedFailureReason"] as? String
            status = "canceled"
        } else {
            // Another ASAuthorization error.
            // Note: The userInfo dictionary contains useful information.
            let error = (error as NSError).userInfo
            logger.log("Error: \(error)")
            errorResponse = error["NSLocalizedFailureReason"] as? String
            status = "error"
        }
        
        //Alert.generic(viewController: presentingVC, message: "", error: error as NSError)
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor!
    }
    
    public func createSignUp(userName: String, userId: Data, challenge: Data, relyingParty:String){
        
    }
    
    // https://developer.apple.com/documentation/authenticationservices/supporting-passkeys
    public func signUpWith(userName: String, userId: Data, challenge: Data, relyingParty:String, anchor: ASPresentationAnchor) {
        
        self.authenticationAnchor = anchor
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userId)
        
        // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    
    // https://forums.developer.apple.com/forums/thread/733946
    public func signInWith(anchor: ASPresentationAnchor, challenge: Data, allowedCredentials:[String] = [], relyingParty:String, preferImmediatelyAvailableCredentials: Bool) {
        self.authenticationAnchor = anchor
        
        
        let passkeyProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
        let passKeyRequest = passkeyProvider.createCredentialAssertionRequest(challenge: challenge)
        
        if allowedCredentials.count > 0 {
            for credId in allowedCredentials {
                if let data =  credId.decodeBase64Url {
                    let credentialID = ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
                    passKeyRequest.allowedCredentials.append(credentialID)
                }
            }
        }
        
        
        let authController = ASAuthorizationController(authorizationRequests: [passKeyRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        
        if preferImmediatelyAvailableCredentials {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, no UI appears and
            // the system passes ASAuthorizationError.Code.canceled to call
            // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
            authController.performRequests(options: .preferImmediatelyAvailableCredentials)
        } else {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
            // passkey from a nearby device.
            authController.performRequests()
        }
    }
    
    // https://developer.apple.com/videos/play/wwdc2022/10092/
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization){
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            
            
            guard let attestationObject = credentialRegistration.rawAttestationObject else { return }
            let clientDataJSON = credentialRegistration.rawClientDataJSON
            let credentialID = credentialRegistration.credentialID
            
            
            print("============================== ASAuthorizationPublicKeyCredentialRegistration ")
            print("Register-attestationObject：", attestationObject.base64URLEncode())
            print("Register-clientDataJSON：base64EncodedString ", clientDataJSON.base64EncodedString())
            print("Register-clientDataJSON：base64Decoded ", clientDataJSON.base64URLEncode().base64Decoded()!)
            print("Register-credentialID base64URLEncode：", credentialID.base64URLEncode())
            
            
            
            let registerAttest = AKAttestation(id: credentialID.base64URLEncode(),
                                               response: AKAttestReponse(attestationObject: attestationObject.base64URLEncode(), clientDataJSON: clientDataJSON.base64URLEncode()))
            
            self.attestation = registerAttest
            
            logger.log("============================== attestationObject base64Decoded \(attestationObject.base64URLEncode().base64Decoded() ?? "") ")
            
            let payload = ["id": credentialID.base64URLEncode(),
                           "response": [
                            "attestationObject": attestationObject.base64URLEncode(),
                            "clientDataJSON": clientDataJSON.base64URLEncode()
                           ]
            ] as [String: Any]
            
            
            
            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
                guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
                self.attestationResponse = payloadJSONText
                
            }
            
            
            
            
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            //print("A passkey was used to sign in: \(credentialAssertion)")
            
            guard let signature = credentialAssertion.signature else {
                logger.log("Missing signature")
                return
            }
            guard let authenticatorData = credentialAssertion.rawAuthenticatorData else {
                logger.log("Missing authenticatorData")
                return
            }
            guard let userID = credentialAssertion.userID else {
                logger.log("Missing userID")
                return
            }
            
            let clientDataJSON = credentialAssertion.rawClientDataJSON
            let credentialID = credentialAssertion.credentialID
            
            
            
            let payload = ["id": credentialID.base64URLEncode(), // Base64URL
                           "response": [
                            "clientDataJSON": clientDataJSON.base64URLEncode(),
                            "authenticatorData": authenticatorData.base64URLEncode(),
                            "signature": signature.base64URLEncode(),
                            "userHandle": userID.base64URLEncode()
                           ]
            ] as [String: Any]
            
            logger.log("============================== payload \(payload)")
            
            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
                guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
                
                self.assertion = AKAssertion(id: credentialID.base64URLEncode(),
                                             response: AKAssertResponse(authenticatorData: authenticatorData.base64URLEncode(),
                                                                        clientDataJSON: clientDataJSON.base64URLEncode(),
                                                                        signature:signature.base64URLEncode(),
                                                                        userHandle:userID.base64URLEncode()))
                
                
                
                self.assertionnResponse = payloadJSONText
                // login request
            }
            
        case let signInWithAppleCredential as ASAuthorizationAppleIDCredential:
            logger.log("============================== signInWithAppleCredential \(signInWithAppleCredential)")
            
        case let passwordCredential as ASPasswordCredential:
            logger.log("============================== passwordCredential \(passwordCredential)")
            
        default:
            fatalError("Received unknown authorization type.")
        }
    }
}

@available(macOS 13.0, *)
extension Data {
    func base64URLEncode() -> String {
        let base64URL = self.base64EncodedString().base64ToBase64url
        return base64URL
    }
}

@available(macOS 13.0, *)
extension String {
    
    var fromBase64 :String {
        let data = Data(base64Encoded: self)
        
        return String(data: data!, encoding: .utf8)!
    }
    
    var decodeBase64Url: Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return Data(base64Encoded: base64)
    }
    
    
    var base64ToBase64url: String {
        let base64url = self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
    
    var base64RulToBase64Standard: String {
        let base64Str = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        return base64Str
    }
    
    /// convert base64URL Encoded String to base64 Encoded String
    var base64URLEncodedToBase64: String {
        var encoded: String = Data(self.utf8).base64EncodedString()
        if encoded.count % 4 > 0 {
            encoded += String(repeating: "=", count: 4 - (encoded.count % 4))
        }
        return encoded
    }
    
    func base64Decoded() -> String? {
        var encoded = self
        if encoded.count % 4 > 0 {
            encoded += String(repeating: "=", count: 4 - (encoded.count % 4))
        }
        guard let data = Data(base64Encoded: encoded) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func toDictionary() -> [String : Any] {
        var result = [String : Any]()
        guard !self.isEmpty else { return result }
        
        guard let dataSelf = self.data(using: .utf8) else {
            return result
        }
        
        if let dic = try? JSONSerialization.jsonObject(with: dataSelf,
                                                       options: .mutableContainers) as? [String : Any] {
            result = dic
        }
        return result
        
    }
}

@available(macOS 13.0, *)
extension Encodable {
    
    func asDictionary() throws -> [String : Any] {
        let data = try JSONEncoder().encode(self)
        
        guard let dictionary = try JSONSerialization.jsonObject(with: data,
                                                                options: .fragmentsAllowed) as? [String: Any] else {
            throw NSError()
        }
        
        return dictionary
    }
}

@available(macOS 13.0, *)
public struct ClientJSONData:Codable {
    
    var type:String = "webauthn.create"
    var challenge:String
    var origin:String
    
}

@available(macOS 13.0, *)
public struct AuthenticationData:Codable {
    
    var type:String = "webauthn.create"
    var challenge:String
    var origin:String
    
}

