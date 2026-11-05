//
//  NotificationDetailViewController.m
//  PurePetsPro
//
//  Category-defining administrative notification dossier & operational command inspector.
//

#import "NotificationDetailViewController.h"
#import "NotificationManager.h"
#import "NotificationManager+Targets.h"
#import "Styling.h"
#import "Language.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPUserMessagesViewController.h"
#import "PPProviderSupportChatsViewController.h"
#import "PPFulfillmentDetailViewController.h"
#import "PPFulfillmentModel.h"
#import "PPDeliveryOrderDetailViewController.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryManager.h"
#import "ChatThreadModel.h"
#import "PPFirebaseCompat.h"

static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

static NSString *PPNotificationDetailTrimmedString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSDictionary *PPNotificationDetailSafeDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPNotificationDetailLocalizedString(id value) {
    NSString *scalar = PPNotificationDetailTrimmedString(value);
    if (scalar.length) return scalar;

    NSDictionary *dictionary = PPNotificationDetailSafeDictionary(value);
    if (dictionary.count == 0) return @"";

    NSArray<NSString *> *primaryKeys = Language.isRTL
        ? @[@"ar", @"arabic", @"titleAr", @"nameAr", @"valueAr", @"textAr"]
        : @[@"en", @"english", @"titleEn", @"nameEn", @"valueEn", @"textEn"];
    NSArray<NSString *> *fallbackKeys = Language.isRTL
        ? @[@"en", @"english", @"titleEn", @"nameEn", @"valueEn", @"textEn"]
        : @[@"ar", @"arabic", @"titleAr", @"nameAr", @"valueAr", @"textAr"];

    for (NSString *key in primaryKeys) {
        NSString *localized = PPNotificationDetailTrimmedString(dictionary[key]);
        if (localized.length) return localized;
    }
    for (NSString *key in fallbackKeys) {
        NSString *localized = PPNotificationDetailTrimmedString(dictionary[key]);
        if (localized.length) return localized;
    }
    return @"";
}

static NSString *PPNotificationDetailFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *value = PPNotificationDetailLocalizedString(source[key]);
        if (value.length) return value;
    }
    return @"";
}

