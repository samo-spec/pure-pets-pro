//
//  PPProviderProfileEditorViewController.m
//  PurePetsPro
//
//  Reinvented & Refactored from first principles (NextGen V9).
//  Hosts the category-defining SwiftUI Commercial Company & Facility Studio (PPProviderProfileEditorView).
//  Completely decoupled from the personal user account profile.
//

#import "PPProviderProfileEditorViewController.h"

#import <PhotosUI/PhotosUI.h>
#import "PPProProfileSettingsViewController.h"
#import "FUManager.h"
#import "PPAlertHelper.h"
#import "PPFirebaseCompat.h"
#import "PPFunc.h"
#import "PPHUD.h"
#import "PPProviderApplicationManager.h"
#import "PPToast.h"
#import "Styling.h"
#import "TOCropViewController.h"
#import "CitiesManager.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"

typedef NS_ENUM(NSInteger, PPProviderProfileEditorPickerMode) {
    PPProviderProfileEditorPickerModeNone = 0,
    PPProviderProfileEditorPickerModeAvatar = 1,
    PPProviderProfileEditorPickerModeCovers = 2,
};

static void PPProviderProfileEditorLog(NSString *message) {
    NSLog(@"[Provider_Editor] %@", message ?: @"");
}

static NSDictionary *PPProviderProfileEditorCityOption(NSString *value, NSString *titleKey) {
    return @{
        @"value": value ?: @"",
        @"titleKey": titleKey ?: @"",
    };
}

static NSArray<NSDictionary *> *PPProviderProfileEditorCityOptions(void) {
    NSArray<CityModel *> *cities = [CitiesManager.shared citiesForCurrentCountry];
    NSMutableArray<NSDictionary *> *options = [NSMutableArray array];
    for (CityModel *city in cities) {
        NSString *cityID = [NSString stringWithFormat:@"%ld", (long)city.cityID];
        NSString *title = Language.isRTL ? city.arName : city.enName;
        [options addObject:PPProviderProfileEditorCityOption(cityID, title)];
    }
    return options.copy;
}

static NSDictionary *PPProviderProfileEditorCityOptionForID(NSString *cityID) {
    NSString *safeID = PPSafeString(cityID);
    for (NSDictionary *option in PPProviderProfileEditorCityOptions()) {
        if ([PPSafeString(option[@"value"]) isEqualToString:safeID]) {
            return option;
        }
    }
    return nil;
}

static BOOL PPProviderProfileEditorStorageErrorLooksFinalized(NSError *error) {
    if (!error) return NO;
    NSString *desc = PPSafeString(error.localizedDescription);
    return [desc containsString:@"already completed"] || [desc containsString:@"finalized"];
}

static BOOL PPProviderProfileEditorFunctionErrorIsUnauthenticated(NSError *error) {
    if (!error) return NO;
    return [error.domain isEqualToString:@"FIRFunctionsErrorDomain"] && error.code == 16;
}

static BOOL PPProviderProfileEditorFunctionErrorIsPermissionDenied(NSError *error) {
    if (!error) return NO;
    return [error.domain isEqualToString:@"FIRFunctionsErrorDomain"] && error.code == 7;
}

static BOOL PPProviderProfileEditorFunctionErrorIsNotFound(NSError *error) {
    if (!error) return NO;
    return [error.domain isEqualToString:@"FIRFunctionsErrorDomain"] && error.code == 5;
}

#pragma mark - Qatar City Selection Sheet Modal

@interface PPProviderProfileEditorCitySheetViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (instancetype)initWithSelectedCity:(NSString *)selectedCity
                          completion:(void(^)(NSString *cityID))completion;
@end

@implementation PPProviderProfileEditorCitySheetViewController {
    NSString *_selectedCity;
    NSArray<NSDictionary *> *_options;
    void (^_completion)(NSString *cityID);
    UITableView *_tableView;
}

- (instancetype)initWithSelectedCity:(NSString *)selectedCity
                          completion:(void(^)(NSString *cityID))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _selectedCity = [PPSafeString(selectedCity) copy];
        _options = PPProviderProfileEditorCityOptions();
        _completion = [completion copy];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(citiesDidUpdate:)
                                                     name:CitiesManagerDidUpdateNotification
                                                   object:nil];
    }
    return self;
}

