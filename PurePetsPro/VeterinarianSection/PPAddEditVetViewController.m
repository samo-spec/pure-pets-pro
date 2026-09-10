//
//  PPAddEditVetViewController.m
//  PurePetsPro
//
//  Reinvented from first principles for iPhone & iPad.
//

#import "PPAddEditVetViewController.h"
#import "PPVetModel.h"
#import "PPVetManager.h"
#import "PPFirebaseCompat.h"
#import "PPFunc+Haptics.h"
#import "PPHUD.h"
#import "PPDesignTokens.h"
#import <PhotosUI/PhotosUI.h>

@interface PPAddEditVetViewController () <UITextViewDelegate, UITextFieldDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

// Scroll & Form Root
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

// Doctor Photo
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong, nullable) UIImage *selectedImage;

// Form Controls
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *whatsappField;
@property (nonatomic, strong) UITextField *costField;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UITextField *kindField;

// Floating Save Bar
@property (nonatomic, strong) UIView *saveBar;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSLayoutConstraint *saveBarBottomConstraint;

// iPad Live Digital Medical Pass Preview
@property (nonatomic, strong) UIView *livePassContainer;
@property (nonatomic, strong) UIImageView *passAvatarView;
@property (nonatomic, strong) UILabel *passDoctorNameLabel;
@property (nonatomic, strong) UILabel *passTypeBadgeLabel;
@property (nonatomic, strong) UIView *passTypeBadgeView;
@property (nonatomic, strong) UILabel *passFeeBadgeLabel;
@property (nonatomic, strong) UILabel *passSpecialtyLabel;
@property (nonatomic, strong) UILabel *passDateLabel;
@property (nonatomic, strong) UILabel *passContactSummaryLabel;

// Animation
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation PPAddEditVetViewController

#pragma mark - Initialization

- (instancetype)initWithVet:(PPVetModel *)vet {
    self = [super init];
    if (self) {
        _vetToEdit = vet ? [vet copy] : [[PPVetModel alloc] init];
        _isEditing = (vet != nil && vet.vetID.length > 0);
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    
    [self pp_setupBackdropGlows];
    [self pp_buildLayoutHierarchy];
    [self pp_buildFormSections];
    [self pp_buildSaveBar];
    [self pp_applyValues];
    [self pp_registerKeyboardNotifications];
    [self pp_prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *title = self.isEditing
        ? (kLang(@"Vet_Edit_Title") ?: ([Language isRTL] ? @"تعديل بيانات الطبيب" : @"Edit Doctor Profile"))
        : (kLang(@"Vet_Add_Title") ?: ([Language isRTL] ? @"إضافة طبيب بيطري" : @"Add Veterinarian"));
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
    [self pp_prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Colors & Helpers

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return AppForgroundColr;
}

- (UIColor *)pp_accentColor {
    return AppPrimaryClr;
}

- (UserModel *)pp_currentUser {
    return UsrMgr.currentUser;
}

- (BOOL)pp_canCreateVetProfile {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canPostVetProfilePermission;
}

- (BOOL)pp_canEditVetProfile {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canEditVetInfoPermission;
}

#pragma mark - Backdrop Glows

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [self pp_createGlowViewWithSize:240.0];
    self.bgGlowBottom = [self pp_createGlowViewWithSize:200.0];
    [self.view addSubview:self.bgGlowTop];
    [self.view addSubview:self.bgGlowBottom];

    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    self.bgGlowTop.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:isDark ? 0.04 : 0.09];
    self.bgGlowTop.layer.shadowColor = [self pp_accentColor].CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.03 : 0.07;
    self.bgGlowTop.layer.shadowRadius = 70.0;

    self.bgGlowBottom.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppInfo].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.05;
    self.bgGlowBottom.layer.shadowRadius = 80.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:240.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:240.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-80.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:80.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:50.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-60.0]
    ]];
}

- (UIView *)pp_createGlowViewWithSize:(CGFloat)size {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.userInteractionEnabled = NO;
    v.layer.cornerRadius = size * 0.5;
    v.layer.masksToBounds = NO;
    return v;
}

#pragma mark - Layout Hierarchy (Adaptive iPhone vs iPad)

- (void)pp_buildLayoutHierarchy {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    if (isPad) {
        [self pp_buildPadSplitStudio];
    } else {
        [self pp_buildPhoneFlow];
    }
}

- (void)pp_buildPhoneFlow {
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 116.0, 0);
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

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:12.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0],
    ]];
}

- (void)pp_buildPadSplitStudio {
    UIView *splitRoot = [UIView new];
    splitRoot.translatesAutoresizingMaskIntoConstraints = NO;
    splitRoot.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:splitRoot];

    // Left Column: Live Doctor Digital Badge & Medical Pass
    self.livePassContainer = [self pp_buildLiveMedicalPassContainer];
    [splitRoot addSubview:self.livePassContainer];

    // Right Column: Form Scroll View
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 116.0, 0);
    [splitRoot addSubview:self.scrollView];

    self.contentStack = [UIStackView new];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [splitRoot.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [splitRoot.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [splitRoot.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [splitRoot.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.livePassContainer.topAnchor constraintEqualToAnchor:splitRoot.topAnchor constant:14.0],
        [self.livePassContainer.leadingAnchor constraintEqualToAnchor:splitRoot.leadingAnchor],
        [self.livePassContainer.widthAnchor constraintEqualToConstant:370.0],
        [self.livePassContainer.bottomAnchor constraintLessThanOrEqualToAnchor:splitRoot.bottomAnchor constant:-100.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:splitRoot.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.livePassContainer.trailingAnchor constant:24.0],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:splitRoot.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:splitRoot.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
    ]];
}

