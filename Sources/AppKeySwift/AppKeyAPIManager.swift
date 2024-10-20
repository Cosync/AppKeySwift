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
import os

@available(macOS 13.0, *)
@MainActor public var AppKeyAPI = AppKeyAPIManager.shared

@available(macOS 13.0, *)
@MainActor public class AppKeyAPIManager:ObservableObject {
    
    static let shared = AppKeyAPIManager()
    
    // Configuration
    public var appToken: String?
    public var appKeyRestAddress: String?

    // Session state
    var appUser:AppUser? = nil
    var application:Application? = nil
    var accessToken:String = ""
    let logger = Logger()
    
    // Configure
    @MainActor public func configure(appToken: String, appKeyRestAddress: String = "") {
        
        appUser = nil
        application = nil
        accessToken = ""
        
        self.appToken = appToken
        if appKeyRestAddress == "" {
            self.appKeyRestAddress = "https://api.appkey.io"

        } else {
            self.appKeyRestAddress = appKeyRestAddress
        }
    }
    
    @MainActor public func getApp() async throws -> Application? {
        
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
            
            let app = try JSONDecoder().decode(Application.self, from: data)
            
            self.application = app
            // print(self.application)
            return app
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    
    @MainActor public func getAppUser(user:AppUser) async throws -> AppUser {
        
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
            
            let result = try JSONDecoder().decode(AppUser.self, from: data)
            
            // print("getAppUser app \(result)")
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
    
    @MainActor public func signup(handle:String, displayName:String, localse:String? = nil) async throws -> AKSignupChallenge? {
        
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
            
            print("register response \(result)")
            
            return result
            
            
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
            
            var user = try JSONDecoder().decode(AppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
            }
            
            
            self.accessToken = user.accessToken!
            self.appUser = user
            
            return true
            
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            throw error
        }
        
    }
    
    @MainActor public func signupConfirm(handle:String, attest:AKAttestation) async throws -> SignupData {
        
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
            
            var signData = try JSONDecoder().decode(SignupData.self, from: data)
            
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
            print("login error \(error.message)")
            throw error
        }
        catch {
            print("login error \(error.localizedDescription)")
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
            
            
            var user = try JSONDecoder().decode(AppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
            }
            
            
            self.appUser = user
            
            if let accessToken = user.accessToken {
                self.accessToken = accessToken
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
            
            logger.info("login json \(json)")
            
            if json["requireAddPasskey"] is Bool {
                throw AppKeyError.accountNoPasskey
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
    
    
    @MainActor public func loginComplete(handle:String, assertion:AKAssertion) async throws -> AppUser? {
        
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
            
            // print("loginComplete jsonString \(data.base64URLEncode().base64Decoded() ?? "" )")
            
            var user = try JSONDecoder().decode(AppUser.self, from: data)
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                user.accessToken = json["access-token"] as? String
            }
            
            
            self.appUser = user
            self.accessToken = user.accessToken!
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
            print("verify error \(error.message)")
            throw error
        }
        catch {
            print("verify error \(error.localizedDescription)")
            throw error
        }
    }
    
    
    
    
    @MainActor public func verifyComplete(handle:String, assertion:AKAssertion) async throws -> Bool {
        
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
            
            print("verifyComplete return data \(data.base64URLEncode().base64Decoded()!)")
            
            guard let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
                throw AppKeyError.internalServerError
            }
            
            logger.info("verifyComplete json = \(json)")
            
            if let valid = json["valid"] as? Bool {
                return valid
            }
            else {
                return false
            }
        }
        catch let error as AppKeyError {
            throw error
        }
        catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    
}

