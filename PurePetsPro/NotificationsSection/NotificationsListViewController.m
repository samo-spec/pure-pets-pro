// NotificationsListViewController.m
#import "NotificationsListViewController.h"
#import "PPToast.h"
#import "NotificationManager.h"   // replace with your manager
#import "NotificationManager+Targets.h"
#import "NotificationModel.h"     // your notification model
#import "NotificationCell.h"
#import "PPFirebaseCompat.h"
#import "Styling.h"
#import "Language.h"
#import "PPS.h"
#import "PPProInAppNotificationPresenter.h"

/// Triage lens.
///
/// The inbox is an unbounded live stream — the reference account carries 203
/// unread — and it previously offered no way to narrow it: no category control,
/// no unread view, no grouping. The only filter was free-text search. A `Filter`
/// affordance was clearly intended (`-onFilterTapped` exists with a localized
/// `PPS_Filter` string) but the `PPS` buttons that would trigger it are disabled,
/// so it has always been unreachable.
///
/// These lenses are local presentation state. They never fetch, never re-derive a
/// permission, and never change what the listener observes. The category cases map
/// onto `PPProNotificationTargetKind`, which Objective-C already computes to route
/// the tap, so a lens can never disagree with a row's icon or its destination.
typedef NS_ENUM(NSInteger, PPNotificationLens) {
    PPNotificationLensInbox = 0,
    PPNotificationLensUnread,
    PPNotificationLensOrders,
    PPNotificationLensDelivery,
    PPNotificationLensChat,
    PPNotificationLensUpdates,
};

/// One day's worth of rows. Section grouping comes free from `createdAt`, which
/// is already the listener's sort key, and turns a 203-row wall into something
/// with structure.
@interface PPNotificationDaySection : NSObject
@property (nonatomic, strong) NSDate *day;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<NotificationModel *> *items;
@end

@implementation PPNotificationDaySection
@end

@interface NotificationsListViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NotificationModel *> *allNotifications;
@property (nonatomic, strong) NSArray<NotificationModel *> *filteredNotifications;
@property (nonatomic, copy) NSArray<PPNotificationDaySection *> *daySections;
@property (nonatomic, assign) PPNotificationLens lens;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) PPS *searchView;              // the PPS instance
@property (nonatomic, strong) UIView *searchContainer;      // wrapper for header
@property (nonatomic, strong) UIView *commandBar;           // pinned identity + lens rail
@property (nonatomic, strong) UIScrollView *lensRail;
@property (nonatomic, strong) UIStackView *lensStack;
@property (nonatomic, strong) NSArray<UIButton *> *lensButtons;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UILabel *unreadBadgeLabel;
@property (nonatomic, strong) UIView *unreadBadgeView;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIView *emptyIconShellView;
@property (nonatomic, strong) UIImageView *emptyIconImageView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *topBackgroundGlowView;
@property (nonatomic, strong) UIView *bottomBackgroundGlowView;

@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL didPlayEntrance;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> inboxListener;
@property (nonatomic, copy, nullable) NSDictionary *pendingRoutePayload;
@property (nonatomic, assign) BOOL didLogMissingPendingRouteMatch;
@property (nonatomic, assign) BOOL pendingOpenNewestUnreadNotification;
@property (nonatomic, assign) BOOL hasReceivedInboxSnapshot;
@property (nonatomic, assign) BOOL hasAppeared;
@property (nonatomic, strong, nullable) NSError *inboxError;
@property (nonatomic, copy, nullable) NSString *lastInboxErrorSignature;
@property (nonatomic, copy, nullable) NSArray<NotificationModel *> *searchResults;

