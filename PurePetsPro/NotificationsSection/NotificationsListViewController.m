// NotificationsListViewController.m
#import "NotificationsListViewController.h"
#import "PPToast.h"
#import "NotificationManager.h"   // replace with your manager
#import "NotificationModel.h"     // your notification model
#import "NotificationCell.h"
#import "PPFirebaseCompat.h"
#import "Styling.h"
#import "Language.h"
#import "PPS.h"
#import "PPProInAppNotificationPresenter.h"

@interface NotificationsListViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NotificationModel *> *allNotifications;
@property (nonatomic, strong) NSArray<NotificationModel *> *filteredNotifications;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) PPS *searchView;              // the PPS instance
@property (nonatomic, strong) UIView *searchContainer;      // wrapper for header
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UILabel *unreadBadgeLabel;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIView *topBackgroundGlowView;
@property (nonatomic, strong) UIView *bottomBackgroundGlowView;

@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL didPlayEntrance;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> inboxListener;
@property (nonatomic, copy, nullable) NSDictionary *pendingRoutePayload;
@property (nonatomic, assign) BOOL didLogMissingPendingRouteMatch;
@property (nonatomic, strong, nullable) NSError *inboxError;
@property (nonatomic, copy, nullable) NSString *lastInboxErrorSignature;
@end

static NSString *PPNotificationsRouteTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSString *PPProAuthenticatedNotificationUID(void)
{
    return PPNotificationsRouteTrimmedString([FIRAuth auth].currentUser.uid);
}

static BOOL PPNotificationsRouteStringsEqual(id lhs, id rhs)
{
    NSString *left = [PPNotificationsRouteTrimmedString(lhs) lowercaseString];
    NSString *right = [PPNotificationsRouteTrimmedString(rhs) lowercaseString];
    return left.length > 0 && right.length > 0 && [left isEqualToString:right];
}

static NSString *PPNotificationsInboxErrorSignature(NSError *error)
{
    if (![error isKindOfClass:NSError.class]) return @"";
    return [NSString stringWithFormat:@"%@:%ld", error.domain ?: @"", (long)error.code];
}

@implementation NotificationsListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.uid = PPProAuthenticatedNotificationUID();

    self.view.backgroundColor = AppBackgroundClr;
    self.allNotifications = @[];
    self.filteredNotifications = @[];
    self.isLoading = NO;

    [self pp_setupBackgroundGlows];
    [self setupTableView];
    [self setupSearchView];
    [self setupEmptyStateView];
    [self pp_updateHeaderMetrics];
    [self pp_updateEmptyState];
    [self fetchNotificationsShowToast:YES];
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // globe  // plus
    [self  pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"NotificationsTitle") showBack:YES];
    [self pp_updateHeaderMetrics];

    NSString *currentUID = PPProAuthenticatedNotificationUID();
    if (![self.uid isEqualToString:currentUID] ||
        (currentUID.length > 0 && !self.inboxListener)) {
        [self.inboxListener remove];
        self.inboxListener = nil;
        self.uid = currentUID;
        self.allNotifications = @[];
        self.filteredNotifications = @[];
        self.isLoading = NO;
        [self reloadTableAnimated:NO];
        [self fetchNotificationsShowToast:NO];
    }

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_playEntranceIfNeeded];
    [self pp_consumePendingRoutePayloadIfPossible];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateTableHeaderLayout];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_updateBackgroundGlowStyle];
        }
    }
}

#pragma mark - Setup UI

- (UIView *)pp_backgroundGlowView {
    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.userInteractionEnabled = NO;
    glow.layer.cornerRadius = 120.0;
    glow.layer.cornerCurve = kCACornerCurveContinuous;
    glow.layer.shadowOffset = CGSizeZero;
    return glow;
}