#pragma mark - iPad Live Medical Pass

- (UIView *)pp_buildLiveMedicalPassContainer {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(container, PPCornerHero);
    PPApplyCardShadow(container);

    UILabel *badgeEyebrow = [self pp_labelWithFont:[Styling fontBold:PPFontCaption1] color:[self pp_accentColor] lines:1];
    badgeEyebrow.text = [Language isRTL] ? @"بطاقة الاعتماد البيطري المباشرة" : @"LIVE CLINICAL PASS";

    UILabel *badgeHeader = [self pp_labelWithFont:[Styling fontBold:PPFontTitle3] color:PrimaryTextClr lines:1];
    badgeHeader.text = [Language isRTL] ? @"معاينة بطاقة الطبيب" : @"Doctor Digital Badge";

    // Shield card inside pass
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(card, PPCornerCard);
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [[self pp_accentColor] colorWithAlphaComponent:0.18].CGColor;

    // Doctor Avatar on pass
    self.passAvatarView = [UIImageView new];
    self.passAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.passAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.passAvatarView.clipsToBounds = YES;
    self.passAvatarView.layer.cornerRadius = 36.0;
    self.passAvatarView.layer.cornerCurve = kCACornerCurveContinuous;
    self.passAvatarView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
    self.passAvatarView.layer.borderWidth = 2.0;
    self.passAvatarView.layer.borderColor = [self pp_accentColor].CGColor;
    self.passAvatarView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
    self.passAvatarView.tintColor = [self pp_accentColor];

    // Verification Seal Icon
    UIImageView *sealIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"]];
    sealIcon.translatesAutoresizingMaskIntoConstraints = NO;
    sealIcon.tintColor = [UIColor ppWarning];
    [card addSubview:sealIcon];

    self.passDoctorNameLabel = [self pp_labelWithFont:[Styling fontBold:PPFontTitle3] color:PrimaryTextClr lines:2];
    self.passDoctorNameLabel.text = [Language isRTL] ? @"اسم الطبيب المعالج" : @"Veterinarian Name";

    self.passTypeBadgeView = [UIView new];
    self.passTypeBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.passTypeBadgeView, PPCornerPill);
    self.passTypeBadgeView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];

    self.passTypeBadgeLabel = [self pp_labelWithFont:[Styling fontBold:PPFontCaption2] color:[self pp_accentColor] lines:1];
    self.passTypeBadgeLabel.text = [Language isRTL] ? @"طبيب شخصي معتمد" : @"Licensed Specialist";
    [self.passTypeBadgeView addSubview:self.passTypeBadgeLabel];

    self.passFeeBadgeLabel = [self pp_labelWithFont:[Styling fontBold:PPFontCallout] color:[self pp_accentColor] lines:1];
    self.passFeeBadgeLabel.text = [Language isRTL] ? @"رسوم الكشفية: -- ر.ق" : @"Consultation: -- QAR";

    self.passSpecialtyLabel = [self pp_labelWithFont:[Styling fontRegular:PPFontFootnote] color:SeconderyTextClr lines:3];
    self.passSpecialtyLabel.text = [Language isRTL] ? @"التخصص والخبرات الإكلينيكية البيطرية" : @"Clinical specialties and medical background";

    self.passDateLabel = [self pp_labelWithFont:[Styling fontMedium:PPFontCaption1] color:SeconderyTextClr lines:1];
    self.passDateLabel.text = [Language isRTL] ? @"📅 موعد التوفر: اليوم" : @"📅 Available: Today";

    self.passContactSummaryLabel = [self pp_labelWithFont:[Styling fontMedium:PPFontCaption2] color:[UIColor ppSuccess] lines:1];
    self.passContactSummaryLabel.text = [Language isRTL] ? @"● متاح للتواصل والاستشارة الفورية" : @"● Ready for immediate inquiries";

    [container addSubview:badgeEyebrow];
    [container addSubview:badgeHeader];
    [container addSubview:card];

    [card addSubview:self.passAvatarView];
    [card addSubview:self.passDoctorNameLabel];
    [card addSubview:self.passTypeBadgeView];
    [card addSubview:self.passFeeBadgeLabel];
    [card addSubview:self.passSpecialtyLabel];
    [card addSubview:self.passDateLabel];
    [card addSubview:self.passContactSummaryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [badgeEyebrow.topAnchor constraintEqualToAnchor:container.topAnchor constant:22.0],
        [badgeEyebrow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:22.0],
        [badgeEyebrow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-22.0],

        [badgeHeader.topAnchor constraintEqualToAnchor:badgeEyebrow.bottomAnchor constant:4.0],
        [badgeHeader.leadingAnchor constraintEqualToAnchor:badgeEyebrow.leadingAnchor],
        [badgeHeader.trailingAnchor constraintEqualToAnchor:badgeEyebrow.trailingAnchor],

        [card.topAnchor constraintEqualToAnchor:badgeHeader.bottomAnchor constant:18.0],
        [card.leadingAnchor constraintEqualToAnchor:badgeEyebrow.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:badgeEyebrow.trailingAnchor],
        [card.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-22.0],

        [self.passAvatarView.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [self.passAvatarView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.passAvatarView.widthAnchor constraintEqualToConstant:72.0],
        [self.passAvatarView.heightAnchor constraintEqualToConstant:72.0],

        [sealIcon.bottomAnchor constraintEqualToAnchor:self.passAvatarView.bottomAnchor constant:2.0],
        [sealIcon.trailingAnchor constraintEqualToAnchor:self.passAvatarView.trailingAnchor constant:4.0],
        [sealIcon.widthAnchor constraintEqualToConstant:22.0],
        [sealIcon.heightAnchor constraintEqualToConstant:22.0],

        [self.passDoctorNameLabel.topAnchor constraintEqualToAnchor:self.passAvatarView.bottomAnchor constant:12.0],
        [self.passDoctorNameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.passDoctorNameLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.passTypeBadgeView.topAnchor constraintEqualToAnchor:self.passDoctorNameLabel.bottomAnchor constant:8.0],
        [self.passTypeBadgeView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.passTypeBadgeView.heightAnchor constraintEqualToConstant:24.0],

        [self.passTypeBadgeLabel.leadingAnchor constraintEqualToAnchor:self.passTypeBadgeView.leadingAnchor constant:10.0],
        [self.passTypeBadgeLabel.trailingAnchor constraintEqualToAnchor:self.passTypeBadgeView.trailingAnchor constant:-10.0],
        [self.passTypeBadgeLabel.centerYAnchor constraintEqualToAnchor:self.passTypeBadgeView.centerYAnchor],

        [self.passFeeBadgeLabel.topAnchor constraintEqualToAnchor:self.passTypeBadgeView.bottomAnchor constant:14.0],
        [self.passFeeBadgeLabel.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],

        [self.passSpecialtyLabel.topAnchor constraintEqualToAnchor:self.passFeeBadgeLabel.bottomAnchor constant:10.0],
        [self.passSpecialtyLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.passSpecialtyLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.passDateLabel.topAnchor constraintEqualToAnchor:self.passSpecialtyLabel.bottomAnchor constant:12.0],
        [self.passDateLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.passDateLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.passContactSummaryLabel.topAnchor constraintEqualToAnchor:self.passDateLabel.bottomAnchor constant:8.0],
        [self.passContactSummaryLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.passContactSummaryLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.passContactSummaryLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20.0],
    ]];

    return container;
}

