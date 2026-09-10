//
//  PPAddEditAdoptPetViewController.m
//  PurePetsPro
//

#import "PPAddEditAdoptPetViewController.h"
#import "PPAdoptPetManager.h"
#import "PPFirebaseCompat.h"
#import "PPFunc+Haptics.h"
#import "PPHUD.h"

@interface PPAddEditAdoptPetViewController () <UITextViewDelegate, UIScrollViewDelegate>
@property (nonatomic, assign) BOOL isEditingPet;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UITextField *adopterNameField;
@property (nonatomic, strong) UITextField *adopterContactField;
@property (nonatomic, strong) UISegmentedControl *statusControl;
@property (nonatomic, strong) UIView *adopterSectionView;
@property (nonatomic, strong) UIView *livePreviewContainer;
@property (nonatomic, strong) UILabel *previewTitleLabel;
@property (nonatomic, strong) UILabel *previewDescLabel;
@property (nonatomic, strong) UILabel *previewStatusLabel;
@property (nonatomic, strong) UIView *previewStatusBadge;
@property (nonatomic, strong) UIView *saveBar;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSLayoutConstraint *saveBarBottomConstraint;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation PPAddEditAdoptPetViewController

- (instancetype)initWithPet:(nullable PPAdoptPetModel *)pet {
    self = [super init];
    if (self) {
        _pet = pet ? [pet copy] : [[PPAdoptPetModel alloc] init];
        _isEditingPet = pet.petID.length > 0;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildBackdrop];
    [self buildScrollView];
    [self buildForm];
    [self buildSaveBar];
    [self populateForm];
    [self registerKeyboardNotifications];
    [self prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *title = self.isEditingPet ? kLang(@"AdoptPro_EditNavTitle") : kLang(@"AdoptPro_AddNavTitle");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
    [self prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Colors

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return AppForgroundColr;
}

- (UIColor *)pp_accentColor {
    return AppPrimaryClr;
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

    self.bgGlowBottom.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:isDark ? 0.035 : 0.075];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppWarning].CGColor;
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
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    if (isPad) {
        // iPad 2-Column Split Studio
        [self buildPadSplitStudio];
    } else {
        // iPhone Ergonomic Flow
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

            [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:14.0],
            [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
            [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
            [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
            [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0],
        ]];
    }
}

- (void)buildPadSplitStudio {
    UIView *splitRoot = [UIView new];
    splitRoot.translatesAutoresizingMaskIntoConstraints = NO;
    splitRoot.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:splitRoot];

    // Left Column: Live Consumer Feed Preview Card
    self.livePreviewContainer = [UIView new];
    self.livePreviewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.livePreviewContainer.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.livePreviewContainer, PPCornerHero);
    PPApplyCardShadow(self.livePreviewContainer);
    [splitRoot addSubview:self.livePreviewContainer];

    UILabel *previewEyebrow = [self labelWithFont:[Styling fontBold:PPFontCaption1] color:[self pp_accentColor] lines:1];
    previewEyebrow.text = [kLang(@"AdoptPro_FormEyebrow") uppercaseString];

    UILabel *previewHeader = [self labelWithFont:[Styling fontBold:PPFontTitle2] color:PrimaryTextClr lines:1];
    previewHeader.text = [Language isRTL] ? @"معاينة المنشور المباشرة" : @"Live Feed Preview";

    UIView *cardBox = [UIView new];
    cardBox.translatesAutoresizingMaskIntoConstraints = NO;
    cardBox.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(cardBox, PPCornerCard);
    cardBox.layer.borderWidth = 1.0;
    cardBox.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;

    UIImageView *petIcon = [UIImageView new];
    petIcon.translatesAutoresizingMaskIntoConstraints = NO;
    petIcon.image = [UIImage systemImageNamed:@"pawprint.circle.fill"];
    petIcon.tintColor = [self pp_accentColor];
    petIcon.contentMode = UIViewContentModeScaleAspectFit;

    self.previewTitleLabel = [self labelWithFont:[Styling fontBold:PPFontTitle3] color:PrimaryTextClr lines:2];
    self.previewTitleLabel.text = self.pet.title.length ? self.pet.title : kLang(@"AdoptPro_Untitled");

    self.previewDescLabel = [self labelWithFont:[Styling fontRegular:PPFontSubheadline] color:SeconderyTextClr lines:4];
    self.previewDescLabel.text = self.pet.descriptionText.length ? self.pet.descriptionText : kLang(@"AdoptPro_NoDescription");

    self.previewStatusBadge = [UIView new];
    self.previewStatusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.previewStatusBadge, PPCornerPill);
    self.previewStatusBadge.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];

    self.previewStatusLabel = [self labelWithFont:[Styling fontBold:PPFontCaption1] color:[self pp_accentColor] lines:1];
    self.previewStatusLabel.text = kLang(@"AdoptPro_Status_Available");
    self.previewStatusLabel.textAlignment = NSTextAlignmentCenter;
    [self.previewStatusBadge addSubview:self.previewStatusLabel];

    [self.livePreviewContainer addSubview:previewEyebrow];
    [self.livePreviewContainer addSubview:previewHeader];
    [self.livePreviewContainer addSubview:cardBox];
    [cardBox addSubview:petIcon];
    [cardBox addSubview:self.previewTitleLabel];
    [cardBox addSubview:self.previewDescLabel];
    [cardBox addSubview:self.previewStatusBadge];

    [NSLayoutConstraint activateConstraints:@[
        [previewEyebrow.topAnchor constraintEqualToAnchor:self.livePreviewContainer.topAnchor constant:24.0],
        [previewEyebrow.leadingAnchor constraintEqualToAnchor:self.livePreviewContainer.leadingAnchor constant:24.0],
        [previewEyebrow.trailingAnchor constraintEqualToAnchor:self.livePreviewContainer.trailingAnchor constant:-24.0],

        [previewHeader.topAnchor constraintEqualToAnchor:previewEyebrow.bottomAnchor constant:4.0],
        [previewHeader.leadingAnchor constraintEqualToAnchor:previewEyebrow.leadingAnchor],
        [previewHeader.trailingAnchor constraintEqualToAnchor:previewEyebrow.trailingAnchor],

        [cardBox.topAnchor constraintEqualToAnchor:previewHeader.bottomAnchor constant:20.0],
        [cardBox.leadingAnchor constraintEqualToAnchor:previewEyebrow.leadingAnchor],
        [cardBox.trailingAnchor constraintEqualToAnchor:previewEyebrow.trailingAnchor],
        [cardBox.bottomAnchor constraintLessThanOrEqualToAnchor:self.livePreviewContainer.bottomAnchor constant:-24.0],

        [petIcon.topAnchor constraintEqualToAnchor:cardBox.topAnchor constant:18.0],
        [petIcon.leadingAnchor constraintEqualToAnchor:cardBox.leadingAnchor constant:18.0],
        [petIcon.widthAnchor constraintEqualToConstant:44.0],
        [petIcon.heightAnchor constraintEqualToConstant:44.0],

        [self.previewStatusBadge.centerYAnchor constraintEqualToAnchor:petIcon.centerYAnchor],
        [self.previewStatusBadge.trailingAnchor constraintEqualToAnchor:cardBox.trailingAnchor constant:-18.0],
        [self.previewStatusBadge.heightAnchor constraintEqualToConstant:26.0],

        [self.previewStatusLabel.leadingAnchor constraintEqualToAnchor:self.previewStatusBadge.leadingAnchor constant:10.0],
        [self.previewStatusLabel.trailingAnchor constraintEqualToAnchor:self.previewStatusBadge.trailingAnchor constant:-10.0],
        [self.previewStatusLabel.centerYAnchor constraintEqualToAnchor:self.previewStatusBadge.centerYAnchor],

        [self.previewTitleLabel.topAnchor constraintEqualToAnchor:petIcon.bottomAnchor constant:14.0],
        [self.previewTitleLabel.leadingAnchor constraintEqualToAnchor:petIcon.leadingAnchor],
        [self.previewTitleLabel.trailingAnchor constraintEqualToAnchor:cardBox.trailingAnchor constant:-18.0],

        [self.previewDescLabel.topAnchor constraintEqualToAnchor:self.previewTitleLabel.bottomAnchor constant:8.0],
        [self.previewDescLabel.leadingAnchor constraintEqualToAnchor:self.previewTitleLabel.leadingAnchor],
        [self.previewDescLabel.trailingAnchor constraintEqualToAnchor:self.previewTitleLabel.trailingAnchor],
        [self.previewDescLabel.bottomAnchor constraintEqualToAnchor:cardBox.bottomAnchor constant:-20.0],
    ]];

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

        [self.livePreviewContainer.topAnchor constraintEqualToAnchor:splitRoot.topAnchor constant:14.0],
        [self.livePreviewContainer.leadingAnchor constraintEqualToAnchor:splitRoot.leadingAnchor],
        [self.livePreviewContainer.widthAnchor constraintEqualToConstant:360.0],
        [self.livePreviewContainer.bottomAnchor constraintLessThanOrEqualToAnchor:splitRoot.bottomAnchor constant:-100.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:splitRoot.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.livePreviewContainer.trailingAnchor constant:20.0],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:splitRoot.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:splitRoot.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
    ]];
}

