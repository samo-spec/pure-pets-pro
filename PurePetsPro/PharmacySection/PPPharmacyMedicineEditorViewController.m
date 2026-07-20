#import "PPPharmacyMedicineEditorViewController.h"
#import "PPVetManager.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface PPPharmacyMedicineEditorViewController () <UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong, nullable) PPVetMedicineModel *medicine;
@property (nonatomic, copy) PPPharmacyMedicineEditorCompletion completion;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

@property (nonatomic, strong) UIView *heroArea;
@property (nonatomic, strong) UIImageView *medicineImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong) UIImage *selectedImage;

@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UITextField *categoryField;
@property (nonatomic, strong) UITextField *customCategoryField;
@property (nonatomic, strong) UIView *customCategoryRow;
@property (nonatomic, strong) UIView *categorySheetBackdrop;
@property (nonatomic, strong) UIView *categorySheetView;
@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UITextField *quantityField;
@property (nonatomic, strong) UIStackView *animalChecklistStack;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *selectedAnimalTypes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIButton *> *animalTypeButtons;
@property (nonatomic, copy) NSString *selectedCategory;
@property (nonatomic, assign) BOOL categoryUsesCustomValue;
@property (nonatomic, strong) UISwitch *availabilitySwitch;
@property (nonatomic, strong) UISwitch *publishedSwitch;

@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation PPPharmacyMedicineEditorViewController

#pragma mark - Premium Colors

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.97 green:0.96 blue:0.95 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.06];
    }];
}

- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine
                      completion:(PPPharmacyMedicineEditorCompletion)completion {
    self = [super init];
    if (self) {
        _medicine = [medicine copy];
        _completion = [completion copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectedAnimalTypes = [NSMutableOrderedSet orderedSet];
    self.animalTypeButtons = [NSMutableDictionary dictionary];
    self.view.backgroundColor = [self pp_canvasColor];
    [self pp_setupBackdropGlows];
    [self pp_buildUI];
    [self pp_applyValues];
    [self pp_configureNavigation];
}

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 110.0;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 100.0;
    [self.view insertSubview:self.bgGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-72.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    [self pp_updateGlowsForStyle];
}

- (void)pp_updateGlowsForStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.05 : 0.10];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 60.0;

    self.bgGlowBottom.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor systemOrangeColor].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 70.0;
}

