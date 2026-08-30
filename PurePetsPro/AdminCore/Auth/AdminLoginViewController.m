//
//  AdminLoginViewController.m
//  Pure Pets Pro
//
//  Hosts the modern SwiftUI login surface while preserving the existing
//  Firebase auth and Pro-access gating pipeline.
//

#import "AdminLoginViewController.h"
#import "PPFirebaseCompat.h"
#import "PurePetsPro-Swift.h"
#import "PPProviderApplicationStatusViewController.h"
#import "AdminDashboardViewController.h"
#import "PPDeliveryCompanyService.h"
#import "SceneDelegate.h"
#import <CommonCrypto/CommonCrypto.h>
@import GoogleSignIn;

extern BOOL PPAdminLoginInProgress(void);
extern void PPAdminSetLoginInProgress(BOOL);
extern NSString * const LanguageDidChangeNotification;
extern NSString * const UserManagerAuthStateDidChangeNotification;

static NSString * const kPPFIRAuthDeserializedResponseKey = @"FIRAuthErrorUserInfoDeserializedResponseKey";
static NSString * const kPPDefaultsVerificationIDKey = @"pro_authVerificationID";
static NSUInteger const kPPMinPhoneDigits = 8;
static NSInteger const kPPAppleRetryMax = 1;
static NSTimeInterval const kPPSMSCooldownSeconds = 30.0;

static BOOL PPProLoginBoolValue(id value) {
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return NO;
}

static BOOL PPProLoginUserDocIsBlocked(NSDictionary *root) {
    if (![root isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSString *accountType = [PPSafeString(root[@"accountType"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *staffProfile = [root[@"staffProfile"] isKindOfClass:NSDictionary.class] ? (NSDictionary *)root[@"staffProfile"] : nil;
    
    NSString *accountStatus = [PPSafeString(root[@"accountStatus"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSString *effectiveStatus = accountStatus;
    if (staffProfile && [accountType isEqualToString:@"staff"]) {
        effectiveStatus = [PPSafeString(staffProfile[@"status"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    return PPProLoginBoolValue(root[@"isBlocked"]) ||
           PPProLoginBoolValue(root[@"blocked"]) ||
           PPProLoginBoolValue(root[@"isDeleted"]) ||
           [effectiveStatus isEqualToString:@"blocked"] ||
           [effectiveStatus isEqualToString:@"disabled"];
}

@interface PPNoPermissionBottomSheetViewController : UIViewController
@end

@implementation PPNoPermissionBottomSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurface];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor ppElevatedSurface];
    }
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    iconView.tintColor = [UIColor ppWarning];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"StatusAccessDenied");
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    UILabel *msgLabel = [[UILabel alloc] init];
    msgLabel.text = kLang(@"StatusNoPartnerAccess");
    msgLabel.font = [UIFont systemFontOfSize:16];
    msgLabel.textColor = [UIColor ppTextSecondary];
    msgLabel.textAlignment = NSTextAlignmentCenter;
    msgLabel.numberOfLines = 0;
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, titleLabel, msgLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconView.heightAnchor constraintEqualToConstant:60],
        [iconView.widthAnchor constraintEqualToConstant:60],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32]
    ]];
}

@end

@interface AdminLoginViewController () <PPProLoginSurfaceControllerDelegate>

@property (nonatomic, strong) PPProLoginSurfaceController *surfaceController;
@property (nonatomic, copy, nullable) NSString *verificationID;
@property (nonatomic, copy, nullable) NSString *currentNonce;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *phoneText;
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, assign) NSInteger appleRetryCount;
@property (nonatomic, assign) NSInteger noPermissionAttempts;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> combinedReg;
@property (nonatomic, strong, nullable) NSDate *lastSMSSentDate;
@property (nonatomic, copy, nullable) NSString *lastVerifiedFullPhone;

@end

@implementation AdminLoginViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _countryCode = @"+974";
        _phoneText = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    self.view.backgroundColor = [self pp_loginBaseBackgroundColor];
    [self pp_buildHostedSurface];
    [self pp_registerObservers];
    [self pp_refreshSurfaceState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.combinedReg remove];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection]) {
            self.view.backgroundColor = [self pp_loginBaseBackgroundColor];
            [self setNeedsStatusBarAppearanceUpdate];
        }
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (@available(iOS 13.0, *)) {
        BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        return isDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
    }
    return UIStatusBarStyleLightContent;
}

