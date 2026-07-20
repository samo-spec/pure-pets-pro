//
//  PPDeliveryOrderDetailViewController.m
//  PurePetsPro
//
//  Premium delivery detail view with hero header, icon-enriched cards,
//  Beiruti fonts, modern section titles, and entrance animations.
//

#import "PPDeliveryOrderDetailViewController.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryManager.h"
#import "PPDeliveryStatusTimelineView.h"
#import "PPFirebaseCompat.h"
#import "ChatThreadModel.h"
#import "PPUserMessagesViewController.h"
#import "UserManager.h"
#import "UIImageView+WebCache.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

static CGFloat const kCardCornerRadius  = 24.0;
static CGFloat const kCardPadding       = 16.0;
static CGFloat const kSectionSpacing    = 16.0;
static CGFloat const kContentPadding    = 20.0;
static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

@interface PPDeliveryOrderDetailViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) PPDeliveryOrderModel *order;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView  *stackView;

// Sections
@property (nonatomic, strong) PPDeliveryStatusTimelineView *timelineView;
@property (nonatomic, strong) MKMapView *deliveryMapView;
@property (nonatomic, strong) UILabel *deliveryDistanceLabel;
@property (nonatomic, strong) UITextView *notesTextView;
@property (nonatomic, strong) UIButton   *actionButton;
@property (nonatomic, strong) UIButton   *reportIssueButton;

// Marketplace provider
@property (nonatomic, strong, nullable) UserModel *marketplaceProviderUser;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> marketplaceProviderListener;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) CLLocationCoordinate2D deliveryDestinationCoordinate;
@property (nonatomic, copy, nullable) NSString *geocodedDeliveryAddress;
@property (nonatomic, assign) BOOL isGeocodingDeliveryAddress;

// Floating action bar
@property (nonatomic, strong) UIView      *floatingActionBar;
@property (nonatomic, strong) UIStackView *floatingActionStack;

// Firestore listener
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> orderListener;

@end

@implementation PPDeliveryOrderDetailViewController

#pragma mark - Init

- (instancetype)initWithOrder:(PPDeliveryOrderModel *)order {
    self = [super init];
    if (self) {
        _order = order;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;

    [self setupScrollView];
    [self setupLocationManager];
    [self buildSections];
    [self startOrderListener];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"OrderDetails") showBack:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [self stopOrderListener];
    }
}

- (void)dealloc {
    [self stopOrderListener];
    [self.marketplaceProviderListener remove];
    self.marketplaceProviderListener = nil;
    self.locationManager.delegate = nil;
    [self.locationManager stopUpdatingLocation];
}

#pragma mark - Firestore Listener

- (void)startOrderListener {
    if (!self.order.orderId.length) return;

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"Orders"] documentWithPath:self.order.orderId];

    __weak typeof(self) weakSelf = self;
    self.orderListener = [docRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || !snapshot.exists) return;

        NSDictionary *data = snapshot.data;
        if (!data) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.order = [PPDeliveryOrderModel fromDictionary:data withID:snapshot.documentID];
            [strongSelf refreshUI];
        });
    }];
}

- (void)stopOrderListener {
    [self.orderListener remove];
    self.orderListener = nil;
}

#pragma mark - Setup UI

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _scrollView.contentInset = UIEdgeInsetsMake(0, 0, 140, 0);
    _scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 140, 0);
    [self.view addSubview:_scrollView];

    _stackView = [[UIStackView alloc] init];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = kSectionSpacing;
    _stackView.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_stackView];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_stackView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:kContentPadding],
        [_stackView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:kContentPadding],
        [_stackView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-kContentPadding],
        [_stackView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-kContentPadding],
        [_stackView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-2 * kContentPadding],
    ]];
}

- (void)setupLocationManager {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = 25.0;
    self.deliveryDestinationCoordinate = kCLLocationCoordinate2DInvalid;
}

