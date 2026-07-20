//
//  PPCategoryPickerController.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 6/9/26.
//

#import "PPCategoryPickerController.h"

static NSString * const PPCategoryPickerCellIdentifier = @"PPCategoryPickerCellIdentifier";
static NSInteger const PPCategoryPickerEmptyTag = 5301;

#pragma mark - Category Picker Cell

@interface PPCategoryPickerCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *accentView;
@property (nonatomic, strong) UIView *iconSurfaceView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *selectionSurfaceView;
@property (nonatomic, strong) UIImageView *selectionIconView;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithMainKind:(MainKindsModel *)kind expanded:(BOOL)expanded selected:(BOOL)selected;
- (void)configureWithSubKind:(SubKindModel *)subKind selected:(BOOL)selected;
@end

@implementation PPCategoryPickerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.layer.cornerRadius = 22.0;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.layer.borderWidth = 0.5;
    _cardView.clipsToBounds = NO;
    [self.contentView addSubview:_cardView];

    _accentView = [[UIView alloc] init];
    _accentView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentView.layer.cornerRadius = 2.0;
    [_cardView addSubview:_accentView];

    _iconSurfaceView = [[UIView alloc] init];
    _iconSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconSurfaceView.layer.cornerRadius = 18.0;
    _iconSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    [_cardView addSubview:_iconSurfaceView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeCenter;
    [_iconSurfaceView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:16.0];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.78;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [Styling fontMedium:11.5];
    _subtitleLabel.textColor = SeconderyTextClr;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.numberOfLines = 1;
    [_cardView addSubview:_subtitleLabel];

    _selectionSurfaceView = [[UIView alloc] init];
    _selectionSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionSurfaceView.layer.cornerRadius = 16.0;
    _selectionSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    [_cardView addSubview:_selectionSurfaceView];

    _selectionIconView = [[UIImageView alloc] init];
    _selectionIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionIconView.contentMode = UIViewContentModeCenter;
    [_selectionSurfaceView addSubview:_selectionIconView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeCenter;
    [_cardView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-2.0],

        [_accentView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:18.0],
        [_accentView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:8.0],
        [_accentView.widthAnchor constraintEqualToConstant:26.0],
        [_accentView.heightAnchor constraintEqualToConstant:4.0],

        [_iconSurfaceView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16.0],
        [_iconSurfaceView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor constant:0.0],
        [_iconSurfaceView.widthAnchor constraintEqualToConstant:40.0],
        [_iconSurfaceView.heightAnchor constraintEqualToConstant:40.0],
        [_iconView.centerXAnchor constraintEqualToAnchor:_iconSurfaceView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconSurfaceView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToAnchor:_iconSurfaceView.widthAnchor constant:6],
        [_iconView.heightAnchor constraintEqualToAnchor:_iconSurfaceView.heightAnchor constant:-6],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconSurfaceView.trailingAnchor constant:14.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_selectionSurfaceView.leadingAnchor constant:-12.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:18.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],

        [_selectionSurfaceView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],
        [_selectionSurfaceView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_selectionSurfaceView.widthAnchor constraintEqualToConstant:32.0],
        [_selectionSurfaceView.heightAnchor constraintEqualToConstant:32.0],
        [_selectionIconView.centerXAnchor constraintEqualToAnchor:_selectionSurfaceView.centerXAnchor],
        [_selectionIconView.centerYAnchor constraintEqualToAnchor:_selectionSurfaceView.centerYAnchor],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_selectionSurfaceView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_selectionSurfaceView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:18.0],
        [_chevronView.heightAnchor constraintEqualToConstant:18.0]
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    [self.layer removeAllAnimations];
    [self.cardView.layer removeAllAnimations];
    self.chevronView.hidden = YES;
    self.selectionIconView.hidden = YES;
    self.selectionSurfaceView.hidden = NO;
    self.selectionSurfaceView.transform = CGAffineTransformIdentity;
}

