#import "PPFulfillmentListViewController.h"
#import "PPFulfillmentDetailViewController.h"
#import "PPFulfillmentModel.h"
#import "PPFulfillmentManager.h"
#import "PPFulfillmentCell.h"
#import "PPFirebaseCompat.h"
#import "PPProviderCompaniesBottomSearchBar.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static const CGFloat PPBottomSearchParkedInset = 16.0;

@interface PPFulfillmentListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *activeValueLabel;
@property (nonatomic, strong) UILabel *netValueLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, assign) NSUInteger listenerGeneration;
@property (nonatomic, copy) NSString *listenerUID;
@property (nonatomic, copy) NSArray<PPFulfillmentModel *> *fulfillments;
@property (nonatomic, copy) NSArray<PPFulfillmentModel *> *filteredFulfillments;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) PPProviderCompaniesBottomSearchBar *bottomSearchBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, strong) UIView *bottomSearchFadeView;
@property (nonatomic, strong) CAGradientLayer *bottomSearchFadeLayer;
@property (nonatomic, strong) UIControl *keyboardDismissOverlay;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, strong) UIStackView *headerBody;
@property (nonatomic, strong) UIStackView *scopeStack;
@property (nonatomic, strong) UILabel *queueStateLabel;
@property (nonatomic, strong) UIButton *queueRetryButton;
@property (nonatomic, strong) UIButton *showAllButton;
@property (nonatomic, assign) NSInteger selectedScope;
@property (nonatomic, assign) BOOL queueFromCache;
@property (nonatomic, strong) NSError *queueError;
@property (nonatomic, strong) FIRAuthStateDidChangeListenerHandle authListener;
@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@end

@implementation PPFulfillmentListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.hasLoaded = NO;
    self.fulfillments = @[];
    self.filteredFulfillments = @[];
    self.searchQuery = @"";

    [self buildHeader];
    [self buildTableView];
    [self buildEmptyState];
    [self buildLoadingState];
    [self buildBottomSearchBar];
    [self startListening];
    __weak typeof(self) weakSelf = self;
    self.authListener = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || [self.listenerUID isEqualToString:user.uid ?: @""]) return;
        self.fulfillments = @[];
        self.filteredFulfillments = @[];
        self.hasLoaded = NO;
        self.queueError = nil;
        self.queueFromCache = NO;
        [self updateUIAnimated:NO];
        [self startListening];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
    self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Fulfillment_Title") showBack:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.bottomSearchBar.hidden && !UIAccessibilityIsReduceMotionEnabled()) [self.bottomSearchBar animateInIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; }

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bottomSearchFadeLayer.frame = self.bottomSearchFadeView.bounds;
    BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) || CGRectGetWidth(self.view.bounds) < 375;
    self.scopeStack.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.scopeStack.distribution = vertical ? UIStackViewDistributionFill : UIStackViewDistributionFillEqually;
    [self fitQueueHeader];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateBottomSearchFadeStyle];
    [self.bottomSearchBar applyCurrentTheme];
    [self updateScopeButtons];
    [self.view setNeedsLayout];
    [self.tableView reloadData];
}

#pragma mark - View Building

