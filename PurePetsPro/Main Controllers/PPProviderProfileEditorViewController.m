#import "PPProviderProfileEditorViewController.h"

#import <PhotosUI/PhotosUI.h>
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

typedef NS_ENUM(NSInteger, PPProviderProfileEditorPickerMode) {
    PPProviderProfileEditorPickerModeNone = 0,
    PPProviderProfileEditorPickerModeAvatar = 1,
    PPProviderProfileEditorPickerModeCovers = 2,
};

static UIColor *PPProviderProfileEditorAccentColor(void) {
    return AppPrimaryClr;
}

static UIColor *PPProviderProfileEditorCanvasColor(void) {
    return AppPageColr;
}

static UIColor *PPProviderProfileEditorSurfaceColor(void) {
    return AppForgroundColr;
}

static UIColor *PPProviderProfileEditorInnerSurfaceColor(void) {
    return [UIColor ppSurface];
}

static UIColor *PPProviderProfileEditorBorderColor(void) {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72];
}

static UIColor *PPProviderProfileEditorPrimaryTextColor(void) {
    return PrimaryTextClr;
}

static UIColor *PPProviderProfileEditorSecondaryTextColor(void) {
    return SeconderyTextClr;
}

static UIColor *PPProviderProfileEditorHeroFallbackColor(void) {
    return [PPProviderProfileEditorAccentColor() colorWithAlphaComponent:0.10];
}

static UIColor *PPProviderProfileEditorHeroOverlayColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor blackColor] colorWithAlphaComponent:0.28]
            : [[UIColor blackColor] colorWithAlphaComponent:0.18];
    }];
}

static UIColor *PPProviderProfileEditorHeroPlateColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.12]
            : [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    }];
}

static UIColor *PPProviderProfileEditorHeroPlateBorderColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.18]
            : [[UIColor whiteColor] colorWithAlphaComponent:0.34];
    }];
}

static UIColor *PPProviderProfileEditorHeroAvatarFillColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.16]
            : [[UIColor whiteColor] colorWithAlphaComponent:0.28];
    }];
}

static BOOL PPProviderProfileEditorStorageErrorLooksFinalized(NSError *error) {
    if (!error) {
        return NO;
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *localizedDescription = PPSafeString(error.localizedDescription);
    if (localizedDescription.length > 0) {
        [parts addObject:localizedDescription];
    }
    NSString *localizedFailureReason = PPSafeString(error.localizedFailureReason);
    if (localizedFailureReason.length > 0) {
        [parts addObject:localizedFailureReason];
    }
    NSData *responseData = [error.userInfo[@"data"] isKindOfClass:NSData.class] ? error.userInfo[@"data"] : nil;
    if (responseData.length > 0) {
        NSString *responseBody = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if (responseBody.length > 0) {
            [parts addObject:responseBody];
        }
    }

    NSString *combined = [[parts componentsJoinedByString:@" "] lowercaseString];
    return [combined containsString:@"already been finalized"];
}

static BOOL PPProviderProfileEditorErrorContainsText(NSError *error, NSString *needle) {
    if (!error || needle.length == 0) {
        return NO;
    }
    NSString *lowerNeedle = needle.lowercaseString;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *value in @[
        PPSafeString(error.localizedDescription),
        PPSafeString(error.localizedFailureReason),
        PPSafeString(error.userInfo[@"code"]),
        PPSafeString(error.userInfo[@"details"]),
        PPSafeString(error.userInfo[NSLocalizedDescriptionKey])
    ]) {
        if (value.length > 0) {
            [parts addObject:value.lowercaseString];
        }
    }
    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:NSError.class] && PPProviderProfileEditorErrorContainsText((NSError *)value, needle)) {
            return YES;
        }
        if ([value isKindOfClass:NSString.class] && [[(NSString *)value lowercaseString] containsString:lowerNeedle]) {
            return YES;
        }
    }
    return [[parts componentsJoinedByString:@" "] containsString:lowerNeedle];
}

static BOOL PPProviderProfileEditorErrorMatchesFunctionsCode(NSError *error, FIRFunctionsErrorCode code) {
    if (!error) {
        return NO;
    }
    if ([error.domain isEqualToString:@"FirebaseFunctions"] && error.code == code) {
        return YES;
    }
    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:NSError.class] && PPProviderProfileEditorErrorMatchesFunctionsCode((NSError *)value, code)) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPProviderProfileEditorFunctionErrorIsUnauthenticated(NSError *error) {
    return PPProviderProfileEditorErrorMatchesFunctionsCode(error, FIRFunctionsErrorCodeUnauthenticated) ||
           PPProviderProfileEditorErrorContainsText(error, @"unauthenticated");
}

static BOOL PPProviderProfileEditorFunctionErrorIsPermissionDenied(NSError *error) {
    return PPProviderProfileEditorErrorMatchesFunctionsCode(error, FIRFunctionsErrorCodePermissionDenied) ||
           PPProviderProfileEditorErrorContainsText(error, @"permission-denied");
}

static BOOL PPProviderProfileEditorFunctionErrorIsNotFound(NSError *error) {
    return PPProviderProfileEditorErrorMatchesFunctionsCode(error, FIRFunctionsErrorCodeNotFound) ||
           PPProviderProfileEditorErrorContainsText(error, @"not-found");
}

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