- (void)citiesDidUpdate:(NSNotification *)note {
    _options = PPProviderProfileEditorCityOptions();
    if (_tableView) {
        [_tableView reloadData];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                          [UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28.0;
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:20.0];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    titleLabel.text = kLang(@"ProviderProfileEditor_CitySheetTitle");
    [self.view addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:13.5];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"ProviderProfileEditor_CitySheetSubtitle");
    [self.view addSubview:subtitleLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.rowHeight = 56.0;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cityCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cityCell"];
        cell.backgroundColor = [UIColor ppSurface];
        cell.textLabel.font = [Styling fontMedium:15.0];
        cell.textLabel.textColor = PrimaryTextClr;
    }
    NSDictionary *option = _options[indexPath.row];
    cell.textLabel.text = option[@"titleKey"];
    BOOL selected = [PPSafeString(option[@"value"]) isEqualToString:_selectedCity];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = AppPrimaryClr;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *option = _options[indexPath.row];
    if (_completion) {
        _completion(option[@"value"]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Main Provider Profile Editor Controller

static NSString * const kPPProviderEditorProfileDidUpdateNotification = @"PPProUserProfileDidUpdateNotification";

static NSArray<NSString *> *PPProviderProfileEditorCleanStringArray(id raw) {
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id item in (NSArray *)raw) {
        if ([item isKindOfClass:NSString.class]) {
            NSString *trimmed = [((NSString *)item) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmed.length > 0) {
                [result addObject:trimmed];
            }
        }
    }
    return result.copy;
}

@interface PPProviderProfileEditorViewController () <PHPickerViewControllerDelegate, TOCropViewControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) PPProviderProfileEditorHostController *hostingController;
@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;
@property (nonatomic, copy) NSString *currentDisplayName;
@property (nonatomic, copy) NSString *currentPhone;
@property (nonatomic, copy) NSString *selectedCityID;
@property (nonatomic, copy) NSString *currentAvatarURLString;
@property (nonatomic, strong) NSMutableArray<NSString *> *persistedCoverImageURLs;
@property (nonatomic, copy) NSString *persistedDisplayName;
@property (nonatomic, copy) NSString *persistedPhone;
@property (nonatomic, copy) NSString *persistedCityID;
@property (nonatomic, copy) NSString *persistedAvatarURLString;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *providerProfileID;

@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isUploadingAvatar;
@property (nonatomic, assign) BOOL isUploadingCovers;
@property (nonatomic, assign) BOOL didHydrateData;
@property (nonatomic, assign) BOOL didHydrateProviderProfile;
@property (nonatomic, assign) BOOL didUserModifyAvatar;
@property (nonatomic, assign) BOOL didUserModifyCovers;
@property (nonatomic, assign) PPProviderProfileEditorPickerMode pickerMode;

@property (nonatomic, strong) id<FIRListenerRegistration> providerStateListener;
@property (nonatomic, strong) id<FIRListenerRegistration> userDocumentListener;
@property (nonatomic, strong, nullable) FIRStorageUploadTask *activeAvatarUploadTask;
@property (nonatomic, strong) NSHashTable<FIRStorageUploadTask *> *activeCoverUploadTasks;
@end

@implementation PPProviderProfileEditorViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.coverImageURLs = [NSMutableArray array];
    self.persistedCoverImageURLs = [NSMutableArray array];
    self.currentDisplayName = @"";
    self.currentPhone = @"";
    self.selectedCityID = @"";
    self.currentAvatarURLString = @"";
    self.persistedDisplayName = @"";
    self.persistedPhone = @"";
    self.persistedCityID = @"";
    self.persistedAvatarURLString = @"";
    self.providerType = PPProviderTypeUnspecified;
    self.providerProfileID = @"";
    self.activeCoverUploadTasks = [NSHashTable weakObjectsHashTable];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleSessionDidSuspend:)
                                                 name:PPProSessionDidSuspendNotification
                                               object:nil];

    [self pp_bindCurrentUserFallbacks];

    __weak typeof(self) weakSelf = self;
    PPProviderProfileEditorSnapshot *snapshot = [self pp_currentSnapshot];
    self.hostingController = [PPProviderProfileEditorHostingBridge makeViewControllerWithSnapshot:snapshot
                                                                                           onSave:^(NSString *displayName, NSString *phone, NSString *cityID, NSString *avatarURL, NSArray<NSString *> *coverURLs) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_saveWithDisplayName:displayName phone:phone cityID:cityID avatarURL:avatarURL coverURLs:coverURLs];
    }
                                                                                    onChangeAvatar:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_changeAvatarTapped];
    }
                                                                                       onAddCover:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_addCoverTapped];
    }
                                                                                    onRemoveCover:^(NSInteger index) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_removeCoverAtIndex:index];
    }
                                                                                     onChangeCity:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_changeCityTapped];
    }
                                                                                onOpenUserProfile:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_openUserProfileSettings];
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
    self.hostingController.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self.hostingController didMoveToParentViewController:self];

    [self pp_startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
}