- (void)pp_configureNavigation {
    [self pp_navBarWithOtherButton:nil title:@""]; // Title is in hero
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (void)pp_buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 100, 0);
    [self.view addSubview:self.scrollView];

    _heroArea = [[UIView alloc] init];
    _heroArea.translatesAutoresizingMaskIntoConstraints = NO;
    _heroArea.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:_heroArea];

    PPHero *heroCard = [[PPHero alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_heroArea addSubview:heroCard];

    _medicineImageView = [[UIImageView alloc] init];
    _medicineImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
    _medicineImageView.clipsToBounds = YES;
    _medicineImageView.layer.cornerRadius = 34.0;
    _medicineImageView.layer.cornerCurve = kCACornerCurveContinuous;
    _medicineImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    _medicineImageView.layer.borderWidth = 2.0;
    _medicineImageView.layer.borderColor = [UIColor whiteColor].CGColor;
    [heroCard addSubview:_medicineImageView];

    _imagePickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *camCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [_imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:camCfg] forState:UIControlStateNormal];
    _imagePickerButton.tintColor = AppPrimaryClr;
    _imagePickerButton.backgroundColor = [self pp_surfaceColor];
    _imagePickerButton.layer.cornerRadius = 16.0;
    _imagePickerButton.layer.borderWidth = 1.0;
    _imagePickerButton.layer.borderColor = [self pp_borderColor].CGColor;
    _imagePickerButton.layer.shadowColor = UIColor.blackColor.CGColor;
    _imagePickerButton.layer.shadowOpacity = 0.1;
    _imagePickerButton.layer.shadowOffset = CGSizeMake(0, 4);
    _imagePickerButton.layer.shadowRadius = 8.0;
    [_imagePickerButton addTarget:self action:@selector(pp_pickImage) forControlEvents:UIControlEventTouchUpInside];
    [heroCard addSubview:_imagePickerButton];

    UILabel *heroTitle = [[UILabel alloc] init];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.font = [Styling fontBold:26.0];
    heroTitle.textColor = PrimaryTextClr;
    heroTitle.textAlignment = NSTextAlignmentCenter;
    heroTitle.text = self.medicine ? kLang(@"Pharmacy_Edit_Title") : kLang(@"Pharmacy_Add_Title");
    [heroCard addSubview:heroTitle];

    UILabel *heroSubtitle = [[UILabel alloc] init];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroSubtitle.font = [Styling fontMedium:13.0];
    heroSubtitle.textColor = SeconderyTextClr;
    heroSubtitle.textAlignment = NSTextAlignmentCenter;
    heroSubtitle.text = kLang(@"Pharmacy_Manage_Subtitle");
    [heroCard addSubview:heroSubtitle];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 36.0;
    [self.scrollView addSubview:self.contentStack];

    [self pp_setupFormSections];

    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:kLang(@"Pharmacy_Save") forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:17.0];
    _saveButton.tintColor = UIColor.whiteColor;
    _saveButton.backgroundColor = AppPrimaryClr;
    _saveButton.layer.cornerRadius = 28.0;
    _saveButton.layer.cornerCurve = kCACornerCurveContinuous;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    _saveButton.layer.shadowColor = AppPrimaryClr.CGColor;
    _saveButton.layer.shadowOpacity = isDark ? 0.15 : 0.3;
    _saveButton.layer.shadowRadius = 16.0;
    _saveButton.layer.shadowOffset = CGSizeMake(0, 8);
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_heroArea.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [_heroArea.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor],
        [_heroArea.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor],
        [_heroArea.heightAnchor constraintEqualToConstant:320.0],

        [heroCard.topAnchor constraintEqualToAnchor:_heroArea.topAnchor constant:12.0],
        [heroCard.leadingAnchor constraintEqualToAnchor:_heroArea.leadingAnchor constant:20.0],
        [heroCard.trailingAnchor constraintEqualToAnchor:_heroArea.trailingAnchor constant:-20.0],
        [heroCard.bottomAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:-12.0],

        [_medicineImageView.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:36.0],
        [_medicineImageView.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [_medicineImageView.widthAnchor constraintEqualToConstant:108.0],
        [_medicineImageView.heightAnchor constraintEqualToConstant:108.0],

        [_imagePickerButton.bottomAnchor constraintEqualToAnchor:_medicineImageView.bottomAnchor constant:0.0],
        [_imagePickerButton.trailingAnchor constraintEqualToAnchor:_medicineImageView.trailingAnchor constant:6.0],
        [_imagePickerButton.widthAnchor constraintEqualToConstant:32.0],
        [_imagePickerButton.heightAnchor constraintEqualToConstant:32.0],

        [heroTitle.topAnchor constraintEqualToAnchor:_medicineImageView.bottomAnchor constant:12.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:4.0],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [self.contentStack.topAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:20.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-40.0],

        [_saveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [_saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [_saveButton.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12.0],
        [_saveButton.heightAnchor constraintEqualToConstant:56.0],
    ]];
}