#pragma mark - Base Styling

- (UIColor *)pp_loginBaseBackgroundColor {
    return [UIColor ppSurface];
}

#pragma mark - UI Hosting

- (void)pp_buildHostedSurface {
    self.surfaceController = [[PPProLoginSurfaceController alloc] init];
    self.surfaceController.delegate = self;
    self.surfaceController.phoneText = self.phoneText ?: @"";
    self.surfaceController.countryCode = self.countryCode ?: @"+974";
    self.surfaceController.showsAppleButton = YES;

    [self addChildViewController:self.surfaceController];
    self.surfaceController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.surfaceController.view];

    NSLayoutConstraint *bottom = [self.surfaceController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    bottom.priority = UILayoutPriorityRequired - 1;

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.surfaceController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.surfaceController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        bottom,
    ]];
    [self.surfaceController didMoveToParentViewController:self];
}

- (void)pp_registerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageDidChange)
                                                 name:LanguageDidChangeNotification
                                               object:nil];
}

- (void)pp_handleLanguageDidChange {
    [self pp_refreshSurfaceState];
}

- (void)pp_refreshSurfaceState {
    if (!self.surfaceController) {
        return;
    }

    self.surfaceController.phoneText = self.phoneText ?: @"";
    self.surfaceController.countryCode = self.countryCode ?: @"+974";
    self.surfaceController.isBusy = self.isAuthenticating;
    if (@available(iOS 13.0, *)) {
        self.surfaceController.showsAppleButton = YES;
    } else {
        self.surfaceController.showsAppleButton = NO;
    }
    [self.surfaceController refreshLocalizationContext];
    [self pp_updatePhoneContinueStateAnimated:NO];
}

#pragma mark - Surface Delegate

- (void)proLoginSurface:(PPProLoginSurfaceController *)controller didChangePhoneText:(NSString *)text {
    (void)controller;
    self.phoneText = text ?: @"";
    [self pp_updatePhoneContinueStateAnimated:YES];
}

- (void)proLoginSurfaceDidRequestCountryCode:(PPProLoginSurfaceController *)controller {
    (void)controller;
    [self pp_pickCountryCode];
}

- (void)proLoginSurfaceDidTapPhoneContinue:(PPProLoginSurfaceController *)controller {
    if (controller.countryCode.length > 0) {
        self.countryCode = controller.countryCode;
    }
    [self pp_handlePhoneSignIn];
}

- (void)proLoginSurfaceDidTapApple:(PPProLoginSurfaceController *)controller {
    (void)controller;
    [self pp_handleAppleSignIn];
}

- (void)proLoginSurfaceDidTapGoogle:(PPProLoginSurfaceController *)controller {
    (void)controller;
    [self pp_handleGoogleSignIn];
}

- (void)proLoginSurfaceDidTapSupport:(PPProLoginSurfaceController *)controller {
    (void)controller;
    [self pp_onRequestSupport];
}

- (void)proLoginSurfaceDidTapLanguage:(PPProLoginSurfaceController *)controller {
    (void)controller;
    [self pp_onLanguageChange];
}

- (void)proLoginSurfaceDidTapProviderApplication:(PPProLoginSurfaceController *)controller {
    [controller focusLoginFormCard];
}

#pragma mark - Input State