- (void)pp_handleSessionDidSuspend:(NSNotification *)note {
    [self.activeAvatarUploadTask cancel];
    self.activeAvatarUploadTask = nil;
    for (FIRStorageUploadTask *task in self.activeCoverUploadTasks.allObjects) {
        [task cancel];
    }
    [self.activeCoverUploadTasks removeAllObjects];
    self.isUploadingAvatar = NO;
    self.isUploadingCovers = NO;
    [self.providerStateListener remove];
    self.providerStateListener = nil;
    [self.userDocumentListener remove];
    self.userDocumentListener = nil;
    [PPHUD dismiss];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.activeAvatarUploadTask cancel];
    self.activeAvatarUploadTask = nil;
    for (FIRStorageUploadTask *task in self.activeCoverUploadTasks.allObjects) {
        [task cancel];
    }
    [self.providerStateListener remove];
    self.providerStateListener = nil;
    [self.userDocumentListener remove];
    self.userDocumentListener = nil;
}

#pragma mark - Navigation to User Profile

- (void)pp_openUserProfileSettings {
    [PPFunc pp_playTapEffect];
    PPProProfileSettingsViewController *controller = [[PPProProfileSettingsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Data & Snapshot

- (NSString *)pp_currentAuthUID {
    return [PPProSessionCoordinator.shared activeUID] ?: @"";
}

- (void)pp_bindCurrentUserFallbacks {
    UserModel *user = UsrMgr.currentUser;
    if (!user) return;
    self.currentDisplayName = PPSafeString(user.displayName.length ? user.displayName : user.UserName);
    self.currentPhone = PPSafeString(user.MobileNo);
    NSString *photoURL = PPSafeString(user.photoURL.length ? user.photoURL : user.UserImageUrl.absoluteString);
    if (photoURL.length == 0) {
        photoURL = PPSafeString([PPProSessionCoordinator.shared currentUser].photoURL.absoluteString);
    }
    self.currentAvatarURLString = photoURL;
    self.persistedDisplayName = self.currentDisplayName;
    self.persistedPhone = self.currentPhone;
    self.persistedAvatarURLString = photoURL;
}

- (PPProviderProfileEditorSnapshot *)pp_currentSnapshot {
    UserModel *user = UsrMgr.currentUser;
    NSString *displayName = self.currentDisplayName.length ? self.currentDisplayName : ([user PPBestDisplayName] ?: @"");
    NSString *phone = self.currentPhone.length ? self.currentPhone : (user.MobileNo ?: @"");
    NSString *cityID = self.selectedCityID ?: @"";
    NSString *cityTitle = [self pp_localizedCityTitleForID:cityID];
    NSString *providerTypeTitle = [PPProviderApplicationManager localizedTitleForProviderType:self.providerType];
    BOOL hasActiveProfile = (self.providerType != PPProviderTypeUnspecified);

    return [[PPProviderProfileEditorSnapshot alloc] initWithDisplayName:displayName ?: @""
                                                                  phone:phone ?: @""
                                                                 cityID:cityID ?: @""
                                                              cityTitle:cityTitle ?: @""
                                                      providerTypeTitle:providerTypeTitle ?: @""
                                                              avatarURL:self.currentAvatarURLString.length ? self.currentAvatarURLString : nil
                                                              coverURLs:self.coverImageURLs.copy ?: @[]
                                                       hasActiveProfile:hasActiveProfile
                                                            statusTitle:hasActiveProfile ? kLang(@"ProviderStatusActive") : @""
                                                   persistedDisplayName:self.persistedDisplayName ?: @""
                                                         persistedPhone:self.persistedPhone ?: @""
                                                        persistedCityID:self.persistedCityID ?: @""
                                                     persistedAvatarURL:self.persistedAvatarURLString.length ? self.persistedAvatarURLString : nil
                                                     persistedCoverURLs:self.persistedCoverImageURLs.copy ?: @[]
                                                      isUploadingAvatar:self.isUploadingAvatar
                                                      isUploadingCovers:self.isUploadingCovers];
}

- (NSString *)pp_localizedCityTitleForID:(NSString *)cityID {
    if (cityID.length == 0) return @"";
    for (NSDictionary *option in PPProviderProfileEditorCityOptions()) {
        if ([PPSafeString(option[@"value"]) isEqualToString:cityID]) {
            return PPSafeString(option[@"titleKey"]);
        }
    }
    return @"";
}

- (void)pp_removeCoverAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.coverImageURLs.count) {
        self.didUserModifyCovers = YES;
        [self.coverImageURLs removeObjectAtIndex:index];
        [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
        [self pp_persistMediaChangeWithSuccessToast:kLang(@"ProviderProfileEditor_Saved")];
    }
}

- (void)pp_startListening {
    __weak typeof(self) weakSelf = self;
    self.providerStateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            PPProviderProfileEditorLog([NSString stringWithFormat:@"Provider state error: %@", error.localizedDescription]);
            return;
        }
        [self pp_applyProviderState:state];
    }];

    NSString *uid = [self pp_currentAuthUID];
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (uid.length == 0 || !db) return;
    self.userDocumentListener = [[[db collectionWithPath:@"UsersCol"] documentWithPath:uid]
                                 addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || !snapshot.exists) return;
        NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
        [self pp_applyUserDocument:data];
    }];
}