- (void)buildSections {
    // Clear existing
    for (UIView *v in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    [self addHeroHeader];
    [self addCustomerInfoSection];
    [self addDeliveryLocationSection];
    [self addMarketplaceProviderSection];
    [self addOrderItemsSection];
    [self addPaymentSection];
    [self addTimelineSection];
    [self addDeliveryNotesSection];
    [self setupFloatingActionBar];
}

- (void)refreshUI {
    // Remove floating bar so buildSections can re-create it
    [_floatingActionBar removeFromSuperview];
    _floatingActionBar = nil;
    [self buildSections];
}

#pragma mark - Card Helper

- (UIView *)createCardWithContent:(void(^)(UIView *card))builder {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = kCardCornerRadius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.shadowColor = AppShadowColor.CGColor;
    card.layer.shadowOpacity = 0.06;
    card.layer.shadowOffset = CGSizeMake(0, 6);
    card.layer.shadowRadius = 16;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;

    // Inner container for clipping the accent stripe
    UIView *innerClip = [[UIView alloc] init];
    innerClip.translatesAutoresizingMaskIntoConstraints = NO;
    innerClip.clipsToBounds = YES;
    innerClip.layer.cornerRadius = kCardCornerRadius;
    innerClip.layer.cornerCurve = kCACornerCurveContinuous;
    innerClip.userInteractionEnabled = NO;
    [card addSubview:innerClip];

    // Left accent stripe (inside inner clip so it doesn't poke out)
    UIView *stripe = [[UIView alloc] init];
    stripe.translatesAutoresizingMaskIntoConstraints = NO;
    stripe.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.25];
    [innerClip addSubview:stripe];
    [NSLayoutConstraint activateConstraints:@[
        [innerClip.topAnchor constraintEqualToAnchor:card.topAnchor],
        [innerClip.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [innerClip.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [innerClip.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [stripe.leadingAnchor constraintEqualToAnchor:innerClip.leadingAnchor],
        [stripe.topAnchor constraintEqualToAnchor:innerClip.topAnchor constant:16],
        [stripe.bottomAnchor constraintEqualToAnchor:innerClip.bottomAnchor constant:-16],
        [stripe.widthAnchor constraintEqualToConstant:4],
    ]];

    if (builder) builder(card);
    return card;
}

- (UIView *)sectionTitleWithIcon:(NSString *)iconName text:(NSString *)text {
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 6;
    row.alignment = UIStackViewAlignmentCenter;

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = AppPrimaryClr;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    icon.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
    [icon.widthAnchor constraintEqualToConstant:14].active = YES;
    [icon.heightAnchor constraintEqualToConstant:14].active = YES;
    [row addArrangedSubview:icon];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = PPFontBold(12);
    lbl.textColor = AppPrimaryClr;
    lbl.text = [text uppercaseString];
    [row addArrangedSubview:lbl];

    return row;
}

- (UIView *)infoRowWithIcon:(NSString *)iconName iconColor:(UIColor *)iconColor text:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor {
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = iconColor;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
    icon.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
    [icon.widthAnchor constraintEqualToConstant:20].active = YES;
    [icon.heightAnchor constraintEqualToConstant: 20].active = YES;
    [row addArrangedSubview:icon];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = font;
    lbl.textColor = textColor;
    lbl.text = text;
    lbl.numberOfLines = 0;
    [row addArrangedSubview:lbl];

    return row;
}

- (UILabel *)valueLabel:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = font;
    lbl.textColor = color;
    lbl.text = text;
    lbl.numberOfLines = 0;
    return lbl;
}

#pragma mark - Hero Header

- (void)addHeroHeader {
    UIColor *statusColor = [self colorForStatus:self.order.deliveryStatus];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.layer.cornerRadius = kCardCornerRadius;
    header.layer.cornerCurve = kCACornerCurveContinuous;
    header.clipsToBounds = YES;
    header.backgroundColor = AppForgroundColr;

    // Shadow (applied on a wrapper since clipsToBounds clips shadows)
    UIView *shadowHost = [[UIView alloc] init];
    shadowHost.translatesAutoresizingMaskIntoConstraints = NO;
    shadowHost.backgroundColor = UIColor.clearColor;
    shadowHost.layer.cornerRadius = kCardCornerRadius;
    shadowHost.layer.cornerCurve = kCACornerCurveContinuous;
    shadowHost.layer.shadowColor = AppShadowColor.CGColor;
    shadowHost.layer.shadowOpacity = 0.06;
    shadowHost.layer.shadowOffset = CGSizeMake(0, 6);
    shadowHost.layer.shadowRadius = 16;
    [shadowHost addSubview:header];

    // Subtle border matching cell pattern
    header.layer.borderWidth = 0.5;
    header.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;

    // Left accent stripe — status-colored vertical bar (like cell)
    UIView *accentStripe = [[UIView alloc] init];
    accentStripe.translatesAutoresizingMaskIntoConstraints = NO;
    accentStripe.backgroundColor = statusColor;
    accentStripe.layer.cornerRadius = 2;
    accentStripe.clipsToBounds = YES;
    [header addSubview:accentStripe];

    // Decorative floating orbs — status tinted
    CGFloat orbInfo[][4] = { {50, -10, 10, 0.07}, {35, 200, 5, 0.05}, {25, 120, 120, 0.06} };
    for (int i = 0; i < 3; i++) {
        UIView *orb = [[UIView alloc] init];
        orb.translatesAutoresizingMaskIntoConstraints = NO;
        CGFloat sz = orbInfo[i][0];
        orb.backgroundColor = [statusColor colorWithAlphaComponent:orbInfo[i][3]];
        orb.layer.cornerRadius = sz / 2.0;
        [header addSubview:orb];
        [NSLayoutConstraint activateConstraints:@[
            [orb.widthAnchor constraintEqualToConstant:sz],
            [orb.heightAnchor constraintEqualToConstant:sz],
            [orb.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:orbInfo[i][1]],
            [orb.topAnchor constraintEqualToAnchor:header.topAnchor constant:orbInfo[i][2]],
        ]];
    }

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    [header addSubview:stack];

    // Order number large
    UILabel *orderNum = [self valueLabel:[NSString stringWithFormat:kLang(@"OrderNumber"), [self.order bestOrderNumber]]
                                    font:PPFontBold(24)
                                   color:PrimaryTextClr];
    [stack addArrangedSubview:orderNum];

    // Customer name
    UILabel *name = [self valueLabel:self.order.customerName.length ? self.order.customerName : @"—"
                                font:PPFontMedium(15)
                               color:SeconderyTextClr];
    [stack addArrangedSubview:name];

    // Order date (if available)
    if (self.order.createdAt) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateStyle = NSDateFormatterMediumStyle;
        df.timeStyle = NSDateFormatterShortStyle;
        UILabel *dateLbl = [self valueLabel:[df stringFromDate:self.order.createdAt]
                                       font:PPFontRegular(12)
                                      color:[SeconderyTextClr colorWithAlphaComponent:0.7]];
        [stack addArrangedSubview:dateLbl];
    }

    // Status pill — translucent semantic color bg, colored text (like cell)
    UIView *pillContainer = [[UIView alloc] init];
    pillContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *pill = [[UIView alloc] init];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.backgroundColor = [statusColor colorWithAlphaComponent:0.15];
    pill.layer.cornerRadius = 12;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    [pillContainer addSubview:pill];

    UILabel *pillLabel = [[UILabel alloc] init];
    pillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    pillLabel.font = PPFontBold(11);
    pillLabel.textColor = statusColor;
    pillLabel.text = [self.order displayStatus];
    [pill addSubview:pillLabel];

    [NSLayoutConstraint activateConstraints:@[
        [pill.leadingAnchor constraintEqualToAnchor:pillContainer.leadingAnchor],
        [pill.topAnchor constraintEqualToAnchor:pillContainer.topAnchor],
        [pill.bottomAnchor constraintEqualToAnchor:pillContainer.bottomAnchor],
        [pill.heightAnchor constraintEqualToConstant:24],
        [pillLabel.topAnchor constraintEqualToAnchor:pill.topAnchor constant:4],
        [pillLabel.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-4],
        [pillLabel.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:12],
        [pillLabel.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12],
    ]];

    [stack addArrangedSubview:pillContainer];

    // Branch badge — if branch is set
    NSString *branchDisplay = (self.order.branchName.length > 0) ? self.order.branchName : self.order.branchID;
    if (branchDisplay.length > 0) {
        UIView *branchContainer = [[UIView alloc] init];
        branchContainer.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *branchPill = [[UIView alloc] init];
        branchPill.translatesAutoresizingMaskIntoConstraints = NO;
        branchPill.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.15];
        branchPill.layer.cornerRadius = 12;
        branchPill.layer.cornerCurve = kCACornerCurveContinuous;
        [branchContainer addSubview:branchPill];

        UIImageView *branchIcon = [[UIImageView alloc] init];
        branchIcon.translatesAutoresizingMaskIntoConstraints = NO;
        branchIcon.contentMode = UIViewContentModeScaleAspectFit;
        branchIcon.tintColor = [UIColor systemOrangeColor];
        UIImageSymbolConfiguration *branchIconCfg = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightSemibold];
        branchIcon.image = [[UIImage systemImageNamed:@"building.2.fill"] imageWithConfiguration:branchIconCfg];
        [branchPill addSubview:branchIcon];

        UILabel *branchPillLabel = [[UILabel alloc] init];
        branchPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
        branchPillLabel.font = PPFontBold(11);
        branchPillLabel.textColor = [UIColor systemOrangeColor];
        branchPillLabel.text = [NSString stringWithFormat:@"%@: %@", kLang(@"Branch"), branchDisplay];
        [branchPill addSubview:branchPillLabel];

        [NSLayoutConstraint activateConstraints:@[
            [branchPill.leadingAnchor constraintEqualToAnchor:branchContainer.leadingAnchor],
            [branchPill.topAnchor constraintEqualToAnchor:branchContainer.topAnchor],
            [branchPill.bottomAnchor constraintEqualToAnchor:branchContainer.bottomAnchor],
            [branchPill.heightAnchor constraintEqualToConstant:24],
            [branchIcon.leadingAnchor constraintEqualToAnchor:branchPill.leadingAnchor constant:10],
            [branchIcon.centerYAnchor constraintEqualToAnchor:branchPill.centerYAnchor],
            [branchIcon.widthAnchor constraintEqualToConstant:14],
            [branchIcon.heightAnchor constraintEqualToConstant:14],
            [branchPillLabel.leadingAnchor constraintEqualToAnchor:branchIcon.trailingAnchor constant:4],
            [branchPillLabel.centerYAnchor constraintEqualToAnchor:branchPill.centerYAnchor],
            [branchPillLabel.trailingAnchor constraintEqualToAnchor:branchPill.trailingAnchor constant:-12],
        ]];

        [stack addArrangedSubview:branchContainer];
    }

    [NSLayoutConstraint activateConstraints:@[
        // Header pinned inside shadow host
        [header.topAnchor constraintEqualToAnchor:shadowHost.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:shadowHost.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:shadowHost.trailingAnchor],
        [header.bottomAnchor constraintEqualToAnchor:shadowHost.bottomAnchor],

        // Left accent stripe
        [accentStripe.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [accentStripe.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],
        [accentStripe.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-16],
        [accentStripe.widthAnchor constraintEqualToConstant:4],

        // Content stack — offset for accent stripe
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:kCardPadding + 6],
        [stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:kCardPadding + 6],
        [stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-kCardPadding],
        [stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-kCardPadding - 4],
    ]];

    [self.stackView addArrangedSubview:shadowHost];
}

#pragma mark - Customer Info Section