#pragma mark - Form Sections

- (void)pp_buildFormSections {
    // 1. Doctor Avatar Hero (for iPhone; iPad also has photo picker inside)
    [self.contentStack addArrangedSubview:[self pp_buildDoctorHeroSection]];

    // 2. Practice Type & Basic Credentials
    [self.contentStack addArrangedSubview:[self pp_buildCredentialsSection]];

    // 3. Clinical Specialty & Description
    [self.contentStack addArrangedSubview:[self pp_buildSpecialtySection]];

    // 4. Emergency Communications Hub
    [self.contentStack addArrangedSubview:[self pp_buildContactSection]];

    // 5. Financial & Schedule Section
    [self.contentStack addArrangedSubview:[self pp_buildFinanceAndScheduleSection]];
}

- (UIView *)pp_buildDoctorHeroSection {
    UIView *surface = [UIView new];
    surface.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(surface, PPCornerHero);
    PPApplyCardShadow(surface);

    UIView *accentLine = [UIView new];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.backgroundColor = [self pp_accentColor];
    accentLine.layer.cornerRadius = 2.5;
    [surface addSubview:accentLine];

    self.logoImageView = [UIImageView new];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoImageView.clipsToBounds = YES;
    self.logoImageView.layer.cornerRadius = 44.0;
    self.logoImageView.layer.cornerCurve = kCACornerCurveContinuous;
    self.logoImageView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
    self.logoImageView.layer.borderWidth = 3.0;
    self.logoImageView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.logoImageView.userInteractionEnabled = YES;
    [surface addSubview:self.logoImageView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickImageTapped)];
    [self.logoImageView addGestureRecognizer:tap];

    self.imagePickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *camCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [self.imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:camCfg] forState:UIControlStateNormal];
    self.imagePickerButton.tintColor = UIColor.whiteColor;
    self.imagePickerButton.backgroundColor = [self pp_accentColor];
    self.imagePickerButton.layer.cornerRadius = 16.0;
    self.imagePickerButton.layer.borderWidth = 2.0;
    self.imagePickerButton.layer.borderColor = UIColor.whiteColor.CGColor;
    [self.imagePickerButton addTarget:self action:@selector(pickImageTapped) forControlEvents:UIControlEventTouchUpInside];
    [surface addSubview:self.imagePickerButton];

    UILabel *heroTitle = [self pp_labelWithFont:[Styling fontBold:22.0] color:PrimaryTextClr lines:1];
    heroTitle.text = self.isEditing
        ? (kLang(@"Vet_Edit_Title") ?: ([Language isRTL] ? @"تعديل بيانات الطبيب" : @"Edit Doctor Profile"))
        : (kLang(@"Vet_Add_Title") ?: ([Language isRTL] ? @"اعتماد طبيب بيطري جديد" : @"Add Veterinarian"));
    heroTitle.textAlignment = NSTextAlignmentCenter;
    [surface addSubview:heroTitle];

    UILabel *heroSubtitle = [self pp_labelWithFont:[Styling fontRegular:13.0] color:SeconderyTextClr lines:2];
    heroSubtitle.text = [Language isRTL]
        ? @"قم بتسجيل وتحديث بيانات الاعتماد، والرسوم الاستشارية، ووسائل الاتصال المباشر"
        : @"Manage clinical credentials, consultation rates, and emergency contacts.";
    heroSubtitle.textAlignment = NSTextAlignmentCenter;
    [surface addSubview:heroSubtitle];

    [NSLayoutConstraint activateConstraints:@[
        [accentLine.topAnchor constraintEqualToAnchor:surface.topAnchor constant:18.0],
        [accentLine.centerXAnchor constraintEqualToAnchor:surface.centerXAnchor],
        [accentLine.widthAnchor constraintEqualToConstant:54.0],
        [accentLine.heightAnchor constraintEqualToConstant:5.0],

        [self.logoImageView.topAnchor constraintEqualToAnchor:accentLine.bottomAnchor constant:16.0],
        [self.logoImageView.centerXAnchor constraintEqualToAnchor:surface.centerXAnchor],
        [self.logoImageView.widthAnchor constraintEqualToConstant:88.0],
        [self.logoImageView.heightAnchor constraintEqualToConstant:88.0],

        [self.imagePickerButton.bottomAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:2.0],
        [self.imagePickerButton.trailingAnchor constraintEqualToAnchor:self.logoImageView.trailingAnchor constant:2.0],
        [self.imagePickerButton.widthAnchor constraintEqualToConstant:32.0],
        [self.imagePickerButton.heightAnchor constraintEqualToConstant:32.0],

        [heroTitle.topAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:14.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],

        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:6.0],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [heroSubtitle.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-20.0],
    ]];

    return surface;
}

