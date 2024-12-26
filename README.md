# AppKeySwift

The AppKeySwift package is used to add functional bindings between a Swift iOS application and the AppKey service. To install this package into a Swift iOS application do the following

---

# Installation in XCode

1. In Xcode, select **File > Swift Packages > Add Package** Dependency.

2. Copy and paste the following into the search/input box, then click Next.

```
    https://github.com/Cosync/AppKeySwift.git
```

3. Leave the default value of **Up to Next Major**, then click **Next**.

4. Select the Package Product; **AppKeySwift**, then click **Finish**

# AppKeyAPIManager class

The **AppKeyAPIManager** class provides a Swift API to the REST API to the AppKey service. This class is modeled on a *singleton* architecture, where is access is called through the **shared** static variable of the class. 

All Swift API functions to the AppKey service are **async** functions that execute and block on the main thread. 

These async functions do not return data to the calling function, rather they set instance variable data on the **AppKeyAPIManager.shared** object. All errors are handled by throwing **AppKeyError** exceptions from within the **async** functions. The calling code must handle these exceptions by placing the Swift function calls within a *do/catch* statement. 

The **AppKeyError** class includes the following enumerations:

- appKeyConfiguration
- invalidAppToken
- appNoLongerExist
- appSuspended
- missingParameter
- accountSuspended
- invalidAccessToken
- appInviteNotSupported
- appSignupNotSupported
- appGoogle2FactorNotSupported
- appPhone2FactorNotSupported
- appUserPhoneNotVerified
- expiredSignupCode
- phoneNumberInUse
- appIsMirgrated
- anonymousLoginNotSupported
- appleLoginNotSupported
- googleLoginNotSupported
- internalServerError
- invalidLoginCredentials
- handleAlreadyRegistered
- invalidData
- accountDoesNotExist
- invalidMetaData
- userNameAlreadyInUse
- appIsNotSupporUserName
- userNameDoesNotExist
- accountIsNotVerify
- invalidLocale
- emailAccountExists
- appleAccountExists
- googleAccountExists
- invalidToken
- passkeyNotExist
- invalidPasskey
- accountNoPasskey

# Function API

The AppKeySwift provides a number of Swift functions 

---

## configure

The *configure()* function call is used to the AppKeySwift to operate with a REST API that implements the AppKey service protocol. This function should be called once at the time the application starts up.

```
    public func configureconfigure(appToken: String, appKeyRestAddress: String = "", rawPublicKey: String = "")
```

### Parameters

