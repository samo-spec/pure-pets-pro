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

@interface PPProviderProfileEditorViewController () <PHPickerViewControllerDelegate, TOCropViewControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) PPProviderProfileEditorHostController *hostingController;
@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;
@property (nonatomic, copy) NSString *currentDisplayName;
@property (nonatomic, copy) NSString *currentPhone;
@property (nonatomic, copy) NSString *selectedCityID;
@property (nonatomic, copy) NSString *currentAvatarURLString;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *providerProfileID;

@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isUploadingAvatar;
@property (nonatomic, assign) BOOL isUploadingCovers;
@property (nonatomic, assign) BOOL didHydrateData;
@property (nonatomic, assign) PPProviderProfileEditorPickerMode pickerMode;

@property (nonatomic, strong) id<FIRListenerRegistration> providerStateListener;
@property (nonatomic, strong) id<FIRListenerRegistration> userDocumentListener;
@end

@implementation PPProviderProfileEditorViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.coverImageURLs = [NSMutableArray array];
    self.currentDisplayName = @"";
    self.currentPhone = @"";
    self.selectedCityID = @"";
    self.currentAvatarURLString = @"";
    self.providerType = PPProviderTypeUnspecified;
    self.providerProfileID = @"";

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

- (void)dealloc {
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
    return [FIRAuth auth].currentUser.uid ?: @"";
}