- (void)pp_setupBackgroundGlows;
- (void)pp_updateBackgroundGlowStyle;
- (void)setupCommandBar;
- (void)setupTableView;
- (void)setupSearchView;
- (void)setupEmptyStateView;
- (void)pp_updateLensChips;
- (void)pp_lensChipTapped:(UIButton *)sender;
- (void)pp_updateTableHeaderLayout;
- (void)pp_recomputeVisibleNotifications;
- (void)pp_rebuildDaySections;
- (void)pp_updateHeaderMetrics;
- (void)pp_updateEmptyState;
- (void)pp_setLoadingIndicatorActive:(BOOL)active;
- (void)pp_playEntranceIfNeeded;
- (void)fetchNotificationsShowToast:(BOOL)showToast;
- (void)pp_consumePendingRoutePayloadIfPossible;
- (void)pp_consumePendingOpenNewestUnreadNotificationIfPossible;
- (void)pp_markNotificationReadIfNeeded:(NotificationModel *)model;
- (void)pp_openNotificationModel:(NotificationModel *)model;
- (void)pp_pushNotificationDetailForModel:(NotificationModel *)model;
- (void)reloadTableAnimated:(BOOL)animated;
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

/// Dynamic Type bridge — `Styling fontBold:`/`fontMedium:` return fixed-size
/// fonts, so this screen previously ignored the user's text-size setting.
static UIFont *PPNotificationsScaledFont(UIFont *base, UIFontTextStyle style)
{
    if (!base) { return nil; }
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:base];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.uid = PPProAuthenticatedNotificationUID();

    self.view.backgroundColor = AppBackgroundClr;
    self.allNotifications = @[];
    self.filteredNotifications = @[];
    self.isLoading = NO;
    self.pendingOpenNewestUnreadNotification = NO;
    self.hasReceivedInboxSnapshot = NO;
    self.hasAppeared = NO;

    [self pp_setupBackgroundGlows];
    [self setupCommandBar];
    [self setupTableView];
    [self setupSearchView];
    [self setupEmptyStateView];
    [self pp_updateHeaderMetrics];
    [self pp_recomputeVisibleNotifications];
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
        self.searchResults = nil;
        self.isLoading = NO;
        self.pendingOpenNewestUnreadNotification = NO;
        self.hasReceivedInboxSnapshot = NO;
        [self pp_recomputeVisibleNotifications];
        [self reloadTableAnimated:NO];
        [self fetchNotificationsShowToast:NO];
    }

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.hasAppeared = YES;
    [self pp_playEntranceIfNeeded];

    // A targeted system/push route takes precedence over Command Focus's
    // broadest-unread request so two detail controllers can never be pushed.
    BOOL hasSpecificRoutePayload = self.pendingRoutePayload.count > 0;
    [self pp_consumePendingRoutePayloadIfPossible];
    if (!hasSpecificRoutePayload) {
        [self pp_consumePendingOpenNewestUnreadNotificationIfPossible];
    }
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
    // Dynamic Type can change while this screen is on-screen; the manually framed
    // table header must be re-measured or it clips the grown text.
    if (previousTraitCollection &&
        ![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_updateTableHeaderLayout];
        [self.tableView reloadData];
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
    // Tuned to the real card geometry (insets + icon plate + 3-label stack); the
    // previous 104 under-estimated it and amplified scroll-offset jumps.
    self.tableView.estimatedRowHeight = 132.0;
    // The table used to be pinned to `view.bottomAnchor` with a flat 24pt content
    // inset and no `contentInsetAdjustmentBehavior`, so the last row rendered
    // underneath the tab bar — visible as content bleeding through the floating
    // bar. `hidesBottomBarWhenPushed` is not set at any of this controller's push
    // sites, so it always lives inside the tab bar container and must respect the
    // bottom safe area.
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, PPSpaceBase, 0);
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    self.tableView.sectionHeaderTopPadding = 0.0;
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

    // constraints — the lens rail is persistent chrome above the scroll area, so
    // filters stay reachable at row 200 instead of scrolling away with the header.
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.commandBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    self.tableView.tableHeaderView = nil;
}



