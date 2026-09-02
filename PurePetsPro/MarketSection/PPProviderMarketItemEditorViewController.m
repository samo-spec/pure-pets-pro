#import "PPProviderMarketItemEditorViewController.h"
#import "PPProviderMarketItem.h"
#import "PPProviderMarketplaceManager.h"
#import "PPFirebaseCompat.h"
#import "MainKindsArrayManager.h"
@interface PPProviderMarketItemEditorViewController () <UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) PPProviderMarketItem *editItem;
@property (nonatomic, assign) BOOL isCreate;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

@property (nonatomic, strong) UIView *heroArea;
@property (nonatomic, strong) NSLayoutConstraint *heroAreaHeightConstraint;
@property (nonatomic, strong) UIImageView *itemImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) NSMutableArray<UIImage *> *selectedImages;
@property (nonatomic, strong) NSMutableArray<NSString *> *imageURLs;

@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *nameEnField;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UITextView *descriptionEnView;
@property (nonatomic, strong) UILabel *descriptionEnPlaceholder;

@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UITextField *qtyField;
@property (nonatomic, strong) UITextField *accessTypeField;
@property (nonatomic, strong) UISegmentedControl *kindControl;
@property (nonatomic, strong) CAGradientLayer *kindControlLiquidLayer;
@property (nonatomic, strong) UIView *accessTypeRow;
@property (nonatomic, strong) UIView *accessTypeSheetBackdrop;
@property (nonatomic, strong) UIView *accessTypeSheetView;
@property (nonatomic, strong) UISwitch *availabilitySwitch;
@property (nonatomic, strong) UISwitch *publishedSwitch;

@property (nonatomic, strong) UITextField *mainKindField;
@property (nonatomic, strong) UIView *mainKindRow;
@property (nonatomic, strong) UIView *mainKindSheetBackdrop;
@property (nonatomic, strong) UIView *mainKindSheetView;
@property (nonatomic, strong) UITextField *subKindField;
@property (nonatomic, strong) UIView *subKindRow;
@property (nonatomic, strong) UIView *subKindSheetBackdrop;
@property (nonatomic, strong) UIView *subKindSheetView;

@property (nonatomic, strong) UITextField *discountPctField;
@property (nonatomic, strong) UITextField *discountAmtField;
@property (nonatomic, strong) UICollectionView *imageCollectionView;
@property (nonatomic, assign) BOOL isNew;

@property (nonatomic, assign) NSInteger selectedAccessoryType;
@property (nonatomic, assign) NSInteger selectedMainCategoryID;
@property (nonatomic, assign) NSInteger selectedSubCategoryID;
@property (nonatomic, strong) NSString *selectedMainKindName;
@property (nonatomic, strong) NSString *selectedSubKindName;

@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation PPProviderMarketItemEditorViewController

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor ppElevatedSurface];
}

- (UIColor *)pp_borderColor {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72];
}

/// The hero has a fixed image plate, but its editorial copy participates in
/// Dynamic Type.  Size the surrounding scroll content from the scaled two-line
/// worst case so Accessibility text never compresses the hierarchy.
- (CGFloat)pp_heroAreaHeight {
    UIFont *titleFont = PPScaledFont([Styling fontBold:23.0], UIFontTextStyleTitle3);
    UIFont *subtitleFont = PPScaledFont([Styling fontMedium:13.0], UIFontTextStyleFootnote);
    CGFloat copyHeight = ceil(titleFont.lineHeight * 2.0)
        + PPSpaceXS
        + ceil(subtitleFont.lineHeight * 2.0);
    CGFloat cardContentHeight = PPSpaceXL + PPSpaceXS + MAX(84.0, copyHeight) + PPSpaceBase;
    return MAX(220.0, ceil(cardContentHeight + (PPSpaceXS * 2.0)));
}

- (instancetype)initForCreate {
    if (self = [super init]) { _isCreate = YES; }
    return self;
}

- (instancetype)initWithItem:(PPProviderMarketItem *)item {
    if (self = [super init]) { _isCreate = NO; _editItem = item; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    [self pp_setupBackdropGlows];
    [self pp_buildUI];
    [self pp_applyValues];
    [self pp_configureNavigation];
    
    // Load main kinds via MainKindsArrayManager
    [MainKindsArrayManager.shared loadMainDataCompletionHandler:^(int result) { }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.kindControlLiquidLayer.frame = self.kindControl.bounds;
    self.kindControlLiquidLayer.cornerRadius = self.kindControl.layer.cornerRadius;
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
    // Pulse uses color as a soft directional cue, not a competing background.
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.025 : 0.055];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.015 : 0.035;
    self.bgGlowTop.layer.shadowRadius = 48.0;

    self.bgGlowBottom.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:isDark ? 0.018 : 0.035];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppWarning].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.010 : 0.025;
    self.bgGlowBottom.layer.shadowRadius = 54.0;
}

- (void)pp_configureNavigation {
    [self pp_navBarWithOtherButton:nil title:@""]; // Title is in hero
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder keyboardType:(UIKeyboardType)type {
    UITextField *f = [[UITextField alloc] init];
    NSDictionary *placeholderAttributes = @{
        NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:0.9],
        NSFontAttributeName: [Styling fontMedium:14]
    };
    f.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:placeholderAttributes];
    f.font = [Styling fontRegular:15];
    f.textColor = PrimaryTextClr;
    f.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.95];
    f.layer.cornerRadius = 16;
    f.layer.borderWidth = 0.5;
    f.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.12].CGColor;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,14,20)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.rightView = [[UIView alloc] initWithFrame:CGRectMake(0,0,14,20)];
    f.rightViewMode = UITextFieldViewModeAlways;
    f.keyboardType = type;
    f.textAlignment = NSTextAlignmentNatural;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [f.heightAnchor constraintEqualToConstant:48].active = YES;
    return f;
}

- (UILabel *)sectionTitleLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [Styling fontBold:14];
    label.textColor = PrimaryTextClr;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = 1;
    return label;
}

- (UIView *)sectionContainerWithTitle:(NSString *)title arrangedSubviews:(NSArray<UIView *> *)views {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.86];
    container.layer.cornerRadius = 20.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 0.5;
    container.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.12].CGColor;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentFill;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    [container addSubview:stack];

    UILabel *titleLabel = [self sectionTitleLabelWithText:title];
    [stack addArrangedSubview:titleLabel];

    for (UIView *view in views) {
        [stack addArrangedSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)buildHeroHeader {
    PPHero *hero = [[PPHero alloc] init];
    hero.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.88];
    iconSurface.layer.cornerRadius = 26.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [hero addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:(self.isCreate ? @"square.and.pencil" : @"bag.fill")
                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]];
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [iconSurface addSubview:icon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = self.isCreate ? kLang(@"Market_AddTitle") : kLang(@"Market_EditTitle");
    titleLabel.font = [Styling fontBold:24];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    [hero addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"Market_FormSubtitle");
    subtitleLabel.font = [Styling fontMedium:13];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    [hero addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [iconSurface.topAnchor constraintEqualToAnchor:hero.topAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:58.0],
        [iconSurface.heightAnchor constraintEqualToConstant:58.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:16.0],
        [titleLabel.topAnchor constraintEqualToAnchor:iconSurface.topAnchor constant:4.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor],
    ]];

    return hero;
}