- (void)buildForm {
    [self.contentStack addArrangedSubview:[self heroSection]];
    [self.contentStack addArrangedSubview:[self listingSection]];
    [self.contentStack addArrangedSubview:[self statusSection]];
    self.adopterSectionView = [self adopterSection];
    [self.contentStack addArrangedSubview:self.adopterSectionView];
    self.adopterSectionView.hidden = (self.statusControl.selectedSegmentIndex != 1);
}

- (UIView *)heroSection {
    UIView *surface = [UIView new];
    surface.backgroundColor = [self pp_surfaceColor];
    surface.layer.cornerRadius = 30.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    surface.layer.shadowColor = (AppShadowColor).CGColor;
    surface.layer.shadowOpacity = 0.07;
    surface.layer.shadowRadius = 24.0;
    surface.layer.shadowOffset = CGSizeMake(0, 14.0);

    UIView *accentLine = [UIView new];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.backgroundColor = [self pp_accentColor];
    accentLine.layer.cornerRadius = 2.5;
    [surface addSubview:accentLine];

    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.10];
    iconShell.layer.cornerRadius = 24.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [surface addSubview:iconShell];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:self.isEditingPet ? @"pencil.and.outline" : @"heart.text.square.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self pp_accentColor];
    [iconShell addSubview:icon];

    UILabel *eyebrow = [self labelWithFont:[Styling fontBold:11.0] color:[self pp_accentColor] lines:1];
    eyebrow.text = [kLang(@"AdoptPro_FormEyebrow") uppercaseString];
    [surface addSubview:eyebrow];

    UILabel *title = [self labelWithFont:[Styling fontBold:30.0] color:PrimaryTextClr lines:2];
    title.text = self.isEditingPet ? kLang(@"AdoptPro_FormEditTitle") : kLang(@"AdoptPro_FormAddTitle");
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.82;
    [surface addSubview:title];

    UILabel *subtitle = [self labelWithFont:[Styling fontRegular:14.0] color:SeconderyTextClr lines:3];
    subtitle.text = self.isEditingPet ? kLang(@"AdoptPro_FormEditSubtitle") : kLang(@"AdoptPro_FormAddSubtitle");
    [surface addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [accentLine.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [accentLine.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [accentLine.widthAnchor constraintEqualToConstant:54.0],
        [accentLine.heightAnchor constraintEqualToConstant:5.0],
        [iconShell.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [iconShell.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],
        [iconShell.widthAnchor constraintEqualToConstant:52.0],
        [iconShell.heightAnchor constraintEqualToConstant:52.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:25.0],
        [icon.heightAnchor constraintEqualToConstant:25.0],
        [eyebrow.topAnchor constraintEqualToAnchor:accentLine.bottomAnchor constant:17.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:iconShell.leadingAnchor constant:-12.0],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:7.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-22.0],
    ]];
    return surface;
}

