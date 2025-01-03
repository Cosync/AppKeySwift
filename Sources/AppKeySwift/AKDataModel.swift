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
    public var id:String = ""
    public var name:String = ""
    public var displayName:String = ""
    public var handle: String = ""
}

@available(macOS 13.0, *)
public struct AKLoginChallenge:Decodable {
    
    
    public var rpId: String
    public var challenge:String 
    public var timeout: Int
    public var userVerification: String
    public var requireAddPasskey:Bool?
}

@available(macOS 13.0, *)
public struct AKCredential: Decodable {
    public var id:String
    public var type:String
}

@available(macOS 13.0, *)
public struct AKRegister: Decodable {
    public var status:Bool
    public var message: String
    public var user: AKUser
}

@available(macOS 13.0, *)
public struct AKErrorReturn: Decodable {
    public var code:Bool
    public var message: String
}

@available(macOS 13.0, *)
public struct AKSignupChallenge: Decodable {
    public var challenge:String
    public var user: AKUser
}

@available(macOS 13.0, *)
public struct AKAttestReponse:Codable {
    public var attestationObject:String
    public var clientDataJSON:String
}

@available(macOS 13.0, *)
public struct AKAttestation:Codable {
    public var id:String
    public var rawId:String?
    public var authenticatorAttachment:String?
    public var type:String?
    public var response:AKAttestReponse
}

@available(macOS 13.0, *)
public struct AKAssertion:Codable {
    public var id:String
    public var rawId:String?
    public var authenticatorAttachment:String?
    public var type:String?
    public var response:AKAssertResponse
}

@available(macOS 13.0, *)
public struct AKAssertResponse:Codable {
    public var authenticatorData:String
    public var clientDataJSON:String
    public var signature:String
    public var userHandle:String
}

@available(macOS 13.0, *)
public struct AKAuthenticationInfo:Decodable {
    public let newCounter:Int
    public let credentialID:String
    public let userVerified:Bool
    public let credentialDeviceType:String
    public let credentialBackedUp:Bool
    public let origin:String
    public let rpID:String
}

@available(macOS 13.0, *)
public struct AKApplication:Codable {
    public let appId:String
    public let displayAppId:String
    public let name:String
    public let userId:String
    public let status:String
    public let handleType:String
    public let emailExtension:Bool
    public let appPublicKey:String
    public let appToken:String
    public let signup:String
    public let anonymousLoginEnabled:Bool
    public let userNamesEnabled:Bool
    public let googleLoginEnabled:Bool
    public let appleLoginEnabled:Bool
    public let googleClientId:String?
    public let appleBundleId:String?
    public let relyPartyId:String?
    public let userJWTExpiration:Int
    public let locales:[String]
    
}

@available(macOS 13.0, *)
public struct AKAppUser:Codable {
    public let appUserId:String
    public let displayName:String
    public let handle:String
    public let status:String
    public let appId:String
    public let loginProvider:String
    public let authenticators:[AKPasskey]
    public var accessToken:String?
    public var signUpToken:String?
    public var jwt:String?
    public let userName:String?
    public let locale:String?
    public let lastLogin: String?
    
}

@available(macOS 13.0, *)
public struct AKSignupData:Codable {
    
    public let handle:String
    public let message:String
    public var signUpToken:String?
}

@available(macOS 13.0, *)
public struct AKPasskey:Codable {
    public let id:String
    public let publicKey:String
    public let counter:Int
    public let deviceType:String
    public let credentialBackedUp:Bool
    public let name:String
    public let platform:String
    public let lastUsed: Date
    public let createdAt: Date
    public let updatedAt: Date
    
}

@available(macOS 13.0, *)
struct AKLoginComplete:Decodable {
    public let verified:Bool
    public let authenticationInfo:AKAuthenticationInfo
    
}