- (void)configureWithMainKind:(MainKindsModel *)kind expanded:(BOOL)expanded selected:(BOOL)selected {
    NSString *iconName = kind.KindIconName.length > 0 ? kind.KindIconName : @"square.grid.2x2";
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightSemibold];

    self.titleLabel.text = kind.KindName.length ? kind.KindName : kLang(@"Market_CategoryReq");
    self.subtitleLabel.text = kind.SubKindsArray.count > 0 ? [NSString stringWithFormat:kLang(@"Market_CategoryPickerSubcategoryCount"), (long)kind.SubKindsArray.count] : kLang(@"Market_CategoryPickerMainOnly");
    self.titleLabel.font = [Styling fontBold:16.0];
    self.titleLabel.textColor = selected ? AppPrimaryClr : PrimaryTextClr;
    UIImage *assetIcon = [[UIImage imageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.iconView.image = assetIcon ?: [UIImage systemImageNamed:@"square.grid.2x2" withConfiguration:iconConfig];
    self.iconView.tintColor = selected ? UIColor.whiteColor : AppPrimaryClr;
    self.iconSurfaceView.backgroundColor = selected ? AppPrimaryClr : [AppPrimaryClr colorWithAlphaComponent:0.085];
    self.accentView.backgroundColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.34] : [AppPrimaryClr colorWithAlphaComponent:0.14];

    self.chevronView.hidden = NO;
    self.selectionIconView.hidden = YES;
    self.chevronView.image = [UIImage systemImageNamed:expanded ? @"chevron.down" : @"chevron.forward"
                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold]];
    self.chevronView.tintColor = selected ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.62];
    self.selectionSurfaceView.backgroundColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.12] : [SeconderyTextClr colorWithAlphaComponent:0.055];
    [self applyCardSelected:selected compact:NO];
}

- (void)configureWithSubKind:(SubKindModel *)subKind selected:(BOOL)selected {
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightBold];
    UIImageSymbolConfiguration *checkConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold];

    self.titleLabel.text = subKind.SubKindName.length ? subKind.SubKindName : kLang(@"Market_Subcategory");
    self.subtitleLabel.text = selected ? kLang(@"Market_CategoryPickerSelected") : kLang(@"Market_CategoryPickerChooseSubcategory");
    self.titleLabel.font = selected ? [Styling fontBold:15.0] : [Styling fontMedium:15.0];
    self.titleLabel.textColor = selected ? AppPrimaryClr : PrimaryTextClr;
    self.iconView.image = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"
                                  withConfiguration:iconConfig];
    self.iconView.tintColor = selected ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.50];
    self.iconSurfaceView.backgroundColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.11] : [SeconderyTextClr colorWithAlphaComponent:0.04];
    self.accentView.backgroundColor = UIColor.clearColor;

    self.chevronView.hidden = YES;
    self.selectionIconView.hidden = NO;
    self.selectionIconView.image = [UIImage systemImageNamed:selected ? @"checkmark" : @"plus"
                                           withConfiguration:checkConfig];
    self.selectionIconView.tintColor = selected ? UIColor.whiteColor : [SeconderyTextClr colorWithAlphaComponent:0.58];
    self.selectionSurfaceView.backgroundColor = selected ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.055];
    [self applyCardSelected:selected compact:YES];
}

- (void)applyCardSelected:(BOOL)selected compact:(BOOL)compact {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *surface = AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor;
    self.cardView.backgroundColor = selected ? [surface colorWithAlphaComponent:isDark ? 0.96 : 0.98] : [surface colorWithAlphaComponent:isDark ? 0.84 : 0.92];
    self.cardView.layer.borderColor = (selected ? [AppPrimaryClr colorWithAlphaComponent:0.22] : [SeconderyTextClr colorWithAlphaComponent:0.08]).CGColor;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = selected ? (isDark ? 0.18 : 0.08) : (isDark ? 0.10 : 0.035);
    self.cardView.layer.shadowRadius = selected ? 18.0 : 10.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, selected ? 10.0 : 5.0);
    self.subtitleLabel.textColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.78] : [SeconderyTextClr colorWithAlphaComponent:compact ? 0.68 : 0.76];
}

