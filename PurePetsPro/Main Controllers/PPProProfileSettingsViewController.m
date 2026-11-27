//
//  PPProProfileSettingsViewController.m
//  PurePetsPro
//
//  Reinvented & Refactored from first principles (NextGen V9).
//  Hosts the category-defining SwiftUI Personal Operator Profile & Account Governance Studio (PPProProfileSettingsView).
//  Completely decoupled from the commercial company profile.
//

#import "PPProProfileSettingsViewController.h"

#import <PhotosUI/PhotosUI.h>
#import "NotificationSettingsViewController.h"
#import "PPProviderProfileEditorViewController.h"
#import "PPProRememberedAccountStore.h"
#import "FUManager.h"
#import "PPFirebaseCompat.h"
#import "PPProviderApplicationManager.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPFunc.h"
#import "PPDesignTokens.h"
#import "TOCropViewController.h"
#import "Language.h"
#import "Styling.h"
#import "PurePetsPro-Swift.h"

static NSString * const kPPProUserProfileDidUpdateNotification = @"PPProUserProfileDidUpdateNotification";

static BOOL PPProProfileStorageErrorLooksFinalized(NSError *error) {
    if (!error) return NO;
    NSString *desc = PPSafeString(error.localizedDescription);
    return [desc containsString:@"already completed"] || [desc containsString:@"finalized"];
}

static NSString *PPProCurrentThemePreference(void) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"themePreference"];
    return saved ?: PPProThemePreferenceSystem;
}

static void PPProApplyThemePreference(NSString *preference) {
    NSString *resolved = preference ?: PPProThemePreferenceSystem;
    [[NSUserDefaults standardUserDefaults] setObject:resolved forKey:@"themePreference"];

    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if ([resolved isEqualToString:PPProThemePreferenceLight]) style = UIUserInterfaceStyleLight;
    if ([resolved isEqualToString:PPProThemePreferenceDark]) style = UIUserInterfaceStyleDark;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            window.overrideUserInterfaceStyle = style;
        }
    }
}

@interface PPProProfileSettingsViewController () <PHPickerViewControllerDelegate, TOCropViewControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) PPProProfileSettingsHostController *hostingController;
@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;
@property (nonatomic, strong) PPProviderOnboardingState *providerState;
@property (nonatomic, strong) NSError *providerStateError;
@property (nonatomic, strong) id<FIRListenerRegistration> providerStateListener;
@property (nonatomic, strong, nullable) FIRStorageUploadTask *activeAvatarUploadTask;
@property (nonatomic, assign) BOOL isUploadingAvatar;
@end

@implementation PPProProfileSettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = YES;
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.coverImageURLs = [NSMutableArray array];

    __weak typeof(self) weakSelf = self;
    PPProProfileSnapshot *snapshot = [self pp_currentProfileSnapshot];
    self.hostingController = [PPProProfileSettingsHostingBridge makeViewControllerWithSnapshot:snapshot
                                                                                       onSave:^(NSString *name, NSString *email, NSString *phone) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_saveProfileWithName:name email:email phone:phone];
    }
                                                                               onChangeAvatar:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_changeAvatarTapped];
    }
                                                                        onEditProviderProfile:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_openProviderProfileEditor];
    }
                                                                          onOpenNotifications:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NotificationSettingsViewController *vc = [[NotificationSettingsViewController alloc] init];
        [strongSelf.navigationController pushViewController:vc animated:YES];
    }
                                                                                onSelectTheme:^(NSString *theme) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        PPProApplyThemePreference(theme);
        [PPToast toast:kLang(@"ThemeUpdated") style:PPToastStyleSuccess haptic:YES duration:1.5];
        [strongSelf pp_refreshAllContent];
    }
                                                                             onSelectLanguage:^(NSString *code) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_applyLanguageCode:code];
    }
                                                                                     onLogout:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_logoutAction];
    }
                                                                                    onDismiss:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.navigationController && strongSelf.navigationController.viewControllers.count > 1) {
            [strongSelf.navigationController popViewControllerAnimated:YES];
        } else {
            [strongSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];

    [self addChildViewController:self.hostingController];
    [self.view addSubview:self.hostingController.view];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self.hostingController didMoveToParentViewController:self];

    [self pp_loadCoverImageURLs];
    [self pp_startProviderStateObservation];
    [self pp_configureMultiAccountSurface];
    [self pp_refreshAllContent];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleSessionDidSuspend:)
                                                 name:PPProSessionDidSuspendNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleSessionDidCommit:)
                                                 name:PPProSessionDidCommitNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleAccountListDidChange:)
                                                 name:PPProSessionAccountListDidChangeNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_loadCoverImageURLs];
    [self pp_refreshAllContent];
}