- (UIView *)pp_buildCredentialsSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"بيانات الطبيب ونمط الممارسة" : @"Doctor & Practice Type"
                                              subtitle:[Language isRTL] ? @"اسم الطبيب أو المركز وتصنيف الاعتماد الرسمي" : @"Official title and licensing category"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    self.titleField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"د. محمد أحمد (أو مجمع بيور بيتس البيطري)" : @"Dr. Full Name or Veterinary Hospital" icon:@"person.text.rectangle.fill"];
    [self.titleField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"اسم الطبيب / المركز البيطري *" : @"Veterinarian / Clinic Name *" content:self.titleField height:58.0]];

    // Practice Type Segment
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"Vet_Type_Personal") ?: ([Language isRTL] ? @"طبيب شخصي مستقل" : @"Individual Specialist"),
        kLang(@"Vet_Type_Company") ?: ([Language isRTL] ? @"عيادة / مركز بيطري" : @"Clinic / Hospital")
    ]];
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.selectedSegmentTintColor = [[self pp_accentColor] colorWithAlphaComponent:0.18];
    [self.typeSegment setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:13.0],
        NSForegroundColorAttributeName: SeconderyTextClr
    } forState:UIControlStateNormal];
    [self.typeSegment setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:13.0],
        NSForegroundColorAttributeName: [self pp_accentColor]
    } forState:UIControlStateSelected];
    [self.typeSegment addTarget:self action:@selector(pp_typeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"نمط الترخيص والممارسة *" : @"Practice Category *" content:self.typeSegment height:52.0]];

    return surface;
}

- (UIView *)pp_buildSpecialtySection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"التخصص والخبرات الإكلينيكية" : @"Clinical Specialty & Bio"
                                              subtitle:[Language isRTL] ? @"اختر التخصصات السريعة وأضف تفاصيل الخبرة الطبية" : @"Select quick specialty tags and describe medical background"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    // Quick specialty tags row
    [stack addArrangedSubview:[self pp_specialtyChipsRow]];

    // Description text view
    UIView *descShell = [self pp_textViewShellWithTitle:[Language isRTL] ? @"النبذة الطبية والخدمات المقدمة *" : @"Medical Bio & Services *"];
    [stack addArrangedSubview:descShell];

    return surface;
}

- (UIView *)pp_specialtyChipsRow {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.alwaysBounceHorizontal = YES;

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:38.0],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    NSArray<NSString *> *tags = [Language isRTL]
        ? @[@"#طب_وجراحة_عامة", @"#باطنية_بيطرية", @"#أسنان_بيطرية", @"#جلدية_وحساسية", @"#لقاحات_وتطعيم", @"#طوارئ_وعناية_مركزة", @"#سونار_وأشعة"]
        : @[@"#GeneralMedicine", @"#InternalMedicine", @"#DentalSurgery", @"#Dermatology", @"#Vaccinations", @"#EmergencyCare", @"#Ultrasound"];

    for (NSString *tag in tags) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.titleLabel.font = [Styling fontMedium:12.5];
        [btn setTitle:tag forState:UIControlStateNormal];
        [btn setTitleColor:[self pp_accentColor] forState:UIControlStateNormal];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [btn addTarget:self action:@selector(pp_specialtyChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:btn];
    }

    return scroll;
}

- (void)pp_specialtyChipTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *tag = [sender titleForState:UIControlStateNormal];
    if (!tag.length) return;
    NSString *current = self.descriptionView.text ?: @"";
    if (current.length > 0) {
        self.descriptionView.text = [NSString stringWithFormat:@"%@ %@", current, tag];
    } else {
        self.descriptionView.text = tag;
    }
    self.descriptionPlaceholder.hidden = (self.descriptionView.text.length > 0);
    [self pp_liveValuesChanged];
}

- (UIView *)pp_buildContactSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"الاتصال السريع والطوارئ" : @"Direct Communications Hub"
                                              subtitle:[Language isRTL] ? @"أرقام الاتصال المباشر والواتساب للاستشارات السريعة" : @"Direct emergency phone and WhatsApp inquiries"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    self.phoneField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"رقم الهاتف المحمول (مثال: 974XXXXXXXX+)" : @"+974 XXXXXXXX" icon:@"phone.circle.fill"];
    self.phoneField.keyboardType = UIKeyboardTypePhonePad;
    [self.phoneField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"رقم الهاتف المباشر" : @"Direct Phone" content:self.phoneField height:58.0]];

    self.whatsappField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"رقم الواتساب للاستشارات (مثال: 974XXXXXXXX+)" : @"+974 XXXXXXXX (WhatsApp)" icon:@"message.circle.fill"];
    self.whatsappField.keyboardType = UIKeyboardTypePhonePad;
    [self.whatsappField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"رقم الواتساب" : @"WhatsApp Number" content:self.whatsappField height:58.0]];

    return surface;
}