- (void)pp_applyProviderState:(PPProviderOnboardingState *)state {
    PPProviderProfile *profile = [self pp_primaryProfileFromState:state];
    if (!profile) {
        [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
        return;
    }

    self.providerType = profile.providerType;
    self.providerProfileID = PPSafeString(profile.profileID);

    NSDictionary *form = [profile.form isKindOfClass:NSDictionary.class] ? profile.form : @{};
    NSDictionary *userSummary = [profile.userSummary isKindOfClass:NSDictionary.class] ? profile.userSummary : @{};
    NSDictionary *publicProfile = [profile publicProfile] ?: @{};

    NSString *displayName = PPSafeString(form[@"fullName"]);
    if (displayName.length == 0) displayName = PPSafeString(publicProfile[@"businessTradeName"]);
    if (displayName.length == 0) displayName = PPSafeString(form[@"tradeName"]);
    if (displayName.length == 0) displayName = PPSafeString(form[@"businessName"]);
    if (displayName.length == 0) displayName = PPSafeString(userSummary[@"displayName"]);
    if (displayName.length == 0) displayName = PPSafeString(state.displayName);

    NSString *phone = PPSafeString(form[@"phone"]);
    if (phone.length == 0) phone = PPSafeString(publicProfile[@"contactPhone"]);
    if (phone.length == 0) phone = PPSafeString(userSummary[@"phone"]);
    if (phone.length == 0) phone = PPSafeString(state.phone);

    NSString *city = PPSafeString(form[@"city"]);

    NSArray<NSString *> *imageRefs = PPProviderProfileEditorCleanStringArray(form[@"imageRefs"]);
    if (imageRefs.count == 0) {
        imageRefs = PPProviderProfileEditorCleanStringArray(publicProfile[@"coverImageUrls"]);
    }

    NSString *avatarURL = PPSafeString(userSummary[@"photoURL"]);
    if (avatarURL.length == 0) avatarURL = PPSafeString(publicProfile[@"logoUrl"]);

    self.persistedDisplayName = displayName;
    self.persistedPhone = phone;
    self.persistedCityID = city;
    if (avatarURL.length > 0) {
        self.persistedAvatarURLString = avatarURL;
    }
    if (imageRefs.count > 0 || self.persistedCoverImageURLs.count == 0) {
        [self.persistedCoverImageURLs removeAllObjects];
        [self.persistedCoverImageURLs addObjectsFromArray:imageRefs];
    }

    if (!self.didHydrateProviderProfile) {
        if (displayName.length > 0) self.currentDisplayName = displayName;
        if (phone.length > 0) self.currentPhone = phone;
        if (city.length > 0) self.selectedCityID = city;
        if (!self.didUserModifyAvatar && avatarURL.length > 0) {
            self.currentAvatarURLString = avatarURL;
        }
        self.didHydrateProviderProfile = YES;
        self.didHydrateData = YES;
    }

    if (!self.didUserModifyAvatar && avatarURL.length > 0 && self.currentAvatarURLString.length == 0) {
        self.currentAvatarURLString = avatarURL;
    }
    if (!self.didUserModifyCovers && imageRefs.count > 0) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:imageRefs];
    }

    [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
}

- (PPProviderProfile *)pp_primaryProfileFromState:(PPProviderOnboardingState *)state {
    NSArray<NSNumber *> *priority = @[
        @(PPProviderTypeMarketplace),
        @(PPProviderTypeService),
        @(PPProviderTypePharmacy),
        @(PPProviderTypeVet),
        @(PPProviderTypeDeliveryCompany),
        @(PPProviderTypeDeliverySubscription),
    ];
    for (NSNumber *wrappedType in priority) {
        if (!PPProviderTypeIsEnabledInProApp(wrappedType.integerValue)) continue;
        PPProviderProfile *profile = [state profileForType:wrappedType.integerValue];
        if (profile) return profile;
    }
    return nil;
}

