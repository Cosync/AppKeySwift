//
//  AKDataModel.swift
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

@available(macOS 13.0, *)
public struct AKUser:Codable {
    var id:String = ""
    var name:String = ""
    var displayName:String = ""
    var handle: String = ""
}

@available(macOS 13.0, *)
public struct AKLoginChallenge:Decodable {
    
    
    var rpId: String
    var challenge:String
    var allowCredentials: [AKCredential]
    var timeout: Int
    var userVerification: String
    var requireAddPasskey:Bool?
}

@available(macOS 13.0, *)
public struct AKCredential: Decodable {
    var id:String
    var type:String
}

@available(macOS 13.0, *)
public struct AKRegister: Decodable {
    var status:Bool
    var message: String
    var user: AKUser
}

@available(macOS 13.0, *)
public struct AKErrorReturn: Decodable {
    var code:Bool
    var message: String
}

@available(macOS 13.0, *)
public struct AKSignupChallenge: Decodable {
    var challenge:String
    var user: AKUser
}

@available(macOS 13.0, *)
public struct AKAttestReponse:Codable {
    var attestationObject:String
    var clientDataJSON:String
}

@available(macOS 13.0, *)
public struct AKAttestation:Codable {
    var id:String
    var rawId:String?
    var authenticatorAttachment:String?
    var type:String?
    var response:AKAttestReponse
}

@available(macOS 13.0, *)
public struct AKAssertion:Codable {
    var id:String
    var rawId:String?
    var authenticatorAttachment:String?
    var type:String?
    var response:AKAssertResponse
}

@available(macOS 13.0, *)
public struct AKAssertResponse:Codable {
    var authenticatorData:String
    var clientDataJSON:String
    var signature:String
    var userHandle:String
}

@available(macOS 13.0, *)
public struct AKAuthenticationInfo:Decodable {
    let newCounter:Int
    let credentialID:String
    let userVerified:Bool
    let credentialDeviceType:String
    let credentialBackedUp:Bool
    let origin:String
    let rpID:String
}

@available(macOS 13.0, *)
public struct Application:Codable {
    let appId:String
    let displayAppId:String
    let name:String
    let userId:String
    let status:String
    let handleType:String
    let emailExtension:Bool
    let appPublicKey:String
    let appToken:String
    let signup:String
    let anonymousLoginEnabled:Bool
    let userNamesEnabled:Bool
    let userJWTExpiration:Int
    let locales:[String]
    
}

@available(macOS 13.0, *)
public struct AppUser:Codable {
    let appUserId:String
    let displayName:String
    let handle:String
    let status:String
    let appId:String
    var accessToken:String?
    var signUpToken:String?
    var jwt:String?
    let userName:String?
    let locale:String?
    let lastLogin: String?
}

@available(macOS 13.0, *)
public struct SignupData:Codable {
    
    let handle:String
    let message:String
    var signUpToken:String?
}

@available(macOS 13.0, *)
struct Passkey:Codable {
    let id:String
    let publicKey:String
    let counter:Int
    let deviceType:String
    let credentialBackedUp:String
    let name:String
    let platform:String
    let lastUsed: Date
    let createdAt: Date
    let updatedAt: Date
    
}

@available(macOS 13.0, *)
struct LoginComplete:Decodable {
    let verified:Bool
    let authenticationInfo:AKAuthenticationInfo
    
}

