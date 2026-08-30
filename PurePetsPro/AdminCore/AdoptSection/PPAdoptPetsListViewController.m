//
//  PPAdoptPetsListViewController.m
//  PurePetsPro
//

#import "PPAdoptPetsListViewController.h"
#import "PPAdoptPetManager.h"
#import "PPAdoptPetCell.h"
#import "PPAdoptPetDetailViewController.h"
#import "PPAddEditAdoptPetViewController.h"
#import "PPFirebaseCompat.h"
#import "PPFunc+Haptics.h"

typedef NS_ENUM(NSInteger, PPAdoptPetsFilter) {
    PPAdoptPetsFilterAll = 0,
    PPAdoptPetsFilterAvailable,
    PPAdoptPetsFilterAdopted,
    PPAdoptPetsFilterHidden
};

@interface PPAdoptPetsListViewController ()
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *totalValueLabel;
@property (nonatomic, strong) UILabel *availableValueLabel;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIButton *emptyActionButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, copy) NSArray<PPAdoptPetModel *> *allPets;
@property (nonatomic, assign) BOOL hasLoadedOnce;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation PPAdoptPetsListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.adoptPets = [NSMutableArray array];
    self.allPets = @[];

    [self buildBackdrop];
    [self buildHero];
    [self buildTableView];
    [self buildStateViews];
    [self prepareEntranceState];
    [self setLoading:YES message:kLang(@"AdoptPro_Loading")];
    [self startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:[self pp_addButton] title:kLang(@"AdoptPro_NavTitle") showBack:YES];
    [self prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)dealloc {
    [self.listener remove];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = [self pp_canvasColor];
        [self updateBackdropStyle];
    }
}

#pragma mark - Colors

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return AppForgroundColr;
}

- (UIColor *)pp_borderColor {
    return [SeconderyTextClr colorWithAlphaComponent:0.09];
}

- (UIColor *)pp_accentColor {
    return AppPrimaryClr;
}

#pragma mark - Building

- (void)buildBackdrop {
    self.bgGlowTop = [self glowViewWithSize:220.0];
    self.bgGlowBottom = [self glowViewWithSize:190.0];
    [self.view addSubview:self.bgGlowTop];
    [self.view addSubview:self.bgGlowBottom];

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
    [self updateBackdropStyle];
}

- (UIView *)glowViewWithSize:(CGFloat)size {
    UIView *view = [UIView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.layer.cornerRadius = size * 0.5;
    view.layer.masksToBounds = NO;
    return view;
}

- (void)updateBackdropStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = [self pp_accentColor];
    self.bgGlowTop.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.045 : 0.10];
    self.bgGlowTop.layer.shadowColor = accent.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 64.0;
    self.bgGlowTop.layer.shadowOffset = CGSizeZero;

    self.bgGlowBottom.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:isDark ? 0.035 : 0.075];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppWarning].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.03 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 72.0;
    self.bgGlowBottom.layer.shadowOffset = CGSizeZero;
}