- (void)pp_setupBackgroundGlows {
    self.topBackgroundGlowView = [self pp_backgroundGlowView];
    self.bottomBackgroundGlowView = [self pp_backgroundGlowView];
    [self.view addSubview:self.topBackgroundGlowView];
    [self.view addSubview:self.bottomBackgroundGlowView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topBackgroundGlowView.widthAnchor constraintEqualToConstant:240.0],
        [self.topBackgroundGlowView.heightAnchor constraintEqualToConstant:240.0],
        [self.topBackgroundGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-118.0],
        [self.topBackgroundGlowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-74.0],

        [self.bottomBackgroundGlowView.widthAnchor constraintEqualToConstant:270.0],
        [self.bottomBackgroundGlowView.heightAnchor constraintEqualToConstant:270.0],
        [self.bottomBackgroundGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:118.0],
        [self.bottomBackgroundGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],
    ]];

    [self pp_updateBackgroundGlowStyle];
}

- (void)pp_updateBackgroundGlowStyle {
    UIColor *accent = AppPrimaryClr;
    UIColor *support = SeconderyTextClr;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    self.topBackgroundGlowView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.050 : 0.075];
    self.topBackgroundGlowView.layer.shadowColor = accent.CGColor;
    self.topBackgroundGlowView.layer.shadowOpacity = isDark ? 0.30 : 0.16;
    self.topBackgroundGlowView.layer.shadowRadius = isDark ? 58.0 : 48.0;

    self.bottomBackgroundGlowView.backgroundColor = [support colorWithAlphaComponent:isDark ? 0.045 : 0.060];
    self.bottomBackgroundGlowView.layer.shadowColor = support.CGColor;
    self.bottomBackgroundGlowView.layer.shadowOpacity = isDark ? 0.22 : 0.12;
    self.bottomBackgroundGlowView.layer.shadowRadius = isDark ? 56.0 : 46.0;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 104.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 24.0, 0);
    [self.tableView registerClass:NotificationCell.class forCellReuseIdentifier:[NotificationCell reuseId]];

    // refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"PullToRefresh")];
    [self.refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl.tintColor = AppPrimaryClr;
    if (@available(iOS 10.0, *)) {
        self.tableView.refreshControl = self.refreshControl;
    } else {
        [self.tableView addSubview:self.refreshControl];
    }

    [self.view addSubview:self.tableView];

    // constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.tableView.tableHeaderView = nil;
}