- (UIView *)pp_textFieldWithPlaceholder:(NSString *)placeholder icon:(NSString *)iconName field:(UITextField * _Nullable __strong *)fieldPtr {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [self pp_surfaceColor];
    container.layer.cornerRadius = 20.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [self pp_borderColor].CGColor;
    [container.heightAnchor constraintEqualToConstant:58.0].active = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:icon];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.textColor = PrimaryTextClr;
    field.font = [Styling fontBold:15.0];
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                   attributes:@{NSForegroundColorAttributeName : [SeconderyTextClr colorWithAlphaComponent:0.3]}];
    // Arabic digits → English digits normalization for numeric keyboards
    [field addTarget:self action:@selector(pp_normalizeArabicDigitsForField:) forControlEvents:UIControlEventEditingChanged];
    [container addSubview:field];
    if (fieldPtr) *fieldPtr = field;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
        [field.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12.0],
        [field.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [field.topAnchor constraintEqualToAnchor:container.topAnchor],
        [field.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (NSString *)pp_trimmedText:(NSString *)text {
    return [PPSafeString(text) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray<NSString *> *)pp_categoryOptionKeys {
    return @[
        @"Pharmacy_Category_Antibiotics",
        @"Pharmacy_Category_Deworming",
        @"Pharmacy_Category_FleaTick",
        @"Pharmacy_Category_PainRelief",
        @"Pharmacy_Category_SkinCoat",
        @"Pharmacy_Category_EyeEar",
        @"Pharmacy_Category_Digestive",
        @"Pharmacy_Category_Vitamins",
        @"Pharmacy_Category_Vaccines",
        @"Pharmacy_Category_FirstAid",
        @"Pharmacy_Category_DentalCare"
    ];
}

- (NSArray<NSString *> *)pp_categoryOptions {
    NSMutableArray<NSString *> *options = [NSMutableArray array];
    for (NSString *key in [self pp_categoryOptionKeys]) {
        [options addObject:kLang(key)];
    }
    return options.copy;
}

- (NSString *)pp_otherCategoryTitle {
    return kLang(@"Pharmacy_Category_Other");
}

- (NSString *)pp_normalizedCategoryText:(NSString *)text {
    return [[self pp_trimmedText:text].lowercaseString stringByReplacingOccurrencesOfString:@"&" withString:@"and"];
}

- (NSString *)pp_localizedCategoryForKey:(NSString *)key languageCode:(NSString *)languageCode {
    NSString *path = [[NSBundle mainBundle] pathForResource:languageCode ofType:@"lproj"];
    NSBundle *bundle = path.length ? [NSBundle bundleWithPath:path] : nil;
    return bundle ? [bundle localizedStringForKey:key value:nil table:nil] : nil;
}

- (NSString *)pp_displayCategoryForSavedCategory:(NSString *)savedCategory {
    NSString *needle = [self pp_normalizedCategoryText:savedCategory];
    if (needle.length == 0) return @"";

    for (NSString *key in [self pp_categoryOptionKeys]) {
        NSArray<NSString *> *candidates = @[
            key,
            kLang(key),
            [self pp_localizedCategoryForKey:key languageCode:@"en"] ?: @"",
            [self pp_localizedCategoryForKey:key languageCode:@"ar"] ?: @""
        ];
        for (NSString *candidate in candidates) {
            if ([[self pp_normalizedCategoryText:candidate] isEqualToString:needle]) {
                return kLang(key);
            }
        }
    }
    return nil;
}

- (NSArray<NSString *> *)pp_animalKindOptions {
    return @[
        kLang(@"Pharmacy_Animal_Cats"),
        kLang(@"Pharmacy_Animal_Dogs"),
        kLang(@"Pharmacy_Animal_Birds"),
        kLang(@"Pharmacy_Animal_Rabbits"),
        kLang(@"Pharmacy_Animal_Horses"),
        kLang(@"Pharmacy_Animal_Camels"),
        kLang(@"Pharmacy_Animal_Sheep"),
        kLang(@"Pharmacy_Animal_Falcons")
    ];
}

- (UIView *)pp_animalChecklistView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    self.animalChecklistStack = [[UIStackView alloc] init];
    self.animalChecklistStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.animalChecklistStack.axis = UILayoutConstraintAxisVertical;
    self.animalChecklistStack.spacing = 8.0;
    [container addSubview:self.animalChecklistStack];

    for (NSString *animal in [self pp_animalKindOptions]) {
        UIButton *button = [self pp_animalOptionButtonWithTitle:animal];
        self.animalTypeButtons[animal] = button;
        [self.animalChecklistStack addArrangedSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.animalChecklistStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.animalChecklistStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.animalChecklistStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.animalChecklistStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIButton *)pp_animalOptionButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.font = [Styling fontBold:14.0];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.82;
    button.layer.cornerRadius = 18.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1.0;
    button.accessibilityIdentifier = title;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 14.0, 0, 14.0);
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(pp_toggleAnimalKind:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:50.0].active = YES;
    return button;
}

- (void)pp_showCategoryPicker {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    [self pp_dismissCategorySheetAnimated:NO];

    UIView *backdrop = [[UIView alloc] init];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    backdrop.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
    [self.view addSubview:backdrop];
    self.categorySheetBackdrop = backdrop;
    [backdrop addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissCategorySheet)]];

   // UIView *sheet = [[UIView alloc] init];
    UIButton *sheet = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed
                                                                          configType:PPButtonConfigrationGlass];
    UIButtonConfiguration *config = sheet.configuration;
    config.background.cornerRadius = PPIOS26() ? 42 : 30;
    config.baseBackgroundColor = [UIColor.clearColor colorWithAlphaComponent:0];
    config.background.backgroundColor = [UIColor.clearColor colorWithAlphaComponent:0];
    sheet.configuration = config;
    sheet.translatesAutoresizingMaskIntoConstraints = NO;
    sheet.backgroundColor = PPIOS26() ? UIColor.clearColor : [self pp_surfaceColor];
    sheet.layer.cornerRadius = PPIOS26() ? 42 : 30;
    sheet.layer.cornerCurve = kCACornerCurveContinuous;
    sheet.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    sheet.layer.borderColor = [self pp_borderColor].CGColor;
    sheet.layer.shadowColor = UIColor.blackColor.CGColor;
    sheet.layer.shadowOpacity = 0.16;
    sheet.layer.shadowRadius = 26.0;
    sheet.layer.shadowOffset = CGSizeMake(0, -8.0);
    [self.view addSubview:sheet];
    self.categorySheetView = sheet;

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.24];
    grabber.layer.cornerRadius = 2.0;
    [sheet addSubview:grabber];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:18.0];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = kLang(@"Pharmacy_Field_Category");
    [sheet addSubview:titleLabel];

    UIScrollView *optionsScroll = [[UIScrollView alloc] init];
    optionsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    optionsScroll.showsVerticalScrollIndicator = NO;
    [sheet addSubview:optionsScroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8.0;
    [optionsScroll addSubview:stack];

    for (NSString *category in [self pp_categoryOptions]) {
        [stack addArrangedSubview:[self pp_categorySheetButtonWithTitle:category custom:NO]];
    }
    [stack addArrangedSubview:[self pp_categorySheetButtonWithTitle:[self pp_otherCategoryTitle] custom:YES]];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [sheet.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [sheet.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [sheet.topAnchor constraintGreaterThanOrEqualToAnchor:guide.topAnchor constant:24.0],
        [sheet.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-8.0],

        [grabber.topAnchor constraintEqualToAnchor:sheet.topAnchor constant:12.0],
        [grabber.centerXAnchor constraintEqualToAnchor:sheet.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:42.0],
        [grabber.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor constant:-20.0],

        [optionsScroll.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:18.0],
        [optionsScroll.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor constant:14.0],
        [optionsScroll.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor constant:-14.0],
        [optionsScroll.bottomAnchor constraintEqualToAnchor:sheet.bottomAnchor constant:-16.0],
        [optionsScroll.heightAnchor constraintEqualToConstant:420.0],

        [stack.topAnchor constraintEqualToAnchor:optionsScroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:optionsScroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:optionsScroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:optionsScroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:optionsScroll.frameLayoutGuide.widthAnchor],
    ]];

    sheet.transform = CGAffineTransformMakeTranslation(0.0, 320.0);
    [UIView animateWithDuration:0.32 delay:0.0 usingSpringWithDamping:0.88 initialSpringVelocity:0.35 options:UIViewAnimationOptionCurveEaseOut animations:^{
        backdrop.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
        sheet.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (UIButton *)pp_categorySheetButtonWithTitle:(NSString *)title custom:(BOOL)isCustom {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.font = [Styling fontBold:15.0];
    button.layer.cornerRadius = 17.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 16.0, 0, 16.0);
    button.accessibilityIdentifier = isCustom ? @"__custom__" : title;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    BOOL selected = isCustom ? self.categoryUsesCustomValue : [self.selectedCategory isEqualToString:title];
    button.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:selected ? 0.10 : 0.0];
    [button addTarget:self action:@selector(pp_categorySheetOptionTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:48.0].active = YES;
    return button;
}

- (void)pp_categorySheetOptionTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    BOOL isCustom = [sender.accessibilityIdentifier isEqualToString:@"__custom__"];
    self.categoryUsesCustomValue = isCustom;
    self.selectedCategory = isCustom ? @"" : (sender.accessibilityIdentifier ?: sender.currentTitle);
    [self pp_updateCategoryUI];
    [self pp_dismissCategorySheetAnimated:YES];
    if (isCustom) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.24 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.customCategoryField becomeFirstResponder];
        });
    }
}