- (void)addCustomerInfoSection {
    __weak typeof(self) weakSelf = self;
    PPDeliveryOrderModel *order = self.order;
    NSString *currentDeliveryUserID = [FIRAuth auth].currentUser.uid ?: @"";
    BOOL canRevealCustomerPhone = [order pp_canRevealCustomerPhoneForDeliveryUserID:currentDeliveryUserID];
    BOOL isDeliveryAccepted = order.deliveryUserId.length > 0;
    BOOL isOfficialProfile = [self pp_isOfficialSupportProfile];
    NSString *exactLocation = [order pp_exactDeliveryLocationText];
    BOOL exactLocationVisible = [order pp_canRevealExactDeliveryLocation] && exactLocation.length > 0;
    NSString *customerLocation = exactLocationVisible ? exactLocation : [order pp_deliveryAreaSummary];

    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 0;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        // ── Section Header ──
        [stack addArrangedSubview:[weakSelf sectionTitleWithIcon:@"person.fill" text:kLang(@"Deliv_CustomerInfo")]];
        [stack setCustomSpacing:14 afterView:stack.arrangedSubviews.lastObject];

        // ── Customer Identity ──
        UILabel *nameLabel = [weakSelf valueLabel:order.customerName.length ? order.customerName : @"—"
                                             font:PPFontBold(20)
                                            color:PrimaryTextClr];
        [stack addArrangedSubview:nameLabel];
        [stack setCustomSpacing:3 afterView:nameLabel];

        UILabel *orderRef = [weakSelf valueLabel:[NSString stringWithFormat:kLang(@"OrderNumber"), [order bestOrderNumber]]
                                            font:PPFontRegular(13)
                                           color:[SeconderyTextClr colorWithAlphaComponent:0.7]];
        [stack addArrangedSubview:orderRef];
        [stack setCustomSpacing:16 afterView:orderRef];

        // ── Separator ──
        UIView *sep1 = [[UIView alloc] init];
        sep1.translatesAutoresizingMaskIntoConstraints = NO;
        sep1.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.07];
        [sep1.heightAnchor constraintEqualToConstant:0.5].active = YES;
        [stack addArrangedSubview:sep1];
        [stack setCustomSpacing:14 afterView:sep1];

        // ── Location ──
        if (customerLocation.length) {
            UIView *locRow = [weakSelf infoRowWithIcon:@"location.fill" iconColor:[UIColor systemOrangeColor]
                                                  text:customerLocation
                                                  font:PPFontRegular(14) textColor:PrimaryTextClr];
            [stack addArrangedSubview:locRow];
            [stack setCustomSpacing:10 afterView:locRow];
        }

        if (!exactLocationVisible && customerLocation.length) {
            UILabel *privacyNote = [weakSelf valueLabel:kLang(@"Deliv_ExactLocationAfterAccepting")
                                                   font:PPFontRegular(11)
                                                  color:[SeconderyTextClr colorWithAlphaComponent:0.65]];
            [stack addArrangedSubview:privacyNote];
            [stack setCustomSpacing:14 afterView:privacyNote];
        } else if (customerLocation.length) {
            [stack setCustomSpacing:14 afterView:stack.arrangedSubviews.lastObject];
        }

        // ── Contact Actions ──
        BOOL hasContactActions = canRevealCustomerPhone || exactLocationVisible;
        if (hasContactActions) {
            UIView *sep2 = [[UIView alloc] init];
            sep2.translatesAutoresizingMaskIntoConstraints = NO;
            sep2.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.07];
            [sep2.heightAnchor constraintEqualToConstant:0.5].active = YES;
            [stack addArrangedSubview:sep2];
            [stack setCustomSpacing:14 afterView:sep2];

            UIStackView *actionRow = [[UIStackView alloc] init];
            actionRow.translatesAutoresizingMaskIntoConstraints = NO;
            actionRow.axis = UILayoutConstraintAxisHorizontal;
            actionRow.spacing = 10;
            actionRow.distribution = UIStackViewDistributionFillEqually;
            [stack addArrangedSubview:actionRow];

            if (canRevealCustomerPhone) {
                UIButton *callBtn = [weakSelf contactActionPill:kLang(@"Call")
                                                           icon:@"phone.fill"
                                                         color:UIColor.systemGreenColor
                                                        action:@selector(callCustomer)];
                [actionRow addArrangedSubview:callBtn];

                UIButton *whatsappBtn = [weakSelf contactActionPill:kLang(@"WhatsApp")
                                                               icon:@"message.fill"
                                                             color:UIColor.systemGreenColor
                                                            action:@selector(openWhatsApp)];
                [actionRow addArrangedSubview:whatsappBtn];
            }

            if (exactLocationVisible) {
                UIButton *mapsBtn = [weakSelf contactActionPill:kLang(@"OpenInMaps")
                                                           icon:@"map.fill"
                                                         color:UIColor.systemBlueColor
                                                        action:@selector(openInMaps)];
                [actionRow addArrangedSubview:mapsBtn];
            }

            [stack setCustomSpacing:14 afterView:actionRow];
        }

        // ── Official Chat (only after acceptance) ──
        if (isOfficialProfile && isDeliveryAccepted && order.userId.length > 0) {
            UIView *sep3 = [[UIView alloc] init];
            sep3.translatesAutoresizingMaskIntoConstraints = NO;
            sep3.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.07];
            [sep3.heightAnchor constraintEqualToConstant:0.5].active = YES;
            [stack addArrangedSubview:sep3];
            [stack setCustomSpacing:14 afterView:sep3];

            UIButton *chatBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            chatBtn.translatesAutoresizingMaskIntoConstraints = NO;
            [chatBtn setTitle:[NSString stringWithFormat:@"  %@", kLang(@"Deliv_ChatWithCustomer")] forState:UIControlStateNormal];
            [chatBtn setImage:[UIImage systemImageNamed:@"message.fill"] forState:UIControlStateNormal];
            chatBtn.tintColor = UIColor.systemBlueColor;
            chatBtn.titleLabel.font = PPFontBold(14);
            chatBtn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
            chatBtn.layer.cornerRadius = 14;
            chatBtn.layer.cornerCurve = kCACornerCurveContinuous;
            [chatBtn addTarget:weakSelf action:@selector(officialSupportStartChat) forControlEvents:UIControlEventTouchUpInside];
            [chatBtn.heightAnchor constraintEqualToConstant:50].active = YES;
            [stack addArrangedSubview:chatBtn];
        }
    }];

    [self.stackView addArrangedSubview:card];
}

- (UIButton *)contactActionPill:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [color colorWithAlphaComponent:0.1];
    btn.layer.cornerRadius = 14;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.tintColor = color;
    btn.titleLabel.font = PPFontBold(12);
    [btn setTitle:title forState:UIControlStateNormal];
    if (iconName.length) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
        [btn setImage:image forState:UIControlStateNormal];
    }
    btn.contentEdgeInsets = UIEdgeInsetsMake(10, 8, 10, 8);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:46].active = YES;
    return btn;
}

#pragma mark - Delivery Location Section

- (BOOL)shouldShowDeliveryLocation {
    return [self.order pp_canRevealExactDeliveryLocation] &&
           [self.order pp_exactDeliveryLocationText].length > 0;
}

- (void)addDeliveryLocationSection {
    if (![self shouldShowDeliveryLocation]) return;

    PPDeliveryOrderModel *order = self.order;
    NSString *address = [order pp_exactDeliveryLocationText];
    if (address.length == 0) return;

    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 10;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        [stack addArrangedSubview:[self sectionTitleWithIcon:@"location.fill" text:kLang(@"Deliv_CustomerLocation")]];

        UILabel *subtitle = [self valueLabel:address
                                       font:PPFontRegular(13)
                                      color:SeconderyTextClr];
        [stack addArrangedSubview:subtitle];

        MKMapView *mapView = [[MKMapView alloc] init];
        mapView.translatesAutoresizingMaskIntoConstraints = NO;
        mapView.showsUserLocation = YES;
        mapView.showsCompass = YES;
        mapView.pitchEnabled = YES;
        mapView.rotateEnabled = YES;
        mapView.scrollEnabled = YES;
        mapView.layer.cornerRadius = 18;
        mapView.layer.cornerCurve = kCACornerCurveContinuous;
        mapView.layer.borderWidth = 0.5;
        mapView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        mapView.clipsToBounds = YES;
        self.deliveryMapView = mapView;
        [stack addArrangedSubview:mapView];
        [mapView.heightAnchor constraintEqualToConstant:184].active = YES;

        UIStackView *buttonRow = [[UIStackView alloc] init];
        buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
        buttonRow.axis = UILayoutConstraintAxisHorizontal;
        buttonRow.spacing = 8;
        buttonRow.distribution = UIStackViewDistributionFillEqually;
        [stack addArrangedSubview:buttonRow];

        UIButton *navigationBtn = [self premiumMapActionButton:kLang(@"Deliv_StartNavigation") icon:@"location.fill" color:UIColor.systemGreenColor action:@selector(startDeliveryNavigation)];
        UIButton *routeBtn = [self premiumMapActionButton:kLang(@"Deliv_ShowRoute") icon:@"arrow.triangle.turn.up.right.circle.fill" color:UIColor.systemBlueColor action:@selector(showDeliveryRoute)];
        UIButton *distanceBtn = [self premiumMapActionButton:kLang(@"Deliv_CalculateDistance") icon:@"ruler.fill" color:UIColor.systemIndigoColor action:@selector(calculateDeliveryDistance)];
        [buttonRow addArrangedSubview:navigationBtn];
        [buttonRow addArrangedSubview:routeBtn];
        [buttonRow addArrangedSubview:distanceBtn];

        UILabel *distanceLabel = [[UILabel alloc] init];
        distanceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        distanceLabel.font = PPFontMedium(12);
        distanceLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.82];
        distanceLabel.textAlignment = NSTextAlignmentCenter;
        distanceLabel.numberOfLines = 1;
        distanceLabel.text = self.deliveryDestinationCoordinate.latitude != 0.0 ? kLang(@"Deliv_DistancePending") : kLang(@"Deliv_DistancePending");
        self.deliveryDistanceLabel = distanceLabel;
        [stack addArrangedSubview:distanceLabel];

        CLLocationCoordinate2D coordinate = [self coordinateFromLocationPointString:order.deliveryLocationPoint];
        if (CLLocationCoordinate2DIsValid(coordinate)) {
            self.deliveryDestinationCoordinate = coordinate;
            [self applyDeliveryCoordinateToCurrentMap];
            if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                [self.locationManager requestWhenInUseAuthorization];
            }
            [self.locationManager startUpdatingLocation];
        } else {
            [self geocodeDeliveryAddress:address];
        }
    }];

    [self.stackView addArrangedSubview:card];
}

- (CLLocationCoordinate2D)coordinateFromLocationPointString:(NSString *)locationPoint {
    NSString *trimmed = [locationPoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return kCLLocationCoordinate2DInvalid;

    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@","];
    if (parts.count < 2) return kCLLocationCoordinate2DInvalid;

    double latitude = [[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] doubleValue];
    double longitude = [[parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] doubleValue];
    if (!isfinite(latitude) || !isfinite(longitude)) return kCLLocationCoordinate2DInvalid;

    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : kCLLocationCoordinate2DInvalid;
}

- (UIButton *)premiumMapActionButton:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [color colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 14;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = color;
    button.titleLabel.font = PPFontBold(11);
    [button setTitle:title forState:UIControlStateNormal];
    if (iconName.length) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
        [button setImage:image forState:UIControlStateNormal];
        [button setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    }
    button.contentEdgeInsets = UIEdgeInsetsMake(8, 6, 8, 6);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:42].active = YES;
    return button;
}

- (void)applyDeliveryCoordinateToCurrentMap {
    if (!CLLocationCoordinate2DIsValid(self.deliveryDestinationCoordinate)) return;

    MKCoordinateSpan span = MKCoordinateSpanMake(0.012, 0.012);
    MKCoordinateRegion region = MKCoordinateRegionMake(self.deliveryDestinationCoordinate, span);
    [self.deliveryMapView setRegion:region animated:YES];
    NSMutableArray<id<MKAnnotation>> *existingPins = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.deliveryMapView.annotations) {
        if (annotation != self.deliveryMapView.userLocation) {
            [existingPins addObject:annotation];
        }
    }
    [self.deliveryMapView removeAnnotations:existingPins];

    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = self.deliveryDestinationCoordinate;
    annotation.title = self.order.customerName.length ? self.order.customerName : kLang(@"Deliv_CustomerInfo");
    [self.deliveryMapView addAnnotation:annotation];
}