- (UIView *)listingSection {
    UIView *surface = [self sectionSurfaceWithTitle:kLang(@"AdoptPro_Section_Listing")
                                           subtitle:kLang(@"AdoptPro_Section_Listing_Subtitle")];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:7701];

    self.titleField = [self textFieldWithPlaceholder:kLang(@"AdoptPro_Field_Title_Placeholder")];
    [self.titleField addTarget:self action:@selector(titleChanged) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:[self fieldShellWithTitle:kLang(@"AdoptPro_Field_Title") content:self.titleField height:58.0]];

    // Temperament quick tags row
    [stack addArrangedSubview:[self temperamentChipsRow]];

    UIView *descriptionShell = [self textViewShellWithTitle:kLang(@"AdoptPro_Field_Description")];
    [stack addArrangedSubview:descriptionShell];
    return surface;
}

- (UIView *)temperamentChipsRow {
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
        ? @[@"#ودود_وأليف", @"#يحب_الأطفال", @"#مدرب_بالكامل", @"#مطعّم_وسليم", @"#هادئ_ولطيف", @"#نشيط_ومرح"]
        : @[@"#Friendly", @"#GoodWithKids", @"#HouseTrained", @"#Vaccinated", @"#Calm", @"#Playful"];

    for (NSString *tag in tags) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.titleLabel.font = [Styling fontMedium:12.5];
        [btn setTitle:tag forState:UIControlStateNormal];
        [btn setTitleColor:[self pp_accentColor] forState:UIControlStateNormal];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [btn addTarget:self action:@selector(temperamentChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:btn];
    }

    return scroll;
}