- (void)pp_buildUI {
    // The editor is presented from an Objective-C dashboard, so make its root
    // direction explicit rather than relying on a navigation-controller default.
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInset = UIEdgeInsetsMake(PPSpaceXS, 0, 128.0, 0);
    self.scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.scrollView];
    
    _heroArea = [[UIView alloc] init];
    _heroArea.translatesAutoresizingMaskIntoConstraints = NO;
    _heroArea.backgroundColor = UIColor.clearColor;
    _heroArea.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.scrollView addSubview:_heroArea];
    
    // The Market editor uses the same warm, quiet hero composition as Pulse:
    // a restrained image plate plus a concise editorial hierarchy.
    PPHero *heroCard = [[PPHero alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.accentColor = AppPrimaryClr;
    heroCard.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_heroArea addSubview:heroCard];
    
    _itemImageView = [[UIImageView alloc] init];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_itemImageView, PPCornerMedium);
    _itemImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    _itemImageView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _itemImageView.layer.borderColor = [self pp_borderColor].CGColor;
    [heroCard addSubview:_itemImageView];
    
    _imagePickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *camCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [_imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:camCfg] forState:UIControlStateNormal];
    _imagePickerButton.tintColor = AppPrimaryClr;
    _imagePickerButton.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(_imagePickerButton, PPTouchTargetMin / 2.0);
    _imagePickerButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _imagePickerButton.layer.borderColor = [self pp_borderColor].CGColor;
    PPApplyButtonShadow(_imagePickerButton);
    _imagePickerButton.alpha = 1.0;
    _imagePickerButton.accessibilityLabel = kLang(@"Market_SectionImages");
    [_imagePickerButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];
    [heroCard addSubview:_imagePickerButton];
    
    UILabel *heroTitle = [[UILabel alloc] init];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.font = [Styling fontBold:23.0];
    heroTitle.textColor = PrimaryTextClr;
    heroTitle.textAlignment = Language.alignmentForCurrentLanguage;
    heroTitle.numberOfLines = 2;
    heroTitle.text = self.isCreate ? kLang(@"Market_AddTitle") : kLang(@"Market_EditTitle");
    PPEnableDynamicType(heroTitle, UIFontTextStyleTitle3);
    [heroCard addSubview:heroTitle];
    
    UILabel *heroSubtitle = [[UILabel alloc] init];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroSubtitle.font = [Styling fontMedium:13.0];
    heroSubtitle.textColor = SeconderyTextClr;
    heroSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    heroSubtitle.numberOfLines = 2;
    heroSubtitle.text = kLang(@"Market_FormSubtitle");
    PPEnableDynamicType(heroSubtitle, UIFontTextStyleFootnote);
    [heroCard addSubview:heroSubtitle];
    
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceXL;
    self.contentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.scrollView addSubview:self.contentStack];
    
    [self pp_setupFormSections];
    
    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:17.0];
    _saveButton.tintColor = UIColor.whiteColor;
    _saveButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(_saveButton, PPCornerMedium);
    PPApplyButtonShadow(_saveButton);
    _saveButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _saveButton.accessibilityLabel = kLang(@"Save");
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];
    
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    self.heroAreaHeightConstraint = [_heroArea.heightAnchor constraintEqualToConstant:[self pp_heroAreaHeight]];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_heroArea.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [_heroArea.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor],
        [_heroArea.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor],
        self.heroAreaHeightConstraint,
        
        [heroCard.topAnchor constraintEqualToAnchor:_heroArea.topAnchor constant:PPSpaceXS],
        [heroCard.leadingAnchor constraintEqualToAnchor:_heroArea.leadingAnchor constant:PPSpaceBase],
        [heroCard.trailingAnchor constraintEqualToAnchor:_heroArea.trailingAnchor constant:-PPSpaceBase],
        [heroCard.bottomAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:-PPSpaceXS],
        
        [_itemImageView.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:PPSpaceXL],
        [_itemImageView.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:PPSpaceBase],
        [_itemImageView.widthAnchor constraintEqualToConstant:84.0],
        [_itemImageView.heightAnchor constraintEqualToConstant:84.0],
        
        [_imagePickerButton.bottomAnchor constraintEqualToAnchor:_itemImageView.bottomAnchor constant:4.0],
        [_imagePickerButton.trailingAnchor constraintEqualToAnchor:_itemImageView.trailingAnchor constant:4.0],
        [_imagePickerButton.widthAnchor constraintEqualToConstant:PPTouchTargetMin],
        [_imagePickerButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin],
        
        [heroTitle.leadingAnchor constraintEqualToAnchor:_itemImageView.trailingAnchor constant:PPSpaceBase],
        [heroTitle.topAnchor constraintEqualToAnchor:_itemImageView.topAnchor constant:PPSpaceXS],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-PPSpaceBase],
        
        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:PPSpaceXS],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroTitle.leadingAnchor],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:heroTitle.trailingAnchor],
        [heroSubtitle.bottomAnchor constraintLessThanOrEqualToAnchor:heroCard.bottomAnchor constant:-PPSpaceBase],
        
        [self.contentStack.topAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:PPSpaceBase],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:PPSpaceBase],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-PPSpaceBase],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-PPSpaceXL],
        
        [_saveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [_saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [_saveButton.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-PPSpaceSM],
        [_saveButton.heightAnchor constraintEqualToConstant:56.0]
    ]];
}

