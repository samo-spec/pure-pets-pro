//
//  PPAddEditVetViewController.m
//  PurePetsPro
//
//  Reinvented from first principles for iPhone & iPad.
//  Apple Design Award caliber Clinical Credentialing Studio & Live Digital Pass.
//

#import "PPAddEditVetViewController.h"
#import "PPVetModel.h"
#import "PPVetManager.h"
#import "PPFirebaseCompat.h"
#import "PPFunc+Haptics.h"
#import "PPHUD.h"
#import "PPDesignTokens.h"
#import <PhotosUI/PhotosUI.h>

@interface PPAddEditVetViewController () <UITextViewDelegate, UITextFieldDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIPointerInteractionDelegate>
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

// Scroll & Form Root
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *splitRoot;
@property (nonatomic, strong) NSLayoutConstraint *splitRootLeading;
@property (nonatomic, strong) NSLayoutConstraint *splitRootTrailing;
@property (nonatomic, strong) NSLayoutConstraint *scrollViewLeadingToPassConstraint;
@property (nonatomic, strong) NSLayoutConstraint *scrollViewLeadingToRootConstraint;

// Doctor Photo
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong, nullable) UIImage *selectedImage;

// Form Controls
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UILabel *charCountLabel;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *whatsappField;
@property (nonatomic, strong) UITextField *costField;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UITextField *kindField;

// Interactive Specialty Matrix
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedSpecialties;
@property (nonatomic, strong) NSMutableArray<UIButton *> *specialtyButtons;

// Floating Frosted Save Bar
@property (nonatomic, strong) UIVisualEffectView *saveBarBlur;
@property (nonatomic, strong) UIView *saveBar;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSLayoutConstraint *saveBarBottomConstraint;

// iPad Live Digital Clinical Pass (Apple Wallet / Credential Pass)
@property (nonatomic, strong) UIView *livePassContainer;
@property (nonatomic, strong) UIView *passCard;
@property (nonatomic, strong) UIImageView *passAvatarView;
@property (nonatomic, strong) UILabel *passDoctorNameLabel;
@property (nonatomic, strong) UILabel *passTypeBadgeLabel;
@property (nonatomic, strong) UIView *passTypeBadgeView;
@property (nonatomic, strong) UILabel *passFeeBadgeLabel;
@property (nonatomic, strong) UIStackView *passSpecialtiesStack;
@property (nonatomic, strong) UILabel *passBioPreviewLabel;
@property (nonatomic, strong) UILabel *passDateLabel;
@property (nonatomic, strong) UILabel *passContactStatusLabel;
@property (nonatomic, strong) UIView *passStatusDot;
@property (nonatomic, strong) UILabel *passLicenseCodeLabel;

// Animation & State Flags
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
        _selectedSpecialties = [NSMutableSet new];
        _specialtyButtons = [NSMutableArray new];
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
        : (kLang(@"Vet_Add_Title") ?: ([Language isRTL] ? @"اعتماد طبيب بيطري جديد" : @"Add Veterinarian"));
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
    [self pp_prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateLayoutForCurrentSize];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self pp_updateLayoutForCurrentSize];
        [self.view layoutIfNeeded];
    } completion:nil];
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
    self.bgGlowTop = [self pp_createGlowViewWithSize:260.0];
    self.bgGlowBottom = [self pp_createGlowViewWithSize:220.0];
    [self.view addSubview:self.bgGlowTop];
    [self.view addSubview:self.bgGlowBottom];

    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    self.bgGlowTop.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:isDark ? 0.04 : 0.08];
    self.bgGlowTop.layer.shadowColor = [self pp_accentColor].CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.03 : 0.06;
    self.bgGlowTop.layer.shadowRadius = 80.0;

    self.bgGlowBottom.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:isDark ? 0.03 : 0.05];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppInfo].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.04;
    self.bgGlowBottom.layer.shadowRadius = 90.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:260.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:260.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-90.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:90.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:60.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-70.0]
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

- (BOOL)pp_shouldUsePadSplitLayout {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && self.view.bounds.size.width >= 720.0);
}

- (void)pp_buildLayoutHierarchy {
    self.splitRoot = [UIView new];
    self.splitRoot.translatesAutoresizingMaskIntoConstraints = NO;
    self.splitRoot.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.splitRoot];

    // Left Column: Live Doctor Digital Pass (Apple Wallet Style)
    self.livePassContainer = [self pp_buildLiveMedicalPassContainer];
    [self.splitRoot addSubview:self.livePassContainer];

    // Right Column: Form Scroll View
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 116.0, 0);
    [self.splitRoot addSubview:self.scrollView];

    self.contentStack = [UIStackView new];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.splitRootLeading = [self.splitRoot.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0];
    self.splitRootTrailing = [self.splitRoot.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0];

    self.scrollViewLeadingToPassConstraint = [self.scrollView.leadingAnchor constraintEqualToAnchor:self.livePassContainer.trailingAnchor constant:24.0];
    self.scrollViewLeadingToRootConstraint = [self.scrollView.leadingAnchor constraintEqualToAnchor:self.splitRoot.leadingAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.splitRoot.topAnchor constraintEqualToAnchor:safe.topAnchor],
        self.splitRootLeading,
        self.splitRootTrailing,
        [self.splitRoot.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.splitRoot.topAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.splitRoot.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.splitRoot.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
    ]];

    [self pp_setupResponsivePassConstraints];
    [self pp_updateLayoutForCurrentSize];
}