/// Pinned identity + lens rail.
///
/// Replaces the 214pt scrolling hero (`PPHero` + large title + explanatory
/// subtitle + count pill + 52pt search field), which consumed roughly the top
/// 40% of the viewport before a single notification was visible, and scrolled
/// away exactly when a 203-row list made navigation controls most useful.
///
/// The explanatory subtitle (`NotificationsInboxSubtitle`) is deliberately not
/// repeated here: it is a one-time orientation sentence, not per-visit
/// information. It is still shown where it genuinely helps — the loading and
/// empty states in `-pp_updateEmptyState`.
- (void)setupCommandBar {
    self.lens = PPNotificationLensInbox;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = UIColor.clearColor;
    bar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:bar];
    self.commandBar = bar;

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.font = PPNotificationsScaledFont([Styling fontBold:PPFontTitle2], UIFontTextStyleTitle2);
    self.headerTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerTitleLabel.textColor = PrimaryTextClr;
    self.headerTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.headerTitleLabel.numberOfLines = 2;
    [bar addSubview:self.headerTitleLabel];

    // The count is the one live figure that belongs in persistent chrome.
    UIView *badgeView = [[UIView alloc] init];
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    PPApplyContinuousCorners(badgeView, PPCornerSmall);
    [bar addSubview:badgeView];
    self.unreadBadgeView = badgeView;

    self.unreadBadgeLabel = [[UILabel alloc] init];
    self.unreadBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.unreadBadgeLabel.font = PPNotificationsScaledFont([Styling fontBold:PPFontCaption1], UIFontTextStyleCaption1);
    self.unreadBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.unreadBadgeLabel.textColor = AppPrimaryClr;
    self.unreadBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.unreadBadgeLabel.numberOfLines = 1;
    [badgeView addSubview:self.unreadBadgeLabel];

    UIScrollView *rail = [[UIScrollView alloc] init];
    rail.translatesAutoresizingMaskIntoConstraints = NO;
    rail.showsHorizontalScrollIndicator = NO;
    rail.alwaysBounceHorizontal = YES;
    rail.clipsToBounds = NO;
    rail.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [bar addSubview:rail];
    self.lensRail = rail;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = PPSpaceSM;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [rail addSubview:stack];
    self.lensStack = stack;

    NSArray<NSNumber *> *lenses = @[
        @(PPNotificationLensInbox),
        @(PPNotificationLensUnread),
        @(PPNotificationLensOrders),
        @(PPNotificationLensDelivery),
        @(PPNotificationLensChat),
        @(PPNotificationLensUpdates),
    ];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    for (NSNumber *boxed in lenses) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.tag = boxed.integerValue;
        chip.titleLabel.font = PPNotificationsScaledFont([Styling fontMedium:PPFontSubheadline], UIFontTextStyleSubheadline);
        chip.titleLabel.adjustsFontForContentSizeCategory = YES;
        chip.titleLabel.numberOfLines = 1;
        chip.contentEdgeInsets = UIEdgeInsetsMake(0, PPSpaceMD, 0, PPSpaceMD);
        PPApplyContinuousCorners(chip, PPCornerSmall);
        chip.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [chip addTarget:self action:@selector(pp_lensChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin - 8.0].active = YES;
        [stack addArrangedSubview:chip];
        [buttons addObject:chip];
    }
    self.lensButtons = buttons.copy;

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:bar.topAnchor constant:PPSpaceMD],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:PPSpaceBase],

        [badgeView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.headerTitleLabel.trailingAnchor constant:PPSpaceSM],
        [badgeView.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-PPSpaceBase],
        [badgeView.centerYAnchor constraintEqualToAnchor:self.headerTitleLabel.centerYAnchor],
        [badgeView.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [self.unreadBadgeLabel.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:PPSpaceMD],
        [self.unreadBadgeLabel.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-PPSpaceMD],
        [self.unreadBadgeLabel.topAnchor constraintEqualToAnchor:badgeView.topAnchor constant:PPSpaceXS],
        [self.unreadBadgeLabel.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor constant:-PPSpaceXS],

        [rail.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:PPSpaceMD],
        [rail.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [rail.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [rail.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-PPSpaceMD],

        [stack.topAnchor constraintEqualToAnchor:rail.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:rail.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:rail.leadingAnchor constant:PPSpaceBase],
        [stack.trailingAnchor constraintEqualToAnchor:rail.trailingAnchor constant:-PPSpaceBase],
        [stack.heightAnchor constraintEqualToAnchor:rail.heightAnchor],
    ]];

    [self pp_updateLensChips];
}