@end

#pragma mark - Category Picker Controller

@interface PPCategoryPickerController ()
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UILabel *heroSummaryLabel;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, assign) CGFloat headerWidth;
@property (nonatomic, assign) BOOL isLoadingKinds;
@end

@implementation PPCategoryPickerController

- (instancetype)initWithSelectedMainID:(NSInteger)mainID selectedSubID:(NSInteger)subID {
    if (self = [super init]) {
        _selectedMainID = mainID;
        _selectedSubID = subID;
        _expandedMainID = mainID > 0 ? mainID : -1;
        _animatedSections = [NSMutableSet set];
    }
    return self;
}

- (void)setOnSelection:(void (^)(NSInteger, NSInteger))block { _onSelection = [block copy]; }

+ (NSString *)displayNameForMainCategoryID:(NSInteger)mainID subCategoryID:(NSInteger)subID {
    NSArray<MainKindsModel *> *kinds = AppManager.shared.MainKindsArray;
    for (MainKindsModel *mk in kinds) {
        if (mk.ID == mainID) {
            if (subID > 0) {
                for (SubKindModel *sk in mk.SubKindsArray) {
                    if (sk.ID == subID) return [NSString stringWithFormat:@"%@ - %@", mk.KindName, sk.SubKindName];
                }
            }
            return mk.KindName;
        }
    }
    return kLang(@"Market_CategoryReq");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kLang(@"Market_SectionClassification");
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.headerWidth = MAX(CGRectGetWidth(self.view.bounds), UIScreen.mainScreen.bounds.size.width);

    [self setupNavigationTitleView];
    [self setupBackdropGlows];
    [self setupDoneButton];
    [self setupTableView];
    [self setupLoadingAndEmptyStates];
    [self loadKindsIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateBackdropGlows];
    [self updateHeroSummary];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startAmbientMotionIfNeeded];
    if (!self.hasAnimatedIn) {
        self.hasAnimatedIn = YES;
        [self animateScreenEntrance];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAmbientMotion];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (fabs(self.headerWidth - width) > 0.5) {
        self.headerWidth = width;
        self.tableView.tableHeaderView = [self buildHeaderViewForWidth:width];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateBackdropGlows];
    [self.tableView reloadData];
}

#pragma mark - Setup

- (void)setupNavigationTitleView {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"Market_SectionClassification");
    titleLabel.font = [Styling fontBold:21.0];
    titleLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    self.navigationItem.titleView = titleLabel;
}

- (void)setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 126.0;
    [self.view addSubview:self.bgGlowTop];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 104.0;
    [self.view addSubview:self.bgGlowBottom];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:252.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:252.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-92.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:94.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:54.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-78.0]
    ]];

    [self updateBackdropGlows];
}

- (void)updateBackdropGlows {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    self.bgGlowTop.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.045 : 0.10];
    self.bgGlowTop.layer.shadowColor = accent.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.05 : 0.10;
    self.bgGlowTop.layer.shadowRadius = 66.0;

    UIColor *warm = UIColor.systemOrangeColor;
    self.bgGlowBottom.backgroundColor = [warm colorWithAlphaComponent:isDark ? 0.025 : 0.055];
    self.bgGlowBottom.layer.shadowColor = warm.CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.03 : 0.07;
    self.bgGlowBottom.layer.shadowRadius = 72.0;
}