- (void)buildHeader {
    self.headerView = [[UIView alloc] init];
    self.headerBody = [[UIStackView alloc] init];
    self.headerBody.axis = UILayoutConstraintAxisVertical;
    self.headerBody.spacing = 12;
    self.headerBody.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.headerBody.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.headerBody];
    self.headlineLabel = [self labelWithFont:[Styling fontBold:27] color:[UIColor ppTextPrimary] lines:0];
    self.headlineLabel.text = kLang(@"ProFulfillment_QueueTitle");
    self.headlineLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    self.subtitleLabel = [self labelWithFont:[Styling fontRegular:15] color:[UIColor ppTextSecondary] lines:0];
    self.subtitleLabel.text = kLang(@"ProFulfillment_QueueSubtitle");
    self.activeValueLabel = [self labelWithFont:[Styling fontBold:16] color:[UIColor ppTextPrimary] lines:0];
    self.netValueLabel = [self labelWithFont:[Styling fontRegular:14] color:[UIColor ppTextSecondary] lines:0];
    self.queueStateLabel = [self labelWithFont:[Styling fontMedium:14] color:[UIColor ppTextSecondary] lines:0];
    self.queueStateLabel.text = kLang(@"Fulfillment_Loading");
    self.queueRetryButton = [self queueButton:kLang(@"ProFulfillment_Refresh") selector:@selector(retryQueue:)];
    self.queueRetryButton.hidden = YES;
    self.scopeStack = [[UIStackView alloc] init];
    self.scopeStack.spacing = 8;
    self.scopeStack.semanticContentAttribute = self.headerBody.semanticContentAttribute;
    NSArray *keys = @[@"ProFulfillment_NeedsAction", @"Fulfillment_Active", @"ProFulfillment_AllOrders"];
    for (NSUInteger i = 0; i < keys.count; i++) {
        UIButton *button = [self queueButton:kLang(keys[i]) selector:@selector(scopeTapped:)];
        button.tag = i;
        button.accessibilityIdentifier = [NSString stringWithFormat:@"fulfillment.scope.%lu", (unsigned long)i];
        [self.scopeStack addArrangedSubview:button];
    }
    for (UIView *view in @[self.headlineLabel, self.subtitleLabel, self.activeValueLabel, self.netValueLabel, self.queueStateLabel, self.queueRetryButton, self.scopeStack]) [self.headerBody addArrangedSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [self.headerBody.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:20],
        [self.headerBody.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-20],
        [self.headerBody.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:18],
        [self.headerBody.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-12],
    ]];
    [self updateScopeButtons];
}

- (UIButton *)queueButton:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout] scaledFontForFont:[Styling fontBold:15]];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    button.layer.cornerRadius = 14;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)updateScopeButtons {
    for (UIButton *button in self.scopeStack.arrangedSubviews) {
        BOOL selected = button.tag == self.selectedScope;
        button.selected = selected;
        button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        button.backgroundColor = selected ? [UIColor ppPrimary] : [UIColor ppSurface];
        [button setTitleColor:selected ? UIColor.whiteColor : [UIColor ppTextPrimary] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateSelected];
    }
}

- (void)scopeTapped:(UIButton *)sender {
    self.selectedScope = sender.tag;
    [self updateScopeButtons];
    [self updateUIAnimated:NO];
}

- (void)showAllOrders:(UIButton *)sender {
    self.selectedScope = 2;
    [self updateScopeButtons];
    [self updateUIAnimated:NO];
}

- (void)retryQueue:(UIButton *)sender { [self startListening]; }

- (void)fitQueueHeader {
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0) return;
    CGSize size = [self.headerView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                              withHorizontalFittingPriority:UILayoutPriorityRequired
                                    verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    if (fabs(CGRectGetHeight(self.headerView.frame) - size.height) > 0.5 || fabs(CGRectGetWidth(self.headerView.frame) - width) > 0.5) {
        self.headerView.frame = CGRectMake(0, 0, width, ceil(size.height));
        self.tableView.tableHeaderView = self.headerView;
    }
}

- (void)buildTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 126, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 126, 0);
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = [PPFulfillmentCell preferredHeight];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:PPFulfillmentCell.class forCellReuseIdentifier:PPFulfillmentCell.reuseIdentifier];
    self.tableView.tableHeaderView = self.headerView;
    [self.view addSubview:self.tableView];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshPulled:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)buildLoadingState {
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color = AppPrimaryClr;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];

    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-24],
    ]];
}