- (UIView *)pp_textFieldWithPlaceholder:(NSString *)placeholder icon:(NSString *)iconName field:(UITextField * _Nullable __strong *)fieldPtr {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [self pp_canvasColor];
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(container, PPCornerMedium);
    container.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    container.layer.borderColor = [self pp_borderColor].CGColor;
    [container.heightAnchor constraintEqualToConstant:58.0].active = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.70];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:icon];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    field.textColor = PrimaryTextClr;
    field.font = [Styling fontBold:15.0];
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                   attributes:@{NSForegroundColorAttributeName : [SeconderyTextClr colorWithAlphaComponent:0.52]}];
    PPEnableDynamicTypeForTextField(field, UIFontTextStyleBody);
    // Arabic digits → English digits normalization for numeric keyboards
    [field addTarget:self action:@selector(pp_normalizeArabicDigitsForField:) forControlEvents:UIControlEventEditingChanged];
    [container addSubview:field];
    if (fieldPtr) *fieldPtr = field;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPSpaceBase],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
        [field.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:PPSpaceSM],
        [field.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-PPSpaceBase],
        [field.topAnchor constraintEqualToAnchor:container.topAnchor],
        [field.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UITextView *)pp_textViewWithPlaceholder:(NSString *)placeholderText field:(UITextView * _Nullable __strong *)fieldPtr placeholderLabel:(UILabel * _Nullable __strong *)placeholderPtr {
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    textView.backgroundColor = [self pp_canvasColor];
    PPApplyContinuousCorners(textView, PPCornerMedium);
    textView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    textView.layer.borderColor = [self pp_borderColor].CGColor;
    textView.textColor = PrimaryTextClr;
    textView.font = PPScaledFont([Styling fontBold:15.0], UIFontTextStyleBody);
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    textView.delegate = self;
    textView.textContainerInset = UIEdgeInsetsMake(18.0, 14.0, 18.0, 14.0);
    [textView.heightAnchor constraintEqualToConstant:140.0].active = YES;
    if (fieldPtr) *fieldPtr = textView;

    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    placeholder.font = [Styling fontBold:15.0];
    placeholder.textColor = [SeconderyTextClr colorWithAlphaComponent:0.3];
    placeholder.text = placeholderText;
    [textView addSubview:placeholder];
    if (placeholderPtr) *placeholderPtr = placeholder;

    [NSLayoutConstraint activateConstraints:@[
        [placeholder.topAnchor constraintEqualToAnchor:textView.topAnchor constant:18.0],
        [placeholder.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:18.0],
    ]];

    return textView;
}

- (UIView *)pp_sectionBlockWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName views:(NSArray<UIView *> *)views {
    // Pulse groups related work inside one quiet surface rather than treating
    // every input as an isolated floating card.
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPStyleCardSurface(surface, PPCornerCard);

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = PPSpaceBase;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.layoutMargins = UIEdgeInsetsMake(PPSpaceBase, PPSpaceBase, PPSpaceBase, PPSpaceBase);
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [surface addSubview:stack];

    [stack addArrangedSubview:[self pp_sectionHeader:title subtitle:subtitle icon:iconName]];
    for (UIView *v in views) [stack addArrangedSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
    ]];
    return surface;
}

- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(iconPlate, 14.0, 0.10);
    [container addSubview:iconPlate];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [iconPlate addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontBold:15.0];
    titleLbl.textColor = PrimaryTextClr;
    titleLbl.text = title;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(titleLbl, UIFontTextStyleHeadline);
    [container addSubview:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLbl.font = [Styling fontMedium:11.0];
    subtitleLbl.textColor = SeconderyTextClr;
    subtitleLbl.text = subtitle;
    subtitleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLbl.numberOfLines = 2;
    subtitleLbl.hidden = subtitle.length == 0;
    PPEnableDynamicType(subtitleLbl, UIFontTextStyleCaption1);
    [container addSubview:subtitleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [iconPlate.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [iconPlate.topAnchor constraintEqualToAnchor:container.topAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:30.0],
        [iconPlate.heightAnchor constraintEqualToConstant:30.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],

        [titleLbl.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:PPSpaceSM],
        [titleLbl.topAnchor constraintEqualToAnchor:iconPlate.topAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:PPSpaceXS],
        [subtitleLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subtitleLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
    ]];
    if (subtitleLbl.hidden) {
        [titleLbl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;
    } else {
        [subtitleLbl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;
    }

    return container;
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

- (UIView *)pp_imageCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(108.0, 108.0);
    layout.minimumInteritemSpacing = PPSpaceSM;
    layout.minimumLineSpacing = PPSpaceSM;

    self.imageCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.imageCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageCollectionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.imageCollectionView.backgroundColor = UIColor.clearColor;
    self.imageCollectionView.showsHorizontalScrollIndicator = NO;
    [self.imageCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"img"];
    self.imageCollectionView.dataSource = self;
    self.imageCollectionView.delegate = self;
    [self.imageCollectionView.heightAnchor constraintEqualToConstant:120.0].active = YES;
    return self.imageCollectionView;
}

- (void)pp_setupFormSections {
    self.selectedImages = [NSMutableArray array];
    self.imageURLs = [NSMutableArray array];

    UIView *nameRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_NameReq") icon:@"square.and.pencil" field:&_nameField];
    self.nameField.keyboardType = UIKeyboardTypeDefault;
    UIView *nameEnRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_NameEn") icon:@"character.cursor.ibeam" field:&_nameEnField];
    self.nameEnField.keyboardType = UIKeyboardTypeASCIICapable;

    UIView *descBlock = [[UIView alloc] init];
    descBlock.translatesAutoresizingMaskIntoConstraints = NO;
    descBlock.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPStyleCardSurface(descBlock, PPCornerCard);
    UIView *descHeader = [self pp_sectionHeader:kLang(@"Description") subtitle:kLang(@"Market_DescriptionHint") icon:@"doc.text.fill"];
    self.descriptionView = [self pp_textViewWithPlaceholder:kLang(@"Description") field:&_descriptionView placeholderLabel:&_descriptionPlaceholder];
    self.descriptionView.keyboardType = UIKeyboardTypeDefault;
    [descBlock addSubview:descHeader];
    [descBlock addSubview:self.descriptionView];
    [NSLayoutConstraint activateConstraints:@[
        [descHeader.topAnchor constraintEqualToAnchor:descBlock.topAnchor constant:PPSpaceBase],
        [descHeader.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor constant:PPSpaceBase],
        [descHeader.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor constant:-PPSpaceBase],
        [self.descriptionView.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:PPSpaceBase],
        [self.descriptionView.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor constant:PPSpaceBase],
        [self.descriptionView.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor constant:-PPSpaceBase],
        [self.descriptionView.bottomAnchor constraintEqualToAnchor:descBlock.bottomAnchor constant:-PPSpaceBase],
    ]];

    UIView *descEnBlock = [[UIView alloc] init];
    descEnBlock.translatesAutoresizingMaskIntoConstraints = NO;
    descEnBlock.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPStyleCardSurface(descEnBlock, PPCornerCard);
    UIView *descEnHeader = [self pp_sectionHeader:kLang(@"Description (EN)") subtitle:@"" icon:@"doc.text.fill"];
    self.descriptionEnView = [self pp_textViewWithPlaceholder:kLang(@"Description (EN)") field:&_descriptionEnView placeholderLabel:&_descriptionEnPlaceholder];
    self.descriptionEnView.keyboardType = UIKeyboardTypeASCIICapable;
    [descEnBlock addSubview:descEnHeader];
    [descEnBlock addSubview:self.descriptionEnView];
    [NSLayoutConstraint activateConstraints:@[
        [descEnHeader.topAnchor constraintEqualToAnchor:descEnBlock.topAnchor constant:PPSpaceBase],
        [descEnHeader.leadingAnchor constraintEqualToAnchor:descEnBlock.leadingAnchor constant:PPSpaceBase],
        [descEnHeader.trailingAnchor constraintEqualToAnchor:descEnBlock.trailingAnchor constant:-PPSpaceBase],
        [self.descriptionEnView.topAnchor constraintEqualToAnchor:descEnHeader.bottomAnchor constant:PPSpaceBase],
        [self.descriptionEnView.leadingAnchor constraintEqualToAnchor:descEnBlock.leadingAnchor constant:PPSpaceBase],
        [self.descriptionEnView.trailingAnchor constraintEqualToAnchor:descEnBlock.trailingAnchor constant:-PPSpaceBase],
        [self.descriptionEnView.bottomAnchor constraintEqualToAnchor:descEnBlock.bottomAnchor constant:-PPSpaceBase],
    ]];

    UIView *priceRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_PriceReq") icon:@"banknote.fill" field:&_priceField];
    self.priceField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    UIView *qtyRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_QuantityReq") icon:@"shippingbox.fill" field:&_qtyField];
    self.qtyField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;

    self.kindControl = [[UISegmentedControl alloc] initWithItems:@[kLang(@"Market_Accessory"), kLang(@"Market_Food")]];
    self.kindControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindControl.selectedSegmentIndex = 0;
    self.kindControl.backgroundColor = [self pp_surfaceColor];
    self.kindControl.layer.cornerRadius = 20.0;
    self.kindControl.layer.cornerCurve = kCACornerCurveContinuous;
    self.kindControl.layer.borderWidth = 1.0;
    self.kindControl.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.20].CGColor;
    self.kindControl.clipsToBounds = YES;
    self.kindControlLiquidLayer = [CAGradientLayer layer];
    self.kindControlLiquidLayer.startPoint = CGPointMake(0.0, 0.0);
    self.kindControlLiquidLayer.endPoint = CGPointMake(1.0, 1.0);
    self.kindControlLiquidLayer.locations = @[@0.0, @0.46, @1.0];
    [self.kindControl.layer insertSublayer:self.kindControlLiquidLayer atIndex:0];
    [self pp_applyLiquidStyleToKindControl];
    [self.kindControl.heightAnchor constraintEqualToConstant:58.0].active = YES;

    UIView *mainRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_CategoryReq") icon:@"folder.fill" field:&_mainKindField];
    self.mainKindRow = mainRow;
    self.mainKindField.userInteractionEnabled = NO;
    self.mainKindField.text = kLang(@"Market_CategoryPickerTapFamily");
    self.mainKindField.textColor = [SeconderyTextClr colorWithAlphaComponent:0.75];
    [mainRow addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_showMainKindPicker)]];

    UIImageView *mainChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold]]];
    mainChevron.translatesAutoresizingMaskIntoConstraints = NO;
    mainChevron.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.45];
    [mainRow addSubview:mainChevron];
    [NSLayoutConstraint activateConstraints:@[
        [mainChevron.trailingAnchor constraintEqualToAnchor:mainRow.trailingAnchor constant:-18.0],
        [mainChevron.centerYAnchor constraintEqualToAnchor:mainRow.centerYAnchor],
        [mainChevron.widthAnchor constraintEqualToConstant:16.0],
        [mainChevron.heightAnchor constraintEqualToConstant:16.0],
    ]];

    UIView *subRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_Subcategory") icon:@"folder" field:&_subKindField];
    self.subKindRow = subRow;
    self.subKindField.userInteractionEnabled = NO;
    self.subKindField.enabled = NO;
    self.subKindField.text = kLang(@"Market_CategoryPickerChooseSubcategory");
    self.subKindField.textColor = [SeconderyTextClr colorWithAlphaComponent:0.75];
    [subRow addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_showSubKindPicker)]];

    UIImageView *subChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold]]];
    subChevron.translatesAutoresizingMaskIntoConstraints = NO;
    subChevron.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.45];
    [subRow addSubview:subChevron];
    [NSLayoutConstraint activateConstraints:@[
        [subChevron.trailingAnchor constraintEqualToAnchor:subRow.trailingAnchor constant:-18.0],
        [subChevron.centerYAnchor constraintEqualToAnchor:subRow.centerYAnchor],
        [subChevron.widthAnchor constraintEqualToConstant:16.0],
        [subChevron.heightAnchor constraintEqualToConstant:16.0],
    ]];

    UIView *imagesBlock = [[UIView alloc] init];
    imagesBlock.translatesAutoresizingMaskIntoConstraints = NO;
    imagesBlock.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPStyleCardSurface(imagesBlock, PPCornerCard);
    UIView *imagesHeader = [self pp_sectionHeader:kLang(@"Market_SectionImages") subtitle:kLang(@"Market_ImagesHint") icon:@"photo.on.rectangle.fill"];
    UIView *imagesView = [self pp_imageCollectionView];
    [imagesBlock addSubview:imagesHeader];
    [imagesBlock addSubview:imagesView];
    [NSLayoutConstraint activateConstraints:@[
        [imagesHeader.topAnchor constraintEqualToAnchor:imagesBlock.topAnchor constant:PPSpaceBase],
        [imagesHeader.leadingAnchor constraintEqualToAnchor:imagesBlock.leadingAnchor constant:PPSpaceBase],
        [imagesHeader.trailingAnchor constraintEqualToAnchor:imagesBlock.trailingAnchor constant:-PPSpaceBase],
        [imagesView.topAnchor constraintEqualToAnchor:imagesHeader.bottomAnchor constant:PPSpaceBase],
        [imagesView.leadingAnchor constraintEqualToAnchor:imagesBlock.leadingAnchor constant:PPSpaceBase],
        [imagesView.trailingAnchor constraintEqualToAnchor:imagesBlock.trailingAnchor constant:-PPSpaceBase],
        [imagesView.bottomAnchor constraintEqualToAnchor:imagesBlock.bottomAnchor constant:-PPSpaceBase],
    ]];

    UIView *discPctRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_DiscountPct") icon:@"percent" field:&_discountPctField];
    self.discountPctField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    UIView *discAmtRow = [self pp_textFieldWithPlaceholder:kLang(@"Market_DiscountAmt") icon:@"banknote.fill" field:&_discountAmtField];
    self.discountAmtField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;

    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Market_SectionIdentity") subtitle:@"" icon:@"info.circle.fill" views:@[nameRow, nameEnRow]]];
    [self.contentStack addArrangedSubview:descBlock];
    [self.contentStack addArrangedSubview:descEnBlock];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Market_SectionCommerce") subtitle:@"" icon:@"dollarsign.circle.fill" views:@[priceRow, qtyRow]]];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Market_SectionClassification") subtitle:kLang(@"Market_CategoryPickerSubtitle") icon:@"pawprint.circle.fill" views:@[mainRow, subRow]]];
    [self.contentStack addArrangedSubview:imagesBlock];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Market_SectionPromotion") subtitle:@"" icon:@"sparkles" views:@[discPctRow, discAmtRow]]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self pp_updateGlowsForStyle];
        self.saveButton.layer.shadowColor = AppPrimaryClr.CGColor;
        [self pp_applyLiquidStyleToKindControl];
    }
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        self.heroAreaHeightConstraint.constant = [self pp_heroAreaHeight];
        [self.view setNeedsLayout];
    }
}