- (NSString *)pp_titleForLens:(PPNotificationLens)lens {
    switch (lens) {
        case PPNotificationLensInbox:    return kLang(@"Inbox");
        case PPNotificationLensUnread:   return kLang(@"Unread");
        case PPNotificationLensOrders:   return kLang(@"notifications_inbox_category_orders");
        case PPNotificationLensDelivery: return kLang(@"notifications_inbox_category_delivery");
        case PPNotificationLensChat:     return kLang(@"notifications_inbox_category_chat");
        case PPNotificationLensUpdates:  return kLang(@"notifications_inbox_category_updates");
    }
    return kLang(@"Inbox");
}

/// Whether a notification belongs to a lens. Category membership is decided by
/// `+targetKindForPayload:` — the same classification the row's icon and the tap's
/// destination use — so the three can never disagree.
- (BOOL)pp_notification:(NotificationModel *)model matchesLens:(PPNotificationLens)lens {
    if (![model isKindOfClass:NotificationModel.class]) return NO;
    if (lens == PPNotificationLensInbox) return YES;
    if (lens == PPNotificationLensUnread) return !model.isRead;

    NSDictionary *payload = [NotificationManager routingPayloadForNotificationModel:model];
    PPProNotificationTargetKind kind = [NotificationManager targetKindForPayload:payload];
    switch (lens) {
        case PPNotificationLensOrders:
            return kind == PPProNotificationTargetKindFulfillment;
        case PPNotificationLensDelivery:
            return kind == PPProNotificationTargetKindDeliveryOrder
                || kind == PPProNotificationTargetKindCompanyDelivery;
        case PPNotificationLensChat:
            return kind == PPProNotificationTargetKindChat;
        case PPNotificationLensUpdates:
            return kind == PPProNotificationTargetKindUnknown;
        default:
            return YES;
    }
}

- (NSUInteger)pp_countForLens:(PPNotificationLens)lens {
    NSUInteger count = 0;
    for (NotificationModel *item in self.allNotifications) {
        if ([self pp_notification:item matchesLens:lens]) count += 1;
    }
    return count;
}

- (void)pp_updateLensChips {
    for (UIButton *chip in self.lensButtons) {
        PPNotificationLens lens = (PPNotificationLens)chip.tag;
        BOOL selected = (lens == self.lens);
        NSUInteger count = [self pp_countForLens:lens];
        NSString *title = [self pp_titleForLens:lens];
        // Counts are appended numerically rather than through a new format string,
        // so the rail introduces no untranslated copy.
        NSString *label = count > 0 ? [NSString stringWithFormat:@"%@ · %lu", title, (unsigned long)count] : title;

        [chip setTitle:label forState:UIControlStateNormal];
        [chip setTitleColor:selected ? UIColor.whiteColor : PrimaryTextClr forState:UIControlStateNormal];
        chip.backgroundColor = selected ? AppPrimaryClr : AppForgroundColr;
        chip.layer.borderWidth = selected ? 0.0 : 1.0 / UIScreen.mainScreen.scale;
        chip.layer.borderColor = PPHairlineColor().CGColor;
        chip.accessibilityLabel = label;
        chip.accessibilityTraits = selected
            ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected)
            : UIAccessibilityTraitButton;
        // An empty lens is still shown — hiding it would make the taxonomy
        // unstable between refreshes — but it is not offered as a destination.
        chip.enabled = (count > 0 || selected || lens == PPNotificationLensInbox);
        chip.alpha = chip.enabled ? 1.0 : 0.45;
    }
}

- (void)pp_lensChipTapped:(UIButton *)sender {
    PPNotificationLens next = (PPNotificationLens)sender.tag;
    if (next == self.lens) return;
    self.lens = next;
    [[UISelectionFeedbackGenerator new] selectionChanged];
    [self pp_updateLensChips];
    [self pp_recomputeVisibleNotifications];
    [self reloadTableAnimated:YES];
    if (self.daySections.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                              atScrollPosition:UITableViewScrollPositionTop
                                      animated:!UIAccessibilityIsReduceMotionEnabled()];
    }
}