- (void)pp_applyUserDocument:(NSDictionary *)data {
    NSArray<NSString *> *coverURLs = PPProviderProfileEditorCleanStringArray(data[@"coverImageUrls"]);
    NSString *photoURL = PPSafeString(data[@"UserImageUrl"]).length ? PPSafeString(data[@"UserImageUrl"]) : PPSafeString(data[@"photoURL"]);

    if (photoURL.length > 0 && self.persistedAvatarURLString.length == 0) {
        self.persistedAvatarURLString = photoURL;
    }
    if (!self.didUserModifyAvatar && photoURL.length > 0) {
        self.currentAvatarURLString = photoURL;
        self.persistedAvatarURLString = photoURL;
    }

    if (coverURLs.count > 0 && self.persistedCoverImageURLs.count == 0) {
        [self.persistedCoverImageURLs removeAllObjects];
        [self.persistedCoverImageURLs addObjectsFromArray:coverURLs];
    }
    if (!self.didUserModifyCovers && self.coverImageURLs.count == 0 && coverURLs.count > 0) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:coverURLs];
    }

    NSString *displayName = PPSafeString(data[@"displayName"]).length ? PPSafeString(data[@"displayName"]) : PPSafeString(data[@"UserName"]);
    NSString *phone = PPSafeString(data[@"MobileNo"]);
    if (displayName.length > 0 && self.persistedDisplayName.length == 0) {
        self.persistedDisplayName = displayName;
    }
    if (phone.length > 0 && self.persistedPhone.length == 0) {
        self.persistedPhone = phone;
    }
    if (!self.didHydrateData) {
        if (displayName.length > 0 && self.currentDisplayName.length == 0) self.currentDisplayName = displayName;
        if (phone.length > 0 && self.currentPhone.length == 0) self.currentPhone = phone;
        self.didHydrateData = YES;
    }

    [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
}

#pragma mark - City Selection

- (void)pp_changeCityTapped {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPProviderProfileEditorCitySheetViewController *sheet =
    [[PPProviderProfileEditorCitySheetViewController alloc] initWithSelectedCity:self.selectedCityID completion:^(NSString *cityID) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.selectedCityID = PPSafeString(cityID);
        [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Photo Picking & Uploads

- (void)pp_changeAvatarTapped {
    [PPFunc pp_playTapEffect];
    self.pickerMode = PPProviderProfileEditorPickerModeAvatar;
    [self pp_presentPhotoPickerWithSelectionLimit:1];
}

- (void)pp_addCoverTapped {
    [PPFunc pp_playTapEffect];
    NSInteger remaining = MAX(1, 5 - self.coverImageURLs.count);
    self.pickerMode = PPProviderProfileEditorPickerModeCovers;
    [self pp_presentPhotoPickerWithSelectionLimit:remaining];
}

- (void)pp_presentPhotoPickerWithSelectionLimit:(NSInteger)selectionLimit {
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = [PHPickerFilter imagesFilter];
        configuration.selectionLimit = selectionLimit;
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    if (self.pickerMode == PPProviderProfileEditorPickerModeAvatar) {
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
        return;
    }

    self.isUploadingCovers = YES;
    [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_UploadingCovers") subtitle:nil];

    NSMutableArray *orderedSlots = [NSMutableArray arrayWithCapacity:results.count];
    for (NSInteger i = 0; i < results.count; i++) {
        [orderedSlots addObject:[NSNull null]];
    }
    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;

    for (NSInteger index = 0; index < results.count; index++) {
        dispatch_group_enter(group);
        NSItemProvider *provider = results[index].itemProvider;
        [self pp_loadImageFromProvider:provider completion:^(UIImage * _Nullable image) {
            if (!image) {
                if (!firstError) firstError = [NSError errorWithDomain:@"PPProviderProfileEditor" code:-1 userInfo:nil];
                dispatch_group_leave(group);
                return;
            }
            [self pp_uploadCoverImage:image indexOffset:index completion:^(NSString * _Nullable urlString, NSError * _Nullable error) {
                if (urlString.length > 0) {
                    @synchronized (orderedSlots) {
                        orderedSlots[index] = urlString;
                    }
                } else if (error && !firstError) {
                    firstError = error;
                }
                dispatch_group_leave(group);
            }];
        }];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isUploadingCovers = NO;
        [PPHUD dismiss];

        NSMutableArray<NSString *> *uploadedURLs = [NSMutableArray array];
        for (id item in orderedSlots) {
            if ([item isKindOfClass:NSString.class] && ((NSString *)item).length > 0) {
                [uploadedURLs addObject:item];
            }
        }

        if (uploadedURLs.count > 0) {
            strongSelf.didUserModifyCovers = YES;
            [strongSelf.coverImageURLs addObjectsFromArray:uploadedURLs];
            if (strongSelf.coverImageURLs.count > 5) {
                strongSelf.coverImageURLs = [[strongSelf.coverImageURLs subarrayWithRange:NSMakeRange(0, 5)] mutableCopy];
            }
            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
            [strongSelf pp_persistMediaChangeWithSuccessToast:firstError ? nil : kLang(@"ProviderProfileEditor_CoverUploaded")];
        }
        if (firstError) {
            [PPToast toast:kLang(@"ProviderProfileEditor_CoverUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        }
    });
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
    NSString *uid = [self pp_currentAuthUID];
    if (uid.length == 0 || !image) {
        [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    self.isUploadingAvatar = YES;
    [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
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
                [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
                [PPHUD dismiss];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
            });
            return;
        }

        FIRStorage *storage = [PPProSessionCoordinator.shared activeStorage];
        if (!storage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.isUploadingAvatar = NO;
                [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
                [PPHUD dismiss];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
            });
            return;
        }
        NSString *path = [NSString stringWithFormat:@"uploads/users/%@/profile/avatar_%lld.jpg",
                          uid,
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        FIRStorageReference *ref = [[storage reference] child:path];
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

        void (^finishOnMain)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
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
                strongSelf.isUploadingAvatar = NO;
                [PPHUD dismiss];
                if (![[PPProSessionCoordinator.shared activeUID] isEqualToString:uid] ||
                    [PPProSessionCoordinator.shared isSuspendedOrLocked]) {
                    return;
                }
                if (urlString.length == 0 || error) {
                    [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
                    [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
                    return;
                }
                strongSelf.didUserModifyAvatar = YES;
                strongSelf.currentAvatarURLString = urlString;
                [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
                [strongSelf pp_persistMediaChangeWithSuccessToast:kLang(@"ProviderProfileEditor_AvatarUploaded")];
            });
        };

        void (^resolveDownloadURL)(NSError * _Nullable) = ^(NSError * _Nullable fallbackError) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
                NSString *resolved = PPSafeString(URL.absoluteString);
                if (resolved.length > 0) {
                    finishOnMain(resolved, nil);
                    return;
                }
                finishOnMain(nil, error2 ?: fallbackError ?: [NSError errorWithDomain:@"PPProviderProfileEditor" code:-44 userInfo:nil]);
            }];
        };

        [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
            resolveDownloadURL(nil);
        }];
        [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
            NSError *taskError = snapshot.error;
            if (PPProviderProfileEditorStorageErrorLooksFinalized(taskError)) {
                resolveDownloadURL(taskError);
                return;
            }
            finishOnMain(nil, taskError ?: [NSError errorWithDomain:@"PPProviderProfileEditor" code:-45 userInfo:nil]);
        }];
    });
}