static NSString *PPProviderProfileEditorLocalizedCityTitle(NSString *cityID) {
    NSDictionary *option = PPProviderProfileEditorCityOptionForID(cityID);
    NSString *titleKey = PPSafeString(option[@"titleKey"]);
    return titleKey.length > 0 ? kLang(titleKey) : @"";
}

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
    self.view.backgroundColor = AppBackgroundClr;
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
    titleLabel.font = [Styling fontBold:22.0];
    titleLabel.textColor = PPProviderProfileEditorPrimaryTextColor();
    titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    titleLabel.text = kLang(@"ProviderProfileEditor_CitySheetTitle");
    [self.view addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:14.0];
    subtitleLabel.textColor = PPProviderProfileEditorSecondaryTextColor();
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
    _tableView.rowHeight = 60.0;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"city";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    NSDictionary *option = _options[indexPath.row];
    NSString *cityID = PPSafeString(option[@"value"]);
    NSString *titleKey = PPSafeString(option[@"titleKey"]);
    cell.textLabel.text = titleKey.length > 0 ? kLang(titleKey) : cityID;
    cell.textLabel.font = [Styling fontMedium:16.0];
    cell.textLabel.textColor = PPProviderProfileEditorPrimaryTextColor();
    cell.detailTextLabel.text = [cityID isEqualToString:_selectedCity] ? kLang(@"ProviderProfileEditor_Selected") : @"";
    cell.detailTextLabel.textColor = AppPrimaryClr;
    cell.backgroundColor = UIColor.clearColor;
    cell.accessoryType = [cityID isEqualToString:_selectedCity] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *option = _options[indexPath.row];
    NSString *cityID = PPSafeString(option[@"value"]);
    _selectedCity = cityID;
    [tableView reloadData];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self->_completion) self->_completion(cityID);
    }];
}

@end

@interface PPProviderProfileEditorCoverCell : UICollectionViewCell

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) UIButton *removeButton;

@end

@implementation PPProviderProfileEditorCoverCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = PPProviderProfileEditorSurfaceColor();
        self.contentView.layer.cornerRadius = 18.0;
        if (@available(iOS 13.0, *)) {
            self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        self.contentView.layer.masksToBounds = YES;
        self.contentView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.contentView.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;

        _imageView = [[UIImageView alloc] init];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.backgroundColor = [PPProviderProfileEditorAccentColor() colorWithAlphaComponent:0.08];
        _imageView.clipsToBounds = YES;
        [self.contentView addSubview:_imageView];

        _removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _removeButton.translatesAutoresizingMaskIntoConstraints = NO;
        _removeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
        _removeButton.tintColor = UIColor.whiteColor;
        _removeButton.layer.cornerRadius = 14.0;
        if (@available(iOS 13.0, *)) {
            [_removeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
        } else {
            [_removeButton setTitle:@"×" forState:UIControlStateNormal];
        }
        [self.contentView addSubview:_removeButton];

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_removeButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [_removeButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10.0],
            [_removeButton.widthAnchor constraintEqualToConstant:28.0],
            [_removeButton.heightAnchor constraintEqualToConstant:28.0],
        ]];
    }
    return self;
}

@end

@interface PPProviderProfileEditorViewController () <UITextFieldDelegate, PHPickerViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, TOCropViewControllerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *footerBar;
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIImageView *heroCoverImageView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIButton *avatarButton;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UILabel *heroMetaLabel;
@property (nonatomic, strong) UITextField *displayNameField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UIButton *cityButton;
@property (nonatomic, strong) UICollectionView *coverCollectionView;
@property (nonatomic, strong) UIButton *addCoverButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSMutableArray<UIView *> *elevatedSurfaceViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *innerSurfaceViews;

@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;
@property (nonatomic, copy) NSString *currentAvatarURLString;
@property (nonatomic, copy) NSString *selectedCityID;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *providerProfileID;
@property (nonatomic, assign) PPProviderProfileEditorPickerMode pickerMode;

@property (nonatomic, copy) NSString *originalDisplayName;
@property (nonatomic, copy) NSString *originalPhone;
@property (nonatomic, copy) NSString *originalCityID;
@property (nonatomic, copy) NSString *originalAvatarURLString;
@property (nonatomic, copy) NSArray<NSString *> *originalCoverImageURLs;

@property (nonatomic, assign) BOOL didHydrateData;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isUploadingAvatar;
@property (nonatomic, assign) BOOL isUploadingCovers;
@property (nonatomic, assign) BOOL hasUploadFailure;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;

@property (nonatomic, strong, nullable) id<FIRListenerRegistration> providerStateListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> userDocumentListener;

@end

@implementation PPProviderProfileEditorViewController

- (void)dealloc {
    [self.providerStateListener remove];
    [self.userDocumentListener remove];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"ProviderProfileEditor_Title") showBack:YES];

    self.elevatedSurfaceViews = [NSMutableArray array];
    self.innerSurfaceViews = [NSMutableArray array];
    self.coverImageURLs = [NSMutableArray array];
    self.originalCoverImageURLs = @[];
    self.originalDisplayName = @"";
    self.originalPhone = @"";
    self.originalCityID = @"";
    self.originalAvatarURLString = @"";
    self.selectedCityID = @"";
    self.currentAvatarURLString = @"";
    self.providerType = PPProviderTypeUnspecified;
    self.providerProfileID = @"";

    [self pp_buildInterface];
    [self pp_applyStaticColors];
    [self pp_bindCurrentUserFallbacks];
    [self pp_startListening];
    [self pp_refreshPreview];
    [self pp_updateSaveState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didRunEntranceAnimation) {
        self.didRunEntranceAnimation = YES;
        [self pp_runEntranceAnimation];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyStaticColors];
        }
    }
}

#pragma mark - UI