- (void)pp_setupResponsivePassConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.livePassContainer.topAnchor constraintEqualToAnchor:self.splitRoot.topAnchor constant:14.0],
        [self.livePassContainer.leadingAnchor constraintEqualToAnchor:self.splitRoot.leadingAnchor],
        [self.livePassContainer.widthAnchor constraintEqualToConstant:380.0],
        [self.livePassContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.splitRoot.bottomAnchor constant:-90.0],
    ]];
}

- (void)pp_updateLayoutForCurrentSize {
    BOOL useSplit = [self pp_shouldUsePadSplitLayout];

    if (useSplit) {
        self.livePassContainer.hidden = NO;
        self.splitRootLeading.constant = 24.0;
        self.splitRootTrailing.constant = -24.0;
        self.scrollViewLeadingToRootConstraint.active = NO;
        self.scrollViewLeadingToPassConstraint.active = YES;
    } else {
        self.livePassContainer.hidden = YES;
        self.splitRootLeading.constant = 16.0;
        self.splitRootTrailing.constant = -16.0;
        self.scrollViewLeadingToPassConstraint.active = NO;
        self.scrollViewLeadingToRootConstraint.active = YES;
    }
}

#pragma mark - iPad Live Digital Clinical Pass (Apple Wallet Standard)

