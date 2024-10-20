//
//  AppKeyError.swift
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

public enum AppKeyError: Error {
    case appKeyConfiguration
    case invalidAppToken                // 400
    case appNoLongerExist               // 401
    case appSuspended                   // 402
    case missingParameter               // 403
    case accountSuspended               // 404
    case invalidAccessToken             // 405
    case appInviteNotSupported          // 406
    case appSignupNotSupported          // 407
    case appGoogle2FactorNotSupported   // 408
    case appPhone2FactorNotSupported    // 409
    case appUserPhoneNotVerified        // 410
    case expiredSignupCode              // 411
    case phoneNumberInUse               // 412
    case appIsMirgrated                 // 413
    case anonymousLoginNotSupported     // 414
    case appleLoginNotSupported         // 415
    case googleLoginNotSupported        // 416
    case internalServerError            // 500
    case invalidLoginCredentials        // 600
    case handleAlreadyRegistered        // 601
    case invalidData                    // 602
    case accountDoesNotExist            // 603
    case invalidMetaData                // 604
    case userNameAlreadyInUse           // 605
    case appIsNotSupporUserName         // 606
    case userNameDoesNotExist           // 607
    case accountIsNotVerify             // 608
    case invalidLocale                  // 609
    case emailAccountExists             // 610
    case appleAccountExists             // 611
    case googleAccountExists            // 612
    case invalidToken                   // 613
    case passkeyNotExist                // 614
    case invalidPasskey                 // 615
    case accountNoPasskey
    
    public var message: String {
        switch self {
        case .appKeyConfiguration:
            return "invalid api configuration"
        case .invalidAppToken:
            return "invalid app token"
        case .appNoLongerExist:
            return "app no longer exists"
        case .appSuspended:
            return "app is suspended"
        case .missingParameter:
            return "missing parameter"
        case .accountSuspended:
            return "user account is suspended"
        case .invalidAccessToken:
            return "invalid access token"
        case .appInviteNotSupported:
            return "app does not support invite"
        case .appSignupNotSupported:
            return "app does not support signup"
        case .appGoogle2FactorNotSupported:
            return "app does not support google two-factor verification"
        case .appPhone2FactorNotSupported:
            return "app does not support phone two-factor verification"
        case .appUserPhoneNotVerified:
            return "user does not have verified phone number"
        case .expiredSignupCode:
            return "expired signup code"
        case .phoneNumberInUse:
            return "phone number already in use"
        case .internalServerError:
            return "internal server error"
        case .invalidLoginCredentials:
            return "invalid login credentials"
        case .handleAlreadyRegistered:
            return "handle already registered"
        case .invalidData:
            return "invalid data"
        case .accountDoesNotExist:
            return "account does not exist"
        case .invalidMetaData:
            return "invalid metadata"
        case .anonymousLoginNotSupported:
            return "app does not support anonymous login"
        case .appIsMirgrated:
            return "app is migrated to other server"
        case .userNameAlreadyInUse:
            return "user name already assigned"
        case .appIsNotSupporUserName:
            return "app does not support username login"
        case .userNameDoesNotExist:
            return "user name deos not exist"
        case .accountIsNotVerify:
            return "account has not been verified"
        case .invalidLocale:
            return "invalid locale"
        case .appleLoginNotSupported:
            return "app does not support Apple Authentication"
        case .googleLoginNotSupported:
            return "app does not support Goole Authentication"
        case .emailAccountExists:
            return "email account already exist"
        case .appleAccountExists:
            return "apple account already exist"
        case .googleAccountExists:
            return "google account already exist"
        case .invalidToken:
            return "token in invalid"
        case .passkeyNotExist:
            return "passkey does not exist"
        case .invalidPasskey:
            return "invalid passkey"
        case .accountNoPasskey:
            return "user does not have passkey"
        }
    }
    
    static func checkResponse(data: Data, response: URLResponse) throws -> Void {
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return
            }
            else if httpResponse.statusCode == 400 {
                if let json = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] {
                    if let code = json["code"] as? Int {
                        switch code {

                        case 400:
                            throw AppKeyError.invalidAppToken
                        case 401:
                            throw AppKeyError.appNoLongerExist
                        case 402:
                            throw AppKeyError.appSuspended
                        case 403:
                            throw AppKeyError.missingParameter
                        case 404:
                            throw AppKeyError.accountSuspended
                        case 405:
                            throw AppKeyError.invalidAccessToken
                        case 406:
                            throw AppKeyError.appInviteNotSupported
                        case 407:
                            throw AppKeyError.appSignupNotSupported
                        case 408:
                            throw AppKeyError.appGoogle2FactorNotSupported
                        case 409:
                            throw AppKeyError.appPhone2FactorNotSupported
                        case 410:
                            throw AppKeyError.appUserPhoneNotVerified
                        case 411:
                            throw AppKeyError.expiredSignupCode
                        case 412:
                            throw AppKeyError.phoneNumberInUse
                        case 413:
                            throw AppKeyError.appIsMirgrated
                        case 414:
                            throw AppKeyError.anonymousLoginNotSupported
                        case 415:
                            throw AppKeyError.appleLoginNotSupported
                        case 416:
                            throw AppKeyError.googleLoginNotSupported
                        case 500:
                            throw AppKeyError.internalServerError
                        case 600:
                            throw AppKeyError.invalidLoginCredentials
                        case 601:
                            throw AppKeyError.handleAlreadyRegistered
                        case 602:
                            throw AppKeyError.invalidData
                        case 603:
                            throw AppKeyError.accountDoesNotExist
                        case 604:
                            throw AppKeyError.invalidMetaData
                        case 605:
                            throw AppKeyError.userNameAlreadyInUse
                        case 606:
                            throw AppKeyError.appIsNotSupporUserName
                        case 607:
                            throw AppKeyError.userNameDoesNotExist
                        case 608:
                            throw AppKeyError.accountIsNotVerify
                        case 609:
                            throw AppKeyError.invalidLocale
                        case 610:
                            throw AppKeyError.emailAccountExists
                        case 611:
                            throw AppKeyError.appleAccountExists
                        case 612:
                            throw AppKeyError.googleAccountExists
                        case 613:
                            throw AppKeyError.invalidToken
                        case 614:
                            throw AppKeyError.passkeyNotExist
                        case 615:
                            throw AppKeyError.invalidPasskey
                       

                        default:
                            throw AppKeyError.internalServerError
                        }
                    } else {
                        throw AppKeyError.internalServerError
                    }
                } else {
                    throw AppKeyError.internalServerError
                }

            } else if httpResponse.statusCode == 500 {
                throw AppKeyError.internalServerError
            }
        }
        throw AppKeyError.internalServerError
    }
}