- (void)pp_handleSessionDidSuspend:(NSNotification *)note {
    [self.activeAvatarUploadTask cancel];
    self.activeAvatarUploadTask = nil;
    self.isUploadingAvatar = NO;
    [self.hostingController setUploadingAvatar:NO];
    [self.providerStateListener remove];
    self.providerStateListener = nil;
    [PPHUD dismiss];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.activeAvatarUploadTask cancel];
    self.activeAvatarUploadTask = nil;
    [self.providerStateListener remove];
    self.providerStateListener = nil;
}

#pragma mark - Navigation to Company Profile

- (void)pp_openProviderProfileEditor {
    [PPFunc pp_playTapEffect];
    PPProviderProfileEditorViewController *controller = [[PPProviderProfileEditorViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Save Profile

- (void)pp_saveProfileWithName:(NSString *)name email:(NSString *)email phone:(NSString *)phone {
    UserModel *user = UsrMgr.currentUser;
    if (!user) {
        [self.hostingController didFinishSaving];
        return;
    }

    NSString *trimmedName = [PPSafeString(name) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *trimmedEmail = [PPSafeString(email) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *trimmedPhone = [PPSafeString(phone) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (trimmedName.length == 0) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProfileSettings_NameRequired")];
        return;
    }

    [self.view endEditing:YES];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Saving") subtitle:nil];

    NSString *currentName = [self pp_displayNameForUser:user];
    NSString *currentEmail = user.UserEmail.length ? user.UserEmail : (user.email.length ? user.email : @"");
    NSString *currentPhone = user.MobileNo.length ? user.MobileNo : @"";

    BOOL nameChanged = ![trimmedName isEqualToString:currentName];
    BOOL emailChanged = ![trimmedEmail isEqualToString:currentEmail];
    BOOL phoneChanged = ![trimmedPhone isEqualToString:currentPhone];

    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;

    if (nameChanged || phoneChanged) {
        NSString *uid = [PPProSessionCoordinator.shared activeUID] ?: (user.uid.length ? user.uid : user.ID);
        FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
        if (uid.length > 0 && db) {
            dispatch_group_enter(group);
            NSMutableDictionary *patch = [NSMutableDictionary dictionary];
            if (nameChanged) {
                patch[@"displayName"] = trimmedName;
                patch[@"UserName"] = trimmedName;
            }
            if (phoneChanged) {
                patch[@"MobileNo"] = trimmedPhone;
            }
            patch[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];

            FIRDocumentReference *userRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
            [userRef setData:patch merge:YES completion:^(NSError * _Nullable error) {
                if (!error) {
                    if (nameChanged) {
                        user.displayName = trimmedName;
                        user.UserName = trimmedName;
                    }
                    if (phoneChanged) {
                        user.MobileNo = trimmedPhone;
                    }
                    [UsrMgr p_cacheUser:user];
                } else if (!firstError) {
                    firstError = error;
                }
                dispatch_group_leave(group);
            }];
        } else if (uid.length > 0 && !firstError) {
            firstError = [NSError errorWithDomain:@"PPProProfileSettings" code:401 userInfo:@{NSLocalizedDescriptionKey: kLang(@"ProviderProfileEditor_SessionExpired")}];
        }
    }

    FIRUser *activeAuthUser = [PPProSessionCoordinator.shared currentUser];
    if (nameChanged && activeAuthUser) {
        dispatch_group_enter(group);
        FIRUserProfileChangeRequest *req = [activeAuthUser profileChangeRequest];
        req.displayName = trimmedName;
        [req commitChangesWithCompletion:^(__unused NSError * _Nullable authErr) {
            dispatch_group_leave(group);
        }];
    }

    if (emailChanged && trimmedEmail.length > 0) {
        dispatch_group_enter(group);
        [FUM updateEmail:trimmedEmail completion:^(NSError *error) {
            if (!error) {
                user.UserEmail = trimmedEmail;
                user.email = trimmedEmail;
                [UsrMgr p_cacheUser:user];
            } else if (!firstError) {
                firstError = error;
            }
            dispatch_group_leave(group);
        }];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        [strongSelf.hostingController didFinishSaving];
        if (firstError) {
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:firstError.localizedDescription];
            return;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kPPProUserProfileDidUpdateNotification object:nil];
        [strongSelf pp_refreshAllContent];
        [PPToast toast:kLang(@"ProfileUpdated") style:PPToastStyleSuccess haptic:YES duration:1.8];
    });
}

#pragma mark - Avatar Picking & Upload

- (void)pp_changeAvatarTapped {
    if (self.isUploadingAvatar) return;
    [PPFunc pp_playTapEffect];
    if (![PPProSessionCoordinator.shared activeUID].length) {
        [PPToast toast:kLang(@"ProviderProfileEditor_SessionExpired") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = [PHPickerFilter imagesFilter];
        configuration.selectionLimit = 1;
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    NSItemProvider *provider = results.firstObject.itemProvider;
    __weak typeof(self) weakSelf = self;
    [self pp_loadImageFromProvider:provider completion:^(UIImage * _Nullable image) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!image) {
            [PPToast toast:kLang(@"ProviderProfileEditor_ImageLoadFailed") style:PPToastStyleError haptic:YES duration:1.4];
            return;
        }
        [PPFunc pp_presentCircularCropperWithImage:image fromController:strongSelf];
    }];
}

- (void)pp_loadImageFromProvider:(NSItemProvider *)provider completion:(void(^)(UIImage * _Nullable image))completion {
    [provider loadDataRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
        UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
        if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
            return;
        }
        if ([provider canLoadObjectOfClass:[UIImage class]]) {
            [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> _Nullable object, NSError * _Nullable loadErr) {
                UIImage *fallbackImage = [object isKindOfClass:[UIImage class]] ? (UIImage *)object : nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(fallbackImage);
                });
            }];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
    }];
}