- (void)setupSearchView {
    CGFloat searchHeight = 52.0;
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 214.0)];
    self.searchContainer.backgroundColor = UIColor.clearColor;
    self.searchContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    PPHero *heroSurface = [[PPHero alloc] init];
    heroSurface.translatesAutoresizingMaskIntoConstraints = NO;
    [self.searchContainer addSubview:heroSurface];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.layer.cornerRadius = 24.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [heroSurface addSubview:iconShell];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.badge.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.font = [Styling fontBold:30];
    self.headerTitleLabel.textColor = PrimaryTextClr;
    self.headerTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.headerTitleLabel.numberOfLines = 1;

    self.headerSubtitleLabel = [[UILabel alloc] init];
    self.headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerSubtitleLabel.font = [Styling fontMedium:13];
    self.headerSubtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.86];
    self.headerSubtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.headerSubtitleLabel.numberOfLines = 2;

    UIStackView *copyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.headerTitleLabel,
        self.headerSubtitleLabel
    ]];
    copyStack.translatesAutoresizingMaskIntoConstraints = NO;
    copyStack.axis = UILayoutConstraintAxisVertical;
    copyStack.alignment = UIStackViewAlignmentFill;
    copyStack.spacing = 5.0;
    copyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [heroSurface addSubview:copyStack];

    UIView *badgeView = [[UIView alloc] init];
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    badgeView.layer.cornerRadius = 16.0;
    badgeView.layer.cornerCurve = kCACornerCurveContinuous;
    [heroSurface addSubview:badgeView];

    self.unreadBadgeLabel = [[UILabel alloc] init];
    self.unreadBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.unreadBadgeLabel.font = [Styling fontBold:11];
    self.unreadBadgeLabel.textColor = AppPrimaryClr;
    self.unreadBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [badgeView addSubview:self.unreadBadgeLabel];

    // PPS instance
    self.searchView = [[PPS alloc] initWithFrame:CGRectZero];
    self.searchView.translatesAutoresizingMaskIntoConstraints = NO;

    // Visual & behavior config (best practices)
    self.searchView.cornerRadius = searchHeight/2.0;
    self.searchView.blurEnabled = NO;
    self.searchView.shadowEnabled = NO;
    self.searchView.debounceInterval = 0.16;
    self.searchView.fuzzyEnabled = YES;
    self.searchView.caseInsensitive = YES;            // typical user expectation
    self.searchView.diacriticsInsensitive = YES;      // Arabic normalized already in PPS
    self.searchView.minRelevanceScore = 0.45;         // tune for recall/precision
    self.searchView.maxResults = 200;
    self.searchView.delegate = self;
    self.searchView.backgroundColor = AppForgroundColr;
    self.searchView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.searchView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    self.searchView.clipsToBounds = YES;

    self.searchView.showsPrimaryButton = NO;
    self.searchView.showsSecondaryButton = NO;

    // Localization & semantic
    self.searchView.textField.placeholder = kLang(@"SearchHere");
    self.searchView.textField.textAlignment = [Language alignmentForCurrentLanguage];
    self.searchView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self.searchContainer addSubview:self.searchView];

    // layout inside container
    [NSLayoutConstraint activateConstraints:@[
        [heroSurface.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:16.0],
        [heroSurface.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:16.0],
        [heroSurface.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-16.0],
        [heroSurface.heightAnchor constraintGreaterThanOrEqualToConstant:112.0],

        [iconShell.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-20.0],
        [iconShell.centerYAnchor constraintEqualToAnchor:heroSurface.centerYAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:48.0],
        [iconShell.heightAnchor constraintEqualToConstant:48.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:21.0],
        [iconView.heightAnchor constraintEqualToConstant:21.0],

        [copyStack.topAnchor constraintEqualToAnchor:heroSurface.topAnchor constant:36.0],
        [copyStack.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:22.0],
        [copyStack.trailingAnchor constraintLessThanOrEqualToAnchor:iconShell.leadingAnchor constant:-16.0],

        [badgeView.topAnchor constraintEqualToAnchor:copyStack.bottomAnchor constant:12.0],
        [badgeView.leadingAnchor constraintEqualToAnchor:copyStack.leadingAnchor],
        [badgeView.heightAnchor constraintEqualToConstant:32.0],
        [badgeView.bottomAnchor constraintLessThanOrEqualToAnchor:heroSurface.bottomAnchor constant:-18.0],

        [self.unreadBadgeLabel.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:14.0],
        [self.unreadBadgeLabel.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-14.0],
        [self.unreadBadgeLabel.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor],

        [self.searchView.topAnchor constraintEqualToAnchor:heroSurface.bottomAnchor constant:14.0],
        [self.searchView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:16.0],
        [self.searchView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-16.0],
        [self.searchView.heightAnchor constraintEqualToConstant:searchHeight],
        [self.searchView.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:-12.0]
    ]];

    // assign as tableHeaderView (works nicely with inset grouped)
    self.tableView.tableHeaderView = self.searchContainer;

    // IMPORTANT: set search items now (empty array until we fetch)
    [self.searchView setSearchItems:@[] stringProvider:^NSString * _Nonnull(id item) {
        // safe provider that returns a searchable string per notification (title + body)
        if (![item isKindOfClass:NotificationModel.class]) return @"";
        NotificationModel *m = (NotificationModel *)item;
        NSString *ttl = [m pp_localizedTitleForCurrentLanguage];
        NSString *bdy = [m pp_localizedBodyForCurrentLanguage];
        // return combined string (use lowercased; PPS normalizes too)
        NSString *combined = [NSString stringWithFormat:@"%@ %@", ttl, bdy];
        return combined;
    }];
}