- (UIView *)pp_buildFinanceAndScheduleSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"الرسوم الاستشارية والجدول" : @"Consultation Fee & Availability"
                                              subtitle:[Language isRTL] ? @"تحديد رسوم الكشفية بالريال القطري وموعد التوفر" : @"Set consultation fee in QAR and clinic schedule"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    // Consultation Fee field with QAR pill
    self.costField = [self pp_textFieldWithPlaceholder:@"150" icon:@"banknote.fill"];
    self.costField.keyboardType = UIKeyboardTypeDecimalPad;
    [self.costField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];

    UIView *feeContainer = [self pp_feeFieldShell];
    [stack addArrangedSubview:feeContainer];

    // Quick Stepper Chips (+25, +50, +100)
    [stack addArrangedSubview:[self pp_feeStepperChipsRow]];

    // Date Picker Container
    UIView *dateBox = [UIView new];
    dateBox.translatesAutoresizingMaskIntoConstraints = NO;
    dateBox.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    PPApplyContinuousCorners(dateBox, PPCornerInput);

    UIImageView *calendarIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"calendar"]];
    calendarIcon.translatesAutoresizingMaskIntoConstraints = NO;
    calendarIcon.tintColor = [self pp_accentColor];
    [dateBox addSubview:calendarIcon];

    UILabel *dateLabel = [self pp_labelWithFont:[Styling fontBold:14.0] color:PrimaryTextClr lines:1];
    dateLabel.text = [Language isRTL] ? @"موعد توفر الحجز في العيادة" : @"Clinic Availability Date";
    [dateBox addSubview:dateLabel];

    self.datePicker = [UIDatePicker new];
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    if (@available(iOS 13.4, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    [self.datePicker addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventValueChanged];
    [dateBox addSubview:self.datePicker];

    [NSLayoutConstraint activateConstraints:@[
        [dateBox.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [calendarIcon.leadingAnchor constraintEqualToAnchor:dateBox.leadingAnchor constant:16.0],
        [calendarIcon.centerYAnchor constraintEqualToAnchor:dateBox.centerYAnchor],
        [calendarIcon.widthAnchor constraintEqualToConstant:22.0],
        [calendarIcon.heightAnchor constraintEqualToConstant:22.0],

        [dateLabel.leadingAnchor constraintEqualToAnchor:calendarIcon.trailingAnchor constant:10.0],
        [dateLabel.centerYAnchor constraintEqualToAnchor:dateBox.centerYAnchor],

        [self.datePicker.trailingAnchor constraintEqualToAnchor:dateBox.trailingAnchor constant:-14.0],
        [self.datePicker.centerYAnchor constraintEqualToAnchor:dateBox.centerYAnchor],
        [self.datePicker.leadingAnchor constraintGreaterThanOrEqualToAnchor:dateLabel.trailingAnchor constant:8.0],
    ]];
    [stack addArrangedSubview:dateBox];

    // Main Pet Kind ID
    self.kindField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"رقم تصنيف الحيوان الرئيسي (مثال: 1 للكلاب، 2 للقطط)" : @"Species Kind ID (e.g. 1 Dogs, 2 Cats)" icon:@"pawprint.fill"];
    self.kindField.keyboardType = UIKeyboardTypeNumberPad;
    [self.kindField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"تصنيف الحيوانات المعتمدة" : @"Target Species ID" content:self.kindField height:58.0]];

    return surface;
}

- (UIView *)pp_feeFieldShell {
    UIView *shell = [UIView new];
    shell.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    PPApplyContinuousCorners(shell, PPCornerInput);

    UILabel *titleLabel = [self pp_labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    titleLabel.text = [Language isRTL] ? @"رسوم الكشفية والاستشارة (ر.ق)" : @"Consultation Fee (QAR)";
    [shell addSubview:titleLabel];

    [shell addSubview:self.costField];

    UILabel *qarPill = [self pp_labelWithFont:[Styling fontBold:12.0] color:[self pp_accentColor] lines:1];
    qarPill.text = [Language isRTL] ? @"ر.ق QAR" : @"QAR";
    qarPill.textAlignment = NSTextAlignmentCenter;
    qarPill.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(qarPill, PPCornerPill);
    [shell addSubview:qarPill];

    [NSLayoutConstraint activateConstraints:@[
        [shell.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [titleLabel.topAnchor constraintEqualToAnchor:shell.topAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],

        [self.costField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [self.costField.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.costField.trailingAnchor constraintEqualToAnchor:qarPill.leadingAnchor constant:-10.0],
        [self.costField.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-9.0],

        [qarPill.centerYAnchor constraintEqualToAnchor:self.costField.centerYAnchor],
        [qarPill.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],
        [qarPill.widthAnchor constraintEqualToConstant:64.0],
        [qarPill.heightAnchor constraintEqualToConstant:28.0],
    ]];

    return shell;
}

- (UIView *)pp_feeStepperChipsRow {
    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10.0;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSArray<NSNumber *> *increments = @[@25, @50, @100];
    for (NSNumber *inc in increments) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.titleLabel.font = [Styling fontBold:13.0];
        [btn setTitle:[NSString stringWithFormat:@"+%@ %@", inc, [Language isRTL] ? @"ر.ق" : @"QAR"] forState:UIControlStateNormal];
        [btn setTitleColor:[self pp_accentColor] forState:UIControlStateNormal];
        btn.tag = inc.integerValue;
        [btn addTarget:self action:@selector(pp_feeStepperTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:36.0].active = YES;
        [stack addArrangedSubview:btn];
    }
    return stack;
}

- (void)pp_feeStepperTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    double current = [self.costField.text doubleValue];
    double updated = current + sender.tag;
    self.costField.text = [NSString stringWithFormat:@"%.0f", updated];
    [self pp_liveValuesChanged];
}

#pragma mark - Field / Section Factory Helpers

- (UIView *)pp_sectionSurfaceWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *surface = [UIView new];
    surface.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(surface, PPCornerCard);
    PPApplyCardBorder(surface);

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.tag = 8801;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [surface addSubview:stack];

    UILabel *titleLabel = [self pp_labelWithFont:[Styling fontBold:17.0] color:PrimaryTextClr lines:1];
    titleLabel.text = title;
    UILabel *subtitleLabel = [self pp_labelWithFont:[Styling fontRegular:12.5] color:SeconderyTextClr lines:2];
    subtitleLabel.text = subtitle;
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:surface.topAnchor constant:18.0],
        [stack.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18.0],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-18.0],
    ]];
    return surface;
}