- (void)pp_dismissCategorySheet {
    [self pp_dismissCategorySheetAnimated:YES];
}

- (void)pp_dismissCategorySheetAnimated:(BOOL)animated {
    UIView *backdrop = self.categorySheetBackdrop;
    UIView *sheet = self.categorySheetView;
    if (!backdrop && !sheet) return;
    void (^cleanup)(void) = ^{
        [backdrop removeFromSuperview];
        [sheet removeFromSuperview];
        self.categorySheetBackdrop = nil;
        self.categorySheetView = nil;
    };
    if (!animated) {
        cleanup();
        return;
    }
    [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        backdrop.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
        sheet.transform = CGAffineTransformMakeTranslation(0.0, 320.0);
    } completion:^(__unused BOOL finished) {
        cleanup();
    }];
}

- (void)pp_updateCategoryUI {
    BOOL hasCategory = self.selectedCategory.length > 0 || self.categoryUsesCustomValue;
    self.categoryField.text = self.categoryUsesCustomValue ? [self pp_otherCategoryTitle] : (self.selectedCategory.length ? self.selectedCategory : kLang(@"Pharmacy_Category_Select"));
    self.categoryField.textColor = hasCategory ? PrimaryTextClr : [SeconderyTextClr colorWithAlphaComponent:0.75];
    self.customCategoryRow.hidden = !self.categoryUsesCustomValue;
}

