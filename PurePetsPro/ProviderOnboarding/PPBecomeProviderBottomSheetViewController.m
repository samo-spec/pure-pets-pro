#import "PPBecomeProviderBottomSheetViewController.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"
#import "CitiesManager.h"
#import "PPButtonHelper.h"
#import "PPFirebaseCompat.h"
#import "PPPaddingLabel.h"
#import "Styling.h"
@import UniformTypeIdentifiers;
@import PhotosUI;
@import VisionKit;
#import <objc/runtime.h>

static void *PPProviderPickerTagKey = &PPProviderPickerTagKey;

static void PPSetPickerTag(UIViewController *vc, NSInteger tag) {
    objc_setAssociatedObject(vc, PPProviderPickerTagKey, @(tag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSInteger PPGetPickerTag(UIViewController *vc) {
    return [objc_getAssociatedObject(vc, PPProviderPickerTagKey) integerValue];
}

static UIColor *PPProviderSheetAccentColor(void) {
    return AppPrimaryClr;
}

static UIColor *PPProviderSheetActionTextOnAccentColor(void) {
    return UIColor.whiteColor;
}

static UIColor *PPProviderSheetBackgroundColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor ppSurface];
    }
    return AppBackgroundClr;
}

static UIColor *PPProviderSheetSurfaceColor(void) {
    return AppForgroundColr;
}

static UIColor *PPProviderSheetMatteColor(void) {
    return [UIColor ppBackground];
}

static UIColor *PPProviderSheetSoftFillColor(void) {
    return [[UIColor ppElevatedSurface] colorWithAlphaComponent:0.5];
}

static UIColor *PPProviderSheetPrimaryTextColor(void) {
    return [UIColor ppTextPrimary];
}

static UIColor *PPProviderSheetSecondaryTextColor(void) {
    return [UIColor ppTextSecondary];
}

static UIColor *PPProviderSheetShadowColor(void) {
    return AppShadowColor;
}

static NSDictionary *PPProviderSheetOption(NSString *value, NSString *titleKey, NSString *subtitleKey) {
    NSMutableDictionary *option = [NSMutableDictionary dictionary];
    option[@"value"] = value ?: @"";
    option[@"titleKey"] = titleKey ?: @"";
    if (subtitleKey.length > 0) {
        option[@"subtitleKey"] = subtitleKey;
    }
    return option.copy;
}

static NSString *PPProviderSheetOptionValue(NSDictionary *option) {
    return PPSafeString(option[@"value"]);
}

static NSString *PPProviderSheetOptionTitle(NSDictionary *option) {
    NSString *titleKey = PPSafeString(option[@"titleKey"]);
    NSString *title = titleKey.length > 0 ? kLang(titleKey) : PPSafeString(option[@"title"]);
    return title.length > 0 ? title : PPProviderSheetOptionValue(option);
}

static NSString *PPProviderSheetOptionSubtitle(NSDictionary *option) {
    NSString *subtitleKey = PPSafeString(option[@"subtitleKey"]);
    NSString *subtitle = subtitleKey.length > 0 ? kLang(subtitleKey) : PPSafeString(option[@"subtitle"]);
    return subtitle;
}

static NSArray<NSDictionary *> *PPProviderCountryCodeOptions(void) {
    return [CitiesManager.shared countryDialCodeOptions] ?: @[];
}

static NSArray<NSDictionary *> *PPProviderAreaKeysForCityID(NSString *cityID) {
    static NSDictionary<NSString *, NSArray<NSString *> *> *mapping;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapping = @{
            @"15001": @[
                @"ProviderQatarAreaDohaAll", @"ProviderQatarAreaMsheireb", @"ProviderQatarAreaWestBay",
                @"ProviderQatarAreaAlDafna", @"ProviderQatarAreaAlSadd", @"ProviderQatarAreaBinMahmoud",
                @"ProviderQatarAreaNajma", @"ProviderQatarAreaAlMansoura", @"ProviderQatarAreaOldAirport",
                @"ProviderQatarAreaThePearl"
            ],
            @"15004": @[
                @"ProviderQatarAreaAlRayyanAll", @"ProviderQatarAreaEducationCity", @"ProviderQatarAreaAlWaab",
                @"ProviderQatarAreaMuaither", @"ProviderQatarAreaAlGharrafa", @"ProviderQatarAreaAlLuqta",
                @"ProviderQatarAreaAlAziziya", @"ProviderQatarAreaAinKhaled", @"ProviderQatarAreaAbuSidra",
                @"ProviderQatarAreaRawdatEgdaim"
            ],
            @"15002": @[
                @"ProviderQatarAreaAlWakrahAll", @"ProviderQatarAreaAlWakrahCity", @"ProviderQatarAreaAlWukair",
                @"ProviderQatarAreaMesaieed", @"ProviderQatarAreaEzdanOasis", @"ProviderQatarAreaAlMashaf",
                @"ProviderQatarAreaBarwaVillage", @"ProviderQatarAreaRasAbuFontas"
            ],
            @"15003": @[
                @"ProviderQatarAreaAlKhorAll", @"ProviderQatarAreaAlKhorCity", @"ProviderQatarAreaAlThakhira",
                @"ProviderQatarAreaRasLaffan", @"ProviderQatarAreaAlGhuwairiya", @"ProviderQatarAreaUmmBirka"
            ],
            @"15005": @[
                @"ProviderQatarAreaAlShamalAll", @"ProviderQatarAreaMadinatAlShamal", @"ProviderQatarAreaArRuays",
                @"ProviderQatarAreaAbuDhalouf", @"ProviderQatarAreaFuwayrit", @"ProviderQatarAreaAlZubarah"
            ],
            @"15007": @[
                @"ProviderQatarAreaUmmSalalAll", @"ProviderQatarAreaUmmSalalAli", @"ProviderQatarAreaUmmSalalMohammed",
                @"ProviderQatarAreaUmmAlAmad", @"ProviderQatarAreaIzghawa", @"ProviderQatarAreaAlKharaitiyat"
            ],
            @"15006": @[
                @"ProviderQatarAreaAlDaayenAll", @"ProviderQatarAreaLusail", @"ProviderQatarAreaUmmQarn",
                @"ProviderQatarAreaRawdatAlHamama", @"ProviderQatarAreaAlEbb", @"ProviderQatarAreaLeabaib",
                @"ProviderQatarAreaWadiAlBanat", @"ProviderQatarAreaJeryanJenaihat"
            ],
            @"15008": @[
                @"ProviderQatarAreaAlShahaniyaAll", @"ProviderQatarAreaAlShahaniyaCity", @"ProviderQatarAreaDukhan",
                @"ProviderQatarAreaUmmBab", @"ProviderQatarAreaRawdatRashed", @"ProviderQatarAreaAlNasraniya",
                @"ProviderQatarAreaAlJemailiya"
            ],
        };
    });
    return mapping[cityID] ?: @[];
}

static NSArray<NSDictionary *> *PPProviderQatarCityOptions(void) {
    NSArray<CityModel *> *cities = [CitiesManager.shared citiesForCurrentCountry];
    NSMutableArray<NSDictionary *> *options = [NSMutableArray array];
    for (CityModel *city in cities) {
        NSString *cityID = [NSString stringWithFormat:@"%ld", (long)city.cityID];
        NSString *title = Language.isRTL ? city.arName : city.enName;
        NSMutableDictionary *option = [PPProviderSheetOption(cityID, title, nil) mutableCopy];
        option[@"areaKeys"] = PPProviderAreaKeysForCityID(cityID);
        [options addObject:option.copy];
    }
    return options.copy;
}

static NSDictionary *PPProviderQatarCityOptionForID(NSString *cityID) {
    NSString *safeCityID = PPSafeString(cityID);
    for (NSDictionary *city in PPProviderQatarCityOptions()) {
        if ([PPProviderSheetOptionValue(city) isEqualToString:safeCityID]) {
            return city;
        }
    }
    return nil;
}

typedef void(^PPProviderOptionSheetCompletion)(NSArray<NSDictionary *> *selectedOptions);

@interface PPProviderPremiumOptionSheetViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *sheetTitle;
@property (nonatomic, copy) NSString *sheetSubtitle;
@property (nonatomic, copy) NSArray<NSDictionary *> *options;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedValues;
@property (nonatomic, assign) BOOL allowsMultipleSelection;
@property (nonatomic, copy) PPProviderOptionSheetCompletion completion;
- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                      options:(NSArray<NSDictionary *> *)options
               selectedValues:(NSArray<NSString *> *)selectedValues
       allowsMultipleSelection:(BOOL)allowsMultipleSelection
                    completion:(PPProviderOptionSheetCompletion)completion;
@end

