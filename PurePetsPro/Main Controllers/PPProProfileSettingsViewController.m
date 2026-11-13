//
//  PPProProfileSettingsViewController.m
//  PurePetsPro
//
//  Reinvented & Refactored from first principles (NextGen V9).
//  Hosts the category-defining SwiftUI Personal Operator Profile & Account Governance Studio (PPProProfileSettingsView).
//  Completely decoupled from the commercial company profile.
//

#import "PPProProfileSettingsViewController.h"

#import "NotificationSettingsViewController.h"
#import "PPProviderProfileEditorViewController.h"
#import "PPFirebaseCompat.h"
#import "PPProviderApplicationManager.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPFunc.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "Styling.h"
#import "PurePetsPro-Swift.h"

static NSString *PPProCurrentThemePreference(void) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"themePreference"];
    return saved ?: PPProThemePreferenceSystem;
}

static void PPProApplyThemePreference(NSString *preference) {
    NSString *resolved = preference ?: PPProThemePreferenceSystem;
    [[NSUserDefaults standardUserDefaults] setObject:resolved forKey:@"themePreference"];
    [[NSUserDefaults standardUserDefaults] synchronize];

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

@interface PPProProfileSettingsViewController ()
@property (nonatomic, strong) PPProProfileSettingsHostController *hostingController;
@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;
@property (nonatomic, strong) PPProviderOnboardingState *providerState;
@property (nonatomic, strong) NSError *providerStateError;
@property (nonatomic, strong) id<FIRListenerRegistration> providerStateListener;
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
    [self pp_refreshAllContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_refreshAllContent];
}

- (void)dealloc {
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

    if (nameChanged) {
        dispatch_group_enter(group);
        user.displayName = trimmedName;
        [UsrMgr p_cacheUser:user];
        [user SYNC:^(NSError *error) {
            if (error && !firstError) firstError = error;
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

    if (phoneChanged) {
        dispatch_group_enter(group);
        user.MobileNo = trimmedPhone;
        [UsrMgr p_cacheUser:user];
        [user SYNC:^(NSError *error) {
            if (error && !firstError) firstError = error;
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
        [strongSelf pp_refreshAllContent];
        [PPToast toast:kLang(@"ProfileUpdated") style:PPToastStyleSuccess haptic:YES duration:1.8];
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
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) return;
    FIRDocumentReference *doc = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    __weak typeof(self) weakSelf = self;
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error || !snap.exists) return;
        NSArray *urls = [snap[@"coverImageUrls"] isKindOfClass:NSArray.class] ? snap[@"coverImageUrls"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.coverImageURLs removeAllObjects];
            for (id item in urls) {
                if ([item isKindOfClass:NSString.class] && ((NSString *)item).length > 0) {
                    [strongSelf.coverImageURLs addObject:item];
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
    if ([user.UserImageUrl isKindOfClass:NSURL.class]) {
        return user.UserImageUrl.absoluteString ?: @"";
    }
    if ([user.UserImageUrl isKindOfClass:NSString.class]) {
        return (NSString *)user.UserImageUrl ?: @"";
    }
    return PPSafeString(user.photoURL);
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