- (void)setupDoneButton {
    self.doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.doneButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.doneButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    [self.doneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.doneButton.titleLabel.font = [Styling fontBold:15.0];
    self.doneButton.backgroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
    self.doneButton.layer.cornerRadius = 16.0;
    self.doneButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.doneButton.layer.shadowColor = (AppPrimaryClr ?: UIColor.systemTealColor).CGColor;
    self.doneButton.layer.shadowOpacity = 0.20;
    self.doneButton.layer.shadowRadius = 10.0;
    self.doneButton.layer.shadowOffset = CGSizeMake(0, 6.0);
    self.doneButton.contentEdgeInsets = UIEdgeInsetsMake(8.0, 18.0, 8.0, 18.0);
    [self.doneButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0, 24.0, 0);
    self.tableView.rowHeight = 76;
    self.tableView.estimatedRowHeight = 76;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:PPCategoryPickerCell.class forCellReuseIdentifier:PPCategoryPickerCellIdentifier];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.tableView.tableHeaderView = [self buildHeaderViewForWidth:self.headerWidth];
}

- (void)setupLoadingAndEmptyStates {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AppPrimaryClr ?: UIColor.systemTealColor;
    [self.view addSubview:self.spinner];

    self.emptyView = [self buildEmptyStateView];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyView.hidden = YES;
    [self.view addSubview:self.emptyView];

    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:44.0],
        [self.emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-28.0]
    ]];
}

- (UIView *)buildHeaderViewForWidth:(CGFloat)width {
    width = MAX(width, 1.0);
    CGFloat height = 188.0;

    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    root.backgroundColor = UIColor.clearColor;
    root.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    PPHero *card = [[PPHero alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:card];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"square.grid.2x2.fill"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold]];
    icon.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    icon.contentMode = UIViewContentModeCenter;
    [iconSurface addSubview:icon];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.text = kLang(@"Market_CategoryPickerEyebrow");
    eyebrowLabel.font = [Styling fontBold:11.0];
    eyebrowLabel.textColor = [AppPrimaryClr colorWithAlphaComponent:0.86];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:eyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.text = kLang(@"Market_SectionClassification");
    self.heroTitleLabel.font = [Styling fontBold:24.0];
    self.heroTitleLabel.textColor = PrimaryTextClr;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.78;
    [card addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.text = kLang(@"Market_CategoryPickerSubtitle");
    self.heroSubtitleLabel.font = [Styling fontMedium:13.0];
    self.heroSubtitleLabel.textColor = SeconderyTextClr;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.numberOfLines = 2;
    [card addSubview:self.heroSubtitleLabel];

    self.heroSummaryLabel = [[UILabel alloc] init];
    self.heroSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSummaryLabel.font = [Styling fontBold:12.0];
    self.heroSummaryLabel.textAlignment = NSTextAlignmentCenter;
    self.heroSummaryLabel.textColor = AppPrimaryClr ?: UIColor.systemTealColor;
    self.heroSummaryLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    self.heroSummaryLabel.layer.cornerRadius = 15.0;
    self.heroSummaryLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroSummaryLabel.clipsToBounds = YES;
    [card addSubview:self.heroSummaryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:root.topAnchor constant:12.0],
        [card.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20.0],
        [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20.0],
        [card.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-14.0],

        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:44.0],
        [iconSurface.widthAnchor constraintEqualToConstant:56.0],
        [iconSurface.heightAnchor constraintEqualToConstant:56.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:16.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:iconSurface.topAnchor constant:0.0],

        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:eyebrowLabel.trailingAnchor],
        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:4.0],

        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:eyebrowLabel.trailingAnchor],
        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:5.0],

        [self.heroSummaryLabel.topAnchor constraintEqualToAnchor:_heroSubtitleLabel.bottomAnchor constant:8.0],

        [self.heroSummaryLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [self.heroSummaryLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],
        [self.heroSummaryLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
        [self.heroSummaryLabel.heightAnchor constraintEqualToConstant:34.0]
    ]];

    self.heroView = card;
    [self updateHeroSummary];
    return root;
}