- (void)pp_buildInterface {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:contentView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18.0;
    [contentView addSubview:self.contentStack];

    self.footerBar = [[UIView alloc] init];
    self.footerBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerBar.backgroundColor = [PPProviderProfileEditorSurfaceColor() colorWithAlphaComponent:0.98];
    self.footerBar.layer.shadowColor = (AppShadowColor).CGColor;
    self.footerBar.layer.shadowOpacity = 0.06;
    self.footerBar.layer.shadowRadius = 18.0;
    self.footerBar.layer.shadowOffset = CGSizeMake(0.0, -6.0);
    self.footerBar.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.view addSubview:self.footerBar];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [Styling fontRegular:12.0];
    self.statusLabel.textColor = PPProviderProfileEditorSecondaryTextColor();
    self.statusLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = kLang(@"ProviderProfileEditor_SaveHint");
    [self.footerBar addSubview:self.statusLabel];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.backgroundColor = PPProviderProfileEditorAccentColor();
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [Styling fontBold:17.0];
    [self.saveButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        self.saveButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.saveButton addTarget:self action:@selector(pp_saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.footerBar addSubview:self.saveButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.footerBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.footerBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.footerBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.footerBar.topAnchor],

        [contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.footerBar.topAnchor constant:14.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.footerBar.leadingAnchor constant:18.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.footerBar.trailingAnchor constant:-18.0],

        [self.saveButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10.0],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.footerBar.leadingAnchor constant:18.0],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.footerBar.trailingAnchor constant:-18.0],
        [self.saveButton.heightAnchor constraintEqualToConstant:56.0],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:self.footerBar.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
    ]];

    [self.contentStack addArrangedSubview:[self pp_makeHeroCard]];
    [self.contentStack addArrangedSubview:[self pp_makeSectionWithTitle:kLang(@"ProviderProfileEditor_IdentitySection")
                                                               subtitle:kLang(@"ProviderProfileEditor_IdentitySubtitle")
                                                                   body:[self pp_makeIdentityBody]]];
    [self.contentStack addArrangedSubview:[self pp_makeSectionWithTitle:kLang(@"ProviderProfileEditor_LocationSection")
                                                               subtitle:kLang(@"ProviderProfileEditor_LocationSubtitle")
                                                                   body:[self pp_makeLocationBody]]];
    [self.contentStack addArrangedSubview:[self pp_makeSectionWithTitle:kLang(@"ProviderProfileEditor_MediaSection")
                                                               subtitle:kLang(@"ProviderProfileEditor_MediaSubtitle")
                                                                   body:[self pp_makeMediaBody]]];
}

- (UIView *)pp_makeHeroCard {
    self.heroCard = [[PPHero alloc] init];
    self.heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCard.layer.cornerRadius = 28.0;

    self.heroCoverImageView = [[UIImageView alloc] init];
    self.heroCoverImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCoverImageView.backgroundColor = PPProviderProfileEditorHeroFallbackColor();
    self.heroCoverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroCoverImageView.clipsToBounds = YES;
    [self.heroCard addSubview:self.heroCoverImageView];

    self.avatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarButton.backgroundColor = PPProviderProfileEditorHeroPlateColor();
    self.avatarButton.layer.cornerRadius = 42.0;
    self.avatarButton.layer.borderWidth = 2.0;
    self.avatarButton.layer.borderColor = PPProviderProfileEditorHeroPlateBorderColor().CGColor;
    self.avatarButton.clipsToBounds = YES;
    [self.avatarButton addTarget:self action:@selector(pp_changeAvatarTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.heroCard addSubview:self.avatarButton];

    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.backgroundColor = PPProviderProfileEditorHeroAvatarFillColor();
    [self.avatarButton addSubview:self.avatarImageView];

    UILabel *avatarHint = [[UILabel alloc] init];
    avatarHint.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHint.text = kLang(@"ProviderProfileEditor_ChangeAvatar");
    avatarHint.font = [Styling fontMedium:11.0];
    avatarHint.textColor = UIColor.whiteColor;
    avatarHint.textAlignment = NSTextAlignmentCenter;
    [self.avatarButton addSubview:avatarHint];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [Styling fontBold:24.0];
    self.heroTitleLabel.textColor = UIColor.whiteColor;
    self.heroTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroTitleLabel.text = [UsrMgr.currentUser PPBestDisplayName] ?: @"";
    [self.heroCard addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [Styling fontRegular:14.0];
    self.heroSubtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    self.heroSubtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.text = kLang(@"ProviderProfileEditor_HeroSubtitle");
    [self.heroCard addSubview:self.heroSubtitleLabel];

    self.heroMetaLabel = [[UILabel alloc] init];
    self.heroMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroMetaLabel.font = [Styling fontMedium:13.0];
    self.heroMetaLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.90];
    self.heroMetaLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroMetaLabel.text = @"";
    [self.heroCard addSubview:self.heroMetaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCard.heightAnchor constraintEqualToConstant:268.0],

        [self.heroCoverImageView.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor],
        [self.heroCoverImageView.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [self.heroCoverImageView.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [self.heroCoverImageView.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor],

        [self.avatarButton.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:22.0],
        [self.avatarButton.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:20.0],
        [self.avatarButton.widthAnchor constraintEqualToConstant:84.0],
        [self.avatarButton.heightAnchor constraintEqualToConstant:84.0],

        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.avatarButton.topAnchor],
        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.avatarButton.leadingAnchor],
        [self.avatarImageView.trailingAnchor constraintEqualToAnchor:self.avatarButton.trailingAnchor],
        [self.avatarImageView.bottomAnchor constraintEqualToAnchor:self.avatarButton.bottomAnchor],

        [avatarHint.centerXAnchor constraintEqualToAnchor:self.avatarButton.centerXAnchor],
        [avatarHint.bottomAnchor constraintEqualToAnchor:self.avatarButton.bottomAnchor constant:-8.0],

        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:20.0],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-20.0],
        [self.heroTitleLabel.bottomAnchor constraintEqualToAnchor:self.heroSubtitleLabel.topAnchor constant:-10.0],

        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],
        [self.heroSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroMetaLabel.topAnchor constant:-8.0],

        [self.heroMetaLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroMetaLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],
        [self.heroMetaLabel.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-20.0],
    ]];

    return self.heroCard;
}

- (UIView *)pp_makeSectionWithTitle:(NSString *)title subtitle:(NSString *)subtitle body:(UIView *)body {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPProviderProfileEditorSurfaceColor();
    container.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }
    container.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    container.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    [self.elevatedSurfaceViews addObject:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:18.0];
    titleLabel.textColor = PPProviderProfileEditorPrimaryTextColor();
    titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    titleLabel.text = title;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:13.0];
    subtitleLabel.textColor = PPProviderProfileEditorSecondaryTextColor();
    subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = subtitle;
    [container addSubview:subtitleLabel];

    body.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:body];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [body.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [body.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [body.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [body.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16.0],
    ]];

    return container;
}