- (void)cropViewController:(TOCropViewController *)cropViewController didFinishCancelled:(BOOL)cancelled {
    (void)cancelled;
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)cropViewController:(TOCropViewController *)cropViewController didCropToCircularImage:(UIImage *)image withRect:(CGRect)cropRect angle:(NSInteger)angle {
    (void)cropRect;
    (void)angle;
    __weak typeof(self) weakSelf = self;
    [cropViewController dismissViewControllerAnimated:YES completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_uploadAvatarImage:image];
    }];
}

- (void)pp_uploadAvatarImage:(UIImage *)image {
    FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
    FIRStorage *activeStorage = [PPProSessionCoordinator.shared activeStorage];
    NSString *uid = PPSafeString(authUser.uid);
    if (uid.length == 0 || !activeStorage || !image) {
        [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    self.isUploadingAvatar = YES;
    [self.hostingController setUploadingAvatar:YES];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_UploadingAvatar") subtitle:nil];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat maxDimension = 900.0;
        UIImage *scaledImage = image;
        if (image.size.width > maxDimension || image.size.height > maxDimension) {
            CGFloat ratio = maxDimension / MAX(image.size.width, image.size.height);
            CGSize target = CGSizeMake(image.size.width * ratio, image.size.height * ratio);
            UIGraphicsBeginImageContextWithOptions(target, NO, 1.0);
            [image drawInRect:CGRectMake(0.0, 0.0, target.width, target.height)];
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?: image;
            UIGraphicsEndImageContext();
        }

        NSData *jpegData = UIImageJPEGRepresentation(scaledImage, 0.82);
        if (jpegData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.isUploadingAvatar = NO;
                [strongSelf.hostingController setUploadingAvatar:NO];
                [PPHUD dismiss];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
            });
            return;
        }

        NSString *path = [NSString stringWithFormat:@"uploads/users/%@/profile/avatar_%lld.jpg",
                          uid,
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        FIRStorageReference *ref = [[activeStorage reference] child:path];
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{@"uploaded_by": uid};
        FIRStorageUploadTask *task = [ref putData:jpegData metadata:metadata];
        __block BOOL didFinish = NO;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.activeAvatarUploadTask = task;
        });

        void (^finishUpload)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
            @synchronized (ref) {
                if (didFinish) return;
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                if (strongSelf.activeAvatarUploadTask == task) {
                    strongSelf.activeAvatarUploadTask = nil;
                }
                if (![[PPProSessionCoordinator.shared activeUID] isEqualToString:uid] ||
                    [PPProSessionCoordinator.shared isSuspendedOrLocked]) {
                    strongSelf.isUploadingAvatar = NO;
                    [strongSelf.hostingController setUploadingAvatar:NO];
                    [PPHUD dismiss];
                    return;
                }
            });
            if (urlString.length == 0 || error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    strongSelf.isUploadingAvatar = NO;
                    [strongSelf.hostingController setUploadingAvatar:NO];
                    [PPHUD dismiss];
                    [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
                });
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf pp_persistUploadedAvatarURLString:urlString completion:^(NSError * _Nullable saveError) {
                    __strong typeof(weakSelf) strongInner = weakSelf;
                    if (!strongInner) return;
                    strongInner.isUploadingAvatar = NO;
                    [strongInner.hostingController setUploadingAvatar:NO];
                    [PPHUD dismiss];
                    if (saveError) {
                        [PPAlertHelper showErrorIn:strongInner title:kLang(@"Error") subtitle:saveError.localizedDescription];
                        return;
                    }
                    [strongInner pp_refreshAllContent];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPPProUserProfileDidUpdateNotification object:nil];
                    [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploaded") style:PPToastStyleSuccess haptic:YES duration:1.6];
                }];
            });
        };

        void (^resolveDownloadURL)(NSError * _Nullable) = ^(NSError * _Nullable fallbackError) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
                NSString *resolved = PPSafeString(URL.absoluteString);
                if (resolved.length > 0) {
                    finishUpload(resolved, nil);
                    return;
                }
                finishUpload(nil, error2 ?: fallbackError ?: [NSError errorWithDomain:@"PPProProfileSettings" code:-44 userInfo:nil]);
            }];
        };

        [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
            resolveDownloadURL(nil);
        }];
        [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
            NSError *taskError = snapshot.error;
            if (PPProProfileStorageErrorLooksFinalized(taskError)) {
                resolveDownloadURL(taskError);
                return;
            }
            finishUpload(nil, taskError ?: [NSError errorWithDomain:@"PPProProfileSettings" code:-45 userInfo:nil]);
        }];
    });
}