- (void)pp_applyLiquidStyleToKindControl {
    if (!self.kindControl) return;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.kindControl.backgroundColor = UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        self.kindControl.selectedSegmentTintColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.24 : 0.16];
    }
    self.kindControl.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.30 : 0.20].CGColor;
    self.kindControlLiquidLayer.colors = @[
        (id)[UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.04 : 0.34].CGColor,
        (id)[AppPrimaryClr colorWithAlphaComponent:isDark ? 0.08 : 0.045].CGColor,
        (id)[AppPrimaryClr colorWithAlphaComponent:isDark ? 0.20 : 0.10].CGColor
    ];
    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:0.82],
        NSFontAttributeName: [Styling fontMedium:13.0]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName: PrimaryTextClr,
        NSFontAttributeName: [Styling fontBold:13.0]
    };
    [self.kindControl setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [self.kindControl setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
}

- (void)pp_applyValues {
    self.availabilitySwitch.on = YES;
    self.publishedSwitch.on = YES;
    self.kindControl.selectedSegmentIndex = 0;
    self.itemImageView.image = [UIImage systemImageNamed:@"bag.fill"];
    self.itemImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
    self.itemImageView.contentMode = UIViewContentModeCenter;

    if (self.isCreate) return;

    self.nameField.text = self.editItem.name;
    self.nameEnField.text = self.editItem.nameEn;
    self.descriptionView.text = self.editItem.desc;
    self.descriptionEnView.text = self.editItem.descEn;
    self.priceField.text = self.editItem.price > 0 ? [NSString stringWithFormat:@"%.0f", self.editItem.price] : @"";
    self.qtyField.text = [NSString stringWithFormat:@"%ld", (long)self.editItem.quantity];
    self.selectedMainCategoryID = self.editItem.petMainCategoryID;
    self.selectedSubCategoryID = self.editItem.petSubCategoryID;
    self.selectedMainKindName = self.editItem.petMainCategoryName;
    self.kindControl.selectedSegmentIndex = (self.editItem.accessKindType == 2) ? 1 : 0;
    [self updateMainKindPickerTitle];
    [self updateSubKindPickerTitle];
    if (self.editItem.imageURLsArray.count > 0) {
        [self.imageURLs addObjectsFromArray:self.editItem.imageURLsArray ?: @[]];
        [self.imageCollectionView reloadData];
    }
}

- (void)saveTapped {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (name.length == 0) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"Market_NameRequired")]; return; }
    double price = self.priceField.text.doubleValue;
    if (price <= 0) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"Market_PriceInvalid")]; return; }
    NSInteger qty = (NSInteger)self.qtyField.text.integerValue;
    if (qty < 0) qty = 0;
    NSInteger cat = self.selectedMainCategoryID;
    if (cat <= 0) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"Market_CategoryRequired")]; return; }

    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    fields[@"name"] = name;
    fields[@"nameEn"] = [self.nameEnField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    fields[@"desc"] = self.descriptionView.text ?: @"";
    fields[@"descEn"] = self.descriptionEnView.text ?: @"";
    fields[@"price"] = @(price);
    fields[@"quantity"] = @(qty);
    fields[@"petMainCategoryID"] = @(cat);
    fields[@"petMainCategoryName"] = self.selectedMainKindName ?: @"";
    fields[@"petSubCategoryID"] = @(self.selectedSubCategoryID);
    double dp = self.discountPctField.text.doubleValue;
    double da = self.discountAmtField.text.doubleValue;
    if (dp > 0) fields[@"discountPercent"] = @(dp);
    if (da > 0) fields[@"discountAmount"] = @(da);
    fields[@"hasOffer"] = @((dp > 0) || (da > 0));

    self.saveButton.enabled = NO;

    // Images: if we have newly selected images, upload them; otherwise keep existing URLs
    if (self.selectedImages.count > 0) {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UploadingImages") subtitle:nil];
        [self uploadImagesThenSave:fields isCreate:self.isCreate];
    } else if (self.isCreate) {
        [self performSave:fields isCreate:YES];
    } else {
        // Edit mode with no new images - keep existing URLs
        [self performSave:fields isCreate:NO];
    }
}

- (void)uploadImagesThenSave:(NSDictionary *)fields isCreate:(BOOL)create {
    __weak typeof(self) ws = self;
    FIRStorage *storage = [FIRStorage storage];
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"unknown";
    NSMutableArray *urls = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSInteger i = 0; i < self.selectedImages.count; i++) {
        dispatch_group_enter(group);
        UIImage *img = self.selectedImages[i];
        NSData *data = UIImageJPEGRepresentation(img, 0.8);
        NSString *safeUID = uid ?: @"";
        NSString *fileName = [NSString stringWithFormat:@"%@_%ld.jpg", safeUID, (long)[[NSDate date] timeIntervalSince1970] * 1000 + i];
        NSString *path = [NSString stringWithFormat:@"marketplace_items/%@/images/%@", safeUID, fileName];
        FIRStorageReference *ref = [storage.reference child:path];
        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{
            @"uploaded_by": safeUID,
            @"media_type": @"image",
            @"item_id": self.editItem.itemID ?: @""
        };
        [ref putData:data metadata:metadata completion:^(FIRStorageMetadata *meta, NSError *err) {
            if (!err) {
                [ref downloadURLWithCompletion:^(NSURL *url, NSError *dErr) {
                    if (url) { @synchronized (urls) { [urls addObject:url.absoluteString]; } }
                    dispatch_group_leave(group);
                }];
            } else {
                NSLog(@"[MarketEditor] upload error: %@", err);
                dispatch_group_leave(group);
            }
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [PPHUD dismiss];
        __strong typeof(ws) self = ws;
        if (!self) return;
        NSMutableDictionary *f = [fields mutableCopy];
        NSMutableArray *allURLs = [self.imageURLs mutableCopy];
        if (urls.count > 0) [allURLs addObjectsFromArray:urls];
        if (allURLs.count > 0) f[@"imageURLsArray"] = allURLs;
        NSLog(@"[MarketEditor] save with %ld image URLs", (long)allURLs.count);
        [self performSave:f isCreate:create];
    });
    // Safety: if group never completes (network hang), force save after 30s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(ws) self = ws;
        if (!self || self.saveButton.enabled) return; // already saved
        NSLog(@"[MarketEditor] upload timeout — saving without images");
        [PPHUD dismiss];
        [self performSave:fields isCreate:create];
    });
}