- (void)setupSearchView {
    CGFloat searchHeight = 52.0;
    // Only the search field scrolls now. Identity and the lens rail live in the
    // pinned command bar, so this header is 76pt instead of 214pt and the first
    // notification is visible on first paint.
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 76.0)];
    self.searchContainer.backgroundColor = UIColor.clearColor;
    self.searchContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

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

    [NSLayoutConstraint activateConstraints:@[
        [self.searchView.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:PPSpaceSM],
        [self.searchView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:PPSpaceBase],
        [self.searchView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-PPSpaceBase],
        [self.searchView.heightAnchor constraintEqualToConstant:searchHeight],
        [self.searchView.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:-PPSpaceMD]
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
    iconShell.backgroundColor = AppPrimaryClrWithAlpha(0.08);
    PPApplyContinuousCorners(iconShell, 34.0);
    [emptyView addSubview:iconShell];
    self.emptyIconShellView = iconShell;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.slash.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClrWithAlpha(0.82);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];
    self.emptyIconImageView = iconView;

    // A real loading affordance. This screen had no spinner at all: the loading
    // state was a text swap on the same empty view as "no notifications", so a
    // slow first paint was indistinguishable from an empty inbox.
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.color = AppPrimaryClr;
    self.loadingIndicator.hidesWhenStopped = YES;
    [iconShell addSubview:self.loadingIndicator];

    self.emptyTitleLabel = [[UILabel alloc] init];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = PPNotificationsScaledFont([Styling fontBold:PPFontTitle2], UIFontTextStyleTitle2);
    self.emptyTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.emptyTitleLabel.textColor = PrimaryTextClr;
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.numberOfLines = 3;

    self.emptySubtitleLabel = [[UILabel alloc] init];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = PPNotificationsScaledFont([Styling fontMedium:13], UIFontTextStyleSubheadline);
    self.emptySubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.emptySubtitleLabel.textColor = SeconderyTextClr;
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 4;

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
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
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
                                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    height = MAX(height, 76.0);

    CGRect frame = self.searchContainer.frame;
    if (fabs(frame.size.width - width) > 0.5 || fabs(frame.size.height - height) > 0.5) {
        frame.size = CGSizeMake(width, height);
        self.searchContainer.frame = frame;
        self.tableView.tableHeaderView = self.searchContainer;
    }
}

/// The one place the visible set is derived.
///
/// Lens and search used to be unable to coexist: `-searchView:didChangeText:`
/// assigned `filteredNotifications = allNotifications` on an empty query, and the
/// listener callback did the same, so any other narrowing would have been silently
/// discarded on the next keystroke or snapshot. Composing both here — and having
/// every caller route through it — makes that class of desync unrepresentable.
- (void)pp_recomputeVisibleNotifications {
    NSString *query = self.searchView.textField.text ?: @"";
    NSArray<NotificationModel *> *base = self.allNotifications ?: @[];

    NSMutableArray<NotificationModel *> *lensed = [NSMutableArray arrayWithCapacity:base.count];
    for (NotificationModel *item in base) {
        if ([self pp_notification:item matchesLens:self.lens]) [lensed addObject:item];
    }

    if (query.length == 0) {
        self.filteredNotifications = lensed.copy;
        [self pp_rebuildDaySections];
        return;
    }

    // Search results arrive asynchronously from PPS; intersect them with the lens
    // rather than replacing it.
    NSMutableSet<NSString *> *allowed = [NSMutableSet setWithCapacity:lensed.count];
    for (NotificationModel *item in lensed) {
        if (item.nid.length > 0) [allowed addObject:item.nid];
    }
    NSMutableArray<NotificationModel *> *result = [NSMutableArray array];
    for (NotificationModel *item in self.searchResults ?: @[]) {
        if ([item isKindOfClass:NotificationModel.class] && [allowed containsObject:item.nid]) {
            [result addObject:item];
        }
    }
    self.filteredNotifications = result.copy;
    [self pp_rebuildDaySections];
}