- (void)pp_persistUploadedAvatarURLString:(NSString *)urlString completion:(void(^)(NSError * _Nullable error))completion {
    FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    NSString *uid = PPSafeString(authUser.uid);
    NSURL *url = urlString.length ? [NSURL URLWithString:urlString] : nil;
    if (uid.length == 0 || !db || !url) {
        if (completion) completion([NSError errorWithDomain:@"PPProProfileSettings" code:-10 userInfo:@{NSLocalizedDescriptionKey: kLang(@"ProviderProfileEditor_AvatarUploadFailed")}]);
        return;
    }

    FIRDocumentReference *userRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
    NSDictionary *fields = @{
        @"UserImageUrl": urlString,
        @"photoURL": urlString,
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };

    dispatch_group_t group = dispatch_group_create();
    __block NSError *firestoreError = nil;

    dispatch_group_enter(group);
    [userRef setData:fields merge:YES completion:^(NSError * _Nullable error) {
        firestoreError = error;
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    FIRUserProfileChangeRequest *req = [authUser profileChangeRequest];
    req.photoURL = url;
    [req commitChangesWithCompletion:^(__unused NSError * _Nullable authError) {
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (!firestoreError) {
            UserModel *user = UsrMgr.currentUser;
            if (user) {
                user.photoURL = urlString;
                [UsrMgr p_cacheUser:user];
            }
        }
        if (completion) completion(firestoreError);
    });
}

#pragma mark - Preferences & Session Actions

- (void)pp_applyLanguageCode:(NSString *)code {
    NSString *target = code.length ? code : @"en";
    NSString *current = [Language currentLanguageCode] ?: @"en";
    if ([target isEqualToString:current]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    UIImage *warnIcon = [UIImage systemImageNamed:@"globe.central.south.asia.fill"];
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"Confirm_LanguageChange_Title")
                             subtitle:kLang(@"Confirm_LanguageChange_Msg")
                          placeholder:nil
                        confirmButton:kLang(@"Confirm")
                         cancelButton:kLang(@"Cancel")
                                 icon:warnIcon
                         confirmBlock:^{
        [Language userSelectedLanguage:target];
        [PPAlertHelper showSuccessIn:weakSelf
                               title:kLang(@"Success")
                            subtitle:kLang(@"Language changed successfully")];
    }
                          cancelBlock:nil];
}

- (nullable SceneDelegate *)pp_sceneDelegate {
    id<UIWindowSceneDelegate> sceneDelegate = self.view.window.windowScene.delegate;
    if ([sceneDelegate isKindOfClass:SceneDelegate.class]) {
        return (SceneDelegate *)sceneDelegate;
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        id<UIWindowSceneDelegate> candidate = ((UIWindowScene *)scene).delegate;
        if ([candidate isKindOfClass:SceneDelegate.class]) {
            return (SceneDelegate *)candidate;
        }
    }
    return nil;
}

- (void)pp_handleSessionDidCommit:(__unused NSNotification *)note {
    [self pp_loadCoverImageURLs];
    [self pp_startProviderStateObservation];
    [self pp_refreshAllContent];
}

- (void)pp_handleAccountListDidChange:(__unused NSNotification *)note {
    [self pp_refreshAllContent];
}

- (void)pp_configureMultiAccountSurface {
    __weak typeof(self) weakSelf = self;
    NSArray<NSDictionary<NSString *, NSString *> *> *accounts = [PPProRememberedAccountStore rolloutEnabled]
        ? ([PPProRememberedAccountStore recordsWithError:nil] ?: @[])
        : @[];
    NSString *activeUID = [PPProSessionCoordinator.shared activeUID] ?: @"";
    [self.hostingController configureMultiAccountEnabled:[PPProRememberedAccountStore rolloutEnabled]
                                               activeUID:activeUID
                                      rememberedAccounts:accounts
                                         onSwitchAccount:^(NSString *uid) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![PPProRememberedAccountStore rolloutEnabled]) return;
        SceneDelegate *sd = [strongSelf pp_sceneDelegate];
        [sd switchToRememberedAccountUID:uid animated:YES];
    }
                                            onAddAccount:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![PPProRememberedAccountStore rolloutEnabled]) return;
        SceneDelegate *sd = [strongSelf pp_sceneDelegate];
        [sd beginAddAccountTransitionAnimated:YES];
    }
                                            onSignOutAll:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![PPProRememberedAccountStore rolloutEnabled]) return;
        SceneDelegate *sd = [strongSelf pp_sceneDelegate];
        [sd signOutAllAccountsAnimated:YES];
    }
                               onRemoveRememberedAccount:^(NSString *uid) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![PPProRememberedAccountStore rolloutEnabled] || uid.length == 0) return;
        [PPProSessionCoordinator.shared removeRememberedAccountWithUID:uid completion:^(__unused BOOL removed, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf) return;
                if (error) {
                    [PPAlertHelper showErrorIn:innerSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                }
                [innerSelf pp_refreshAllContent];
            });
        }];
    }];
}