- (UIView *)pp_makeIdentityBody {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;

    self.displayNameField = [self pp_textFieldWithPlaceholder:kLang(@"ProviderProfileEditor_DisplayNamePlaceholder")];
    self.phoneField = [self pp_textFieldWithPlaceholder:kLang(@"ProviderProfileEditor_PhonePlaceholder")];
    self.phoneField.keyboardType = UIKeyboardTypePhonePad;

    [stack addArrangedSubview:[self pp_wrappedInputWithTitle:kLang(@"ProviderProfileEditor_DisplayNameTitle") field:self.displayNameField]];
    [stack addArrangedSubview:[self pp_wrappedInputWithTitle:kLang(@"ProviderProfileEditor_PhoneTitle") field:self.phoneField]];
    return stack;
}

- (UIView *)pp_makeLocationBody {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = PPProviderProfileEditorInnerSurfaceColor();
    row.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        row.layer.cornerCurve = kCACornerCurveContinuous;
    }
    row.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    row.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    [self.innerSurfaceViews addObject:row];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"ProviderProfileEditor_CityTitle");
    titleLabel.font = [Styling fontMedium:16.0];
    titleLabel.textColor = PPProviderProfileEditorPrimaryTextColor();
    [row addSubview:titleLabel];

    self.cityButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cityButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cityButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    self.cityButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self.cityButton setTitleColor:PPProviderProfileEditorSecondaryTextColor() forState:UIControlStateNormal];
    self.cityButton.tintColor = PPProviderProfileEditorAccentColor();
    self.cityButton.titleLabel.font = [Styling fontMedium:15.0];
    [self.cityButton addTarget:self action:@selector(pp_changeCityTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.0, *)) {
        [self.cityButton setImage:[UIImage systemImageNamed:@"chevron.down"] forState:UIControlStateNormal];
    }
    [row addSubview:self.cityButton];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:60.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16.0],
        [self.cityButton.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.cityButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.trailingAnchor constant:12.0],
        [self.cityButton.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14.0],
    ]];
    return row;
}

- (UIView *)pp_makeMediaBody {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;

    UILabel *coversTitle = [[UILabel alloc] init];
    coversTitle.text = kLang(@"ProviderProfileEditor_CoversTitle");
    coversTitle.font = [Styling fontMedium:16.0];
    coversTitle.textColor = PPProviderProfileEditorPrimaryTextColor();
    [stack addArrangedSubview:coversTitle];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12.0;
    layout.itemSize = CGSizeMake(136.0, 96.0);
    self.coverCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.coverCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.coverCollectionView.backgroundColor = UIColor.clearColor;
    self.coverCollectionView.showsHorizontalScrollIndicator = NO;
    self.coverCollectionView.dataSource = self;
    self.coverCollectionView.delegate = self;
    [self.coverCollectionView registerClass:PPProviderProfileEditorCoverCell.class forCellWithReuseIdentifier:@"cover"];
    [stack addArrangedSubview:self.coverCollectionView];
    [self.coverCollectionView.heightAnchor constraintEqualToConstant:96.0].active = YES;

    self.addCoverButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addCoverButton.backgroundColor = PPProviderProfileEditorInnerSurfaceColor();
    self.addCoverButton.layer.cornerRadius = 18.0;
    self.addCoverButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.addCoverButton.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        self.addCoverButton.layer.cornerCurve = kCACornerCurveContinuous;
        [self.addCoverButton setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    }
    self.addCoverButton.tintColor = PPProviderProfileEditorAccentColor();
    [self.addCoverButton setTitle:[NSString stringWithFormat:@"  %@", kLang(@"ProviderProfileEditor_AddCover")] forState:UIControlStateNormal];
    self.addCoverButton.titleLabel.font = [Styling fontMedium:15.0];
    [self.addCoverButton setTitleColor:PPProviderProfileEditorPrimaryTextColor() forState:UIControlStateNormal];
    [self.addCoverButton addTarget:self action:@selector(pp_addCoverTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.innerSurfaceViews addObject:self.addCoverButton];
    [stack addArrangedSubview:self.addCoverButton];
    [self.addCoverButton.heightAnchor constraintEqualToConstant:52.0].active = YES;

    return stack;
}

- (UIView *)pp_wrappedInputWithTitle:(NSString *)title field:(UITextField *)field {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8.0;

    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [Styling fontMedium:15.0];
    label.textColor = PPProviderProfileEditorPrimaryTextColor();
    [stack addArrangedSubview:label];

    UIView *container = [[UIView alloc] init];
    container.backgroundColor = PPProviderProfileEditorInnerSurfaceColor();
    container.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }
    container.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    container.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    [self.innerSurfaceViews addObject:container];
    [stack addArrangedSubview:container];
    [container.heightAnchor constraintEqualToConstant:56.0].active = YES;

    [container addSubview:field];
    [NSLayoutConstraint activateConstraints:@[
        [field.topAnchor constraintEqualToAnchor:container.topAnchor],
        [field.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [field.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [field.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return stack;
}

- (UITextField *)pp_textFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.textColor = PPProviderProfileEditorPrimaryTextColor();
    field.tintColor = PPProviderProfileEditorAccentColor();
    field.font = [Styling fontMedium:16.0];
    field.textAlignment = [Language alignmentForCurrentLanguage];
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                  attributes:@{
        NSForegroundColorAttributeName: [PPProviderProfileEditorSecondaryTextColor() colorWithAlphaComponent:0.82]
    }];
    field.delegate = self;
    [field addTarget:self action:@selector(pp_textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    return field;
}

#pragma mark - Data

- (void)pp_bindCurrentUserFallbacks {
    if (![self pp_cachedUserMatchesCurrentAuthSession]) {
        return;
    }
    UserModel *user = UsrMgr.currentUser;
    self.displayNameField.text = PPSafeString(user.displayName.length ? user.displayName : user.UserName);
    self.phoneField.text = PPSafeString(user.MobileNo);
    NSString *photoURL = PPSafeString(user.photoURL.length ? user.photoURL : user.UserImageUrl.absoluteString);
    self.currentAvatarURLString = photoURL;
    self.originalAvatarURLString = photoURL;
}

- (void)pp_startListening {
    __weak typeof(self) weakSelf = self;
    self.providerStateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            self.statusLabel.text = error.localizedDescription ?: kLang(@"ProviderProfileEditor_LoadFailed");
            return;
        }
        [self pp_applyProviderState:state];
    }];

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
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
        self.statusLabel.text = kLang(@"ProviderProfileEditor_NoProfile");
        [self pp_updateSaveState];
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
        self.displayNameField.text = displayName;
        self.phoneField.text = phone;
        self.selectedCityID = city;
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:imageRefs];

        self.originalDisplayName = displayName ?: @"";
        self.originalPhone = phone ?: @"";
        self.originalCityID = city ?: @"";
        self.originalAvatarURLString = self.currentAvatarURLString ?: @"";
        self.originalCoverImageURLs = self.coverImageURLs.copy ?: @[];
        self.didHydrateData = YES;
    }

    self.statusLabel.text = [NSString stringWithFormat:kLang(@"ProviderProfileEditor_ProfileReadyFormat"),
                             [PPProviderApplicationManager localizedTitleForProviderType:profile.providerType]];
    [self.coverCollectionView reloadData];
    [self pp_refreshPreview];
    [self pp_updateSaveState];
}