- (void)performSave:(NSDictionary *)fields isCreate:(BOOL)create {
    if (create) {
        NSMutableDictionary *f = [fields mutableCopy];
        f[@"accessKindType"] = @(self.kindControl.selectedSegmentIndex == 1 ? 2 : 1);
        [[PPProviderMarketplaceManager sharedManager] createMarketItem:f completion:^(BOOL ok, NSString *iid, NSString *msg, NSError *err) {
            self.saveButton.enabled = YES;
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_ItemCreated")];
            if (self.onSave) self.onSave();
            [self.navigationController popViewControllerAnimated:YES];
        }];
    } else {
        [[PPProviderMarketplaceManager sharedManager] updateMarketItem:self.editItem.itemID fields:fields completion:^(BOOL ok, NSString *msg, NSError *err) {
            self.saveButton.enabled = YES;
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_ItemSaved")];
            if (self.onSave) self.onSave();
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
}

- (void)pickImage {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.selectionLimit = 5;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pp_pickImage {
    [self pickImage];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    // When editing, keep existing imageURLs; just append new selectedImages
    dispatch_group_t group = dispatch_group_create();
    for (PHPickerResult *r in results) {
        dispatch_group_enter(group);
        [r.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *img, NSError *err) {
            if (img) [self.selectedImages addObject:img];
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{ [self.imageCollectionView reloadData]; });
}

#pragma mark - Image Collection View

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return self.imageURLs.count + self.selectedImages.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    NSInteger totalImages = self.imageURLs.count + self.selectedImages.count;
    NSInteger urlIdx = ip.item;
    
    if (urlIdx == totalImages) {
        UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"img" forIndexPath:ip];
        for (UIView *sv in cell.contentView.subviews) [sv removeFromSuperview];
        PPApplyContinuousCorners(cell.contentView, PPCornerMedium);
        cell.contentView.clipsToBounds = YES;
        cell.contentView.backgroundColor = [self pp_canvasColor];
        cell.contentView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        cell.contentView.layer.borderColor = [self pp_borderColor].CGColor;
        
        UIView *addView = [[UIView alloc] initWithFrame:cell.contentView.bounds];
        addView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        addView.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:addView];
        
        UIImageView *plusIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        plusIcon.center = CGPointMake(addView.bounds.size.width / 2, addView.bounds.size.height / 2);
        plusIcon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        plusIcon.image = [UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold]];
        plusIcon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.7];
        [addView addSubview:plusIcon];
        
        UILabel *addLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, plusIcon.frame.origin.y + plusIcon.frame.size.height + 4, addView.bounds.size.width, 20)];
        addLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        addLabel.text = kLang(@"Add");
        addLabel.font = [Styling fontMedium:12];
        addLabel.textColor = [AppPrimaryClr colorWithAlphaComponent:0.7];
        addLabel.textAlignment = NSTextAlignmentCenter;
        [addView addSubview:addLabel];
        
        UIButton *addButton = [UIButton buttonWithType:UIButtonTypeCustom];
        addButton.frame = addView.bounds;
        addButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        addButton.tag = ip.item;
        [addButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];
        [addView addSubview:addButton];
        
        return cell;
    }
    
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"img" forIndexPath:ip];
    for (UIView *sv in cell.contentView.subviews) [sv removeFromSuperview];
    cell.contentView.layer.cornerRadius = 12; cell.contentView.clipsToBounds = YES;
    cell.contentView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.5];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    iv.contentMode = UIViewContentModeScaleAspectFill; iv.clipsToBounds = YES;
    [cell.contentView addSubview:iv];
    
    if (urlIdx < (NSInteger)self.imageURLs.count) {
        [iv setImageFromUrl:self.imageURLs[urlIdx] placeholderImage:@"sparkles"];
    } else {
        NSInteger imgIdx = urlIdx - (NSInteger)self.imageURLs.count;
        if (imgIdx < (NSInteger)self.selectedImages.count) iv.image = self.selectedImages[imgIdx];
    }
    
    UIButton *del = [UIButton buttonWithType:UIButtonTypeCustom];
    del.frame = CGRectMake(cell.contentView.bounds.size.width - 22, 2, 20, 20);
    del.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    del.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.85];
    del.layer.cornerRadius = 10; del.clipsToBounds = YES;
    [del setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    del.tintColor = UIColor.whiteColor;
    del.tag = ip.item;
    [del addTarget:self action:@selector(removeImageAtCell:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:del];
    return cell;
}

- (void)removeImageAtCell:(UIButton *)sender {
    NSInteger totalImages = self.imageURLs.count + self.selectedImages.count;
    NSInteger idx = sender.tag;
    if (idx >= totalImages) return;
    if (idx < (NSInteger)self.imageURLs.count) [self.imageURLs removeObjectAtIndex:idx];
    else { NSInteger i = idx - (NSInteger)self.imageURLs.count; if (i < (NSInteger)self.selectedImages.count) [self.selectedImages removeObjectAtIndex:i]; }
    [self.imageCollectionView reloadData];
}

#pragma mark - Lifecycle

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:3.8 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction animations:^{
            self.bgGlowTop.transform = CGAffineTransformMakeScale(1.05, 1.05);
            self.bgGlowBottom.transform = CGAffineTransformMakeScale(0.98, 0.98);
        } completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.bgGlowTop.layer removeAllAnimations];
    [self.bgGlowBottom.layer removeAllAnimations];
    self.bgGlowTop.transform = CGAffineTransformIdentity;
    self.bgGlowBottom.transform = CGAffineTransformIdentity;
}

#pragma mark - Category Picker Buttons

