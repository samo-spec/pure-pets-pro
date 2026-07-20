//
//  PPAdoptPetDetailViewController.m
//  PurePetsPro
//

#import "PPAdoptPetDetailViewController.h"
#import "PPAddEditAdoptPetViewController.h"
#import "PPAdoptPetManager.h"
#import "PPFirebaseCompat.h"
#import "PPFunc+Haptics.h"
#import "PPHUD.h"
#import "UIImageView+WebCache.h"

static NSString *PPAdoptDetailDisplay(NSString *value) {
    NSString *trimmed = [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    return trimmed.length > 0 ? trimmed : @"-";
}

@interface PPAdoptPetDetailViewController ()
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *actionBar;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation PPAdoptPetDetailViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildBackdrop];
    [self buildScrollView];
    [self buildContent];
    [self buildActionBar];
    [self prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:[self editNavButton] title:kLang(@"AdoptPro_DetailNavTitle") showBack:YES];
    [self refreshContent];
    [self prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

#pragma mark - Colors

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.10 green:0.10 blue:0.11 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_accentColor {
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_statusColor {
    if (self.pet.isDeleted || self.pet.isBlocked) return UIColor.systemRedColor;
    if (self.pet.visibility == 1 || [self.pet.status isEqualToString:@"hidden"]) return UIColor.systemOrangeColor;
    if (self.pet.isAdopted || [self.pet.status isEqualToString:@"adopted"]) return UIColor.systemGreenColor;
    return [self pp_accentColor];
}

#pragma mark - Build

- (void)buildBackdrop {
    self.bgGlowTop = [self glowViewWithSize:220.0];
    self.bgGlowBottom = [self glowViewWithSize:190.0];
    [self.view addSubview:self.bgGlowTop];
    [self.view addSubview:self.bgGlowBottom];

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:isDark ? 0.045 : 0.10];
    self.bgGlowTop.layer.shadowColor = [self pp_accentColor].CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 64.0;

    self.bgGlowBottom.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:isDark ? 0.035 : 0.075];
    self.bgGlowBottom.layer.shadowColor = UIColor.systemOrangeColor.CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.03 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 72.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-74.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:86.0],
        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:190.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:190.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-58.0],
    ]];
}

- (UIView *)glowViewWithSize:(CGFloat)size {
    UIView *view = [UIView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.layer.cornerRadius = size * 0.5;
    view.layer.masksToBounds = NO;
    return view;
}

- (void)buildScrollView {
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 112.0, 0);
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.scrollView];

    self.contentStack = [UIStackView new];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-28.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0],
    ]];
}

- (void)buildContent {
    [self.contentStack addArrangedSubview:[self heroSection]];
    [self.contentStack addArrangedSubview:[self detailsSection]];
    [self.contentStack addArrangedSubview:[self adopterSection]];
}