/// Groups the visible rows by calendar day.
///
/// `createdAt` is already the listener's sort key, so this adds structure without
/// adding data. Section titles use `NSDateFormatter.doesRelativeDateFormatting`,
/// which yields the system's own localized "Today"/"Yesterday" — no new
/// localization keys, and correct in every locale the device supports.
- (void)pp_rebuildDaySections {
    NSArray<NotificationModel *> *items = self.filteredNotifications ?: @[];
    if (items.count == 0) {
        self.daySections = @[];
        return;
    }

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:[Language currentLanguageCode] ?: @"en"];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.doesRelativeDateFormatting = YES;

    NSMutableArray<PPNotificationDaySection *> *sections = [NSMutableArray array];
    PPNotificationDaySection *current = nil;
    NSMutableArray<NotificationModel *> *bucket = nil;

    for (NotificationModel *item in items) {
        NSDate *day = [calendar startOfDayForDate:item.createdAt ?: [NSDate date]];
        if (!current || ![calendar isDate:current.day inSameDayAsDate:day]) {
            if (current) { current.items = bucket.copy; [sections addObject:current]; }
            current = [PPNotificationDaySection new];
            current.day = day;
            current.title = [formatter stringFromDate:day];
            bucket = [NSMutableArray array];
        }
        [bucket addObject:item];
    }
    if (current) { current.items = bucket.copy; [sections addObject:current]; }
    self.daySections = sections.copy;
}

- (NotificationModel * _Nullable)pp_notificationAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section < 0 || indexPath.section >= (NSInteger)self.daySections.count) return nil;
    PPNotificationDaySection *section = self.daySections[indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)section.items.count) return nil;
    return section.items[indexPath.row];
}

- (void)pp_updateHeaderMetrics {
    NSUInteger unreadCount = 0;
    for (NotificationModel *item in self.allNotifications) {
        if (![item isKindOfClass:NotificationModel.class]) continue;
        if (!item.isRead) unreadCount += 1;
    }

    self.headerTitleLabel.text = kLang(@"Inbox");
    if (unreadCount > 0) {
        self.unreadBadgeLabel.text = [NSString stringWithFormat:kLang(@"NotificationsUnreadFormat"), (unsigned long)unreadCount];
        self.unreadBadgeView.backgroundColor = AppPrimaryClrWithAlpha(0.10);
        self.unreadBadgeLabel.textColor = AppPrimaryClr;
    } else {
        self.unreadBadgeLabel.text = kLang(@"NotificationsAllRead");
        self.unreadBadgeView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
        self.unreadBadgeLabel.textColor = SeconderyTextClr;
    }
    [self pp_updateLensChips];
}