- (void)pp_bindCurrentUserFallbacks {
    UserModel *user = UsrMgr.currentUser;
    if (!user) return;
    self.currentDisplayName = PPSafeString(user.displayName.length ? user.displayName : user.UserName);
    self.currentPhone = PPSafeString(user.MobileNo);
    NSString *photoURL = PPSafeString(user.photoURL.length ? user.photoURL : user.UserImageUrl.absoluteString);
    self.currentAvatarURLString = photoURL;
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
                                                             statusTitle:hasActiveProfile ? kLang(@"ProviderStatusActive") : @""];
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
        [self.coverImageURLs removeObjectAtIndex:index];
        [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
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
    if (uid.length == 0) return;
    self.userDocumentListener = [[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid]
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
    NSString *displayName = PPSafeString(form[@"fullName"]).length ? PPSafeString(form[@"fullName"]) : state.displayName;
    NSString *phone = PPSafeString(form[@"phone"]).length ? PPSafeString(form[@"phone"]) : state.phone;
    NSString *city = PPSafeString(form[@"city"]);
    NSArray<NSString *> *imageRefs = [form[@"imageRefs"] isKindOfClass:NSArray.class] ? form[@"imageRefs"] : @[];

    if (!self.didHydrateData) {
        self.currentDisplayName = displayName;
        self.currentPhone = phone;
        self.selectedCityID = city;
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:imageRefs];
        self.didHydrateData = YES;
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
    NSArray *coverURLs = [data[@"coverImageUrls"] isKindOfClass:NSArray.class] ? data[@"coverImageUrls"] : @[];
    NSString *photoURL = PPSafeString(data[@"UserImageUrl"]).length ? PPSafeString(data[@"UserImageUrl"]) : PPSafeString(data[@"photoURL"]);
    if (!self.didHydrateData && coverURLs.count > 0) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:coverURLs];
    }
    if (photoURL.length > 0 && self.currentAvatarURLString.length == 0) {
        self.currentAvatarURLString = photoURL;
    }
    if (!self.didHydrateData) {
        NSString *displayName = PPSafeString(data[@"displayName"]).length ? PPSafeString(data[@"displayName"]) : PPSafeString(data[@"UserName"]);
        NSString *phone = PPSafeString(data[@"MobileNo"]);
        if (displayName.length > 0) self.currentDisplayName = displayName;
        if (phone.length > 0) self.currentPhone = phone;
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
        [self pp_loadImageFromProvider:provider completion:^(UIImage * _Nullable image) {
            if (!image) {
                [PPToast toast:kLang(@"ProviderProfileEditor_ImageLoadFailed") style:PPToastStyleError haptic:YES duration:1.4];
                return;
            }
            [PPFunc pp_presentCircularCropperWithImage:image fromController:self];
        }];
        return;
    }

    self.isUploadingCovers = YES;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_UploadingCovers") subtitle:nil];

    NSMutableArray<NSString *> *uploadedURLs = [NSMutableArray array];
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
            [self pp_uploadCoverImage:image completion:^(NSString * _Nullable urlString, NSError * _Nullable error) {
                if (urlString.length > 0) {
                    @synchronized (uploadedURLs) {
                        [uploadedURLs addObject:urlString];
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
        if (uploadedURLs.count > 0) {
            [strongSelf.coverImageURLs addObjectsFromArray:uploadedURLs];
            if (strongSelf.coverImageURLs.count > 5) {
                strongSelf.coverImageURLs = [[strongSelf.coverImageURLs subarrayWithRange:NSMakeRange(0, 5)] mutableCopy];
            }
            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
        }
        if (firstError) {
            [PPToast toast:kLang(@"ProviderProfileEditor_CoverUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        } else if (uploadedURLs.count > 0) {
            [PPToast toast:kLang(@"ProviderProfileEditor_CoverUploaded") style:PPToastStyleSuccess haptic:YES duration:1.4];
        }
    });
}

- (void)pp_loadImageFromProvider:(NSItemProvider *)provider completion:(void(^)(UIImage * _Nullable image))completion {
    [provider loadDataRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
        UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    }];
}

- (void)cropViewController:(TOCropViewController *)cropViewController didCropToCircularImage:(UIImage *)image withRect:(CGRect)cropRect angle:(NSInteger)angle {
    [cropViewController dismissViewControllerAnimated:YES completion:^{
        [self pp_uploadAvatarImage:image];
    }];
}

- (void)pp_uploadAvatarImage:(UIImage *)image {
    NSString *uid = [self pp_currentAuthUID];
    if (uid.length == 0 || !image) {
        [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    self.isUploadingAvatar = YES;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_UploadingAvatar") subtitle:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat maxDimension = 900.0;
        UIImage *scaledImage = image;
        if (image.size.width > maxDimension || image.size.height > maxDimension) {
            CGFloat ratio = maxDimension / MAX(image.size.width, image.size.height);
            CGSize target = CGSizeMake(image.size.width * ratio, image.size.height * ratio);
            UIGraphicsBeginImageContextWithOptions(target, NO, 1.0);
            [image drawInRect:CGRectMake(0.0, 0.0, target.width, target.height)];
            scaledImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }

        NSData *jpegData = UIImageJPEGRepresentation(scaledImage, 0.82);
        if (jpegData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUploadingAvatar = NO;
                [PPHUD dismiss];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
            });
            return;
        }

        NSString *path = [NSString stringWithFormat:@"uploads/users/%@/profile/avatar_%lld.jpg",
                          uid,
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{@"uploaded_by": uid};
        FIRStorageUploadTask *task = [ref putData:jpegData metadata:metadata];
        __block BOOL didFinish = NO;

        void (^finishOnMain)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
            @synchronized (ref) {
                if (didFinish) return;
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUploadingAvatar = NO;
                [PPHUD dismiss];
                if (urlString.length == 0 || error) {
                    [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
                    return;
                }
                self.currentAvatarURLString = urlString;
                [self.hostingController updateSnapshot:[self pp_currentSnapshot]];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploaded") style:PPToastStyleSuccess haptic:YES duration:1.4];
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

- (void)pp_uploadCoverImage:(UIImage *)image completion:(void(^)(NSString * _Nullable urlString, NSError * _Nullable error))completion {
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
            scaledImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }

        NSData *jpegData = UIImageJPEGRepresentation(scaledImage, 0.82);
        if (jpegData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, [NSError errorWithDomain:@"PPProviderProfileEditor" code:-3 userInfo:nil]);
            });
            return;
        }

        NSString *path = [NSString stringWithFormat:@"uploads/users/%@/profile/cover_%lld.jpg",
                          uid,
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{@"uploaded_by": uid};
        FIRStorageUploadTask *task = [ref putData:jpegData metadata:metadata];
        __block BOOL didFinish = NO;

        void (^finishOnMain)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
            @synchronized (ref) {
                if (didFinish) return;
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(urlString, error);
            });
        };

        [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                NSString *resolved = PPSafeString(URL.absoluteString);
                if (resolved.length > 0) {
                    finishOnMain(resolved, nil);
                } else {
                    finishOnMain(nil, error);
                }
            }];
        }];
        [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
            finishOnMain(nil, snapshot.error);
        }];
    });
}