**appToken** : String - this contains the application token for AppKey (usually retrieved from the Keys section of the AppKey Portal. 

**appKeyRestAddress** : String - this optional parameter contains the HTTPS REST API address for the AppKey service. The default is 'https://sandbox.cosync.net' if not specified.

**rawPublicKey** : String - this optional parameter contains the raw Publc Key for the Cosync Application. The default is '' if not specified. This is used by the function **isValidJWT**.

For self-hosted versions of the AppKey server, the **appKeyRestAddress** is the HTTPS REST API address of the AppKey server.

This function does not throw any exceptions.

### Example

```
    AppKeyAPIManager.shared.configure(appToken: Constants.APP_TOKEN,
                          appKeyRestAddress: Constants.API_URL_ADDRESS,
                               rawPublicKey: Constants.RAW_PUBLIC_KEY)
```

---

## isValidJWT

The *isValidJWT()* function is used to validate a jwt token after a call to the *loginComplete()* function. This function will only work if the **rawPublicKey** has been set as part of the configuration function.

This function can verify that the jwt token returned by the *loginComplete()* function is valid and comes from the right provider. 

```
    public func isValidJWT() -> Bool
```

This function will return `true` if the **jwt** token is valid and signed correctly, `false` otherwise.


### Parameters

**none**

## getApp

The *getApp()* function is used by the client application to get information about the application within AppKey. The *getApp()* function will save user information inside member variables of the **AppKeyAPIManager.shared** object. These member variables include the following information:

* **application** : AKApplication - application object

The AKApplication object contains the following fields

* **appId** : String - unique 128 bit application id
* **displayAppId** : String - unique display application id
* **name** : String - name of application
* **userId** : String - AppKey user id who owns application
* **status** : String - 'active', 'inactive', 'migrated'
* **handleType** : String - 'email', 'phone'
* **emailExtension** : Bool - email extensions supported
* **appPublicKey** : String - app raw public key
* **appToken** : String - app token
* **signup** : String - app signup 'open' or 'invite'
* **anonymousLoginEnabled** : Bool - anonymous login enabled
* **userNamesEnabled** : Bool - user names enabled
* **userJWTExpiration** : Int - JWT token expirations in hours
* **locales** : [String] - list of locales support by application

```
    public func getApp() async throws -> Void
```

### Parameters

None

### Example

```
    do {
        try await AppKeyAPIManager.shared.getApp()
    } catch let error as AppKeyError {
        NSLog(@"getApp error '%@'", error.message)
    }
```

## getAppUser

The *getAppUser()* function is used by the client application to get information about the currently logged in user to AppKey. The *getAppUser()* function will save user information inside member variables of the **AppKeyAPIManager.shared** object. These member variables include the following information:

* **appUser** : AKAppUser - application user object

The AKAppUser object contains the following fields

* **appUserId** : String - unique 128 bit user id
* **displayName** : String - user display name
* **handle** : String - user handle (email or phone)
* **status** : String - user status 'pending', 'active', 'suspended'
* **appId** : String - unique 128 bit application id
* **accessToken** : String? - JWT REST access token for logged in user
* **signUpToken** : String? - JWT REST sign up token
* **jwt** : String? - JWT login token
* **userName** : String? - unique user name (alphanumeric)
* **locale** : String? - current user locale
* **lastLogin** :  String? - date stamp of last login

```
    public func geApptUser() async throws -> Void
```

### Parameters

None

### Example

```
    do {
        try await AppKeyAPIManager.shared.getAppUser()
    } catch let error as AppKeyError {
        NSLog(@"getAppUser error '%@'", error.message)
    }
```


## signup

The *signup()* function is used to signup a user with a AppKey application. The signup process is spread accross three functions, which have to be called within the right order:

* **signup**
* **signupConfirm**
* **signupComplete**

The *signup()* function is responsible for registering a new user handle (email or phone) with the application. This handle must be unique to the user and not already assigned to another account. The client must also provide a display name (first and last) and can optionally include a locale (default is ‘EN’ if unspecified). The *signup()* function returns an *AKSignupChallenge* object, which contains a challenge to be signed by the private key generated on the client side. 

```
    public func signup(
        handle: String, 
        displayName: String, 
        locale: String? = nil) async throws -> AKSignupChallenge
```

If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**handle** : String - this contains the user's handle (email or phone). 

**displayName** : String - this contains the user's display name.

**locale** : String - 2 letter **locale** for the user


### Example

```
    do {
        try await AppKeyAPIManager.shared.signup(handle: self.email, 
                            displayName: self.displayName)
    } catch let error as AppKeyError {
        NSLog(@"signup error '%@'", error.message)
    }
```

## signupConfirm

The *signupConfirm()* function is the second step in registering a user with an AppKey application. It’s called after the user’s biometric data has been validated on the client device and the passkey has been stored in the keychain. Since biometric verification ensures user authenticity, there’s no need for CAPTCHAs to distinguish between a human and a bot. This process prevents automated bot signups on the AppKey server. The attestation object passed to this function is generated by the *AKPasskeysManager*, and the function returns an *AKSignupData* object.

```
    public func signupConfirm(
        handle: String, 
        attest: AKAttestation) async throws -> AKSignupData
```

If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**handle** : String - this contains the user's handle (email or phone). 

**attest** : AKAttestation - this contains the user's attestation object


### Example

```
    do {
        let signupData = try await AppKeyAPIManager.shared.signupConfirm(handle: self.email, 
                                    attest: self.attestation)
    } catch let error as AppKeyError {
        NSLog(@"signupConfirm error '%@'", error.message)
    }
```

## signupComplete

The *signupComplete()* function is the final step in registering a user with an AppKey application, called after *signupConfirm()*. It takes the six-digit code sent to the user’s handle (email or phone) to verify ownership. AppKey uses two-factor verification: first, the user’s biometric data, and second, the code sent to their handle. If the verification is successful, the function returns true - ensuring the user both owns the handle and passes biometric checks.


The passed in *signupToken* is retrieved from the *AKSignupData* object returned by the called to the *signupConfirm()* function. 

```
    public func signupComplete(
        signupToken: String, 
        code: String) async throws -> Bool
```

If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**signupToken** : String - this contains the user's signup token

**code** : String - six-digit code sent to user's handle


### Example

```
    do {
        let success = try await AppKeyAPIManager.shared.signupComplete(signupToken: self.signupToken, 
                                    code: self.code)
    } catch let error as AppKeyError {
        NSLog(@"signupComplete error '%@'", error.message)
    }
```

## login

The *login()* function is used to login into a user's account. The login process is spread accross two functions, which have to be called within the right order:

* **login**
* **loginComplete**

The *login()* function initiates the passkey login process for a user handle (email or phone) that has already been registered with the application. The handle must correspond to a user that’s signed up and stored on the server. This function returns an *AKLoginChallenge* object, which includes a challenge that the client must sign using the private key stored in the device’s keychain. This step ensures the user’s identity is verified securely.

```
    public func login(
        handle: String
        ) async throws -> AKLoginChallenge
```

If an error occurs in the call to the function, an AppKeyError exceptions will be thrown.


### Parameters

**handle** : String - this contains the user's user name or email. 

### Example

```
    do {
        try await AppKeyAPIManager.shared.login(handle: email)
    } catch let error as AppKeyError {
        NSLog(@"login error '%@'", error.message)
    }
```

## loginComplete

The *loginComplete()* function is the second step in registering a user with an AppKey application, called after *login()*. It takes the the user’s handle (email or phone) and an AKAssertion object to verify the login. 

If the *loginComplete()* is successful it will return to the caller, the login credentials will be saved in member variable of the **AppKeyAPIManager** shared object:

* **appUser** : AKAppUser - application user object
* **accessToken** : String? - JWT REST access token for logged in user
* **jwt** : String? - JWT login token

The AKAppUser object contains the following fields

* **appUserId** : String - unique 128 bit user id
* **displayName** : String - user display name
* **handle** : String - user handle (email or phone)
* **status** : String - user status 'pending', 'active', 'suspended'
* **appId** : String - unique 128 bit application id
* **accessToken** : String? - JWT REST access token for logged in user
* **signUpToken** : String? - JWT REST sign up token
* **jwt** : String? - JWT login token
* **userName** : String? - unique user name (alphanumeric)
* **locale** : String? - current user locale
* **lastLogin** :  String? - date stamp of last login

```
    public func loginComplete(
        handle: String,
        assertion: AKAssertion
        ) async throws -> Void
```
If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**handle** : String - this contains the user's handle (email or phone). 
**assertion** : AKAssertion - this contains the AKAssertion object

### Example

```
    do {
        let appUser = try await AppKeyAPIManager.shared.loginComplete(self.handle, self.assertion)
    } catch let error as AppKeyError {
        NSLog(@"loginComplete error '%@'", error.message)
    }
```

## loginAnonymous

The *loginAnonymous()* function is used to login anonymously into the AppKey system. The anonymous login process is spread accross two functions, which have to be called within the right order:

* **loginAnonymous**
* **loginAnonymousComplete**

This function will only work if the anonymous login capability is enable with the AppKey portal for the applicaiton. 

The *loginAnonymous()* function initiates the anonymous passkey login process with the application. The function is passed a uuidString string, which is used to create the anonymous handle. That way, if the client wishes to reuse an anonymous handle, it can do so by reusing the same uuidString paramter. This function returns an *AKSignupChallenge* object, which includes a challenge that the client must sign using the private key stored in the device’s keychain. This step ensures the user’s anonymous identity is verified securely.

```
    public func loginAnonymous(
        uuidString: String
        ) async throws -> AKSignupChallenge
```

If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.


### Parameters

**handle** : String - this contains a unique string for the anonymous user (e.g. \<prefix\>_UUID)

### Example

```
    let uuid = UUID().uuidString
    do {
        try await AppKeyAPIManager.shared.loginAnonymous(uuid)
    } catch let error as AppKeyError {
        NSLog(@"loginAnonymous error '%@'", error.message)
    }
```

## loginAnonymousComplete

The *loginAnonymousComplete()* function is the second step in registering an anonymous user with an AppKey application, called after *loginAnonymous()*. 


If the *loginComplete()* is successful it will return to the caller, the login credentials will be saved in member variable of the **AppKeyAPIManager** shared object:

* **appUser** : AKAppUser - application user object
* **accessToken** : String? - JWT REST access token for logged in user
* **jwt** : String? - JWT login token

The AKAppUser object contains the following fields

* **appUserId** : String - unique 128 bit user id
* **displayName** : String - user display name
* **handle** : String - user handle (email or phone)
* **status** : String - user status 'pending', 'active', 'suspended'
* **appId** : String - unique 128 bit application id
* **accessToken** : String? - JWT REST access token for logged in user
* **signUpToken** : String? - JWT REST sign up token
* **jwt** : String? - JWT login token
* **userName** : String? - unique user name (alphanumeric)
* **locale** : String? - current user locale
* **lastLogin** :  String? - date stamp of last login

```
    public func loginAnonymousComplete(
        handle: String,
        assertion: AKAssertion
        ) async throws -> Void
```
If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**handle** : String - this contains the user's handle (email or phone). 
**assertion** : AKAssertion - this contains the AKAssertion object

### Example

```
    do {
        try await AppKeyAPIManager.shared.loginAnonymousComplete(self.handle, self.assertion)
    } catch let error as AppKeyError {
        NSLog(@"loginAnonymousComplete error '%@'", error.message)
    }
```

## verify

The *verify()* function is used to verify a user's account using a saved passkey. The verify function is a lightweight version of the *login()* function. The verify process is spread accross two functions, which have to be called within the right order:

* **verify**
* **verifyComplete**

The *verify()* function initiates the passkey verification process for a user handle (email or phone) that has already been registered with the application. The handle must correspond to a user that’s signed up and stored on the server. This function returns an *AKLoginChallenge* object, which includes a challenge that the client must sign using the private key stored in the device’s keychain. This step ensures the user’s identity is verified securely.

```
    public func verify(
        handle: String
        ) async throws -> AKLoginChallenge
```

If an error occurs in the call to the function, an AppKeyError exceptions will be thrown.


### Parameters

**handle** : String - this contains the user's user name or email. 

### Example

```
    do {
        try await AppKeyAPIManager.shared.verify(handle: email)
    } catch let error as AppKeyError {
        NSLog(@"verify error '%@'", error.message)
    }
```

## verifyComplete

The *verifyComplete()* function is the second step in registering a user with an AppKey application, called after *verify()*. It takes the the user’s handle (email or phone) and an AKAssertion object to verify the login. 

If the *verifyComplete()* is successful it will return to the caller with a boolean value, true if verified false otherwise.

```
    public func verifyComplete(
        handle: String,
        assertion: AKAssertion
        ) async throws -> Bool
```
If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**handle** : String - this contains the user's handle (email or phone). 
**assertion** : AKAssertion - this contains the AKAssertion object

### Example

```
    do {
        let appUser = try await AppKeyAPIManager.shared.verifyComplete(self.handle, self.assertion)
    } catch let error as AppKeyError {
        NSLog(@"verifyComplete error '%@'", error.message)
    }
```

## logout

The *logout()* function is used by the client application to log out of the AppKey server. This function does not actually call the server, rather it erases all the local data associated with the JWT login token. This function should be called when the user logs out.

```
    public func logout() -> Void
```

### Parameters

none

### Example

```
    AppKeyAPIManager.shared.logout()
```

## setUserLocale

The *setUserLocale()* function is used by the client application to set the user's **locale**. The locale is a two letter code that identifies the user's locale - by default the locale is 'EN' for English. The AppKey authentication system supports the ISO 631–1 codes that are described [ISO 639–1 codes](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes). Note: a client can only set the locale for a user if that locale is supported by the application in the Cosync Portal.

```
    public func setUserLocale(
        locale: String) async throws -> Void
```

### Parameters

**locale** : String - contains the user's locale (always uppercase)

### Example

```
    do {
        try await AppKeyAPIManager.shared.setUserLocale(locale: locale)
    } catch let error as AppKeyError {
        NSLog(@"setUserLocale error '%@'", error.message)
    }
```

## setUserName

The *setUserName()* function is used by the client application to set the user name associated with a user account. User names must be unique names that allow the application to identify a user by something other than the email or phone handle. Typically, a user name is selected the first time a user logs in, or after he/she signs up for the first time. This function will only work if user names are enabled with AppKey for the application in the portal.

User names must consist of alphanumeric characters - starting with a letter. They are not case sensitive

```
    public func setUserName(
        _ userName: String) async throws -> Void
```
If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**userName** : String - user name to be associated with logged in user

### Example

```
    do {
        try await AppKeyAPIManager.shared.setUserName(userName: "joesmith")
    } catch let error as AppKeyError {
        NSLog(@"setUserName error '%@'", error.message)
    }
```

## userNameAvailable

The *userNameAvailable()* function is used by the client application whether a user name is available and unique for the application. User names must be unique names that allow the application to identify a user by something other than the email or phone handle. 

User names must consist of alphanumeric characters - starting with a letter. They are not case sensitive

```
    public func userNameAvailable(
        userName: String) async throws -> Bool
```
This fuction returns **true** if user name is available, **false** otherwise. 

If an error occurs in the call to the function, a AppKeyError exceptions will be thrown.

### Parameters

**userName** : String - user name to be associated with logged in user

### Example

```
    do {
        let isAvailable = try await AppKeyAPIManager.shared.userNameAvailable(userName: "joesmith")
        if isAvailable {
            ...
        }
    } catch let error as AppKeyError {
        NSLog(@"userName error '%@'", error.message)
    }
```

## deleteAccount

The *deleteAccount()* function is used by the client application to delete the account of the currently logged in user to AppKey. The user must either be logged in using a passkey, or using a social account. 

```
    public func deleteAccount() async throws -> Void
```

### Parameters

None

### Example

```
    do {
        try await AppKeyAPIManager.shared.deleteAccount()
    } catch let error as AppKeyError {
        NSLog(@"deleteAccount error '%@'", error.message)
    }
```

## socialLogin

The *socialLogin()* function allows a client application to authenticate with AppKey using a social account, either Apple or Google. The user can log in via a passkey or a social account. Social login is supported because major providers are adopting passkeys as their authentication strategy. Additionally, it simplifies access by letting users delegate authentication to a social provider rather than creating a separate account.

This function is included for completeness. Best practice is to first call *socialLogin()*; if the login fails because the account does not exist, fall back to *socialSignup()* to create the account.

```
    public func socialLogin(_ token: String, provider: String) async throws -> Void
```

### Parameters

**token** : String - apple identity token or google auth token
**provider** : String - name of provider either 'apple' or 'google'

### Example

```
    do {
         let user = try await AppKeyAPIManager.socialLogin(token, provider: provider)
    } catch let error as AppKeyError {
        NSLog(@"socialLogin error '%@'", error.message)
    }
```

## socialSignup

The *socialSignup()* function allows a client application to authenticate and create an account with AppKey using a social account, either Apple or Google. The user can log in via a passkey or a social account. Social signup is supported because major providers are adopting passkeys as their authentication strategy. Additionally, it simplifies access by letting users delegate authentication to a social provider rather than creating a separate account.

```
    public func socialSignup(_ token: String, email:String, provider:String, displayName: String, locale: String? = nil) async throws -> Void
```

### Parameters

**token** : String - apple identity token or google auth token
**email** : String - email returned by social provider
**displayName**: String - it is givenName concatenated to familyName
**provider** : String - name of provider either 'apple' or 'google'
**locale** : String - default 'EN'

### Example

```
    do {
         let _ = try await AppKeyAPIManager.socialSignup(token, email:email, provider: self.provider, displayName: displayName)
    } catch let error as AppKeyError {
        NSLog(@"socialSignup error '%@'", error.message)
    }
```


## verifySocialAccount

The *verifySocialAccount()* function ensures the identity of a logged-in social account. It acts as a safeguard before calling the *deleteAccount()* function, which removes the user’s social account from AppKey.

```
    public func verifySocialAccount(_ token: String, provider: String) async throws -> AKAppUser
```

### Parameters

**token** : String - apple identity token or google auth token
**provider** : String - name of provider either 'apple' or 'google'

### Example

```
    do {
         let verifyComplete = try await AppKeyAPIManager.verifySocialAccount(token, provider: provider)
    } catch let error as AppKeyError {
        NSLog(@"verifySocialAccount error '%@'", error.message)
    }
```