- (UIView *)buildEmptyStateView {
    UIView *container = [[UIView alloc] init];
    container.tag = PPCategoryPickerEmptyTag;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    iconSurface.layer.cornerRadius = 28.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"tray"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24.0 weight:UIImageSymbolWeightSemibold]];
    icon.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    [iconSurface addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = kLang(@"Market_CategoryPickerEmptyTitle");
    title.font = [Styling fontBold:20.0];
    title.textColor = PrimaryTextClr;
    title.textAlignment = NSTextAlignmentCenter;
    [container addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = kLang(@"Market_CategoryPickerEmptySubtitle");
    subtitle.font = [Styling fontMedium:13.0];
    subtitle.textColor = SeconderyTextClr;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 2;
    [container addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:container.topAnchor],
        [iconSurface.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [iconSurface.widthAnchor constraintEqualToConstant:56.0],
        [iconSurface.heightAnchor constraintEqualToConstant:56.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:16.0],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

#pragma mark - Data

- (void)loadKindsIfNeeded {
    self.kinds = [self visibleKindsFromKinds:AppManager.shared.MainKindsArray ?: @[]];
    if (self.kinds.count > 0) {
        [self updateContentState];
        return;
    }

    self.isLoadingKinds = YES;
    [self updateContentState];
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    [AppManager.shared fetchMainKindsWithCompletion:^(NSArray<MainKindsModel *> *kinds, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            self.isLoadingKinds = NO;
            self.kinds = [self visibleKindsFromKinds:kinds ?: @[]];
            [self.spinner stopAnimating];
            [self.tableView reloadData];
            [self updateContentState];
            [self animateVisibleCellsOnce];
        });
    }];
}

- (NSArray<MainKindsModel *> *)visibleKindsFromKinds:(NSArray<MainKindsModel *> *)kinds {
    NSMutableArray<MainKindsModel *> *visibleKinds = [NSMutableArray array];
    for (MainKindsModel *kind in kinds) {
        if (kind.isVisibleInUserApp) {
            [visibleKinds addObject:kind];
        }
    }
    return visibleKinds.copy;
}

- (void)updateContentState {
    BOOL hasKinds = self.kinds.count > 0;
    self.tableView.hidden = self.isLoadingKinds;
    self.emptyView.hidden = self.isLoadingKinds || hasKinds;
    if (self.isLoadingKinds) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

- (void)updateHeroSummary {
    if (!self.heroSummaryLabel) return;
    NSString *display = [self displayNameForCurrentSelection];
    BOOL hasSelection = self.selectedMainID > 0;
    self.heroSummaryLabel.text = hasSelection ? [NSString stringWithFormat:kLang(@"Market_CategoryPickerSelectedFormat"), display] : kLang(@"Market_CategoryPickerTapFamily");
    self.heroSummaryLabel.textColor = hasSelection ? (AppPrimaryClr ?: UIColor.systemTealColor) : SeconderyTextClr;
    self.heroSummaryLabel.backgroundColor = hasSelection ? [AppPrimaryClr colorWithAlphaComponent:0.09] : [SeconderyTextClr colorWithAlphaComponent:0.055];
}

- (NSString *)displayNameForCurrentSelection {
    for (MainKindsModel *mainKind in self.kinds) {
        if (mainKind.ID == self.selectedMainID) {
            if (self.selectedSubID > 0) {
                for (SubKindModel *subKind in mainKind.SubKindsArray) {
                    if (subKind.ID == self.selectedSubID) {
                        return [NSString stringWithFormat:@"%@ - %@", mainKind.KindName, subKind.SubKindName];
                    }
                }
            }
            return mainKind.KindName;
        }
    }
    return [[self class] displayNameForMainCategoryID:self.selectedMainID subCategoryID:self.selectedSubID];
}

#pragma mark - Motion

- (void)startAmbientMotionIfNeeded {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:5.8 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.bgGlowTop.transform = CGAffineTransformMakeScale(1.045, 1.045);
        self.bgGlowBottom.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)stopAmbientMotion {
    [self.bgGlowTop.layer removeAllAnimations];
    [self.bgGlowBottom.layer removeAllAnimations];
    self.bgGlowTop.transform = CGAffineTransformIdentity;
    self.bgGlowBottom.transform = CGAffineTransformIdentity;
}

- (void)animateScreenEntrance {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
        return;
    }

    self.heroView.alpha = 0.0;
    self.heroView.transform = CGAffineTransformMakeTranslation(0, 14.0);
    [UIView animateWithDuration:0.46 delay:0.03 usingSpringWithDamping:0.86 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self animateVisibleCellsOnce];
}

- (void)animateVisibleCellsOnce {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    NSArray<NSIndexPath *> *visible = [self.tableView indexPathsForVisibleRows];
    for (NSInteger i = 0; i < visible.count; i++) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:visible[i]];
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0, 14.0);
        [UIView animateWithDuration:0.38 delay:i * 0.035 usingSpringWithDamping:0.84 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)animatePressForCell:(UITableViewCell *)cell completion:(void (^)(void))completion {
    if (!cell) {
        if (completion) completion();
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        if (completion) completion();
        return;
    }

    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        cell.transform = CGAffineTransformMakeScale(0.972, 0.972);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL finished) {
            if (completion) completion();
        }];
    }];
}