- (void)pp_updateEmptyState {
    BOOL isSearching = self.searchView.textField.text.length > 0;
    BOOL shouldShowEmpty = (self.filteredNotifications.count == 0);
    self.emptyStateView.hidden = !shouldShowEmpty;

    BOOL isFirstLoad = (self.isLoading && self.allNotifications.count == 0);
    // `inboxError` is also raised for cache-only snapshots while valid data is
    // still rendered, so the error state is only claimed when nothing loaded.
    BOOL isErrored = (self.inboxError != nil && self.allNotifications.count == 0);

    [self pp_setLoadingIndicatorActive:isFirstLoad];

    if (isFirstLoad) {
        self.emptyTitleLabel.text = kLang(@"Loading");
        self.emptySubtitleLabel.text = kLang(@"NotificationsInboxSubtitle");
        return;
    }

    if (isErrored) {
        self.emptyIconImageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
        self.emptyTitleLabel.text = kLang(@"FetchError");
        self.emptySubtitleLabel.text = kLang(@"PullToRefresh");
        return;
    }

    self.emptyIconImageView.image = [UIImage systemImageNamed:isSearching ? @"magnifyingglass" : @"bell.slash.fill"];
    self.emptyTitleLabel.text = isSearching ? kLang(@"NotificationsNoSearchResults") : kLang(@"NoNotifications");
    self.emptySubtitleLabel.text = isSearching ? kLang(@"NotificationsNoSearchSubtitle") : kLang(@"NotificationsEmptySubtitle");

    // A lens that filters to zero is not an empty inbox, and saying "no
    // notifications yet" there would be false. Name the lens instead, reusing its
    // own already-localized title.
    if (!isSearching && self.lens != PPNotificationLensInbox && self.allNotifications.count > 0) {
        self.emptyIconImageView.image = [UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"];
        self.emptyTitleLabel.text = [self pp_titleForLens:self.lens];
        self.emptySubtitleLabel.text = kLang(@"NotificationsAllRead");
    }
}

/// While loading, the spinner takes the icon shell so the state reads as work in
/// progress rather than as an empty inbox.
- (void)pp_setLoadingIndicatorActive:(BOOL)active {
    self.emptyIconImageView.hidden = active;
    if (active) {
        [self.loadingIndicator startAnimating];
    } else {
        [self.loadingIndicator stopAnimating];
    }
}

- (void)pp_playEntranceIfNeeded {
    if (self.didPlayEntrance || UIAccessibilityIsReduceMotionEnabled()) return;
    self.didPlayEntrance = YES;

    self.commandBar.alpha = 0.0;
    self.commandBar.transform = CGAffineTransformMakeTranslation(0, 14.0);
    [UIView animateWithDuration:0.48
                          delay:0.02
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.commandBar.alpha = 1.0;
        self.commandBar.transform = CGAffineTransformIdentity;
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
    self.hasReceivedInboxSnapshot = NO;
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
        self.searchResults = nil;
        [self pp_recomputeVisibleNotifications];
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
        self.hasReceivedInboxSnapshot = YES;
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
        }
        // update PPS search index with items
        [self.searchView setSearchItems:self.allNotifications stringProvider:^NSString * _Nonnull(id item) {
            if (![item isKindOfClass:NotificationModel.class]) return @"";
            NotificationModel *m = (NotificationModel *)item;
            NSString *combined = [NSString stringWithFormat:@"%@ %@", [m pp_localizedTitleForCurrentLanguage], [m pp_localizedBodyForCurrentLanguage]];
            return combined;
        }];

        [self pp_updateHeaderMetrics];
        [self pp_recomputeVisibleNotifications];
        [self reloadTableAnimated:YES];
        BOOL hasSpecificRoutePayload = self.pendingRoutePayload.count > 0;
        [self pp_consumePendingRoutePayloadIfPossible];
        if (!hasSpecificRoutePayload) {
            [self pp_consumePendingOpenNewestUnreadNotificationIfPossible];
        }
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

/// Command Focus cannot truthfully name an unread record before the inbox has
/// loaded. It therefore requests the latest unread item only after this
/// controller receives the authenticated, manager-sorted snapshot.
- (void)pp_openNewestUnreadNotificationWhenReady
{
    self.pendingOpenNewestUnreadNotification = YES;
    [self pp_consumePendingOpenNewestUnreadNotificationIfPossible];
}

- (void)pp_consumePendingOpenNewestUnreadNotificationIfPossible
{
    if (!self.pendingOpenNewestUnreadNotification ||
        !self.hasReceivedInboxSnapshot ||
        !self.hasAppeared) {
        return;
    }

    self.pendingOpenNewestUnreadNotification = NO;
    for (NotificationModel *item in self.allNotifications) {
        if ([item isKindOfClass:NotificationModel.class] && !item.isRead) {
            [self pp_openNotificationModel:item];
            return;
        }
    }
    // The dashboard count may have changed between snapshots. In that case the
    // expected safe result is the inbox itself, never a stale or fabricated row.
}

- (void)pp_markNotificationReadIfNeeded:(NotificationModel *)model
{
    if (![model isKindOfClass:NotificationModel.class] || model.isRead) {
        return;
    }

    // Optimistic, but no longer unaccountable. Every call site previously passed
    // `completion:nil`, so a rejected `userNotificationInboxReadAck` /
    // `staffNotificationInboxReadAck` left the row permanently showing as read
    // with no rollback and nothing surfaced. The local flip is kept for
    // responsiveness and reverted if the server refuses.
    model.isRead = YES;
    [self pp_updateHeaderMetrics];
    [self pp_recomputeVisibleNotifications];

    __weak typeof(self) weakSelf = self;
    [[NotificationManager shared] markRead:model forUser:self.uid completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !error) return;
        model.isRead = NO;
        [self pp_updateHeaderMetrics];
        [self pp_recomputeVisibleNotifications];
        [self reloadTableAnimated:NO];
        DLog(@"[NotificationsV2] read-ack rejected | domain=%@ code=%ld", error.domain ?: @"unknown", (long)error.code);
        [PPToast toast:kLang(@"FetchError") style:PPToastStyleError haptic:YES duration:2.0 position:PPToastPositionBottom inView:self.view];
    }];
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

    // Route to the thing the notification is *about*.
    //
    // Every non-company-delivery row used to push `NotificationDetailViewController`
    // — a screen that restates the notification — even though
    // `NotificationManager+Targets` already knew how to open the fulfillment, the
    // delivery order or the chat thread, and was already doing exactly that for
    // push deep-links. Tapping "New order #PP-…" now opens the order.
    //
    // No new authorization: `+routePayload:` performs the same ownership/scope
    // checks and pushes the same controllers as the push path, and reports whether
    // it handled the payload. The detail screen remains the honest fallback for a
    // notification with no concrete target.
    NSDictionary *routingPayload = [NotificationManager routingPayloadForNotificationModel:model];
    if ([NotificationManager payloadHasDirectTarget:routingPayload]) {
        __weak typeof(self) weakSelf = self;
        [NotificationManager routePayload:routingPayload
                fromNavigationController:self.navigationController
                               presenter:self
                              completion:^(BOOL handled) {
            if (handled) return;
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_pushNotificationDetailForModel:model];
        }];
        return;
    }

    [self pp_pushNotificationDetailForModel:model];
}