- (void)temperamentChipTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *tag = [sender titleForState:UIControlStateNormal];
    if (tag.length == 0) return;
    NSString *current = self.descriptionView.text ?: @"";
    if (current.length > 0) {
        self.descriptionView.text = [NSString stringWithFormat:@"%@ %@", current, tag];
    } else {
        self.descriptionView.text = tag;
    }
    self.descriptionPlaceholder.hidden = self.descriptionView.text.length > 0;
    [self updateLivePreview];
}

- (void)titleChanged {
    [self updateLivePreview];
}

- (UIView *)statusSection {
    UIView *surface = [self sectionSurfaceWithTitle:kLang(@"AdoptPro_Section_Status")
                                           subtitle:kLang(@"AdoptPro_Section_Status_Subtitle")];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:7701];
    self.statusControl = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"AdoptPro_Status_Available"),
        kLang(@"AdoptPro_Status_Adopted"),
        kLang(@"AdoptPro_Status_Hidden")
    ]];
    self.statusControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusControl.selectedSegmentTintColor = [[self pp_accentColor] colorWithAlphaComponent:0.18];
    [self.statusControl setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:12.0],
        NSForegroundColorAttributeName: SeconderyTextClr
    } forState:UIControlStateNormal];
    [self.statusControl setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:12.0],
        NSForegroundColorAttributeName: [self pp_accentColor]
    } forState:UIControlStateSelected];
    [self.statusControl addTarget:self action:@selector(statusChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self fieldShellWithTitle:kLang(@"AdoptPro_Field_Status") content:self.statusControl height:52.0]];
    return surface;
}

- (void)statusChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    BOOL isAdopted = (sender.selectedSegmentIndex == 1);
    [UIView animateWithDuration:0.25 animations:^{
        self.adopterSectionView.alpha = isAdopted ? 1.0 : 0.0;
        self.adopterSectionView.hidden = !isAdopted;
    }];
    [self updateLivePreview];
}

- (UIView *)adopterSection {
    UIView *surface = [self sectionSurfaceWithTitle:kLang(@"AdoptPro_Section_Adopter")
                                           subtitle:kLang(@"AdoptPro_Section_Adopter_Subtitle")];
    UIStackView *stack = (UIStackView *)[surface viewWithTag:7701];
    self.adopterNameField = [self textFieldWithPlaceholder:kLang(@"AdoptPro_Field_Adopter_Placeholder")];
    self.adopterContactField = [self textFieldWithPlaceholder:kLang(@"AdoptPro_Field_AdopterContact_Placeholder")];
    self.adopterContactField.keyboardType = UIKeyboardTypePhonePad;
    [stack addArrangedSubview:[self fieldShellWithTitle:kLang(@"AdoptPro_Field_Adopter") content:self.adopterNameField height:58.0]];
    [stack addArrangedSubview:[self fieldShellWithTitle:kLang(@"AdoptPro_Field_AdopterContact") content:self.adopterContactField height:58.0]];
    return surface;
}