- (NSString *)pp_numericPhoneDigits {
    NSString *source = self.phoneText ?: @"";
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [[source componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
}

- (void)pp_updatePhoneContinueStateAnimated:(BOOL)animated {
    (void)animated;
    BOOL hasValidPhone = [self pp_numericPhoneDigits].length >= kPPMinPhoneDigits;
    self.surfaceController.isPhoneContinueEnabled = hasValidPhone && !self.isAuthenticating;
}

#pragma mark - Country Code / Support / Language

- (void)pp_pickCountryCode {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"ProLoginCountryCode")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.countryCode;
        textField.keyboardType = UIKeyboardTypePhonePad;
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK_Title")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSString *value = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!value.length) {
            return;
        }

        if (![value hasPrefix:@"+"]) {
            value = [NSString stringWithFormat:@"+%@", value];
        }

        self.countryCode = value;
        [self pp_refreshSurfaceState];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_onLanguageChange {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Confirm_LanguageChange_Title")
                                                                   message:kLang(@"Confirm_LanguageChange_Msg")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK_Title")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        Language.languageVal == 0
            ? [Language userSelectedLanguage:LanguageCode[1]]
            : [Language userSelectedLanguage:LanguageCode[0]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_onRequestSupport {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"ProLoginSupportTitle")
                                                                   message:kLang(@"ProLoginSupportMessage")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK_Title")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Phone Auth

- (void)pp_handlePhoneSignIn {
    if (self.isAuthenticating) {
        return;
    }

    NSString *digits = [self pp_numericPhoneDigits];
    if (digits.length < kPPMinPhoneDigits) {
        [PPAlertHelper showWarningIn:self title:kLang(@"Warning") subtitle:kLang(@"ProLoginPhoneRequired")];
        return;
    }

    // Rate-limit: enforce cooldown between SMS sends
    if (self.lastSMSSentDate) {
        NSTimeInterval elapsed = -[self.lastSMSSentDate timeIntervalSinceNow];
        if (elapsed < kPPSMSCooldownSeconds) {
            NSInteger remaining = (NSInteger)ceil(kPPSMSCooldownSeconds - elapsed);
            NSString *msg = [NSString stringWithFormat:@"%@ %lds", kLang(@"ProLoginSMSCooldown"), (long)remaining];
            [PPAlertHelper showWarningIn:self title:kLang(@"Warning") subtitle:msg];
            return;
        }
    }

    NSString *code = self.countryCode ?: @"+974";
    if (![code hasPrefix:@"+"]) {
        code = [NSString stringWithFormat:@"+%@", code];
    }
    NSString *full = [NSString stringWithFormat:@"%@%@", code, digits];
    self.lastVerifiedFullPhone = full;

    [self.view endEditing:YES];
    [self pp_sendVerificationCodeToPhone:full isResend:NO];
}

- (void)pp_sendVerificationCodeToPhone:(NSString *)fullPhone isResend:(BOOL)isResend {
    self.isAuthenticating = YES;
    [self pp_setInteractionEnabled:NO];
    NSString *hudTitle = isResend ? kLang(@"ProLoginResendingCode") : kLang(@"ProLoginSendingCode");
    [PPHUD showIndeterminateIn:self.view title:hudTitle subtitle:nil];
    PPAdminSetLoginInProgress(YES);

    __weak typeof(self) weakSelf = self;
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:fullPhone
                                            UIDelegate:nil
                                            completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            self.isAuthenticating = NO;
            [self pp_setInteractionEnabled:YES];

            if (error) {
                PPAdminSetLoginInProgress(NO);
                NSString *friendlyMessage = [self pp_friendlyPhoneErrorMessage:error];
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:friendlyMessage];
                return;
            }

            if (verificationID.length == 0) {
                PPAdminSetLoginInProgress(NO);
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginCodeSendFailed")];
                return;
            }

            self.verificationID = verificationID;
            self.lastSMSSentDate = [NSDate date];
            [[NSUserDefaults standardUserDefaults] setObject:verificationID forKey:kPPDefaultsVerificationIDKey];

            if (!isResend) {
                [self pp_promptForVerificationCode:fullPhone];
            }
        });
    }];
}

- (NSString *)pp_friendlyPhoneErrorMessage:(NSError *)error {
    if (!error) {
        return kLang(@"ProLoginCodeSendFailed");
    }

    NSInteger code = error.code;
    // FIRAuthErrorCode values
    if (code == 17010) { // tooManyRequests
        return kLang(@"ProLoginTooManyRequests");
    }
    if (code == 17042) { // invalidPhoneNumber
        return kLang(@"ProLoginInvalidPhone");
    }
    if (code == 17062) { // captchaCheckFailed
        return kLang(@"ProLoginCaptchaFailed");
    }
    if (code == 17999) { // internalError — often App Check
        if ([self pp_errorLooksLikeAppCheckFailure:error]) {
            return kLang(@"StatusAppCheckInvalid");
        }
    }
    return error.localizedDescription ?: kLang(@"ProLoginCodeSendFailed");
}

