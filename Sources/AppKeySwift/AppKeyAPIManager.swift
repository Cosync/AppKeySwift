//
//  AppKeyAPIManager.swift
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
import CryptoKit
 

@available(macOS 10.14, *)
extension String {

    func md5() -> String {
        guard let d = self.data(using: .utf8) else { return ""}
        let digest = Insecure.MD5.hash(data: d)
        let h = digest.reduce("") { (res: String, element) in
            let hex = String(format: "%02x", element)
            //print(ch, hex)
            let  t = res + hex
            return t
        }
        return h
    }
    
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    
    func deletingSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
    
    func base64StringWithPadding() -> String {
        var stringTobeEncoded = self.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingCount = self.count % 4
        for _ in 0..<paddingCount {
            stringTobeEncoded += "="
        }
        return stringTobeEncoded
    }
}


@available(macOS 13.0, *)
@MainActor public var AppKeyAPI = AppKeyAPIManager.shared

@available(macOS 13.0, *)
@MainActor public class AppKeyAPIManager:ObservableObject {
    
    public static let shared = AppKeyAPIManager()
    
    // Configuration
    public var appToken: String?
    public var appKeyRestAddress: String?
    public var rawPublicKey: String?

    // Session state
    public var appUser:AKAppUser? = nil
    public var application:AKApplication? = nil
    public var accessToken:String = ""
    public var jwt: String?
   
    
    // Configure
    @MainActor public func configure(appToken: String, appKeyRestAddress: String = "", rawPublicKey: String = "") {
        
        logout()
        
        self.appToken = appToken
        if appKeyRestAddress == "" {
            self.appKeyRestAddress = "https://api.appkey.io"

        } else {
            self.appKeyRestAddress = appKeyRestAddress
        }
        self.rawPublicKey = rawPublicKey
    }
    