- (UIView *)pp_fieldShellWithTitle:(NSString *)title content:(UIView *)content height:(CGFloat)height {
    UIView *shell = [UIView new];
    shell.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    PPApplyContinuousCorners(shell, PPCornerInput);

    UILabel *titleLabel = [self pp_labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    titleLabel.text = title;
    [shell addSubview:titleLabel];
    [shell addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [shell.heightAnchor constraintGreaterThanOrEqualToConstant:height],
        [titleLabel.topAnchor constraintEqualToAnchor:shell.topAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],
        [content.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [content.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-9.0],
    ]];
    return shell;
}

- (UIView *)pp_textViewShellWithTitle:(NSString *)title {
    UIView *shell = [UIView new];
    shell.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    PPApplyContinuousCorners(shell, PPCornerInput);

    UILabel *titleLabel = [self pp_labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    titleLabel.text = title;
    [shell addSubview:titleLabel];

    self.descriptionView = [UITextView new];
    self.descriptionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionView.backgroundColor = UIColor.clearColor;
    self.descriptionView.font = [Styling fontRegular:15.0];
    self.descriptionView.textColor = PrimaryTextClr;
    self.descriptionView.textAlignment = Language.alignmentForCurrentLanguage;
    self.descriptionView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.descriptionView.delegate = self;
    self.descriptionView.scrollEnabled = NO;
    [shell addSubview:self.descriptionView];

    self.descriptionPlaceholder = [self pp_labelWithFont:[Styling fontRegular:15.0] color:[SeconderyTextClr colorWithAlphaComponent:0.60] lines:2];
    self.descriptionPlaceholder.text = [Language isRTL]
        ? @"اكتب نبذة عن التخصص، المؤهلات والخبرات السابقة، والخدمات المتوفرة بالعيادة..."
        : @"Provide details about medical specialties, qualifications, and clinic services...";
    [shell addSubview:self.descriptionPlaceholder];

    [NSLayoutConstraint activateConstraints:@[
        [shell.heightAnchor constraintGreaterThanOrEqualToConstant:132.0],
        [titleLabel.topAnchor constraintEqualToAnchor:shell.topAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],

        [self.descriptionView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [self.descriptionView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor constant:-4.0],
        [self.descriptionView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:4.0],
        [self.descriptionView.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-8.0],

        [self.descriptionPlaceholder.topAnchor constraintEqualToAnchor:self.descriptionView.topAnchor constant:8.0],
        [self.descriptionPlaceholder.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.descriptionPlaceholder.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
    ]];
    return shell;
}

- (UITextField *)pp_textFieldWithPlaceholder:(NSString *)placeholder icon:(NSString *)iconName {
    UITextField *field = [UITextField new];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.backgroundColor = UIColor.clearColor;
    field.font = [Styling fontBold:15.0];
    field.textColor = PrimaryTextClr;
    field.tintColor = [self pp_accentColor];
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyNext;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @"" attributes:@{
        NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:0.55],
        NSFontAttributeName: [Styling fontRegular:14.0]
    }];
    [field addTarget:self action:@selector(pp_normalizeArabicDigitsForField:) forControlEvents:UIControlEventEditingChanged];
    return field;
}

- (UILabel *)pp_labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

#pragma mark - Floating Save Bar

- (void)pp_buildSaveBar {
    self.saveBar = [UIView new];
    self.saveBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveBar.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.saveBar, PPCornerHero);
    PPApplyFloatingBarShadow(self.saveBar);
    [self.view addSubview:self.saveBar];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.backgroundColor = [self pp_accentColor];
    self.saveButton.tintColor = UIColor.whiteColor;
    PPApplyContinuousCorners(self.saveButton, PPCornerButton);
    self.saveButton.titleLabel.font = [Styling fontBold:16.0];
    [self.saveButton setTitle:self.isEditing
        ? (kLang(@"Vet_Action_Save") ?: ([Language isRTL] ? @"حفظ التعديلات" : @"Save Changes"))
        : (kLang(@"Vet_Action_Save") ?: ([Language isRTL] ? @"اعتماد الملف الطبي" : @"Save Doctor Profile"))
                     forState:UIControlStateNormal];
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.saveBar addSubview:self.saveButton];

    self.saveBarBottomConstraint = [self.saveBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.saveBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.saveBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        self.saveBarBottomConstraint,
        [self.saveBar.heightAnchor constraintEqualToConstant:66.0],

        [self.saveButton.topAnchor constraintEqualToAnchor:self.saveBar.topAnchor constant:10.0],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.saveBar.leadingAnchor constant:10.0],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.saveBar.trailingAnchor constant:-10.0],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:self.saveBar.bottomAnchor constant:-10.0],
    ]];
}