- (void)buildBottomSearchBar {
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

    self.bottomSearchBar = [[PPProviderCompaniesBottomSearchBar alloc] initWithPlaceholder:kLang(@"Fulfillment_BottomSearch_Placeholder")];
    self.bottomSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchBar.hidden = YES;
    __weak typeof(self) weakSelf = self;
    self.bottomSearchBar.textDidChangeHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUIAnimated:NO];
    };
    self.bottomSearchBar.submitHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUIAnimated:NO];
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
    UIColor *base = AppBackgroundClr;
    self.bottomSearchFadeLayer.colors = @[
        (id)[base colorWithAlphaComponent:0.0].CGColor,
        (id)[base colorWithAlphaComponent:0.78].CGColor,
        (id)[base colorWithAlphaComponent:1.0].CGColor
    ];
}

- (void)buildEmptyState {
    UIStackView *empty = [[UIStackView alloc] init];
    empty.axis = UILayoutConstraintAxisVertical;
    empty.spacing = 10;
    empty.layoutMargins = UIEdgeInsetsMake(24, 16, 24, 16);
    empty.layoutMarginsRelativeArrangement = YES;
    empty.backgroundColor = [UIColor ppSurface];
    empty.layer.cornerRadius = PPCornerCard;
    self.emptyContainer = empty;
    self.emptyTitleLabel = [self labelWithFont:[Styling fontBold:21] color:[UIColor ppTextPrimary] lines:0];
    self.emptySubtitleLabel = [self labelWithFont:[Styling fontRegular:15] color:[UIColor ppTextSecondary] lines:0];
    self.showAllButton = [self queueButton:kLang(@"ProFulfillment_AllOrders") selector:@selector(showAllOrders:)];
    [empty addArrangedSubview:self.emptyTitleLabel];
    [empty addArrangedSubview:self.emptySubtitleLabel];
    [empty addArrangedSubview:self.showAllButton];
    [self.headerBody addArrangedSubview:empty];
    empty.hidden = YES;
}

#pragma mark - UI Helpers

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:font];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (NSString *)moneyString:(double)value currency:(NSString *)currency {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:[Language isRTL] ? @"ar_QA" : @"en_QA"];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = currency;
    return [formatter stringFromNumber:@(value)] ?: @"—";
}

#pragma mark - Data

- (void)startListening {
    [self.listener remove];
    self.listener = nil;
    NSUInteger generation = ++self.listenerGeneration;
    NSString *uid = [[FIRAuth auth].currentUser.uid ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.listenerUID = uid;
    self.queueError = nil;
    self.queueStateLabel.text = kLang(@"Fulfillment_Loading");
    self.queueRetryButton.hidden = YES;
    if (uid.length == 0) {
        self.fulfillments = @[];
        self.hasLoaded = YES;
        self.queueError = [NSError errorWithDomain:@"PPFulfillmentManager" code:401 userInfo:nil];
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        [self updateUIAnimated:NO];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.spinner startAnimating];
    self.listener = [[PPFulfillmentManager sharedManager] observeFulfillmentsForOwnerID:uid stateHandler:^(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error, BOOL fromCache) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.listenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || ![self.listenerUID isEqualToString:uid]) {
            self.fulfillments = @[];
            [self.spinner stopAnimating];
            [self.refreshControl endRefreshing];
            [self updateUIAnimated:NO];
            self.tableView.tableFooterView = nil;
            return;
        }
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        self.hasLoaded = YES;
        self.queueFromCache = fromCache;
        self.queueError = error;
        if (error) {
            self.fulfillments = fulfillments ?: @[];
            [self updateUIAnimated:YES];
            [self updatePagingFooter];
            [PPToast toast:kLang(@"Fulfillment_LoadError") style:PPToastStyleError haptic:NO duration:3.0];
            return;
        }
        self.fulfillments = fulfillments ?: @[];
        [self updateUIAnimated:YES];
        [self updatePagingFooter];
    }];
}

- (void)refreshPulled:(UIRefreshControl *)refreshControl {
    [self startListening];
}