#pragma mark - Actions

- (void)doneTapped {
    [PPFunc pp_playTapEffect];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.10 animations:^{
            self.doneButton.transform = CGAffineTransformMakeScale(0.96, 0.96);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.16 animations:^{
                self.doneButton.transform = CGAffineTransformIdentity;
            }];
        }];
    }
    if (self.onSelection) self.onSelection(self.selectedMainID, self.selectedSubID);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.kinds.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    MainKindsModel *mainKind = self.kinds[section];
    return mainKind.ID == self.expandedMainID ? 1 + mainKind.SubKindsArray.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPCategoryPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCategoryPickerCellIdentifier forIndexPath:indexPath];
    MainKindsModel *mainKind = self.kinds[indexPath.section];
    BOOL isMain = indexPath.row == 0;

    if (isMain) {
        BOOL selected = mainKind.ID == self.selectedMainID;
        [cell configureWithMainKind:mainKind expanded:(mainKind.ID == self.expandedMainID) selected:selected];
    } else {
        SubKindModel *subKind = mainKind.SubKindsArray[indexPath.row - 1];
        BOOL selected = (mainKind.ID == self.selectedMainID && subKind.ID == self.selectedSubID);
        [cell configureWithSubKind:subKind selected:selected];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 0; }
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 0; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return  72; }
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section { return [UIView new]; }
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section { return [UIView new]; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [PPFunc pp_playTapEffect];

    MainKindsModel *mainKind = self.kinds[indexPath.section];
    BOOL isMain = indexPath.row == 0;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    __weak typeof(self) weakSelf = self;
    [self animatePressForCell:cell completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (isMain) {
            NSInteger previousExpanded = self.expandedMainID;
            self.expandedMainID = (previousExpanded == mainKind.ID) ? -1 : mainKind.ID;
            if (self.selectedMainID != mainKind.ID) {
                self.selectedMainID = mainKind.ID;
                self.selectedSubID = 0;
            }
            [self updateHeroSummary];
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }

        SubKindModel *subKind = mainKind.SubKindsArray[indexPath.row - 1];
        self.selectedMainID = mainKind.ID;
        self.selectedSubID = subKind.ID;
        [self updateHeroSummary];
        [tableView reloadData];
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *sectionKey = @(indexPath.section);
    if (self.hasAnimatedIn || [self.animatedSections containsObject:sectionKey] || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self.animatedSections addObject:sectionKey];
    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeTranslation(0, 12.0);
    [UIView animateWithDuration:0.34 delay:indexPath.section * 0.025 usingSpringWithDamping:0.84 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
