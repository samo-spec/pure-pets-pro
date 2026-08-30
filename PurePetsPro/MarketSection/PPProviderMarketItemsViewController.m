#import "PPProviderMarketItemsViewController.h"
#import "PPProviderMarketItemEditorViewController.h"
#import "PPProviderMarketItem.h"
#import "PPProviderMarketplaceManager.h"
#import "PPFirebaseCompat.h"
#import "PPProviderCompaniesBottomSearchBar.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static const CGFloat PPBottomSearchParkedInset = 16.0;

@interface PPProviderMarketItemsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, assign) CGFloat headerWidth;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *items;
@property (nonatomic, strong) UILabel *headerCountBadge;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *filteredItems;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) PPProviderCompaniesBottomSearchBar *bottomSearchBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, strong) UIView *bottomSearchFadeView;
@property (nonatomic, strong) CAGradientLayer *bottomSearchFadeLayer;
@property (nonatomic, strong) UIControl *keyboardDismissOverlay;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@end

@implementation PPProviderMarketItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = pp_canvasColor();
    self.hasLoaded = NO;
    self.items = @[];
    self.filteredItems = @[];
    self.searchQuery = @"";

    [self setupAddButton];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(10, 0, 124, 0);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(10, 0, 124, 0);
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = 118;
    _tableView.estimatedRowHeight = 118;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:[self cellClass] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:_tableView];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];

    [self buildEmptyState];
    [self.view addSubview:_emptyView];
    [self setupBottomSearchBar];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    self.headerWidth = MAX(CGRectGetWidth(self.view.bounds), UIScreen.mainScreen.bounds.size.width);
    self.tableView.tableHeaderView = [self buildHeaderViewForWidth:self.headerWidth];
    [self startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
    self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:self.addButton title:kLang(@"Market_Title") showBack:YES];
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (fabs(self.headerWidth - width) > 0.5) {
        self.headerWidth = width;
        self.tableView.tableHeaderView = [self buildHeaderViewForWidth:width];
    }
    self.bottomSearchFadeLayer.frame = self.bottomSearchFadeView.bounds;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateBottomSearchFadeStyle];
    [self.bottomSearchBar applyCurrentTheme];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.bottomSearchBar.hidden) {
        [self.bottomSearchBar animateInIfNeeded];
    }
}




- (Class)cellClass { return UITableViewCell.class; }

- (void)setupAddButton {
    self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        // Fallback on earlier versions
    }
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = UIColor.clearColor;
    config.background.backgroundColor = UIColor.clearColor;
    self.addButton.configuration = config;
    
    [self.addButton setImage:[UIImage systemImageNamed:@"plus" withConfiguration:cfg] forState:UIControlStateNormal];
    self.addButton.tintColor = UIColor.whiteColor;
    self.addButton.backgroundColor = UIColor.clearColor;
    self.addButton.layer.cornerRadius = 22.0;
    self.addButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.addButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.addButton.layer.shadowOpacity = 0.24;
    self.addButton.layer.shadowRadius = 10.0;
    self.addButton.layer.shadowOffset = CGSizeMake(0, 6);
    [self.addButton.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [self.addButton.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [self.addButton addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupBottomSearchBar {
    self.bottomSearchFadeView = [[UIView alloc] init];
    self.bottomSearchFadeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchFadeView.userInteractionEnabled = NO;
    self.bottomSearchFadeView.hidden = YES;
    [self.view addSubview:self.bottomSearchFadeView];

    self.bottomSearchFadeLayer = [CAGradientLayer layer];
    self.bottomSearchFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bottomSearchFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    self.bottomSearchFadeLayer.locations = @[@0.0, @0.56, @1.0];
    [self.bottomSearchFadeView.layer addSublayer:self.bottomSearchFadeLayer];

    self.bottomSearchBar = [[PPProviderCompaniesBottomSearchBar alloc] initWithPlaceholder:kLang(@"Market_BottomSearch_Placeholder")];
    self.bottomSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchBar.hidden = YES;
    __weak typeof(self) weakSelf = self;
    self.bottomSearchBar.textDidChangeHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUI];
    };
    self.bottomSearchBar.submitHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUI];
    };
    [self.view addSubview:self.bottomSearchBar];
    [self installKeyboardDismissOverlay];
    self.bottomSearchBar.keyboardEditingStateHandler = ^(BOOL editing) {
        __strong typeof(weakSelf) self = weakSelf;
        self.keyboardDismissOverlay.hidden = !editing;
        self.bottomSearchFadeView.hidden = editing || self.bottomSearchBar.hidden;
    };

    self.bottomSearchBarBottomConstraint = [self.bottomSearchBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-PPBottomSearchParkedInset];
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomSearchFadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomSearchFadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomSearchFadeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomSearchFadeView.heightAnchor constraintEqualToConstant:136.0],

        [self.bottomSearchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.bottomSearchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        self.bottomSearchBarBottomConstraint,
        [self.bottomSearchBar.heightAnchor constraintEqualToConstant:48.0],
    ]];
    [self.bottomSearchBar installKeyboardAvoidanceInView:self.view bottomConstraint:self.bottomSearchBarBottomConstraint];
    [self updateBottomSearchFadeStyle];
}