- (void)setupEmptyStateView {
    UIView *emptyView = [[UIView alloc] init];
    emptyView.backgroundColor = UIColor.clearColor;
    emptyView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    iconShell.layer.cornerRadius = 34.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [emptyView addSubview:iconShell];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.slash.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.82];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    self.emptyTitleLabel = [[UILabel alloc] init];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = [Styling fontBold:20];
    self.emptyTitleLabel.textColor = PrimaryTextClr;
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.numberOfLines = 2;

    self.emptySubtitleLabel = [[UILabel alloc] init];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = [Styling fontMedium:13];
    self.emptySubtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.82];
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 3;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        iconShell,
        self.emptyTitleLabel,
        self.emptySubtitleLabel
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 12.0;
    [emptyView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [iconShell.widthAnchor constraintEqualToConstant:68.0],
        [iconShell.heightAnchor constraintEqualToConstant:68.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:27.0],
        [iconView.heightAnchor constraintEqualToConstant:27.0],
        [stack.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:54.0],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:emptyView.leadingAnchor constant:36.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:emptyView.trailingAnchor constant:-36.0],
        [self.emptySubtitleLabel.widthAnchor constraintLessThanOrEqualToConstant:280.0],
    ]];

    self.emptyStateView = emptyView;
    self.tableView.backgroundView = emptyView;
}