- (void)pp_promptForVerificationCode:(NSString *)phone {
    NSString *message = [NSString stringWithFormat:@"%@ %@", kLang(@"ProLoginCodeSentTo"), phone];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"ProLoginEnterCode")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"-  -  -  -  -  -";
        textField.textContentType = UITextContentTypeOneTimeCode;
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ProLoginVerify")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSString *code = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (code.length < 4) {
            [PPAlertHelper showWarningIn:self title:kLang(@"Warning") subtitle:kLang(@"ProLoginCodeTooShort")];
            return;
        }

        [self pp_signInWithPhoneVerificationCode:code];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ProLoginResendCode")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        // Check cooldown before resending
        if (self.lastSMSSentDate) {
            NSTimeInterval elapsed = -[self.lastSMSSentDate timeIntervalSinceNow];
            if (elapsed < kPPSMSCooldownSeconds) {
                NSInteger remaining = (NSInteger)ceil(kPPSMSCooldownSeconds - elapsed);
                NSString *msg = [NSString stringWithFormat:@"%@ %lds", kLang(@"ProLoginSMSCooldown"), (long)remaining];
                [PPAlertHelper showWarningIn:self title:kLang(@"Warning") subtitle:msg];
                // Re-show the verification prompt
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self pp_promptForVerificationCode:phone];
                });
                return;
            }
        }

        [self pp_sendVerificationCodeToPhone:phone isResend:YES];
        // Re-show the verification prompt after resend completes
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (self && !self.isAuthenticating) {
                [self pp_promptForVerificationCode:phone];
            }
        });
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:^(__unused UIAlertAction *action) {
        PPAdminSetLoginInProgress(NO);
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_signInWithPhoneVerificationCode:(NSString *)code {
    NSString *verificationID = self.verificationID ?: [[NSUserDefaults standardUserDefaults] stringForKey:kPPDefaultsVerificationIDKey];
    if (!verificationID.length) {
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginCodeExpired")];
        PPAdminSetLoginInProgress(NO);
        return;
    }

    FIRAuthCredential *credential = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                                                  verificationCode:code];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProLoginVerifyingCode") subtitle:nil];
    [self pp_signInWithCredential:credential displayName:nil];
}

#pragma mark - Apple Sign-In

- (void)pp_handleAppleSignIn {
    if (self.isAuthenticating) {
        return;
    }

    self.appleRetryCount = 0;
    [self pp_startAppleSignIn];
}