- (UIView *)heroSection {
    self.heroSurfaceView = [UIView new];
    self.heroSurfaceView.backgroundColor = [self pp_surfaceColor];
    self.heroSurfaceView.layer.cornerRadius = 30.0;
    self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.heroSurfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    self.heroSurfaceView.layer.shadowColor = (AppShadowColor ?: UIColor.blackColor).CGColor;
    self.heroSurfaceView.layer.shadowOpacity = 0.07;
    self.heroSurfaceView.layer.shadowRadius = 24.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0, 14.0);

    UIView *accentLine = [UIView new];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.backgroundColor = [self pp_statusColor];
    accentLine.layer.cornerRadius = 2.5;
    [self.heroSurfaceView addSubview:accentLine];

    self.heroImageView = [UIImageView new];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.10];
    self.heroImageView.tintColor = [self pp_accentColor];
    self.heroImageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.layer.cornerRadius = 24.0;
    self.heroImageView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroSurfaceView addSubview:self.heroImageView];

    UILabel *eyebrow = [self labelWithFont:[Styling fontBold:11.0] color:[self pp_accentColor] lines:1];
    eyebrow.text = [kLang(@"AdoptPro_DetailEyebrow") uppercaseString];
    [self.heroSurfaceView addSubview:eyebrow];

    self.titleLabel = [self labelWithFont:[Styling fontBold:30.0] color:PrimaryTextClr ?: UIColor.labelColor lines:2];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    [self.heroSurfaceView addSubview:self.titleLabel];

    self.subtitleLabel = [self labelWithFont:[Styling fontRegular:14.0] color:SeconderyTextClr ?: UIColor.secondaryLabelColor lines:3];
    [self.heroSurfaceView addSubview:self.subtitleLabel];

    self.statusLabel = [self labelWithFont:[Styling fontBold:11.0] color:[self pp_statusColor] lines:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.backgroundColor = [[self pp_statusColor] colorWithAlphaComponent:0.11];
    self.statusLabel.layer.cornerRadius = 12.0;
    self.statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusLabel.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentLine.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [accentLine.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [accentLine.widthAnchor constraintEqualToConstant:54.0],
        [accentLine.heightAnchor constraintEqualToConstant:5.0],

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:22.0],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-22.0],
        [self.heroImageView.widthAnchor constraintEqualToConstant:92.0],
        [self.heroImageView.heightAnchor constraintEqualToConstant:92.0],

        [eyebrow.topAnchor constraintEqualToAnchor:accentLine.bottomAnchor constant:17.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroImageView.leadingAnchor constant:-14.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:7.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroImageView.leadingAnchor constant:-14.0],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.heroImageView.bottomAnchor constant:13.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.heroImageView.trailingAnchor],
        [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:92.0],
        [self.statusLabel.heightAnchor constraintEqualToConstant:24.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:12.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-22.0],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-22.0],
    ]];
    return self.heroSurfaceView;
}

- (UIView *)detailsSection {
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Status") value:[self statusText] icon:@"tag.fill"]];
    [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Owner") value:[self shortID:self.pet.ownerID] icon:@"person.crop.circle.fill"]];
    if (self.pet.ageMonths > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Age") value:[NSString stringWithFormat:kLang(@"AdoptPro_AgeMonths_Format"), (long)self.pet.ageMonths] icon:@"calendar"]];
    }
    if (self.pet.gender.length > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Gender") value:self.pet.gender icon:@"figure.stand"]];
    }
    if (self.pet.kindID > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Kind") value:[NSString stringWithFormat:@"%ld", (long)self.pet.kindID] icon:@"pawprint.fill"]];
    }
    if (self.pet.breedID > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Breed") value:[NSString stringWithFormat:@"%ld", (long)self.pet.breedID] icon:@"leaf.fill"]];
    }
    NSString *created = [self formattedDate:self.pet.createdAt];
    if (created.length > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Created") value:created icon:@"clock.fill"]];
    }
    return [self sectionWithTitle:kLang(@"AdoptPro_Section_Details") subtitle:kLang(@"AdoptPro_Section_Details_Subtitle") rows:rows];
}

- (UIView *)adopterSection {
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_Adopter") value:PPAdoptDetailDisplay(self.pet.adopterName) icon:@"heart.fill"]];
    [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_AdopterContact") value:PPAdoptDetailDisplay(self.pet.adopterContact) icon:@"phone.fill"]];
    if (self.pet.adopterUserID.length > 0) {
        [rows addObject:[self rowWithTitle:kLang(@"AdoptPro_Field_AdopterID") value:[self shortID:self.pet.adopterUserID] icon:@"number"]];
    }
    return [self sectionWithTitle:kLang(@"AdoptPro_Section_Adopter") subtitle:kLang(@"AdoptPro_Section_Adopter_Subtitle") rows:rows];
}

- (UIView *)sectionWithTitle:(NSString *)title subtitle:(NSString *)subtitle rows:(NSArray<UIView *> *)rows {
    UIView *surface = [UIView new];
    surface.backgroundColor = [self pp_surfaceColor];
    surface.layer.cornerRadius = 24.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [surface addSubview:stack];

    UILabel *titleLabel = [self labelWithFont:[Styling fontBold:18.0] color:PrimaryTextClr ?: UIColor.labelColor lines:1];
    titleLabel.text = title;
    UILabel *subtitleLabel = [self labelWithFont:[Styling fontRegular:13.0] color:SeconderyTextClr ?: UIColor.secondaryLabelColor lines:2];
    subtitleLabel.text = subtitle;
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:subtitleLabel];

    for (UIView *row in rows) {
        [stack addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:surface.topAnchor constant:18.0],
        [stack.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18.0],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-18.0],
    ]];
    return surface;
}