- (UIView *)pp_buildLiveMedicalPassContainer {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    // Eyebrow and Section Header
    UILabel *badgeEyebrow = [self pp_labelWithFont:[Styling fontBold:PPFontCaption1] color:[self pp_accentColor] lines:1];
    badgeEyebrow.text = [Language isRTL] ? @"بطاقة الاعتماد البيطري الرقمية · استوديو المعاينة" : @"DIGITAL CLINICAL CREDENTIAL · LIVE PASS";

    UILabel *badgeHeader = [self pp_labelWithFont:[Styling fontBold:PPFontTitle3] color:PrimaryTextClr lines:1];
    badgeHeader.text = [Language isRTL] ? @"بطاقة الطبيب المباشرة" : @"Doctor Credential Pass";

    // Pass Card Root
    self.passCard = [UIView new];
    self.passCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.passCard.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.passCard, PPCornerHero);
    PPApplyElevatedShadow(self.passCard);
    self.passCard.layer.borderWidth = 1.0;
    self.passCard.layer.borderColor = [[self pp_accentColor] colorWithAlphaComponent:0.20].CGColor;
    self.passCard.clipsToBounds = YES;

    // Add pointer interaction for trackpad
    if (@available(iOS 13.4, *)) {
        UIPointerInteraction *hover = [[UIPointerInteraction alloc] initWithDelegate:self];
        [self.passCard addInteraction:hover];
    }

    // Top Holographic Gradient Ribbon
    UIView *ribbon = [UIView new];
    ribbon.translatesAutoresizingMaskIntoConstraints = NO;
    ribbon.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];
    [self.passCard addSubview:ribbon];

    // Verification Seal Icon
    UIImageView *sealIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"]];
    sealIcon.translatesAutoresizingMaskIntoConstraints = NO;
    sealIcon.tintColor = [UIColor ppWarning];
    [ribbon addSubview:sealIcon];

    UILabel *passAuthorityLabel = [self pp_labelWithFont:[Styling fontBold:11.0] color:[self pp_accentColor] lines:1];
    passAuthorityLabel.text = [Language isRTL] ? @"بيور بيتس · ترخيص الممارسة الإكلينيكية" : @"PUREPETS LICENSED CLINICAL PRACTICE";
    [ribbon addSubview:passAuthorityLabel];

    // Pass Avatar View (Continuous Squircle)
    self.passAvatarView = [UIImageView new];
    self.passAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.passAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.passAvatarView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.passAvatarView, 28.0);
    self.passAvatarView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
    self.passAvatarView.layer.borderWidth = 2.5;
    self.passAvatarView.layer.borderColor = [self pp_accentColor].CGColor;
    self.passAvatarView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
    self.passAvatarView.tintColor = [self pp_accentColor];
    [self.passCard addSubview:self.passAvatarView];

    // Doctor Name on Pass
    self.passDoctorNameLabel = [self pp_labelWithFont:[Styling fontBold:20.0] color:PrimaryTextClr lines:2];
    self.passDoctorNameLabel.text = [Language isRTL] ? @"اسم الطبيب المعالج" : @"Veterinarian Name";
    [self.passCard addSubview:self.passDoctorNameLabel];

    // Practice Type Badge Pill
    self.passTypeBadgeView = [UIView new];
    self.passTypeBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.passTypeBadgeView, PPCornerPill);
    self.passTypeBadgeView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];
    [self.passCard addSubview:self.passTypeBadgeView];

    self.passTypeBadgeLabel = [self pp_labelWithFont:[Styling fontBold:PPFontCaption1] color:[self pp_accentColor] lines:1];
    self.passTypeBadgeLabel.text = [Language isRTL] ? @"طبيب شخصي معتمد" : @"Licensed Specialist";
    [self.passTypeBadgeView addSubview:self.passTypeBadgeLabel];

    // Fee Pill on Pass
    self.passFeeBadgeLabel = [self pp_labelWithFont:[Styling fontBold:PPFontHeadline] color:[self pp_accentColor] lines:1];
    self.passFeeBadgeLabel.text = [Language isRTL] ? @"رسوم الكشفية: 150 ر.ق" : @"Consultation: 150 QAR";
    self.passFeeBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.passFeeBadgeLabel.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.07];
    PPApplyContinuousCorners(self.passFeeBadgeLabel, PPCornerPill);
    [self.passCard addSubview:self.passFeeBadgeLabel];

    // Dynamic Specialties Stack (Horizontal)
    self.passSpecialtiesStack = [UIStackView new];
    self.passSpecialtiesStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.passSpecialtiesStack.axis = UILayoutConstraintAxisHorizontal;
    self.passSpecialtiesStack.spacing = 6.0;
    self.passSpecialtiesStack.alignment = UIStackViewAlignmentCenter;
    self.passSpecialtiesStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.passCard addSubview:self.passSpecialtiesStack];

    // Bio preview
    self.passBioPreviewLabel = [self pp_labelWithFont:[Styling fontRegular:12.5] color:SeconderyTextClr lines:3];
    self.passBioPreviewLabel.text = [Language isRTL] ? @"النبذة الإكلينيكية والخبرات المعتمدة..." : @"Clinical bio and accredited medical services...";
    [self.passCard addSubview:self.passBioPreviewLabel];

    // Hairline Divider
    UIView *divider = [UIView new];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75];
    [self.passCard addSubview:divider];

    // Date Label
    self.passDateLabel = [self pp_labelWithFont:[Styling fontMedium:PPFontCaption1] color:SeconderyTextClr lines:1];
    self.passDateLabel.text = [Language isRTL] ? @"📅 موعد التوفر: اليوم" : @"📅 Available: Today";
    [self.passCard addSubview:self.passDateLabel];

    // Live Readiness Indicator (Pulsing Dot + Text)
    self.passStatusDot = [UIView new];
    self.passStatusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.passStatusDot.backgroundColor = [UIColor ppSuccess];
    self.passStatusDot.layer.cornerRadius = 4.5;
    [self.passCard addSubview:self.passStatusDot];

    self.passContactStatusLabel = [self pp_labelWithFont:[Styling fontBold:11.5] color:[UIColor ppSuccess] lines:1];
    self.passContactStatusLabel.text = [Language isRTL] ? @"متاح للتواصل واستشارات الطوارئ" : @"Ready for Direct Emergency Consultations";
    [self.passCard addSubview:self.passContactStatusLabel];

    // Simulated QR Verification Graphic Dock
    UIView *qrDock = [UIView new];
    qrDock.translatesAutoresizingMaskIntoConstraints = NO;
    qrDock.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(qrDock, PPCornerInput);
    [self.passCard addSubview:qrDock];

    UIImageView *qrIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"qrcode"]];
    qrIcon.translatesAutoresizingMaskIntoConstraints = NO;
    qrIcon.tintColor = SeconderyTextClr;
    [qrDock addSubview:qrIcon];

    self.passLicenseCodeLabel = [self pp_labelWithFont:[Styling fontMedium:10.5] color:SeconderyTextClr lines:1];
    self.passLicenseCodeLabel.text = [NSString stringWithFormat:@"LIC-QAT-%05ld", (long)(arc4random_uniform(89999) + 10000)];
    [qrDock addSubview:self.passLicenseCodeLabel];

    [container addSubview:badgeEyebrow];
    [container addSubview:badgeHeader];
    [container addSubview:self.passCard];

    [NSLayoutConstraint activateConstraints:@[
        [badgeEyebrow.topAnchor constraintEqualToAnchor:container.topAnchor constant:10.0],
        [badgeEyebrow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [badgeEyebrow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],

        [badgeHeader.topAnchor constraintEqualToAnchor:badgeEyebrow.bottomAnchor constant:4.0],
        [badgeHeader.leadingAnchor constraintEqualToAnchor:badgeEyebrow.leadingAnchor],
        [badgeHeader.trailingAnchor constraintEqualToAnchor:badgeEyebrow.trailingAnchor],

        [self.passCard.topAnchor constraintEqualToAnchor:badgeHeader.bottomAnchor constant:14.0],
        [self.passCard.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.passCard.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.passCard.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-16.0],

        [ribbon.topAnchor constraintEqualToAnchor:self.passCard.topAnchor],
        [ribbon.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor],
        [ribbon.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor],
        [ribbon.heightAnchor constraintEqualToConstant:38.0],

        [sealIcon.leadingAnchor constraintEqualToAnchor:ribbon.leadingAnchor constant:14.0],
        [sealIcon.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [sealIcon.widthAnchor constraintEqualToConstant:18.0],
        [sealIcon.heightAnchor constraintEqualToConstant:18.0],

        [passAuthorityLabel.leadingAnchor constraintEqualToAnchor:sealIcon.trailingAnchor constant:8.0],
        [passAuthorityLabel.trailingAnchor constraintEqualToAnchor:ribbon.trailingAnchor constant:-14.0],
        [passAuthorityLabel.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],

        [self.passAvatarView.topAnchor constraintEqualToAnchor:ribbon.bottomAnchor constant:16.0],
        [self.passAvatarView.centerXAnchor constraintEqualToAnchor:self.passCard.centerXAnchor],
        [self.passAvatarView.widthAnchor constraintEqualToConstant:76.0],
        [self.passAvatarView.heightAnchor constraintEqualToConstant:76.0],

        [self.passDoctorNameLabel.topAnchor constraintEqualToAnchor:self.passAvatarView.bottomAnchor constant:12.0],
        [self.passDoctorNameLabel.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [self.passDoctorNameLabel.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],

        [self.passTypeBadgeView.topAnchor constraintEqualToAnchor:self.passDoctorNameLabel.bottomAnchor constant:8.0],
        [self.passTypeBadgeView.centerXAnchor constraintEqualToAnchor:self.passCard.centerXAnchor],
        [self.passTypeBadgeView.heightAnchor constraintEqualToConstant:26.0],

        [self.passTypeBadgeLabel.leadingAnchor constraintEqualToAnchor:self.passTypeBadgeView.leadingAnchor constant:12.0],
        [self.passTypeBadgeLabel.trailingAnchor constraintEqualToAnchor:self.passTypeBadgeView.trailingAnchor constant:-12.0],
        [self.passTypeBadgeLabel.centerYAnchor constraintEqualToAnchor:self.passTypeBadgeView.centerYAnchor],

        [self.passFeeBadgeLabel.topAnchor constraintEqualToAnchor:self.passTypeBadgeView.bottomAnchor constant:12.0],
        [self.passFeeBadgeLabel.centerXAnchor constraintEqualToAnchor:self.passCard.centerXAnchor],
        [self.passFeeBadgeLabel.heightAnchor constraintEqualToConstant:32.0],
        [self.passFeeBadgeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.passCard.leadingAnchor constant:20.0],
        [self.passFeeBadgeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.passCard.trailingAnchor constant:-20.0],

        [self.passSpecialtiesStack.topAnchor constraintEqualToAnchor:self.passFeeBadgeLabel.bottomAnchor constant:12.0],
        [self.passSpecialtiesStack.centerXAnchor constraintEqualToAnchor:self.passCard.centerXAnchor],
        [self.passSpecialtiesStack.heightAnchor constraintEqualToConstant:24.0],

        [self.passBioPreviewLabel.topAnchor constraintEqualToAnchor:self.passSpecialtiesStack.bottomAnchor constant:10.0],
        [self.passBioPreviewLabel.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [self.passBioPreviewLabel.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],

        [divider.topAnchor constraintEqualToAnchor:self.passBioPreviewLabel.bottomAnchor constant:14.0],
        [divider.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [divider.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [self.passDateLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12.0],
        [self.passDateLabel.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [self.passDateLabel.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],

        [self.passStatusDot.topAnchor constraintEqualToAnchor:self.passDateLabel.bottomAnchor constant:10.0],
        [self.passStatusDot.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [self.passStatusDot.widthAnchor constraintEqualToConstant:9.0],
        [self.passStatusDot.heightAnchor constraintEqualToConstant:9.0],

        [self.passContactStatusLabel.centerYAnchor constraintEqualToAnchor:self.passStatusDot.centerYAnchor],
        [self.passContactStatusLabel.leadingAnchor constraintEqualToAnchor:self.passStatusDot.trailingAnchor constant:8.0],
        [self.passContactStatusLabel.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],

        [qrDock.topAnchor constraintEqualToAnchor:self.passContactStatusLabel.bottomAnchor constant:16.0],
        [qrDock.leadingAnchor constraintEqualToAnchor:self.passCard.leadingAnchor constant:16.0],
        [qrDock.trailingAnchor constraintEqualToAnchor:self.passCard.trailingAnchor constant:-16.0],
        [qrDock.bottomAnchor constraintEqualToAnchor:self.passCard.bottomAnchor constant:-18.0],
        [qrDock.heightAnchor constraintEqualToConstant:38.0],

        [qrIcon.leadingAnchor constraintEqualToAnchor:qrDock.leadingAnchor constant:12.0],
        [qrIcon.centerYAnchor constraintEqualToAnchor:qrDock.centerYAnchor],
        [qrIcon.widthAnchor constraintEqualToConstant:20.0],
        [qrIcon.heightAnchor constraintEqualToConstant:20.0],

        [self.passLicenseCodeLabel.leadingAnchor constraintEqualToAnchor:qrIcon.trailingAnchor constant:8.0],
        [self.passLicenseCodeLabel.trailingAnchor constraintEqualToAnchor:qrDock.trailingAnchor constant:-12.0],
        [self.passLicenseCodeLabel.centerYAnchor constraintEqualToAnchor:qrDock.centerYAnchor],
    ]];

    return container;
}

#pragma mark - Unified Apple Health-Style Form Sections (4 Grouped Units)

- (void)pp_buildFormSections {
    // Section 1: Doctor Identity & Practice Credentialing (Avatar, Title, Practice Type)
    [self.contentStack addArrangedSubview:[self pp_buildIdentityAndLicensingSection]];

    // Section 2: Clinical Specialization & Editorial Bio (Interactive Tag Matrix & Bio Editor)
    [self.contentStack addArrangedSubview:[self pp_buildSpecializationAndBioSection]];

    // Section 3: Direct Communications Hub (Phone & WhatsApp Telemetry)
    [self.contentStack addArrangedSubview:[self pp_buildCommunicationsSection]];

    // Section 4: Practice Economics & Clinical Availability (Fee Stepper, Calendar, Target Species)
    [self.contentStack addArrangedSubview:[self pp_buildEconomicsAndScheduleSection]];
}

#pragma mark - Section 1: Identity & Licensing

- (UIView *)pp_buildIdentityAndLicensingSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"الهوية المهنية وتصنيف الممارسة" : @"Identity & Practice Licensing"
                                              subtitle:[Language isRTL] ? @"الصورة الرسمية، الاسم التجاري أو الطبي، ونمط الترخيص البيطري" : @"Official photo, legal practice name, and accredited category"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    // Avatar Row with Camera Floating Badge
    UIView *avatarShell = [UIView new];
    avatarShell.translatesAutoresizingMaskIntoConstraints = NO;

    self.logoImageView = [UIImageView new];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.logoImageView, 38.0);
    self.logoImageView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
    self.logoImageView.layer.borderWidth = 3.0;
    self.logoImageView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.logoImageView.userInteractionEnabled = YES;
    [avatarShell addSubview:self.logoImageView];

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
    PPApplyButtonShadow(self.imagePickerButton);
    [avatarShell addSubview:self.imagePickerButton];

    UILabel *photoPrompt = [self pp_labelWithFont:[Styling fontMedium:12.5] color:[self pp_accentColor] lines:1];
    photoPrompt.text = [Language isRTL] ? @"انقر لتغيير الصورة الرسمية للطبيب" : @"Tap to upload official doctor photo";
    photoPrompt.textAlignment = NSTextAlignmentCenter;
    [avatarShell addSubview:photoPrompt];

    [NSLayoutConstraint activateConstraints:@[
        [self.logoImageView.topAnchor constraintEqualToAnchor:avatarShell.topAnchor constant:4.0],
        [self.logoImageView.centerXAnchor constraintEqualToAnchor:avatarShell.centerXAnchor],
        [self.logoImageView.widthAnchor constraintEqualToConstant:76.0],
        [self.logoImageView.heightAnchor constraintEqualToConstant:76.0],

        [self.imagePickerButton.bottomAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:2.0],
        [self.imagePickerButton.trailingAnchor constraintEqualToAnchor:self.logoImageView.trailingAnchor constant:2.0],
        [self.imagePickerButton.widthAnchor constraintEqualToConstant:32.0],
        [self.imagePickerButton.heightAnchor constraintEqualToConstant:32.0],

        [photoPrompt.topAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:8.0],
        [photoPrompt.leadingAnchor constraintEqualToAnchor:avatarShell.leadingAnchor],
        [photoPrompt.trailingAnchor constraintEqualToAnchor:avatarShell.trailingAnchor],
        [photoPrompt.bottomAnchor constraintEqualToAnchor:avatarShell.bottomAnchor constant:-4.0],
    ]];
    [stack addArrangedSubview:avatarShell];

    // Doctor / Clinic Legal Title Field
    self.titleField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"د. محمد أحمد (أو مجمع بيور بيتس البيطري)" : @"Dr. Full Name or Veterinary Hospital" icon:@"person.crop.rectangle.badge.plus"];
    [self.titleField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"اسم الطبيب / المركز البيطري المعتمد *" : @"Veterinarian / Clinic Name *" content:self.titleField height:58.0]];

    // Practice Type Segment
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"Vet_Type_Personal") ?: ([Language isRTL] ? @"طبيب شخصي مستقل" : @"Individual Specialist"),
        kLang(@"Vet_Type_Company") ?: ([Language isRTL] ? @"عيادة / مجمع بيطري" : @"Clinic / Hospital")
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
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"تصنيف رخصة الممارسة *" : @"Accreditation Category *" content:self.typeSegment height:52.0]];

    return surface;
}