- (void)geocodeDeliveryAddress:(NSString *)address {
    if (self.isGeocodingDeliveryAddress) return;
    if ([self.geocodedDeliveryAddress isEqualToString:address]) {
        [self applyDeliveryCoordinateToCurrentMap];
        return;
    }
    self.isGeocodingDeliveryAddress = YES;
    self.geocodedDeliveryAddress = address;

    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    __weak typeof(self) weakSelf = self;
    [geocoder geocodeAddressString:address completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf) return;
            strongSelf.isGeocodingDeliveryAddress = NO;
            if (error || placemarks.count == 0) {
                strongSelf.deliveryDistanceLabel.text = kLang(@"Deliv_DistanceUnavailable");
                return;
            }

            CLPlacemark *placemark = placemarks.firstObject;
            CLLocationCoordinate2D coordinate = placemark.location ? placemark.location.coordinate : kCLLocationCoordinate2DInvalid;
            if (!CLLocationCoordinate2DIsValid(coordinate)) {
                strongSelf.deliveryDistanceLabel.text = kLang(@"Deliv_DistanceUnavailable");
                return;
            }
            strongSelf.deliveryDestinationCoordinate = coordinate;
            [strongSelf applyDeliveryCoordinateToCurrentMap];

            if ([strongSelf.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                [strongSelf.locationManager requestWhenInUseAuthorization];
            }
            [strongSelf.locationManager startUpdatingLocation];
        });
    }];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *currentLocation = locations.lastObject;
    if (!currentLocation || !CLLocationCoordinate2DIsValid(self.deliveryDestinationCoordinate)) return;

    CLLocation *destination = [[CLLocation alloc] initWithLatitude:self.deliveryDestinationCoordinate.latitude longitude:self.deliveryDestinationCoordinate.longitude];
    CLLocationDistance distance = [currentLocation distanceFromLocation:destination];
    if (distance < 1000.0) {
        self.deliveryDistanceLabel.text = [NSString stringWithFormat:kLang(@"Deliv_DistanceMeters"), (long)distance];
    } else {
        self.deliveryDistanceLabel.text = [NSString stringWithFormat:kLang(@"Deliv_DistanceKilometers"), [@(distance / 1000.0) stringValue]];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    self.deliveryDistanceLabel.text = kLang(@"Deliv_DistanceUnavailable");
}

#pragma mark - Marketplace Provider Section

- (void)addMarketplaceProviderSection {
    NSString *providerID = self.order.marketplaceProviderID;
    if (providerID.length == 0 ||
        [providerID isEqualToString:@"platform"] ||
        [providerID isEqualToString:PPDeliveryOfficialSupportUserID]) return;

    __weak typeof(self) weakSelf = self;
    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 12;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        [stack addArrangedSubview:[weakSelf sectionTitleWithIcon:@"storefront.fill" text:kLang(@"Deliv_MarketplaceProvider")]];

        UIStackView *profileRow = [[UIStackView alloc] init];
        profileRow.translatesAutoresizingMaskIntoConstraints = NO;
        profileRow.axis = UILayoutConstraintAxisHorizontal;
        profileRow.spacing = 12;
        profileRow.alignment = UIStackViewAlignmentCenter;
        [stack addArrangedSubview:profileRow];

        UIImageView *avatar = [[UIImageView alloc] init];
        avatar.translatesAutoresizingMaskIntoConstraints = NO;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.clipsToBounds = YES;
        avatar.layer.cornerRadius = 26;
        avatar.layer.cornerCurve = kCACornerCurveContinuous;
        avatar.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
        UIImageSymbolConfiguration *avatarCfg = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];

        // Use provider photo URL if available, otherwise use placeholder
        if (weakSelf.marketplaceProviderUser.UserImageUrl) {
            [avatar sd_setImageWithURL:weakSelf.marketplaceProviderUser.UserImageUrl placeholderImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
        } else if (weakSelf.order.marketplaceProviderPhotoURLString.length > 0) {
            [avatar sd_setImageWithURL:[NSURL URLWithString:weakSelf.order.marketplaceProviderPhotoURLString] placeholderImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
        } else {
            avatar.image = [[UIImage systemImageNamed:@"person.crop.circle.fill"] imageWithConfiguration:avatarCfg];
            avatar.tintColor = AppPrimaryClr;
        }
        [profileRow addArrangedSubview:avatar];
        [avatar.widthAnchor constraintEqualToConstant:52].active = YES;
        [avatar.heightAnchor constraintEqualToConstant:52].active = YES;

        NSString *providerName = weakSelf.marketplaceProviderUser.PPBestDisplayName.length
            ? weakSelf.marketplaceProviderUser.PPBestDisplayName
            : (weakSelf.order.marketplaceProviderName.length
                ? weakSelf.order.marketplaceProviderName
                : weakSelf.order.marketplaceProviderID);
        UILabel *name = [weakSelf valueLabel:providerName
                                      font:PPFontBold(16)
                                     color:PrimaryTextClr];
        [profileRow addArrangedSubview:name];

        UILabel *type = [weakSelf valueLabel:kLang(@"Deliv_ProviderMarketplaceOwner")
                                      font:PPFontMedium(14)
                                     color:[AppPrimaryClr colorWithAlphaComponent:0.86]];
        [profileRow addArrangedSubview:type];

        if (weakSelf.order.marketplaceItemIDs.count > 0) {
            UILabel *items = [weakSelf valueLabel:[NSString stringWithFormat:kLang(@"Deliv_MarketplaceItems"), (long)weakSelf.order.marketplaceItemIDs.count]
                                            font:PPFontRegular(12)
                                           color:SeconderyTextClr];
            [stack addArrangedSubview:items];
        }

        UIStackView *buttonRow = [[UIStackView alloc] init];
        buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
        buttonRow.axis = UILayoutConstraintAxisHorizontal;
        buttonRow.spacing = 10;
        buttonRow.distribution = UIStackViewDistributionFillEqually;
        [stack addArrangedSubview:buttonRow];

        UIButton *chatBtn = [weakSelf premiumProviderActionButton:kLang(@"Deliv_ChatProvider") icon:@"message.fill" color:UIColor.systemBlueColor action:@selector(chatWithMarketplaceProvider)];
        UIButton *callBtn = [weakSelf premiumProviderActionButton:kLang(@"Deliv_CallProvider") icon:@"phone.fill" color:UIColor.systemGreenColor action:@selector(callMarketplaceProvider)];
        [buttonRow addArrangedSubview:chatBtn];
        [buttonRow addArrangedSubview:callBtn];

        if (weakSelf.order.marketplaceProviderID.length) {
            [weakSelf loadMarketplaceProvider:weakSelf.order.marketplaceProviderID];
        }
    }];

    [self.stackView addArrangedSubview:card];
}

- (UIButton *)premiumProviderActionButton:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [color colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 15;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = color;
    button.titleLabel.font = PPFontBold(13);
    [button setTitle:title forState:UIControlStateNormal];
    if (iconName.length) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
        [button setImage:image forState:UIControlStateNormal];
    }
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 8, 10, 8);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    return button;
}

- (void)loadMarketplaceProvider:(NSString *)providerID {
    if (self.marketplaceProviderListener) return;
    __weak typeof(self) weakSelf = self;
    self.marketplaceProviderListener = [[UserManager shared] listenUserWithUID:providerID change:^(UserModel * _Nullable user) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.marketplaceProviderUser = user;
            // Cache the provider user in DeliveryManager for use in cells and other places
            if (user) {
                [[PPDeliveryManager shared] cacheProviderUser:user forID:providerID];
            }
            if ([strongSelf.order.marketplaceProviderID isEqualToString:providerID]) {
                [strongSelf refreshUI];
            }
        });
    }];
}