@implementation PPProviderPremiumOptionSheetViewController {
    UITableView *_tableView;
    UIButton *_doneButton;
}

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                      options:(NSArray<NSDictionary *> *)options
               selectedValues:(NSArray<NSString *> *)selectedValues
       allowsMultipleSelection:(BOOL)allowsMultipleSelection
                    completion:(PPProviderOptionSheetCompletion)completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sheetTitle = title.copy ?: @"";
        _sheetSubtitle = subtitle.copy ?: @"";
        _options = options.copy ?: @[];
        _selectedValues = [NSMutableSet setWithArray:selectedValues ?: @[]];
        _allowsMultipleSelection = allowsMultipleSelection;
        _completion = [completion copy];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPProviderSheetBackgroundColor();
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:header];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:22.0];
    titleLabel.textColor = PPProviderSheetPrimaryTextColor();
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = self.sheetTitle;
    [header addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontMedium:12.5];
    subtitleLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.86];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.text = self.sheetSubtitle;
    [header addSubview:subtitleLabel];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.tintColor = PPProviderSheetPrimaryTextColor();
    closeButton.backgroundColor = PPProviderSheetMatteColor();
    closeButton.layer.cornerRadius = 18.0;
    closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageSymbolConfiguration *closeConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightBold];
    [closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:closeConfig] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(pp_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:closeButton style:PPButtonAnimationStylePulse];
    [header addSubview:closeButton];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 70.0;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:_tableView];

    UIView *footer = [[UIView alloc] init];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    footer.hidden = !self.allowsMultipleSelection;
    [self.view addSubview:footer];

    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeCustom];
    clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    clearButton.titleLabel.font = [Styling fontBold:14.0];
    clearButton.layer.cornerRadius = 20.0;
    clearButton.layer.cornerCurve = kCACornerCurveContinuous;
    clearButton.backgroundColor = PPProviderSheetMatteColor();
    [clearButton setTitle:kLang(@"ProviderPickerClear") forState:UIControlStateNormal];
    [clearButton setTitleColor:PPProviderSheetPrimaryTextColor() forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(pp_clearTapped) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:clearButton style:PPButtonAnimationStylePulse];
    [footer addSubview:clearButton];

    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    _doneButton.titleLabel.font = [Styling fontBold:15.0];
    _doneButton.layer.cornerRadius = 22.0;
    _doneButton.layer.cornerCurve = kCACornerCurveContinuous;
    _doneButton.backgroundColor = PPProviderSheetAccentColor();
    _doneButton.layer.shadowColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.35].CGColor;
    _doneButton.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    _doneButton.layer.shadowRadius = 18.0;
    _doneButton.layer.shadowOpacity = 0.12;
    [_doneButton setTitle:kLang(@"Done") forState:UIControlStateNormal];
    [_doneButton setTitleColor:PPProviderSheetActionTextOnAccentColor() forState:UIControlStateNormal];
    [_doneButton addTarget:self action:@selector(pp_doneTapped) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:_doneButton style:PPButtonAnimationStyleDefault];
    [footer addSubview:_doneButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutYAxisAnchor *tableBottomAnchor = self.allowsMultipleSelection ? footer.topAnchor : safe.bottomAnchor;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18.0],
        [header.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [header.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

        [closeButton.topAnchor constraintEqualToAnchor:header.topAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [closeButton.widthAnchor constraintEqualToConstant:36.0],
        [closeButton.heightAnchor constraintEqualToConstant:36.0],

        [titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:4.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-14.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:tableBottomAnchor],

        [footer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [footer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [footer.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12.0],
        [footer.heightAnchor constraintEqualToConstant:58.0],

        [clearButton.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],
        [clearButton.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [clearButton.widthAnchor constraintEqualToConstant:108.0],
        [clearButton.heightAnchor constraintEqualToConstant:44.0],

        [_doneButton.leadingAnchor constraintEqualToAnchor:clearButton.trailingAnchor constant:12.0],
        [_doneButton.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
        [_doneButton.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [_doneButton.heightAnchor constraintEqualToConstant:48.0],
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderPremiumOptionCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PPProviderPremiumOptionCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = PPProviderSheetSurfaceColor();
        cell.contentView.layer.cornerRadius = 18.0;
        cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        cell.textLabel.font = [Styling fontBold:15.0];
        cell.textLabel.textColor = PPProviderSheetPrimaryTextColor();
        cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.font = [Styling fontMedium:12.0];
        cell.detailTextLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.82];
        cell.detailTextLabel.textAlignment = Language.alignmentForCurrentLanguage;
        cell.detailTextLabel.numberOfLines = 2;
    }

    NSDictionary *option = self.options[indexPath.row];
    NSString *value = PPProviderSheetOptionValue(option);
    BOOL selected = [self.selectedValues containsObject:value];
    cell.textLabel.text = PPProviderSheetOptionTitle(option);
    cell.detailTextLabel.text = PPProviderSheetOptionSubtitle(option);
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = PPProviderSheetAccentColor();
    cell.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *option = self.options[indexPath.row];
    NSString *value = PPProviderSheetOptionValue(option);
    if (self.allowsMultipleSelection) {
        if ([self.selectedValues containsObject:value]) {
            [self.selectedValues removeObject:value];
        } else if (value.length > 0) {
            [self.selectedValues addObject:value];
        }
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        return;
    }

    if (value.length > 0) {
        [self.selectedValues setSet:[NSSet setWithObject:value]];
    }
    if (self.completion) {
        self.completion(@[option]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 6.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 6.0;
}

- (void)pp_doneTapped {
    NSMutableArray<NSDictionary *> *selected = [NSMutableArray array];
    for (NSDictionary *option in self.options) {
        if ([self.selectedValues containsObject:PPProviderSheetOptionValue(option)]) {
            [selected addObject:option];
        }
    }
    if (self.completion) {
        self.completion(selected.copy);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_clearTapped {
    [self.selectedValues removeAllObjects];
    [_tableView reloadData];
}

- (void)pp_closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface PPProviderPlanCardControl : UIControl
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIStackView *featureStack;
@property (nonatomic, strong) PPPaddingLabel *badgeLabel;
@property (nonatomic, strong) UIView *selectionOrbView;
@property (nonatomic, strong) UIImageView *selectionImageView;
@property (nonatomic, strong) UIView *decorDiscView;
@property (nonatomic, strong) UIView *decorLineView;
@property (nonatomic, strong) PPProviderPlan *plan;
- (instancetype)initWithPlan:(PPProviderPlan *)plan;
- (void)applySelectionState:(BOOL)isSelected;
@end

@implementation PPProviderPlanCardControl

- (instancetype)initWithPlan:(PPProviderPlan *)plan {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        UIColor *accentColor = PPProviderSheetAccentColor();

        self.plan = plan;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.backgroundColor = PPProviderSheetSurfaceColor();
        self.layer.cornerRadius = 24.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.10].CGColor;
        self.layer.shadowColor = PPProviderSheetShadowColor().CGColor;
        self.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        self.layer.shadowRadius = 22.0;
        self.layer.shadowOpacity = 0.05;

        self.decorDiscView = [[UIView alloc] init];
        self.decorDiscView.translatesAutoresizingMaskIntoConstraints = NO;
        self.decorDiscView.userInteractionEnabled = NO;
        self.decorDiscView.backgroundColor = [accentColor colorWithAlphaComponent:0.055];
        self.decorDiscView.layer.cornerRadius = 68.0;
        self.decorDiscView.layer.cornerCurve = kCACornerCurveContinuous;
        [self insertSubview:self.decorDiscView atIndex:0];

        self.decorLineView = [[UIView alloc] init];
        self.decorLineView.translatesAutoresizingMaskIntoConstraints = NO;
        self.decorLineView.userInteractionEnabled = NO;
        self.decorLineView.backgroundColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.055];
        self.decorLineView.layer.cornerRadius = 1.0;
        [self insertSubview:self.decorLineView atIndex:1];

        self.selectionOrbView = [[UIView alloc] init];
        self.selectionOrbView.translatesAutoresizingMaskIntoConstraints = NO;
        self.selectionOrbView.backgroundColor = PPProviderSheetMatteColor();
        self.selectionOrbView.layer.cornerRadius = 18.0;
        self.selectionOrbView.layer.cornerCurve = kCACornerCurveContinuous;
        self.selectionOrbView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.selectionOrbView.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.12].CGColor;
        [self addSubview:self.selectionOrbView];

        UIImageSymbolConfiguration *selectionConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                      weight:UIImageSymbolWeightBold];
        self.selectionImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus" withConfiguration:selectionConfig]];
        self.selectionImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.selectionImageView.tintColor = accentColor;
        [self.selectionOrbView addSubview:self.selectionImageView];

        self.badgeLabel = [[PPPaddingLabel alloc] init];
        self.badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.badgeLabel.font = [Styling fontBold:10.0];
        self.badgeLabel.textInsets = UIEdgeInsetsMake(7, 12, 7, 12);
        self.badgeLabel.textColor = accentColor;
        self.badgeLabel.backgroundColor = PPProviderSheetMatteColor();
        self.badgeLabel.layer.cornerRadius = 14.0;
        self.badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
        self.badgeLabel.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.badgeLabel.layer.borderColor = [accentColor colorWithAlphaComponent:0.20].CGColor;
        self.badgeLabel.clipsToBounds = YES;
        self.badgeLabel.text = plan.recommended ? kLang(@"ProviderPlanRecommended") : @"";
        self.badgeLabel.hidden = !plan.recommended;
        [self addSubview:self.badgeLabel];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [Styling fontBold:23.0];
        self.titleLabel.textColor = PPProviderSheetPrimaryTextColor();
        self.titleLabel.numberOfLines = 2;
        self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.titleLabel.text = plan.localizedName;
        [self addSubview:self.titleLabel];

        self.priceLabel = [[UILabel alloc] init];
        self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.priceLabel.font = [Styling fontBold:13.0];
        self.priceLabel.textColor = accentColor;
        self.priceLabel.numberOfLines = 2;
        self.priceLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.priceLabel.text = plan.localizedPriceLine;
        [self addSubview:self.priceLabel];

        self.descriptionLabel = [[UILabel alloc] init];
        self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.descriptionLabel.font = [Styling fontRegular:13.5];
        self.descriptionLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.95];
        self.descriptionLabel.numberOfLines = 0;
        self.descriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.descriptionLabel.text = plan.localizedDescriptionText;
        [self addSubview:self.descriptionLabel];

        BOOL hasFeatures = plan.features.count > 0;
        self.featureStack = [[UIStackView alloc] init];
        self.featureStack.translatesAutoresizingMaskIntoConstraints = NO;
        self.featureStack.axis = UILayoutConstraintAxisVertical;
        self.featureStack.spacing = 8.0;
        self.featureStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.featureStack.hidden = !hasFeatures;
        [self addSubview:self.featureStack];

        NSUInteger maxFeatures = MIN(plan.features.count, 4);
        for (NSUInteger idx = 0; idx < maxFeatures; idx++) {
            NSString *feature = plan.features[idx];
            UIStackView *row = [[UIStackView alloc] init];
            row.translatesAutoresizingMaskIntoConstraints = NO;
            row.axis = UILayoutConstraintAxisHorizontal;
            row.alignment = UIStackViewAlignmentCenter;
            row.spacing = 8.0;
            row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

            UIImageSymbolConfiguration *featureConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
            UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:featureConfig]];
            checkView.translatesAutoresizingMaskIntoConstraints = NO;
            checkView.tintColor = accentColor;
            [checkView.widthAnchor constraintEqualToConstant:14.0].active = YES;
            [checkView.heightAnchor constraintEqualToConstant:14.0].active = YES;

            UILabel *featureLabel = [[UILabel alloc] init];
            featureLabel.translatesAutoresizingMaskIntoConstraints = NO;
            featureLabel.font = [Styling fontMedium:12.0];
            featureLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.92];
            featureLabel.numberOfLines = 2;
            featureLabel.textAlignment = Language.alignmentForCurrentLanguage;
            featureLabel.text = feature;

            [row addArrangedSubview:checkView];
            [row addArrangedSubview:featureLabel];
            [self.featureStack addArrangedSubview:row];
        }

        [NSLayoutConstraint activateConstraints:@[
            [self.decorDiscView.widthAnchor constraintEqualToConstant:136.0],
            [self.decorDiscView.heightAnchor constraintEqualToConstant:136.0],
            [self.decorDiscView.topAnchor constraintEqualToAnchor:self.topAnchor constant:-44.0],
            [self.decorDiscView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:38.0],

            [self.decorLineView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18.0],
            [self.decorLineView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18.0],
            [self.decorLineView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18.0],
            [self.decorLineView.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

            [self.selectionOrbView.topAnchor constraintEqualToAnchor:self.topAnchor constant:18.0],
            [self.selectionOrbView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18.0],
            [self.selectionOrbView.widthAnchor constraintEqualToConstant:36.0],
            [self.selectionOrbView.heightAnchor constraintEqualToConstant:36.0],

            [self.selectionImageView.centerXAnchor constraintEqualToAnchor:self.selectionOrbView.centerXAnchor],
            [self.selectionImageView.centerYAnchor constraintEqualToAnchor:self.selectionOrbView.centerYAnchor],

            [self.badgeLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:18.0],
            [self.badgeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18.0],
            [self.badgeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionOrbView.leadingAnchor constant:-10.0],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.badgeLabel.hidden ? self.topAnchor : self.badgeLabel.bottomAnchor
                                                      constant:self.badgeLabel.hidden ? 18.0 : 12.0],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18.0],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.selectionOrbView.leadingAnchor constant:-12.0],

            [self.priceLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],
            [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18.0],

            [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.priceLabel.bottomAnchor constant:12.0],
            [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18.0],

            [self.featureStack.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:(hasFeatures ? 14.0 : 0.0)],
            [self.featureStack.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.featureStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18.0],
            [self.featureStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-18.0],
        ]];

        NSLayoutConstraint *bottomAnchor = [self.featureStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18.0];
        bottomAnchor.priority = UILayoutPriorityDefaultHigh;
        bottomAnchor.active = hasFeatures;

        NSLayoutConstraint *featureHeightConstraint = [self.featureStack.heightAnchor constraintEqualToConstant:0.0];
        featureHeightConstraint.active = !hasFeatures;

        NSLayoutConstraint *descriptionBottomAnchor = [self.descriptionLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18.0];
        descriptionBottomAnchor.priority = UILayoutPriorityDefaultLow;
        descriptionBottomAnchor.active = YES;

        [self applySelectionState:NO];
    }
    return self;
}

- (void)applySelectionState:(BOOL)isSelected {
    UIColor *accentColor = PPProviderSheetAccentColor();
    UIColor *surfaceColor = PPProviderSheetSurfaceColor();
    UIColor *borderColor = isSelected ? [accentColor colorWithAlphaComponent:0.38] : [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.10];
    UIColor *backgroundColor = surfaceColor;
    UIColor *selectionBackground = isSelected ? accentColor : PPProviderSheetMatteColor();
    UIColor *selectionTint = isSelected ? PPProviderSheetActionTextOnAccentColor() : accentColor;
    UIImageSymbolConfiguration *selectionConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                  weight:UIImageSymbolWeightBold];
    UIImage *selectionImage = [UIImage systemImageNamed:(isSelected ? @"checkmark" : @"plus") withConfiguration:selectionConfig];

    void (^updates)(void) = ^{
        self.layer.borderColor = borderColor.CGColor;
        self.backgroundColor = backgroundColor;
        self.layer.shadowOpacity = isSelected ? 0.10 : 0.05;
        self.decorDiscView.alpha = isSelected ? 1.0 : 0.55;
        self.decorDiscView.transform = isSelected ? CGAffineTransformMakeScale(1.08, 1.08) : CGAffineTransformIdentity;
        self.decorLineView.backgroundColor = [accentColor colorWithAlphaComponent:isSelected ? 0.18 : 0.055];
        self.selectionOrbView.backgroundColor = selectionBackground;
        self.selectionOrbView.layer.borderColor = [selectionBackground colorWithAlphaComponent:isSelected ? 1.0 : 0.12].CGColor;
        self.selectionImageView.image = selectionImage;
        self.selectionImageView.tintColor = selectionTint;
    };

    if (self.window) {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:updates completion:nil];
        if (isSelected && !UIAccessibilityIsReduceMotionEnabled()) {
            self.selectionOrbView.transform = CGAffineTransformMakeScale(0.86, 0.86);
            [UIView animateWithDuration:0.34
                                  delay:0.0
                 usingSpringWithDamping:0.78
                  initialSpringVelocity:0.36
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.selectionOrbView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    } else {
        updates();
    }

    self.accessibilityTraits = isSelected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
}

@end

@interface PPBecomeProviderBottomSheetViewController () <UITextFieldDelegate, UITextViewDelegate, UIScrollViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate, VNDocumentCameraViewControllerDelegate, PPYesWeScanWrapperDelegate>
@property (nonatomic, strong) PPProviderOnboardingState *state;
@property (nonatomic, copy) NSArray<NSNumber *> *eligibleProviderTypes;
@property (nonatomic, assign) PPProviderType selectedProviderType;
@property (nonatomic, strong) NSArray<UIButton *> *typeButtons;
@property (nonatomic, strong) NSArray<PPProviderPlan *> *plans;
@property (nonatomic, strong, nullable) PPProviderPlan *selectedPlan;
@property (nonatomic, copy) NSString *plansLoadErrorMessage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *planStack;
@property (nonatomic, strong) UILabel *plansStateLabel;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UILabel *footerHintLabel;
@property (nonatomic, strong) NSLayoutConstraint *footerBarBottomConstraint;
@property (nonatomic, strong) UIView *businessNameContainer;
@property (nonatomic, strong) UIView *companyNameContainer;
@property (nonatomic, strong) UIView *legalNameContainer;
@property (nonatomic, strong) UIView *addressContainer;
@property (nonatomic, strong) UIView *licenseNumberContainer;
@property (nonatomic, strong) UIView *commercialRegistrationContainer;
@property (nonatomic, strong) UIButton *countryCodeButton;
@property (nonatomic, strong) UITextField *fullNameField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *businessNameField;
@property (nonatomic, strong) UITextField *companyNameField;
@property (nonatomic, strong) UITextField *legalNameField;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UITextField *licenseNumberField;
@property (nonatomic, strong) UITextField *commercialRegistrationField;
@property (nonatomic, strong) UITextField *cityField;
@property (nonatomic, strong) UITextField *coverageAreasField;
@property (nonatomic, strong) UITextView *notesView;
@property (nonatomic, copy) NSString *selectedCountryCode;
@property (nonatomic, copy) NSString *selectedCityIdentifier;
@property (nonatomic, copy) NSArray<NSString *> *selectedCoverageAreaKeys;
@property (nonatomic, strong) PPPaddingLabel *heroTypePill;
@property (nonatomic, strong) UILabel *heroFocusLabel;
@property (nonatomic, strong) UIImageView *heroStageIconView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroStageView;
@property (nonatomic, strong) UIView *heroGlowTopView;
@property (nonatomic, strong) UIView *heroGlowBottomView;
@property (nonatomic, strong) UIView *heroLiquidLineView;
@property (nonatomic, strong) UIView *ambientTopView;
@property (nonatomic, strong) UIView *ambientBottomView;
@property (nonatomic, assign) BOOL isLoadingPlans;
@property (nonatomic, assign) BOOL isSubmitting;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL ambientMotionRunning;

@property (nonatomic, copy) NSString *licenseDocumentURL;
@property (nonatomic, copy) NSString *commercialRegDocumentURL;
@property (nonatomic, assign) BOOL isUploadingLicense;
@property (nonatomic, assign) BOOL isUploadingCommercialReg;
@property (nonatomic, strong) UIView *licenseAttachZone;
@property (nonatomic, strong) UIView *commercialAttachZone;
@property (nonatomic, strong) UIImageView *licenseThumbView;
@property (nonatomic, strong) UIImageView *commercialThumbView;
@property (nonatomic, assign) PPProviderType lastAppliedProviderType;
@property (nonatomic, strong, nullable) PPYesWeScanWrapper *scanWrapper;
@end

@implementation PPBecomeProviderBottomSheetViewController