- (void)pp_logoutAction {
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"LogOut")
                             subtitle:kLang(@"LogOutConfirmation")
                          placeholder:nil
                        confirmButton:kLang(@"LogOut")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{
        [UsrMgr signOut];
    } cancelBlock:nil];
}

#pragma mark - Snapshot & State Observation

- (PPProProfileSnapshot *)pp_currentProfileSnapshot {
    UserModel *user = UsrMgr.currentUser;
    NSString *displayName = [self pp_displayNameForUser:user];
    NSString *roleName = [PPRolePermission localizedRoleName:user.role] ?: @"";
    NSString *email = user.UserEmail.length ? user.UserEmail : (user.email.length ? user.email : @"");
    NSString *phone = user.MobileNo.length ? user.MobileNo : @"";
    NSString *avatarURL = [self pp_avatarURLStringForUser:user];
    NSString *workspace = [self pp_primaryProviderWorkspaceTitle] ?: @"";
    NSString *status = [self pp_providerStatusTitle] ?: @"";
    NSString *planSummary = [self pp_providerPlanSummary] ?: @"";
    NSString *themeKey = PPProCurrentThemePreference() ?: PPProThemePreferenceSystem;
    NSString *langCode = [Language currentLanguageCode] ?: @"ar";

    return [[PPProProfileSnapshot alloc] initWithDisplayName:displayName ?: @""
                                                       email:email ?: @""
                                                       phone:phone ?: @""
                                                    roleName:roleName ?: @""
                                                   avatarURL:avatarURL.length ? avatarURL : nil
                                                   coverURLs:self.coverImageURLs.copy ?: @[]
                                              workspaceTitle:workspace
                                                 statusTitle:status
                                                 planSummary:planSummary
                                             currentThemeKey:themeKey
                                         currentLanguageCode:langCode];
}