- (UIButton *)pp_categoryButtonWithTitle:(NSString *)placeholder {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.95];
    button.layer.cornerRadius = 16;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.12].CGColor;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [button setTitle:placeholder forState:UIControlStateNormal];
    [button setTitleColor:SeconderyTextClr forState:UIControlStateNormal];
    button.titleLabel.font = [Styling fontRegular:15];
    [button.heightAnchor constraintEqualToConstant:48].active = YES;
   // [button setImage:[UIImage imageNamed:@"chevron.down"] forState:UIControlStateNormal];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevron.tintColor = SeconderyTextClr;
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-12],
        [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:22],
        [chevron.heightAnchor constraintEqualToConstant:22]
    ]];
    
    return button;
}

- (void)updateMainKindPickerTitle {
    NSString *title = self.selectedMainCategoryID > 0
        ? [self pp_mainKindDisplayNameForID:self.selectedMainCategoryID]
        : kLang(@"Species");
    self.mainKindField.text = title;
    self.mainKindField.textColor = self.selectedMainCategoryID > 0 ? PrimaryTextClr : SeconderyTextClr;
    self.subKindField.enabled = (self.selectedMainCategoryID > 0);
    self.subKindField.userInteractionEnabled = (self.selectedMainCategoryID > 0);
    self.subKindField.alpha = self.selectedMainCategoryID > 0 ? 1.0 : 0.5;
}

- (void)updateSubKindPickerTitle {
    NSString *title = self.selectedSubCategoryID > 0
        ? [self pp_subKindDisplayNameForID:self.selectedSubCategoryID mainID:self.selectedMainCategoryID]
        : kLang(@"Breed");
    [self.subKindField setText:title];
    [self.subKindField setTextColor:self.selectedSubCategoryID > 0 ? PrimaryTextClr : SeconderyTextClr];
}

- (NSString *)pp_mainKindDisplayNameForID:(NSInteger)mainID {
    MainKindsModel *mk = [self mainKindForID:mainID];
    return mk.KindName ?: self.selectedMainKindName ?: kLang(@"Species");
}

- (NSString *)pp_subKindDisplayNameForID:(NSInteger)subID mainID:(NSInteger)mainID {
    SubKindModel *sk = [self subKindForID:subID mainID:mainID];
    return sk.SubKindName ?: self.selectedSubKindName ?: kLang(@"Breed");
}

- (MainKindsModel *)mainKindForID:(NSInteger)kindID {
    NSArray<MainKindsModel *> *kinds = MainKindsArrayManager.shared.MainKindsArray ?: AppMgr.MainKindsArray ?: @[];
    for (MainKindsModel *mk in kinds) {
        if (mk.ID == kindID) return mk;
    }
    return nil;
}

- (SubKindModel *)subKindForID:(NSInteger)subID mainID:(NSInteger)mainID {
    MainKindsModel *main = [self mainKindForID:mainID];
    if (!main) return nil;
    for (SubKindModel *sk in (main.SubKindsArray ?: @[])) {
        if (sk.ID == subID) return sk;
    }
    return nil;
}

- (void)pp_showMainKindPicker {
    [PPFunc pp_playTapEffect]; [self.view endEditing:YES];
    [self pp_dismissMainKindSheet:nil]; [self pp_dismissSubKindSheet:nil];
    UIView *bd = [[UIView alloc] init]; bd.translatesAutoresizingMaskIntoConstraints = NO; bd.backgroundColor = UIColor.clearColor;
    [self.view addSubview:bd]; self.mainKindSheetBackdrop = bd;
    [bd addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissMainKindSheetFromGR:)]];
    UIButton *sheet = [self pp_glassSheetView]; sheet.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sheet]; self.mainKindSheetView = sheet;
    UILabel *title = [self pp_sheetTitle:kLang(@"Market_SectionClassification")]; [sheet addSubview:title];
    UIScrollView *scroll = [self pp_sheetScrollView]; [sheet addSubview:scroll];
    UIStackView *stack = [self pp_sheetStackInScroll:scroll];
    for (MainKindsModel *mk in MainKindsArrayManager.shared.MainKindsArray) {
        UIButton *b = [self pp_sheetButtonWithTitle:mk.KindName custom:NO]; b.tag = mk.ID;
        [b addTarget:self action:@selector(pp_mainKindTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:b];
    }
    [self pp_layoutSheet:sheet backdrop:bd title:title scroll:scroll stack:stack height:MIN(420, 80 + (NSInteger)MainKindsArrayManager.shared.MainKindsArray.count * 58)];
    [self pp_animateSheetIn:sheet backdrop:bd];
}
- (void)pp_mainKindTapped:(UIButton *)s {
    MainKindsModel *mk = [self mainKindForID:s.tag];
    self.selectedMainCategoryID = s.tag;
    self.selectedSubCategoryID = 0;
    self.selectedMainKindName = mk.KindName ?: s.currentTitle ?: @"";
    [self pp_dismissMainKindSheet:nil];
    [self updateMainKindPickerTitle];
    [self updateSubKindPickerTitle];
}
- (void)pp_dismissMainKindSheetFromGR:(UITapGestureRecognizer *)gr { [self pp_dismissMainKindSheet:nil]; }

- (void)pp_dismissMainKindSheet:(UIButton *)s {
    UIView *bd = self.mainKindSheetBackdrop,
    *sh = self.mainKindSheetView; self.mainKindSheetBackdrop = nil; self.mainKindSheetView = nil; if (!sh) return; void (^rem)(void) = ^{ [bd removeFromSuperview]; [sh removeFromSuperview]; };
    if (s) { [UIView animateWithDuration:0.25 animations:^{
        bd.alpha=0;
        sh.alpha=0;
        sh.transform=CGAffineTransformMakeTranslation(0,200);
    } completion:^(BOOL f){
        rem(); }];
    }
    else rem();
}

- (void)pp_showSubKindPicker {
    if (self.selectedMainCategoryID <= 0) return;
    MainKindsModel *mk = [self mainKindForID:self.selectedMainCategoryID];
    if (!mk || mk.SubKindsArray.count == 0) return;
    
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    [self pp_dismissMainKindSheet:nil];
    [self pp_dismissSubKindSheet:nil];
    UIView *bd = [[UIView alloc] init];
    bd.translatesAutoresizingMaskIntoConstraints = NO;
    bd.backgroundColor = UIColor.clearColor;
    [self.view addSubview:bd];
    self.subKindSheetBackdrop = bd;
    [bd addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissSubKindSheetFromGR:)]];
    UIButton *sheet = [self pp_glassSheetView];
    sheet.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sheet];
    self.subKindSheetView = sheet;
    UILabel *title = [self pp_sheetTitle:mk.KindName];
    [sheet addSubview:title];
    UIScrollView *scroll = [self pp_sheetScrollView];
    [sheet addSubview:scroll];
    UIStackView *stack = [self pp_sheetStackInScroll:scroll];
    for (SubKindModel *sk in mk.SubKindsArray) {
        UIButton *b = [self pp_sheetButtonWithTitle:sk.SubKindName custom:NO]; b.tag = sk.ID;
        [b addTarget:self action:@selector(pp_subKindTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:b];
    }
    [self pp_layoutSheet:sheet backdrop:bd title:title scroll:scroll stack:stack height:MIN(420, 80 + (NSInteger)mk.SubKindsArray.count * 58)];
    [self pp_animateSheetIn:sheet backdrop:bd];
}
- (void)pp_subKindTapped:(UIButton *)s {
    SubKindModel *sk = [self subKindForID:s.tag mainID:self.selectedMainCategoryID];
    self.selectedSubCategoryID = s.tag;
    self.selectedSubKindName = sk.SubKindName ?: s.currentTitle ?: @"";
    [self pp_dismissSubKindSheet:nil];
    [self updateSubKindPickerTitle];
}