#pragma mark - Section 2: Specialization & Bio

- (UIView *)pp_buildSpecializationAndBioSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"التخصصات الإكلينيكية والنبذة" : @"Clinical Specialization & Bio"
                                              subtitle:[Language isRTL] ? @"اختر وسوم التخصص المباشرة واكتب نبذة طبية موثقة للمراجعين" : @"Toggle medical specialty badges and detail accredited clinic services"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    // Interactive Specialty Tag Matrix
    [stack addArrangedSubview:[self pp_interactiveSpecialtyMatrix]];

    // Editorial Bio & Services Text View
    UIView *descShell = [self pp_textViewShellWithTitle:[Language isRTL] ? @"النبذة الطبية والخدمات المقدمة *" : @"Medical Bio & Accredited Services *"];
    [stack addArrangedSubview:descShell];

    return surface;
}

- (UIView *)pp_interactiveSpecialtyMatrix {
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
        [scroll.heightAnchor constraintEqualToConstant:42.0],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    NSArray<NSString *> *tags = [Language isRTL]
        ? @[@"#طب_وجراحة_عامة", @"#باطنية_بيطرية", @"#أسنان_وجراحة_فم", @"#جلدية_وحساسية", @"#لقاحات_وتحصين", @"#طوارئ_وعناية_مركزة", @"#سونار_وأشعة", @"#تغذية_علاجية"]
        : @[@"#GeneralSurgery", @"#InternalMedicine", @"#DentalSurgery", @"#Dermatology", @"#Vaccinations", @"#EmergencyCare", @"#Ultrasound", @"#ClinicalNutrition"];

    [self.specialtyButtons removeAllObjects];
    for (NSString *tag in tags) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [[self pp_accentColor] colorWithAlphaComponent:0.25].CGColor;
        btn.titleLabel.font = [Styling fontMedium:12.5];
        [btn setTitle:tag forState:UIControlStateNormal];
        btn.contentEdgeInsets = UIEdgeInsetsMake(7, 14, 7, 14);
        [btn addTarget:self action:@selector(pp_specialtyTagToggled:) forControlEvents:UIControlEventTouchUpInside];
        [self pp_styleSpecialtyButton:btn selected:NO];

        if (@available(iOS 13.4, *)) {
            UIPointerInteraction *hover = [[UIPointerInteraction alloc] initWithDelegate:self];
            [btn addInteraction:hover];
        }

        [self.specialtyButtons addObject:btn];
        [stack addArrangedSubview:btn];
    }

    return scroll;
}