- (void)pp_applyUserDocument:(NSDictionary *)data {
    NSArray *coverURLs = [data[@"coverImageUrls"] isKindOfClass:NSArray.class] ? data[@"coverImageUrls"] : @[];
    NSString *photoURL = PPSafeString(data[@"UserImageUrl"]).length ? PPSafeString(data[@"UserImageUrl"]) : PPSafeString(data[@"photoURL"]);
    if (!self.didHydrateData && coverURLs.count > 0) {
        [self.coverImageURLs removeAllObjects];
        [self.coverImageURLs addObjectsFromArray:coverURLs];
        self.originalCoverImageURLs = self.coverImageURLs.copy;
    }
    if (photoURL.length > 0 && self.currentAvatarURLString.length == 0) {
        self.currentAvatarURLString = photoURL;
        self.originalAvatarURLString = photoURL;
    }
    if (!self.didHydrateData) {
        NSString *displayName = PPSafeString(data[@"displayName"]).length ? PPSafeString(data[@"displayName"]) : PPSafeString(data[@"UserName"]);
        NSString *phone = PPSafeString(data[@"MobileNo"]);
        if (displayName.length > 0) {
            self.displayNameField.text = displayName;
            self.originalDisplayName = displayName;
        }
        if (phone.length > 0) {
            self.phoneField.text = phone;
            self.originalPhone = phone;
        }
    }
    [self.coverCollectionView reloadData];
    [self pp_refreshPreview];
    [self pp_updateSaveState];
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
        if (!PPProviderTypeIsEnabledInProApp(wrappedType.integerValue)) {
            continue;
        }
        PPProviderProfile *profile = [state profileForType:wrappedType.integerValue];
        if (profile) return profile;
    }
    return nil;
}

#pragma mark - Actions

- (void)pp_textFieldDidChange:(UITextField *)sender {
    [self pp_refreshPreview];
    [self pp_updateSaveState];
}