- (void)pp_toggleAnimalKind:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *animal = sender.accessibilityIdentifier ?: sender.currentTitle;
    if (animal.length == 0) return;
    if ([self.selectedAnimalTypes containsObject:animal]) {
        [self.selectedAnimalTypes removeObject:animal];
    } else {
        [self.selectedAnimalTypes addObject:animal];
    }
    [self pp_updateAnimalChecklistUI];
}

- (void)pp_addAnimalOptionIfNeeded:(NSString *)animal {
    if (animal.length == 0 || self.animalTypeButtons[animal] || !self.animalChecklistStack) return;
    UIButton *button = [self pp_animalOptionButtonWithTitle:animal];
    self.animalTypeButtons[animal] = button;
    [self.animalChecklistStack addArrangedSubview:button];
}

- (void)pp_updateAnimalChecklistUI {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
    [self.animalTypeButtons enumerateKeysAndObjectsUsingBlock:^(NSString *animal, UIButton *button, __unused BOOL *stop) {
        BOOL selected = [self.selectedAnimalTypes containsObject:animal];
        UIImage *icon = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle" withConfiguration:cfg];
        [button setImage:icon forState:UIControlStateNormal];
        [button setTitleColor:selected ? AppPrimaryClr : PrimaryTextClr forState:UIControlStateNormal];
        button.tintColor = selected ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.45];
        button.backgroundColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.10] : [self pp_surfaceColor];
        button.layer.borderColor = (selected ? [AppPrimaryClr colorWithAlphaComponent:0.26] : [self pp_borderColor]).CGColor;
        button.imageEdgeInsets = UIEdgeInsetsZero;
        button.titleEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 0, 0, 10.0) : UIEdgeInsetsMake(0, 10.0, 0, 0);
    }];
}