- (void)pp_refreshAllContent {
    PPProProfileSnapshot *snapshot = [self pp_currentProfileSnapshot];
    [self.hostingController updateSnapshot:snapshot];
    NSArray<NSDictionary<NSString *, NSString *> *> *accounts = [PPProRememberedAccountStore rolloutEnabled]
        ? ([PPProRememberedAccountStore recordsWithError:nil] ?: @[])
        : @[];
    NSString *activeUID = [PPProSessionCoordinator.shared activeUID] ?: @"";
    [self.hostingController updateRememberedAccounts:accounts
                                           activeUID:activeUID
                                 multiAccountEnabled:[PPProRememberedAccountStore rolloutEnabled]];
}

- (void)pp_startProviderStateObservation {
    [self.providerStateListener remove];
    __weak typeof(self) weakSelf = self;
    self.providerStateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.providerState = state;
        strongSelf.providerStateError = error;
        [strongSelf pp_refreshAllContent];
    }];
}

- (void)pp_loadCoverImageURLs {
    FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (!authUser.uid.length || !db) return;
    FIRDocumentReference *doc = [[db collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    __weak typeof(self) weakSelf = self;
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error || !snap.exists) return;
        NSArray *urls = [snap[@"coverImageUrls"] isKindOfClass:NSArray.class] ? snap[@"coverImageUrls"] : @[];
        NSString *docPhoto = PPSafeString(snap[@"UserImageUrl"]).length ? PPSafeString(snap[@"UserImageUrl"]) : PPSafeString(snap[@"photoURL"]);
        NSString *docName = PPSafeString(snap[@"displayName"]).length ? PPSafeString(snap[@"displayName"]) : PPSafeString(snap[@"UserName"]);
        NSString *docPhone = PPSafeString(snap[@"MobileNo"]);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.coverImageURLs removeAllObjects];
            for (id item in urls) {
                if ([item isKindOfClass:NSString.class] && ((NSString *)item).length > 0) {
                    [strongSelf.coverImageURLs addObject:item];
                }
            }
            UserModel *user = UsrMgr.currentUser;
            if (user) {
                BOOL userUpdated = NO;
                if (docPhoto.length > 0 && ![PPSafeString(user.photoURL) isEqualToString:docPhoto]) {
                    user.photoURL = docPhoto;
                    userUpdated = YES;
                }
                if (docName.length > 0 && ![PPSafeString(user.displayName) isEqualToString:docName]) {
                    user.displayName = docName;
                    user.UserName = docName;
                    userUpdated = YES;
                }
                if (docPhone.length > 0 && ![PPSafeString(user.MobileNo) isEqualToString:docPhone]) {
                    user.MobileNo = docPhone;
                    userUpdated = YES;
                }
                if (userUpdated) {
                    [UsrMgr p_cacheUser:user];
                }
            }
            [strongSelf pp_refreshAllContent];
        });
    }];
}