- (void)pp_updateTableHeaderLayout {
    if (!self.searchContainer || !self.tableView.tableHeaderView) return;

    CGFloat width = self.tableView.bounds.size.width;
    if (width <= 0) return;

    CGSize targetSize = CGSizeMake(width, UILayoutFittingCompressedSize.height);
    CGFloat height = [self.searchContainer systemLayoutSizeFittingSize:targetSize
                                         withHorizontalFittingPriority:UILayoutPriorityRequired
                                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height + 18.0;
    height = MAX(height, 214.0);

    CGRect frame = self.searchContainer.frame;
    if (fabs(frame.size.width - width) > 0.5 || fabs(frame.size.height - height) > 0.5) {
        frame.size = CGSizeMake(width, height);
        self.searchContainer.frame = frame;
        self.tableView.tableHeaderView = self.searchContainer;
    }
}

- (void)pp_updateHeaderMetrics {
    NSUInteger unreadCount = 0;
    for (NotificationModel *item in self.allNotifications) {
        if (![item isKindOfClass:NotificationModel.class]) continue;
        if (!item.isRead) unreadCount += 1;
    }

    self.headerTitleLabel.text = kLang(@"Inbox");
    self.headerSubtitleLabel.text = kLang(@"NotificationsInboxSubtitle");
    if (unreadCount > 0) {
        self.unreadBadgeLabel.text = [NSString stringWithFormat:kLang(@"NotificationsUnreadFormat"), (unsigned long)unreadCount];
    } else {
        self.unreadBadgeLabel.text = kLang(@"NotificationsAllRead");
    }
}

- (void)pp_updateEmptyState {
    BOOL isSearching = self.searchView.textField.text.length > 0;
    BOOL shouldShowEmpty = (self.filteredNotifications.count == 0);
    self.emptyStateView.hidden = !shouldShowEmpty;

    if (self.isLoading && self.allNotifications.count == 0) {
        self.emptyTitleLabel.text = kLang(@"Loading");
        self.emptySubtitleLabel.text = kLang(@"NotificationsInboxSubtitle");
        return;
    }

    if (self.inboxError && self.allNotifications.count == 0) {
        self.emptyTitleLabel.text = kLang(@"FetchError");
        self.emptySubtitleLabel.text = kLang(@"PullToRefresh");
        return;
    }

    self.emptyTitleLabel.text = isSearching ? kLang(@"NotificationsNoSearchResults") : kLang(@"NoNotifications");
    self.emptySubtitleLabel.text = isSearching ? kLang(@"NotificationsNoSearchSubtitle") : kLang(@"NotificationsEmptySubtitle");
}

- (void)pp_playEntranceIfNeeded {
    if (self.didPlayEntrance || UIAccessibilityIsReduceMotionEnabled()) return;
    self.didPlayEntrance = YES;

    self.searchContainer.alpha = 0.0;
    self.searchContainer.transform = CGAffineTransformMakeTranslation(0, 14.0);
    [UIView animateWithDuration:0.48
                          delay:0.02
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.searchContainer.alpha = 1.0;
        self.searchContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Actions (filter/scan stubs)

- (void)onFilterTapped {
    DLog(@"Filter tapped");
    // show filter UI — left as an exercise (present modal, action sheet, etc.)
    [PPToast toast:kLang(@"PPS_Filter") style:PPToastStyleInfo haptic:NO duration:1.0 position:PPToastPositionBottom inView:self.view];
}

- (void)onScanTapped {
    DLog(@"Scan tapped");
    [PPToast toast:kLang(@"PPS_Scan") style:PPToastStyleInfo haptic:NO duration:1.0 position:PPToastPositionBottom inView:self.view];
}

#pragma mark - Fetch

- (void)onRefresh {
    [self fetchNotificationsShowToast:NO];
}

- (void)fetchNotificationsShowToast:(BOOL)showToast {
    if (self.isLoading) return;
    self.isLoading = YES;
    DLog(@"Fetching notifications...");
    [self pp_updateEmptyState];

    if (showToast) {
        [PPToast toast:kLang(@"Loading") style:PPToastStyleInfo haptic:NO duration:1.2 position:PPToastPositionBottom inView:self.view];
    }

    NSString *currentUID = PPProAuthenticatedNotificationUID();
    if (currentUID.length == 0) {
        self.isLoading = NO;
        [self.refreshControl endRefreshing];
        self.allNotifications = @[];
        self.filteredNotifications = @[];
        [self reloadTableAnimated:NO];
        return;
    }
    self.uid = currentUID;

    __weak typeof(self) weakSelf = self;
    __block BOOL shouldToastLoaded = showToast;
    // Live listen

    [self.inboxListener remove];
    self.inboxListener = [[NotificationManager shared] observeInboxForUser:self.uid stateHandler:^(NSArray<NotificationModel *> *items, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isLoading = NO;
        if (self.refreshControl.isRefreshing) [self.refreshControl endRefreshing];

        self.inboxError = error;
        if (error) {
            NSString *signature = PPNotificationsInboxErrorSignature(error);
            BOOL shouldSurfaceError = signature.length > 0 && ![signature isEqualToString:self.lastInboxErrorSignature];
            self.lastInboxErrorSignature = signature;
            if (shouldSurfaceError) {
                DLog(@"[NotificationsV2] Pro inbox listener failed | domain=%@ code=%ld", error.domain ?: @"unknown", (long)error.code);
                [PPToast toast:kLang(@"FetchError") style:PPToastStyleError haptic:YES duration:2.0 position:PPToastPositionBottom inView:self.view];
            }
        } else {
            self.lastInboxErrorSignature = nil;
        }

        // A degraded listener may still have confirmed items. Keep them visible
        // instead of replacing the inbox with an indistinguishable empty state.
        if (!error || items.count > 0 || self.allNotifications.count == 0) {
            self.allNotifications = items ?: @[];
            if (self.searchView.textField.text.length == 0) {
                self.filteredNotifications = self.allNotifications;
            }
        }
        // update PPS search index with items
        [self.searchView setSearchItems:self.allNotifications stringProvider:^NSString * _Nonnull(id item) {
            if (![item isKindOfClass:NotificationModel.class]) return @"";
            NotificationModel *m = (NotificationModel *)item;
            NSString *combined = [NSString stringWithFormat:@"%@ %@", [m pp_localizedTitleForCurrentLanguage], [m pp_localizedBodyForCurrentLanguage]];
            return combined;
        }];

        [self pp_updateHeaderMetrics];
        [self reloadTableAnimated:YES];
        [self pp_consumePendingRoutePayloadIfPossible];
        if (!error && shouldToastLoaded) {
            [PPToast toast:kLang(@"NotificationsLoaded") style:PPToastStyleSuccess haptic:NO duration:1.0 position:PPToastPositionBottom inView:self.view];
            shouldToastLoaded = NO;
        }
   
        
        
    }];
    /*
     
     [[NotificationManager shared] fetchAllNotificationsWithCompletion:^(NSArray<NotificationModel *> * _Nullable notifications, NSError * _Nullable error) {
         dispatch_async(dispatch_get_main_queue(), ^{
             __strong typeof(weakSelf) self = weakSelf;
             self.isLoading = NO;
             if (self.refreshControl.isRefreshing) [self.refreshControl endRefreshing];

             if (error) {
                 DLog(@"Failed fetching notifications: %@", error.localizedDescription);
                 [PPToast toast:kLang(@"FetchError") style:PPToastStyleError haptic:YES duration:2.0 position:PPToastPositionBottom inView:self.view];
                 return;
             }

             self.allNotifications = notifications ?: @[];
             self.filteredNotifications = self.allNotifications;

             // update PPS search index with items
             [self.searchView setSearchItems:self.allNotifications stringProvider:^NSString * _Nonnull(id item) {
                 if (![item isKindOfClass:NotificationModel.class]) return @"";
                 NotificationModel *m = (NotificationModel *)item;
                 NSString *combined = [NSString stringWithFormat:@"%@ %@", [m pp_localizedTitleForCurrentLanguage], [m pp_localizedBodyForCurrentLanguage]];
                 return combined;
             }];

             [self reloadTableAnimated:YES];
             [PPToast toast:kLang(@"NotificationsLoaded") style:PPToastStyleSuccess haptic:NO duration:1.0 position:PPToastPositionBottom inView:self.view];
         });
     }];
     */
}

- (void)handleNotificationRoutePayload:(NSDictionary *)payload
{
    if (![payload isKindOfClass:NSDictionary.class] || payload.count == 0) {
        NSLog(@"[NotificationRoute] NotificationsListViewController received empty payload. Showing inbox only.");
        self.pendingRoutePayload = nil;
        return;
    }
    self.pendingRoutePayload = [payload copy];
    self.didLogMissingPendingRouteMatch = NO;
    [self pp_consumePendingRoutePayloadIfPossible];
}

- (NotificationModel * _Nullable)pp_notificationMatchingRoutePayload:(NSDictionary *)payload
{
    if (payload.count == 0 || self.allNotifications.count == 0) {
        return nil;
    }

    NSDictionary *payloadMeta = [payload[@"meta"] isKindOfClass:NSDictionary.class] ? payload[@"meta"] : @{};
    NSString *notificationID = PPNotificationsRouteTrimmedString(payload[@"notificationId"]);
    if (notificationID.length == 0) notificationID = PPNotificationsRouteTrimmedString(payload[@"nid"] ?: payloadMeta[@"notificationId"]);
    if (notificationID.length > 0) {
        for (NotificationModel *item in self.allNotifications) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            NSDictionary *meta = [item.meta isKindOfClass:NSDictionary.class] ? item.meta : @{};
            if (PPNotificationsRouteStringsEqual(item.nid, notificationID) ||
                PPNotificationsRouteStringsEqual(meta[@"notificationId"], notificationID)) {
                return item;
            }
        }
    }

    NSString *fulfillmentID = PPNotificationsRouteTrimmedString(payload[@"fulfillmentId"] ?: payload[@"fulfillmentID"]);
    if (fulfillmentID.length == 0) fulfillmentID = PPNotificationsRouteTrimmedString(payloadMeta[@"fulfillmentId"] ?: payloadMeta[@"fulfillmentID"]);
    if (fulfillmentID.length > 0) {
        for (NotificationModel *item in self.allNotifications) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            NSDictionary *meta = [item.meta isKindOfClass:NSDictionary.class] ? item.meta : @{};
            if (PPNotificationsRouteStringsEqual(meta[@"fulfillmentId"], fulfillmentID) ||
                PPNotificationsRouteStringsEqual(meta[@"fulfillmentID"], fulfillmentID)) {
                return item;
            }
        }
    }

    NSString *requestID = PPNotificationsRouteTrimmedString(payload[@"requestId"] ?: payloadMeta[@"requestId"]);
    if (requestID.length > 0) {
        for (NotificationModel *item in self.allNotifications) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            NSDictionary *meta = [item.meta isKindOfClass:NSDictionary.class] ? item.meta : @{};
            if (PPNotificationsRouteStringsEqual(meta[@"requestId"], requestID)) {
                return item;
            }
        }
    }

    NSString *orderID = PPNotificationsRouteTrimmedString(payload[@"orderId"] ?: payload[@"orderID"] ?: payload[@"parentOrderId"] ?: payload[@"parentOrderID"]);
    if (orderID.length == 0) orderID = PPNotificationsRouteTrimmedString(payloadMeta[@"orderId"] ?: payloadMeta[@"orderID"] ?: payloadMeta[@"parentOrderId"] ?: payloadMeta[@"parentOrderID"]);
    if (orderID.length > 0) {
        for (NotificationModel *item in self.allNotifications) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            NSDictionary *meta = [item.meta isKindOfClass:NSDictionary.class] ? item.meta : @{};
            if (PPNotificationsRouteStringsEqual(meta[@"orderId"], orderID) ||
                PPNotificationsRouteStringsEqual(meta[@"orderID"], orderID) ||
                PPNotificationsRouteStringsEqual(meta[@"parentOrderId"], orderID) ||
                PPNotificationsRouteStringsEqual(meta[@"parentOrderID"], orderID)) {
                return item;
            }
        }
    }

    NSString *threadID = PPNotificationsRouteTrimmedString(payload[@"threadId"] ?: payload[@"threadID"] ?: payloadMeta[@"threadId"] ?: payloadMeta[@"threadID"]);
    if (threadID.length > 0) {
        for (NotificationModel *item in self.allNotifications) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            NSDictionary *meta = [item.meta isKindOfClass:NSDictionary.class] ? item.meta : @{};
            if (PPNotificationsRouteStringsEqual(meta[@"threadId"], threadID) ||
                PPNotificationsRouteStringsEqual(meta[@"threadID"], threadID)) {
                return item;
            }
        }
    }

    return nil;
}