- (void)pp_pushNotificationDetailForModel:(NotificationModel *)model
{
    NotificationDetailViewController *vc = [[NotificationDetailViewController alloc] initWithModel:model userID:self.uid];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - PPSDelegate (fuzzy / debounce)

- (void)searchView:(PPS *)view didChangeText:(NSString *)text {
    // PPS has filterAsyncForText:completion:
    if (text.length == 0) {
        self.searchResults = nil;
        [self pp_recomputeVisibleNotifications];
        [self reloadTableAnimated:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [view filterAsyncForText:text completion:^(NSString * _Nonnull query, NSArray * _Nonnull results) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        // results are objects preserved from items array (NotificationModel).
        // They are intersected with the active lens in pp_recomputeVisibleNotifications
        // rather than replacing it.
        self.searchResults = results ?: @[];
        [self pp_recomputeVisibleNotifications];
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
    // Reduce Motion was honoured by the header entrance but not here, so the
    // row stagger still ran. It is now gated the same way.
    if (UIAccessibilityIsReduceMotionEnabled()) return;

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
        // Capped so a full screen of rows never feels slow to settle.
        delay = MIN(delay + 0.035, 0.28);
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.daySections.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.daySections.count) return 0;
    return (NSInteger)self.daySections[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NotificationCell *cell = [tableView dequeueReusableCellWithIdentifier:[NotificationCell reuseId] forIndexPath:indexPath];
    NotificationModel *m = [self pp_notificationAtIndexPath:indexPath];
    if (m) { [cell configure:m]; }
    return cell;
}

/// Sticky day header. The title is the system's own relative date formatting, so
/// this adds structure to a 203-row list without adding copy or a new key.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.daySections.count) return nil;

    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *pill = [[UIView alloc] init];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.backgroundColor = AppForgroundColr;
    pill.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    pill.layer.borderColor = PPHairlineColor().CGColor;
    PPApplyContinuousCorners(pill, PPCornerSmall);
    [container addSubview:pill];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = self.daySections[section].title;
    label.font = PPNotificationsScaledFont([Styling fontBold:PPFontCaption1], UIFontTextStyleCaption1);
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = SeconderyTextClr;
    label.numberOfLines = 1;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    [pill addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [pill.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPSpaceBase],
        [pill.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-PPSpaceBase],
        [pill.topAnchor constraintEqualToAnchor:container.topAnchor constant:PPSpaceSM],
        [pill.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-PPSpaceXS],
        [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:PPSpaceMD],
        [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-PPSpaceMD],
        [label.topAnchor constraintEqualToAnchor:pill.topAnchor constant:PPSpaceXS],
        [label.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-PPSpaceXS],
    ]];
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return 40.0;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NotificationModel *m = [self pp_notificationAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!m) { return; }
    [self pp_openNotificationModel:m];
    // Marking read can move a row out of the active lens (the unread view in
    // particular), so the section model is rebuilt instead of a now-stale index
    // path being reloaded in place.
    [self reloadTableAnimated:NO];
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