- (void)chatWithMarketplaceProvider {
    [PPFunc pp_playTapEffect];
    NSString *providerID = self.order.marketplaceProviderID;
    if (providerID.length == 0 ||
        [providerID isEqualToString:@"platform"] ||
        [providerID isEqualToString:PPDeliveryOfficialSupportUserID]) return;

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length == 0 || [providerID isEqualToString:currentUID]) {
        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *threadID = ([currentUID compare:providerID] == NSOrderedAscending)
        ? [NSString stringWithFormat:@"%@_%@", currentUID, providerID]
        : [NSString stringWithFormat:@"%@_%@", providerID, currentUID];
    FIRDocumentReference *threadRef = [[db collectionWithPath:@"Chats"] documentWithPath:threadID];

    __weak typeof(self) weakSelf = self;
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error) {
                DLog(@"[DeliveryChat] Could not read provider thread %@: %@", threadID, error.localizedDescription);
                [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                return;
            }

            NSString *providerName = strongSelf.marketplaceProviderUser.PPBestDisplayName.length
                ? strongSelf.marketplaceProviderUser.PPBestDisplayName
                : (strongSelf.order.marketplaceProviderName.length
                    ? strongSelf.order.marketplaceProviderName
                    : providerID);

            FIRUser *authenticatedUser = [FIRAuth auth].currentUser;
            UserModel *deliveryUser = [UserManager shared].currentUser;
            BOOL deliveryUserMatchesSession =
                ([deliveryUser.uid isEqualToString:currentUID] ||
                 [deliveryUser.ID isEqualToString:currentUID]);
            NSString *deliveryName = deliveryUserMatchesSession && deliveryUser.PPBestDisplayName.length
                ? deliveryUser.PPBestDisplayName
                : (authenticatedUser.displayName.length ? authenticatedUser.displayName : currentUID);
            NSString *deliveryPhotoURL = deliveryUserMatchesSession && deliveryUser.UserImageUrl.absoluteString.length
                ? deliveryUser.UserImageUrl.absoluteString
                : (authenticatedUser.photoURL.absoluteString ?: @"");
            NSDictionary *providerMetadata = @{
                @"conversationType": @"provider_chat",
                @"threadType": @"provider_chat",
                @"supportThread": @(NO),
                // The marketplace provider owns this provider-chat inbox;
                // the delivery provider is the contacting participant.
                @"supportUserId": providerID,
                @"customerId": currentUID,
                @"supportDisplayName": deliveryName,
                @"supportPhotoUrl": deliveryPhotoURL,
                @"supportStatus": @"waiting_for_provider",
                @"sourcePlatform": @"pro_ios",
                @"sourceScreen": @"delivery_order_detail",
                @"sourceType": @"order",
                @"sourceEntityId": strongSelf.order.orderId ?: @""
            };

            if (snapshot.exists) {
                NSDictionary *existingData = snapshot.data ?: @{};
                NSArray *members = existingData[@"members"];
                if (![members isKindOfClass:NSArray.class] ||
                    ![members containsObject:currentUID] ||
                    ![members containsObject:providerID]) {
                    [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                    return;
                }
                [threadRef setData:providerMetadata merge:YES completion:^(NSError * _Nullable mergeError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (mergeError) {
                            DLog(@"[DeliveryChat] Could not canonicalize provider thread %@: %@", threadID, mergeError.localizedDescription);
                            [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                            return;
                        }
                        [strongSelf openProviderChatThreadWithID:threadID
                                                      providerID:providerID
                                                     displayName:providerName];
                    });
                }];
                return;
            }

            NSMutableDictionary *payload = [@{
                @"members": @[currentUID, providerID],
                @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
                @"lastMessage": @"",
                @"lastUpdated": [FIRFieldValue fieldValueForServerTimestamp],
                @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
                @"mutedBy": @[],
                @"binnedBy": @[],
                @"reportedBy": @[],
                @"reportCount": @0,
                @"messagesCount": @0
            } mutableCopy];
            [payload addEntriesFromDictionary:providerMetadata];

            [threadRef setData:payload completion:^(NSError * _Nullable createError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (createError) {
                        DLog(@"[DeliveryChat] Could not create provider thread %@: %@", threadID, createError.localizedDescription);
                        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                        return;
                    }
                    [strongSelf openProviderChatThreadWithID:threadID
                                                  providerID:providerID
                                                 displayName:providerName];
                });
            }];
        });
    }];
}

- (void)openProviderChatThreadWithID:(NSString *)threadID providerID:(NSString *)providerID displayName:(NSString *)displayName {
    ChatThreadModel *thread = [[ChatThreadModel alloc] init];
    thread.ID = threadID;
    thread.conversationType = @"provider_chat";
    thread.supportUserID = providerID;
    thread.customerId = [FIRAuth auth].currentUser.uid ?: @"";
    thread.supportDisplayName = displayName;
    thread.memberIDs = @[thread.customerId, providerID];
    UserModel *providerUser = self.marketplaceProviderUser;
    if (providerUser.ID.length == 0) {
        providerUser = [UserModel new];
        providerUser.ID = providerID;
        providerUser.UserName = displayName;
    }
    thread.otherUser = providerUser;
    PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
    [self.navigationController pushViewController:messagesVC animated:YES];
}

- (void)callMarketplaceProvider {
    [PPFunc pp_playTapEffect];
    NSString *phone = self.marketplaceProviderUser.MobileNo ?: self.order.marketplaceProviderPhone;
    if (!phone.length) {
        [PPToast toast:kLang(@"Deliv_NoProviderPhone")];
        return;
    }
    NSString *cleaned = [[phone componentsSeparatedByCharactersInSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
        componentsJoinedByString:@""];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", cleaned]];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

#pragma mark - Order Items Section

- (void)addOrderItemsSection {
    if (self.order.items.count == 0) return;

    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 0;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        UIView *titleView = [self sectionTitleWithIcon:@"bag.fill" text:kLang(@"OrderItems")];
        [stack addArrangedSubview:titleView];
        [stack setCustomSpacing:10 afterView:titleView];

        // Items count subtitle
        UILabel *countLabel = [self valueLabel:[NSString stringWithFormat:kLang(@"Deliv_ItemsInOrder"), (long)self.order.items.count]
                                          font:PPFontRegular(12)
                                         color:SeconderyTextClr];
        [stack addArrangedSubview:countLabel];
        [stack setCustomSpacing:12 afterView:countLabel];

        for (NSInteger i = 0; i < (NSInteger)self.order.items.count; i++) {
            PPDeliveryOrderItem *item = self.order.items[i];
            UIView *row = [self createItemRow:item];
            [stack addArrangedSubview:row];

            // Add separator between items
            if (i < (NSInteger)self.order.items.count - 1) {
                UIView *sep = [[UIView alloc] init];
                sep.translatesAutoresizingMaskIntoConstraints = NO;
                sep.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
                [sep.heightAnchor constraintEqualToConstant:0.5].active = YES;
                [stack addArrangedSubview:sep];
            }
        }
    }];

    [self.stackView addArrangedSubview:card];
}

- (UIView *)createItemRow:(PPDeliveryOrderItem *)item {
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.alignment = UIStackViewAlignmentCenter;

    // Spacing
    UIView *rowPadding = [[UIView alloc] init];
    rowPadding.translatesAutoresizingMaskIntoConstraints = NO;
    [row addArrangedSubview:rowPadding];
    [rowPadding.widthAnchor constraintEqualToConstant:0].active = YES;

    // Quantity badge — filled circle
    UILabel *qty = [[UILabel alloc] init];
    qty.translatesAutoresizingMaskIntoConstraints = NO;
    qty.font = PPFontBold(11);
    qty.textColor = UIColor.whiteColor;
    qty.backgroundColor = AppPrimaryClr;
    qty.textAlignment = NSTextAlignmentCenter;
    qty.layer.cornerRadius = 13;
    qty.clipsToBounds = YES;
    qty.text = [NSString stringWithFormat:@"%ld", (long)item.quantity];
    [qty.widthAnchor constraintEqualToConstant:26].active = YES;
    [qty.heightAnchor constraintEqualToConstant:26].active = YES;
    [row addArrangedSubview:qty];

    // Name
    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.font = PPFontMedium(14);
    name.textColor = PrimaryTextClr;
    name.text = item.name;
    name.numberOfLines = 2;
    [name setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:name];

    // Price
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.maximumFractionDigits = 2;
    UILabel *price = [[UILabel alloc] init];
    price.translatesAutoresizingMaskIntoConstraints = NO;
    price.font = PPFontBold(13);
    price.textColor = SeconderyTextClr;
    price.text = [fmt stringFromNumber:@(item.price * item.quantity)];
    [price setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:price];

    // Row has vertical padding
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapper addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:8],
        [row.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [row.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-8],
    ]];

    return wrapper;
}

#pragma mark - Payment Section

- (void)addPaymentSection {
    PPDeliveryOrderModel *order = self.order;

    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 10;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        // Section title with payment icon
        NSString *payIcon = [order isCashOrder] ? @"banknote" : @"creditcard";
        [stack addArrangedSubview:[self sectionTitleWithIcon:payIcon text:kLang(@"Deliv_PaymentDetails")]];

        // Total
        [stack addArrangedSubview:[self detailRow:kLang(@"TotalAmount")
                                            value:[order formattedTotal]
                                             bold:YES]];

        // Method with semantic color
        BOOL isCash = [order isCashOrder];
        NSString *methodDisplay = isCash ? kLang(@"CashPayment") : kLang(@"OnlinePayment");
        [stack addArrangedSubview:[self detailRow:kLang(@"PaymentMethod") value:methodDisplay bold:NO]];

        // Payment status with semantic indicator
        NSString *payDisplay;
        UIColor *payStatusColor;
        if ([order.paymentStatus.lowercaseString containsString:@"pending"]) {
            payDisplay = kLang(@"Deliv_PaymentPending");
            payStatusColor = UIColor.systemOrangeColor;
        } else {
            payDisplay = kLang(@"Paid");
            payStatusColor = UIColor.systemGreenColor;
        }
        if (order.paymentCollectedAt) {
            payDisplay = kLang(@"Deliv_PaymentCollected");
            payStatusColor = UIColor.systemTealColor;
        }

        UIView *statusRow = [self detailRowWithStatusDot:kLang(@"PaymentStatus")
                                                   value:payDisplay
                                                dotColor:payStatusColor];
        [stack addArrangedSubview:statusRow];
    }];

    [self.stackView addArrangedSubview:card];
}