- (void)pp_consumePendingRoutePayloadIfPossible
{
    NSDictionary *payload = self.pendingRoutePayload;
    if (payload.count == 0) {
        return;
    }

    NotificationModel *match = [self pp_notificationMatchingRoutePayload:payload];
    if (!match) {
        if (!self.isLoading && self.allNotifications.count > 0 && !self.didLogMissingPendingRouteMatch) {
            self.didLogMissingPendingRouteMatch = YES;
            NSLog(@"[NotificationRoute] Notifications payload did not match any inbox item yet. requestId=%@ orderId=%@ threadId=%@",
                  PPNotificationsRouteTrimmedString(payload[@"requestId"]),
                  PPNotificationsRouteTrimmedString(payload[@"orderId"]),
                  PPNotificationsRouteTrimmedString(payload[@"threadId"]).length > 0 ? PPNotificationsRouteTrimmedString(payload[@"threadId"]) : PPNotificationsRouteTrimmedString(payload[@"threadID"]));
        }
        return;
    }

    self.pendingRoutePayload = nil;
    self.didLogMissingPendingRouteMatch = NO;
    [self pp_openNotificationModel:match];
}

- (void)pp_markNotificationReadIfNeeded:(NotificationModel *)model
{
    if (![model isKindOfClass:NotificationModel.class] || model.isRead) {
        return;
    }

    model.isRead = YES;
    [self pp_updateHeaderMetrics];
    [[NotificationManager shared] markRead:model forUser:self.uid completion:nil];
}