static NSString *PPNotificationDetailNormalizedNotificationType(NSDictionary *payload) {
    NSString *type = [PPNotificationDetailFirstStringForKeys(PPNotificationDetailSafeDictionary(payload), @[
        @"notificationType", @"type", @"eventKey", @"route"
    ]) lowercaseString];
    type = [type stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [type stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
}

static BOOL PPNotificationDetailIsProviderOrderCancellation(NSDictionary *payload) {
    return [PPNotificationDetailNormalizedNotificationType(payload) isEqualToString:@"provider_order_cancelled"];
}

@interface NotificationDetailViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) NotificationModel *model;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSDictionary *routePayload;
@property (nonatomic, assign) BOOL isWideLayout;

// Navigation
@property (nonatomic, strong) UIView *dossierNavBarView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navEyebrowLabel;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIButton *readStatusNavButton;
@property (nonatomic, strong) UIButton *shareNavButton;
@property (nonatomic, strong) UIButton *clipboardNavButton;

// Layout Surfaces
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIStackView *iphoneContentStack;
@property (nonatomic, strong) UIStackView *ipadWingsStack;
@property (nonatomic, strong) UIStackView *ipadLeadingWing;
@property (nonatomic, strong) UIStackView *ipadTrailingWing;

// Cards & Elements
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIView *bodyCardView;
@property (nonatomic, strong) UIView *contextCardView;
@property (nonatomic, strong) UIView *metadataCardView;
@property (nonatomic, strong) UIView *actionDockContainer;
@property (nonatomic, strong) UIButton *primaryActionButton;
@property (nonatomic, strong) UILabel *actionSubtitleLabel;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UIView *statusBadgePill;

// Firestore live listener for order summaries
@property (nonatomic, strong) id<FIRListenerRegistration> summaryOrderListener;
@property (nonatomic, strong) PPDeliveryOrderModel *summaryOrder;

@end

@implementation NotificationDetailViewController

#pragma mark - Initializers

- (instancetype)initWithModel:(NotificationModel *)model userID:(NSString *)uid onDismiss:(nullable void (^)(void))onDismiss {
    self = [super init];
    if (self) {
        _model = model;
        _uid = [uid copy] ?: @"";
        _onDismiss = [onDismiss copy];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithModel:(NotificationModel *)model userID:(NSString *)uid {
    return [self initWithModel:model userID:uid onDismiss:nil];
}

- (void)dealloc {
    [self.summaryOrderListener remove];
    self.summaryOrderListener = nil;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.routePayload = [NotificationManager routingPayloadForNotificationModel:self.model];

    [self setupNavigationBar];
    [self setupScrollHierarchy];
    [self rebuildContent];

    // Mark as read immediately on open
    if (!self.model.isRead) {
        self.model.isRead = YES;
        [self updateReadButtonAppearance];
        [[NotificationManager shared] markRead:self.model forUser:self.uid completion:nil];
    }

    [self startOrderSummaryListenerIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    BOOL wide = (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.view.bounds.size.width >= 640.0);
    if (wide != self.isWideLayout) {
        self.isWideLayout = wide;
        [self rebuildContent];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL wide = (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.view.bounds.size.width >= 640.0);
    if (wide != self.isWideLayout) {
        self.isWideLayout = wide;
        [self rebuildContent];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return (self.navigationController.viewControllers.count > 1);
}

#pragma mark - Navigation Bar

- (void)setupNavigationBar {
    _dossierNavBarView = [[UIView alloc] init];
    _dossierNavBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _dossierNavBarView.backgroundColor = [UIColor ppElevatedSurface];
    _dossierNavBarView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:_dossierNavBarView];

    UIView *hairline = [[UIView alloc] init];
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    hairline.backgroundColor = [UIColor ppBorder];
    [_dossierNavBarView addSubview:hairline];

    UIView *barContent = [[UIView alloc] init];
    barContent.translatesAutoresizingMaskIntoConstraints = NO;
    barContent.backgroundColor = UIColor.clearColor;
    barContent.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_dossierNavBarView addSubview:barContent];

    // 1. Back Button
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *backImageName = [Language isRTL] ? @"chevron.right" : @"chevron.left";
    UIImage *backImg = [UIImage systemImageNamed:backImageName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold]];
    [backBtn setImage:backImg forState:UIControlStateNormal];
    backBtn.tintColor = [UIColor ppTextPrimary];
    [backBtn addTarget:self action:@selector(handleBackAction) forControlEvents:UIControlEventTouchUpInside];
    _backButton = backBtn;
    [barContent addSubview:_backButton];

    // 2. Title Stack
    UIStackView *titleStack = [[UIStackView alloc] init];
    titleStack.translatesAutoresizingMaskIntoConstraints = NO;
    titleStack.axis = UILayoutConstraintAxisVertical;
    titleStack.alignment = UIStackViewAlignmentCenter;
    titleStack.spacing = 1.0;
    titleStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [barContent addSubview:titleStack];

    _navEyebrowLabel = [[UILabel alloc] init];
    _navEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _navEyebrowLabel.text = [Language isRTL] ? @"مركز التنبيهات والعمليات" : @"OPERATIONS & NOTIFICATIONS";
    _navEyebrowLabel.font = [Styling fontBold:10.5];
    _navEyebrowLabel.textColor = [UIColor ppTextTertiary];
    _navEyebrowLabel.textAlignment = NSTextAlignmentCenter;
    [titleStack addArrangedSubview:_navEyebrowLabel];

    _navTitleLabel = [[UILabel alloc] init];
    _navTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _navTitleLabel.text = [Language isRTL] ? @"تفاصيل التنبيه" : @"Notification Dossier";
    _navTitleLabel.font = [Styling fontBold:16.5];
    _navTitleLabel.textColor = [UIColor ppTextPrimary];
    _navTitleLabel.textAlignment = NSTextAlignmentCenter;
    [titleStack addArrangedSubview:_navTitleLabel];

    // 3. Trailing Action Icons
    UIStackView *actionsCluster = [[UIStackView alloc] init];
    actionsCluster.translatesAutoresizingMaskIntoConstraints = NO;
    actionsCluster.axis = UILayoutConstraintAxisHorizontal;
    actionsCluster.alignment = UIStackViewAlignmentCenter;
    actionsCluster.spacing = 8.0;
    actionsCluster.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [barContent addSubview:actionsCluster];

    _clipboardNavButton = [self makeNavCircleButtonWithIcon:@"doc.on.doc"
                                                 color:[UIColor ppPrimary]
                                                action:@selector(handleCopyFullText)];
    _clipboardNavButton.accessibilityLabel = [Language isRTL] ? @"نسخ نص الإشعار" : @"Copy notification text";
    [actionsCluster addArrangedSubview:_clipboardNavButton];

    _shareNavButton = [self makeNavCircleButtonWithIcon:@"square.and.arrow.up"
                                                  color:[UIColor ppPrimary]
                                                 action:@selector(handleShareAction)];
    _shareNavButton.accessibilityLabel = [Language isRTL] ? @"مشاركة التنبيه" : @"Share notification";
    [actionsCluster addArrangedSubview:_shareNavButton];

    _readStatusNavButton = [self makeNavCircleButtonWithIcon:(self.model.isRead ? @"envelope.fill" : @"envelope.open.fill")
                                                       color:[UIColor ppPrimary]
                                                      action:@selector(handleToggleReadStatus)];
    _readStatusNavButton.accessibilityLabel = [Language isRTL] ? @"تبديل حالة القراءة" : @"Toggle read status";
    [actionsCluster addArrangedSubview:_readStatusNavButton];

    [NSLayoutConstraint activateConstraints:@[
        [_dossierNavBarView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_dossierNavBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_dossierNavBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_dossierNavBarView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:56.0],

        [hairline.leadingAnchor constraintEqualToAnchor:_dossierNavBarView.leadingAnchor],
        [hairline.trailingAnchor constraintEqualToAnchor:_dossierNavBarView.trailingAnchor],
        [hairline.bottomAnchor constraintEqualToAnchor:_dossierNavBarView.bottomAnchor],
        [hairline.heightAnchor constraintEqualToConstant:0.5],

        [barContent.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [barContent.bottomAnchor constraintEqualToAnchor:_dossierNavBarView.bottomAnchor constant:-4.0],
        [barContent.leadingAnchor constraintEqualToAnchor:_dossierNavBarView.leadingAnchor constant:14.0],
        [barContent.trailingAnchor constraintEqualToAnchor:_dossierNavBarView.trailingAnchor constant:-14.0],

        [_backButton.leadingAnchor constraintEqualToAnchor:barContent.leadingAnchor],
        [_backButton.centerYAnchor constraintEqualToAnchor:barContent.centerYAnchor],
        [_backButton.widthAnchor constraintEqualToConstant:44.0],
        [_backButton.heightAnchor constraintEqualToConstant:44.0],

        [titleStack.centerXAnchor constraintEqualToAnchor:barContent.centerXAnchor],
        [titleStack.centerYAnchor constraintEqualToAnchor:barContent.centerYAnchor],
        [titleStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:_backButton.trailingAnchor constant:8.0],
        [titleStack.trailingAnchor constraintLessThanOrEqualToAnchor:actionsCluster.leadingAnchor constant:-8.0],

        [actionsCluster.trailingAnchor constraintEqualToAnchor:barContent.trailingAnchor],
        [actionsCluster.centerYAnchor constraintEqualToAnchor:barContent.centerYAnchor]
    ]];
}

- (UIButton *)makeNavCircleButtonWithIcon:(NSString *)iconName color:(UIColor *)color action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *img = [UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightSemibold]];
    [btn setImage:img forState:UIControlStateNormal];
    btn.tintColor = color;
    btn.backgroundColor = [color colorWithAlphaComponent:0.08];
    btn.layer.borderWidth = 0.8;
    btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(btn, 18.0);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:36.0],
        [btn.heightAnchor constraintEqualToConstant:36.0]
    ]];
    return btn;
}