- (void)pp_changeCityTapped {
    [PPFunc pp_playTapEffect];
    PPProviderProfileEditorCitySheetViewController *sheet =
    [[PPProviderProfileEditorCitySheetViewController alloc] initWithSelectedCity:self.selectedCityID completion:^(NSString *cityID) {
        self.selectedCityID = PPSafeString(cityID);
        [self pp_refreshPreview];
        [self pp_updateSaveState];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

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

- (void)pp_saveTapped {
    [PPFunc pp_playTapEffect];
    PPProviderProfileEditorLog([NSString stringWithFormat:
                                @"Save tapped. providerType=%@ authUID=%@ cachedUID=%@ hasPendingChanges=%@ uploads avatar=%@ covers=%@",
                                PPProviderTypeIdentifier(self.providerType),
                                PPSafeString([FIRAuth auth].currentUser.uid),
                                PPSafeString(UsrMgr.currentUser.uid).length ? PPSafeString(UsrMgr.currentUser.uid) : PPSafeString(UsrMgr.currentUser.ID),
                                [self pp_hasPendingChanges] ? @"YES" : @"NO",
                                self.isUploadingAvatar ? @"YES" : @"NO",
                                self.isUploadingCovers ? @"YES" : @"NO"]);
    if (![self pp_validateBeforeSave]) return;
    if (self.providerType == PPProviderTypeUnspecified) {
        PPProviderProfileEditorLog(@"Save aborted: providerType is unspecified.");
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_NoProfile")];
        return;
    }

    self.isSaving = YES;
    [self pp_updateSaveState];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderProfileEditor_Saving") subtitle:nil];

    NSDictionary *payload = @{
        @"providerType": PPProviderTypeIdentifier(self.providerType),
        @"displayName": PPSafeString(self.displayNameField.text),
        @"phone": PPSafeString(self.phoneField.text),
        @"city": PPSafeString(self.selectedCityID),
        @"avatarURL": PPSafeString(self.currentAvatarURLString),
        @"coverImageUrls": self.coverImageURLs.copy ?: @[],
    };

    PPProviderProfileEditorLog([NSString stringWithFormat:
                                @"Prepared payload. providerType=%@ displayNameLength=%lu phoneLength=%lu city=%@ avatarURLPresent=%@  ",
                                PPSafeString(payload[@"providerType"]),
                                (unsigned long)PPSafeString(payload[@"displayName"]).length,
                                (unsigned long)PPSafeString(payload[@"phone"]).length,
                                PPSafeString(payload[@"city"]),
                                PPSafeString(payload[@"avatarURL"]).length > 0 ? @"YES" : @"NO" ]);

    [self pp_callUpdateProviderProfileWithPayload:payload
                                   didRefreshAuth:NO
                             didRetryMissingAuth:NO];
}

- (void)pp_callUpdateProviderProfileWithPayload:(NSDictionary *)payload
                                 didRefreshAuth:(BOOL)didRefreshAuth
                           didRetryMissingAuth:(BOOL)didRetryMissingAuth {
    NSString *authUID = [self pp_currentAuthUID];
    PPProviderProfileEditorLog([NSString stringWithFormat:
                                @"Starting callable. authUID=%@ didRefreshAuth=%@ didRetryMissingAuth=%@",
                                authUID,
                                didRefreshAuth ? @"YES" : @"NO",
                                didRetryMissingAuth ? @"YES" : @"NO"]);
    if (authUID.length == 0) {
        NSString *cachedUID = PPSafeString(UsrMgr.currentUser.uid).length
            ? PPSafeString(UsrMgr.currentUser.uid)
            : PPSafeString(UsrMgr.currentUser.ID);
        PPProviderProfileEditorLog([NSString stringWithFormat:
                                    @"No active auth user at callable start. cachedUID=%@ didRetryMissingAuth=%@",
                                    cachedUID,
                                    didRetryMissingAuth ? @"YES" : @"NO"]);
        if (!didRetryMissingAuth && cachedUID.length > 0) {
            PPProviderProfileEditorLog(@"Retrying save once after short delay because cached user exists.");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pp_callUpdateProviderProfileWithPayload:payload
                                               didRefreshAuth:didRefreshAuth
                                         didRetryMissingAuth:YES];
            });
            return;
        }

        self.isSaving = NO;
        [PPHUD dismiss];
        self.hasUploadFailure = YES;
        [self pp_updateSaveState];
        PPProviderProfileEditorLog(@"Save failed before callable: session expired after missing-auth retry path.");
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_SessionExpired")];
        return;
    }

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"updateMyProviderProfile"];
    callable.timeoutInterval = 30.0;

    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            if (error) {
                PPProviderProfileEditorLog([NSString stringWithFormat:
                                            @"Callable error. domain=%@ code=%ld description=%@ details=%@ unauth=%@ permissionDenied=%@ notFound=%@",
                                            PPSafeString(error.domain),
                                            (long)error.code,
                                            PPSafeString(error.localizedDescription),
                                            PPSafeString(error.userInfo[@"details"]),
                                            PPProviderProfileEditorFunctionErrorIsUnauthenticated(error) ? @"YES" : @"NO",
                                            PPProviderProfileEditorFunctionErrorIsPermissionDenied(error) ? @"YES" : @"NO",
                                            PPProviderProfileEditorFunctionErrorIsNotFound(error) ? @"YES" : @"NO"]);
                if (!didRefreshAuth && PPProviderProfileEditorFunctionErrorIsUnauthenticated(error)) {
                    PPProviderProfileEditorLog(@"Callable reported unauthenticated. Forcing ID token refresh.");
                    [self pp_refreshAuthSessionWithCompletion:^(BOOL refreshed) {
                        PPProviderProfileEditorLog([NSString stringWithFormat:
                                                    @"ID token refresh finished. refreshed=%@",
                                                    refreshed ? @"YES" : @"NO"]);
                        if (refreshed) {
                            [self pp_callUpdateProviderProfileWithPayload:payload
                                                           didRefreshAuth:YES
                                                     didRetryMissingAuth:YES];
                        } else {
                            [self pp_handleFinalSaveError:error];
                        }
                    }];
                    return;
                }
                [self pp_handleFinalSaveError:error];
                return;
            }

            NSDictionary *resultData = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            PPProviderProfileEditorLog([NSString stringWithFormat:
                                        @"Callable success. result=%@",
                                        resultData]);
            [self pp_finishSuccessfulSave];
        });
    }];
}

- (void)pp_finishSuccessfulSave
{
    PPProviderProfileEditorLog(@"Save finished successfully. Updating local originals and cached user.");
    self.isSaving = NO;
    [PPHUD dismiss];

    self.originalDisplayName = PPSafeString(self.displayNameField.text);
    self.originalPhone = PPSafeString(self.phoneField.text);
    self.originalCityID = PPSafeString(self.selectedCityID);
    self.originalAvatarURLString = PPSafeString(self.currentAvatarURLString);
    self.originalCoverImageURLs = self.coverImageURLs.copy ?: @[];
    self.hasUploadFailure = NO;

    UserModel *user = UsrMgr.currentUser;
    if (user) {
        user.displayName = self.originalDisplayName;
        user.UserName = self.originalDisplayName;
        user.MobileNo = self.originalPhone;
        if (self.originalAvatarURLString.length > 0) {
            user.photoURL = self.originalAvatarURLString;
        }
        [UsrMgr p_cacheUser:user];
    }

    self.statusLabel.text = kLang(@"ProviderProfileEditor_SavedHint");
    [self pp_refreshPreview];
    [self pp_updateSaveState];
    [PPToast toast:kLang(@"ProviderProfileEditor_Saved") style:PPToastStyleSuccess haptic:YES duration:1.7];
}

- (void)pp_handleFinalSaveError:(NSError *)error
{
    PPProviderProfileEditorLog([NSString stringWithFormat:
                                @"Final save error. friendlyMessage=%@ rawDomain=%@ rawCode=%ld rawDescription=%@",
                                [self pp_friendlyFunctionsError:error],
                                PPSafeString(error.domain),
                                (long)error.code,
                                PPSafeString(error.localizedDescription)]);
    self.isSaving = NO;
    [PPHUD dismiss];
    self.hasUploadFailure = YES;
    [self pp_updateSaveState];
    [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:[self pp_friendlyFunctionsError:error]];
}