- (UIView *)rowWithTitle:(NSString *)title value:(NSString *)value icon:(NSString *)iconName {
    UIView *row = [UIView new];
    row.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    row.layer.cornerRadius = 17.0;
    row.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self pp_accentColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:icon];

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    titleLabel.text = title;
    [row addSubview:titleLabel];

    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:15.0] color:PrimaryTextClr ?: UIColor.labelColor lines:2];
    valueLabel.text = value;
    [row addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14.0],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14.0],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:10.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3.0],
        [valueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-10.0],
    ]];
    return row;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

#pragma mark - Action Bar

- (void)buildActionBar {
    self.actionBar = [UIView new];
    self.actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionBar.backgroundColor = [self pp_surfaceColor];
    self.actionBar.layer.cornerRadius = 28.0;
    self.actionBar.layer.cornerCurve = kCACornerCurveContinuous;
    self.actionBar.layer.shadowColor = (AppShadowColor ?: UIColor.blackColor).CGColor;
    self.actionBar.layer.shadowOpacity = 0.10;
    self.actionBar.layer.shadowRadius = 22.0;
    self.actionBar.layer.shadowOffset = CGSizeMake(0, 12.0);
    [self.view addSubview:self.actionBar];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10.0;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.actionBar addSubview:stack];

    self.primaryButton = [self buttonWithTitle:kLang(@"AdoptPro_Action_MarkAdopted") color:[self pp_accentColor] selector:@selector(primaryStatusTapped)];
    self.secondaryButton = [self buttonWithTitle:kLang(@"AdoptPro_Edit") color:[SeconderyTextClr colorWithAlphaComponent:0.78] selector:@selector(editTapped)];
    self.deleteButton = [self buttonWithTitle:kLang(@"Delete") color:UIColor.systemRedColor selector:@selector(deleteTapped)];
    [stack addArrangedSubview:self.primaryButton];
    [stack addArrangedSubview:self.secondaryButton];
    [stack addArrangedSubview:self.deleteButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [self.actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [self.actionBar.heightAnchor constraintEqualToConstant:66.0],
        [stack.topAnchor constraintEqualToAnchor:self.actionBar.topAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:self.actionBar.leadingAnchor constant:10.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.actionBar.trailingAnchor constant:-10.0],
        [stack.bottomAnchor constraintEqualToAnchor:self.actionBar.bottomAnchor constant:-10.0],
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = [color colorWithAlphaComponent:0.12];
    button.tintColor = color;
    button.layer.cornerRadius = 20.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [Styling fontBold:13.0];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)editNavButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [self pp_accentColor];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"pencil" withConfiguration:config] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = kLang(@"AdoptPro_Edit");
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:44.0],
        [button.heightAnchor constraintEqualToConstant:44.0],
    ]];
    return button;
}

#pragma mark - Content