#pragma mark - Scroll & Content Hierarchy

- (void)setupScrollHierarchy {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _contentContainer = [[UIView alloc] init];
    _contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentContainer];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.dossierNavBarView.bottomAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_contentContainer.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [_contentContainer.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [_contentContainer.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [_contentContainer.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [_contentContainer.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor]
    ]];
}

#pragma mark - Content Builder & Layout Adapters

- (void)rebuildContent {
    // Clear old layout
    for (UIView *v in self.contentContainer.subviews) {
        [v removeFromSuperview];
    }
    if (self.actionDockContainer) {
        [self.actionDockContainer removeFromSuperview];
        self.actionDockContainer = nil;
    }

    // Build fresh individual cards
    self.heroCardView = [self buildHeroCard];
    self.bodyCardView = [self buildBodyCard];
    self.contextCardView = [self buildContextCardIfNeeded];
    self.metadataCardView = [self buildMetadataCard];

    if (self.isWideLayout) {
        [self buildWideiPadLayout];
    } else {
        [self buildCompactiPhoneLayout];
    }
}

- (void)buildCompactiPhoneLayout {
    self.scrollView.contentInset = UIEdgeInsetsMake(16.0, 0.0, 110.0, 0.0);

    _iphoneContentStack = [[UIStackView alloc] init];
    _iphoneContentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _iphoneContentStack.axis = UILayoutConstraintAxisVertical;
    _iphoneContentStack.spacing = 16.0;
    _iphoneContentStack.alignment = UIStackViewAlignmentFill;
    [self.contentContainer addSubview:_iphoneContentStack];

    [_iphoneContentStack addArrangedSubview:self.heroCardView];
    [_iphoneContentStack addArrangedSubview:self.bodyCardView];
    if (self.contextCardView) {
        [_iphoneContentStack addArrangedSubview:self.contextCardView];
    }
    [_iphoneContentStack addArrangedSubview:self.metadataCardView];

    [NSLayoutConstraint activateConstraints:@[
        [_iphoneContentStack.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [_iphoneContentStack.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16.0],
        [_iphoneContentStack.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16.0],
        [_iphoneContentStack.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-20.0],
    ]];

    // Pinned Bottom Frosted Glass Dock
    [self setupPinnedActionDock];
}

- (void)buildWideiPadLayout {
    self.scrollView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 32.0, 0.0);

    _ipadWingsStack = [[UIStackView alloc] init];
    _ipadWingsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _ipadWingsStack.axis = UILayoutConstraintAxisHorizontal;
    _ipadWingsStack.spacing = 20.0;
    _ipadWingsStack.alignment = UIStackViewAlignmentTop;
    _ipadWingsStack.distribution = UIStackViewDistributionFill;
    _ipadWingsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentContainer addSubview:_ipadWingsStack];

    // Leading Wing (~62%): Hero, Narrative, and Domain Context
    _ipadLeadingWing = [[UIStackView alloc] init];
    _ipadLeadingWing.translatesAutoresizingMaskIntoConstraints = NO;
    _ipadLeadingWing.axis = UILayoutConstraintAxisVertical;
    _ipadLeadingWing.spacing = 16.0;
    _ipadLeadingWing.alignment = UIStackViewAlignmentFill;
    [_ipadWingsStack addArrangedSubview:_ipadLeadingWing];

    [_ipadLeadingWing addArrangedSubview:self.heroCardView];
    [_ipadLeadingWing addArrangedSubview:self.bodyCardView];
    if (self.contextCardView) {
        [_ipadLeadingWing addArrangedSubview:self.contextCardView];
    }

    // Trailing Wing (~38%): Command Action Center & Metadata Matrix
    _ipadTrailingWing = [[UIStackView alloc] init];
    _ipadTrailingWing.translatesAutoresizingMaskIntoConstraints = NO;
    _ipadTrailingWing.axis = UILayoutConstraintAxisVertical;
    _ipadTrailingWing.spacing = 16.0;
    _ipadTrailingWing.alignment = UIStackViewAlignmentFill;
    [_ipadWingsStack addArrangedSubview:_ipadTrailingWing];

    UIView *ipadActionCard = [self buildInlineActionCardForiPad];
    if (ipadActionCard) {
        [_ipadTrailingWing addArrangedSubview:ipadActionCard];
    }
    [_ipadTrailingWing addArrangedSubview:self.metadataCardView];

    [NSLayoutConstraint activateConstraints:@[
        [_ipadWingsStack.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [_ipadWingsStack.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:24.0],
        [_ipadWingsStack.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-24.0],
        [_ipadWingsStack.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-24.0],

        [_ipadLeadingWing.widthAnchor constraintEqualToAnchor:_ipadWingsStack.widthAnchor multiplier:0.60 constant:-10.0]
    ]];
}

#pragma mark - Card Builders