- (void)pp_styleSpecialtyButton:(UIButton *)btn selected:(BOOL)selected {
    if (selected) {
        btn.backgroundColor = [self pp_accentColor];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.layer.borderColor = [self pp_accentColor].CGColor;
    } else {
        btn.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.07];
        [btn setTitleColor:[self pp_accentColor] forState:UIControlStateNormal];
        btn.layer.borderColor = [[self pp_accentColor] colorWithAlphaComponent:0.22].CGColor;
    }
}

- (void)pp_specialtyTagToggled:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *tag = [sender titleForState:UIControlStateNormal];
    if (!tag.length) return;

    BOOL isCurrentlySelected = [self.selectedSpecialties containsObject:tag];
    if (isCurrentlySelected) {
        [self.selectedSpecialties removeObject:tag];
        [self pp_styleSpecialtyButton:sender selected:NO];
    } else {
        [self.selectedSpecialties addObject:tag];
        [self pp_styleSpecialtyButton:sender selected:YES];
    }

    // Spring feedback
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        sender.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4 options:0 animations:^{
            sender.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [self pp_syncSpecialtiesToBio];
    [self pp_liveValuesChanged];
}

- (void)pp_syncSpecialtiesToBio {
    // Update live pass tags
    [self pp_updatePassSpecialtiesStack];
}