- (void)refreshContent {
    self.titleLabel.text = self.pet.title.length > 0 ? self.pet.title : kLang(@"AdoptPro_Untitled");
    self.subtitleLabel.text = self.pet.descriptionText.length > 0 ? self.pet.descriptionText : kLang(@"AdoptPro_NoDescription");
    self.statusLabel.text = [self statusText];
    self.statusLabel.textColor = [self pp_statusColor];
    self.statusLabel.backgroundColor = [[self pp_statusColor] colorWithAlphaComponent:0.11];
    NSString *firstURL = self.pet.imageURLs.firstObject;
    if (firstURL.length > 0) {
        [self.heroImageView sd_setImageWithURL:[NSURL URLWithString:firstURL]
                              placeholderImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    }
    BOOL adopted = self.pet.isAdopted || [self.pet.status isEqualToString:@"adopted"];
    [self.primaryButton setTitle:(adopted ? kLang(@"AdoptPro_Action_MarkAvailable") : kLang(@"AdoptPro_Action_MarkAdopted")) forState:UIControlStateNormal];
}

- (NSString *)statusText {
    if (self.pet.isDeleted) return kLang(@"AdoptPro_Status_Deleted");
    if (self.pet.isBlocked) return kLang(@"AdoptPro_Status_Blocked");
    if (self.pet.visibility == 1 || [self.pet.status isEqualToString:@"hidden"]) return kLang(@"AdoptPro_Status_Hidden");
    if (self.pet.isAdopted || [self.pet.status isEqualToString:@"adopted"]) return kLang(@"AdoptPro_Status_Adopted");
    return kLang(@"AdoptPro_Status_Available");
}

- (NSString *)shortID:(NSString *)identifier {
    if (identifier.length == 0) return @"-";
    if (identifier.length <= 10) return identifier;
    return [NSString stringWithFormat:@"%@...", [identifier substringToIndex:10]];
}

- (NSString *)formattedDate:(NSDate *)date {
    if (!date) return @"";
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

#pragma mark - Actions

- (void)editTapped {
    [PPFunc pp_playTapEffect];
    PPAddEditAdoptPetViewController *vc = [[PPAddEditAdoptPetViewController alloc] initWithPet:self.pet];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)primaryStatusTapped {
    [PPFunc pp_playTapEffect];
    BOOL adopted = self.pet.isAdopted || [self.pet.status isEqualToString:@"adopted"];
    NSString *newStatus = adopted ? @"available" : @"adopted";
    [self updateStatus:newStatus];
}

- (void)updateStatus:(NSString *)status {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"AdoptPro_Updating") subtitle:nil];
    __weak typeof(self) weakSelf = self;
    [[PPAdoptPetManager sharedManager] updateAdoptStatus:self.pet.petID status:status completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPHUD dismiss];
        if (!success) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"AdoptPro_Error_Update")];
            return;
        }
        self.pet.status = status;
        self.pet.isAdopted = [status isEqualToString:@"adopted"];
        self.pet.visibility = [status isEqualToString:@"hidden"] ? 1 : 0;
        [self refreshContent];
        [PPHUD showSuccess:kLang(@"Saved") subtitle:kLang(@"AdoptPro_StatusUpdated")];
    }];
}

- (void)deleteTapped {
    [PPFunc pp_playTapEffect];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"AdoptPro_DeleteConfirmTitle")
                                                                   message:kLang(@"AdoptPro_DeleteConfirmMessage")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Deleting") subtitle:nil];
        [[PPAdoptPetManager sharedManager] deleteAdoptRequest:self.pet.petID completion:^(BOOL success, NSError *error) {
            [PPHUD dismiss];
            if (!success) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"AdoptPro_Error_Delete")];
                return;
            }
            [PPHUD showSuccess:kLang(@"Deleted") subtitle:kLang(@"AdoptPro_DeletedSuccess")];
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Motion

- (void)prepareEntranceState {
    if (self.didPrepareEntrance || self.didPlayEntrance) return;
    self.didPrepareEntrance = YES;
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.actionBar.alpha = 0.0;
    self.actionBar.transform = CGAffineTransformMakeTranslation(0, 16.0);
}

- (void)runEntranceIfNeeded {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        self.actionBar.alpha = 1.0;
        self.actionBar.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.46 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.42 delay:0.10 usingSpringWithDamping:0.88 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.actionBar.alpha = 1.0;
        self.actionBar.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