- (instancetype)initWithState:(PPProviderOnboardingState *)state
          eligibleProviderTypes:(NSArray<NSNumber *> *)eligibleProviderTypes
          preferredProviderType:(PPProviderType)preferredProviderType {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _state = state;
        NSMutableArray<NSNumber *> *enabledTypes = [NSMutableArray array];
        for (NSNumber *typeValue in eligibleProviderTypes ?: @[]) {
            if (PPProviderTypeIsEnabledInProApp(typeValue.integerValue)) {
                [enabledTypes addObject:typeValue];
            }
        }
        _eligibleProviderTypes = enabledTypes.copy;
        if ([_eligibleProviderTypes containsObject:@(preferredProviderType)]) {
            _selectedProviderType = preferredProviderType;
        } else {
            _selectedProviderType = PPProviderTypeUnspecified;
        }
        _plans = @[];
        _selectedCountryCode = @"+974";
        _selectedCityIdentifier = @"";
        _selectedCoverageAreaKeys = @[];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.modalInPresentation = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(citiesDidUpdate:)
                                                 name:CitiesManagerDidUpdateNotification
                                               object:nil];
    [CitiesManager.shared loadData];
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_buildLayout];
    [self pp_prefillFromState];
    [self pp_reloadTypeButtons];
    [self pp_reloadPlans];
    [self pp_updateSubmitButtonState];
    [self pp_registerForKeyboardNotifications];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_forceBecomeProviderNavigationControls];
    [self pp_prepareEntranceAnimationState];
    [self pp_startAmbientMotionIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_forceBecomeProviderNavigationControls];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)pp_forceBecomeProviderNavigationControls {
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";

    UIView *bar = [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"BecomeProviderTitle") showBack:NO];

    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.translucent = YES;
    navBar.prefersLargeTitles = NO;

    if (bar) {
        bar.backgroundColor = UIColor.clearColor;

        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithTransparentBackground];
            appearance.backgroundColor = UIColor.clearColor;
            appearance.backgroundEffect = nil;
            appearance.shadowColor = UIColor.clearColor;
            appearance.titleTextAttributes = @{
                NSForegroundColorAttributeName: PPProviderSheetPrimaryTextColor(),
                NSFontAttributeName: [Styling fontBold:18.0]
            };
            navBar.standardAppearance = appearance;
            navBar.scrollEdgeAppearance = appearance;
            navBar.compactAppearance = appearance;
        } else {
            navBar.barTintColor = UIColor.clearColor;
            navBar.backgroundColor = UIColor.clearColor;
            [navBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            navBar.shadowImage = [UIImage new];
        }
    }

    [self pp_navBarRemoveButtonForKey:@"close"];
    [self pp_navBarSetLeftIcon:@"xmark" key:@"close" target:self action:@selector(closeTapped) tap:^{}];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self pp_stopAmbientMotion];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Layout

- (void)pp_buildLayout {
    [self pp_buildAmbientBackground];

    UIView *footerBar = [[UIView alloc] init];
    footerBar.translatesAutoresizingMaskIntoConstraints = NO;
    footerBar.backgroundColor = [PPProviderSheetBackgroundColor() colorWithAlphaComponent:0.68];
    [self.view addSubview:footerBar];

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *footerBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        UIVisualEffectView *footerBlurView = [[UIVisualEffectView alloc] initWithEffect:footerBlur];
        footerBlurView.translatesAutoresizingMaskIntoConstraints = NO;
        footerBlurView.userInteractionEnabled = NO;
        [footerBar addSubview:footerBlurView];
        [NSLayoutConstraint activateConstraints:@[
            [footerBlurView.topAnchor constraintEqualToAnchor:footerBar.topAnchor],
            [footerBlurView.leadingAnchor constraintEqualToAnchor:footerBar.leadingAnchor],
            [footerBlurView.trailingAnchor constraintEqualToAnchor:footerBar.trailingAnchor],
            [footerBlurView.bottomAnchor constraintEqualToAnchor:footerBar.bottomAnchor],
        ]];
    }

    UIView *footerHairline = [[UIView alloc] init];
    footerHairline.translatesAutoresizingMaskIntoConstraints = NO;
    footerHairline.backgroundColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.10];
    [footerBar addSubview:footerHairline];

    UILabel *footerHintLabel = [[UILabel alloc] init];
    footerHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerHintLabel.font = [Styling fontMedium:12.0];
    footerHintLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.92];
    footerHintLabel.numberOfLines = 2;
    footerHintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    footerHintLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [footerBar addSubview:footerHintLabel];
    self.footerHintLabel = footerHintLabel;

    UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    submitButton.layer.cornerRadius = 22.0;
    submitButton.layer.cornerCurve = kCACornerCurveContinuous;
    submitButton.titleLabel.font = [Styling fontBold:16.0];
    submitButton.contentEdgeInsets = UIEdgeInsetsMake(17.0, 18.0, 17.0, 18.0);
    submitButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [submitButton.heightAnchor constraintEqualToConstant:56.0].active = YES;
    [PPButtonHelper attachTapAnimationToButton:submitButton style:PPButtonAnimationStyleDefault];
    [footerBar addSubview:submitButton];
    self.submitButton = submitButton;

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    scrollView.delegate = self;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [scrollView addGestureRecognizer:tapGesture];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 18.0;
    contentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [scrollView addSubview:contentStack];
    self.contentStack = contentStack;

    self.footerBarBottomConstraint = [footerBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:footerBar.topAnchor],

        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:104.0],
        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:20.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-20.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-34.0],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-40.0],

        [footerBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [footerBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.footerBarBottomConstraint,

        [footerHairline.topAnchor constraintEqualToAnchor:footerBar.topAnchor],
        [footerHairline.leadingAnchor constraintEqualToAnchor:footerBar.leadingAnchor constant:20.0],
        [footerHairline.trailingAnchor constraintEqualToAnchor:footerBar.trailingAnchor constant:-20.0],
        [footerHairline.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [footerHintLabel.topAnchor constraintEqualToAnchor:footerBar.topAnchor constant:14.0],
        [footerHintLabel.leadingAnchor constraintEqualToAnchor:footerBar.leadingAnchor constant:20.0],
        [footerHintLabel.trailingAnchor constraintEqualToAnchor:footerBar.trailingAnchor constant:-20.0],

        [submitButton.topAnchor constraintEqualToAnchor:footerHintLabel.bottomAnchor constant:10.0],
        [submitButton.leadingAnchor constraintEqualToAnchor:footerBar.leadingAnchor constant:20.0],
        [submitButton.trailingAnchor constraintEqualToAnchor:footerBar.trailingAnchor constant:-20.0],

        [submitButton.bottomAnchor constraintEqualToAnchor:footerBar.bottomAnchor constant:-14.0],
    ]];

    [contentStack addArrangedSubview:[self pp_buildHeroSection]];

    [contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProviderTypeSectionTitle")
                                                                  subtitle:kLang(@"ProviderTypeSelectSubtitle")]];

    UIStackView *typeStack = [[UIStackView alloc] init];
    typeStack.translatesAutoresizingMaskIntoConstraints = NO;
    typeStack.axis = UILayoutConstraintAxisVertical;
    typeStack.alignment = UIStackViewAlignmentFill;
    typeStack.distribution = UIStackViewDistributionFill;
    typeStack.spacing = 10.0;
    typeStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentStack addArrangedSubview:typeStack];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSMutableArray<NSNumber *> *pendingRow = [NSMutableArray array];
    for (NSUInteger idx = 0; idx < self.eligibleProviderTypes.count; idx++) {
        NSNumber *typeValue = self.eligibleProviderTypes[idx];

        BOOL isMarketplace = (typeValue.integerValue == PPProviderTypeMarketplace);
        if (isMarketplace) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.tag = typeValue.integerValue;
            button.layer.cornerRadius = 18.0;
            button.layer.cornerCurve = kCACornerCurveContinuous;
            button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
            button.titleLabel.font = [Styling fontBold:14.0];
            button.titleLabel.numberOfLines = 2;
            button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            button.titleLabel.minimumScaleFactor = 0.88;
            button.titleLabel.adjustsFontSizeToFitWidth = YES;
            button.titleLabel.textAlignment = NSTextAlignmentCenter;
            button.contentEdgeInsets = UIEdgeInsetsMake(18.0, 16.0, 18.0, 16.0);
            button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
            [button addTarget:self action:@selector(typeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            [PPButtonHelper attachTapAnimationToButton:button style:PPButtonAnimationStylePulse];
            [button.heightAnchor constraintEqualToConstant:76.0].active = YES;
            [typeStack addArrangedSubview:button];
            [buttons addObject:button];
            continue;
        }

        [pendingRow addObject:typeValue];

        BOOL isLastItem = (idx == self.eligibleProviderTypes.count - 1);
        if (pendingRow.count < 2 && !isLastItem) {
            continue;
        }

        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.translatesAutoresizingMaskIntoConstraints = NO;
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.alignment = UIStackViewAlignmentFill;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = 10.0;
        rowStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [typeStack addArrangedSubview:rowStack];

        for (NSNumber *rowTypeValue in pendingRow) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.tag = rowTypeValue.integerValue;
            button.layer.cornerRadius = 18.0;
            button.layer.cornerCurve = kCACornerCurveContinuous;
            button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
            button.titleLabel.font = [Styling fontBold:14.0];
            button.titleLabel.numberOfLines = 2;
            button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            button.titleLabel.minimumScaleFactor = 0.88;
            button.titleLabel.adjustsFontSizeToFitWidth = YES;
            button.titleLabel.textAlignment = NSTextAlignmentCenter;
            button.contentEdgeInsets = UIEdgeInsetsMake(16.0, 14.0, 16.0, 14.0);
            button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
            [button addTarget:self action:@selector(typeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            [PPButtonHelper attachTapAnimationToButton:button style:PPButtonAnimationStylePulse];
            [button.heightAnchor constraintEqualToConstant:76.0].active = YES;
            [rowStack addArrangedSubview:button];
            [buttons addObject:button];
        }

        if (pendingRow.count == 1) {
            UIView *spacer = [[UIView alloc] init];
            spacer.translatesAutoresizingMaskIntoConstraints = NO;
            spacer.userInteractionEnabled = NO;
            [rowStack addArrangedSubview:spacer];
        }

        [pendingRow removeAllObjects];
    }
    self.typeButtons = buttons.copy;

    [contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProviderPlanSectionTitle")
                                                                  subtitle:kLang(@"ProviderPlansSelectPrompt")]];

    self.plansStateLabel = [[UILabel alloc] init];
    self.plansStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.plansStateLabel.font = [Styling fontMedium:12.0];
    self.plansStateLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.90];
    self.plansStateLabel.numberOfLines = 0;
    self.plansStateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.plansStateLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentStack addArrangedSubview:self.plansStateLabel];

    UIStackView *planStack = [[UIStackView alloc] init];
    planStack.translatesAutoresizingMaskIntoConstraints = NO;
    planStack.axis = UILayoutConstraintAxisVertical;
    planStack.spacing = 12.0;
    planStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.planStack = planStack;
    [contentStack addArrangedSubview:planStack];

    [contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProviderApplicationDetailsTitle")
                                                                  subtitle:kLang(@"ProviderApplicationDetailsSubtitle")]];
    [contentStack addArrangedSubview:[self pp_buildDetailsSurface]];
}