- (void)pp_updatePassSpecialtiesStack {
    if (!self.passSpecialtiesStack) return;

    for (UIView *sub in self.passSpecialtiesStack.arrangedSubviews) {
        [self.passSpecialtiesStack removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }

    NSArray<NSString *> *all = [self.selectedSpecialties allObjects];
    NSInteger showCount = MIN(3, (NSInteger)all.count);
    for (NSInteger i = 0; i < showCount; i++) {
        UILabel *pill = [self pp_labelWithFont:[Styling fontBold:10.5] color:[self pp_accentColor] lines:1];
        pill.text = all[i];
        pill.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];
        PPApplyContinuousCorners(pill, PPCornerPill);
        pill.textAlignment = NSTextAlignmentCenter;
        [self.passSpecialtiesStack addArrangedSubview:pill];
        [pill.heightAnchor constraintEqualToConstant:22.0].active = YES;
    }

    if (all.count > 3) {
        UILabel *morePill = [self pp_labelWithFont:[Styling fontBold:10.5] color:SeconderyTextClr lines:1];
        morePill.text = [NSString stringWithFormat:@"+%ld", (long)(all.count - 3)];
        morePill.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.12];
        PPApplyContinuousCorners(morePill, PPCornerPill);
        morePill.textAlignment = NSTextAlignmentCenter;
        [self.passSpecialtiesStack addArrangedSubview:morePill];
        [morePill.heightAnchor constraintEqualToConstant:22.0].active = YES;
    }
}

#pragma mark - Section 3: Communications Hub

- (UIView *)pp_buildCommunicationsSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"الاتصال السريع واستشارات الطوارئ" : @"Direct Emergency Communications"
                                              subtitle:[Language isRTL] ? @"أرقام الاتصال المباشر والواتساب للاستشارات السريعة الفورية" : @"Direct phone and official WhatsApp numbers for immediate inquiries"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    self.phoneField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"رقم الهاتف المباشر (مثال: 974XXXXXXXX+)" : @"+974 XXXXXXXX" icon:@"phone.circle.fill"];
    self.phoneField.keyboardType = UIKeyboardTypePhonePad;
    [self.phoneField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"رقم الهاتف المباشر" : @"Direct Mobile Phone" content:self.phoneField height:58.0]];

    self.whatsappField = [self pp_textFieldWithPlaceholder:[Language isRTL] ? @"رقم الواتساب للاستشارات (مثال: 974XXXXXXXX+)" : @"+974 XXXXXXXX (WhatsApp)" icon:@"message.circle.fill"];
    self.whatsappField.keyboardType = UIKeyboardTypePhonePad;
    [self.whatsappField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self pp_fieldShellWithTitle:[Language isRTL] ? @"رقم الواتساب للطوارئ" : @"Official WhatsApp Contact" content:self.whatsappField height:58.0]];

    return surface;
}

#pragma mark - Section 4: Economics & Schedule