- (void)buildHero {
    self.heroSurfaceView = [UIView new];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [self pp_surfaceColor];
    self.heroSurfaceView.layer.cornerRadius = 30.0;
    self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.heroSurfaceView.layer.borderColor = [self pp_borderColor].CGColor;
    self.heroSurfaceView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.08].CGColor;
    self.heroSurfaceView.layer.shadowOpacity = 0.07;
    self.heroSurfaceView.layer.shadowRadius = 24.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0, 14.0);
    [self.view addSubview:self.heroSurfaceView];

    UIView *accentLine = [UIView new];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.backgroundColor = [self pp_accentColor];
    accentLine.layer.cornerRadius = 2.5;
    [self.heroSurfaceView addSubview:accentLine];

    UIView *iconSurface = [UIView new];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 22.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroSurfaceView addSubview:iconSurface];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.text.square.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [self pp_accentColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconSurface addSubview:iconView];

    self.eyebrowLabel = [self labelWithFont:[Styling fontBold:11.0] color:[self pp_accentColor] lines:1];
    self.eyebrowLabel.text = [kLang(@"AdoptPro_ListEyebrow") uppercaseString];
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.titleLabel = [self labelWithFont:[Styling fontBold:30.0] color:PrimaryTextClr lines:2];
    self.titleLabel.text = kLang(@"AdoptPro_ListTitle");
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    [self.heroSurfaceView addSubview:self.titleLabel];

    self.subtitleLabel = [self labelWithFont:[Styling fontRegular:14.0] color:SeconderyTextClr lines:2];
    self.subtitleLabel.text = kLang(@"AdoptPro_ListSubtitle");
    [self.heroSurfaceView addSubview:self.subtitleLabel];

    UIStackView *metricStack = [[UIStackView alloc] init];
    metricStack.translatesAutoresizingMaskIntoConstraints = NO;
    metricStack.axis = UILayoutConstraintAxisHorizontal;
    metricStack.distribution = UIStackViewDistributionFillEqually;
    metricStack.spacing = 10.0;
    metricStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.heroSurfaceView addSubview:metricStack];

    UIView *totalMetric = [self metricViewWithTitle:kLang(@"AdoptPro_Total") value:@"0"];
    UIView *availableMetric = [self metricViewWithTitle:kLang(@"AdoptPro_Available") value:@"0"];
    self.totalValueLabel = (UILabel *)[totalMetric viewWithTag:9151];
    self.availableValueLabel = (UILabel *)[availableMetric viewWithTag:9151];
    [metricStack addArrangedSubview:totalMetric];
    [metricStack addArrangedSubview:availableMetric];

    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"AdoptPro_Filter_All"),
        kLang(@"AdoptPro_Filter_Available"),
        kLang(@"AdoptPro_Filter_Adopted"),
        kLang(@"AdoptPro_Filter_Hidden")
    ]];
    self.filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterControl.selectedSegmentIndex = PPAdoptPetsFilterAll;
    self.filterControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.filterControl.selectedSegmentTintColor = [[self pp_accentColor] colorWithAlphaComponent:0.18];
    [self.filterControl setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:11.0],
        NSForegroundColorAttributeName: SeconderyTextClr
    } forState:UIControlStateNormal];
    [self.filterControl setTitleTextAttributes:@{
        NSFontAttributeName: [Styling fontBold:11.0],
        NSForegroundColorAttributeName: [self pp_accentColor]
    } forState:UIControlStateSelected];
    [self.filterControl addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    [self.heroSurfaceView addSubview:self.filterControl];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],

        [accentLine.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [accentLine.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [accentLine.widthAnchor constraintEqualToConstant:52.0],
        [accentLine.heightAnchor constraintEqualToConstant:5.0],

        [iconSurface.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [iconSurface.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        [iconSurface.widthAnchor constraintEqualToConstant:48.0],
        [iconSurface.heightAnchor constraintEqualToConstant:48.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:accentLine.bottomAnchor constant:16.0],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:iconSurface.leadingAnchor constant:-12.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:6.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-22.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [metricStack.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:18.0],
        [metricStack.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [metricStack.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [metricStack.heightAnchor constraintEqualToConstant:58.0],

        [self.filterControl.topAnchor constraintEqualToAnchor:metricStack.bottomAnchor constant:14.0],
        [self.filterControl.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.filterControl.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.filterControl.heightAnchor constraintEqualToConstant:36.0],
        [self.filterControl.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-20.0],
    ]];
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

- (UIView *)metricViewWithTitle:(NSString *)title value:(NSString *)value {
    UIView *view = [UIView new];
    view.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.055];
    view.layer.cornerRadius = 18.0;
    view.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *caption = [self labelWithFont:[Styling fontMedium:10.5] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    caption.text = title;
    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:20.0] color:PrimaryTextClr lines:1];
    valueLabel.text = value;
    valueLabel.tag = 9151;

    [view addSubview:caption];
    [view addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [caption.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14.0],
        [caption.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14.0],
        [caption.topAnchor constraintEqualToAnchor:view.topAnchor constant:9.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:caption.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:caption.trailingAnchor],
        [valueLabel.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:3.0],
    ]];
    return view;
}

- (void)buildTableView {
    self.tableView = [UITableView new];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 104.0;
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0, 24.0, 0);
    [self.tableView registerClass:PPAdoptPetCell.class forCellReuseIdentifier:@"PPAdoptPetCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:12.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)buildStateViews {
    self.emptyStateView = [UIView new];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.hidden = YES;
    [self.view addSubview:self.emptyStateView];

    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.10];
    iconShell.layer.cornerRadius = 28.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [self.emptyStateView addSubview:iconShell];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.circle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self pp_accentColor];
    [iconShell addSubview:icon];

    self.emptyTitleLabel = [self labelWithFont:[Styling fontBold:21.0] color:PrimaryTextClr lines:2];
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.text = kLang(@"AdoptPro_EmptyTitle");
    [self.emptyStateView addSubview:self.emptyTitleLabel];

    self.emptySubtitleLabel = [self labelWithFont:[Styling fontRegular:14.0] color:SeconderyTextClr lines:3];
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.text = kLang(@"AdoptPro_EmptySubtitle");
    [self.emptyStateView addSubview:self.emptySubtitleLabel];

    self.emptyActionButton = [self filledButtonWithTitle:kLang(@"AdoptPro_AddListing") selector:@selector(addTapped)];
    [self.emptyStateView addSubview:self.emptyActionButton];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.color = [self pp_accentColor];
    [self.view addSubview:self.loadingIndicator];

    self.stateLabel = [self labelWithFont:[Styling fontMedium:13.0] color:SeconderyTextClr lines:2];
    self.stateLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.stateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-14.0],
        [self.emptyStateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:36.0],
        [self.emptyStateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-36.0],

        [iconShell.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor],
        [iconShell.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:56.0],
        [iconShell.heightAnchor constraintEqualToConstant:56.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:28.0],
        [icon.heightAnchor constraintEqualToConstant:28.0],

        [self.emptyTitleLabel.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:16.0],
        [self.emptyTitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [self.emptyTitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor],
        [self.emptySubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyTitleLabel.bottomAnchor constant:8.0],
        [self.emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [self.emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor],
        [self.emptyActionButton.topAnchor constraintEqualToAnchor:self.emptySubtitleLabel.bottomAnchor constant:18.0],
        [self.emptyActionButton.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [self.emptyActionButton.heightAnchor constraintEqualToConstant:46.0],
        [self.emptyActionButton.widthAnchor constraintGreaterThanOrEqualToConstant:156.0],
        [self.emptyActionButton.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-10.0],
        [self.stateLabel.topAnchor constraintEqualToAnchor:self.loadingIndicator.bottomAnchor constant:12.0],
        [self.stateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:42.0],
        [self.stateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-42.0],
    ]];
}