- (UIView *)pp_buildHeroSection {
    UIColor *accentColor = PPProviderSheetAccentColor();

    UIView *heroSurface = [[UIView alloc] init];
    heroSurface.translatesAutoresizingMaskIntoConstraints = NO;
    heroSurface.backgroundColor = [PPProviderSheetSurfaceColor() colorWithAlphaComponent:0.34];
    heroSurface.layer.cornerRadius = 34.0;
    heroSurface.layer.cornerCurve = kCACornerCurveContinuous;
    heroSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    heroSurface.layer.borderColor = [accentColor colorWithAlphaComponent:0.18].CGColor;
    heroSurface.layer.shadowColor = [PPProviderSheetShadowColor() CGColor];
    heroSurface.layer.shadowOffset = CGSizeMake(0.0, 22.0);
    heroSurface.layer.shadowRadius = 44.0;
    heroSurface.layer.shadowOpacity = 0.085;
    heroSurface.clipsToBounds = NO;
    self.heroSurfaceView = heroSurface;

    UIView *materialHost = [[UIView alloc] init];
    materialHost.translatesAutoresizingMaskIntoConstraints = NO;
    materialHost.clipsToBounds = YES;
    materialHost.layer.cornerRadius = 34.0;
    materialHost.layer.cornerCurve = kCACornerCurveContinuous;
    materialHost.userInteractionEnabled = NO;
    [heroSurface addSubview:materialHost];

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        [materialHost addSubview:blurView];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:materialHost.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:materialHost.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:materialHost.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:materialHost.bottomAnchor],
        ]];
    }

    UIView *heroGlowTop = [[UIView alloc] init];
    heroGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    heroGlowTop.userInteractionEnabled = NO;
    heroGlowTop.backgroundColor = [accentColor colorWithAlphaComponent:0.13];
    heroGlowTop.layer.cornerRadius = 88.0;
    heroGlowTop.layer.cornerCurve = kCACornerCurveContinuous;
    [materialHost addSubview:heroGlowTop];
    self.heroGlowTopView = heroGlowTop;

    UIView *heroGlowBottom = [[UIView alloc] init];
    heroGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    heroGlowBottom.userInteractionEnabled = NO;
    heroGlowBottom.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.055];
    heroGlowBottom.layer.cornerRadius = 104.0;
    heroGlowBottom.layer.cornerCurve = kCACornerCurveContinuous;
    [materialHost addSubview:heroGlowBottom];
    self.heroGlowBottomView = heroGlowBottom;

    UIView *liquidLine = [[UIView alloc] init];
    liquidLine.translatesAutoresizingMaskIntoConstraints = NO;
    liquidLine.userInteractionEnabled = NO;
    liquidLine.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.34];
    liquidLine.layer.cornerRadius = 1.0;
    [materialHost addSubview:liquidLine];
    self.heroLiquidLineView = liquidLine;

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [Styling fontBold:11.0];
    eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrowLabel.text = kLang(@"BecomeProviderEyebrow");
    [heroSurface addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:30.0];
    titleLabel.textColor = PPProviderSheetPrimaryTextColor();
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = kLang(@"BecomeProviderHeadline");
    [heroSurface addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:14.0];
    subtitleLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.92];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    subtitleLabel.text = kLang(@"BecomeProviderSubtitle");
    [heroSurface addSubview:subtitleLabel];

    self.heroTypePill = [[PPPaddingLabel alloc] init];
    self.heroTypePill.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTypePill.font = [Styling fontBold:12.0];
    self.heroTypePill.textInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    self.heroTypePill.textColor = accentColor;
    self.heroTypePill.backgroundColor = PPProviderSheetMatteColor();
    self.heroTypePill.layer.cornerRadius = 17.0;
    self.heroTypePill.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroTypePill.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.heroTypePill.layer.borderColor = [accentColor colorWithAlphaComponent:0.24].CGColor;
    self.heroTypePill.clipsToBounds = YES;
    [heroSurface addSubview:self.heroTypePill];

    self.heroFocusLabel = [[UILabel alloc] init];
    self.heroFocusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFocusLabel.font = [Styling fontMedium:13.0];
    self.heroFocusLabel.textColor = PPProviderSheetPrimaryTextColor();
    self.heroFocusLabel.numberOfLines = 2;
    self.heroFocusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [heroSurface addSubview:self.heroFocusLabel];

    UIView *heroStageView = [[UIView alloc] init];
    heroStageView.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageView.backgroundColor = [PPProviderSheetMatteColor() colorWithAlphaComponent:0.72];
    heroStageView.layer.cornerRadius = 30.0;
    heroStageView.layer.cornerCurve = kCACornerCurveContinuous;
    heroStageView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    heroStageView.layer.borderColor = [accentColor colorWithAlphaComponent:0.18].CGColor;
    heroStageView.layer.shadowColor = PPProviderSheetShadowColor().CGColor;
    heroStageView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    heroStageView.layer.shadowRadius = 22.0;
    heroStageView.layer.shadowOpacity = 0.08;
    [heroSurface addSubview:heroStageView];
    self.heroStageView = heroStageView;

    UIView *heroStageCore = [[UIView alloc] init];
    heroStageCore.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageCore.backgroundColor = PPProviderSheetSurfaceColor();
    heroStageCore.layer.cornerRadius = 20.0;
    heroStageCore.layer.cornerCurve = kCACornerCurveContinuous;
    [heroStageView addSubview:heroStageCore];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                              weight:UIImageSymbolWeightSemibold];
    self.heroStageIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill" withConfiguration:iconConfig]];
    self.heroStageIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStageIconView.tintColor = accentColor;
    [heroStageCore addSubview:self.heroStageIconView];

    [NSLayoutConstraint activateConstraints:@[
        [heroSurface.heightAnchor constraintGreaterThanOrEqualToConstant:318.0],

        [materialHost.topAnchor constraintEqualToAnchor:heroSurface.topAnchor],
        [materialHost.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor],
        [materialHost.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor],
        [materialHost.bottomAnchor constraintEqualToAnchor:heroSurface.bottomAnchor],

        [heroGlowTop.widthAnchor constraintEqualToConstant:176.0],
        [heroGlowTop.heightAnchor constraintEqualToConstant:176.0],
        [heroGlowTop.topAnchor constraintEqualToAnchor:materialHost.topAnchor constant:-58.0],
        [heroGlowTop.trailingAnchor constraintEqualToAnchor:materialHost.trailingAnchor constant:46.0],

        [heroGlowBottom.widthAnchor constraintEqualToConstant:208.0],
        [heroGlowBottom.heightAnchor constraintEqualToConstant:208.0],
        [heroGlowBottom.bottomAnchor constraintEqualToAnchor:materialHost.bottomAnchor constant:74.0],
        [heroGlowBottom.leadingAnchor constraintEqualToAnchor:materialHost.leadingAnchor constant:-70.0],

        [liquidLine.leadingAnchor constraintEqualToAnchor:materialHost.leadingAnchor constant:28.0],
        [liquidLine.trailingAnchor constraintEqualToAnchor:materialHost.trailingAnchor constant:-28.0],
        [liquidLine.topAnchor constraintEqualToAnchor:materialHost.topAnchor constant:1.0],
        [liquidLine.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [heroStageView.topAnchor constraintEqualToAnchor:heroSurface.topAnchor constant:28.0],
        [heroStageView.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-24.0],
        [heroStageView.widthAnchor constraintEqualToConstant:92.0],
        [heroStageView.heightAnchor constraintEqualToConstant:92.0],

        [heroStageCore.centerXAnchor constraintEqualToAnchor:heroStageView.centerXAnchor],
        [heroStageCore.centerYAnchor constraintEqualToAnchor:heroStageView.centerYAnchor],
        [heroStageCore.widthAnchor constraintEqualToConstant:40.0],
        [heroStageCore.heightAnchor constraintEqualToConstant:40.0],

        [self.heroStageIconView.centerXAnchor constraintEqualToAnchor:heroStageCore.centerXAnchor],
        [self.heroStageIconView.centerYAnchor constraintEqualToAnchor:heroStageCore.centerYAnchor],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:heroSurface.topAnchor constant:34.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:24.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:heroStageView.leadingAnchor constant:-16.0],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:8.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:heroStageView.leadingAnchor constant:-18.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-24.0],

        [self.heroTypePill.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:22.0],
        [self.heroTypePill.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [self.heroTypePill.trailingAnchor constraintLessThanOrEqualToAnchor:heroSurface.trailingAnchor constant:-24.0],

        [self.heroFocusLabel.topAnchor constraintEqualToAnchor:self.heroTypePill.bottomAnchor constant:10.0],
        [self.heroFocusLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [self.heroFocusLabel.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-24.0],
        [self.heroFocusLabel.bottomAnchor constraintEqualToAnchor:heroSurface.bottomAnchor constant:-30.0],
    ]];

    return heroSurface;
}

- (UIView *)pp_buildDetailsSurface {
    UIView *detailsSurface = [[UIView alloc] init];
    detailsSurface.translatesAutoresizingMaskIntoConstraints = NO;
    detailsSurface.backgroundColor = [PPProviderSheetMatteColor() colorWithAlphaComponent:0.74];
    detailsSurface.layer.cornerRadius = 24.0;
    detailsSurface.layer.cornerCurve = kCACornerCurveContinuous;
    detailsSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    detailsSurface.layer.borderColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.12].CGColor;
    detailsSurface.layer.shadowColor = [PPProviderSheetShadowColor() CGColor];
    detailsSurface.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    detailsSurface.layer.shadowRadius = 24.0;
    detailsSurface.layer.shadowOpacity = 0.055;
    detailsSurface.clipsToBounds = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [detailsSurface addSubview:stack];

    self.fullNameField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderFullNamePlaceholder") keyboard:UIKeyboardTypeDefault];
    self.phoneField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderPhonePlaceholder") keyboard:UIKeyboardTypePhonePad];
    self.emailField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderEmailPlaceholder") keyboard:UIKeyboardTypeEmailAddress];
    self.businessNameField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderBusinessNamePlaceholder") keyboard:UIKeyboardTypeDefault];
    self.companyNameField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderCompanyNamePlaceholder") keyboard:UIKeyboardTypeDefault];
    self.legalNameField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderLegalNamePlaceholder") keyboard:UIKeyboardTypeDefault];
    self.addressField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderAddressPlaceholder") keyboard:UIKeyboardTypeDefault];
    self.licenseNumberField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderLicenseNumberPlaceholder") keyboard:UIKeyboardTypeDefault];
    self.commercialRegistrationField = [self pp_makeTextFieldWithPlaceholder:kLang(@"ProviderCommercialRegistrationPlaceholder") keyboard:UIKeyboardTypeDefault];
    self.cityField = [self pp_makePickerFieldWithPlaceholder:kLang(@"ProviderCityPlaceholder")];
    self.coverageAreasField = [self pp_makePickerFieldWithPlaceholder:kLang(@"ProviderCoverageAreasPlaceholder")];

    self.emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.emailField.textContentType = UITextContentTypeEmailAddress;
    self.phoneField.textContentType = UITextContentTypeTelephoneNumber;

    self.notesView = [[UITextView alloc] init];
    self.notesView.translatesAutoresizingMaskIntoConstraints = NO;
    self.notesView.backgroundColor = UIColor.clearColor;
    self.notesView.textColor = PPProviderSheetPrimaryTextColor();
    self.notesView.font = [Styling fontMedium:15.0];
    self.notesView.delegate = self;
    self.notesView.textAlignment = Language.alignmentForCurrentLanguage;
    self.notesView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.notesView.textContainerInset = UIEdgeInsetsZero;
    self.notesView.textContainer.lineFragmentPadding = 0.0;

    UIView *phoneInputView = [self pp_buildPhoneInputView];

    NSArray<UIView *> *rows = @[
        [self pp_rowContainerWithTitle:kLang(@"ProviderFullNameField") inputView:self.fullNameField inputHeight:24.0 showSeparator:NO],
        [self pp_rowContainerWithTitle:kLang(@"ProviderPhoneField") inputView:phoneInputView inputHeight:44.0 showSeparator:NO],
        [self pp_rowContainerWithTitle:kLang(@"ProviderEmailField") inputView:self.emailField inputHeight:24.0 showSeparator:NO]
    ];
    for (UIView *row in rows) {
        [stack addArrangedSubview:row];
    }

    self.businessNameContainer = [self pp_rowContainerWithTitle:kLang(@"ProviderBusinessNameField") inputView:self.businessNameField inputHeight:24.0 showSeparator:NO];
    [stack addArrangedSubview:self.businessNameContainer];
    self.companyNameContainer = [self pp_rowContainerWithTitle:kLang(@"ProviderCompanyNameField") inputView:self.companyNameField inputHeight:24.0 showSeparator:NO];
    [stack addArrangedSubview:self.companyNameContainer];
    self.legalNameContainer = [self pp_rowContainerWithTitle:kLang(@"ProviderLegalNameField") inputView:self.legalNameField inputHeight:24.0 showSeparator:NO];
    [stack addArrangedSubview:self.legalNameContainer];
    self.addressContainer = [self pp_rowContainerWithTitle:kLang(@"ProviderAddressField") inputView:self.addressField inputHeight:24.0 showSeparator:NO];
    [stack addArrangedSubview:self.addressContainer];
    self.licenseNumberContainer = [self pp_buildDocumentCardWithTitle:kLang(@"ProviderLicenseNumberField") textField:self.licenseNumberField tag:100];
    [stack addArrangedSubview:self.licenseNumberContainer];
    self.commercialRegistrationContainer = [self pp_buildDocumentCardWithTitle:kLang(@"ProviderCommercialRegistrationField") textField:self.commercialRegistrationField tag:200];
    [stack addArrangedSubview:self.commercialRegistrationContainer];

    [stack addArrangedSubview:[self pp_rowContainerWithTitle:kLang(@"ProviderCityField") inputView:self.cityField inputHeight:24.0 showSeparator:NO]];
    [stack addArrangedSubview:[self pp_rowContainerWithTitle:kLang(@"ProviderCoverageAreasField") inputView:self.coverageAreasField inputHeight:24.0 showSeparator:NO]];
    [stack addArrangedSubview:[self pp_rowContainerWithTitle:kLang(@"ProviderNotesField") inputView:self.notesView inputHeight:94.0 showSeparator:NO]];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:detailsSurface.topAnchor constant:16.0],
        [stack.leadingAnchor constraintEqualToAnchor:detailsSurface.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:detailsSurface.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:detailsSurface.bottomAnchor constant:-16.0],
    ]];

    return detailsSurface;
}

#pragma mark - Premium Document Attachment Card

static NSInteger const PPDCAttachTagLicense = 100;
static NSInteger const PPDCAttachTagCommercialReg = 200;

- (UIView *)pp_buildDocumentCardWithTitle:(NSString *)title textField:(UITextField *)textField tag:(NSInteger)tag {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    card.backgroundColor = PPProviderSheetSurfaceColor();
    card.layer.cornerRadius = 20.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.075].CGColor;
    card.layer.shadowColor = PPProviderSheetShadowColor().CGColor;
    card.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    card.layer.shadowRadius = 18.0;
    card.layer.shadowOpacity = 0.035;

    UIView *accentView = [[UIView alloc] init];
    accentView.translatesAutoresizingMaskIntoConstraints = NO;
    accentView.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.72];
    accentView.layer.cornerRadius = 1.5;
    accentView.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:accentView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:11.5];
    titleLabel.textColor = [PPProviderSheetPrimaryTextColor() colorWithAlphaComponent:0.82];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.88;
    titleLabel.text = title;
    [card addSubview:titleLabel];

    UIView *fieldSurface = [[UIView alloc] init];
    fieldSurface.translatesAutoresizingMaskIntoConstraints = NO;
    fieldSurface.backgroundColor = [PPProviderSheetSoftFillColor() colorWithAlphaComponent:0.42];
    fieldSurface.layer.cornerRadius = 16.0;
    fieldSurface.layer.cornerCurve = kCACornerCurveContinuous;
    fieldSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    fieldSurface.layer.borderColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.09].CGColor;
    [card addSubview:fieldSurface];
    [fieldSurface addSubview:textField];

    UIStackView *attachZone = [self pp_buildAttachmentZoneWithTag:tag];
    attachZone.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:attachZone];
    if (tag == PPDCAttachTagLicense) {
        self.licenseAttachZone = attachZone;
    } else {
        self.commercialAttachZone = attachZone;
    }

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.08];
    [card addSubview:divider];

    [NSLayoutConstraint activateConstraints:@[
        [accentView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [accentView.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [accentView.widthAnchor constraintEqualToConstant:3.0],
        [accentView.heightAnchor constraintEqualToConstant:22.0],

        [titleLabel.centerYAnchor constraintEqualToAnchor:accentView.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentView.trailingAnchor constant:9.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [fieldSurface.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [fieldSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [fieldSurface.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [fieldSurface.heightAnchor constraintGreaterThanOrEqualToConstant:46.0],

        [textField.topAnchor constraintEqualToAnchor:fieldSurface.topAnchor constant:11.0],
        [textField.leadingAnchor constraintEqualToAnchor:fieldSurface.leadingAnchor constant:12.0],
        [textField.trailingAnchor constraintEqualToAnchor:fieldSurface.trailingAnchor constant:-12.0],
        [textField.bottomAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor constant:-11.0],

        [divider.topAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor constant:10.0],
        [divider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [divider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [attachZone.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8.0],
        [attachZone.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [attachZone.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [attachZone.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10.0],
    ]];

    return card;
}

- (UIStackView *)pp_buildAttachmentZoneWithTag:(NSInteger)tag {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10.0;
    stack.distribution = UIStackViewDistributionFill;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    stack.userInteractionEnabled = YES;
    stack.tag = tag;

    UIImageView *thumbView = [[UIImageView alloc] init];
    thumbView.translatesAutoresizingMaskIntoConstraints = NO;
    thumbView.contentMode = UIViewContentModeScaleAspectFill;
    thumbView.clipsToBounds = YES;
    thumbView.layer.cornerRadius = 8.0;
    thumbView.layer.cornerCurve = kCACornerCurveContinuous;
    thumbView.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.06];
    thumbView.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [thumbView.widthAnchor constraintEqualToConstant:36.0],
        [thumbView.heightAnchor constraintEqualToConstant:36.0],
    ]];
    [stack addArrangedSubview:thumbView];
    if (tag == PPDCAttachTagLicense) {
        self.licenseThumbView = thumbView;
    } else {
        self.commercialThumbView = thumbView;
    }

    UILabel *stateLabel = [[UILabel alloc] init];
    stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stateLabel.font = [Styling fontMedium:13.0];
    stateLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.72];
    stateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    stateLabel.numberOfLines = 1;
    stateLabel.text = kLang(@"ProviderAttachDocumentHint");
    [stack addArrangedSubview:stateLabel];

    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    spacer.backgroundColor = UIColor.clearColor;
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [stack addArrangedSubview:spacer];

    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    actionButton.tag = tag;
    UIImage *attachIcon = [UIImage systemImageNamed:@"doc.badge.plus"];
    [actionButton setImage:attachIcon forState:UIControlStateNormal];
    actionButton.tintColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.72];
    actionButton.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.08];
    actionButton.layer.cornerRadius = 18.0;
    actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    actionButton.accessibilityLabel = kLang(@"ProviderAttachDocumentHint");
    [actionButton addTarget:self action:@selector(pp_attachButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [actionButton.widthAnchor constraintEqualToConstant:36.0],
        [actionButton.heightAnchor constraintEqualToConstant:36.0],
    ]];
    [stack addArrangedSubview:actionButton];

    UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    removeButton.tag = tag;
    removeButton.hidden = YES;
    UIImage *removeIcon = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [removeButton setImage:removeIcon forState:UIControlStateNormal];
    removeButton.tintColor = [[UIColor ppError] colorWithAlphaComponent:0.72];
    removeButton.backgroundColor = UIColor.clearColor;
    [removeButton addTarget:self action:@selector(pp_removeDocumentTapped:) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [removeButton.widthAnchor constraintEqualToConstant:28.0],
        [removeButton.heightAnchor constraintEqualToConstant:28.0],
    ]];
    [stack addArrangedSubview:removeButton];

    return stack;
}

- (void)pp_updateAttachmentZoneForTag:(NSInteger)tag {
    BOOL isLicense = (tag == PPDCAttachTagLicense);
    UIStackView *attachZone = (UIStackView *)(isLicense ? self.licenseAttachZone : self.commercialAttachZone);
    UIImageView *thumbView = isLicense ? self.licenseThumbView : self.commercialThumbView;
    NSString *docURL = isLicense ? self.licenseDocumentURL : self.commercialRegDocumentURL;
    BOOL isUploading = isLicense ? self.isUploadingLicense : self.isUploadingCommercialReg;

    UILabel *stateLabel = (UILabel *)attachZone.arrangedSubviews[1];
    UIButton *actionButton = (UIButton *)attachZone.arrangedSubviews[3];
    UIButton *removeButton = (UIButton *)attachZone.arrangedSubviews[4];

    if (isUploading) {
        thumbView.hidden = YES;
        stateLabel.text = kLang(@"ProviderUploadingDocument");
        stateLabel.textColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.82];
        actionButton.hidden = YES;
        removeButton.hidden = YES;
        return;
    }

    if (docURL.length > 0) {
        thumbView.hidden = NO;
        UIImage *docIcon = [UIImage systemImageNamed:@"doc.text.fill"];
        thumbView.image = docIcon;
        thumbView.tintColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.72];
        thumbView.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.08];
        stateLabel.text = kLang(@"ProviderDocumentAttached");
        stateLabel.textColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.82];
        actionButton.hidden = YES;
        removeButton.hidden = NO;
    } else {
        thumbView.hidden = YES;
        stateLabel.text = kLang(@"ProviderAttachDocumentHint");
        stateLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.72];
        actionButton.hidden = NO;
        removeButton.hidden = YES;
    }
}