- (void)pp_uploadCoverImage:(UIImage *)image
                indexOffset:(NSInteger)indexOffset
                 completion:(void(^)(NSString * _Nullable urlString, NSError * _Nullable error))completion {
    NSString *uid = [self pp_currentAuthUID];
    if (uid.length == 0 || !image) {
        if (completion) completion(nil, [NSError errorWithDomain:@"PPProviderProfileEditor" code:-2 userInfo:nil]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat maxDimension = 1600.0;
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
                if (completion) completion(nil, [NSError errorWithDomain:@"PPProviderProfileEditor" code:-3 userInfo:nil]);
            });
            return;
        }

        FIRStorage *storage = [PPProSessionCoordinator.shared activeStorage];
        if (!storage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, [NSError errorWithDomain:@"PPProviderProfileEditor" code:-4 userInfo:nil]);
            });
            return;
        }
        NSString *path = [NSString stringWithFormat:@"uploads/users/%@/profile/cover_%lld_%ld.jpg",
                          uid,
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000),
                          (long)indexOffset];
        FIRStorageReference *ref = [[storage reference] child:path];
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{@"uploaded_by": uid};
        FIRStorageUploadTask *task = [ref putData:jpegData metadata:metadata];
        __block BOOL didFinish = NO;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.activeCoverUploadTasks addObject:task];
        });

        void (^finishOnMain)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
            @synchronized (ref) {
                if (didFinish) return;
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf.activeCoverUploadTasks removeObject:task];
                }
                if (![[PPProSessionCoordinator.shared activeUID] isEqualToString:uid] ||
                    [PPProSessionCoordinator.shared isSuspendedOrLocked]) {
                    if (completion) completion(nil, [NSError errorWithDomain:@"PPProviderProfileEditor" code:-5 userInfo:nil]);
                    return;
                }
                if (completion) completion(urlString, error);
            });
        };

        void (^resolveDownloadURL)(NSError * _Nullable) = ^(NSError * _Nullable fallbackError) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                NSString *resolved = PPSafeString(URL.absoluteString);
                if (resolved.length > 0) {
                    finishOnMain(resolved, nil);
                } else {
                    finishOnMain(nil, error ?: fallbackError);
                }
            }];
        };

        [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
            resolveDownloadURL(nil);
        }];
        [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
            NSError *taskError = snapshot.error;
            if (PPProviderProfileEditorStorageErrorLooksFinalized(taskError)) {
                resolveDownloadURL(taskError);
                return;
            }
            finishOnMain(nil, taskError);
        }];
    });
}

#pragma mark - Save Operation