- (UIButton *)filledButtonWithTitle:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [self pp_accentColor];
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 23.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [Styling fontBold:15.0];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Navigation

- (UIButton *)pp_addButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tintColor = [self pp_accentColor];
    btn.backgroundColor = AppForgroundColr;
    btn.layer.cornerRadius = 22.0;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.layer.shadowColor = (AppShadowColor).CGColor;
    btn.layer.shadowOpacity = 0.08;
    btn.layer.shadowRadius = 14.0;
    btn.layer.shadowOffset = CGSizeMake(0, 7.0);
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [btn setImage:[UIImage systemImageNamed:@"plus" withConfiguration:config] forState:UIControlStateNormal];
    btn.accessibilityLabel = kLang(@"AdoptPro_AddListing");
    [btn addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:44.0],
        [btn.heightAnchor constraintEqualToConstant:44.0],
    ]];
    return btn;
}

- (void)addTapped {
    [PPFunc pp_playTapEffect];
    PPAddEditAdoptPetViewController *vc = [[PPAddEditAdoptPetViewController alloc] initWithPet:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Data

- (void)startListening {
    [self.listener remove];
    __weak typeof(self) weakSelf = self;
    self.listener = [[PPAdoptPetManager sharedManager] observeAllAdoptPets:^(NSArray<PPAdoptPetModel *> *pets, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.hasLoadedOnce = YES;
        [self setLoading:NO message:nil];
        if (error) {
            DLog(@"[AdoptPets] listener error: %@", error.localizedDescription);
            [self showError:error.localizedDescription ?: kLang(@"AdoptPro_Error_Loading")];
            return;
        }
        self.allPets = pets ?: @[];
        [self updateMetrics];
        [self applyCurrentFilterAnimated:YES];
    }];
}

- (void)filterChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    [self applyCurrentFilterAnimated:YES];
}

- (void)applyCurrentFilterAnimated:(BOOL)animated {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPAdoptPetModel *pet, NSDictionary *bindings) {
        switch (self.filterControl.selectedSegmentIndex) {
            case PPAdoptPetsFilterAvailable:
                return !pet.isBlocked && !pet.isDeleted && pet.visibility != 1 && !pet.isAdopted && ![pet.status isEqualToString:@"hidden"] && ![pet.status isEqualToString:@"adopted"];
            case PPAdoptPetsFilterAdopted:
                return pet.isAdopted || [pet.status isEqualToString:@"adopted"];
            case PPAdoptPetsFilterHidden:
                return pet.isBlocked || pet.isDeleted || pet.visibility == 1 || [pet.status isEqualToString:@"hidden"];
            default:
                return YES;
        }
    }];
    NSArray *filtered = [self.allPets filteredArrayUsingPredicate:predicate];
    self.adoptPets = [filtered mutableCopy] ?: [NSMutableArray array];
    [self.tableView reloadData];
    [self updateEmptyState];
    if (animated && self.adoptPets.count > 0) {
        [self playCellEntranceAnimation];
    }
}