- (void)pp_attachButtonTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"ProviderAttachCamera") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pp_presentCameraForTag:tag];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"ProviderAttachPhotoLibrary") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pp_presentPhotoPickerForTag:tag];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"ProviderAttachFiles") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pp_presentDocumentPickerForTag:tag];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"ProviderAttachScan") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pp_presentScanForTag:tag];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_presentCameraForTag:(NSInteger)tag {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [PPToast toast:kLang(@"ProviderCameraUnavailable") style:PPToastStyleWarning haptic:YES duration:1.5];
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    PPSetPickerTag(picker, tag);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pp_presentPhotoPickerForTag:(NSInteger)tag {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    PPSetPickerTag(picker, tag);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pp_presentDocumentPickerForTag:(NSInteger)tag {
    NSArray *types = @[UTTypePDF, UTTypePNG, UTTypeJPEG, UTTypeImage];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    PPSetPickerTag(picker, tag);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pp_presentScanForTag:(NSInteger)tag {
    self.scanWrapper = [[PPYesWeScanWrapper alloc] init];
    self.scanWrapper.delegate = self;
    [self.scanWrapper presentScannerFrom:self withTag:tag];
}

- (void)pp_handleImage:(UIImage *)image forTag:(NSInteger)tag {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isLicense = (tag == PPDCAttachTagLicense);
        if (isLicense) {
            self.isUploadingLicense = YES;
        } else {
            self.isUploadingCommercialReg = YES;
        }
        [self pp_updateAttachmentZoneForTag:tag];
        [self pp_uploadDocumentImage:image forTag:tag];
    });
}

- (void)pp_uploadDocumentImage:(UIImage *)image forTag:(NSInteger)tag {
    FIRUser *user = [FIRAuth auth].currentUser;
    if (!user) {
        [PPToast toast:kLang(@"Error") style:PPToastStyleError haptic:YES duration:1.5];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat maxDim = 1200.0;
        UIImage *scaled = image;
        if (image.size.width > maxDim || image.size.height > maxDim) {
            CGFloat scale = maxDim / MAX(image.size.width, image.size.height);
            CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
            UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
            [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            scaled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        NSData *jpegData = UIImageJPEGRepresentation(scaled, 0.75);
        if (!jpegData) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self pp_didFailUploadForTag:tag]; });
            return;
        }

        NSString *suffix = (tag == PPDCAttachTagLicense) ? @"license" : @"commercial_reg";
        NSString *path = [NSString stringWithFormat:@"provider_applications/%@/%@_%lld.jpg",
                          user.uid, suffix, (long long)([[NSDate date] timeIntervalSince1970] * 1000)];

        FIRStorage *storage = [FIRStorage storage];
        FIRStorageReference *ref = [storage.reference child:path];
        FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
        meta.contentType = @"image/jpeg";

        FIRStorageUploadTask *task = [ref putData:jpegData metadata:meta];
        [task observeStatus:FIRStorageTaskStatusSuccess handler:^(FIRStorageTaskSnapshot *snap) {
            [ref downloadURLWithCompletion:^(NSURL *url, NSError *urlError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (url && !urlError) {
                        [self pp_didUploadDocumentURL:url.absoluteString forTag:tag];
                    } else {
                        [self pp_didFailUploadForTag:tag];
                    }
                });
            }];
        }];
        [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snap) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self pp_didFailUploadForTag:tag];
            });
        }];
    });
}

- (void)pp_didUploadDocumentURL:(NSString *)urlString forTag:(NSInteger)tag {
    BOOL isLicense = (tag == PPDCAttachTagLicense);
    if (isLicense) {
        self.licenseDocumentURL = urlString;
        self.isUploadingLicense = NO;
    } else {
        self.commercialRegDocumentURL = urlString;
        self.isUploadingCommercialReg = NO;
    }
    [self pp_updateAttachmentZoneForTag:tag];
    [PPToast toast:kLang(@"ProviderDocumentUploaded") style:PPToastStyleSuccess haptic:YES duration:1.5];
}

- (void)pp_didFailUploadForTag:(NSInteger)tag {
    BOOL isLicense = (tag == PPDCAttachTagLicense);
    if (isLicense) {
        self.isUploadingLicense = NO;
    } else {
        self.isUploadingCommercialReg = NO;
    }
    [self pp_updateAttachmentZoneForTag:tag];
    [PPToast toast:kLang(@"ProviderUploadFailed") style:PPToastStyleError haptic:YES duration:1.5];
}

- (void)pp_removeDocumentTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    BOOL isLicense = (tag == PPDCAttachTagLicense);
    if (isLicense) {
        self.licenseDocumentURL = @"";
    } else {
        self.commercialRegDocumentURL = @"";
    }
    [self pp_updateAttachmentZoneForTag:tag];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    NSInteger tag = PPGetPickerTag(picker);
    [picker dismissViewControllerAnimated:YES completion:^{
        if (image) {
            [self pp_handleImage:image forTag:tag];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSInteger tag = PPGetPickerTag(picker);
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) return;
    [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
        UIImage *image = (UIImage *)object;
        if (image) {
            [self pp_handleImage:image forTag:tag];
        }
    }];
}

#pragma mark - UIDocumentPickerViewControllerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSInteger tag = PPGetPickerTag(controller);
    NSURL *fileURL = urls.firstObject;
    if (!fileURL) return;
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:fileURL]];
    if (image) {
        [self pp_handleImage:image forTag:tag];
    } else {
        [PPToast toast:kLang(@"ProviderUnsupportedFile") style:PPToastStyleWarning haptic:YES duration:1.5];
    }
}

#pragma mark - VNDocumentCameraViewControllerDelegate

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFinishWithScan:(VNDocumentCameraScan *)scan {
    NSInteger tag = PPGetPickerTag(controller);
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (scan.pageCount > 0) {
        UIImage *image = [scan imageOfPageAtIndex:0];
        [self pp_handleImage:image forTag:tag];
    }
}

- (void)documentCameraViewControllerDidCancel:(VNDocumentCameraViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFailWithError:(NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:nil];
    [PPToast toast:kLang(@"ProviderScanFailed") style:PPToastStyleError haptic:YES duration:1.5];
}

#pragma mark - PPYesWeScanWrapperDelegate

- (void)yesWeScanWrapper:(PPYesWeScanWrapper *)wrapper didCaptureImage:(UIImage *)image forTag:(NSInteger)tag {
    [self pp_handleImage:image forTag:tag];
    self.scanWrapper = nil;
}

- (UILabel *)pp_sectionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:12.0];
    label.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.92];
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.text = text;
    return label;
}

- (UIView *)pp_buildSectionHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:18.0];
    titleLabel.textColor = PPProviderSheetPrimaryTextColor();
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 2;
    titleLabel.text = title;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontMedium:12.0];
    subtitleLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.82];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = subtitle;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)pp_rowContainerWithTitle:(NSString *)title inputView:(UIView *)inputView inputHeight:(CGFloat)inputHeight showSeparator:(BOOL)showSeparator {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    container.backgroundColor = PPProviderSheetSurfaceColor();
    container.layer.cornerRadius = 20.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    container.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.075].CGColor;
    container.layer.shadowColor = PPProviderSheetShadowColor().CGColor;
    container.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    container.layer.shadowRadius = 18.0;
    container.layer.shadowOpacity = 0.035;

    UIView *accentView = [[UIView alloc] init];
    accentView.translatesAutoresizingMaskIntoConstraints = NO;
    accentView.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.72];
    accentView.layer.cornerRadius = 1.5;
    accentView.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:accentView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:11.5];
    titleLabel.textColor = [PPProviderSheetPrimaryTextColor() colorWithAlphaComponent:0.82];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.88;
    titleLabel.text = title;
    [container addSubview:titleLabel];

    BOOL isCompositeInput = [inputView isKindOfClass:[UIStackView class]];
    CGFloat fieldVerticalInset = isCompositeInput ? 0.0 : 11.0;
    CGFloat fieldHorizontalInset = isCompositeInput ? 0.0 : 12.0;

    UIView *fieldSurface = [[UIView alloc] init];
    fieldSurface.translatesAutoresizingMaskIntoConstraints = NO;
    fieldSurface.backgroundColor = isCompositeInput ? UIColor.clearColor : [PPProviderSheetSoftFillColor() colorWithAlphaComponent:0.42];
    fieldSurface.layer.cornerRadius = isCompositeInput ? 0.0 : 16.0;
    fieldSurface.layer.cornerCurve = kCACornerCurveContinuous;
    fieldSurface.layer.borderWidth = isCompositeInput ? 0.0 : (1.0 / UIScreen.mainScreen.scale);
    fieldSurface.layer.borderColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.09].CGColor;
    [container addSubview:fieldSurface];
    [fieldSurface addSubview:inputView];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [accentView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],
        [accentView.topAnchor constraintEqualToAnchor:container.topAnchor constant:16.0],
        [accentView.widthAnchor constraintEqualToConstant:3.0],
        [accentView.heightAnchor constraintEqualToConstant:22.0],

        [titleLabel.centerYAnchor constraintEqualToAnchor:accentView.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentView.trailingAnchor constant:9.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14.0],

        [fieldSurface.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [fieldSurface.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [fieldSurface.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],
        [fieldSurface.heightAnchor constraintGreaterThanOrEqualToConstant:(inputHeight + (fieldVerticalInset * 2.0))],

        [inputView.topAnchor constraintEqualToAnchor:fieldSurface.topAnchor constant:fieldVerticalInset],
        [inputView.leadingAnchor constraintEqualToAnchor:fieldSurface.leadingAnchor constant:fieldHorizontalInset],
        [inputView.trailingAnchor constraintEqualToAnchor:fieldSurface.trailingAnchor constant:-fieldHorizontalInset],
        [inputView.bottomAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor constant:-fieldVerticalInset],
        [inputView.heightAnchor constraintGreaterThanOrEqualToConstant:inputHeight],
    ]];

    UIView *separator = nil;
    if (showSeparator) {
        separator = [[UIView alloc] init];
        separator.translatesAutoresizingMaskIntoConstraints = NO;
        separator.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.08];
        [container addSubview:separator];
        [constraints addObjectsFromArray:@[
            [fieldSurface.bottomAnchor constraintEqualToAnchor:separator.topAnchor constant:-14.0],
            [separator.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],
            [separator.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14.0],
            [separator.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
            [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        ]];
    } else {
        [constraints addObject:[fieldSurface.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12.0]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
    return container;
}

- (UIView *)pp_buildPhoneInputView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10.0;
    stack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    UIButton *countryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    countryButton.translatesAutoresizingMaskIntoConstraints = NO;
    countryButton.backgroundColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.10];
    countryButton.layer.cornerRadius = 16.0;
    countryButton.layer.cornerCurve = kCACornerCurveContinuous;
    countryButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    countryButton.layer.borderColor = [PPProviderSheetAccentColor() colorWithAlphaComponent:0.28].CGColor;
    countryButton.titleLabel.font = [Styling fontBold:14.0];
    countryButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    countryButton.titleLabel.minimumScaleFactor = 0.86;
    countryButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
    countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    countryButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [countryButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [countryButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [countryButton addTarget:self action:@selector(countryCodeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:countryButton style:PPButtonAnimationStylePulse];
    [countryButton.widthAnchor constraintEqualToConstant:94.0].active = YES;
    [countryButton.heightAnchor constraintEqualToConstant:44.0].active = YES;
    self.countryCodeButton = countryButton;

    UIView *phoneFieldShell = [[UIView alloc] init];
    phoneFieldShell.translatesAutoresizingMaskIntoConstraints = NO;
    phoneFieldShell.backgroundColor = PPProviderSheetSurfaceColor();
    phoneFieldShell.layer.cornerRadius = 16.0;
    phoneFieldShell.layer.cornerCurve = kCACornerCurveContinuous;
    phoneFieldShell.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    phoneFieldShell.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.08].CGColor;
    phoneFieldShell.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [phoneFieldShell setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [phoneFieldShell setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.phoneField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.phoneField.textAlignment = NSTextAlignmentRight;
    [phoneFieldShell addSubview:self.phoneField];

    [NSLayoutConstraint activateConstraints:@[
        [self.phoneField.topAnchor constraintEqualToAnchor:phoneFieldShell.topAnchor constant:10.0],
        [self.phoneField.leadingAnchor constraintEqualToAnchor:phoneFieldShell.leadingAnchor constant:13.0],
        [self.phoneField.trailingAnchor constraintEqualToAnchor:phoneFieldShell.trailingAnchor constant:-13.0],
        [self.phoneField.bottomAnchor constraintEqualToAnchor:phoneFieldShell.bottomAnchor constant:-10.0],
        [phoneFieldShell.heightAnchor constraintEqualToConstant:44.0],
    ]];

    [stack addArrangedSubview:countryButton];
    [stack addArrangedSubview:phoneFieldShell];
    [self pp_updateCountryCodeButton];
    return stack;
}

- (UITextField *)pp_makeTextFieldWithPlaceholder:(NSString *)placeholder keyboard:(UIKeyboardType)keyboardType {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.backgroundColor = UIColor.clearColor;
    field.textColor = PPProviderSheetPrimaryTextColor();
    field.font = [Styling fontMedium:15.0];
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                   attributes:@{
        NSFontAttributeName: [Styling fontMedium:14.0],
        NSForegroundColorAttributeName: [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.66]
    }];
    field.keyboardType = keyboardType;
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    field.delegate = self;
    [field addTarget:self action:@selector(fieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    return field;
}

- (UITextField *)pp_makePickerFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [self pp_makeTextFieldWithPlaceholder:placeholder keyboard:UIKeyboardTypeDefault];
    field.tintColor = UIColor.clearColor;
    field.inputView = [[UIView alloc] initWithFrame:CGRectZero];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;

    UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:chevronConfig]];
    chevron.tintColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.72];
    chevron.contentMode = UIViewContentModeCenter;
    chevron.frame = CGRectMake(0, 0, 28.0, 24.0);
    field.rightView = chevron;
    field.rightViewMode = UITextFieldViewModeAlways;
    field.accessibilityTraits = UIAccessibilityTraitButton;
    return field;
}

- (void)pp_buildAmbientBackground {
    UIView *glowTop = [[UIView alloc] init];
    glowTop.translatesAutoresizingMaskIntoConstraints = NO;
    glowTop.backgroundColor = [PPProviderSheetSoftFillColor() colorWithAlphaComponent:0.42];
    glowTop.layer.cornerRadius = 140.0;
    glowTop.layer.cornerCurve = kCACornerCurveContinuous;
    glowTop.userInteractionEnabled = NO;
    [self.view insertSubview:glowTop atIndex:0];

    UIView *glowBottom = [[UIView alloc] init];
    glowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    glowBottom.backgroundColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.045];
    glowBottom.layer.cornerRadius = 160.0;
    glowBottom.layer.cornerCurve = kCACornerCurveContinuous;
    glowBottom.userInteractionEnabled = NO;
    [self.view insertSubview:glowBottom atIndex:0];
    self.ambientTopView = glowTop;
    self.ambientBottomView = glowBottom;

    [NSLayoutConstraint activateConstraints:@[
        [glowTop.widthAnchor constraintEqualToConstant:280.0],
        [glowTop.heightAnchor constraintEqualToConstant:280.0],
        [glowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-80.0],
        [glowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:60.0],

        [glowBottom.widthAnchor constraintEqualToConstant:320.0],
        [glowBottom.heightAnchor constraintEqualToConstant:320.0],
        [glowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:100.0],
        [glowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-80.0],
    ]];

    glowTop.alpha = 0.70;
    glowBottom.alpha = 0.82;
    glowTop.transform = CGAffineTransformMakeScale(0.94, 0.94);
    glowBottom.transform = CGAffineTransformMakeScale(0.98, 0.98);
}