- (void)pp_syncLocalEditsFromHost {
    NSString *liveName = [PPSafeString(self.hostingController.currentEditedDisplayName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *livePhone = [PPSafeString(self.hostingController.currentEditedPhone) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *liveCity = PPSafeString(self.hostingController.currentEditedCityID);
    if (liveName.length > 0) self.currentDisplayName = liveName;
    if (livePhone.length > 0) self.currentPhone = livePhone;
    if (liveCity.length > 0) self.selectedCityID = liveCity;
}

- (void)pp_persistAvatarMirrorOnlyWithSuccessToast:(nullable NSString *)successToast {
    NSString *uid = [self pp_currentAuthUID];
    NSString *avatarURL = PPSafeString(self.currentAvatarURLString);
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (uid.length == 0 || avatarURL.length == 0 || !db) return;

    FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
    NSURL *url = [NSURL URLWithString:avatarURL];
    if (authUser && url) {
        FIRUserProfileChangeRequest *req = [authUser profileChangeRequest];
        req.photoURL = url;
        [req commitChangesWithCompletion:nil];
    }

    FIRDocumentReference *userRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
    NSDictionary *patch = @{
        @"UserImageUrl": avatarURL,
        @"photoURL": avatarURL,
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };

    __weak typeof(self) weakSelf = self;
    [userRef setData:patch merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            strongSelf.persistedAvatarURLString = avatarURL;
            strongSelf.didUserModifyAvatar = NO;
            UserModel *user = UsrMgr.currentUser;
            if (user) {
                user.photoURL = avatarURL;
                [UsrMgr p_cacheUser:user];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kPPProviderEditorProfileDidUpdateNotification object:nil];
            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
            if (successToast.length > 0) {
                [PPToast toast:successToast style:PPToastStyleSuccess haptic:YES duration:1.5];
            }
        });
    }];
}

- (void)pp_persistMediaChangeWithSuccessToast:(nullable NSString *)successToast {
    [self pp_syncLocalEditsFromHost];

    if (self.providerType != PPProviderTypeUnspecified) {
        if (self.currentDisplayName.length > 0 && self.currentPhone.length > 0 && self.selectedCityID.length > 0) {
            [self pp_saveViaCallableWithSuccessToast:successToast showHUD:NO];
            return;
        }
        // Keep media dirty in ViewModel so Save button stays enabled once missing required fields are filled.
        NSString *hint = self.currentDisplayName.length == 0
            ? kLang(@"ProfileSettings_NameRequired")
            : (self.currentPhone.length == 0 ? kLang(@"ProviderProfileEditor_PhoneRequired") : kLang(@"ProviderProfileEditor_CityRequired"));
        [PPToast toast:hint style:PPToastStyleWarning haptic:YES duration:2.0];
        return;
    }

    if (self.didUserModifyAvatar && self.currentAvatarURLString.length > 0 && !self.didUserModifyCovers) {
        [self pp_persistAvatarMirrorOnlyWithSuccessToast:successToast];
        return;
    }

    [PPToast toast:kLang(@"ProviderProfileEditor_NoProfile") style:PPToastStyleWarning haptic:YES duration:2.0];
}

- (void)pp_saveWithDisplayName:(NSString *)displayName
                         phone:(NSString *)phone
                        cityID:(NSString *)cityID
                     avatarURL:(NSString *)avatarURL
                     coverURLs:(NSArray<NSString *> *)coverURLs {
    self.currentDisplayName = [PPSafeString(displayName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.currentPhone = [PPSafeString(phone) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.selectedCityID = PPSafeString(cityID);
    if (avatarURL.length > 0) self.currentAvatarURLString = avatarURL;
    if (coverURLs) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:coverURLs];
    }

    if (self.providerType != PPProviderTypeUnspecified) {
        [self pp_saveViaCallableWithSuccessToast:kLang(@"ProviderProfileEditor_Saved") showHUD:YES];
    } else {
        [self pp_saveDirectToUserCollection];
    }
}

- (void)pp_saveViaCallableWithSuccessToast:(nullable NSString *)successToast showHUD:(BOOL)showHUD {
    if (self.currentDisplayName.length == 0) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProfileSettings_NameRequired")];
        return;
    }
    if (self.currentPhone.length == 0) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_PhoneRequired")];
        return;
    }
    if (self.selectedCityID.length == 0) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_CityRequired")];
        return;
    }

    self.isSaving = YES;
    if (showHUD) {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_Saving") subtitle:nil];
    }

    NSString *submittedDisplayName = PPSafeString(self.currentDisplayName);
    NSString *submittedPhone = PPSafeString(self.currentPhone);
    NSString *submittedCity = PPSafeString(self.selectedCityID);
    NSString *submittedAvatar = PPSafeString(self.currentAvatarURLString);
    NSArray<NSString *> *submittedCovers = self.coverImageURLs.copy ?: @[];

    NSDictionary *payload = @{
        @"providerType": PPProviderTypeIdentifier(self.providerType),
        @"displayName": submittedDisplayName,
        @"phone": submittedPhone,
        @"city": submittedCity,
        @"avatarURL": submittedAvatar,
        @"coverImageUrls": submittedCovers,
    };

    FIRFunctions *functions = [PPProSessionCoordinator.shared activeFunctions];
    if (!functions) {
        self.isSaving = NO;
        if (showHUD) {
            [PPHUD dismiss];
        }
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_SessionExpired")];
        return;
    }

    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"updateMyProviderProfile"];
    callable.timeoutInterval = 30.0;

    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        (void)result;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.isSaving = NO;
            if (showHUD) {
                [PPHUD dismiss];
            }
            [strongSelf.hostingController didFinishSaving];

            if (error) {
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }

            strongSelf.persistedDisplayName = submittedDisplayName;
            strongSelf.persistedPhone = submittedPhone;
            strongSelf.persistedCityID = submittedCity;
            if (submittedAvatar.length > 0) {
                strongSelf.persistedAvatarURLString = submittedAvatar;
            }
            [strongSelf.persistedCoverImageURLs removeAllObjects];
            [strongSelf.persistedCoverImageURLs addObjectsFromArray:submittedCovers];
            strongSelf.didUserModifyAvatar = NO;
            strongSelf.didUserModifyCovers = NO;

            FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
            if (authUser) {
                FIRUserProfileChangeRequest *req = [authUser profileChangeRequest];
                req.displayName = submittedDisplayName;
                if (submittedAvatar.length > 0) {
                    NSURL *avatarURLObj = [NSURL URLWithString:submittedAvatar];
                    if (avatarURLObj) {
                        req.photoURL = avatarURLObj;
                    }
                }
                [req commitChangesWithCompletion:nil];
            }

            UserModel *user = UsrMgr.currentUser;
            if (user) {
                user.displayName = submittedDisplayName;
                user.UserName = submittedDisplayName;
                user.MobileNo = submittedPhone;
                if (submittedAvatar.length > 0) {
                    user.photoURL = submittedAvatar;
                }
                [UsrMgr p_cacheUser:user];
            }

            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kPPProviderEditorProfileDidUpdateNotification object:nil];
            if (successToast.length > 0) {
                [PPToast toast:successToast style:PPToastStyleSuccess haptic:YES duration:1.7];
            }
        });
    }];
}