- (void)updateLivePreview {
    if (!self.livePreviewContainer) return;
    NSString *title = [self trimmed:self.titleField.text];
    self.previewTitleLabel.text = title.length > 0 ? title : kLang(@"AdoptPro_Untitled");
    NSString *desc = [self trimmed:self.descriptionView.text];
    self.previewDescLabel.text = desc.length > 0 ? desc : kLang(@"AdoptPro_NoDescription");

    switch (self.statusControl.selectedSegmentIndex) {
        case 1:
            self.previewStatusLabel.text = kLang(@"AdoptPro_Status_Adopted");
            self.previewStatusLabel.textColor = [UIColor ppSuccess];
            self.previewStatusBadge.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
            break;
        case 2:
            self.previewStatusLabel.text = kLang(@"AdoptPro_Status_Hidden");
            self.previewStatusLabel.textColor = [UIColor ppWarning];
            self.previewStatusBadge.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.12];
            break;
        default:
            self.previewStatusLabel.text = kLang(@"AdoptPro_Status_Available");
            self.previewStatusLabel.textColor = [self pp_accentColor];
            self.previewStatusBadge.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.12];
            break;
    }
}

- (UIView *)sectionSurfaceWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
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
    stack.tag = 7701;
    [surface addSubview:stack];

    UILabel *titleLabel = [self labelWithFont:[Styling fontBold:18.0] color:PrimaryTextClr lines:1];
    titleLabel.text = title;
    UILabel *subtitleLabel = [self labelWithFont:[Styling fontRegular:13.0] color:SeconderyTextClr lines:2];
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

- (UIView *)fieldShellWithTitle:(NSString *)title content:(UIView *)content height:(CGFloat)height {
    UIView *shell = [UIView new];
    shell.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    shell.layer.cornerRadius = 17.0;
    shell.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
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

- (UIView *)textViewShellWithTitle:(NSString *)title {
    UIView *shell = [UIView new];
    shell.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.045];
    shell.layer.cornerRadius = 17.0;
    shell.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:11.0] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
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

    self.descriptionPlaceholder = [self labelWithFont:[Styling fontRegular:15.0] color:[SeconderyTextClr colorWithAlphaComponent:0.65] lines:2];
    self.descriptionPlaceholder.text = kLang(@"AdoptPro_Field_Description_Placeholder");
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

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder {
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
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{
        NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:0.60],
        NSFontAttributeName: [Styling fontRegular:15.0]
    }];
    // Arabic digits → English digits normalization for numeric keyboards
    [field addTarget:self action:@selector(pp_normalizeArabicDigitsForField:) forControlEvents:UIControlEventEditingChanged];
    return field;
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