- (void)pp_setupFormSections {
    // Basic Info
    UIView *titleRow = [self pp_textFieldWithPlaceholder:kLang(@"Pharmacy_Field_Title") icon:@"tag.fill" field:&_titleField];
    UIView *catRow = [self pp_textFieldWithPlaceholder:kLang(@"Pharmacy_Field_Category") icon:@"folder.fill" field:&_categoryField];
    self.categoryField.userInteractionEnabled = NO;
    self.categoryField.text = kLang(@"Pharmacy_Category_Select");
    self.categoryField.textColor = [SeconderyTextClr colorWithAlphaComponent:0.75];
    catRow.userInteractionEnabled = YES;
    [catRow addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_showCategoryPicker)]];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold]]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.45];
    [catRow addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [chevron.trailingAnchor constraintEqualToAnchor:catRow.trailingAnchor constant:-18.0],
        [chevron.centerYAnchor constraintEqualToAnchor:catRow.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:16.0],
        [chevron.heightAnchor constraintEqualToConstant:16.0],
    ]];

    self.customCategoryRow = [self pp_textFieldWithPlaceholder:kLang(@"Pharmacy_Category_Other_Name") icon:@"square.and.pencil" field:&_customCategoryField];
    self.customCategoryRow.hidden = YES;

    // Description
    UIView *descBlock = [[UIView alloc] init];
    descBlock.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *descHeader = [self pp_sectionHeader:kLang(@"Pharmacy_Field_Description") subtitle:kLang(@"Pharmacy_Field_Description_Hint") icon:@"doc.text.fill"];
    self.descriptionView = [self pp_textView];
    [descBlock addSubview:descHeader];
    [descBlock addSubview:self.descriptionView];
    [NSLayoutConstraint activateConstraints:@[
        [descHeader.topAnchor constraintEqualToAnchor:descBlock.topAnchor],
        [descHeader.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor],
        [descHeader.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor],
        [self.descriptionView.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:12.0],
        [self.descriptionView.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor],
        [self.descriptionView.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor],
        [self.descriptionView.bottomAnchor constraintEqualToAnchor:descBlock.bottomAnchor],
    ]];

    // Pricing & Inventory
    UIView *priceRow = [self pp_textFieldWithPlaceholder:kLang(@"Pharmacy_Field_Price") icon:@"banknote.fill" field:&_priceField];
    self.priceField.keyboardType = UIKeyboardTypeDecimalPad;
    UIView *quantRow = [self pp_textFieldWithPlaceholder:kLang(@"Pharmacy_Field_Quantity") icon:@"shippingbox.fill" field:&_quantityField];
    self.quantityField.keyboardType = UIKeyboardTypeNumberPad;

    // Animal Types
    UIView *animRow = [self pp_animalChecklistView];

    // Options
    UIView *optionsBlock = [[UIView alloc] init];
    optionsBlock.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *row1 = [self pp_switchRowWithTitle:kLang(@"Pharmacy_Field_Availability") icon:@"checkmark.seal.fill" assignTo:&_availabilitySwitch];
    UIView *row2 = [self pp_switchRowWithTitle:kLang(@"Pharmacy_Field_Published") icon:@"eye.fill" assignTo:&_publishedSwitch];
    [optionsBlock addSubview:row1];
    [optionsBlock addSubview:row2];
    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:optionsBlock.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:optionsBlock.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:optionsBlock.trailingAnchor],
        [row2.topAnchor constraintEqualToAnchor:row1.bottomAnchor constant:12.0],
        [row2.leadingAnchor constraintEqualToAnchor:optionsBlock.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:optionsBlock.trailingAnchor],
        [row2.bottomAnchor constraintEqualToAnchor:optionsBlock.bottomAnchor],
    ]];

    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Pharmacy_Section_Basic") subtitle:kLang(@"Pharmacy_Section_Basic_Hint") icon:@"info.circle.fill" views:@[titleRow, catRow, self.customCategoryRow]]];
    [self.contentStack addArrangedSubview:descBlock];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Pharmacy_Section_Pricing") subtitle:kLang(@"Pharmacy_Section_Pricing_Hint") icon:@"dollarsign.circle.fill" views:@[priceRow, quantRow]]];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Pharmacy_Field_AnimalTypes") subtitle:kLang(@"Pharmacy_Field_AnimalTypes_Hint") icon:@"pawprint.circle.fill" views:@[animRow]]];
    [self.contentStack addArrangedSubview:[self pp_sectionHeader:kLang(@"Pharmacy_Section_Options") subtitle:kLang(@"Pharmacy_Section_Options_Hint") icon:@"slider.horizontal.3"]];
    [self.contentStack addArrangedSubview:optionsBlock];
}

- (UIView *)pp_sectionBlockWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [stack addArrangedSubview:[self pp_sectionHeader:title subtitle:subtitle icon:iconName]];
    for (UIView *v in views) [stack addArrangedSubview:v];
    return stack;
}

- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = AppPrimaryClr;
    bar.layer.cornerRadius = 2.0;
    [container addSubview:bar];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [container addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontBold:14];
    titleLbl.textColor = PrimaryTextClr;
    titleLbl.text = title;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLbl.font = [Styling fontMedium:11];
    subtitleLbl.textColor = SeconderyTextClr;
    subtitleLbl.text = subtitle;
    subtitleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLbl.numberOfLines = 2;
    subtitleLbl.alpha = 0.7;
    [container addSubview:subtitleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.widthAnchor constraintEqualToConstant:28.0],
        [bar.heightAnchor constraintEqualToConstant:4.0],

        [icon.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:9.0],
        [icon.widthAnchor constraintEqualToConstant:16.0],
        [icon.heightAnchor constraintEqualToConstant:16.0],

        [titleLbl.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6.0],
        [titleLbl.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4.0],
        [subtitleLbl.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
        [subtitleLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [subtitleLbl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (UITextView *)pp_textView {
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = [self pp_surfaceColor];
    textView.layer.cornerRadius = 20.0;
    textView.layer.cornerCurve = kCACornerCurveContinuous;
    textView.layer.borderWidth = 1.0;
    textView.layer.borderColor = [self pp_borderColor].CGColor;
    textView.textColor = PrimaryTextClr;
    textView.font = [Styling fontBold:15.0];
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    textView.delegate = self;
    textView.textContainerInset = UIEdgeInsetsMake(18.0, 14.0, 18.0, 14.0);
    [textView.heightAnchor constraintEqualToConstant:140.0].active = YES;

    self.descriptionPlaceholder = [[UILabel alloc] init];
    self.descriptionPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionPlaceholder.font = [Styling fontBold:15.0];
    self.descriptionPlaceholder.textColor = [SeconderyTextClr colorWithAlphaComponent:0.3];
    self.descriptionPlaceholder.text = kLang(@"Pharmacy_Field_Description");
    [textView addSubview:self.descriptionPlaceholder];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionPlaceholder.topAnchor constraintEqualToAnchor:textView.topAnchor constant:18.0],
        [self.descriptionPlaceholder.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:18.0],
    ]];

    return textView;
}

- (UIView *)pp_switchRowWithTitle:(NSString *)title icon:(NSString *)iconName assignTo:(UISwitch * __strong *)togglePtr {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [self pp_surfaceColor];
    container.layer.cornerRadius = 20.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [self pp_borderColor].CGColor;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:15.0];
    label.textColor = PrimaryTextClr;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.text = title;
    [container addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = AppPrimaryClr;
    [container addSubview:toggle];
    *togglePtr = toggle;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12.0],
        [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [toggle.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [container.heightAnchor constraintEqualToConstant:58.0],
    ]];

    return container;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self pp_updateGlowsForStyle];
        self.saveButton.layer.shadowColor = AppPrimaryClr.CGColor;
    }
}