- (void)pp_startAmbientMotionIfNeeded {
    if (self.ambientMotionRunning || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.ambientMotionRunning = YES;
    [self.ambientTopView.layer removeAnimationForKey:@"pp_matte_breathe"];
    [self.ambientBottomView.layer removeAnimationForKey:@"pp_matte_breathe"];
    [self.heroGlowTopView.layer removeAllAnimations];
    [self.heroGlowBottomView.layer removeAllAnimations];
    [self.heroLiquidLineView.layer removeAllAnimations];

    [UIView animateWithDuration:6.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientTopView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-10.0, 16.0),
                                                                CGAffineTransformMakeScale(1.06, 1.06));
        self.ambientTopView.alpha = 0.46;
    } completion:nil];

    [UIView animateWithDuration:7.4
                          delay:0.35
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientBottomView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(12.0, -12.0),
                                                                   CGAffineTransformMakeScale(1.04, 1.04));
        self.ambientBottomView.alpha = 0.58;
    } completion:nil];

    [UIView animateWithDuration:5.8
                          delay:0.15
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroGlowTopView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-16.0, 14.0),
                                                                 CGAffineTransformMakeScale(1.10, 1.10));
        self.heroGlowTopView.alpha = 0.68;
    } completion:nil];

    [UIView animateWithDuration:6.8
                          delay:0.55
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroGlowBottomView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(14.0, -10.0),
                                                                    CGAffineTransformMakeScale(1.08, 1.08));
        self.heroGlowBottomView.alpha = 0.78;
    } completion:nil];

    [UIView animateWithDuration:4.6
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroLiquidLineView.alpha = 0.42;
        self.heroLiquidLineView.transform = CGAffineTransformMakeScale(0.88, 1.0);
    } completion:nil];
}

- (void)pp_stopAmbientMotion {
    self.ambientMotionRunning = NO;
    [self.ambientTopView.layer removeAllAnimations];
    [self.ambientBottomView.layer removeAllAnimations];
    [self.heroGlowTopView.layer removeAllAnimations];
    [self.heroGlowBottomView.layer removeAllAnimations];
    [self.heroLiquidLineView.layer removeAllAnimations];
}

#pragma mark - State

- (void)closeTapped {
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UIViewController *rootController = self.view.window.rootViewController;
    if (rootController.presentedViewController) {
        [rootController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_prefillFromState {
    self.fullNameField.text = self.state.displayName ?: @"";
    [self pp_applyPrefilledPhone:self.state.phone ?: @""];
    self.emailField.text = self.state.email ?: @"";
    [self pp_updateCountryCodeButton];
    [self pp_applyProviderFormPrefillForType:self.selectedProviderType];
}

- (void)citiesDidUpdate:(NSNotification *)note {
    NSString *storedPhone = [PPSafeString(self.state.phone) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *currentPhoneText = [PPSafeString(self.phoneField.text) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (storedPhone.length > 0 && ([currentPhoneText isEqualToString:storedPhone] || [currentPhoneText hasPrefix:@"+"])) {
        [self pp_applyPrefilledPhone:storedPhone];
        [self pp_updateCountryCodeButton];
    }
    if (self.lastAppliedProviderType != PPProviderTypeUnspecified) {
        [self pp_applyProviderFormPrefillForType:self.lastAppliedProviderType];
    }
}

- (NSDictionary *)pp_providerFormForType:(PPProviderType)type {
    if (type == PPProviderTypeUnspecified) {
        return @{};
    }
    PPProviderApplication *application = [self.state applicationForType:type];
    if ([application.form isKindOfClass:NSDictionary.class] && application.form.count > 0) {
        return application.form;
    }
    PPProviderProfile *profile = [self.state profileForType:type];
    if ([profile.form isKindOfClass:NSDictionary.class] && profile.form.count > 0) {
        return profile.form;
    }
    return @{};
}

- (NSDictionary *)pp_cityOptionMatchingStoredValue:(NSString *)storedValue {
    NSString *trimmed = [PPSafeString(storedValue) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }

    NSString *lowerTrimmed = trimmed.lowercaseString;
    for (NSDictionary *option in PPProviderQatarCityOptions()) {
        NSString *value = PPProviderSheetOptionValue(option);
        NSString *title = PPProviderSheetOptionTitle(option);
        if ([value.lowercaseString isEqualToString:lowerTrimmed] ||
            [title.lowercaseString isEqualToString:lowerTrimmed]) {
            return option;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)pp_coverageAreaKeysMatchingStoredValues:(NSArray *)storedValues cityID:(NSString *)cityID {
    if (![storedValues isKindOfClass:NSArray.class] || cityID.length == 0) {
        return @[];
    }

    NSDictionary *city = PPProviderQatarCityOptionForID(cityID);
    NSArray<NSString *> *areaKeys = [city[@"areaKeys"] isKindOfClass:NSArray.class] ? city[@"areaKeys"] : @[];
    NSMutableArray<NSString *> *matchedKeys = [NSMutableArray array];

    for (id rawValue in storedValues) {
        NSString *stored = [PPSafeString(rawValue) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (stored.length == 0) {
            continue;
        }
        NSString *lowerStored = stored.lowercaseString;
        for (NSString *areaKey in areaKeys) {
            NSString *localizedTitle = PPSafeString(kLang(areaKey));
            if ([areaKey.lowercaseString isEqualToString:lowerStored] ||
                [localizedTitle.lowercaseString isEqualToString:lowerStored]) {
                [matchedKeys addObject:areaKey];
                break;
            }
        }
    }

    return matchedKeys.copy;
}




- (void)pp_applyProviderFormPrefillForType:(PPProviderType)type {
    self.lastAppliedProviderType = type;
    NSDictionary *form = [self pp_providerFormForType:type];
    if (form.count == 0) {
        self.businessNameField.text = @"";
        self.companyNameField.text = @"";
        self.legalNameField.text = @"";
        self.addressField.text = @"";
        self.licenseNumberField.text = @"";
        self.commercialRegistrationField.text = @"";
        self.notesView.text = @"";
        self.licenseDocumentURL = @"";
        self.commercialRegDocumentURL = @"";
        self.selectedCityIdentifier = @"";
        self.selectedCoverageAreaKeys = @[];
        self.cityField.text = @"";
        self.coverageAreasField.text = @"";
        [self pp_updateAttachmentZoneForTag:PPDCAttachTagLicense];
        [self pp_updateAttachmentZoneForTag:PPDCAttachTagCommercialReg];
        return;
    }

    self.businessNameField.text = PPSafeString(form[@"businessName"]);
    self.companyNameField.text = PPSafeString(form[@"companyName"]);
    self.legalNameField.text = PPSafeString(form[@"legalName"]);
    self.addressField.text = PPSafeString(form[@"address"]);
    self.licenseNumberField.text = PPSafeString(form[@"licenseNumber"]);
    self.commercialRegistrationField.text = PPSafeString(form[@"commercialRegistrationNumber"]);
    self.notesView.text = PPSafeString(form[@"notes"]);
    self.licenseDocumentURL = PPSafeString(form[@"licenseDocumentURL"]);
    self.commercialRegDocumentURL = PPSafeString(form[@"commercialRegistrationDocumentURL"]);

    NSDictionary *cityOption = [self pp_cityOptionMatchingStoredValue:PPSafeString(form[@"city"])];
    self.selectedCityIdentifier = PPProviderSheetOptionValue(cityOption);
    self.cityField.text = PPProviderSheetOptionTitle(cityOption);
    self.selectedCoverageAreaKeys = [self pp_coverageAreaKeysMatchingStoredValues:form[@"coverageAreas"]
                                                                            cityID:self.selectedCityIdentifier];
    [self pp_updateCoverageAreasDisplay];
    [self pp_updateAttachmentZoneForTag:PPDCAttachTagLicense];
    [self pp_updateAttachmentZoneForTag:PPDCAttachTagCommercialReg];
}

- (void)pp_applyPrefilledPhone:(NSString *)phone {
    NSString *trimmedPhone = [PPSafeString(phone) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedPhone.length == 0) {
        self.selectedCountryCode = self.selectedCountryCode.length ? self.selectedCountryCode : @"+974";
        self.phoneField.text = @"";
        return;
    }

    for (NSDictionary *option in PPProviderCountryCodeOptions()) {
        NSString *code = PPProviderSheetOptionValue(option);
        if (code.length > 0 && [trimmedPhone hasPrefix:code]) {
            self.selectedCountryCode = code;
            NSString *localNumber = [trimmedPhone substringFromIndex:code.length];
            self.phoneField.text = [localNumber stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            return;
        }
    }

    self.selectedCountryCode = self.selectedCountryCode.length ? self.selectedCountryCode : @"+974";
    self.phoneField.text = trimmedPhone;
}

- (void)pp_updateCountryCodeButton {
    NSString *code = self.selectedCountryCode.length ? self.selectedCountryCode : @"+974";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightBold];
    UIImage *image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:config];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.baseWritingDirection = NSWritingDirectionLeftToRight;
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:code attributes:@{
        NSFontAttributeName: [Styling fontBold:14.0],
        NSForegroundColorAttributeName: PPProviderSheetPrimaryTextColor(),
        NSParagraphStyleAttributeName: paragraph
    }];
    [self.countryCodeButton setTitle:nil forState:UIControlStateNormal];
    [self.countryCodeButton setAttributedTitle:attributedTitle forState:UIControlStateNormal];
    [self.countryCodeButton setImage:image forState:UIControlStateNormal];
    self.countryCodeButton.tintColor = PPProviderSheetAccentColor();
    self.countryCodeButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"ProviderCountryCodeField"), code];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.attributedTitle = attributedTitle;
        configuration.image = image;
        configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
        configuration.imagePadding = 6.0;
        configuration.baseForegroundColor = PPProviderSheetPrimaryTextColor();
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
        self.countryCodeButton.configuration = configuration;
    } else {
        self.countryCodeButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0);
    }
}

- (void)pp_reloadTypeButtons {
    UIColor *accentColor = PPProviderSheetAccentColor();
    for (UIButton *button in self.typeButtons) {
        PPProviderType type = button.tag;
        BOOL isSelected = (type == self.selectedProviderType);
        UIColor *buttonTextColor = isSelected ? accentColor : PPProviderSheetPrimaryTextColor();
        UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightSemibold];
        UIImage *iconImage = [UIImage systemImageNamed:[PPProviderApplicationManager symbolNameForProviderType:type] withConfiguration:iconConfig];

        button.backgroundColor = isSelected ? [PPProviderSheetSurfaceColor() colorWithAlphaComponent:0.96] : [PPProviderSheetSurfaceColor() colorWithAlphaComponent:0.78];
        button.layer.borderColor = (isSelected ? [accentColor colorWithAlphaComponent:0.38] : [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.10]).CGColor;
        button.layer.shadowColor = PPProviderSheetShadowColor().CGColor;
        button.layer.shadowOffset = CGSizeMake(0.0, isSelected ? 12.0 : 6.0);
        button.layer.shadowRadius = isSelected ? 22.0 : 12.0;
        button.layer.shadowOpacity = isSelected ? 0.12 : 0.035;
        button.tintColor = buttonTextColor;
        NSString *title = [PPProviderApplicationManager localizedTitleForProviderType:type];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
            NSFontAttributeName: [Styling fontBold:14.0],
            NSForegroundColorAttributeName: buttonTextColor,
            NSParagraphStyleAttributeName: paragraphStyle
        }];
        [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        [button setImage:iconImage forState:UIControlStateNormal];
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
            configuration.attributedTitle = attributedTitle;
            configuration.image = iconImage;
            configuration.imagePlacement = NSDirectionalRectEdgeTop;
            configuration.imagePadding = 8.0;
            configuration.baseForegroundColor = buttonTextColor;
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(13.0, 12.0, 13.0, 12.0);
            button.configuration = configuration;
        } else {
            button.imageEdgeInsets = UIEdgeInsetsMake(-26.0, 0.0, 0.0, -22.0);
            button.titleEdgeInsets = UIEdgeInsetsMake(30.0, -22.0, 0.0, 0.0);
        }
        button.accessibilityTraits = isSelected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    }

    [self pp_updateHeroSelectionState];
    [self pp_updateBusinessFieldVisibilityAnimated:NO];
}