- (void)pp_startAppleSignIn {
    if (@available(iOS 13.0, *)) {
        self.isAuthenticating = YES;
        [self pp_setInteractionEnabled:NO];

        NSString *nonce = [self pp_randomNonce:32];
        self.currentNonce = nonce;

        ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
        ASAuthorizationAppleIDRequest *request = [provider createRequest];
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
        request.nonce = [self pp_sha256Nonce:nonce];

        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        [controller performRequests];
    } else {
        [PPAlertHelper showWarningIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginAppleRequires13")];
    }
}

- (nullable NSString *)pp_displayNameFromAppleFullName:(NSPersonNameComponents * _Nullable)fullName API_AVAILABLE(ios(13.0)) {
    if (!fullName) {
        return nil;
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *given = [fullName.givenName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *family = [fullName.familyName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (given.length > 0) {
        [parts addObject:given];
    }
    if (family.length > 0) {
        [parts addObject:family];
    }
    NSString *combined = [parts componentsJoinedByString:@" "];
    return combined.length > 0 ? combined : nil;
}

- (void)authorizationController:(ASAuthorizationController *)controller
   didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
    if (![authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        self.isAuthenticating = NO;
        [self pp_setInteractionEnabled:YES];
        return;
    }

    ASAuthorizationAppleIDCredential *appleCredential = (ASAuthorizationAppleIDCredential *)authorization.credential;
    NSData *tokenData = appleCredential.identityToken;

    // Retry on missing token (Apple sometimes returns nil on first attempt)
    if (tokenData.length == 0) {
        [self pp_retryAppleSignInOrFail];
        return;
    }

    NSString *identityToken = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
    if (!identityToken.length || self.currentNonce.length == 0) {
        [self pp_retryAppleSignInOrFail];
        return;
    }

    // Extract display name — Apple only provides this on the FIRST sign-in
    NSString *displayName = [self pp_displayNameFromAppleFullName:appleCredential.fullName];

    FIRAuthCredential *credential = [FIROAuthProvider appleCredentialWithIDToken:identityToken
                                                                        rawNonce:self.currentNonce
                                                                        fullName:appleCredential.fullName];

    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProLoginAppleSigningIn") subtitle:nil];
    PPAdminSetLoginInProgress(YES);
    [self pp_signInWithCredential:credential displayName:displayName];
}

- (void)pp_retryAppleSignInOrFail {
    if (self.appleRetryCount < kPPAppleRetryMax) {
        self.appleRetryCount += 1;
        self.isAuthenticating = NO;
        [self pp_setInteractionEnabled:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self pp_startAppleSignIn];
        });
    } else {
        self.isAuthenticating = NO;
        [self pp_setInteractionEnabled:YES];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginAppleTokenMissing")];
    }
}

- (void)authorizationController:(ASAuthorizationController *)controller
          didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isAuthenticating = NO;
        [self pp_setInteractionEnabled:YES];
        [PPHUD dismiss];

        if (error.code == ASAuthorizationErrorCanceled) {
            return;
        }

        // Specific Apple error handling
        NSString *subtitle;
        if (error.code == ASAuthorizationErrorFailed) {
            subtitle = kLang(@"ProLoginAppleAuthFailed");
        } else if (error.code == ASAuthorizationErrorNotHandled) {
            subtitle = kLang(@"ProLoginAppleNotHandled");
        } else {
            subtitle = error.localizedDescription ?: kLang(@"ProLoginAppleFailed");
        }
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:subtitle];
    });
}

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller API_AVAILABLE(ios(13.0)) {
    return self.view.window;
}

#pragma mark - Google Sign-In

- (void)pp_handleGoogleSignIn {
    if (self.isAuthenticating) {
        return;
    }

    NSString *clientID = [self pp_googleClientID];
    if (clientID.length == 0 || ![self pp_hasGoogleURLSchemeForClientID:clientID]) {
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginGoogleConfigMissing")];
        return;
    }

    self.isAuthenticating = YES;
    [self pp_setInteractionEnabled:NO];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProLoginGoogleConnecting") subtitle:nil];
    PPAdminSetLoginInProgress(YES);

    // GIDSignIn.sharedInstance.configuration removed to preserve App Check

    __weak typeof(self) weakSelf = self;
    [GIDSignIn.sharedInstance signInWithPresentingViewController:self
                                                            hint:nil
                                                      completion:^(GIDSignInResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            if (error) {
                [PPHUD dismiss];
                self.isAuthenticating = NO;
                [self pp_setInteractionEnabled:YES];
                PPAdminSetLoginInProgress(NO);
                if (error.code != kGIDSignInErrorCodeCanceled) {
                    [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription];
                }
                return;
            }

            NSString *identityToken = result.user.idToken.tokenString;
            NSString *accessToken = result.user.accessToken.tokenString;
            if (!identityToken || !accessToken) {
                [PPHUD dismiss];
                self.isAuthenticating = NO;
                [self pp_setInteractionEnabled:YES];
                PPAdminSetLoginInProgress(NO);
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProLoginGoogleTokenMissing")];
                return;
            }

            FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:identityToken accessToken:accessToken];
            [self pp_signInWithCredential:credential displayName:result.user.profile.name];
        });
    }];
}