- (UIView *)detailRow:(NSString *)label value:(NSString *)value bold:(BOOL)bold {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.distribution = UIStackViewDistributionFill;

    UILabel *keyLbl = [[UILabel alloc] init];
    keyLbl.font = PPFontRegular(14);
    keyLbl.textColor = SeconderyTextClr;
    keyLbl.text = label;
    [keyLbl setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:keyLbl];

    UILabel *valLbl = [[UILabel alloc] init];
    valLbl.font = bold ? PPFontBold(15) : PPFontMedium(14);
    valLbl.textColor = PrimaryTextClr;
    valLbl.text = value;
    valLbl.textAlignment = NSTextAlignmentRight;
    [row addArrangedSubview:valLbl];

    return row;
}

- (UIView *)detailRowWithStatusDot:(NSString *)label value:(NSString *)value dotColor:(UIColor *)dotColor {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.distribution = UIStackViewDistributionFill;

    UILabel *keyLbl = [[UILabel alloc] init];
    keyLbl.font = PPFontRegular(14);
    keyLbl.textColor = SeconderyTextClr;
    keyLbl.text = label;
    [keyLbl setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:keyLbl];

    // Value with dot
    UIStackView *valStack = [[UIStackView alloc] init];
    valStack.axis = UILayoutConstraintAxisHorizontal;
    valStack.spacing = 6;
    valStack.alignment = UIStackViewAlignmentCenter;

    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = dotColor;
    dot.layer.cornerRadius = 4;
    [dot.widthAnchor constraintEqualToConstant:8].active = YES;
    [dot.heightAnchor constraintEqualToConstant:8].active = YES;
    [valStack addArrangedSubview:dot];

    UILabel *valLbl = [[UILabel alloc] init];
    valLbl.font = PPFontMedium(14);
    valLbl.textColor = dotColor;
    valLbl.text = value;
    [valStack addArrangedSubview:valLbl];

    [row addArrangedSubview:valStack];

    return row;
}

#pragma mark - Timeline Section

- (void)addTimelineSection {
    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 10;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        [stack addArrangedSubview:[self sectionTitleWithIcon:@"clock.arrow.circlepath" text:kLang(@"Deliv_Timeline")]];

        self.timelineView = [[PPDeliveryStatusTimelineView alloc] init];
        self.timelineView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.timelineView configureWithOrder:self.order];
        [stack addArrangedSubview:self.timelineView];
    }];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - Delivery Notes Section

- (void)addDeliveryNotesSection {
    UIView *card = [self createCardWithContent:^(UIView *card) {
        UIStackView *stack = [[UIStackView alloc] init];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 10;
        [card addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
            [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
            [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
            [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
        ]];

        [stack addArrangedSubview:[self sectionTitleWithIcon:@"note.text" text:kLang(@"Deliv_NotesSection")]];

        self.notesTextView = [[UITextView alloc] init];
        self.notesTextView.translatesAutoresizingMaskIntoConstraints = NO;
        self.notesTextView.font = PPFontRegular(14);
        self.notesTextView.textColor = PrimaryTextClr;
        self.notesTextView.text = self.order.notes.length ? self.order.notes : @"";
        self.notesTextView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
        self.notesTextView.layer.cornerRadius = 14;
        self.notesTextView.layer.cornerCurve = kCACornerCurveContinuous;
        self.notesTextView.layer.borderWidth = 0.5;
        self.notesTextView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        self.notesTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
        self.notesTextView.scrollEnabled = NO;
        [self.notesTextView.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
        [stack addArrangedSubview:self.notesTextView];
    }];

    [self.stackView addArrangedSubview:card];
}

#pragma mark - Floating Action Bar

- (void)setupFloatingActionBar {
    PPDeliveryOrderModel *order = self.order;
    BOOL hasActions = [order canAcceptDelivery] ||
                      [order canConfirmPackageHandover] ||
                      [order canMarkInTransit] ||
                      [order canMarkDelivered] ||
                      [order canCollectCashPayment] ||
                      [order canMarkCompleted] ||
                      ![order isTerminal];
    if (!hasActions) return;

    // Blurred frosted background
    _floatingActionBar = [[UIView alloc] init];
    _floatingActionBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_floatingActionBar];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_floatingActionBar insertSubview:blurView atIndex:0];

    // Top separator
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.1];
    [_floatingActionBar addSubview:sep];

    _floatingActionStack = [[UIStackView alloc] init];
    _floatingActionStack.translatesAutoresizingMaskIntoConstraints = NO;
    _floatingActionStack.axis = UILayoutConstraintAxisVertical;
    _floatingActionStack.spacing = 8;
    [_floatingActionBar addSubview:_floatingActionStack];

    // Primary action
    if ([order canAcceptDelivery]) {
        UIButton *btn = [self primaryActionButton:kLang(@"AcceptDelivery")
                                            color:UIColor.systemGreenColor
                                           action:@selector(confirmAcceptDelivery)
                                             icon:@"hand.thumbsup.fill"];
        [_floatingActionStack addArrangedSubview:btn];
        self.actionButton = btn;
    } else if ([order canConfirmPackageHandover]) {
        // If a delivery agent is assigned, only the assigned agent can pick up
        BOOL isDeliveryAssigned = (order.deliveryUserId.length > 0);
        NSString *currentUid = [FIRAuth auth].currentUser.uid;
        if (!isDeliveryAssigned || [order.deliveryUserId isEqualToString:currentUid]) {
            UIButton *btn = [self primaryActionButton:kLang(@"PickUpFromStore")
                                                color:UIColor.systemIndigoColor
                                               action:@selector(confirmPickup)
                                                 icon:@"shippingbox.fill"];
            [_floatingActionStack addArrangedSubview:btn];
            self.actionButton = btn;
        }
    } else if ([order canMarkInTransit]) {
        NSString *currentUid = [FIRAuth auth].currentUser.uid;
        if (order.deliveryUserId.length == 0 || [order.deliveryUserId isEqualToString:currentUid]) {
            UIButton *btn = [self primaryActionButton:kLang(@"Deliv_StartTransit")
                                                color:UIColor.systemBlueColor
                                               action:@selector(confirmStartTransit)
                                                 icon:@"truck.box.fill"];
            [_floatingActionStack addArrangedSubview:btn];
            self.actionButton = btn;
        }
    } else if ([order canMarkDelivered]) {
        // Only the assigned delivery agent can mark as delivered
        BOOL isDeliveryAssigned = (order.deliveryUserId.length > 0);
        NSString *currentUid = [FIRAuth auth].currentUser.uid;
        if (!isDeliveryAssigned || [order.deliveryUserId isEqualToString:currentUid]) {
            UIButton *btn = [self primaryActionButton:kLang(@"MarkAsDelivered")
                                                color:UIColor.systemGreenColor
                                               action:@selector(confirmDelivery)
                                                 icon:@"checkmark.circle.fill"];
            [_floatingActionStack addArrangedSubview:btn];
            self.actionButton = btn;
        }
    } else if ([order canCollectCashPayment]) {
        NSString *title = [NSString stringWithFormat:@"%@ — %@", kLang(@"CollectCashPayment"), [order formattedTotal]];
        UIButton *btn = [self primaryActionButton:title
                                            color:UIColor.systemTealColor
                                           action:@selector(confirmCashCollection)
                                             icon:@"banknote.fill"];
        [_floatingActionStack addArrangedSubview:btn];
        self.actionButton = btn;
    } else if ([order canMarkCompleted]) {
        UIButton *btn = [self primaryActionButton:kLang(@"Deliv_CompleteOrder")
                                            color:UIColor.systemGreenColor
                                           action:@selector(confirmCompleteOrder)
                                             icon:@"checkmark.seal.fill"];
        [_floatingActionStack addArrangedSubview:btn];
        self.actionButton = btn;
    }

    // Report issue
    if (![order isTerminal]) {
        self.reportIssueButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.reportIssueButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.reportIssueButton setTitle:[NSString stringWithFormat:@"  %@", kLang(@"ReportIssue")] forState:UIControlStateNormal];
        [self.reportIssueButton setImage:[UIImage systemImageNamed:@"exclamationmark.bubble.fill"] forState:UIControlStateNormal];
        self.reportIssueButton.tintColor = UIColor.systemOrangeColor;
        self.reportIssueButton.titleLabel.font = PPFontMedium(14);
        self.reportIssueButton.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.1];
        self.reportIssueButton.layer.cornerRadius = 14;
        self.reportIssueButton.layer.cornerCurve = kCACornerCurveContinuous;
        [self.reportIssueButton addTarget:self action:@selector(reportIssue) forControlEvents:UIControlEventTouchUpInside];
        [self.reportIssueButton.heightAnchor constraintEqualToConstant:50].active = YES;
        [_floatingActionStack addArrangedSubview:self.reportIssueButton];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_floatingActionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_floatingActionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_floatingActionBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [blurView.topAnchor constraintEqualToAnchor:_floatingActionBar.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:_floatingActionBar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_floatingActionBar.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_floatingActionBar.bottomAnchor],

        [sep.topAnchor constraintEqualToAnchor:_floatingActionBar.topAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:_floatingActionBar.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:_floatingActionBar.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],

        [_floatingActionStack.topAnchor constraintEqualToAnchor:_floatingActionBar.topAnchor constant:10],
        [_floatingActionStack.leadingAnchor constraintEqualToAnchor:_floatingActionBar.leadingAnchor constant:16],
        [_floatingActionStack.trailingAnchor constraintEqualToAnchor:_floatingActionBar.trailingAnchor constant:-16],
        [_floatingActionStack.bottomAnchor constraintEqualToAnchor:_floatingActionBar.safeAreaLayoutGuide.bottomAnchor constant:-8],
    ]];
}