- (BOOL)pp_validateBeforeSave {
    NSString *displayName = [PPSafeString(self.displayNameField.text) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *phone = [PPSafeString(self.phoneField.text) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (displayName.length == 0) {
        PPProviderProfileEditorLog(@"Validation failed: empty display name.");
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProfileSettings_NameRequired")];
        return NO;
    }
    if (phone.length == 0) {
        PPProviderProfileEditorLog(@"Validation failed: empty phone.");
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_PhoneRequired")];
        return NO;
    }
    if (self.selectedCityID.length == 0) {
        PPProviderProfileEditorLog(@"Validation failed: missing city.");
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProviderProfileEditor_CityRequired")];
        return NO;
    }
    PPProviderProfileEditorLog(@"Validation passed.");
    return YES;
}

#pragma mark - Preview

- (void)pp_refreshPreview {
    NSString *displayName = PPSafeString(self.displayNameField.text).length ? PPSafeString(self.displayNameField.text) : kLang(@"ProviderProfileEditor_DisplayNamePlaceholder");
    NSString *cityTitle = PPProviderProfileEditorLocalizedCityTitle(self.selectedCityID);
    NSString *providerTitle = self.providerType != PPProviderTypeUnspecified ? [PPProviderApplicationManager localizedTitleForProviderType:self.providerType] : kLang(@"ProviderProfileEditor_ProfileTypePending");

    self.heroTitleLabel.text = displayName;
    self.heroSubtitleLabel.text = providerTitle;
    self.heroMetaLabel.text = cityTitle.length > 0 ? cityTitle : kLang(@"ProviderProfileEditor_CityPlaceholder");
    [self.cityButton setTitle:(cityTitle.length > 0 ? cityTitle : kLang(@"ProviderProfileEditor_CityPlaceholder")) forState:UIControlStateNormal];

    NSURL *avatarURL = self.currentAvatarURLString.length ? [NSURL URLWithString:self.currentAvatarURLString] : nil;
    if (avatarURL) {
        UIImage *placeholder = nil;
        if (@available(iOS 13.0, *)) {
            placeholder = [UIImage systemImageNamed:@"person.fill"];
        }
        [self.avatarImageView setImageFromUrl:avatarURL.absoluteString placeholderImage:@"person.fill"];
    } else if (@available(iOS 13.0, *)) {
        self.avatarImageView.image = [UIImage systemImageNamed:@"person.fill"];
        self.avatarImageView.tintColor = UIColor.whiteColor;
    } else {
        self.avatarImageView.image = nil;
    }

    NSString *coverString = self.coverImageURLs.firstObject;
    NSURL *coverURL = coverString.length ? [NSURL URLWithString:coverString] : nil;
    if (coverURL) {
        [self.heroCoverImageView setImageFromUrl:coverURL.absoluteString placeholderImage:nil];
    } else {
        self.heroCoverImageView.image = nil;
    }
}

- (void)pp_updateSaveState {
    BOOL hasChanges = [self pp_hasPendingChanges];
    BOOL disabled = self.isSaving || self.isUploadingAvatar || self.isUploadingCovers || self.providerType == PPProviderTypeUnspecified;
    self.saveButton.enabled = hasChanges && !disabled;
    self.saveButton.alpha = self.saveButton.enabled ? 1.0 : 0.56;
    self.saveButton.backgroundColor = self.saveButton.enabled
        ? PPProviderProfileEditorAccentColor()
        : [PPProviderProfileEditorAccentColor() colorWithAlphaComponent:0.42];

    if (self.isUploadingAvatar || self.isUploadingCovers) {
        self.statusLabel.text = kLang(@"ProviderProfileEditor_UploadingHint");
    } else if (self.isSaving) {
        self.statusLabel.text = kLang(@"ProviderProfileEditor_SavingHint");
    } else if (self.hasUploadFailure) {
        self.statusLabel.text = kLang(@"ProviderProfileEditor_RetryHint");
    } else if (hasChanges) {
        self.statusLabel.text = kLang(@"ProviderProfileEditor_UnsavedHint");
    } else if (self.providerType == PPProviderTypeUnspecified) {
        self.statusLabel.text = kLang(@"ProviderProfileEditor_NoProfile");
    }
}

- (BOOL)pp_hasPendingChanges {
    BOOL textChanged = ![PPSafeString(self.displayNameField.text) isEqualToString:PPSafeString(self.originalDisplayName)] ||
    ![PPSafeString(self.phoneField.text) isEqualToString:PPSafeString(self.originalPhone)] ||
    ![PPSafeString(self.selectedCityID) isEqualToString:PPSafeString(self.originalCityID)] ||
    ![PPSafeString(self.currentAvatarURLString) isEqualToString:PPSafeString(self.originalAvatarURLString)];
    BOOL coversChanged = ![[self.coverImageURLs copy] isEqualToArray:self.originalCoverImageURLs ?: @[]];
    return textChanged || coversChanged;
}

#pragma mark - Picker

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
    self.hasUploadFailure = NO;
    [self pp_updateSaveState];
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

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.isUploadingCovers = NO;
        [PPHUD dismiss];
        if (uploadedURLs.count > 0) {
            [self.coverImageURLs addObjectsFromArray:uploadedURLs];
            if (self.coverImageURLs.count > 5) {
                self.coverImageURLs = [[self.coverImageURLs subarrayWithRange:NSMakeRange(0, 5)] mutableCopy];
            }
            [self.coverCollectionView reloadData];
            [self pp_refreshPreview];
        }
        if (firstError) {
            self.hasUploadFailure = YES;
            [PPToast toast:kLang(@"ProviderProfileEditor_CoverUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        } else if (uploadedURLs.count > 0) {
            [PPToast toast:kLang(@"ProviderProfileEditor_CoverUploaded") style:PPToastStyleSuccess haptic:YES duration:1.4];
        }
        [self pp_updateSaveState];
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

// Rewritten to use Firebase Storage completion strategy like covers
- (void)pp_uploadAvatarImage:(UIImage *)image {
    NSString *uid = [self pp_currentAuthUID];
    if (uid.length == 0 || !image) {
        self.hasUploadFailure = YES;
        [self pp_updateSaveState];
        [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    self.isUploadingAvatar = YES;
    self.hasUploadFailure = NO;
    [self pp_updateSaveState];
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
                self.hasUploadFailure = YES;
                [PPHUD dismiss];
                [self pp_updateSaveState];
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
                if (didFinish) {
                    return;
                }
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUploadingAvatar = NO;
                [PPHUD dismiss];
                if (urlString.length == 0 || error) {
                    self.hasUploadFailure = YES;
                    [self pp_updateSaveState];
                    [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
                    return;
                }
                self.currentAvatarURLString = urlString;
                self.hasUploadFailure = NO;
                [self pp_refreshPreview];
                [self pp_updateSaveState];
                [PPToast toast:kLang(@"ProviderProfileEditor_AvatarUploaded") style:PPToastStyleSuccess haptic:YES duration:1.4];
            });
        };

        void (^resolveDownloadURL)(NSError * _Nullable) = ^(NSError * _Nullable fallbackError) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
                NSString *resolvedURLString = PPSafeString(URL.absoluteString);
                if (resolvedURLString.length > 0) {
                    finishOnMain(resolvedURLString, nil);
                    return;
                }
                NSError *resolvedError = error2 ?: fallbackError ?: [NSError errorWithDomain:@"PPProviderProfileEditor"
                                                                                        code:-44
                                                                                    userInfo:nil];
                finishOnMain(nil, resolvedError);
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
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
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
            [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
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
                if (didFinish) {
                    return;
                }
                didFinish = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(urlString, error);
                }
            });
        };

        void (^resolveDownloadURL)(NSError * _Nullable) = ^(NSError * _Nullable fallbackError) {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
                NSString *resolvedURLString = PPSafeString(URL.absoluteString);
                if (resolvedURLString.length > 0) {
                    finishOnMain(resolvedURLString, nil);
                    return;
                }
                NSError *resolvedError = error2 ?: fallbackError ?: [NSError errorWithDomain:@"PPProviderProfileEditor"
                                                                                        code:-4
                                                                                    userInfo:nil];
                finishOnMain(nil, resolvedError);
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
            finishOnMain(nil, taskError ?: [NSError errorWithDomain:@"PPProviderProfileEditor" code:-5 userInfo:nil]);
        }];
    });
}