- (void)pp_updateHeroSelectionState {
    UIColor *accentColor = PPProviderSheetAccentColor();
    PPProviderType type = self.selectedProviderType;

    if (type == PPProviderTypeUnspecified) {
        self.heroTypePill.text = kLang(@"ProviderTypeSelect");
        self.heroFocusLabel.text = kLang(@"ProviderTypeSelectSubtitle");
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
        self.heroStageIconView.image = [UIImage systemImageNamed:@"questionmark.circle.fill" withConfiguration:config];
    } else {
        self.heroTypePill.text = [PPProviderApplicationManager localizedTitleForProviderType:type];
        self.heroFocusLabel.text = [PPProviderApplicationManager localizedSubtitleForProviderType:type];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
        self.heroStageIconView.image = [UIImage systemImageNamed:[PPProviderApplicationManager symbolNameForProviderType:type] withConfiguration:config];
    }
    self.heroStageIconView.tintColor = accentColor;

    if (self.heroStageView.window && !UIAccessibilityIsReduceMotionEnabled()) {
        self.heroStageView.transform = CGAffineTransformMakeScale(0.94, 0.94);
        [UIView animateWithDuration:0.38
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.24
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.heroStageView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_updateBusinessFieldVisibilityAnimated:(BOOL)animated {
    BOOL showsServiceFields = (self.selectedProviderType == PPProviderTypeService);
    BOOL showsCompanyFields = (self.selectedProviderType == PPProviderTypeDeliveryCompany);
    NSArray<UIView *> *companyViews = @[
        self.companyNameContainer,
        self.legalNameContainer,
        self.addressContainer,
        self.licenseNumberContainer,
        self.commercialRegistrationContainer,
    ];

    void (^applyState)(void) = ^{
        self.businessNameContainer.alpha = showsServiceFields ? 1.0 : 0.0;
        for (UIView *view in companyViews) {
            view.alpha = showsCompanyFields ? 1.0 : 0.0;
        }
        [self.view layoutIfNeeded];
    };

    void (^finalizeState)(void) = ^{
        self.businessNameContainer.hidden = !showsServiceFields;
        for (UIView *view in companyViews) {
            view.hidden = !showsCompanyFields;
        }
    };

    if (!animated) {
        self.businessNameContainer.hidden = NO;
        for (UIView *view in companyViews) {
            view.hidden = NO;
        }
        applyState();
        finalizeState();
        return;
    }

    self.businessNameContainer.hidden = NO;
    for (UIView *view in companyViews) {
        view.hidden = NO;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:applyState
                     completion:^(__unused BOOL finished) {
        finalizeState();
    }];
}

- (void)typeButtonTapped:(UIButton *)sender {
    PPProviderType nextType = sender.tag;
    if (!PPProviderTypeIsEnabledInProApp(nextType)) {
        return;
    }
    if (nextType == self.selectedProviderType) {
        return;
    }

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.10
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            sender.transform = CGAffineTransformMakeScale(0.975, 0.975);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.22
                                  delay:0.0
                 usingSpringWithDamping:0.84
                  initialSpringVelocity:0.4
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                sender.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }

    self.selectedProviderType = nextType;
    self.selectedPlan = nil;
    self.plans = @[];
    [self pp_applyProviderFormPrefillForType:nextType];
    [self pp_reloadTypeButtons];
    [self pp_updateBusinessFieldVisibilityAnimated:YES];
    [self pp_reloadPlans];
    [self pp_updateSubmitButtonState];
}

- (void)pp_reloadPlans {
    if (self.selectedProviderType == PPProviderTypeUnspecified ||
        !PPProviderTypeIsEnabledInProApp(self.selectedProviderType)) {
        self.isLoadingPlans = NO;
        self.plans = @[];
        self.selectedPlan = nil;
        self.plansLoadErrorMessage = @"";
        self.plansStateLabel.text = kLang(@"ProviderPlansSelectPrompt");
        [self pp_renderPlans];
        [self pp_updateSubmitButtonState];
        return;
    }

    NSString *previousPlanID = self.selectedPlan.planID ?: @"";
    if (previousPlanID.length == 0) {
        PPProviderApplication *existingApplication = [self.state applicationForType:self.selectedProviderType];
        previousPlanID = existingApplication.planID ?: @"";
    }
    if (previousPlanID.length == 0) {
        PPProviderProfile *existingProfile = [self.state profileForType:self.selectedProviderType];
        previousPlanID = existingProfile.planID ?: @"";
    }
    self.plansLoadErrorMessage = @"";
    self.isLoadingPlans = YES;
    self.plansStateLabel.text = kLang(@"ProviderPlansLoading");
    [self pp_renderPlans];
    [self pp_updateSubmitButtonState];

    __weak typeof(self) weakSelf = self;
    [[PPProviderApplicationManager shared] fetchPlansForProviderType:self.selectedProviderType completion:^(NSArray<PPProviderPlan *> * _Nullable plans, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isLoadingPlans = NO;
        self.plans = plans ?: @[];
        PPProviderPlan *matchedPlan = nil;
        if (previousPlanID.length > 0) {
            for (PPProviderPlan *plan in self.plans) {
                if ([plan.planID isEqualToString:previousPlanID]) {
                    matchedPlan = plan;
                    break;
                }
            }
        }
        self.selectedPlan = matchedPlan;

        if (error) {
            self.plansLoadErrorMessage = error.localizedDescription ?: kLang(@"ProviderPlansLoadFailed");
            self.plansStateLabel.text = self.plansLoadErrorMessage;
        } else if (self.plans.count == 0) {
            self.plansLoadErrorMessage = @"";
            self.plansStateLabel.text = kLang(@"ProviderPlansEmpty");
        } else if (self.selectedPlan) {
            self.plansLoadErrorMessage = @"";
            self.plansStateLabel.text = kLang(@"ProviderPlansReady");
        } else {
            self.plansLoadErrorMessage = @"";
            self.plansStateLabel.text = kLang(@"ProviderPlansSelectPrompt");
        }

        [self pp_renderPlans];
        [self pp_updateSubmitButtonState];
    }];
}

- (void)pp_renderPlans {
    for (UIView *view in self.planStack.arrangedSubviews.copy) {
        [self.planStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    if (self.isLoadingPlans || self.plans.count == 0) {
        UILabel *stateLabel = [[UILabel alloc] init];
        stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
        stateLabel.font = [Styling fontMedium:13.0];
        stateLabel.textColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.88];
        stateLabel.textAlignment = Language.alignmentForCurrentLanguage;
        stateLabel.numberOfLines = 0;
        stateLabel.text = self.plansStateLabel.text.length > 0 ? self.plansStateLabel.text : kLang(@"ProviderPlansSelectPrompt");

        UIView *stateSurface = [[UIView alloc] init];
        stateSurface.translatesAutoresizingMaskIntoConstraints = NO;
        stateSurface.backgroundColor = PPProviderSheetMatteColor();
        stateSurface.layer.cornerRadius = 22.0;
        stateSurface.layer.cornerCurve = kCACornerCurveContinuous;
        stateSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        stateSurface.layer.borderColor = [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.08].CGColor;
        [stateSurface addSubview:stateLabel];
        [NSLayoutConstraint activateConstraints:@[
            [stateLabel.topAnchor constraintEqualToAnchor:stateSurface.topAnchor constant:18.0],
            [stateLabel.leadingAnchor constraintEqualToAnchor:stateSurface.leadingAnchor constant:18.0],
            [stateLabel.trailingAnchor constraintEqualToAnchor:stateSurface.trailingAnchor constant:-18.0],
            [stateLabel.bottomAnchor constraintEqualToAnchor:stateSurface.bottomAnchor constant:-18.0],
        ]];
        [self.planStack addArrangedSubview:stateSurface];
        return;
    }

    for (PPProviderPlan *plan in self.plans) {
        PPProviderPlanCardControl *card = [[PPProviderPlanCardControl alloc] initWithPlan:plan];
        [card addTarget:self action:@selector(planCardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card applySelectionState:[plan.planID isEqualToString:self.selectedPlan.planID]];
        [self.planStack addArrangedSubview:card];
    }
}

- (void)planCardTapped:(PPProviderPlanCardControl *)sender {
    [PPButtonHelper animateTapOnView:sender];
    self.selectedPlan = sender.plan;
    PPProviderApplication *blockingApplication = [self pp_blockingApplicationForSelectedPlan];
    if (blockingApplication) {
        self.plansStateLabel.text = [self pp_duplicateApplicationMessageForApplication:blockingApplication];
        [self pp_showDuplicateApplicationAlert:blockingApplication];
    } else {
        self.plansStateLabel.text = kLang(@"ProviderPlansReady");
    }
    [self pp_renderPlans];
    [self pp_updateSubmitButtonState];
}

- (void)countryCodeTapped:(UIButton *)sender {
    (void)sender;
    [self pp_dismissKeyboard];
    NSArray<NSDictionary *> *countryOptions = PPProviderCountryCodeOptions();
    if (countryOptions.count == 0) {
        [CitiesManager.shared loadData];
        NSString *message = CitiesManager.shared.isLoading ? kLang(@"ProviderCountriesLoading") : kLang(@"ProviderCountriesUnavailable");
        [PPToast toast:message style:PPToastStyleWarning haptic:YES duration:1.6];
        return;
    }

    NSMutableArray<NSString *> *selected = [NSMutableArray array];
    if (self.selectedCountryCode.length > 0) {
        [selected addObject:self.selectedCountryCode];
    }

    __weak typeof(self) weakSelf = self;
    PPProviderPremiumOptionSheetViewController *sheet =
    [[PPProviderPremiumOptionSheetViewController alloc] initWithTitle:kLang(@"ProviderCountryPickerTitle")
                                                             subtitle:kLang(@"ProviderCountryPickerSubtitle")
                                                              options:countryOptions
                                                       selectedValues:selected.copy
                                               allowsMultipleSelection:NO
                                                            completion:^(NSArray<NSDictionary *> *selectedOptions) {
        __strong typeof(weakSelf) self = weakSelf;
        NSDictionary *option = selectedOptions.firstObject;
        NSString *code = PPProviderSheetOptionValue(option);
        if (!self || code.length == 0) {
            return;
        }
        self.selectedCountryCode = code;
        [self pp_updateCountryCodeButton];
        [self pp_updateSubmitButtonState];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_showCityPicker {
    [self pp_dismissKeyboard];
    NSMutableArray<NSString *> *selected = [NSMutableArray array];
    if (self.selectedCityIdentifier.length > 0) {
        [selected addObject:self.selectedCityIdentifier];
    }

    NSMutableArray<NSDictionary *> *cityOptions = [NSMutableArray array];
    for (NSDictionary *city in PPProviderQatarCityOptions()) {
        NSMutableDictionary *option = [city mutableCopy];
        option[@"subtitleKey"] = @"ProviderCityPickerRowSubtitle";
        [cityOptions addObject:option.copy];
    }

    __weak typeof(self) weakSelf = self;
    PPProviderPremiumOptionSheetViewController *sheet =
    [[PPProviderPremiumOptionSheetViewController alloc] initWithTitle:kLang(@"ProviderCityPickerTitle")
                                                             subtitle:kLang(@"ProviderCityPickerSubtitle")
                                                              options:cityOptions.copy
                                                       selectedValues:selected.copy
                                               allowsMultipleSelection:NO
                                                            completion:^(NSArray<NSDictionary *> *selectedOptions) {
        __strong typeof(weakSelf) self = weakSelf;
        NSDictionary *city = selectedOptions.firstObject;
        if (!self || city.count == 0) {
            return;
        }
        [self pp_applySelectedCityOption:city];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_applySelectedCityOption:(NSDictionary *)city {
    NSString *cityID = PPProviderSheetOptionValue(city);
    if (cityID.length == 0) {
        return;
    }
    BOOL changedCity = ![self.selectedCityIdentifier isEqualToString:cityID];
    self.selectedCityIdentifier = cityID;
    self.cityField.text = PPProviderSheetOptionTitle(city);
    if (changedCity) {
        self.selectedCoverageAreaKeys = @[];
        [self pp_updateCoverageAreasDisplay];
    }
    [self pp_updateSubmitButtonState];

    if (changedCity && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.16 animations:^{
            self.cityField.transform = CGAffineTransformMakeScale(0.985, 0.985);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.28
                                  delay:0.0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0.35
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.cityField.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }
}

- (NSArray<NSDictionary *> *)pp_coverageOptionsForSelectedCity {
    NSDictionary *city = PPProviderQatarCityOptionForID(self.selectedCityIdentifier);
    NSArray<NSString *> *areaKeys = [city[@"areaKeys"] isKindOfClass:NSArray.class] ? city[@"areaKeys"] : @[];
    NSMutableArray<NSDictionary *> *options = [NSMutableArray array];
    for (NSString *areaKey in areaKeys) {
        if (PPSafeString(areaKey).length == 0) {
            continue;
        }
        [options addObject:PPProviderSheetOption(areaKey, areaKey, nil)];
    }
    return options.copy;
}

- (void)pp_showCoverageAreaPicker {
    [self pp_dismissKeyboard];
    if (self.selectedCityIdentifier.length == 0) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"ProviderCityRequired")
                            subtitle:kLang(@"ProviderCoverageSelectCityFirst")];
        return;
    }

    NSArray<NSDictionary *> *coverageOptions = [self pp_coverageOptionsForSelectedCity];
    NSDictionary *city = PPProviderQatarCityOptionForID(self.selectedCityIdentifier);
    NSString *subtitle = [NSString stringWithFormat:kLang(@"ProviderCoveragePickerSubtitleFormat"), PPProviderSheetOptionTitle(city)];
    __weak typeof(self) weakSelf = self;
    PPProviderPremiumOptionSheetViewController *sheet =
    [[PPProviderPremiumOptionSheetViewController alloc] initWithTitle:kLang(@"ProviderCoveragePickerTitle")
                                                             subtitle:subtitle
                                                              options:coverageOptions
                                                       selectedValues:self.selectedCoverageAreaKeys ?: @[]
                                               allowsMultipleSelection:YES
                                                            completion:^(NSArray<NSDictionary *> *selectedOptions) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSMutableArray<NSString *> *keys = [NSMutableArray array];
        for (NSDictionary *option in selectedOptions) {
            NSString *key = PPProviderSheetOptionValue(option);
            if (key.length > 0) {
                [keys addObject:key];
            }
        }
        self.selectedCoverageAreaKeys = keys.copy;
        [self pp_updateCoverageAreasDisplay];
        [self pp_updateSubmitButtonState];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (NSArray<NSString *> *)pp_selectedCoverageAreaTitles {
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSString *key in self.selectedCoverageAreaKeys ?: @[]) {
        NSString *title = kLang(key);
        if (title.length > 0) {
            [titles addObject:title];
        }
    }
    return titles.copy;
}

- (void)pp_updateCoverageAreasDisplay {
    NSArray<NSString *> *titles = [self pp_selectedCoverageAreaTitles];
    self.coverageAreasField.text = [titles componentsJoinedByString:@", "];
}

- (void)fieldDidChange:(id)sender {
    (void)sender;
    [self pp_updateSubmitButtonState];
}

- (void)textViewDidChange:(UITextView *)textView {
    (void)textView;
    [self pp_updateSubmitButtonState];
}

- (void)pp_updateSubmitButtonState {
    PPProviderApplicationDraft *draft = [self pp_currentDraft];
    NSError *validationError = [[PPProviderApplicationManager shared] validateDraft:draft selectedPlan:self.selectedPlan];
    PPProviderApplication *blockingApplication = [self pp_blockingApplicationForSelectedPlan];

    BOOL enabled = (validationError == nil) && !blockingApplication && !self.isLoadingPlans && !self.isSubmitting;
    UIColor *accentColor = PPProviderSheetAccentColor();
    NSString *buttonTitle = self.isSubmitting ? kLang(@"ProviderSubmittingTitle") : kLang(@"ProviderSubmitButton");

    self.submitButton.enabled = enabled;
    self.submitButton.backgroundColor = enabled ? accentColor : PPProviderSheetMatteColor();
    UIColor *submitTitleColor = enabled ? PPProviderSheetActionTextOnAccentColor() : [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.70];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSAttributedString *submitAttributedTitle = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{
        NSFontAttributeName: [Styling fontBold:16.0],
        NSForegroundColorAttributeName: submitTitleColor,
        NSParagraphStyleAttributeName: paragraph
    }];
    [self.submitButton setTitle:nil forState:UIControlStateNormal];
    [self.submitButton setAttributedTitle:submitAttributedTitle forState:UIControlStateNormal];
    [self.submitButton setAttributedTitle:submitAttributedTitle forState:UIControlStateDisabled];
    [self.submitButton setTitleColor:submitTitleColor forState:UIControlStateNormal];
    self.submitButton.tintColor = submitTitleColor;
    self.submitButton.layer.shadowColor = [accentColor colorWithAlphaComponent:0.36].CGColor;
    self.submitButton.layer.shadowOffset = CGSizeMake(0.0, enabled ? 14.0 : 5.0);
    self.submitButton.layer.shadowRadius = enabled ? 22.0 : 10.0;
    self.submitButton.layer.shadowOpacity = enabled ? 0.16 : 0.02;
    self.submitButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.submitButton.layer.borderColor = (enabled ? [accentColor colorWithAlphaComponent:0.22] : [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.08]).CGColor;
    UIImageSymbolConfiguration *submitIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
    UIImage *submitIcon = [UIImage systemImageNamed:(self.isSubmitting ? @"clock.fill" : @"paperplane.fill") withConfiguration:submitIconConfig];
    [self.submitButton setImage:submitIcon forState:UIControlStateNormal];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = submitIcon;
        configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
        configuration.imagePadding = 8.0;
        configuration.baseForegroundColor = submitTitleColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(17.0, 18.0, 17.0, 18.0);
        configuration.attributedTitle = submitAttributedTitle;
        self.submitButton.configuration = configuration;
    } else {
        self.submitButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 8.0, 0.0, -8.0);
    }
    if (self.isSubmitting) {
        self.footerHintLabel.text = kLang(@"ProviderSubmittingSubtitle");
    } else if (self.isLoadingPlans) {
        self.footerHintLabel.text = kLang(@"ProviderPlansLoading");
    } else if (self.plansLoadErrorMessage.length > 0) {
        self.footerHintLabel.text = self.plansLoadErrorMessage;
    } else if (blockingApplication) {
        self.footerHintLabel.text = [self pp_duplicateApplicationMessageForApplication:blockingApplication];
    } else if (validationError) {
        self.footerHintLabel.text = validationError.localizedDescription;
    } else if (self.selectedPlan) {
        self.footerHintLabel.text = kLang(@"ProviderPlansReady");
    } else {
        self.footerHintLabel.text = self.plansStateLabel.text.length > 0 ? self.plansStateLabel.text : kLang(@"ProviderPlansSelectPrompt");
    }

    self.footerHintLabel.textColor = enabled
        ? [PPProviderSheetSecondaryTextColor() colorWithAlphaComponent:0.92]
        : [PPProviderSheetPrimaryTextColor() colorWithAlphaComponent:0.82];
}

- (PPProviderApplication *)pp_blockingApplicationForSelectedPlan {
    if (self.selectedProviderType == PPProviderTypeUnspecified || self.selectedPlan.planID.length == 0) {
        return nil;
    }
    return [self.state blockingApplicationForType:self.selectedProviderType planID:self.selectedPlan.planID];
}

- (NSString *)pp_duplicateApplicationMessageForApplication:(PPProviderApplication *)application {
    NSString *format = kLang(@"ProviderDuplicateApplicationMessageFormat");
    NSString *statusText = [PPProviderApplicationManager localizedStatusTitle:application.status];
    return [NSString stringWithFormat:format, statusText.length ? statusText : kLang(@"ProviderStatusPending")];
}

- (void)pp_showDuplicateApplicationAlert:(PPProviderApplication *)application {
    [PPAlertHelper showWarningIn:self
                           title:kLang(@"ProviderDuplicateApplicationTitle")
                        subtitle:[self pp_duplicateApplicationMessageForApplication:application]];
}

- (PPProviderApplicationDraft *)pp_currentDraft {
    PPProviderApplicationDraft *draft = [[PPProviderApplicationDraft alloc] init];
    draft.providerType = self.selectedProviderType;
    draft.fullName = PPSafeString(self.fullNameField.text);
    draft.phone = [self pp_normalizedPhoneForSubmission];
    draft.email = PPSafeString(self.emailField.text);
    draft.businessName = PPSafeString(self.businessNameField.text);
    draft.companyName = PPSafeString(self.companyNameField.text);
    draft.legalName = PPSafeString(self.legalNameField.text);
    draft.address = PPSafeString(self.addressField.text);
    draft.licenseNumber = PPSafeString(self.licenseNumberField.text);
    draft.commercialRegistrationNumber = PPSafeString(self.commercialRegistrationField.text);
    draft.licenseDocumentURL = PPSafeString(self.licenseDocumentURL);
    draft.commercialRegistrationDocumentURL = PPSafeString(self.commercialRegDocumentURL);
    draft.city = PPSafeString(self.cityField.text);
    draft.notes = PPSafeString(self.notesView.text);

    draft.coverageAreas = [self pp_selectedCoverageAreaTitles];
    return draft;
}

- (NSString *)pp_normalizedPhoneForSubmission {
    NSString *rawPhone = [PPSafeString(self.phoneField.text) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (rawPhone.length == 0) {
        return @"";
    }
    if ([rawPhone hasPrefix:@"+"]) {
        return [self pp_compactPhoneString:rawPhone];
    }
    NSString *code = self.selectedCountryCode.length ? self.selectedCountryCode : @"+974";
    return [NSString stringWithFormat:@"%@%@", code, [self pp_compactPhoneString:rawPhone]];
}

- (NSString *)pp_compactPhoneString:(NSString *)phone {
    NSMutableString *result = [NSMutableString string];
    NSCharacterSet *decimalSet = [NSCharacterSet decimalDigitCharacterSet];
    for (NSUInteger idx = 0; idx < phone.length; idx++) {
        unichar character = [phone characterAtIndex:idx];
        if (idx == 0 && character == '+') {
            [result appendString:@"+"];
            continue;
        }
        if ([decimalSet characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        }
    }
    return result.copy;
}

- (void)submitTapped {
    if (self.isSubmitting) {
        return;
    }

    [self pp_dismissKeyboard];

    PPProviderApplicationDraft *draft = [self pp_currentDraft];
    NSError *validationError = [[PPProviderApplicationManager shared] validateDraft:draft selectedPlan:self.selectedPlan];
    if (validationError) {
        [PPAlertHelper showWarningIn:self title:kLang(@"Warning") subtitle:validationError.localizedDescription];
        return;
    }
    PPProviderApplication *blockingApplication = [self pp_blockingApplicationForSelectedPlan];
    if (blockingApplication) {
        [self pp_showDuplicateApplicationAlert:blockingApplication];
        [self pp_updateSubmitButtonState];
        return;
    }

    self.isSubmitting = YES;
    [self pp_updateSubmitButtonState];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"ProviderSubmittingTitle") subtitle:kLang(@"ProviderSubmittingSubtitle")];

    __weak typeof(self) weakSelf = self;
    [[PPProviderApplicationManager shared] submitDraft:draft selectedPlan:self.selectedPlan completion:^(NSDictionary * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [PPHUD dismiss];
        self.isSubmitting = NO;
        [self pp_updateSubmitButtonState];

        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"ProviderSubmitFailed")];
            return;
        }

        NSString *message = PPSafeString(response[@"message"]);
        if (message.length == 0) {
            message = kLang(@"ProviderApplicationSubmitted");
        }
        [PPToast toast:message style:PPToastStyleSuccess haptic:YES duration:2.2];
        if ([self.delegate respondsToSelector:@selector(becomeProviderBottomSheetDidSubmitApplication:)]) {
            [self.delegate becomeProviderBottomSheetDidSubmitApplication:self];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    CGFloat offsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top;
    CGFloat progress = MIN(1.0, MAX(0.0, offsetY / 180.0));
    self.heroSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, -progress * 8.0);
    self.heroStageView.transform = CGAffineTransformMakeTranslation(0.0, progress * 10.0);
}

#pragma mark - Keyboard

- (void)pp_registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleKeyboardNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleKeyboardNotification:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)pp_handleKeyboardNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo ?: @{};
    CGRect keyboardEndFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardEndFrame fromView:nil];
    BOOL keyboardIsHiding = [notification.name isEqualToString:UIKeyboardWillHideNotification] ||
                            CGRectGetMinY(keyboardFrameInView) >= CGRectGetMaxY(self.view.bounds);

    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] ?: 0.25;
    UIViewAnimationOptions options = (([userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16) & UIViewAnimationOptionCurveEaseInOut);

    CGFloat footerHeight = CGRectGetHeight(self.submitButton.bounds) + CGRectGetHeight(self.footerHintLabel.bounds) + 38.0;
    CGFloat bottomInset = footerHeight;

    if (!keyboardIsHiding) {
        CGFloat keyboardOverlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView));
        bottomInset = footerHeight + keyboardOverlap;
    }

    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        UIEdgeInsets insets = self.scrollView.contentInset;
        insets.bottom = bottomInset;
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    } completion:^(BOOL finished) {
        if (!keyboardIsHiding) {
            // Scroll the active field into visible area
            UIView *firstResponder = [self pp_findFirstResponderInView:self.scrollView];
            if (firstResponder) {
                CGRect fieldRect = [firstResponder convertRect:firstResponder.bounds toView:self.scrollView];
                fieldRect = CGRectInset(fieldRect, 0.0, -20.0);
                [self.scrollView scrollRectToVisible:fieldRect animated:YES];
            }
        }
    }];
}