#pragma mark - Live Sync & Form Populating

- (void)pp_applyValues {
    if (!self.isEditing) {
        self.logoImageView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.logoImageView.tintColor = [self pp_accentColor];
        self.logoImageView.contentMode = UIViewContentModeCenter;
        [self pp_liveValuesChanged];
        return;
    }

    PPVetModel *v = self.vetToEdit;
    self.titleField.text = v.title ?: @"";
    self.phoneField.text = v.phone ?: @"";
    self.whatsappField.text = v.whatsapp ?: @"";
    self.descriptionView.text = v.descriptionText ?: @"";
    self.descriptionPlaceholder.hidden = (self.descriptionView.text.length > 0);
    self.costField.text = (v.vetCost > 0) ? [NSString stringWithFormat:@"%.0f", v.vetCost] : @"";
    self.datePicker.date = v.availableDate ?: [NSDate date];
    self.kindField.text = (v.petMainKindID > 0) ? [NSString stringWithFormat:@"%ld", (long)v.petMainKindID] : @"";
    self.typeSegment.selectedSegmentIndex = (v.type == PPVetTypeCompany) ? 1 : 0;

    if (v.logoURL.length > 0) {
        [self.logoImageView setImageFromUrl:v.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
        self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
        if (self.passAvatarView) {
            [self.passAvatarView setImageFromUrl:v.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
        }
    } else {
        self.logoImageView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.logoImageView.tintColor = [self pp_accentColor];
        self.logoImageView.contentMode = UIViewContentModeCenter;
    }

    [self pp_liveValuesChanged];
}

- (void)pp_typeSegmentChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    [self pp_liveValuesChanged];
}

- (void)pp_liveValuesChanged {
    if (!self.livePassContainer) return;

    NSString *name = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.passDoctorNameLabel.text = (name.length > 0) ? name : ([Language isRTL] ? @"اسم الطبيب المعالج" : @"Veterinarian Name");

    BOOL isCompany = (self.typeSegment.selectedSegmentIndex == 1);
    self.passTypeBadgeLabel.text = isCompany
        ? ([Language isRTL] ? @"عيادة / مركز بيطري" : @"Licensed Clinic")
        : ([Language isRTL] ? @"طبيب شخصي معتمد" : @"Licensed Specialist");

    double fee = [self.costField.text doubleValue];
    if (fee > 0) {
        self.passFeeBadgeLabel.text = [NSString stringWithFormat:@"%@: %.0f %@", [Language isRTL] ? @"رسوم الكشفية" : @"Consultation", fee, [Language isRTL] ? @"ر.ق" : @"QAR"];
    } else {
        self.passFeeBadgeLabel.text = [Language isRTL] ? @"رسوم الكشفية: غير محددة" : @"Consultation: Free / Not Set";
    }

    NSString *desc = [self.descriptionView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.passSpecialtyLabel.text = (desc.length > 0) ? desc : ([Language isRTL] ? @"التخصص والخبرات الإكلينيكية البيطرية" : @"Clinical specialties and medical background");

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterNoStyle;
    NSString *dateStr = [df stringFromDate:self.datePicker.date];
    self.passDateLabel.text = [NSString stringWithFormat:@"%@: %@", [Language isRTL] ? @"📅 موعد التوفر" : @"📅 Available", dateStr];

    BOOL hasContact = (self.phoneField.text.length > 0 || self.whatsappField.text.length > 0);
    self.passContactSummaryLabel.text = hasContact
        ? ([Language isRTL] ? @"● متاح للتواصل والاستشارة الفورية" : @"● Ready for direct inquiries")
        : ([Language isRTL] ? @"○ يرجى إدخال هاتف أو واتساب للطوارئ" : @"○ Emergency contacts not set");
    self.passContactSummaryLabel.textColor = hasContact ? [UIColor ppSuccess] : [UIColor ppWarning];
}

#pragma mark - Save Action

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];

    if ((self.isEditing && ![self pp_canEditVetProfile]) || (!self.isEditing && ![self pp_canCreateVetProfile])) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
        return;
    }

    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Vet_Validation_NameRequired") ?: ([Language isRTL] ? @"يرجى كتابة اسم الطبيب أو العيادة" : @"Please enter doctor or clinic name")];
        [self.titleField becomeFirstResponder];
        return;
    }

    PPVetModel *model = self.vetToEdit ? [self.vetToEdit copy] : [[PPVetModel alloc] init];
    model.title           = title;
    model.phone           = PPSafeString(self.phoneField.text);
    model.whatsapp        = PPSafeString(self.whatsappField.text);
    model.descriptionText = PPSafeString(self.descriptionView.text);
    model.vetCost         = [self.costField.text doubleValue];
    model.availableDate   = self.datePicker.date;
    model.petMainKindID   = [self.kindField.text integerValue];
    model.type            = (self.typeSegment.selectedSegmentIndex == 1) ? PPVetTypeCompany : PPVetTypePersonal;

    if (!self.isEditing) {
        model.userID = [FIRAuth auth].currentUser.uid ?: @"";
        model.canEditProfile = YES;
        model.canPostServices = YES;
        model.canPostMedicines = NO;
        model.verificationStatus = @"pending";
    }

    if (model.animalTypes.count == 0 && model.petMainKindID > 0) {
        model.animalTypes = @[[NSString stringWithFormat:@"%ld", (long)model.petMainKindID]];
    }
    model.readyToContact = (model.phone.length > 0 || model.whatsapp.length > 0);

    self.saveButton.enabled = NO;
    self.saveButton.alpha = 0.72;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Vet_Saving") ?: ([Language isRTL] ? @"جاري الحفظ..." : @"Saving...") subtitle:nil];

    __weak typeof(self) weakSelf = self;
    PPVetVoidBlock done = ^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        self.saveButton.enabled = YES;
        self.saveButton.alpha = 1.0;
        [PPHUD dismiss];
        if (error) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            return;
        }
        NSString *msg = self.isEditing
            ? (kLang(@"Vet_Updated_Success") ?: ([Language isRTL] ? @"تم تحديث ملف الطبيب بنجاح" : @"Doctor profile updated successfully"))
            : (kLang(@"Vet_Added_Success") ?: ([Language isRTL] ? @"تم إضافة الطبيب البيطري بنجاح" : @"Doctor profile registered successfully"));
        [PPHUD showSuccess:kLang(@"Success_Title") subtitle:msg];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
    };

    if (self.isEditing) {
        [[PPVetManager sharedManager] updateVet:model image:self.selectedImage completion:done];
    } else {
        [[PPVetManager sharedManager] addVet:model image:self.selectedImage completion:done];
    }
}