#pragma mark - Action Buttons (legacy — now in floating bar)

- (void)addActionButtons {
    UIStackView *btnStack = [[UIStackView alloc] init];
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    btnStack.axis = UILayoutConstraintAxisVertical;
    btnStack.spacing = 12;

    PPDeliveryOrderModel *order = self.order;

    // Accept delivery (highest priority — shown when order is ready and no delivery agent)
    if ([order canAcceptDelivery]) {
        UIButton *btn = [self primaryActionButton:kLang(@"AcceptDelivery")
                                            color:UIColor.systemTealColor
                                           action:@selector(confirmAcceptDelivery)
                                             icon:@"hand.raised.fill"];
        [btnStack addArrangedSubview:btn];
        self.actionButton = btn;
    }
    // Primary action
    else if ([order canMarkShipped]) {
        // If a delivery agent is assigned, only the assigned agent can pick up
        BOOL isDeliveryAssigned = (order.deliveryUserId.length > 0);
        NSString *currentUid = [FIRAuth auth].currentUser.uid;
        if (!isDeliveryAssigned || [order.deliveryUserId isEqualToString:currentUid]) {
            UIButton *btn = [self primaryActionButton:kLang(@"PickUpFromStore")
                                                color:UIColor.systemIndigoColor
                                               action:@selector(confirmPickup)
                                                 icon:@"shippingbox.fill"];
            [btnStack addArrangedSubview:btn];
            self.actionButton = btn;
        }
    } else if ([order canMarkDelivered]) {
        // Only the assigned delivery agent can mark as delivered
        BOOL isDeliveryAssigned = (order.deliveryUserId.length > 0);
        NSString *currentUid = [FIRAuth auth].currentUser.uid;
        if (!isDeliveryAssigned || [order.deliveryUserId isEqualToString:currentUid]) {
            UIButton *btn = [self primaryActionButton:kLang(@"MarkAsDelivered")
                                                color:UIColor.systemGreenColor
                                               action:@selector(confirmDelivery)
                                                 icon:@"checkmark.circle.fill"];
            [btnStack addArrangedSubview:btn];
            self.actionButton = btn;
        }
    } else if ([order canCollectCashPayment]) {
        NSString *title = [NSString stringWithFormat:@"%@ — %@", kLang(@"CollectCashPayment"), [order formattedTotal]];
        UIButton *btn = [self primaryActionButton:title
                                            color:UIColor.systemTealColor
                                           action:@selector(confirmCashCollection)
                                             icon:@"banknote.fill"];
        [btnStack addArrangedSubview:btn];
        self.actionButton = btn;
    }

    // Report issue (always available for active orders)
    if (![order isTerminal]) {
        self.reportIssueButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.reportIssueButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.reportIssueButton setTitle:[NSString stringWithFormat:@"  %@", kLang(@"ReportIssue")] forState:UIControlStateNormal];
        [self.reportIssueButton setImage:[UIImage systemImageNamed:@"exclamationmark.bubble.fill"] forState:UIControlStateNormal];
        self.reportIssueButton.tintColor = UIColor.systemOrangeColor;
        self.reportIssueButton.titleLabel.font = PPFontMedium(15);
        [self.reportIssueButton addTarget:self action:@selector(reportIssue) forControlEvents:UIControlEventTouchUpInside];
        [self.reportIssueButton.heightAnchor constraintEqualToConstant:44].active = YES;
        [btnStack addArrangedSubview:self.reportIssueButton];
    }

    if (btnStack.arrangedSubviews.count > 0) {
        [self.stackView addArrangedSubview:btnStack];
    }
}

- (UIButton *)primaryActionButton:(NSString *)title color:(UIColor *)color action:(SEL)action icon:(NSString *)iconName {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 16;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    [btn setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.titleLabel.font = PPFontBold(16);
    if (iconName) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        UIImage *img = [[UIImage systemImageNamed:iconName] imageWithConfiguration:cfg];
        [btn setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        btn.tintColor = UIColor.whiteColor;
    }
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:54].active = YES;

    // Shadow
    btn.layer.shadowColor = color.CGColor;
    btn.layer.shadowOpacity = 0.3;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowRadius = 8;

    return btn;
}

#pragma mark - Official Support Chat

- (BOOL)pp_isOfficialSupportProfile {
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    return [currentUID isEqualToString:PPDeliveryOfficialSupportUserID];
}

- (void)officialSupportStartChat {
    [PPFunc pp_playTapEffect];
    NSString *customerUID = self.order.userId;
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (customerUID.length == 0 || currentUID.length == 0) return;
    if ([customerUID isEqualToString:currentUID]) {
        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *threadID = ([currentUID compare:customerUID] == NSOrderedAscending)
        ? [NSString stringWithFormat:@"%@_%@", currentUID, customerUID]
        : [NSString stringWithFormat:@"%@_%@", customerUID, currentUID];
    FIRDocumentReference *threadRef = [[db collectionWithPath:@"Chats"] documentWithPath:threadID];

    __weak typeof(self) weakSelf = self;
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error) {
                DLog(@"[OfficialChat] Could not read customer thread %@: %@", threadID, error.localizedDescription);
                [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                return;
            }

            NSString *customerName = strongSelf.order.customerName.length ? strongSelf.order.customerName : customerUID;
            if (snapshot.exists) {
                NSDictionary *existingData = snapshot.data ?: @{};
                NSArray *members = existingData[@"members"];
                if (![members isKindOfClass:NSArray.class] ||
                    ![members containsObject:currentUID] ||
                    ![members containsObject:customerUID]) {
                    [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                    return;
                }
                [strongSelf openCustomerChatThreadWithID:threadID
                                             customerID:customerUID
                                            displayName:customerName];
                return;
            }

            UserModel *officialUser = [UserManager shared].currentUser;
            NSString *officialName = officialUser.PPBestDisplayName.length
                ? officialUser.PPBestDisplayName
                : currentUID;
            NSString *officialPhotoURL = officialUser.UserImageUrl.absoluteString ?: @"";
            NSDictionary *payload = @{
                @"members": @[currentUID, customerUID],
                @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
                @"lastMessage": @"",
                @"lastUpdated": [FIRFieldValue fieldValueForServerTimestamp],
                @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
                @"mutedBy": @[],
                @"binnedBy": @[],
                @"reportedBy": @[],
                @"reportCount": @0,
                @"messagesCount": @0,
                @"conversationType": @"support_chat",
                @"threadType": @"support_chat",
                @"supportThread": @(YES),
                @"supportUserId": currentUID,
                @"customerId": customerUID,
                @"supportDisplayName": officialName,
                @"supportPhotoUrl": officialPhotoURL,
                @"supportStatus": @"active",
                @"sourcePlatform": @"pro_ios",
                @"sourceScreen": @"delivery_order_detail",
                @"sourceType": @"order",
                @"sourceEntityId": strongSelf.order.orderId ?: @""
            };

            [threadRef setData:payload completion:^(NSError * _Nullable createError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (createError) {
                        DLog(@"[OfficialChat] Could not create customer thread %@: %@", threadID, createError.localizedDescription);
                        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
                        return;
                    }
                    [strongSelf openCustomerChatThreadWithID:threadID
                                                 customerID:customerUID
                                                displayName:customerName];
                });
            }];
        });
    }];
}

- (void)openCustomerChatThreadWithID:(NSString *)threadID customerID:(NSString *)customerID displayName:(NSString *)displayName {
    ChatThreadModel *thread = [[ChatThreadModel alloc] init];
    thread.ID = threadID;
    thread.conversationType = @"support_chat";
    thread.supportUserID = [FIRAuth auth].currentUser.uid ?: @"";
    thread.customerId = customerID;
    thread.supportDisplayName = displayName;
    thread.memberIDs = @[thread.supportUserID, customerID];
    UserModel *customerUser = [UserModel new];
    customerUser.ID = customerID;
    customerUser.UserName = displayName;
    thread.otherUser = customerUser;
    PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
    [self.navigationController pushViewController:messagesVC animated:YES];
}

#pragma mark - Status Color

- (UIColor *)colorForStatus:(NSString *)status {
    NSString *lower = [status lowercaseString];
    if ([@[PPDeliveryStatusReadyToShip, PPDeliveryStatusRequested, PPDeliveryStatusAwaitingHandover] containsObject:lower])
        return UIColor.systemOrangeColor;
    if ([@[PPDeliveryStatusPickedUp, PPDeliveryStatusInTransit] containsObject:lower])
        return UIColor.systemIndigoColor;
    if ([@[PPDeliveryStatusDelivered, PPDeliveryStatusPaymentPending, PPDeliveryStatusPaymentConfirmed, PPDeliveryStatusCompleted] containsObject:lower])
        return UIColor.systemGreenColor;
    if ([@[PPDeliveryStatusCancelled, PPDeliveryStatusFailed, PPDeliveryStatusReturnedToStore] containsObject:lower])
        return UIColor.systemRedColor;
    if ([@[@"processing", @"preparing", @"packed", @"confirmed", @"paid"] containsObject:lower])
        return UIColor.systemBlueColor;
    return UIColor.systemGrayColor;
}