- (NSString *)pp_googleClientID {
    NSString *clientID = [FIRApp defaultApp].options.clientID;
    if (clientID.length > 0) {
        return [clientID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }

    NSString *infoClientID = NSBundle.mainBundle.infoDictionary[@"GIDClientID"];
    if ([infoClientID isKindOfClass:NSString.class]) {
        return [infoClientID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return @"";
}

- (BOOL)pp_hasGoogleURLSchemeForClientID:(NSString *)clientID {
    NSString *trimmedClientID = [clientID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *suffix = @".apps.googleusercontent.com";
    if (![trimmedClientID hasSuffix:suffix] || trimmedClientID.length <= suffix.length) {
        return NO;
    }

    NSString *clientPrefix = [trimmedClientID substringToIndex:trimmedClientID.length - suffix.length];
    NSString *requiredScheme = [NSString stringWithFormat:@"com.googleusercontent.apps.%@", clientPrefix];
    NSArray *urlTypes = [NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"] isKindOfClass:NSArray.class]
        ? NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"]
        : @[];
    for (NSDictionary *urlType in urlTypes) {
        NSArray *schemes = [urlType[@"CFBundleURLSchemes"] isKindOfClass:NSArray.class] ? urlType[@"CFBundleURLSchemes"] : @[];
        for (NSString *scheme in schemes) {
            if ([scheme isKindOfClass:NSString.class] && [scheme isEqualToString:requiredScheme]) {
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark - Shared Credential Sign-In

- (void)pp_signInWithCredential:(FIRAuthCredential *)credential displayName:(NSString *_Nullable)name {
    __weak typeof(self) weakSelf = self;
    [[FIRAuth auth] signInWithCredential:credential
                              completion:^(FIRAuthDataResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            self.isAuthenticating = NO;
            [self pp_setInteractionEnabled:YES];

            FIRUser *user = result.user ?: [FIRAuth auth].currentUser;
            if (error || !user) {
                PPAdminSetLoginInProgress(NO);
                NSString *subtitle = [self pp_friendlyFirebaseAuthErrorMessage:error];
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:subtitle];
                return;
            }

            // Update Firebase Auth display name if provided and not already set
            NSString *trimmedName = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmedName.length > 0 && (user.displayName.length == 0 || [user.displayName hasPrefix:@"user"])) {
                FIRUserProfileChangeRequest *changeRequest = [user profileChangeRequest];
                changeRequest.displayName = trimmedName;
                [changeRequest commitChangesWithCompletion:^(NSError * _Nullable profileError) {
                    if (profileError) {
                        DLog(@"[Auth] Failed to update displayName: %@", profileError.localizedDescription);
                    }
                }];
            }

            NSDictionary *extra = nil;
            if (trimmedName.length > 0) {
                extra = @{@"UserName": trimmedName};
            }

            [[FUManager shared] ensureUserDocumentExistsForCurrentUserWithExtra:extra
                                                                     completion:^(NSError *documentError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) {
                        return;
                    }
                    if (documentError) {
                        DLog(@"[Auth] ensureUserDocument error: %@", documentError.localizedDescription);
                    }
                    [self pp_gatekeepServiceProviderForUID:user.uid];
                });
            }];
        });
    }];
}

- (NSString *)pp_friendlyFirebaseAuthErrorMessage:(NSError *)error {
    if (!error) {
        return kLang(@"StatusLoginFailed");
    }

    NSInteger code = error.code;
    // Common FIRAuthErrorCode values
    if (code == 17005) { // userDisabled
        return kLang(@"ProLoginAccountDisabled");
    }
    if (code == 17009) { // wrongPassword
        return kLang(@"ProLoginWrongCredentials");
    }
    if (code == 17010) { // tooManyRequests
        return kLang(@"ProLoginTooManyRequests");
    }
    if (code == 17020) { // networkError
        return kLang(@"ProLoginNetworkError");
    }
    if (code == 17999) { // internalError
        if ([self pp_errorLooksLikeAppCheckFailure:error]) {
            return kLang(@"StatusAppCheckInvalid");
        }
    }
    if (code == 17044) { // invalidVerificationCode
        return kLang(@"ProLoginInvalidCode");
    }
    if (code == 17051) { // sessionExpired
        return kLang(@"ProLoginCodeExpired");
    }
    return error.localizedDescription ?: kLang(@"StatusLoginFailed");
}

#pragma mark - Service Provider Gate

- (void)pp_continueToProviderOnboarding {
    PPAdminSetLoginInProgress(NO);
    PPProviderApplicationStatusViewController *statusController = [[PPProviderApplicationStatusViewController alloc] init];
    statusController.prefersAutoPresentBecomeProvider = NO;
    [self.navigationController setViewControllers:@[statusController] animated:YES];
}

- (void)pp_preflightDeliveryCompanyMembershipForUID:(NSString *)uid {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:kLang(@"StatusLoggingIn")];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles,
                                                                                NSError * _Nullable error) {
        [PPHUD dismiss];
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![activeUID isEqualToString:uid]) {
            PPAdminSetLoginInProgress(NO);
            return;
        }

        PPDeliveryCompanyProfile *profile = profiles.firstObject;
        if (profile.companyID.length > 0) {
            DLog(@"[ProGate] delivery company membership granted uid=%@ company=%@ role=%@",
                 uid, profile.companyID, profile.role);
            [PPDeliveryCompanyService.shared storeVerifiedProfile:profile];
            PPAdminSetLoginInProgress(NO);

            SceneDelegate *sceneDelegate = (SceneDelegate *)self.view.window.windowScene.delegate;
            if ([sceneDelegate isKindOfClass:SceneDelegate.class]) {
                [sceneDelegate showDashboardWithDeliveryCompanyProfile:profile animated:YES];
            } else {
                AdminDashboardViewController *dashboard =
                    [[AdminDashboardViewController alloc] initWithDeliveryCompanyProfile:profile];
                [self.navigationController setViewControllers:@[dashboard] animated:YES];
            }
            return;
        }

        if (error) {
            DLog(@"[ProGate] delivery company membership preflight failed; continuing onboarding: %@",
                 error.localizedDescription);
        }
        [self pp_continueToProviderOnboarding];
    }];
}