- (void)updatePagingFooter {
    if (![[PPFulfillmentManager sharedManager] canLoadMoreFulfillmentsForListener:self.listener]) {
        self.tableView.tableFooterView = nil;
        return;
    }
    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    more.frame = CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 52);
    [more setTitle:kLang(@"Fulfillment_LoadMore") forState:UIControlStateNormal];
    more.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [more addTarget:self action:@selector(loadMoreFulfillments:) forControlEvents:UIControlEventTouchUpInside];
    self.tableView.tableFooterView = more;
}

- (void)loadMoreFulfillments:(UIButton *)sender {
    sender.enabled = NO;
    [[PPFulfillmentManager sharedManager] loadMoreFulfillmentsForListener:self.listener];
}

- (void)updateUIAnimated:(BOOL)animated {
    [self refreshFilteredFulfillments];
    [self updateSummary];
    BOOL sourceEmpty = self.fulfillments.count == 0;
    BOOL displayEmpty = self.filteredFulfillments.count == 0;
    self.emptyContainer.hidden = !self.hasLoaded || !displayEmpty;
    self.tableView.hidden = NO; // Header, filters and recovery remain scrollable even with no rows.
    self.bottomSearchBar.hidden = !self.hasLoaded || sourceEmpty;
    self.bottomSearchFadeView.hidden = self.bottomSearchBar.hidden || self.bottomSearchBar.isKeyboardEditing;
    [self.bottomSearchBar setResultCount:self.filteredFulfillments.count totalCount:self.fulfillments.count];
    [self updateEmptyStateForSearch:self.hasActiveSearchQuery sourceEmpty:sourceEmpty displayEmpty:displayEmpty];
    self.queueStateLabel.text = !self.hasLoaded ? kLang(@"Fulfillment_Loading") : (self.queueError ? kLang(@"ProFulfillment_QueueError") : (self.queueFromCache ? kLang(@"ProFulfillment_CachedQueue") : kLang(@"ProFulfillment_LiveQueue")));
    self.queueRetryButton.hidden = !(self.queueError || self.queueFromCache || self.listenerUID.length == 0);
    [self.tableView reloadData];
    [self fitQueueHeader];
}

- (void)updateSummary {
    NSInteger active = 0;
    BOOL missingMoney = NO;
    NSMutableDictionary<NSString *, NSNumber *> *totals = [NSMutableDictionary dictionary];
    for (PPFulfillmentModel *model in self.fulfillments) {
        if (!model.isTerminal) active++;
        if (model.hasMoneyProjection) totals[model.currency] = @([totals[model.currency] doubleValue] + model.providerNet);
        else missingMoney = YES;
    }
    self.activeValueLabel.text = [NSString localizedStringWithFormat:kLang(@"ProFulfillment_ActiveCount"), (long)active];
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSString *currency in [[totals allKeys] sortedArrayUsingSelector:@selector(compare:)]) [values addObject:[self moneyString:totals[currency].doubleValue currency:currency]];
    NSString *snapshot = values.count ? [values componentsJoinedByString:@" · "] : kLang(@"ProFulfillment_MoneyUnavailable");
    self.netValueLabel.text = [NSString stringWithFormat:kLang(@"ProFulfillment_QueueSnapshot"), snapshot];
    if (missingMoney && values.count) self.netValueLabel.text = [self.netValueLabel.text stringByAppendingFormat:@"\n%@", kLang(@"ProFulfillment_PartialMoney")];
}

#pragma mark - Search

- (NSArray<PPFulfillmentModel *> *)displayedFulfillments {
    return self.filteredFulfillments ?: @[];
}

- (BOOL)hasActiveSearchQuery {
    return [self trimmedSearchQuery].length > 0;
}