    // isValidJWT - check whether self.jwt is valid and signed correctly
    // code inspired from Muhammed Tanriverdi see link
    // https://mtanriverdi.medium.com/how-to-decode-jwt-and-validate-the-signature-in-swift-97092bd654f7
    //
    @MainActor public func isValidJWT() -> Bool {
        
        if let jwt = self.jwt,
           let rawPublicKey = self.rawPublicKey,
           !rawPublicKey.isEmpty {
            
            let parts = jwt.components(separatedBy: ".")
            
            if parts.count == 3 {
                
                let header = parts[0]
                let payload = parts[1]
                let signature = parts[2]
                
                if let decodedData = Data(base64Encoded: rawPublicKey) {
                    
                    if var publicKeyText = String(data: decodedData, encoding: .utf8) {
                        publicKeyText = publicKeyText.deletingPrefix("-----BEGIN PUBLIC KEY-----")
                        publicKeyText = publicKeyText.deletingSuffix("-----END PUBLIC KEY-----")
                        publicKeyText = String(publicKeyText.filter { !" \n\t\r".contains($0) })
                        
                        if let dataPublicKey = Data(base64Encoded: publicKeyText) {
                            
                            let publicKey: SecKey? = SecKeyCreateWithData(dataPublicKey as NSData, [
                                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                kSecAttrKeyClass: kSecAttrKeyClassPublic
                            ] as NSDictionary, nil)
                            
                            if let publicKey = publicKey {
                                let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
                                
                                let dataSigned = (header + "." + payload).data(using: .ascii)!
                                
                                let dataSignature = Data.init(
                                    base64Encoded: signature.base64StringWithPadding()
                                )!

                                return SecKeyVerifySignature(publicKey,
                                                                   algorithm,
                                                                   dataSigned as NSData,
                                                                   dataSignature as NSData,
                                                                   nil)
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    @MainActor public func getApp() async throws -> AKApplication? {
        
        do {
            guard let appToken = self.appToken else {
                throw AppKeyError.appKeyConfiguration
            }
            
            guard let appKeyRestAddress = self.appKeyRestAddress else {
                throw AppKeyError.appKeyConfiguration
            }

            guard let url = URL(string: "\(appKeyRestAddress)/api/appuser/app") else {
                throw AppKeyError.invalidData
            }
            
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = ["app-token": appToken]
            
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)
            try AppKeyError.checkResponse(data: data, response: response)
            
            let app = try JSONDecoder().decode(AKApplication.self, from: data)
            
            self.application = app

            return app
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    
    @MainActor public func getAppUser(user:AKAppUser) async throws -> AKAppUser {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/user"
        
        do {
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            
            
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            urlRequest.httpMethod = "GET"
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            
            self.appUser = result
            
            return result
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    @MainActor public func signup(handle:String, displayName:String, locale:String? = nil) async throws -> AKSignupChallenge? {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/signup"
        
        do {
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "displayName", value: displayName),
                                                URLQueryItem(name: "handle", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            let result = try JSONDecoder().decode(AKSignupChallenge.self, from: data)
            
            //print("register response \(result)")
            
            return result
            
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    @MainActor public func signupConfirm(handle:String, attest:AKAttestation) async throws -> AKSignupData {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/signupConfirm"
        do {
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            let attetstRsponse = "{\"attestationObject\": \"\(attest.response.attestationObject)\", \"clientDataJSON\": \"\(attest.response.clientDataJSON)\"}"
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: moddedHandle),
                                                URLQueryItem(name: "id", value: attest.id),
                                                URLQueryItem(name: "response", value: attetstRsponse )
            ]
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            var signData = try JSONDecoder().decode(AKSignupData.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                signData.signUpToken = json["signup-token"] as? String
            }
            
            
            return signData
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    @MainActor public func signupComplete(signupToken:String, code:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/signupComplete"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "code", value: code)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["signup-token": signupToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            print("signupComplete jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            
            return true
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    @MainActor public func login(handle:String) async throws -> AKLoginChallenge? {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/login"
        
        do {
            // your post request data
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
                        
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            guard let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
                
                throw AppKeyError.internalServerError
            }
            
            print("login json \(json)")
            
            if json["requireAddPasskey"] is Bool {
                throw AppKeyError.passkeyNotExist
            }
            
            let result = try JSONDecoder().decode(AKLoginChallenge.self, from: data)
            return result
            
            
        }
        catch let error as AppKeyError {
            print("login error \(error.message)")
            throw error
        }
        catch {
            print("login error \(error.localizedDescription)")
            throw error
        }
    }
    
    
    @MainActor public func loginComplete(handle:String, assertion:AKAssertion) async throws -> AKAppUser? {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/loginComplete"
        do {
            
            
            let assertRsponse = "{\"authenticatorData\": \"\(assertion.response.authenticatorData)\", \"clientDataJSON\": \"\(assertion.response.clientDataJSON)\", \"signature\": \"\(assertion.response.signature)\", \"userHandle\": \"\(assertion.response.userHandle)\"}"
            
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: moddedHandle),
                                                URLQueryItem(name: "id", value: assertion.id),
                                                URLQueryItem(name: "response", value: assertRsponse )
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
                        
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            print("loginComplete jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            return user
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    
    @MainActor public func loginAnonymous(uuidString: String) async throws -> AKSignupChallenge? {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/loginAnonymous"
        
        do {
            
            let handle = "ANON_\(uuidString)"
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: handle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            // print("loginAnonymous return data \(data.base64URLEncode().base64Decoded()!)")
            
            let result = try JSONDecoder().decode(AKSignupChallenge.self, from: data)
            
            // print("login server response \(result)")
            
            return result
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
    }
    
    
    @MainActor public func loginAnonymousComplete(handle:String, attest:AKAttestation) async throws -> Bool {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/loginAnonymousComplete"
        do {
            
            let attetstRsponse = "{\"attestationObject\": \"\(attest.response.attestationObject)\", \"clientDataJSON\": \"\(attest.response.clientDataJSON)\"}"
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: handle),
                                                URLQueryItem(name: "id", value: attest.id),
                                                URLQueryItem(name: "response", value: attetstRsponse )
            ]
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            // print("loginAnonymousComplete data \(data.base64URLEncode().base64Decoded()!)")
            
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            
            return true
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    @MainActor public func verify(handle:String) async throws -> AKLoginChallenge? {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/verify"
        
        do {
            // your post request data
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: moddedHandle)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token":appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            
            // print("verify return data \(data.base64URLEncode().base64Decoded()!)")
            
            let result = try JSONDecoder().decode(AKLoginChallenge.self, from: data)
            
            return result
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
    }
    
    @MainActor public func verifyComplete(handle:String, assertion:AKAssertion) async throws -> AKAppUser {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/verifyComplete"
        do {
            
            
            let assertRsponse = "{\"authenticatorData\": \"\(assertion.response.authenticatorData)\", \"clientDataJSON\": \"\(assertion.response.clientDataJSON)\", \"signature\": \"\(assertion.response.signature)\", \"userHandle\": \"\(assertion.response.userHandle)\"}"
            
            let moddedHandle = handle.replacingOccurrences(of: "+", with: "%2B")
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "handle", value: moddedHandle),
                                                URLQueryItem(name: "id", value: assertion.id),
                                                URLQueryItem(name: "response", value: assertRsponse )
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            //print("verifyComplete return data \(data.base64URLEncode().base64Decoded()!)")
            
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            return user
            
             
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
           
            throw error
        }
    }
    
    @MainActor public func logout() { 
        
        self.appUser = nil
        self.application = nil
        self.accessToken = ""
        self.jwt = nil
    }
    
    @MainActor public func setUserLocale(locale:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/setLocale"
        do {
            
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                URLQueryItem(name: "locale", value: locale)
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            
            // print("locale jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            return true
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    @MainActor public func setUserName(userName:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/setUsername"
        do {
            
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                URLQueryItem(name: "userName", value: userName)
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            
            // print("setUsername jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            return true
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    @MainActor public func userNameAvailable(userName:String) async throws -> Bool {
        
        do {
            
            guard let appKeyRestAddress = self.appKeyRestAddress else {
                throw AppKeyError.appKeyConfiguration
            }

            guard let url = URL(string: "\(appKeyRestAddress)/api/appuser/userNameAvailable?userName=\(userName)") else {
                throw AppKeyError.invalidData
            }
            
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = ["access-token": accessToken]
            
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)
            try AppKeyError.checkResponse(data: data, response: response)
            
            guard let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
                throw AppKeyError.internalServerError
            }
            
            if let available = json["available"] as? Bool {
                return available
            }
            else {
                return false
            }
            
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    // user must do login ceremony process to get new access token before call this deleteAccount
    @MainActor public func deleteAccount() async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/deleteAccount"
        do {
             
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            // print("locale jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            return true
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    
    
    
    // Singup into AppKey with Apple or Google
    @MainActor public func socialSignup(_ token: String, email:String, provider:String, displayName: String, locale: String? = nil) async throws -> AKAppUser {
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        if provider == "google"{
            guard self.application!.googleLoginEnabled == true else {
                throw AppKeyError.googleLoginNotSupported
            }
        }
        else if provider == "apple" {
            guard self.application!.appleLoginEnabled == true else {
                throw AppKeyError.appleLoginNotSupported
            }
        }
        
        let config = URLSessionConfiguration.default

        let session = URLSession(configuration: config)
            
        let url = URL(string: "\(appKeyRestAddress)/api/appuser/socialSignup")!
    
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = ["app-token": appToken]

        var requestBodyComponents = URLComponents()
        
        requestBodyComponents.queryItems = [URLQueryItem(name: "token", value: token),
                                        URLQueryItem(name: "provider", value: provider),
                                        URLQueryItem(name: "displayName", value: displayName),
                                        URLQueryItem(name: "handle", value: email)]
        
        if let locale = locale {
            requestBodyComponents.queryItems?.append(URLQueryItem(name: "locale", value: locale))
        }
       
        
        urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
        
        do {
            
            let (data, response) = try await session.data(for: urlRequest)
            
             
            
            // ensure there is no error for this HTTP response
            try AppKeyError.checkResponse(data: data, response: response)
            
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            
            return user
             
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }

    }
    
     
    
    // Social Login into AppKey
    @MainActor public func socialLogin(_ token: String, provider: String) async throws -> AKAppUser {
        
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }
         
        //let _ = try await self.getApp()
        
        if provider == "google"{
            guard self.application!.googleLoginEnabled == true else {
                throw AppKeyError.googleLoginNotSupported
            }
        }
        else if provider == "apple" {
            guard self.application!.appleLoginEnabled == true else {
                throw AppKeyError.appleLoginNotSupported
            }
        }
       
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "token", value: token),
                                                URLQueryItem(name: "provider", value: provider)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            
            let url = URL(string: "\(appKeyRestAddress)/api/appuser/socialLogin")!
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            return user
         
        }
        catch let error as AppKeyError {
             throw error
        }
        catch {
            throw error
        }


    }
    
    
    
    // Verify Social Account for ownership
    @MainActor public func verifySocialAccount(_ token: String, provider: String) async throws -> AKAppUser {
        
        
        guard let appToken = self.appToken else {
            throw AppKeyError.appKeyConfiguration
        }
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }
         
        //let _ = try await self.getApp()
        
        if provider == "google"{
            guard self.application!.googleLoginEnabled == true else {
                throw AppKeyError.googleLoginNotSupported
            }
        }
        else if provider == "apple" {
            guard self.application!.appleLoginEnabled == true else {
                throw AppKeyError.appleLoginNotSupported
            }
        }
       
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [URLQueryItem(name: "token", value: token),
                                                URLQueryItem(name: "provider", value: provider)]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            
            let url = URL(string: "\(appKeyRestAddress)/api/appuser/verifySocialAccount")!
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.allHTTPHeaderFields = ["app-token": appToken]
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            var user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
                user.jwt = json["jwt"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
            }
            if let jwt = user.jwt {
                self.jwt = jwt
            }
            return user
         
        }
        catch let error as AppKeyError {
             throw error
        }
        catch {
            throw error
        }


    }
    
    
    
    
    @MainActor public func updateProfile(displayName:String) async throws -> Bool {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/updateProfile"
        do {
            
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                URLQueryItem(name: "displayName", value: displayName)
            ]
            
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            return true
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
    }
    
    @MainActor public func addPasskey() async throws -> AKSignupChallenge {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/addPasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            // print("verify return data \(data.base64URLEncode().base64Decoded()!)")
            
            let result = try JSONDecoder().decode(AKSignupChallenge.self, from: data)
            
            return result
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    @MainActor public func addPasskeyComplete(attest:AKAttestation) async throws -> AKAppUser {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/addPasskeyComplete"
        
        do {
            
            let attetstRsponse = "{\"attestationObject\": \"\(attest.response.attestationObject)\", \"clientDataJSON\": \"\(attest.response.clientDataJSON)\"}"
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "id", value: attest.id),
                                                URLQueryItem(name: "response", value: attetstRsponse )
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            //print("addPasskeyComplete return data \(data.base64URLEncode().base64Decoded()!)")
            
            let user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            self.appUser = user
            
            return user
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    
    @MainActor public func updatePasskey(keyId:String, keyName:String) async throws -> AKAppUser? {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/updatePasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "keyId", value: keyId),
                                                URLQueryItem(name: "keyName", value: keyName)
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            //print("removePasskey return data \(data.base64URLEncode().base64Decoded()!)")
            
            let user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            self.appUser = user
            
            return user
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
    @MainActor public func removePasskey(keyId:String) async throws -> AKAppUser? {
        
        guard let appKeyRestAddress = self.appKeyRestAddress else {
            throw AppKeyError.appKeyConfiguration
        }

        let url = "\(appKeyRestAddress)/api/appuser/removePasskey"
        
        do {
            
            var requestBodyComponents = URLComponents()
            requestBodyComponents.queryItems = [
                                                URLQueryItem(name: "keyId", value: keyId)
            ]
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let url = URL(string: url)!
             
            
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = ["access-token": self.accessToken]
            
            urlRequest.httpBody = requestBodyComponents.query?.data(using: .utf8)
            
            
            let (data, response) = try await session.data(for: urlRequest)
            try AppKeyError.checkResponse(data: data, response: response)
            
            //print("removePasskey return data \(data.base64URLEncode().base64Decoded()!)")
            
            let user = try JSONDecoder().decode(AKAppUser.self, from: data)
            
            self.appUser = user
            
            return user
            
        }
        catch let error as AppKeyError {
           
            throw error
        }
        catch {
            
            throw error
        }
        
    }
    
}