- (void)pp_applyValues {
    if (!self.medicine) {
        self.availabilitySwitch.on = YES;
        self.publishedSwitch.on = YES;
        self.categoryUsesCustomValue = NO;
        self.selectedCategory = @"";
        [self pp_updateCategoryUI];
        [self pp_updateAnimalChecklistUI];
        self.medicineImageView.image = [UIImage systemImageNamed:@"pills.fill"];
        self.medicineImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
        self.medicineImageView.contentMode = UIViewContentModeCenter;
        return;
    }

    self.titleField.text = self.medicine.title ?: @"";
    self.descriptionView.text = self.medicine.medicineDescription ?: @"";
    NSString *savedCategory = [self pp_trimmedText:self.medicine.category];
    NSString *displayCategory = [self pp_displayCategoryForSavedCategory:savedCategory];
    if (savedCategory.length > 0 && displayCategory.length == 0) {
        self.categoryUsesCustomValue = YES;
        self.customCategoryField.text = savedCategory;
        self.selectedCategory = @"";
    } else {
        self.categoryUsesCustomValue = NO;
        self.customCategoryField.text = @"";
        self.selectedCategory = displayCategory ?: @"";
    }
    [self pp_updateCategoryUI];
    self.priceField.text = self.medicine.price > 0 ? [NSString stringWithFormat:@"%.2f", self.medicine.price] : @"";
    self.quantityField.text = [NSString stringWithFormat:@"%ld", (long)MAX(0, self.medicine.stockQuantity)];
    [self.selectedAnimalTypes removeAllObjects];
    for (NSString *animal in self.medicine.animalTypes ?: @[]) {
        NSString *trimmedAnimal = [self pp_trimmedText:animal];
        if (trimmedAnimal.length > 0) {
            [self pp_addAnimalOptionIfNeeded:trimmedAnimal];
            [self.selectedAnimalTypes addObject:trimmedAnimal];
        }
    }
    [self pp_updateAnimalChecklistUI];
    self.availabilitySwitch.on = self.medicine.isAvailable;
    self.publishedSwitch.on = self.medicine.isPublished;
    [self pp_updateDescriptionPlaceholder];

    if (self.medicine.imageUrl.length > 0) {
        [self.medicineImageView setImageWithURL:[NSURL URLWithString:self.medicine.imageUrl] placeholder:nil ];
        self.medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        self.medicineImageView.image = [UIImage systemImageNamed:@"pills.fill"];
        self.medicineImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
        self.medicineImageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)pp_pickImage {
    [PPFunc pp_playTapEffect];
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Photo library unavailable")];
        return;
    }

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        __weak typeof(self) weakSelf = self;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus nextStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (nextStatus == PHAuthorizationStatusAuthorized) {
                    [weakSelf pp_presentLegacyImagePicker];
                } else {
                    [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Please enable photo library access in Settings to select photos.")];
                }
            });
        }];
        return;
    }

    if (status != PHAuthorizationStatusAuthorized) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Please enable photo library access in Settings to select photos.")];
        return;
    }

    [self pp_presentLegacyImagePicker];
}

- (void)pp_presentLegacyImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) return;
    if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Pharmacy_Field_Description_Hint")];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            UIImage *image = [object isKindOfClass:UIImage.class] ? (UIImage *)object : nil;
            if (!image || error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"Photo library unavailable")];
                return;
            }
            self.selectedImage = image;
            self.medicineImageView.image = image;
            self.medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        self.selectedImage = image;
        self.medicineImageView.image = image;
        self.medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)textViewDidChange:(UITextView *)textView {
    [self pp_updateDescriptionPlaceholder];
}

- (void)pp_updateDescriptionPlaceholder {
    self.descriptionPlaceholder.hidden = self.descriptionView.text.length > 0;
}

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    NSString *title = [[PPSafeString(self.titleField.text) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (title.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Pharmacy_Validation_TitleRequired")];
        return;
    }

    double price = self.priceField.text.doubleValue;
    if (price <= 0.0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Pharmacy_Validation_PriceRequired")];
        return;
    }

    NSString *category = self.categoryUsesCustomValue ? [self pp_trimmedText:self.customCategoryField.text] : [self pp_trimmedText:self.selectedCategory];
    if (category.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Pharmacy_Validation_CategoryRequired")];
        return;
    }

    PPVetMedicineModel *medicine = self.medicine ? [self.medicine copy] : [[PPVetMedicineModel alloc] init];
    medicine.title = title;
    medicine.medicineDescription = PPSafeString(self.descriptionView.text);
    medicine.category = category;
    medicine.price = price;
    medicine.stockQuantity = self.quantityField.text.integerValue;
    medicine.isAvailable = self.availabilitySwitch.isOn;
    medicine.isPublished = self.publishedSwitch.isOn;
    medicine.isDisabled = NO;
    medicine.animalTypes = self.selectedAnimalTypes.array ?: @[];

    if (self.completion) {
        self.completion(medicine, self.selectedImage);
    }
}

- (void)pp_normalizeArabicDigitsForField:(UITextField *)textField {
    NSString *raw = textField.text;
    if (!raw.length) return;
    
    NSString *normalized = [PPFunc normalizedNumericString:raw];
    if (![normalized isEqualToString:raw]) {
        textField.text = normalized;
    }
}

@end