- (void)buildSaveBar {
    self.saveBar = [UIView new];
    self.saveBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveBar.backgroundColor = [self pp_surfaceColor];
    self.saveBar.layer.cornerRadius = 28.0;
    self.saveBar.layer.cornerCurve = kCACornerCurveContinuous;
    self.saveBar.layer.shadowColor = (AppShadowColor).CGColor;
    self.saveBar.layer.shadowOpacity = 0.10;
    self.saveBar.layer.shadowRadius = 22.0;
    self.saveBar.layer.shadowOffset = CGSizeMake(0, 12.0);
    [self.view addSubview:self.saveBar];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.backgroundColor = [self pp_accentColor];
    self.saveButton.tintColor = UIColor.whiteColor;
    self.saveButton.layer.cornerRadius = 21.0;
    self.saveButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.saveButton.titleLabel.font = [Styling fontBold:16.0];
    [self.saveButton setTitle:(self.isEditingPet ? kLang(@"AdoptPro_SaveChanges") : kLang(@"AdoptPro_CreateListing")) forState:UIControlStateNormal];
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

#pragma mark - Form State

- (void)populateForm {
    self.titleField.text = self.pet.title;
    self.descriptionView.text = self.pet.descriptionText;
    self.descriptionPlaceholder.hidden = self.descriptionView.text.length > 0;
    self.adopterNameField.text = self.pet.adopterName;
    self.adopterContactField.text = self.pet.adopterContact;
    if (self.pet.visibility == 1 || [self.pet.status isEqualToString:@"hidden"]) {
        self.statusControl.selectedSegmentIndex = 2;
    } else if (self.pet.isAdopted || [self.pet.status isEqualToString:@"adopted"]) {
        self.statusControl.selectedSegmentIndex = 1;
    } else {
        self.statusControl.selectedSegmentIndex = 0;
    }
    self.adopterSectionView.hidden = (self.statusControl.selectedSegmentIndex != 1);
    [self updateLivePreview];
}

- (void)applyFormToPet {
    self.pet.title = [self trimmed:self.titleField.text];
    self.pet.descriptionText = [self trimmed:self.descriptionView.text];
    self.pet.adopterName = [self trimmed:self.adopterNameField.text];
    self.pet.adopterContact = [self trimmed:self.adopterContactField.text];
    switch (self.statusControl.selectedSegmentIndex) {
        case 1:
            self.pet.status = @"adopted";
            self.pet.isAdopted = YES;
            self.pet.visibility = 0;
            break;
        case 2:
            self.pet.status = @"hidden";
            self.pet.isAdopted = NO;
            self.pet.visibility = 1;
            break;
        default:
            self.pet.status = @"available";
            self.pet.isAdopted = NO;
            self.pet.visibility = 0;
            break;
    }
}

- (NSString *)trimmed:(NSString *)value {
    return [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
}

#pragma mark - Actions

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    [self applyFormToPet];

    if (self.pet.title.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"AdoptPro_Validation_TitleRequired")];
        [self.titleField becomeFirstResponder];
        return;
    }
    if (self.pet.descriptionText.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"AdoptPro_Validation_DescriptionRequired")];
        [self.descriptionView becomeFirstResponder];
        return;
    }

    self.saveButton.enabled = NO;
    self.saveButton.alpha = 0.72;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"AdoptPro_Saving") subtitle:nil];
    __weak typeof(self) weakSelf = self;
    [[PPAdoptPetManager sharedManager] createAdoptRequest:self.pet completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        self.saveButton.enabled = YES;
        self.saveButton.alpha = 1.0;
        [PPHUD dismiss];
        if (!success) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"AdoptPro_Error_Save")];
            return;
        }
        NSString *subtitle = self.isEditingPet ? kLang(@"AdoptPro_UpdatedSuccess") : kLang(@"AdoptPro_CreatedSuccess");
        [PPHUD showSuccess:kLang(@"Saved") subtitle:subtitle];
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

#pragma mark - Text Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.titleField) {
        [self.descriptionView becomeFirstResponder];
    } else if (textField == self.adopterNameField) {
        [self.adopterContactField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.descriptionPlaceholder.hidden = textView.text.length > 0;
    [self updateLivePreview];
}

#pragma mark - iPad Hardware Key Commands

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
                     discoverabilityTitle:[Language isRTL] ? @"حفظ المنشور" : @"Save Listing"],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                            modifierFlags:0
                                   action:@selector(handleEscapeKey)
                     discoverabilityTitle:[Language isRTL] ? @"رجوع / إلغاء" : @"Back / Cancel"]
    ];
}

- (void)handleEscapeKey {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Keyboard

- (void)registerKeyboardNotifications {
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
    CGFloat target = overlap > 0 ? -(overlap - safeBottom + 12.0) : -12.0;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue] ?: 0.25;
    UIViewAnimationOptions options = (UIViewAnimationOptions)([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    self.saveBarBottomConstraint.constant = target;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Motion

- (void)prepareEntranceState {
    if (self.didPrepareEntrance || self.didPlayEntrance) return;
    self.didPrepareEntrance = YES;
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.saveBar.alpha = 0.0;
    self.saveBar.transform = CGAffineTransformMakeTranslation(0, 16.0);
}

- (void)runEntranceIfNeeded {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        self.saveBar.alpha = 1.0;
        self.saveBar.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.46 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.42 delay:0.10 usingSpringWithDamping:0.88 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.saveBar.alpha = 1.0;
        self.saveBar.transform = CGAffineTransformIdentity;
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