- (NSString *)pp_displayNameForUser:(UserModel *)user {
    NSString *displayName = PPSafeString(user.displayName);
    if (displayName.length == 0) displayName = PPSafeString([user PPBestDisplayName]);
    if (displayName.length == 0) displayName = PPSafeString(user.UserName);
    return displayName;
}

- (NSString *)pp_avatarURLStringForUser:(UserModel *)user {
    if ([user.UserImageUrl isKindOfClass:NSURL.class] && user.UserImageUrl.absoluteString.length > 0) {
        return user.UserImageUrl.absoluteString ?: @"";
    }
    if ([user.UserImageUrl isKindOfClass:NSString.class] && ((NSString *)user.UserImageUrl).length > 0) {
        return (NSString *)user.UserImageUrl ?: @"";
    }
    if (PPSafeString(user.photoURL).length > 0) {
        return PPSafeString(user.photoURL);
    }
    return PPSafeString([PPProSessionCoordinator.shared currentUser].photoURL.absoluteString);
}

- (NSString *)pp_primaryProviderWorkspaceTitle {
    if (UsrMgr.currentUser.canAccessProviderMarketplaceFeature) return kLang(@"Market_Title");
    if (UsrMgr.currentUser.canPharmacyFeature && UsrMgr.currentUser.canManagePetMedicinesPermission) return kLang(@"Pharmacy_Manage_Title");
    if ((UsrMgr.currentUser.canOfferServices || UsrMgr.currentUser.canOfferServicesFeature) && UsrMgr.currentUser.canManageServiceProviderPermission) return kLang(@"ManageServices");
    if (UsrMgr.currentUser.canVetFeature && (UsrMgr.currentUser.canEditVetInfoPermission || UsrMgr.currentUser.canManageVetPermission || UsrMgr.currentUser.canPostVetProfilePermission)) return kLang(@"Vet_Manage_Title");
    if (UsrMgr.currentUser.canDeliveryCompanyFeature || self.providerState.canDeliveryCompany) return kLang(@"DeliveryCompany_Title");
    if (PPProviderTypeIsEnabledInProApp(PPProviderTypeDeliverySubscription) && (UsrMgr.currentUser.canDelivery || UsrMgr.currentUser.canDeliveryFeature) && UsrMgr.currentUser.canManageDeliveryPermission) return kLang(@"DeliveryManagement");
    if (self.providerState.partnerOnboardingVisible || self.providerState.hasAnyLifecycleRecord) return kLang(@"ProviderSubscriptionCardTitle");
    return @"";
}