- (void)updateMetrics {
    NSInteger total = self.allPets.count;
    NSInteger available = 0;
    for (PPAdoptPetModel *pet in self.allPets) {
        BOOL hidden = pet.isBlocked || pet.isDeleted || pet.visibility == 1 || [pet.status isEqualToString:@"hidden"];
        BOOL adopted = pet.isAdopted || [pet.status isEqualToString:@"adopted"];
        if (!hidden && !adopted) {
            available++;
        }
    }
    self.totalValueLabel.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.availableValueLabel.text = [NSString stringWithFormat:@"%ld", (long)available];
}

- (void)setLoading:(BOOL)loading message:(NSString *)message {
    self.loadingIndicator.hidden = !loading;
    loading ? [self.loadingIndicator startAnimating] : [self.loadingIndicator stopAnimating];
    self.stateLabel.hidden = !loading && message.length == 0;
    self.stateLabel.text = message;
    self.tableView.hidden = loading;
    self.emptyStateView.hidden = YES;
}

- (void)showError:(NSString *)message {
    self.tableView.hidden = YES;
    self.emptyStateView.hidden = YES;
    self.stateLabel.hidden = NO;
    self.stateLabel.text = message.length > 0 ? message : kLang(@"AdoptPro_Error_Loading");
}

- (void)updateEmptyState {
    BOOL empty = self.hasLoadedOnce && self.adoptPets.count == 0;
    self.tableView.hidden = empty;
    self.emptyStateView.hidden = !empty;
    self.stateLabel.hidden = YES;
    if (empty && self.allPets.count > 0) {
        self.emptyTitleLabel.text = kLang(@"AdoptPro_FilterEmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"AdoptPro_FilterEmptySubtitle");
    } else {
        self.emptyTitleLabel.text = kLang(@"AdoptPro_EmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"AdoptPro_EmptySubtitle");
    }
}

#pragma mark - Motion

- (void)prepareEntranceState {
    if (self.didPrepareEntrance || self.didPlayEntrance) return;
    self.didPrepareEntrance = YES;
    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.tableView.alpha = 0.0;
    self.emptyStateView.alpha = 0.0;
}

- (void)runEntranceIfNeeded {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.tableView.alpha = 1.0;
        self.emptyStateView.alpha = 1.0;
        return;
    }
    [UIView animateWithDuration:0.48 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.36 delay:0.10 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.tableView.alpha = 1.0;
        self.emptyStateView.alpha = 1.0;
    } completion:nil];
}

- (void)playCellEntranceAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    for (NSUInteger idx = 0; idx < cells.count; idx++) {
        UITableViewCell *cell = cells[idx];
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0, 14.0);
        [UIView animateWithDuration:0.40 delay:0.025 * idx options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.adoptPets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPAdoptPetCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptPetCell" forIndexPath:indexPath];
    PPAdoptPetModel *pet = self.adoptPets[indexPath.row];
    [cell configureWithAdoptPet:pet];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PPAdoptPetModel *pet = self.adoptPets[indexPath.row];
    [PPFunc pp_playTapEffect];
    PPAdoptPetDetailViewController *vc = [PPAdoptPetDetailViewController new];
    vc.pet = pet;
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPAdoptPetModel *pet = self.adoptPets[indexPath.row];
    UIContextualAction *edit = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                       title:kLang(@"AdoptPro_Edit")
                                                                     handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        PPAddEditAdoptPetViewController *vc = [[PPAddEditAdoptPetViewController alloc] initWithPet:pet];
        [self.navigationController pushViewController:vc animated:YES];
        completionHandler(YES);
    }];
    edit.backgroundColor = [self pp_accentColor];
    return [UISwipeActionsConfiguration configurationWithActions:@[edit]];
}

@end