#pragma mark - Actions: Accept Delivery

- (void)confirmAcceptDelivery {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"AcceptDelivery")
                           subtitle:kLang(@"AcceptDeliveryMessage")
                        placeholder:nil
                      confirmButton:kLang(@"AcceptDelivery")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeAcceptDelivery];
    } cancelBlock:nil];
}

- (void)executeAcceptDelivery {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"AcceptDelivery") subtitle:nil];
    self.actionButton.enabled = NO;

    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] acceptDeliveryOrder:self.order.orderId completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Confirm Pickup

- (void)confirmPickup {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"ConfirmPickup")
                           subtitle:kLang(@"ConfirmPickupMessage")
                        placeholder:nil
                      confirmButton:kLang(@"ConfirmPickup")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeMarkShipped];
    } cancelBlock:nil];
}

- (void)executeMarkShipped {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"PickUpFromStore") subtitle:nil];
    self.actionButton.enabled = NO;

    NSString *note = self.notesTextView.text ?: @"";
    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] markOrderShipped:self.order.orderId note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Start Transit

- (void)confirmStartTransit {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"Deliv_StartTransit")
                           subtitle:kLang(@"Deliv_StartTransitMessage")
                        placeholder:nil
                      confirmButton:kLang(@"Deliv_StartTransit")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeStartTransit];
    } cancelBlock:nil];
}

- (void)executeStartTransit {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Deliv_StartTransit") subtitle:nil];
    self.actionButton.enabled = NO;

    NSString *note = self.notesTextView.text ?: @"";
    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] markOrderInTransit:self.order.orderId note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Confirm Delivery

- (void)confirmDelivery {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"ConfirmDelivery")
                           subtitle:kLang(@"ConfirmDeliveryMessage")
                        placeholder:nil
                      confirmButton:kLang(@"ConfirmDelivery")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeMarkDelivered];
    } cancelBlock:nil];
}

- (void)executeMarkDelivered {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"MarkAsDelivered") subtitle:nil];
    self.actionButton.enabled = NO;

    NSString *note = self.notesTextView.text ?: @"";
    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] markOrderDelivered:self.order.orderId note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Collect Cash

- (void)confirmCashCollection {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    NSString *amountStr = [self.order formattedTotal];

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"ConfirmCashCollection")
                           subtitle:[NSString stringWithFormat:kLang(@"ConfirmCashCollectionMessage"), amountStr]
                        placeholder:nil
                      confirmButton:kLang(@"ConfirmCashCollection")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeCollectCash];
    } cancelBlock:nil];
}

- (void)executeCollectCash {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"CollectCashPayment") subtitle:nil];
    self.actionButton.enabled = NO;

    NSString *note = self.notesTextView.text ?: @"";
    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] collectCashPayment:self.order.orderId note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Complete Order

- (void)confirmCompleteOrder {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"Deliv_CompleteOrder")
                           subtitle:kLang(@"Deliv_CompleteOrderMessage")
                        placeholder:nil
                      confirmButton:kLang(@"Deliv_CompleteOrder")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [weakSelf executeCompleteOrder];
    } cancelBlock:nil];
}

- (void)executeCompleteOrder {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Deliv_CompleteOrder") subtitle:nil];
    self.actionButton.enabled = NO;

    NSString *note = self.notesTextView.text ?: @"";
    __weak typeof(self) weakSelf = self;

    [[PPDeliveryManager shared] markOrderCompleted:self.order.orderId note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        strongSelf.actionButton.enabled = YES;

        if (success) {
            [PPFunc pp_playSuccessEffect];
            [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"DeliverySuccess") subtitle:message];
        } else {
            [PPFunc pp_playErrorEffect];
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
        }
    }];
}

#pragma mark - Actions: Report Issue

- (void)reportIssue {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showTextPromptIn:self
                            title:kLang(@"ReportIssue")
                         subtitle:nil
                      placeholder:kLang(@"IssueNote")
                      initialText:nil
                      confirmText:kLang(@"SubmitIssue")
                       cancelText:kLang(@"Cancel")
                       completion:^(NSString * _Nullable text) {
        if (text.length == 0) return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // Save issue note to Firestore
        FIRFirestore *db = [FIRFirestore firestore];
        FIRDocumentReference *docRef = [[db collectionWithPath:@"Orders"] documentWithPath:strongSelf.order.orderId];
        NSDictionary *update = @{
            @"deliveryIssue": text,
            @"deliveryIssueAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"deliveryIssueBy": [FIRAuth auth].currentUser.uid ?: @""
        };
        [docRef updateData:update completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                } else {
                    [PPFunc pp_playSuccessEffect];
                    [PPAlertHelper showSuccessIn:strongSelf title:kLang(@"ReportIssue") subtitle:kLang(@"Deliv_IssueReported")];
                }
            });
        }];
    }];
}

#pragma mark - Actions: Delivery Location

- (void)startDeliveryNavigation {
    [PPFunc pp_playTapEffect];
    if (![self.order pp_canRevealExactDeliveryLocation]) return;

    CLLocationCoordinate2D coordinate = [self coordinateFromLocationPointString:self.order.deliveryLocationPoint];
    if (CLLocationCoordinate2DIsValid(coordinate)) {
        NSURL *coordinateURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?daddr=%f,%f", coordinate.latitude, coordinate.longitude]];
        if (coordinateURL && [[UIApplication sharedApplication] canOpenURL:coordinateURL]) {
            [[UIApplication sharedApplication] openURL:coordinateURL options:@{} completionHandler:nil];
            return;
        }
    }

    NSString *address = [self.order pp_exactDeliveryLocationText];
    if (!address.length) return;
    NSString *encoded = [address stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *mapsURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?daddr=%@", encoded]];
    if (mapsURL && [[UIApplication sharedApplication] canOpenURL:mapsURL]) {
        [[UIApplication sharedApplication] openURL:mapsURL options:@{} completionHandler:nil];
    }
}

- (void)showDeliveryRoute {
    [PPFunc pp_playTapEffect];
    if (![self.order pp_canRevealExactDeliveryLocation]) return;

    NSString *address = [self.order pp_exactDeliveryLocationText];
    if (!address.length) return;

    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DIsValid(self.deliveryDestinationCoordinate)
        ? self.deliveryDestinationCoordinate
        : [self coordinateFromLocationPointString:self.order.deliveryLocationPoint];
    if (CLLocationCoordinate2DIsValid(coordinate)) {
        MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
        MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
        mapItem.name = self.order.customerName.length ? self.order.customerName : kLang(@"Deliv_CustomerInfo");
        [MKMapItem openMapsWithItems:@[mapItem] launchOptions:@{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving}];
        return;
    }

    NSString *encoded = [address stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *mapsURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?daddr=%@", encoded]];
    if (mapsURL && [[UIApplication sharedApplication] canOpenURL:mapsURL]) {
        [[UIApplication sharedApplication] openURL:mapsURL options:@{} completionHandler:nil];
    }
}

- (void)calculateDeliveryDistance {
    [PPFunc pp_playTapEffect];
    if (!CLLocationCoordinate2DIsValid(self.deliveryDestinationCoordinate)) {
        self.deliveryDistanceLabel.text = kLang(@"Deliv_DistanceUnavailable");
        return;
    }
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startUpdatingLocation];
    self.deliveryDistanceLabel.text = kLang(@"Deliv_DistancePending");
}

#pragma mark - Actions: Contact

- (void)callCustomer {
    [PPFunc pp_playTapEffect];
    NSString *currentDeliveryUserID = [FIRAuth auth].currentUser.uid ?: @"";
    if (![self.order pp_canRevealCustomerPhoneForDeliveryUserID:currentDeliveryUserID]) {
        [PPToast toast:kLang(@"Deliv_CustomerPhoneAfterAccepting")];
        return;
    }
    NSString *phone = self.order.customerPhone;
    if (!phone.length) return;
    NSString *cleaned = [[phone componentsSeparatedByCharactersInSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
        componentsJoinedByString:@""];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", cleaned]];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)openWhatsApp {
    [PPFunc pp_playTapEffect];
    NSString *phone = self.order.customerPhone;
    if (!phone.length) return;
    NSString *cleaned = [[phone componentsSeparatedByCharactersInSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
        componentsJoinedByString:@""];
    NSString *waURL = [NSString stringWithFormat:@"https://wa.me/%@", cleaned];
    NSURL *url = [NSURL URLWithString:waURL];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)openInMaps {
    [PPFunc pp_playTapEffect];
    if (![self.order pp_canRevealExactDeliveryLocation]) return;

    CLLocationCoordinate2D coordinate = [self coordinateFromLocationPointString:self.order.deliveryLocationPoint];
    if (CLLocationCoordinate2DIsValid(coordinate)) {
        NSURL *coordinateURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%f,%f", coordinate.latitude, coordinate.longitude]];
        if (coordinateURL) {
            [[UIApplication sharedApplication] openURL:coordinateURL options:@{} completionHandler:nil];
            return;
        }
    }

    NSString *address = [self.order pp_exactDeliveryLocationText];
    if (!address.length) return;
    NSString *encoded = [address stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *mapsURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%@", encoded]];
    if (mapsURL) {
        [[UIApplication sharedApplication] openURL:mapsURL options:@{} completionHandler:nil];
    }
}

@end