- (NSString *)pp_providerStatusTitle {
    if (self.providerStateError) return kLang(@"ProviderHeroErrorBadge");
    if (self.providerState.isBlocked) return kLang(@"ProviderHeroBlockedBadge");

    NSArray<NSNumber *> *types = @[
        @(PPProviderTypeMarketplace),
        @(PPProviderTypeDeliveryCompany),
        @(PPProviderTypeVet),
        @(PPProviderTypePharmacy),
        @(PPProviderTypeDeliverySubscription),
        @(PPProviderTypeService)
    ];
    for (NSNumber *typeValue in types) {
        PPProviderType type = typeValue.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) continue;
        if ([self.providerState isActiveForType:type]) return kLang(@"ProviderStatusActive");
        PPProviderProfile *managedProfile = [self.providerState profileForType:type];
        if (managedProfile.hasManagedSubscription) return kLang([@"PartnerSub_Status_" stringByAppendingString:managedProfile.effectiveSubscriptionStatus]);
        PPProviderApplication *application = [self.providerState applicationForType:type];
        NSString *status = [[PPSafeString(application.status) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([status isEqualToString:@"pending"] || [status isEqualToString:@"under_review"]) {
            return kLang(@"ProviderStatusUnderReview");
        }
    }
    if ([self pp_primaryProviderWorkspaceTitle].length > 0) {
        return kLang(@"ProfileSettings_ProviderPreviewStatusReady");
    }
    return kLang(@"ProfileSettings_ProviderPreviewStatusUnavailable");
}

- (NSString *)pp_providerPlanSummary {
    if (self.providerStateError) {
        return self.providerStateError.localizedDescription.length ? self.providerStateError.localizedDescription : kLang(@"ProviderStateErrorSubtitle");
    }
    if (self.providerState.isBlocked) {
        return kLang(@"ProviderSubscriptionCardBlockedSubtitle");
    }

    NSArray<NSNumber *> *types = @[
        @(PPProviderTypeMarketplace),
        @(PPProviderTypeDeliveryCompany),
        @(PPProviderTypeVet),
        @(PPProviderTypePharmacy),
        @(PPProviderTypeDeliverySubscription),
        @(PPProviderTypeService)
    ];
    for (NSNumber *typeValue in types) {
        PPProviderType type = typeValue.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) continue;
        PPProviderProfile *profile = [self.providerState profileForType:type];
        if (profile.hasManagedSubscription) return [NSString stringWithFormat:@"%@ · %@", profile.localizedPlanName, profile.localizedSubscriptionSummary];
        if ([self.providerState isActiveForType:type] || [PPSafeString(profile.status).lowercaseString isEqualToString:@"active"]) {
            NSString *planName = profile.localizedPlanName.length ? profile.localizedPlanName : kLang(@"ProviderSubscriptionCardActivePlanFallback");
            return [NSString stringWithFormat:kLang(@"ProfileSettings_ProviderPreviewPlanFormat"), planName];
        }

        PPProviderApplication *application = [self.providerState applicationForType:type];
        NSString *applicationStatus = [[PPSafeString(application.status) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([applicationStatus isEqualToString:@"pending"] || [applicationStatus isEqualToString:@"under_review"]) {
            return kLang(@"ProviderSubscriptionCardReviewSubtitle");
        }
    }

    if ([self pp_primaryProviderWorkspaceTitle].length > 0) {
        return kLang(@"ProfileSettings_ProviderPreviewWorkspaceHint");
    }
    return kLang(@"ProfileSettings_ProviderPreviewEmpty");
}

@end