- (UIView *)pp_buildEconomicsAndScheduleSection {
    UIView *surface = [self pp_sectionSurfaceWithTitle:[Language isRTL] ? @"الرسوم الاستشارية والجدول الزمني" : @"Consultation Economics & Availability"
                                              subtitle:[Language isRTL] ? @"تحديد رسوم الكشفية بالريال القطري، أزرار الزيادة السريعة، وموعد التوفر" : @"Set consultation fee in QAR, quick steppers, and clinic schedule"];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:8801];

    // Consultation Fee field with QAR pill
    self.costField = [self pp_textFieldWithPlaceholder:@"150" icon:@"banknote.fill"];
    self.costField.keyboardType = UIKeyboardTypeDecimalPad;
    [self.costField addTarget:self action:@selector(pp_liveValuesChanged) forControlEvents:UIControlEventEditingChanged];

    UIView *feeContainer = [self pp_feeFieldShell];
    [stack addArrangedSubview:feeContainer];

    // Quick Stepper Chips (+25, +50, +100, Free)
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
    titleLabel.text = [Language isRTL] ? @"رسوم الكشفية والاستشارة الطبية (ر.ق) *" : @"Consultation Fee (QAR) *";
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
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSArray<NSDictionary *> *chips = @[
        @{@"val": @0, @"title": [Language isRTL] ? @"مجاني" : @"Free"},
        @{@"val": @25, @"title": [Language isRTL] ? @"+25 ر.ق" : @"+25 QAR"},
        @{@"val": @50, @"title": [Language isRTL] ? @"+50 ر.ق" : @"+50 QAR"},
        @{@"val": @100, @"title": [Language isRTL] ? @"+100 ر.ق" : @"+100 QAR"}
    ];

    for (NSDictionary *d in chips) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.titleLabel.font = [Styling fontBold:12.5];
        [btn setTitle:d[@"title"] forState:UIControlStateNormal];
        [btn setTitleColor:[self pp_accentColor] forState:UIControlStateNormal];
        btn.tag = [d[@"val"] integerValue];
        [btn addTarget:self action:@selector(pp_feeStepperTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:36.0].active = YES;

        if (@available(iOS 13.4, *)) {
            UIPointerInteraction *hover = [[UIPointerInteraction alloc] initWithDelegate:self];
            [btn addInteraction:hover];
        }

        [stack addArrangedSubview:btn];
    }
    return stack;
}