- (void)pp_dismissSubKindSheetFromGR:(UITapGestureRecognizer *)gr
{
    [self pp_dismissSubKindSheet:nil];
}

- (void)pp_dismissSubKindSheet:(UIButton *)s {
    UIView *bd = self.subKindSheetBackdrop,
    *sh = self.subKindSheetView;
    self.subKindSheetBackdrop = nil;
    self.subKindSheetView = nil;
    if (!sh) return; void (^rem)(void) = ^{
        [bd removeFromSuperview]; [sh removeFromSuperview];
    };
    if (s)
    { [UIView animateWithDuration:0.25 animations:^{
        bd.alpha=0; sh.alpha=0;
        sh.transform=CGAffineTransformMakeTranslation(0,200);
    } completion:^(BOOL f){
        rem(); }];
    } else rem();
}

#pragma mark - Sheet Helpers

- (UIButton *)pp_glassSheetView {
    UIButton *sheet = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    sheet.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIButtonConfiguration *configuration = sheet.configuration;
    configuration.background.cornerRadius = PPCornerHero;
    configuration.baseBackgroundColor = UIColor.clearColor;
    configuration.background.backgroundColor = UIColor.clearColor;
    NSDictionary *attributes = @{
        NSFontAttributeName: [Styling fontBold:17.0],
        NSForegroundColorAttributeName: PrimaryTextClr
    };
    [sheet setAttributedTitle:[[NSAttributedString alloc] initWithString:@"" attributes:attributes] forState:UIControlStateNormal];
    sheet.configuration = configuration;
    sheet.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(sheet, PPCornerHero);
    sheet.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    sheet.layer.borderColor = [self pp_borderColor].CGColor;
    PPApplyCardShadow(sheet);
    return sheet;
}


- (UILabel *)pp_sheetTitle:(NSString *)t
{
    UILabel *l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.font = [Styling fontBold:18];
    l.textColor = PrimaryTextClr;
    l.textAlignment = NSTextAlignmentCenter;
    l.text = t;
    return l;
}

- (UIScrollView *)pp_sheetScrollView
{
    UIScrollView *s = [[UIScrollView alloc] init];
    s.translatesAutoresizingMaskIntoConstraints = NO;
    s.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    s.showsVerticalScrollIndicator = NO;
    return s;
}

- (UIStackView *)pp_sheetStackInScroll:(UIScrollView *)sc
{
    UIStackView *s = [[UIStackView alloc] init];
    s.translatesAutoresizingMaskIntoConstraints = NO;
    s.axis = UILayoutConstraintAxisVertical;
    s.spacing = PPSpaceSM;
    s.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [sc addSubview:s];
    return s;
}

- (UIButton *)pp_sheetButtonWithTitle:(NSString *)title custom:(BOOL)custom {
    UIButton *button = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed
                                                                        configType:PPButtonConfigrationGlass];
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIButtonConfiguration *configuration = button.configuration;
    configuration.background.cornerRadius = PPCornerMedium;
    configuration.baseBackgroundColor = UIColor.clearColor;
    configuration.background.backgroundColor = UIColor.clearColor;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceSM, PPSpaceBase, PPSpaceSM, PPSpaceBase);
    configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
    button.configuration = configuration;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.backgroundColor = [self pp_canvasColor];
    PPApplyContinuousCorners(button, PPCornerMedium);
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [self pp_borderColor].CGColor;

    NSDictionary *attributes = @{
        NSFontAttributeName: PPScaledFont([Styling fontBold:14.0], UIFontTextStyleBody),
        NSForegroundColorAttributeName: custom ? AppPrimaryClr : PrimaryTextClr
    };
    [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title ?: @"" attributes:attributes] forState:UIControlStateNormal];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:52.0].active = YES;
    return button;
}

- (void)pp_layoutSheet:(UIView *)sheet backdrop:(UIView *)bd title:(UILabel *)tl scroll:(UIScrollView *)sc stack:(UIStackView *)st height:(CGFloat)h
{
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [bd.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [bd.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bd.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bd.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [sheet.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [sheet.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [sheet.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-8],

        [tl.topAnchor constraintEqualToAnchor:sheet.topAnchor constant:20],
        [tl.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor constant:20],
        [tl.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor constant:-20],

        [sc.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:14],
        [sc.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor constant:14],
        [sc.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor constant:-14],
        [sc.bottomAnchor constraintEqualToAnchor:sheet.bottomAnchor constant:-16],
        [sc.heightAnchor constraintEqualToConstant:h],

        [st.topAnchor constraintEqualToAnchor:sc.contentLayoutGuide.topAnchor],
        [st.leadingAnchor constraintEqualToAnchor:sc.contentLayoutGuide.leadingAnchor],
        [st.trailingAnchor constraintEqualToAnchor:sc.contentLayoutGuide.trailingAnchor],
        [st.bottomAnchor constraintEqualToAnchor:sc.contentLayoutGuide.bottomAnchor],
        [st.widthAnchor constraintEqualToAnchor:sc.frameLayoutGuide.widthAnchor]
    ]];
}

- (void)pp_animateSheetIn:(UIView *)sheet backdrop:(UIView *)bd
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        bd.backgroundColor = [UIColor colorWithWhite:0 alpha:0.28];
        sheet.transform = CGAffineTransformIdentity;
        return;
    }

    sheet.transform = CGAffineTransformMakeTranslation(0, 320);
    [UIView animateWithDuration:0.32
                         delay:0
          usingSpringWithDamping:0.88
           initialSpringVelocity:0.35
                         options:UIViewAnimationOptionCurveEaseOut
                      animations:^{
        bd.backgroundColor = [UIColor colorWithWhite:0 alpha:0.28];
        sheet.transform = CGAffineTransformIdentity;
    } completion:nil];
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