- (void)updateBottomSearchFadeStyle {
    UIColor *base = pp_canvasColor();
    self.bottomSearchFadeLayer.colors = @[
        (id)[base colorWithAlphaComponent:0.0].CGColor,
        (id)[base colorWithAlphaComponent:0.78].CGColor,
        (id)[base colorWithAlphaComponent:1.0].CGColor
    ];
}

- (UIView *)buildHeaderViewForWidth:(CGFloat)width {
    width = MAX(width, 1.0);
    CGFloat height = 176.0;

    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    root.backgroundColor = UIColor.clearColor;

    PPHero *heroCard = [[PPHero alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.accentColor = AppPrimaryClr;
    [root addSubview:heroCard];

    [NSLayoutConstraint activateConstraints:@[
        [heroCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [heroCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [heroCard.topAnchor constraintEqualToAnchor:root.topAnchor],
        [heroCard.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [heroCard addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"bag.fill"
                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]];
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [iconSurface addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = kLang(@"Market_Title");
    title.font = [Styling fontBold:24];
    title.textColor = PrimaryTextClr;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.numberOfLines = 1;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.8;
    [heroCard addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = kLang(@"Market_HeaderSubtitle");
    subtitle.font = [Styling fontMedium:13];
    subtitle.textColor = SeconderyTextClr;
    subtitle.textAlignment = Language.alignmentForCurrentLanguage;
    subtitle.numberOfLines = 2;
    [heroCard addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [iconSurface.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:42.0],
        [iconSurface.widthAnchor constraintEqualToConstant:56.0],
        [iconSurface.heightAnchor constraintEqualToConstant:56.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [title.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:16.0],
        [title.topAnchor constraintEqualToAnchor:iconSurface.topAnchor constant:4.0],
        [title.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

    ]];

    _headerCountBadge = [[UILabel alloc] init];
    _headerCountBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _headerCountBadge.text = @"—";
    _headerCountBadge.font = [Styling fontBold:12];
    _headerCountBadge.textColor = AppPrimaryClr;
    _headerCountBadge.textAlignment = NSTextAlignmentCenter;
    _headerCountBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    _headerCountBadge.layer.cornerRadius = 12;
    _headerCountBadge.layer.cornerCurve = kCACornerCurveContinuous;
    _headerCountBadge.layer.borderWidth = 0.0 / UIScreen.mainScreen.scale;
    _headerCountBadge.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.0].CGColor;
    _headerCountBadge.layer.shadowColor = AppPrimaryClr.CGColor;
    _headerCountBadge.layer.shadowOpacity = 0.10;
    _headerCountBadge.layer.shadowRadius = 8.0;
    _headerCountBadge.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    _headerCountBadge.clipsToBounds = YES;
    [heroCard addSubview:_headerCountBadge];
    [NSLayoutConstraint activateConstraints:@[
        [_headerCountBadge.leadingAnchor constraintEqualToAnchor:subtitle.leadingAnchor],
        [_headerCountBadge.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:10],
        [_headerCountBadge.widthAnchor constraintEqualToConstant:52],
        [_headerCountBadge.heightAnchor constraintEqualToConstant:24],
    ]];

    [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:heroCard.bottomAnchor constant:-18.0].active = YES;
    self.headerView = root;
    return root;
}

- (void)buildEmptyState {
    _emptyView = [[UIView alloc] init];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.hidden = YES;
    UIView *circle = [[UIView alloc] init];
    circle.translatesAutoresizingMaskIntoConstraints = NO;
    circle.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    circle.layer.cornerRadius = 44.0;
    [_emptyView addSubview:circle];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bag.fill"]];
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [circle addSubview:icon];
    UILabel *title = [[UILabel alloc] init];
    title.text = kLang(@"Market_EmptyTitle");
    title.font = [Styling fontBold:17];
    title.textColor = PrimaryTextClr;
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO; [_emptyView addSubview:title];
    self.emptyTitleLabel = title;
    UILabel *sub = [[UILabel alloc] init];
    sub.text = kLang(@"Market_EmptySubtitle");
    sub.font = [Styling fontRegular:13];
    sub.textColor = SeconderyTextClr;
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 0;
    sub.translatesAutoresizingMaskIntoConstraints = NO; [_emptyView addSubview:sub];
    self.emptySubtitleLabel = sub;
    [NSLayoutConstraint activateConstraints:@[
        [circle.widthAnchor constraintEqualToConstant:88],
        [circle.heightAnchor constraintEqualToConstant:88],
        [circle.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [circle.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [icon.widthAnchor constraintEqualToConstant:30],
        [icon.heightAnchor constraintEqualToConstant:30],
        [icon.centerXAnchor constraintEqualToAnchor:circle.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:circle.centerYAnchor],
        [title.topAnchor constraintEqualToAnchor:circle.bottomAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor], [title.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [sub.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor constant:20],
        [sub.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor constant:-20],
        [sub.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor], ]];
}

- (void)startListening {
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid) { self.hasLoaded = YES; [self updateUI]; return; }
    __weak typeof(self) ws = self;
    [self.spinner startAnimating];
    self.listener = [[PPProviderMarketplaceManager sharedManager] observeMarketItemsForOwnerID:uid onChange:^(NSArray<PPProviderMarketItem *> *items, NSError *error) {
        __strong typeof(ws) self = ws;
        if (error) { [PPToast toast:kLang(@"Market_LoadError") style:PPToastStyleError haptic:NO duration:3.0]; self.hasLoaded = YES; [self.spinner stopAnimating]; [self updateUI]; return; }
        self.items = items ?: @[]; self.hasLoaded = YES; [self.spinner stopAnimating]; [self updateUI];
    }];
}

- (void)updateUI {
    [self refreshFilteredItems];
    BOOL hasSearch = [self hasActiveSearchQuery];
    BOOL sourceEmpty = self.items.count == 0;
    BOOL displayEmpty = self.filteredItems.count == 0;
    BOOL shouldShowEmpty = self.hasLoaded && (sourceEmpty || (hasSearch && displayEmpty));
    self.emptyView.hidden = !shouldShowEmpty;
    self.tableView.hidden = !self.hasLoaded || sourceEmpty || (hasSearch && displayEmpty);
    self.bottomSearchBar.hidden = !self.hasLoaded || sourceEmpty;
    self.bottomSearchFadeView.hidden = self.bottomSearchBar.hidden || self.bottomSearchBar.isKeyboardEditing;
    CGFloat width = self.headerWidth > 0 ? self.headerWidth : MAX(CGRectGetWidth(self.view.bounds), UIScreen.mainScreen.bounds.size.width);
    self.tableView.tableHeaderView = [self buildHeaderViewForWidth:width];
    if (hasSearch && !sourceEmpty) {
        self.headerCountBadge.text = [NSString stringWithFormat:kLang(@"PPBottomSearch_Results_Format"), (long)self.filteredItems.count, (long)self.items.count];
    } else {
        self.headerCountBadge.text = [NSString stringWithFormat:@"%ld %@", (long)self.items.count, kLang(@"Market_ItemsCount")];
    }
    [self.bottomSearchBar setResultCount:self.filteredItems.count totalCount:self.items.count];
    [self updateEmptyStateForSearch:hasSearch sourceEmpty:sourceEmpty displayEmpty:displayEmpty];
    [self.tableView reloadData];
    if (!self.bottomSearchBar.hidden) {
        [self.bottomSearchBar animateInIfNeeded];
    }
}

#pragma mark - Search

- (NSArray<PPProviderMarketItem *> *)displayedItems {
    return self.filteredItems ?: @[];
}

- (BOOL)hasActiveSearchQuery {
    return [self trimmedSearchQuery].length > 0;
}

- (NSString *)trimmedSearchQuery {
    return [self.searchQuery ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)refreshFilteredItems {
    NSArray<PPProviderMarketItem *> *source = self.items ?: @[];
    NSString *query = [self trimmedSearchQuery];
    if (query.length == 0) {
        self.filteredItems = source;
        return;
    }

    NSMutableArray<PPProviderMarketItem *> *matches = [NSMutableArray array];
    for (PPProviderMarketItem *item in source) {
        NSString *searchText = [self searchTextForMarketItem:item];
        if ([searchText rangeOfString:query options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location != NSNotFound) {
            [matches addObject:item];
        }
    }
    self.filteredItems = matches.copy;
}

- (NSString *)searchTextForMarketItem:(PPProviderMarketItem *)item {
    if (!item) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [self appendSearchObject:item.itemID toParts:parts];
    [self appendSearchObject:item.name toParts:parts];
    [self appendSearchObject:item.nameEn toParts:parts];
    [self appendSearchObject:item.desc toParts:parts];
    [self appendSearchObject:item.descEn toParts:parts];
    [self appendSearchObject:item.petMainCategoryName toParts:parts];
    [self appendSearchObject:item.ownerType toParts:parts];
    [self appendSearchObject:[item kindLabel] toParts:parts];
    [self appendSearchObject:[item stockLabel] toParts:parts];
    [self appendSearchObject:[item visibilityLabel] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%ld", (long)item.quantity] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", item.price] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", item.finalPrice] toParts:parts];
    if (item.hasOffer) [self appendSearchObject:kLang(@"Market_Offer") toParts:parts];
    return [parts componentsJoinedByString:@" "];
}

- (void)appendSearchObject:(id)object toParts:(NSMutableArray<NSString *> *)parts {
    if (![object isKindOfClass:NSString.class]) return;
    NSString *value = [(NSString *)object stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length > 0) {
        [parts addObject:value];
    }
}

- (void)updateEmptyStateForSearch:(BOOL)hasSearch sourceEmpty:(BOOL)sourceEmpty displayEmpty:(BOOL)displayEmpty {
    if (hasSearch && !sourceEmpty && displayEmpty) {
        self.emptyTitleLabel.text = kLang(@"Market_SearchEmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Market_SearchEmptySubtitle");
    } else {
        self.emptyTitleLabel.text = kLang(@"Market_EmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Market_EmptySubtitle");
    }
}

- (void)installKeyboardDismissOverlay {
    self.keyboardDismissOverlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.keyboardDismissOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyboardDismissOverlay.backgroundColor = UIColor.clearColor;
    self.keyboardDismissOverlay.hidden = YES;
    self.keyboardDismissOverlay.accessibilityElementsHidden = YES;
    [self.keyboardDismissOverlay addTarget:self action:@selector(dismissBottomSearchKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:self.keyboardDismissOverlay aboveSubview:self.bottomSearchBar];
    [NSLayoutConstraint activateConstraints:@[
        [self.keyboardDismissOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.keyboardDismissOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keyboardDismissOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.keyboardDismissOverlay.bottomAnchor constraintEqualToAnchor:self.bottomSearchBar.topAnchor],
    ]];
}

- (void)dismissBottomSearchKeyboard {
    [self.bottomSearchBar dismissKeyboard];
}

- (void)addTapped {
    PPProviderMarketItemEditorViewController *vc = [[PPProviderMarketItemEditorViewController alloc] initForCreate];
    __weak typeof(self) ws = self;
    vc.onSave = ^{ [ws updateUI]; };
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return [self displayedItems].count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    cell.backgroundColor = UIColor.clearColor; cell.contentView.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self configureCell:cell atIndexPath:ip];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)ip {
    PPProviderMarketItem *item = [self displayedItems][ip.row];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    
    
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 24.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.07].CGColor;
    cell.layer.shadowColor = AppShadowColor.CGColor;
    cell.layer.shadowOpacity = 0.055;
    cell.layer.shadowRadius = 18.0;
    cell.layer.shadowOffset = CGSizeMake(0, 10.0);
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.clipsToBounds = YES;
    [cell.contentView addSubview:card];

    UIView *toneHalo = [[UIView alloc] init];
    toneHalo.translatesAutoresizingMaskIntoConstraints = NO;
    toneHalo.userInteractionEnabled = NO;
    toneHalo.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.055];
    toneHalo.layer.cornerRadius = 42.0;
    [card addSubview:toneHalo];

    UIView *imageShell = [[UIView alloc] init];
    imageShell.translatesAutoresizingMaskIntoConstraints = NO;
    imageShell.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.065];
    imageShell.layer.cornerRadius = 18.0;
    imageShell.layer.cornerCurve = kCACornerCurveContinuous;
    imageShell.clipsToBounds = YES;
    [card addSubview:imageShell];

    UIImageView *img = [[UIImageView alloc] init];
    img.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    img.layer.cornerRadius = 16;
    img.clipsToBounds = YES;
    img.contentMode = UIViewContentModeScaleAspectFill;
    img.translatesAutoresizingMaskIntoConstraints = NO;
    [imageShell addSubview:img];

    if (item.imageURLsArray.firstObject.length > 0) {
        [img setImageURL:[NSURL URLWithString:item.imageURLsArray.firstObject]];
    } else {
        UIImageView *placeholder = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill"]];
        placeholder.translatesAutoresizingMaskIntoConstraints = NO;
        placeholder.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.24];
        placeholder.contentMode = UIViewContentModeCenter;
        [img addSubview:placeholder];
        [NSLayoutConstraint activateConstraints:@[
            [placeholder.centerXAnchor constraintEqualToAnchor:img.centerXAnchor],
            [placeholder.centerYAnchor constraintEqualToAnchor:img.centerYAnchor],
            [placeholder.widthAnchor constraintEqualToConstant:24.0],
            [placeholder.heightAnchor constraintEqualToConstant:24.0],
        ]];
    }

    UILabel *name = [[UILabel alloc] init];
    name.text = item.nameEn.length > 0 ? item.nameEn : item.name;
    name.numberOfLines = 1;
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    name.font = [Styling fontBold:16.5];
    name.textColor = PrimaryTextClr;
    name.textAlignment = Language.alignmentForCurrentLanguage;
    name.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:name];

    UILabel *kindBadge = [[UILabel alloc] init];
    kindBadge.translatesAutoresizingMaskIntoConstraints = NO;
    kindBadge.text = [NSString stringWithFormat:@"  %@  ", [item kindLabel].uppercaseString];
    kindBadge.font = [Styling fontBold:10.0];
    kindBadge.textColor = AppPrimaryClr;
    kindBadge.textAlignment = NSTextAlignmentCenter;
    kindBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    kindBadge.layer.cornerRadius = 10.0;
    kindBadge.layer.cornerCurve = kCACornerCurveContinuous;
    kindBadge.clipsToBounds = YES;
    [card addSubview:kindBadge];

    NSString *stockLabel = [item stockLabel];
    NSString *visibilityLabel = [item visibilityLabel];
    BOOL isHidden = visibilityLabel.length > 0;

    UILabel *stockBadge = [[UILabel alloc] init];
    stockBadge.translatesAutoresizingMaskIntoConstraints = NO;
    stockBadge.text = [NSString stringWithFormat:@"  %@  ", stockLabel.length ? stockLabel : kLang(@"Market_InStock")];
    stockBadge.font = [Styling fontBold:10.0];
    stockBadge.textAlignment = NSTextAlignmentCenter;
    UIColor *stockColor = item.noStock ? [UIColor ppError] : [UIColor ppSuccess];
    stockBadge.textColor = stockColor;
    stockBadge.backgroundColor = [stockColor colorWithAlphaComponent:item.noStock ? 0.09 : 0.11];
    stockBadge.layer.cornerRadius = 10.0;
    stockBadge.layer.cornerCurve = kCACornerCurveContinuous;
    stockBadge.clipsToBounds = YES;
    [card addSubview:stockBadge];

    UILabel *stateLabel = [[UILabel alloc] init];
    NSMutableArray<NSString *> *states = [NSMutableArray array];
    if (isHidden) [states addObject:visibilityLabel];
    if (item.hasOffer) [states addObject:kLang(@"Market_Offer")];
    stateLabel.text = states.count ? [states componentsJoinedByString:@"  /  "] : kLang(@"Market_Stock");
    stateLabel.font = [Styling fontMedium:11.5];
    stateLabel.textColor = isHidden ? [UIColor ppWarning] : [SeconderyTextClr colorWithAlphaComponent:0.72];
    stateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    stateLabel.numberOfLines = 1;
    stateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stateLabel];

    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.text = [NSString stringWithFormat:@"%.0f QAR", item.finalPrice > 0 ? item.finalPrice : item.price];
    priceLabel.font = [Styling fontBold:17.0];
    priceLabel.textColor = PrimaryTextClr;
    priceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:priceLabel];

    UIButton *menuButton = [UIButton new];
    
    menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [menuButton setImage:[UIImage systemImageNamed:@"ellipsis"
                                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular]] forState:UIControlStateNormal];
    
    if(PPIOS26())
    {
        UIButtonConfiguration *config;
        
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            // Fallback on earlier versions
        }
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseBackgroundColor = UIColor.clearColor;
        config.background.backgroundColor = UIColor.clearColor;
        menuButton.configuration = config;
    }
    else
    {
        menuButton.tintColor = AppPrimaryClr;
        menuButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.075];
        menuButton.layer.cornerRadius = 18.0;
        menuButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    
    
   
   
    menuButton.tag = ip.row;
    [menuButton addTarget:self action:@selector(menuTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    
    [card addSubview:menuButton];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:18],
        [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-18],
        [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:7],
        [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-7],

        [toneHalo.widthAnchor constraintEqualToConstant:86.0],
        [toneHalo.heightAnchor constraintEqualToConstant:86.0],
        [toneHalo.topAnchor constraintEqualToAnchor:card.topAnchor constant:-26.0],
        [toneHalo.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:18.0],

        [imageShell.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [imageShell.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [imageShell.widthAnchor constraintEqualToConstant:76],
        [imageShell.heightAnchor constraintEqualToConstant:76],

        [img.topAnchor constraintEqualToAnchor:imageShell.topAnchor constant:4.0],
        [img.leadingAnchor constraintEqualToAnchor:imageShell.leadingAnchor constant:4.0],
        [img.trailingAnchor constraintEqualToAnchor:imageShell.trailingAnchor constant:-4.0],
        [img.bottomAnchor constraintEqualToAnchor:imageShell.bottomAnchor constant:-4.0],

        [kindBadge.topAnchor constraintEqualToAnchor:card.topAnchor constant:17.0],
        [kindBadge.leadingAnchor constraintEqualToAnchor:imageShell.trailingAnchor constant:16.0],
        [kindBadge.heightAnchor constraintEqualToConstant:20.0],
        [kindBadge.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [kindBadge.trailingAnchor constraintLessThanOrEqualToAnchor:menuButton.leadingAnchor constant:-10.0],

        [menuButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [menuButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [menuButton.widthAnchor constraintEqualToConstant:36],
        [menuButton.heightAnchor constraintEqualToConstant:36],

        [name.leadingAnchor constraintEqualToAnchor:kindBadge.leadingAnchor],
        [name.topAnchor constraintEqualToAnchor:kindBadge.bottomAnchor constant:8.0],
        [name.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [stateLabel.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [stateLabel.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:7.0],
        [stateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18.0],
        [stateLabel.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-15.0],

        [stockBadge.leadingAnchor constraintEqualToAnchor:imageShell.leadingAnchor],
        [stockBadge.heightAnchor constraintEqualToConstant:20.0],
        [stockBadge.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],
        [stockBadge.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],

        [priceLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [priceLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
        [priceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:stockBadge.trailingAnchor constant:12.0],

    ]];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    PPProviderMarketItem *item = [self displayedItems][ip.row];
    PPProviderMarketItemEditorViewController *vc = [[PPProviderMarketItemEditorViewController alloc] initWithItem:item];
    __weak typeof(self) ws = self;
    vc.onSave = ^{ [ws updateUI]; };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)menuTapped:(UIButton *)sender {
    NSArray<PPProviderMarketItem *> *displayedItems = [self displayedItems];
    if (sender.tag < 0 || sender.tag >= (NSInteger)displayedItems.count) { return; }
    [self presentActionsForItem:displayedItems[sender.tag] fromView:sender];
}

- (void)presentActionsForItem:(PPProviderMarketItem *)item fromView:(UIView *)sourceView {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.name message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = sourceView;
    popover.sourceRect = sourceView.bounds;

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Market_Stock") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showStockAlert:item];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Market_Offer") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showOfferAlert:item];
    }]];

    BOOL isVisible = item.showInAppMarket && !item.isArchived;
    NSString *visTitle = isVisible ? kLang(@"Market_HideFromMarket") : kLang(@"Market_ShowInMarket");
    [sheet addAction:[UIAlertAction actionWithTitle:visTitle style:isVisible ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self toggleVisibilityForItem:item];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleVisibilityForItem:(PPProviderMarketItem *)item {
    BOOL isVisible = item.showInAppMarket && !item.isArchived;
    if (isVisible) {
        __weak typeof(self) ws = self;
        [PPAlertHelper showConfirmationIn:self title:kLang(@"Market_HideFromMarket") subtitle:kLang(@"Market_HideConfirm") placeholder:nil
                           confirmButton:kLang(@"Confirm") cancelButton:kLang(@"Cancel") confirmBlock:^{
            [PPHUD showIndeterminateIn:ws.view title:kLang(@"Market_UpdatingVisibility") subtitle:nil];
            [[PPProviderMarketplaceManager sharedManager] archiveMarketItemWithID:item.itemID completion:^(BOOL ok, NSString *msg, NSError *err) {
                [PPHUD dismiss];
                if (!ok) { [PPAlertHelper showErrorIn:ws title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
                [PPHUD showSuccess:kLang(@"Market_ItemHidden")];
            }];
        } cancelBlock:nil];
    } else {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingVisibility") subtitle:nil];
        [[PPProviderMarketplaceManager sharedManager] publishMarketItemWithID:item.itemID completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_ItemShown")];
        }];
    }
}

- (void)showStockAlert:(PPProviderMarketItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Market_Stock") message:nil preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alert) wa = alert;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = kLang(@"Market_QuantityReq");
        tf.text = [NSString stringWithFormat:@"%ld", (long)item.quantity];
        tf.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSInteger qty = (NSInteger)wa.textFields.firstObject.text.integerValue;
        if (qty < 0) qty = 0;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingStock") subtitle:nil];
        [[PPProviderMarketplaceManager sharedManager] updateMarketStock:item.itemID quantity:qty completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_StockUpdated")];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showOfferAlert:(PPProviderMarketItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Market_Offer") message:nil preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alert) wa = alert;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = kLang(@"Market_DiscountPct");
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = kLang(@"Market_DiscountAmt");
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Market_SetOffer") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        double dp = wa.textFields.firstObject.text.doubleValue;
        double da = wa.textFields[1].text.doubleValue;
        BOOL ho = dp > 0 || da > 0;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingOffer") subtitle:nil];
        [[PPProviderMarketplaceManager sharedManager] updateMarketOffer:item.itemID discountPercent:dp discountAmount:da hasOffer:ho completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_OfferUpdated")];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Market_RemoveOffer") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingOffer") subtitle:nil];
        [[PPProviderMarketplaceManager sharedManager] updateMarketOffer:item.itemID discountPercent:0 discountAmount:0 hasOffer:NO completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_OfferRemoved")];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)archiveTapped:(UIButton *)sender {
    NSArray<PPProviderMarketItem *> *displayedItems = [self displayedItems];
    if (sender.tag < 0 || sender.tag >= (NSInteger)displayedItems.count) { return; }
    PPProviderMarketItem *item = displayedItems[sender.tag];
    __weak typeof(self) ws = self;
    [PPAlertHelper showConfirmationIn:self title:kLang(@"Market_ArchiveTitle") subtitle:kLang(@"Market_ArchiveConfirm") placeholder:nil
                       confirmButton:kLang(@"Confirm") cancelButton:kLang(@"Cancel") confirmBlock:^{
        [PPHUD showIndeterminateIn:ws.view title:kLang(@"Market_Archiving") subtitle:nil];
        [[PPProviderMarketplaceManager sharedManager] archiveMarketItemWithID:item.itemID completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:ws title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_Archived")];
        }];
    } cancelBlock:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.listener remove];
}

@end