- (void)pp_gatekeepServiceProviderForUID:(NSString *)uid {
    if (!uid.length) {
        [PPHUD dismiss];
        PPAdminSetLoginInProgress(NO);
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"StatusUserDocError")];
        [UserManager.shared signOut];
        return;
    }

    [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:kLang(@"StatusLoggingIn")];

    __weak typeof(self) weakSelf = self;
    [AppMgr checkIfUserWithUID:uid canAccessPro:^(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (error) {
                DLog(@"[ProGate] fetch error: %@", error.localizedDescription);
                if ([self pp_errorLooksLikeAppCheckFailure:error]) {
                    PPAdminSetLoginInProgress(NO);
                    [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"StatusAppCheckInvalid")];
                    return;
                }

                PPAdminSetLoginInProgress(NO);
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"StatusUserDocError")];
                [UserManager.shared signOut];
                return;
            }

            if (!allowed) {
                DLog(@"[ProGate] user authenticated but not yet approved for provider access uid=%@", uid);

                if (PPProLoginUserDocIsBlocked(userDoc ?: @{})) {
                    [UserManager.shared signOut];
                    PPAdminSetLoginInProgress(NO);
                    self.noPermissionAttempts++;
                    if (self.noPermissionAttempts == 1) {
                        [PPAlertHelper showErrorIn:self title:kLang(@"StatusAccessDenied") subtitle:kLang(@"StatusNoPartnerAccess")];
                    } else {
                        PPNoPermissionBottomSheetViewController *sheet = [[PPNoPermissionBottomSheetViewController alloc] init];
                        if (@available(iOS 15.0, *)) {
                            if (sheet.sheetPresentationController) {
                                sheet.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
                                sheet.sheetPresentationController.prefersGrabberVisible = YES;
                            }
                        }
                        [self presentViewController:sheet animated:YES completion:nil];
                    }
                    return;
                }

                [self pp_preflightDeliveryCompanyMembershipForUID:uid];
                return;
            }

            DLog(@"[ProGate] service provider access granted uid=%@", uid);
            [self pp_finishLoginAndStartUserStream];
        });
    }];
}