- (void)pp_feeStepperTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    if (sender.tag == 0) {
        self.costField.text = @"0";
    } else {
        double current = [self.costField.text doubleValue];
        double updated = current + sender.tag;
        self.costField.text = [NSString stringWithFormat:@"%.0f", updated];
    }
    [self pp_liveValuesChanged];

    // Spring feedback
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.3 options:0 animations:^{
            sender.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Field / Section Factory Helpers

- (UIView *)pp_sectionSurfaceWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *surface = [UIView new];
    surface.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(surface, PPCornerCard);
    PPApplyCardBorder(surface);
    PPApplyCardShadow(surface);

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
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

    self.charCountLabel = [self pp_labelWithFont:[Styling fontRegular:10.5] color:[SeconderyTextClr colorWithAlphaComponent:0.65] lines:1];
    self.charCountLabel.text = @"0 / 500";
    self.charCountLabel.textAlignment = NSTextAlignmentRight;
    [shell addSubview:self.charCountLabel];

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

    self.descriptionPlaceholder = [self pp_labelWithFont:[Styling fontRegular:14.5] color:[SeconderyTextClr colorWithAlphaComponent:0.55] lines:2];
    self.descriptionPlaceholder.text = [Language isRTL]
        ? @"اكتب نبذة عن التخصص، المؤهلات والخبرات السابقة، والخدمات المتوفرة بالعيادة..."
        : @"Provide details about medical specialties, qualifications, and clinic services...";
    [shell addSubview:self.descriptionPlaceholder];

    [NSLayoutConstraint activateConstraints:@[
        [shell.heightAnchor constraintGreaterThanOrEqualToConstant:132.0],
        [titleLabel.topAnchor constraintEqualToAnchor:shell.topAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],

        [self.charCountLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [self.charCountLabel.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],
        [self.charCountLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.trailingAnchor constant:8.0],

        [self.descriptionView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [self.descriptionView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor constant:-4.0],
        [self.descriptionView.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-10.0],
        [self.descriptionView.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-8.0],

        [self.descriptionPlaceholder.topAnchor constraintEqualToAnchor:self.descriptionView.topAnchor constant:8.0],
        [self.descriptionPlaceholder.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.descriptionPlaceholder.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],
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
    if (iconName.length > 0) {
        UIView *iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32.0, 28.0)];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
        iconView.tintColor = [[self pp_accentColor] colorWithAlphaComponent:0.85];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.frame = CGRectMake(4.0, 4.0, 20.0, 20.0);
        [iconContainer addSubview:iconView];
        if ([Language isRTL]) {
            field.rightView = iconContainer;
            field.rightViewMode = UITextFieldViewModeAlways;
        } else {
            field.leftView = iconContainer;
            field.leftViewMode = UITextFieldViewModeAlways;
        }
    }
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

#pragma mark - Floating Frosted Glass Save Bar

- (void)pp_buildSaveBar {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.saveBarBlur = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.saveBarBlur.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.saveBarBlur, PPCornerHero);
    self.saveBarBlur.clipsToBounds = YES;
    self.saveBarBlur.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.saveBarBlur.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.8].CGColor;
    PPApplyFloatingBarShadow(self.saveBarBlur);
    [self.view addSubview:self.saveBarBlur];

    self.saveBar = self.saveBarBlur.contentView;

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.backgroundColor = [self pp_accentColor];
    self.saveButton.tintColor = UIColor.whiteColor;
    PPApplyContinuousCorners(self.saveButton, PPCornerButton);
    self.saveButton.titleLabel.font = [Styling fontBold:16.0];
    [self.saveButton setTitle:self.isEditing
        ? (kLang(@"Vet_Action_Save") ?: ([Language isRTL] ? @"حفظ التعديلات" : @"Save Changes"))
        : (kLang(@"Vet_Action_Save") ?: ([Language isRTL] ? @"اعتماد وتوثيق الملف الطبي" : @"Save Doctor Profile"))
                     forState:UIControlStateNormal];
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    PPApplyButtonShadow(self.saveButton);

    if (@available(iOS 13.4, *)) {
        UIPointerInteraction *hover = [[UIPointerInteraction alloc] initWithDelegate:self];
        [self.saveButton addInteraction:hover];
    }

    [self.saveBar addSubview:self.saveButton];

    self.saveBarBottomConstraint = [self.saveBarBlur.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.saveBarBlur.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.saveBarBlur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        self.saveBarBottomConstraint,
        [self.saveBarBlur.heightAnchor constraintEqualToConstant:66.0],

        [self.saveButton.topAnchor constraintEqualToAnchor:self.saveBar.topAnchor constant:9.0],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.saveBar.leadingAnchor constant:10.0],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.saveBar.trailingAnchor constant:-10.0],
        [self.saveButton.bottomAnchor constraintEqualToAnchor:self.saveBar.bottomAnchor constant:-9.0],
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
    self.charCountLabel.text = [NSString stringWithFormat:@"%lu / 500", (unsigned long)self.descriptionView.text.length];
    self.costField.text = (v.vetCost > 0) ? [NSString stringWithFormat:@"%.0f", v.vetCost] : @"";
    self.datePicker.date = v.availableDate ?: [NSDate date];
    self.kindField.text = (v.petMainKindID > 0) ? [NSString stringWithFormat:@"%ld", (long)v.petMainKindID] : @"";
    self.typeSegment.selectedSegmentIndex = (v.type == PPVetTypeCompany) ? 1 : 0;

    // Parse existing tags from description if any
    for (UIButton *btn in self.specialtyButtons) {
        NSString *tag = [btn titleForState:UIControlStateNormal];
        if (tag && [v.descriptionText containsString:tag]) {
            [self.selectedSpecialties addObject:tag];
            [self pp_styleSpecialtyButton:btn selected:YES];
        }
    }
    [self pp_updatePassSpecialtiesStack];

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
        ? ([Language isRTL] ? @"عيادة / مجمع بيطري مرخص" : @"Licensed Clinic")
        : ([Language isRTL] ? @"طبيب شخصي معتمد" : @"Licensed Specialist");

    double fee = [self.costField.text doubleValue];
    if (fee > 0) {
        self.passFeeBadgeLabel.text = [NSString stringWithFormat:@"%@: %.0f %@", [Language isRTL] ? @"رسوم الكشفية" : @"Consultation", fee, [Language isRTL] ? @"ر.ق" : @"QAR"];
    } else {
        self.passFeeBadgeLabel.text = [Language isRTL] ? @"رسوم الكشفية: مجانية / غير محددة" : @"Consultation: Free / Not Set";
    }

    NSString *desc = [self.descriptionView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.passBioPreviewLabel.text = (desc.length > 0) ? desc : ([Language isRTL] ? @"التخصص والخبرات الإكلينيكية المعتمدة..." : @"Accredited clinical specialties & services...");

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterNoStyle;
    NSString *dateStr = [df stringFromDate:self.datePicker.date];
    self.passDateLabel.text = [NSString stringWithFormat:@"%@: %@", [Language isRTL] ? @"📅 موعد التوفر" : @"📅 Available", dateStr];

    BOOL hasContact = (self.phoneField.text.length > 0 || self.whatsappField.text.length > 0);
    self.passContactStatusLabel.text = hasContact
        ? ([Language isRTL] ? @"متاح للتواصل واستشارات الطوارئ" : @"Ready for Direct Emergency Consultations")
        : ([Language isRTL] ? @"يرجى إدخال هاتف أو واتساب للطوارئ" : @"Emergency contacts not set");
    self.passContactStatusLabel.textColor = hasContact ? [UIColor ppSuccess] : [UIColor ppWarning];
    self.passStatusDot.backgroundColor = hasContact ? [UIColor ppSuccess] : [UIColor ppWarning];

    [self pp_updatePassSpecialtiesStack];
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
            : (kLang(@"Vet_Added_Success") ?: ([Language isRTL] ? @"تم اعتماد وتسجيل الطبيب بنجاح" : @"Doctor profile registered successfully"));
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
                      discoverabilityTitle:[Language isRTL] ? @"حفظ واعتماد الملف الطبي" : @"Save Doctor Profile"],
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
        [self.phoneField becomeFirstResponder];
    } else if (textField == self.phoneField) {
        [self.whatsappField becomeFirstResponder];
    } else if (textField == self.whatsappField) {
        [self.costField becomeFirstResponder];
    } else if (textField == self.costField) {
        [self.descriptionView becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.descriptionPlaceholder.hidden = (textView.text.length > 0);
    self.charCountLabel.text = [NSString stringWithFormat:@"%lu / 500", (unsigned long)textView.text.length];
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

#pragma mark - Pointer Interaction (iPad Trackpad Hover)

- (nullable UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region API_AVAILABLE(ios(13.4)) {
    if (!interaction.view) return nil;
    UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:interaction.view];
    return [UIPointerStyle styleWithEffect:[UIPointerHighlightEffect effectWithPreview:preview] shape:nil];
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
    self.saveBarBlur.alpha = 0.0;
    self.saveBarBlur.transform = CGAffineTransformMakeTranslation(0, 16.0);
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
        self.saveBarBlur.alpha = 1.0;
        self.saveBarBlur.transform = CGAffineTransformIdentity;
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
        self.saveBarBlur.alpha = 1.0;
        self.saveBarBlur.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