- (void)pp_saveDirectToUserCollection {
    NSString *uid = [self pp_currentAuthUID];
    UserModel *user = UsrMgr.currentUser;
    FIRFirestore *db = [PPProSessionCoordinator.shared activeFirestore];
    if (uid.length == 0 || !user || !db) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_SessionExpired")];
        return;
    }

    self.isSaving = YES;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_Saving") subtitle:nil];

    NSMutableDictionary *patch = [NSMutableDictionary dictionary];
    if (self.currentDisplayName.length > 0) {
        patch[@"displayName"] = self.currentDisplayName;
        patch[@"UserName"] = self.currentDisplayName;
        user.displayName = self.currentDisplayName;
        user.UserName = self.currentDisplayName;
    }
    if (self.currentPhone.length > 0) {
        patch[@"MobileNo"] = self.currentPhone;
        user.MobileNo = self.currentPhone;
    }
    if (self.currentAvatarURLString.length > 0) {
        patch[@"UserImageUrl"] = self.currentAvatarURLString;
        patch[@"photoURL"] = self.currentAvatarURLString;
        user.photoURL = self.currentAvatarURLString;
    }
    patch[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];

    BOOL attemptedProviderOnlyFields =
        ![self.coverImageURLs isEqualToArray:self.persistedCoverImageURLs] ||
        ![self.selectedCityID isEqualToString:self.persistedCityID ?: @""];

    FIRDocumentReference *userRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
    __weak typeof(self) weakSelf = self;
    [userRef setData:patch merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.isSaving = NO;
            [PPHUD dismiss];
            [strongSelf.hostingController didFinishSaving];
            if (error) {
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            strongSelf.persistedDisplayName = strongSelf.currentDisplayName;
            strongSelf.persistedPhone = strongSelf.currentPhone;
            if (strongSelf.currentAvatarURLString.length > 0) {
                strongSelf.persistedAvatarURLString = strongSelf.currentAvatarURLString;
            }
            strongSelf.didUserModifyAvatar = NO;
            [UsrMgr p_cacheUser:user];

            FIRUser *authUser = [PPProSessionCoordinator.shared currentUser];
            if (authUser && strongSelf.currentAvatarURLString.length > 0) {
                FIRUserProfileChangeRequest *req = [authUser profileChangeRequest];
                req.displayName = strongSelf.currentDisplayName;
                req.photoURL = [NSURL URLWithString:strongSelf.currentAvatarURLString];
                [req commitChangesWithCompletion:nil];
            }

            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kPPProviderEditorProfileDidUpdateNotification object:nil];
            if (attemptedProviderOnlyFields) {
                [PPToast toast:kLang(@"ProviderProfileEditor_NoProfile") style:PPToastStyleWarning haptic:YES duration:2.0];
            } else {
                [PPToast toast:kLang(@"ProfileUpdated") style:PPToastStyleSuccess haptic:YES duration:1.8];
            }
        });
    }];
}

@end