- (UIView *)buildHeroCard {
    UIView *card = [self makeElevatedCard];

    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *orderID = PPNotificationDetailFirstStringForKeys(meta, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    NSString *type = PPNotificationDetailFirstStringForKeys(meta, @[@"notificationType", @"type", @"eventKey", @"route"]);
    BOOL isProviderOrderCancellation = PPNotificationDetailIsProviderOrderCancellation(self.routePayload);
    NSString *title = [self.model pp_localizedTitleForCurrentLanguage];
    if (title.length == 0) title = self.model.title ?: @"";

    UIColor *crestAccent = [UIColor ppPrimary];
    NSString *crestSymbol = @"bell.badge.fill";
    NSString *categoryName = kLang(@"Notification_Dossier_Category_System");

    if (isProviderOrderCancellation) {
        crestAccent = [UIColor colorWithRed:0.78 green:0.22 blue:0.18 alpha:1.0];
        crestSymbol = @"xmark.circle.fill";
        categoryName = kLang(@"Notification_Dossier_Category_Order");
    } else if ([type containsString:@"chat"] || [type containsString:@"support"] || [title containsString:@"support"] || [title containsString:@"دعم"]) {
        crestAccent = [UIColor ppQuickActionServices] ?: [UIColor colorWithRed:0.02 green:0.65 blue:0.42 alpha:1.0];
        crestSymbol = @"bubble.left.and.bubble.right.fill";
        categoryName = kLang(@"Notification_Dossier_Category_Support");
    } else if (orderID.length > 0 || [type containsString:@"order"]) {
        crestAccent = [UIColor colorWithRed:0.85 green:0.47 blue:0.02 alpha:1.0];
        crestSymbol = @"bag.fill";
        categoryName = kLang(@"Notification_Dossier_Category_Order");
    } else if ([type containsString:@"fulfillment"]) {
        crestAccent = [UIColor colorWithRed:0.31 green:0.27 blue:0.90 alpha:1.0];
        crestSymbol = @"shippingbox.fill";
        categoryName = kLang(@"Notification_Dossier_Category_Fulfillment");
    } else if ([type containsString:@"delivery"]) {
        crestAccent = [UIColor colorWithRed:0.01 green:0.52 blue:0.78 alpha:1.0];
        crestSymbol = @"location.fill";
        categoryName = kLang(@"Notification_Dossier_Category_Delivery");
    }

    // 1. Icon Crest
    UIView *crestView = [[UIView alloc] init];
    crestView.translatesAutoresizingMaskIntoConstraints = NO;
    crestView.backgroundColor = [crestAccent colorWithAlphaComponent:0.12];
    crestView.layer.borderColor = [crestAccent colorWithAlphaComponent:0.24].CGColor;
    crestView.layer.borderWidth = 1.0;
    PPApplyContinuousCorners(crestView, 18.0);
    [card addSubview:crestView];

    UIImageView *symbolView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:crestSymbol]];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.tintColor = crestAccent;
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    [crestView addSubview:symbolView];

    // 2. Category Pill
    UIView *catPill = [[UIView alloc] init];
    catPill.translatesAutoresizingMaskIntoConstraints = NO;
    catPill.backgroundColor = [crestAccent colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(catPill, PPCornerPill);
    [card addSubview:catPill];

    UILabel *catLabel = [[UILabel alloc] init];
    catLabel.translatesAutoresizingMaskIntoConstraints = NO;
    catLabel.font = [Styling fontBold:11.5];
    catLabel.textColor = crestAccent;
    catLabel.text = categoryName;
    [catPill addSubview:catLabel];

    // 3. Read Telemetry Badge
    _statusBadgePill = [[UIView alloc] init];
    _statusBadgePill.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgePill.backgroundColor = self.model.isRead ? [[UIColor ppSuccess] colorWithAlphaComponent:0.10] : [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(_statusBadgePill, PPCornerPill);
    [card addSubview:_statusBadgePill];

    _statusBadgeLabel = [[UILabel alloc] init];
    _statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgeLabel.font = [Styling fontBold:11.0];
    _statusBadgeLabel.textColor = self.model.isRead ? [UIColor ppSuccess] : [UIColor ppPrimary];
    _statusBadgeLabel.text = self.model.isRead ? kLang(@"Read") : kLang(@"Unread");
    [_statusBadgePill addSubview:_statusBadgeLabel];

    // 4. Localized Timestamp
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.font = [Styling fontMedium:12.5];
    timeLabel.textColor = [UIColor ppTextSecondary];
    timeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    timeLabel.text = [fmt stringFromDate:self.model.createdAt ?: [NSDate date]];
    [card addSubview:timeLabel];

    // 5. Headline Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:22.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    [card addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [crestView.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [crestView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [crestView.widthAnchor constraintEqualToConstant:52.0],
        [crestView.heightAnchor constraintEqualToConstant:52.0],

        [symbolView.centerXAnchor constraintEqualToAnchor:crestView.centerXAnchor],
        [symbolView.centerYAnchor constraintEqualToAnchor:crestView.centerYAnchor],
        [symbolView.widthAnchor constraintEqualToConstant:26.0],
        [symbolView.heightAnchor constraintEqualToConstant:26.0],

        [catPill.centerYAnchor constraintEqualToAnchor:crestView.centerYAnchor],
        [catPill.leadingAnchor constraintEqualToAnchor:crestView.trailingAnchor constant:12.0],
        [catPill.heightAnchor constraintEqualToConstant:26.0],

        [catLabel.leadingAnchor constraintEqualToAnchor:catPill.leadingAnchor constant:10.0],
        [catLabel.trailingAnchor constraintEqualToAnchor:catPill.trailingAnchor constant:-10.0],
        [catLabel.centerYAnchor constraintEqualToAnchor:catPill.centerYAnchor],

        [_statusBadgePill.centerYAnchor constraintEqualToAnchor:crestView.centerYAnchor],
        [_statusBadgePill.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [_statusBadgePill.heightAnchor constraintEqualToConstant:26.0],

        [_statusBadgeLabel.leadingAnchor constraintEqualToAnchor:_statusBadgePill.leadingAnchor constant:10.0],
        [_statusBadgeLabel.trailingAnchor constraintEqualToAnchor:_statusBadgePill.trailingAnchor constant:-10.0],
        [_statusBadgeLabel.centerYAnchor constraintEqualToAnchor:_statusBadgePill.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:crestView.bottomAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [timeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [timeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [timeLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [timeLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    return card;
}

- (UIView *)buildBodyCard {
    UIView *card = [self makeElevatedCard];

    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = [Language isRTL] ? @"نص الإشعار والتفاصيل" : @"Notification Narrative";
    header.font = [Styling fontBold:14.5];
    header.textColor = [UIColor ppTextSecondary];
    header.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:header];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [copyBtn setTitle:kLang(@"Notification_Dossier_Action_CopyText") forState:UIControlStateNormal];
    [copyBtn setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    copyBtn.tintColor = [UIColor ppPrimary];
    copyBtn.titleLabel.font = [Styling fontBold:12.0];
    [copyBtn addTarget:self action:@selector(handleCopyFullText) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:copyBtn];

    NSString *body = [self.model pp_localizedBodyForCurrentLanguage];
    if (body.length == 0) body = self.model.body ?: @"";

    UILabel *bodyLabel = [[UILabel alloc] init];
    bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    bodyLabel.font = [Styling fontRegular:16.0];
    bodyLabel.textColor = [UIColor ppTextPrimary];
    bodyLabel.numberOfLines = 0;
    bodyLabel.textAlignment = Language.alignmentForCurrentLanguage;
    bodyLabel.text = body;
    [card addSubview:bodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],

        [copyBtn.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [copyBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [copyBtn.leadingAnchor constraintGreaterThanOrEqualToAnchor:header.trailingAnchor constant:8.0],

        [bodyLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [bodyLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [bodyLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [bodyLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    return card;
}

- (nullable UIView *)buildContextCardIfNeeded {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    PPProNotificationTargetKind targetKind = [NotificationManager targetKindForPayload:self.routePayload];

    // Case A: Support / Chat Notification
    if (targetKind == PPProNotificationTargetKindChat || [self.model.title containsString:@"support"] || [self.model.title containsString:@"دعم"]) {
        UIView *card = [self makeElevatedCard];
        UIColor *chatColor = [UIColor ppQuickActionServices] ?: [UIColor colorWithRed:0.02 green:0.65 blue:0.42 alpha:1.0];

        UILabel *header = [[UILabel alloc] init];
        header.translatesAutoresizingMaskIntoConstraints = NO;
        header.text = kLang(@"Notification_Dossier_Context_SupportTitle");
        header.font = [Styling fontBold:14.5];
        header.textColor = chatColor;
        header.textAlignment = Language.alignmentForCurrentLanguage;
        [card addSubview:header];

        UILabel *tipLabel = [[UILabel alloc] init];
        tipLabel.translatesAutoresizingMaskIntoConstraints = NO;
        tipLabel.font = [Styling fontMedium:13.5];
        tipLabel.textColor = [UIColor ppTextPrimary];
        tipLabel.numberOfLines = 0;
        tipLabel.textAlignment = Language.alignmentForCurrentLanguage;
        tipLabel.text = kLang(@"Notification_Dossier_Context_SupportTip");
        [card addSubview:tipLabel];

        NSString *threadID = PPNotificationDetailFirstStringForKeys(meta, @[@"conversationId", @"threadId", @"threadID"]);
        UIView *threadRow = [self makeMetaRow:([Language isRTL] ? @"معرف المحادثة" : @"Thread ID")
                                         val:(threadID.length ? threadID : ([Language isRTL] ? @"محادثة دعم عامة" : @"General Support"))];
        [card addSubview:threadRow];

        [NSLayoutConstraint activateConstraints:@[
            [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
            [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

            [tipLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8.0],
            [tipLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [tipLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

            [threadRow.topAnchor constraintEqualToAnchor:tipLabel.bottomAnchor constant:12.0],
            [threadRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [threadRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
            [threadRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
        ]];
        return card;
    }

    // Case B: Order / Fulfillment Notification
    NSString *orderID = PPNotificationDetailFirstStringForKeys(meta, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    if (orderID.length > 0 || targetKind == PPProNotificationTargetKindDeliveryOrder || targetKind == PPProNotificationTargetKindFulfillment) {
        UIView *card = [self makeElevatedCard];
        UIColor *orderColor = [UIColor colorWithRed:0.85 green:0.47 blue:0.02 alpha:1.0];

        UILabel *header = [[UILabel alloc] init];
        header.translatesAutoresizingMaskIntoConstraints = NO;
        header.text = kLang(@"Notification_RequestSummaryTitle");
        header.font = [Styling fontBold:14.5];
        header.textColor = orderColor;
        header.textAlignment = Language.alignmentForCurrentLanguage;
        [card addSubview:header];

        UIStackView *rowsStack = [[UIStackView alloc] init];
        rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
        rowsStack.axis = UILayoutConstraintAxisVertical;
        rowsStack.spacing = 8.0;
        [card addSubview:rowsStack];

        NSString *displayOrder = orderID.length ? orderID : (self.summaryOrder ? [self.summaryOrder bestOrderNumber] : @"-");
        [rowsStack addArrangedSubview:[self makeMetaRow:kLang(@"Notification_RequestSummaryOrder") val:displayOrder]];

        if (self.summaryOrder) {
            NSString *pickup = [self.summaryOrder pp_pickupLocationSummary];
            if (pickup.length) {
                [rowsStack addArrangedSubview:[self makeMetaRow:([Language isRTL] ? @"موقع الفرع / الاستلام" : @"Pickup Branch") val:pickup]];
            }
            NSString *dest = [self.summaryOrder pp_deliveryAreaSummary];
            if (dest.length) {
                [rowsStack addArrangedSubview:[self makeMetaRow:([Language isRTL] ? @"منطقة التوصيل" : @"Delivery Zone") val:dest]];
            }
            NSString *status = [self.summaryOrder displayStatus];
            if (status.length) {
                [rowsStack addArrangedSubview:[self makeMetaRow:([Language isRTL] ? @"حالة الطلب" : @"Order Status") val:status]];
            }
        }

        [NSLayoutConstraint activateConstraints:@[
            [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
            [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

            [rowsStack.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
            [rowsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [rowsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
            [rowsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
        ]];
        return card;
    }

    return nil;
}

- (UIView *)buildMetadataCard {
    UIView *card = [self makeElevatedCard];

    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = kLang(@"Notification_Dossier_Meta_Title");
    header.font = [Styling fontBold:14.5];
    header.textColor = [UIColor ppTextSecondary];
    header.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:header];

    UIStackView *rowsStack = [[UIStackView alloc] init];
    rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowsStack.axis = UILayoutConstraintAxisVertical;
    rowsStack.spacing = 8.0;
    [card addSubview:rowsStack];

    [rowsStack addArrangedSubview:[self makeMetaRow:kLang(@"Notification_Dossier_Meta_NID") val:self.model.nid ?: @"-"]];
    if (self.model.targetUserID.length > 0) {
        [rowsStack addArrangedSubview:[self makeMetaRow:kLang(@"Notification_Dossier_Meta_Target") val:self.model.targetUserID]];
    }

    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    if (meta[@"route"]) {
        [rowsStack addArrangedSubview:[self makeMetaRow:kLang(@"Notification_Dossier_Meta_Route") val:[NSString stringWithFormat:@"%@", meta[@"route"]]]];
    }
    if (self.model.sourcePath.length > 0) {
        [rowsStack addArrangedSubview:[self makeMetaRow:kLang(@"Notification_Dossier_Meta_Source") val:self.model.sourcePath]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [rowsStack.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [rowsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [rowsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [rowsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    return card;
}

#pragma mark - Primary Action & Dynamic Cockpit

- (NSString *)resolvedActionTitle {
    PPProNotificationTargetKind targetKind = [NotificationManager targetKindForPayload:self.routePayload];
    switch (targetKind) {
        case PPProNotificationTargetKindChat:
            return kLang(@"Notification_CTA_OpenChat");
        case PPProNotificationTargetKindFulfillment:
            return kLang(@"Notification_CTA_OpenFulfillment");
        case PPProNotificationTargetKindDeliveryOrder:
        case PPProNotificationTargetKindCompanyDelivery:
            return kLang(@"Notification_CTA_OpenDelivery");
        default:
            return kLang(@"Notification_Dossier_Action_CopyText");
    }
}

- (NSString *)resolvedActionSubtitle {
    PPProNotificationTargetKind targetKind = [NotificationManager targetKindForPayload:self.routePayload];
    switch (targetKind) {
        case PPProNotificationTargetKindChat:
            return kLang(@"Notification_CTA_ChatSubtitle");
        case PPProNotificationTargetKindFulfillment:
            return kLang(@"Notification_CTA_OrderSubtitle");
        case PPProNotificationTargetKindDeliveryOrder:
        case PPProNotificationTargetKindCompanyDelivery:
            return kLang(@"Notification_CTA_DeliverySubtitle");
        default:
            return kLang(@"Notification_CTA_SystemSubtitle");
    }
}

- (void)setupPinnedActionDock {
    self.actionDockContainer = [[UIView alloc] init];
    self.actionDockContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionDockContainer.backgroundColor = UIColor.clearColor;
    self.actionDockContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.actionDockContainer];

    // Blur Backing
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight];
    UIVisualEffectView *dockBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    dockBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    dockBlurView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    dockBlurView.layer.borderWidth = 0.5;
    [self.actionDockContainer addSubview:dockBlurView];

    // Button
    self.primaryActionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.primaryActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryActionButton.backgroundColor = [UIColor ppPrimary];
    [self.primaryActionButton setTitle:[self resolvedActionTitle] forState:UIControlStateNormal];
    [self.primaryActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.primaryActionButton.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(self.primaryActionButton, 18.0);
    PPApplyButtonShadow(self.primaryActionButton);

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
    UIImage *arrow = [[UIImage systemImageNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"] imageWithConfiguration:symConfig];
    [self.primaryActionButton setImage:arrow forState:UIControlStateNormal];
    self.primaryActionButton.tintColor = UIColor.whiteColor;
    self.primaryActionButton.imageEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 8, 0, -8) : UIEdgeInsetsMake(0, -8, 0, 8);
    [self.primaryActionButton addTarget:self action:@selector(handlePrimaryAction) forControlEvents:UIControlEventTouchUpInside];
    [self.actionDockContainer addSubview:self.primaryActionButton];

    // Accurate Subtitle
    self.actionSubtitleLabel = [[UILabel alloc] init];
    self.actionSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionSubtitleLabel.font = [Styling fontMedium:11.0];
    self.actionSubtitleLabel.textColor = [UIColor ppTextSecondary];
    self.actionSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.actionSubtitleLabel.text = [self resolvedActionSubtitle];
    self.actionSubtitleLabel.numberOfLines = 1;
    [self.actionDockContainer addSubview:self.actionSubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionDockContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.actionDockContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.actionDockContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [dockBlurView.topAnchor constraintEqualToAnchor:self.actionDockContainer.topAnchor],
        [dockBlurView.leadingAnchor constraintEqualToAnchor:self.actionDockContainer.leadingAnchor],
        [dockBlurView.trailingAnchor constraintEqualToAnchor:self.actionDockContainer.trailingAnchor],
        [dockBlurView.bottomAnchor constraintEqualToAnchor:self.actionDockContainer.bottomAnchor],

        [self.primaryActionButton.topAnchor constraintEqualToAnchor:self.actionDockContainer.topAnchor constant:12.0],
        [self.primaryActionButton.leadingAnchor constraintEqualToAnchor:self.actionDockContainer.leadingAnchor constant:16.0],
        [self.primaryActionButton.trailingAnchor constraintEqualToAnchor:self.actionDockContainer.trailingAnchor constant:-16.0],
        [self.primaryActionButton.heightAnchor constraintEqualToConstant:52.0],

        [self.actionSubtitleLabel.topAnchor constraintEqualToAnchor:self.primaryActionButton.bottomAnchor constant:8.0],
        [self.actionSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.actionDockContainer.leadingAnchor constant:20.0],
        [self.actionSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.actionDockContainer.trailingAnchor constant:-20.0],
        [self.actionSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8.0]
    ]];
}

- (UIView *)buildInlineActionCardForiPad {
    UIView *card = [self makeElevatedCard];

    UILabel *header = [[UILabel alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = [Language isRTL] ? @"مركز الإجراءات المباشرة" : @"Command Action Center";
    header.font = [Styling fontBold:15.0];
    header.textColor = [UIColor ppTextSecondary];
    header.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:header];

    UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    actionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    actionBtn.backgroundColor = [UIColor ppPrimary];
    [actionBtn setTitle:[self resolvedActionTitle] forState:UIControlStateNormal];
    [actionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    actionBtn.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(actionBtn, 18.0);
    PPApplyButtonShadow(actionBtn);

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
    UIImage *arrow = [[UIImage systemImageNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"] imageWithConfiguration:symConfig];
    [actionBtn setImage:arrow forState:UIControlStateNormal];
    actionBtn.tintColor = UIColor.whiteColor;
    actionBtn.imageEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 8, 0, -8) : UIEdgeInsetsMake(0, -8, 0, 8);
    [actionBtn addTarget:self action:@selector(handlePrimaryAction) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:actionBtn];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.font = [Styling fontMedium:12.0];
    subLabel.textColor = [UIColor ppTextSecondary];
    subLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subLabel.text = [self resolvedActionSubtitle];
    subLabel.numberOfLines = 0;
    [card addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [actionBtn.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14.0],
        [actionBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [actionBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [actionBtn.heightAnchor constraintEqualToConstant:52.0],

        [subLabel.topAnchor constraintEqualToAnchor:actionBtn.bottomAnchor constant:10.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [subLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [subLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    return card;
}

#pragma mark - Primary Action Execution (Intelligent Fall-Safe Routing)

- (void)handlePrimaryAction {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [haptic impactOccurred];
    }

    NSDictionary *payload = self.routePayload ?: @{};
    PPProNotificationTargetKind targetKind = [NotificationManager targetKindForPayload:payload];
    BOOL isProviderOrderCancellation = PPNotificationDetailIsProviderOrderCancellation(payload);

    // 1. Support / Chat Notification
    if (targetKind == PPProNotificationTargetKindChat || [self.model.title containsString:@"support"] || [self.model.title containsString:@"دعم"]) {
        NSString *threadID = PPNotificationDetailFirstStringForKeys(payload, @[@"conversationId", @"threadId", @"threadID"]);

        if (threadID.length > 0) {
            [PPHUD showIndeterminateIn:self.view title:kLang(@"Loading") subtitle:nil];
            FIRDocumentReference *threadRef = [[[FIRFirestore firestore] collectionWithPath:@"Chats"] documentWithPath:threadID];
            __weak typeof(self) weakSelf = self;
            [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [PPHUD dismiss];
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;

                    if (!error && snapshot.exists && snapshot.data) {
                        ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
                        thread.ID = snapshot.documentID;
                        PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
                        messagesVC.hidesBottomBarWhenPushed = YES;
                        [strongSelf.navigationController pushViewController:messagesVC animated:YES];
                    } else {
                        // Document unavailable or archived -> Gracefully route to Provider Customer Support Chats!
                        [strongSelf pp_openSupportChatsListGracefully];
                    }
                });
            }];
        } else {
            // No direct thread ID in payload -> Gracefully open Provider Customer Support Chats list directly!
            [self pp_openSupportChatsListGracefully];
        }
        return;
    }

    // 2. Fulfillment / Order Notification
    if (targetKind == PPProNotificationTargetKindFulfillment || isProviderOrderCancellation) {
        NSString *fulfillmentID = PPNotificationDetailFirstStringForKeys(payload, @[@"fulfillmentId", @"fulfillmentID"]);
        if (fulfillmentID.length > 0) {
            [PPHUD showIndeterminateIn:self.view title:kLang(@"Loading") subtitle:nil];
            FIRDocumentReference *ref = [[[FIRFirestore firestore] collectionWithPath:@"FulfillmentOrders"] documentWithPath:fulfillmentID];
            __weak typeof(self) weakSelf = self;
            [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [PPHUD dismiss];
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;

                    if (!error && snapshot.exists && snapshot.data) {
                        PPFulfillmentModel *model = [PPFulfillmentModel modelFromDictionary:snapshot.data fulfillmentID:snapshot.documentID];
                        if (model) {
                            PPFulfillmentDetailViewController *vc = [[PPFulfillmentDetailViewController alloc] initWithModel:model];
                            vc.hidesBottomBarWhenPushed = YES;
                            [strongSelf.navigationController pushViewController:vc animated:YES];
                            return;
                        }
                    }
                    [PPToast toast:kLang(@"Notification_RequestSummaryUnavailable") style:PPToastStyleInfo haptic:YES duration:2.0 position:PPToastPositionBottom inView:strongSelf.view];
                });
            }];
            return;
        }
    }

    // 3. Delivery Order
    if (targetKind == PPProNotificationTargetKindDeliveryOrder) {
        NSString *orderID = PPNotificationDetailFirstStringForKeys(payload, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
        if (orderID.length > 0) {
            [PPHUD showIndeterminateIn:self.view title:kLang(@"Loading") subtitle:nil];
            FIRDocumentReference *ref = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
            __weak typeof(self) weakSelf = self;
            [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [PPHUD dismiss];
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;

                    if (!error && snapshot.exists && snapshot.data) {
                        PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:snapshot.data withID:snapshot.documentID];
                        if (order) {
                            PPDeliveryOrderDetailViewController *vc = [[PPDeliveryOrderDetailViewController alloc] initWithOrder:order];
                            vc.hidesBottomBarWhenPushed = YES;
                            [strongSelf.navigationController pushViewController:vc animated:YES];
                            return;
                        }
                    }
                    [PPToast toast:kLang(@"Notification_RequestSummaryUnavailable") style:PPToastStyleInfo haptic:YES duration:2.0 position:PPToastPositionBottom inView:strongSelf.view];
                });
            }];
            return;
        }
    }

    // 4. Default Routing with fail-safe messaging
    __weak typeof(self) weakSelf = self;
    [NotificationManager routePayload:payload
             fromNavigationController:self.navigationController
                            presenter:self
                           completion:^(BOOL handled) {
        if (!handled) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSString *msg = (targetKind == PPProNotificationTargetKindChat)
                ? kLang(@"Notification_Dossier_Error_ChatUnavailable")
                : kLang(@"Notification_RequestSummaryUnavailable");
            [PPToast toast:msg style:PPToastStyleInfo haptic:YES duration:2.2 position:PPToastPositionBottom inView:strongSelf.view];
        }
    }];
}

- (void)pp_openSupportChatsListGracefully {
    PPProviderSupportChatsViewController *chatsVC = [[PPProviderSupportChatsViewController alloc] init];
    chatsVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:chatsVC animated:YES];
    [PPToast toast:kLang(@"Notification_Dossier_Error_ChatUnavailable") style:PPToastStyleInfo haptic:NO duration:2.0 position:PPToastPositionBottom inView:self.view];
}

#pragma mark - Read Status & Actions

- (void)handleToggleReadStatus {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [haptic impactOccurred];
    }
    self.model.isRead = !self.model.isRead;
    [self updateReadButtonAppearance];

    [[NotificationManager shared] markRead:self.model forUser:self.uid completion:nil];

    NSString *msg = self.model.isRead
        ? ([Language isRTL] ? @"تم تحديد التنبيه كمقروء" : @"Marked as read")
        : ([Language isRTL] ? @"تم تحديد التنبيه كغير مقروء" : @"Marked as unread");
    [PPToast toast:msg style:PPToastStyleSuccess haptic:NO duration:1.5 position:PPToastPositionBottom inView:self.view];
}

- (void)updateReadButtonAppearance {
    NSString *icon = self.model.isRead ? @"envelope.fill" : @"envelope.open.fill";
    UIImage *img = [UIImage systemImageNamed:icon withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightSemibold]];
    [_readStatusNavButton setImage:img forState:UIControlStateNormal];

    if (_statusBadgeLabel && _statusBadgePill) {
        _statusBadgeLabel.text = self.model.isRead ? kLang(@"Read") : kLang(@"Unread");
        _statusBadgeLabel.textColor = self.model.isRead ? [UIColor ppSuccess] : [UIColor ppPrimary];
        _statusBadgePill.backgroundColor = self.model.isRead ? [[UIColor ppSuccess] colorWithAlphaComponent:0.10] : [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
    }
}

- (void)handleCopyFullText {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [haptic impactOccurred];
    }
    NSString *title = [self.model pp_localizedTitleForCurrentLanguage] ?: self.model.title ?: @"";
    NSString *body = [self.model pp_localizedBodyForCurrentLanguage] ?: self.model.body ?: @"";
    NSString *combined = [NSString stringWithFormat:@"%@\n\n%@", title, body];
    [UIPasteboard generalPasteboard].string = combined;
    [PPToast toast:kLang(@"Notification_Dossier_Action_Copied") style:PPToastStyleSuccess haptic:NO duration:1.5 position:PPToastPositionBottom inView:self.view];
}

- (void)handleShareAction {
    NSString *title = [self.model pp_localizedTitleForCurrentLanguage] ?: self.model.title ?: @"";
    NSString *body = [self.model pp_localizedBodyForCurrentLanguage] ?: self.model.body ?: @"";
    NSString *text = [NSString stringWithFormat:@"%@\n\n%@", title, body];
    UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        act.popoverPresentationController.sourceView = _shareNavButton;
        act.popoverPresentationController.sourceRect = _shareNavButton.bounds;
    }
    [self presentViewController:act animated:YES completion:nil];
}

- (void)handleBackAction {
    if (self.onDismiss) {
        self.onDismiss();
        return;
    }
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Live Summary Listener

- (void)startOrderSummaryListenerIfNeeded {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *orderID = PPNotificationDetailFirstStringForKeys(meta, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    if (orderID.length == 0 || self.summaryOrderListener) return;

    FIRDocumentReference *ref = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    self.summaryOrderListener = [ref addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (snapshot.exists && snapshot.data) {
                strongSelf.summaryOrder = [PPDeliveryOrderModel fromDictionary:snapshot.data withID:snapshot.documentID];
                [strongSelf rebuildContent];
            }
        });
    }];
}

#pragma mark - UI Helpers

- (UIView *)makeElevatedCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppSurfaceElevated];
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(card, PPCornerCard);
    PPApplyCardShadow(card);
    return card;
}

- (UIView *)makeMetaRow:(NSString *)key val:(NSString *)val {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor ppSurface];
    row.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    row.layer.borderWidth = 0.5;
    PPApplyContinuousCorners(row, PPCornerSmall);

    UILabel *keyLabel = [[UILabel alloc] init];
    keyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    keyLabel.font = [Styling fontMedium:13.0];
    keyLabel.textColor = [UIColor ppTextSecondary];
    keyLabel.text = key;
    keyLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:keyLabel];

    UILabel *valLabel = [[UILabel alloc] init];
    valLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valLabel.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightMedium];
    valLabel.textColor = [UIColor ppTextPrimary];
    valLabel.text = val;
    valLabel.textAlignment = [Language isRTL] ? NSTextAlignmentLeft : NSTextAlignmentRight;
    [row addSubview:valLabel];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:38.0],
        [keyLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [keyLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [valLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12.0],
        [valLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:keyLabel.trailingAnchor constant:12.0],
        [valLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];

    return row;
}

@end