#pragma mark - Image Picker

- (void)pickImageTapped {
    [PPFunc pp_playTapEffect];
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *first = results.firstObject;
    if ([first.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        __weak typeof(self) weakSelf = self;
        [first.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if ([object isKindOfClass:[UIImage class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    self.selectedImage = (UIImage *)object;
                    self.logoImageView.image = self.selectedImage;
                    self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
                    if (self.passAvatarView) {
                        self.passAvatarView.image = self.selectedImage;
                        self.passAvatarView.contentMode = UIViewContentModeScaleAspectFill;
                    }
                });
            }
        }];
    }
}

#pragma mark - Hardware Keyboard Support (iPad)

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        return nil;
    }
    return @[
        [UIKeyCommand keyCommandWithInput:@"s"
                            modifierFlags:UIKeyModifierCommand
                                   action:@selector(saveTapped)
                     discoverabilityTitle:[Language isRTL] ? @"حفظ الملف الطبي" : @"Save Doctor Profile"],
        [UIKeyCommand keyCommandWithInput:@"p"
                            modifierFlags:UIKeyModifierCommand
                                   action:@selector(pickImageTapped)
                     discoverabilityTitle:[Language isRTL] ? @"اختيار صورة الطبيب" : @"Pick Doctor Photo"],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                            modifierFlags:0
                                   action:@selector(pp_handleEscapeKey)
                     discoverabilityTitle:[Language isRTL] ? @"رجوع / إلغاء" : @"Back / Cancel"]
    ];
}

- (void)pp_handleEscapeKey {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Text Delegates

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.titleField) {
        [self.descriptionView becomeFirstResponder];
    } else if (textField == self.phoneField) {
        [self.whatsappField becomeFirstResponder];
    } else if (textField == self.whatsappField) {
        [self.costField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.descriptionPlaceholder.hidden = (textView.text.length > 0);
    [self pp_liveValuesChanged];
}

- (void)pp_normalizeArabicDigitsForField:(UITextField *)textField {
    NSString *raw = textField.text;
    if (!raw.length) return;
    NSString *normalized = [PPFunc normalizedNumericString:raw];
    if (![normalized isEqualToString:raw]) {
        textField.text = normalized;
    }
}

#pragma mark - Keyboard Management

- (void)pp_registerKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillChange:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    CGRect endFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:endFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(converted));
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat target = (overlap > 0) ? -(overlap - safeBottom + 12.0) : -12.0;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue] ?: 0.25;
    UIViewAnimationOptions options = (UIViewAnimationOptions)([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    self.saveBarBottomConstraint.constant = target;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Motion & Entrance

- (void)pp_prepareEntranceState {
    if (self.didPrepareEntrance || self.didPlayEntrance) return;
    self.didPrepareEntrance = YES;
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.saveBar.alpha = 0.0;
    self.saveBar.transform = CGAffineTransformMakeTranslation(0, 16.0);
    if (self.livePassContainer) {
        self.livePassContainer.alpha = 0.0;
        self.livePassContainer.transform = CGAffineTransformMakeTranslation(-12.0, 0);
    }
}

- (void)pp_runEntranceIfNeeded {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        self.saveBar.alpha = 1.0;
        self.saveBar.transform = CGAffineTransformIdentity;
        if (self.livePassContainer) {
            self.livePassContainer.alpha = 1.0;
            self.livePassContainer.transform = CGAffineTransformIdentity;
        }
        return;
    }
    [UIView animateWithDuration:0.46 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        if (self.livePassContainer) {
            self.livePassContainer.alpha = 1.0;
            self.livePassContainer.transform = CGAffineTransformIdentity;
        }
    } completion:nil];
    [UIView animateWithDuration:0.42 delay:0.10 usingSpringWithDamping:0.88 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.saveBar.alpha = 1.0;
        self.saveBar.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