- (NSString *)trimmedSearchQuery {
    return [self.searchQuery ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)refreshFilteredFulfillments {
    NSString *query = [self trimmedSearchQuery];
    NSMutableArray<PPFulfillmentModel *> *matches = [NSMutableArray array];
    for (PPFulfillmentModel *model in self.fulfillments ?: @[]) {
        if (self.selectedScope == 0 && !model.requiresProviderAction) continue;
        if (self.selectedScope == 1 && model.isTerminal) continue;
        if (query.length && [[self searchTextForFulfillment:model] rangeOfString:query options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location == NSNotFound) continue;
        [matches addObject:model];
    }
    self.filteredFulfillments = matches.copy;
}

- (NSString *)searchTextForFulfillment:(PPFulfillmentModel *)model {
    if (!model) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [self appendSearchObject:model.fulfillmentID toParts:parts];
    [self appendSearchObject:model.parentOrderId toParts:parts];
    [self appendSearchObject:model.parentOrderNumber toParts:parts];
    [self appendSearchObject:model.parentUserId toParts:parts];
    [self appendSearchObject:model.ownerID toParts:parts];
    [self appendSearchObject:model.ownerType toParts:parts];
    [self appendSearchObject:model.fulfillmentMode toParts:parts];
    [self appendSearchObject:model.status toParts:parts];
    [self appendSearchObject:[model statusDisplayName] toParts:parts];
    [self appendSearchObject:model.currency toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%ld", (long)model.itemCount] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", model.subtotal] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", model.providerNet] toParts:parts];
    [self appendSearchObject:model.items toParts:parts];
    [self appendSearchObject:model.events toParts:parts];
    return [parts componentsJoinedByString:@" "];
}

- (void)appendSearchObject:(id)object toParts:(NSMutableArray<NSString *> *)parts {
    if (!object || object == (id)[NSNull null]) return;
    if ([object isKindOfClass:NSString.class]) {
        NSString *value = [(NSString *)object stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) [parts addObject:value];
        return;
    }
    if ([object isKindOfClass:NSNumber.class]) {
        [parts addObject:[(NSNumber *)object stringValue]];
        return;
    }
    if ([object isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)object) {
            [self appendSearchObject:value toParts:parts];
        }
        return;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id value in [(NSDictionary *)object allValues]) {
            [self appendSearchObject:value toParts:parts];
        }
    }
}

- (void)updateEmptyStateForSearch:(BOOL)hasSearch sourceEmpty:(BOOL)sourceEmpty displayEmpty:(BOOL)displayEmpty {
    self.showAllButton.hidden = sourceEmpty || self.selectedScope == 2 || hasSearch;
    if (self.queueError && sourceEmpty) {
        self.emptyTitleLabel.text = kLang(@"Fulfillment_LoadError");
        self.emptySubtitleLabel.text = kLang(@"ProFulfillment_QueueError");
    } else if (hasSearch && displayEmpty) {
        self.emptyTitleLabel.text = kLang(@"Fulfillment_SearchEmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Fulfillment_SearchEmptySubtitle");
    } else if (!sourceEmpty && self.selectedScope == 0) {
        self.emptyTitleLabel.text = kLang(@"ProFulfillment_CaughtUp");
        self.emptySubtitleLabel.text = kLang(@"ProFulfillment_CaughtUpDetail");
    } else {
        self.emptyTitleLabel.text = kLang(@"Fulfillment_EmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Fulfillment_EmptySubtitle");
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
        [self.keyboardDismissOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)dismissBottomSearchKeyboard {
    [self.bottomSearchBar dismissKeyboard];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self displayedFulfillments].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPFulfillmentCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPFulfillmentCell reuseIdentifier] forIndexPath:indexPath];
    [cell configureWithModel:[self displayedFulfillments][indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPFulfillmentModel *model = [self displayedFulfillments][indexPath.row];
    PPFulfillmentDetailViewController *vc = [[PPFulfillmentDetailViewController alloc] initWithModel:model];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (self.authListener) [[FIRAuth auth] removeAuthStateDidChangeListener:self.authListener];
    self.listenerGeneration += 1;
    [self.listener remove];
}

@end