#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.coverImageURLs.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPProviderProfileEditorCoverCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cover" forIndexPath:indexPath];
    NSString *urlString = PPSafeString(self.coverImageURLs[indexPath.item]);
    [cell.imageView setImageFromUrl:urlString placeholderImage:nil];
    cell.removeButton.tag = indexPath.item;
    [cell.removeButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.removeButton addTarget:self action:@selector(pp_removeCoverTapped:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

- (void)pp_removeCoverTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= self.coverImageURLs.count) return;
    [PPFunc pp_playTapEffect];
    [self.coverImageURLs removeObjectAtIndex:index];
    [self.coverCollectionView reloadData];
    [self pp_refreshPreview];
    [self pp_updateSaveState];
}

#pragma mark - Helpers

- (NSString *)pp_currentAuthUID {
    return PPSafeString([FIRAuth auth].currentUser.uid);
}

- (BOOL)pp_cachedUserMatchesCurrentAuthSession {
    NSString *authUID = [self pp_currentAuthUID];
    if (authUID.length == 0) {
        return NO;
    }
    UserModel *user = UsrMgr.currentUser;
    if (!user) {
        return YES;
    }
    NSString *cachedUID = PPSafeString(user.uid).length ? PPSafeString(user.uid) : PPSafeString(user.ID);
    return cachedUID.length == 0 || [cachedUID isEqualToString:authUID];
}

- (void)pp_refreshAuthSessionWithCompletion:(void(^)(BOOL refreshed))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        PPProviderProfileEditorLog(@"ID token refresh skipped: no current Firebase auth user.");
        if (completion) completion(NO);
        return;
    }
    PPProviderProfileEditorLog([NSString stringWithFormat:
                                @"Requesting forced ID token refresh for uid=%@",
                                PPSafeString(authUser.uid)]);
    [authUser getIDTokenForcingRefresh:YES completion:^(NSString *token, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProviderProfileEditorLog([NSString stringWithFormat:
                                        @"Forced ID token refresh callback. tokenPresent=%@ error=%@",
                                        token.length > 0 ? @"YES" : @"NO",
                                        PPSafeString(error.localizedDescription)]);
            if (completion) completion(token.length > 0 && error == nil);
        });
    }];
}

- (NSString *)pp_friendlyFunctionsError:(NSError *)error {
    NSDictionary *details = [error.userInfo[@"details"] isKindOfClass:NSDictionary.class] ? error.userInfo[@"details"] : nil;
    NSString *message = PPSafeString(details[@"message"]);
    if (message.length == 0) {
        message = error.localizedDescription;
    }
    if (PPProviderProfileEditorFunctionErrorIsUnauthenticated(error)) {
        return kLang(@"ProviderProfileEditor_SessionExpired");
    }
    if (PPProviderProfileEditorFunctionErrorIsPermissionDenied(error)) {
        return kLang(@"ProviderProfileEditor_PermissionDenied");
    }
    if (PPProviderProfileEditorFunctionErrorIsNotFound(error)) {
        return kLang(@"ProviderProfileEditor_NoProfile");
    }
    return message.length > 0 ? message : kLang(@"ProviderProfileEditor_SaveFailed");
}

- (void)pp_runEntranceAnimation {
    NSArray<UIView *> *views = @[self.heroCard ?: UIView.new];
    for (UIView *view in views) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    [UIView animateWithDuration:0.72
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        self.heroCard.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyStaticColors {
    self.view.backgroundColor = AppBackgroundClr;
    self.footerBar.backgroundColor = [PPProviderProfileEditorSurfaceColor() colorWithAlphaComponent:0.98];
    self.footerBar.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    self.heroCoverImageView.backgroundColor = PPProviderProfileEditorHeroFallbackColor();
    self.avatarButton.backgroundColor = PPProviderProfileEditorHeroPlateColor();
    self.avatarButton.layer.borderColor = PPProviderProfileEditorHeroPlateBorderColor().CGColor;
    self.avatarImageView.backgroundColor = PPProviderProfileEditorHeroAvatarFillColor();

    for (UIView *view in self.elevatedSurfaceViews) {
        view.backgroundColor = PPProviderProfileEditorSurfaceColor();
        view.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    }
    for (UIView *view in self.innerSurfaceViews) {
        view.backgroundColor = PPProviderProfileEditorInnerSurfaceColor();
        view.layer.borderColor = PPProviderProfileEditorBorderColor().CGColor;
    }
}

@end