#pragma mark - Save Operation

- (void)pp_saveWithDisplayName:(NSString *)displayName
                         phone:(NSString *)phone
                        cityID:(NSString *)cityID
                     avatarURL:(NSString *)avatarURL
                     coverURLs:(NSArray<NSString *> *)coverURLs {
    self.currentDisplayName = PPSafeString(displayName);
    self.currentPhone = PPSafeString(phone);
    self.selectedCityID = PPSafeString(cityID);
    if (avatarURL.length > 0) self.currentAvatarURLString = avatarURL;
    if (coverURLs) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:coverURLs];
    }

    if (self.providerType != PPProviderTypeUnspecified) {
        [self pp_saveViaCallable];
    } else {
        [self pp_saveDirectToUserCollection];
    }
}

- (void)pp_saveViaCallable {
    if (self.currentDisplayName.length == 0) {
        [self.hostingController didFinishSaving];
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProfileSettings_NameRequired")];
        return;
    }

    self.isSaving = YES;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_Saving") subtitle:nil];

    NSDictionary *payload = @{
        @"providerType": PPProviderTypeIdentifier(self.providerType),
        @"displayName": PPSafeString(self.currentDisplayName),
        @"phone": PPSafeString(self.currentPhone),
        @"city": PPSafeString(self.selectedCityID),
        @"avatarURL": PPSafeString(self.currentAvatarURLString),
        @"coverImageUrls": self.coverImageURLs.copy ?: @[],
    };

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"updateMyProviderProfile"];
    callable.timeoutInterval = 30.0;

    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
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

            UserModel *user = UsrMgr.currentUser;
            if (user) {
                user.displayName = strongSelf.currentDisplayName;
                user.UserName = strongSelf.currentDisplayName;
                user.MobileNo = strongSelf.currentPhone;
                if (strongSelf.currentAvatarURLString.length > 0) {
                    user.photoURL = strongSelf.currentAvatarURLString;
                }
                [UsrMgr p_cacheUser:user];
            }

            [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
            [PPToast toast:kLang(@"ProviderProfileEditor_Saved") style:PPToastStyleSuccess haptic:YES duration:1.7];
        });
    }];
}

- (void)pp_saveDirectToUserCollection {
    NSString *uid = [self pp_currentAuthUID];
    UserModel *user = UsrMgr.currentUser;
    if (uid.length == 0 || !user) {
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
    if (self.selectedCityID.length > 0) {
        patch[@"city"] = self.selectedCityID;
    }
    if (self.currentAvatarURLString.length > 0) {
        patch[@"UserImageUrl"] = self.currentAvatarURLString;
        patch[@"photoURL"] = self.currentAvatarURLString;
        user.photoURL = self.currentAvatarURLString;
    }
    patch[@"coverImageUrls"] = self.coverImageURLs.copy ?: @[];
    patch[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];

    [UsrMgr p_cacheUser:user];

    FIRDocumentReference *userRef = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid];
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
            } else {
                [user SYNC:nil];
                [strongSelf.hostingController updateSnapshot:[strongSelf pp_currentSnapshot]];
                [PPToast toast:kLang(@"ProfileUpdated") style:PPToastStyleSuccess haptic:YES duration:1.8];
            }
        });
    }];
}

@end