- (UIView *)pp_findFirstResponderInView:(UIView *)view {
    if (view.isFirstResponder) return view;
    for (UIView *subview in view.subviews) {
        UIView *found = [self pp_findFirstResponderInView:subview];
        if (found) return found;
    }
    return nil;
}

- (void)pp_dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - Animation

- (void)pp_prepareEntranceAnimationState {
    if (self.didRunEntranceAnimation) return;
    NSArray<UIView *> *targets = [self pp_entranceAnimationTargets];
    CGFloat offset = 22.0;
    for (UIView *view in targets) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, offset);
        offset += 8.0;
    }
}

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didRunEntranceAnimation) {
        return;
    }
    self.didRunEntranceAnimation = YES;

    NSArray<UIView *> *targets = [self pp_entranceAnimationTargets];

    [targets enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.52
                              delay:0.04 * idx
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (NSArray<UIView *> *)pp_entranceAnimationTargets {
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (UIView *view in self.contentStack.arrangedSubviews) {
        [views addObject:view];
    }
    if (self.submitButton.superview) {
        [views addObject:self.submitButton.superview];
    }
    return views.copy;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.cityField) {
        [self pp_showCityPicker];
        return NO;
    }
    if (textField == self.coverageAreasField) {
        [self pp_showCoverageAreaPicker];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSArray<UITextField *> *orderedFields = @[
        self.fullNameField,
        self.phoneField,
        self.emailField,
        self.businessNameField,
        self.companyNameField,
        self.legalNameField,
        self.addressField,
        self.licenseNumberField,
        self.commercialRegistrationField,
        self.cityField,
        self.coverageAreasField
    ];
    NSUInteger index = [orderedFields indexOfObject:textField];
    if (index == NSNotFound) {
        [textField resignFirstResponder];
        return NO;
    }

    for (NSUInteger nextIndex = index + 1; nextIndex < orderedFields.count; nextIndex++) {
        UITextField *nextField = orderedFields[nextIndex];
        if ((nextField == self.businessNameField && self.businessNameContainer.hidden) ||
            (nextField == self.companyNameField && self.companyNameContainer.hidden) ||
            (nextField == self.legalNameField && self.legalNameContainer.hidden) ||
            (nextField == self.addressField && self.addressContainer.hidden) ||
            (nextField == self.licenseNumberField && self.licenseNumberContainer.hidden) ||
            (nextField == self.commercialRegistrationField && self.commercialRegistrationContainer.hidden)) {
            continue;
        }
        if (nextField == self.cityField) {
            [self pp_showCityPicker];
            return NO;
        }
        if (nextField == self.coverageAreasField) {
            [self pp_showCoverageAreaPicker];
            return NO;
        }
        [nextField becomeFirstResponder];
        return NO;
    }

    [textField resignFirstResponder];
    return NO;
}

@end