- (void)pp_openNotificationModel:(NotificationModel *)model
{
    if (![model isKindOfClass:NotificationModel.class]) {
        return;
    }

    [self pp_markNotificationReadIfNeeded:model];

    NSString *route = [PPNotificationsRouteTrimmedString(model.meta[@"route"]).lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *type = [PPNotificationsRouteTrimmedString(model.meta[@"notificationType"] ?: model.meta[@"type"]).lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *requestID = PPNotificationsRouteTrimmedString(model.meta[@"requestId"]);
    if (requestID.length > 0 &&
        ([route isEqualToString:@"fleet_partner"] || [type hasPrefix:@"company_delivery"])) {
        NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:model.meta ?: @{}];
        payload[@"requestId"] = requestID;
        payload[@"title"] = [model pp_localizedTitleForCurrentLanguage] ?: @"";
        payload[@"body"] = [model pp_localizedBodyForCurrentLanguage] ?: @"";
        [[NSNotificationCenter defaultCenter] postNotificationName:PPProCompanyDeliveryNotificationTappedNotification
                                                            object:requestID
                                                          userInfo:payload.copy];
        return;
    }

    NotificationDetailViewController *vc = [[NotificationDetailViewController alloc] initWithModel:model userID:self.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - PPSDelegate (fuzzy / debounce)

- (void)searchView:(PPS *)view didChangeText:(NSString *)text {
    // PPS has filterAsyncForText:completion:
    if (text.length == 0) {
        // restore all
        self.filteredNotifications = self.allNotifications;
        [self reloadTableAnimated:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [view filterAsyncForText:text completion:^(NSString * _Nonnull query, NSArray * _Nonnull results) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        // results are objects preserved from items array (NotificationModel)
        self.filteredNotifications = results ?: @[];
        [self reloadTableAnimated:YES];
    }];
}

- (void)searchViewDidSubmit:(PPS *)view {
    // optional: when user taps return
    [self.searchView unfocus];
}

#pragma mark - Table reload animation

- (void)reloadTableAnimated:(BOOL)animated {
    [self pp_updateEmptyState];
    [self.tableView reloadData];

    if (!animated || self.filteredNotifications.count == 0) return;

    NSArray *cells = [self.tableView visibleCells];
    CGFloat delay = 0.0;
    for (UITableViewCell *cell in cells) {
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0, 10.0);
    }
    for (UITableViewCell *cell in cells) {
        [UIView animateWithDuration:0.34
                              delay:delay
             usingSpringWithDamping:0.94
              initialSpringVelocity:0.25
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
        delay += 0.035;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredNotifications.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NotificationModel *m = self.filteredNotifications[indexPath.row];
    NotificationCell *cell = [tableView dequeueReusableCellWithIdentifier:[NotificationCell reuseId] forIndexPath:indexPath];
    [cell configure:m];

    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.filteredNotifications.count == 0 || indexPath.row >= self.filteredNotifications.count) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    NotificationModel *m = self.filteredNotifications[indexPath.row];
    [self pp_openNotificationModel:m];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Dealloc

- (void)dealloc {
    [self.inboxListener remove];
    DLog(@"NotificationsListViewController dealloc");
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:NotificationCell.class]) {
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
        return;
    }
    [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO buttonRowIndex:0 buttonSection:1];
}


@end