#pragma mark - Finish Login

- (void)pp_finishLoginAndStartUserStream {
    if (self.combinedReg) {
        [self.combinedReg remove];
        self.combinedReg = nil;
    }

    __weak typeof(self) weakSelf = self;
    self.combinedReg = [[FUManager shared] listenCombinedUser:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            if (error || !user) {
                PPAdminSetLoginInProgress(NO);
                [PPHUD dismiss];
                [self.combinedReg remove];
                self.combinedReg = nil;
                [PPAlertHelper showErrorIn:self title:kLang(@"Error")
                                subtitle:error.localizedDescription ?: kLang(@"StatusUserDocError")];
                if (![self pp_errorLooksLikeAppCheckFailure:error]) {
                    [UserManager.shared signOut];
                }
                return;
            }

            [UsrMgr p_writeUserToDisk:user forUID:user.uid];
            [PPHUD dismiss];
            PPAdminSetLoginInProgress(NO);
            [[NSNotificationCenter defaultCenter] postNotificationName:UserManagerAuthStateDidChangeNotification object:nil];
        });
    }];
}

#pragma mark - Interaction Helpers

- (void)pp_setInteractionEnabled:(BOOL)enabled {
    self.surfaceController.isBusy = !enabled;
    [self pp_updatePhoneContinueStateAnimated:YES];
}

#pragma mark - Apple Nonce Helpers

- (NSString *)pp_randomNonce:(NSUInteger)length {
    NSString *characters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._";
    NSMutableString *string = [NSMutableString stringWithCapacity:length];
    uint8_t buffer[length];
    SecRandomCopyBytes(kSecRandomDefault, length, buffer);
    for (NSUInteger i = 0; i < length; i++) {
        [string appendFormat:@"%C", [characters characterAtIndex:buffer[i] % characters.length]];
    }
    return string;
}

- (NSString *)pp_sha256Nonce:(NSString *)input {
    const char *utf8 = [input UTF8String];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(utf8, (CC_LONG)strlen(utf8), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

#pragma mark - Error Helpers

- (BOOL)pp_errorLooksLikeAppCheckFailure:(NSError *_Nullable)error {
    if (![error isKindOfClass:NSError.class]) {
        return NO;
    }

    NSArray<NSString *> *messages = @[
        error.localizedDescription ?: @"",
        [self pp_authBackendMessageFromError:error] ?: @""
    ];
    for (NSString *message in messages) {
        NSString *lowercase = message.lowercaseString;
        if ([lowercase containsString:@"appcheck"] ||
            [lowercase containsString:@"app check"] ||
            [lowercase containsString:@"app attest"] ||
            [lowercase containsString:@"app check token is invalid"]) {
            return YES;
        }
    }

    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:NSError.class] && underlying != error) {
        return [self pp_errorLooksLikeAppCheckFailure:underlying];
    }
    return NO;
}

- (NSString *)pp_authBackendMessageFromError:(NSError *_Nullable)error {
    if (!error) {
        return @"";
    }

    id payload = error.userInfo[kPPFIRAuthDeserializedResponseKey];
    NSString *message = [self pp_messageFromDeserializedPayload:payload];
    if (message.length) {
        return message;
    }

    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:NSError.class]) {
        message = [self pp_messageFromDeserializedPayload:underlying.userInfo[kPPFIRAuthDeserializedResponseKey]];
        if (message.length) {
            return message;
        }
    }
    return @"";
}

- (NSString *)pp_messageFromDeserializedPayload:(id)payload {
    if (![payload isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *dictionary = (NSDictionary *)payload;
    NSString *message = [dictionary[@"message"] isKindOfClass:NSString.class] ? dictionary[@"message"] : @"";
    if (message.length) {
        return message;
    }

    id errorObject = [dictionary[@"error"] isKindOfClass:NSDictionary.class] ? dictionary[@"error"] : nil;
    if (errorObject) {
        message = [errorObject[@"message"] isKindOfClass:NSString.class] ? errorObject[@"message"] : @"";
    }
    return message;
}

@end
