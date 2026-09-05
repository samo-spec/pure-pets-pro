//
//  PPDeliveryDashboardViewController.m
//  PurePetsPro
//
//  Category-defining Delivery Operations Cockpit:
//  Real-time Dispatch HUD, Omni-Search with Integrated Filter Button,
//  Route Visual Cards with Micro-Actions, and Quick Transition Sheet.
//

#import "PPDeliveryDashboardViewController.h"
#import "PPDeliveryManager.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryOrderDetailViewController.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "Language.h"
#import "Styling.h"
#import "PPFunc+Haptics.h"
#import "PPToast.h"
#import <MapKit/MapKit.h>

#pragma mark - Filter & Sort Types

typedef NS_ENUM(NSInteger, PPDeliveryPaymentFilter) {
    PPDeliveryPaymentFilterAll = 0,
    PPDeliveryPaymentFilterCOD,
    PPDeliveryPaymentFilterPrepaid
};

typedef NS_ENUM(NSInteger, PPDeliverySortOrder) {
    PPDeliverySortNewest = 0,
    PPDeliverySortAmountHighToLow,
    PPDeliverySortAmountLowToHigh
};

#pragma mark - Forward Declarations

@class PPDeliveryFilterSheet;
@class PPDeliveryQuickTransitionSheet;
@class PPDeliveryOperationCardCell;

// MARK: - Category-Defining Delivery Filter Sheet

@interface PPDeliveryFilterSheet : UIViewController
@property (nonatomic, assign) PPDeliveryFilter selectedStatusFilter;
@property (nonatomic, assign) PPDeliveryPaymentFilter selectedPaymentFilter;
@property (nonatomic, assign) PPDeliverySortOrder selectedSortOrder;
@property (nonatomic, copy) NSArray<PPDeliveryOrderModel *> *allOrders;
@property (nonatomic, copy) void (^onApply)(PPDeliveryFilter statusFilter, PPDeliveryPaymentFilter paymentFilter, PPDeliverySortOrder sortOrder);

@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) NSMutableArray<UIButton *> *statusPills;
@property (nonatomic, strong) NSMutableArray<UIButton *> *paymentPills;
@property (nonatomic, strong) NSMutableArray<UIButton *> *sortPills;

- (instancetype)initWithStatusFilter:(PPDeliveryFilter)statusFilter
                       paymentFilter:(PPDeliveryPaymentFilter)paymentFilter
                           sortOrder:(PPDeliverySortOrder)sortOrder
                           allOrders:(NSArray<PPDeliveryOrderModel *> *)allOrders;
@end

@implementation PPDeliveryFilterSheet

- (instancetype)initWithStatusFilter:(PPDeliveryFilter)statusFilter
                       paymentFilter:(PPDeliveryPaymentFilter)paymentFilter
                           sortOrder:(PPDeliverySortOrder)sortOrder
                           allOrders:(NSArray<PPDeliveryOrderModel *> *)allOrders {
    self = [super init];
    if (self) {
        _selectedStatusFilter = statusFilter;
        _selectedPaymentFilter = paymentFilter;
        _selectedSortOrder = sortOrder;
        _allOrders = allOrders ?: @[];
        _statusPills = [NSMutableArray array];
        _paymentPills = [NSMutableArray array];
        _sortPills = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupSheetUI];
    [self updateButtonsState];
}

- (void)setupSheetUI {
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"Deliv_FilterSheet_Title");
    titleLabel.font = [Styling fontBold:17.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:titleLabel];

    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resetButton setTitle:kLang(@"Deliv_FilterSheet_Reset") forState:UIControlStateNormal];
    self.resetButton.titleLabel.font = [Styling fontBold:13.5];
    self.resetButton.tintColor = [UIColor ppPrimary];
    [self.resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.resetButton];

    UIView *headerDivider = [[UIView alloc] init];
    headerDivider.translatesAutoresizingMaskIntoConstraints = NO;
    headerDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [self.view addSubview:headerDivider];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:scrollView];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 18.0;
    contentStack.alignment = UIStackViewAlignmentFill;
    [scrollView addSubview:contentStack];

    // 1. Status Section
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Deliv_FilterSheet_SectionStatus")]];
    [contentStack addArrangedSubview:[self buildStatusPillRow]];

    // 2. Payment Section
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Deliv_FilterSheet_SectionPayment")]];
    [contentStack addArrangedSubview:[self buildPaymentPillRow]];

    // 3. Sort Order Section
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Deliv_FilterSheet_SectionSort")]];
    [contentStack addArrangedSubview:[self buildSortPillRow]];

    // 4. Apply CTA Button
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.titleLabel.font = [Styling fontBold:16.0];
    self.applyButton.tintColor = UIColor.whiteColor;
    self.applyButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.applyButton, 22);
    PPApplyButtonShadow(self.applyButton);
    [self.applyButton addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.applyButton];

    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [titleLabel.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],

        [self.resetButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [self.resetButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],

        [headerDivider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [headerDivider.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerDivider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerDivider.heightAnchor constraintEqualToConstant:0.8],

        [scrollView.topAnchor constraintEqualToAnchor:headerDivider.bottomAnchor constant:12],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.applyButton.topAnchor constant:-12],

        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.applyButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [self.applyButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (UIView *)buildSectionHeader:(NSString *)title {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = title;
    lbl.font = [Styling fontBold:13.5];
    lbl.textColor = [UIColor ppTextSecondary];
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    return lbl;
}

- (UIView *)buildStatusPillRow {
    NSArray<NSDictionary *> *defs = @[
        @{@"filter": @(PPDeliveryFilterAll), @"title": kLang(@"Deliv_FilterSheet_All")},
        @{@"filter": @(PPDeliveryFilterReady), @"title": kLang(@"Deliv_FilterSheet_ReadyOnly")},
        @{@"filter": @(PPDeliveryFilterInTransit), @"title": kLang(@"Deliv_FilterSheet_InTransitOnly")},
        @{@"filter": @(PPDeliveryFilterDelivered), @"title": kLang(@"Deliv_FilterSheet_DeliveredOnly")},
        @{@"filter": @(PPDeliveryFilterCancelled), @"title": kLang(@"Deliv_FilterSheet_CancelledOnly")}
    ];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:36],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSDictionary *def in defs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:def[@"title"] forState:UIControlStateNormal];
        btn.tag = [def[@"filter"] integerValue];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        PPApplyContinuousCorners(btn, 16);
        [btn addTarget:self action:@selector(statusPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [self.statusPills addObject:btn];
        [stack addArrangedSubview:btn];
    }
    return scroll;
}

- (UIView *)buildPaymentPillRow {
    NSArray<NSDictionary *> *defs = @[
        @{@"pay": @(PPDeliveryPaymentFilterAll), @"title": kLang(@"Deliv_FilterSheet_All")},
        @{@"pay": @(PPDeliveryPaymentFilterCOD), @"title": kLang(@"Deliv_FilterSheet_CODOnly")},
        @{@"pay": @(PPDeliveryPaymentFilterPrepaid), @"title": kLang(@"Deliv_FilterSheet_PrepaidOnly")}
    ];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:36],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSDictionary *def in defs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:def[@"title"] forState:UIControlStateNormal];
        btn.tag = [def[@"pay"] integerValue];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        PPApplyContinuousCorners(btn, 16);
        [btn addTarget:self action:@selector(paymentPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [self.paymentPills addObject:btn];
        [stack addArrangedSubview:btn];
    }
    return scroll;
}

- (UIView *)buildSortPillRow {
    NSArray<NSDictionary *> *defs = @[
        @{@"sort": @(PPDeliverySortNewest), @"title": kLang(@"Deliv_FilterSheet_SortNewest")},
        @{@"sort": @(PPDeliverySortAmountHighToLow), @"title": kLang(@"Deliv_FilterSheet_SortAmountHigh")},
        @{@"sort": @(PPDeliverySortAmountLowToHigh), @"title": kLang(@"Deliv_FilterSheet_SortAmountLow")}
    ];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:36],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSDictionary *def in defs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:def[@"title"] forState:UIControlStateNormal];
        btn.tag = [def[@"sort"] integerValue];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        PPApplyContinuousCorners(btn, 16);
        [btn addTarget:self action:@selector(sortPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [self.sortPills addObject:btn];
        [stack addArrangedSubview:btn];
    }
    return scroll;
}

- (void)statusPillTapped:(UIButton *)sender {
    self.selectedStatusFilter = sender.tag;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateButtonsState];
}

- (void)paymentPillTapped:(UIButton *)sender {
    self.selectedPaymentFilter = sender.tag;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateButtonsState];
}

- (void)sortPillTapped:(UIButton *)sender {
    self.selectedSortOrder = sender.tag;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateButtonsState];
}

- (void)resetTapped {
    self.selectedStatusFilter = PPDeliveryFilterAll;
    self.selectedPaymentFilter = PPDeliveryPaymentFilterAll;
    self.selectedSortOrder = PPDeliverySortNewest;
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeWarning];
    [self updateButtonsState];
}

- (NSInteger)calculatedMatchCount {
    NSInteger count = 0;
    for (PPDeliveryOrderModel *order in self.allOrders) {
        BOOL statusMatch = YES;
        switch (self.selectedStatusFilter) {
            case PPDeliveryFilterAll: statusMatch = YES; break;
            case PPDeliveryFilterReady: statusMatch = order.isReady; break;
            case PPDeliveryFilterPendingPickup: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusAwaitingHandover] || [order.deliveryStatus isEqualToString:PPDeliveryStatusPickedUp]; break;
            case PPDeliveryFilterInTransit: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusInTransit]; break;
            case PPDeliveryFilterDelivered: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusDelivered] || [order.deliveryStatus isEqualToString:PPDeliveryStatusCompleted]; break;
            case PPDeliveryFilterCancelled: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusCancelled] || [order.deliveryStatus isEqualToString:PPDeliveryStatusFailed]; break;
        }

        BOOL paymentMatch = YES;
        switch (self.selectedPaymentFilter) {
            case PPDeliveryPaymentFilterAll: paymentMatch = YES; break;
            case PPDeliveryPaymentFilterCOD: paymentMatch = order.isCashOrder; break;
            case PPDeliveryPaymentFilterPrepaid: paymentMatch = !order.isCashOrder; break;
        }

        if (statusMatch && paymentMatch) count++;
    }
    return count;
}

- (void)updateButtonsState {
    for (UIButton *btn in self.statusPills) {
        BOOL isSel = (btn.tag == self.selectedStatusFilter);
        btn.titleLabel.font = isSel ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
        if (isSel) {
            btn.tintColor = UIColor.whiteColor;
            btn.backgroundColor = [UIColor ppPrimary];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.tintColor = [UIColor ppTextPrimary];
            btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
            btn.layer.borderWidth = 0.7;
            btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }

    for (UIButton *btn in self.paymentPills) {
        BOOL isSel = (btn.tag == self.selectedPaymentFilter);
        btn.titleLabel.font = isSel ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
        if (isSel) {
            btn.tintColor = UIColor.whiteColor;
            btn.backgroundColor = [UIColor ppPrimary];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.tintColor = [UIColor ppTextPrimary];
            btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
            btn.layer.borderWidth = 0.7;
            btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }

    for (UIButton *btn in self.sortPills) {
        BOOL isSel = (btn.tag == self.selectedSortOrder);
        btn.titleLabel.font = isSel ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
        if (isSel) {
            btn.tintColor = UIColor.whiteColor;
            btn.backgroundColor = [UIColor ppPrimary];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.tintColor = [UIColor ppTextPrimary];
            btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
            btn.layer.borderWidth = 0.7;
            btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }

    NSInteger matchCount = [self calculatedMatchCount];
    NSString *btnTitle = [NSString stringWithFormat:kLang(@"Deliv_FilterSheet_ApplyFormat"), (long)matchCount];
    [self.applyButton setTitle:btnTitle forState:UIControlStateNormal];

    BOOL isDefault = (self.selectedStatusFilter == PPDeliveryFilterAll && self.selectedPaymentFilter == PPDeliveryPaymentFilterAll && self.selectedSortOrder == PPDeliverySortNewest);
    self.resetButton.alpha = isDefault ? 0.4 : 1.0;
    self.resetButton.userInteractionEnabled = !isDefault;
}

- (void)applyTapped {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
    if (self.onApply) {
        self.onApply(self.selectedStatusFilter, self.selectedPaymentFilter, self.selectedSortOrder);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// MARK: - Category-Defining Delivery Quick Transition Sheet

@interface PPDeliveryQuickTransitionSheet : UIViewController
@property (nonatomic, strong) PPDeliveryOrderModel *order;
@property (nonatomic, copy) void (^onActionExecuted)(void);
- (instancetype)initWithOrder:(PPDeliveryOrderModel *)order;
@end

@implementation PPDeliveryQuickTransitionSheet

- (instancetype)initWithOrder:(PPDeliveryOrderModel *)order {
    self = [super init];
    if (self) {
        _order = order;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupUI];
}

- (void)setupUI {
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = [NSString stringWithFormat:@"%@ · #%@", kLang(@"Deliv_QuickAction_Title"), self.order.displayOrderNumber];
    titleLabel.font = [Styling fontBold:16.5];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:titleLabel];

    UIView *headerDivider = [[UIView alloc] init];
    headerDivider.translatesAutoresizingMaskIntoConstraints = NO;
    headerDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [self.view addSubview:headerDivider];

    // Scrollable Content
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:scrollView];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 14.0;
    contentStack.alignment = UIStackViewAlignmentFill;
    [scrollView addSubview:contentStack];

    // 1. Route Summary Surface
    UIView *routeCard = [[UIView alloc] init];
    routeCard.backgroundColor = [UIColor ppSurface];
    PPApplyContinuousCorners(routeCard, PPCornerMedium);
    routeCard.layer.borderWidth = 0.7;
    routeCard.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
    [contentStack addArrangedSubview:routeCard];

    UIStackView *routeStack = [[UIStackView alloc] init];
    routeStack.translatesAutoresizingMaskIntoConstraints = NO;
    routeStack.axis = UILayoutConstraintAxisVertical;
    routeStack.spacing = 10.0;
    [routeCard addSubview:routeStack];

    [NSLayoutConstraint activateConstraints:@[
        [routeStack.topAnchor constraintEqualToAnchor:routeCard.topAnchor constant:12],
        [routeStack.bottomAnchor constraintEqualToAnchor:routeCard.bottomAnchor constant:-12],
        [routeStack.leadingAnchor constraintEqualToAnchor:routeCard.leadingAnchor constant:14],
        [routeStack.trailingAnchor constraintEqualToAnchor:routeCard.trailingAnchor constant:-14],
    ]];

    // Pickup Row
    NSString *pickupText = [self.order pp_pickupLocationSummary];
    [routeStack addArrangedSubview:[self buildLocationRowWithIcon:@"building.2.fill"
                                                           color:[UIColor ppWarning]
                                                           title:kLang(@"Deliv_Route_Pickup")
                                                           value:pickupText.length ? pickupText : kLang(@"Deliv_BranchPendingAssignment")]];

    // Dropoff Row
    NSString *dropoffText = [self.order pp_visibleCustomerLocationSummary];
    [routeStack addArrangedSubview:[self buildLocationRowWithIcon:@"mappin.circle.fill"
                                                           color:[UIColor ppPrimary]
                                                           title:kLang(@"Deliv_Route_Dropoff")
                                                           value:dropoffText.length ? dropoffText : kLang(@"Deliv_DeliveryAreaPending")]];

    // 2. Financial Highlight (COD or Prepaid)
    UIView *financeCard = [[UIView alloc] init];
    financeCard.backgroundColor = self.order.isCashOrder ? [[UIColor ppWarning] colorWithAlphaComponent:0.08] : [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(financeCard, PPCornerSmall);
    financeCard.layer.borderWidth = 0.7;
    financeCard.layer.borderColor = (self.order.isCashOrder ? [UIColor ppWarning] : [UIColor ppSuccess]).CGColor;
    [contentStack addArrangedSubview:financeCard];

    UILabel *financeLabel = [[UILabel alloc] init];
    financeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    financeLabel.font = [Styling fontBold:14.0];
    financeLabel.textColor = self.order.isCashOrder ? [UIColor ppWarning] : [UIColor ppSuccess];
    financeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    if (self.order.isCashOrder) {
        financeLabel.text = [NSString stringWithFormat:@"💵 %@: %@", kLang(@"Deliv_CashOnDelivery"), [self.order formattedTotal]];
    } else {
        financeLabel.text = [NSString stringWithFormat:@"💳 %@ · %@", kLang(@"Deliv_OnlinePayment"), [self.order formattedTotal]];
    }
    [financeCard addSubview:financeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [financeLabel.topAnchor constraintEqualToAnchor:financeCard.topAnchor constant:10],
        [financeLabel.bottomAnchor constraintEqualToAnchor:financeCard.bottomAnchor constant:-10],
        [financeLabel.leadingAnchor constraintEqualToAnchor:financeCard.leadingAnchor constant:12],
        [financeLabel.trailingAnchor constraintEqualToAnchor:financeCard.trailingAnchor constant:-12],
    ]];

    // 3. Main Action Button
    UIButton *primaryActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    primaryActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    primaryActionBtn.titleLabel.font = [Styling fontBold:16.0];
    primaryActionBtn.tintColor = UIColor.whiteColor;
    primaryActionBtn.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(primaryActionBtn, 22);
    PPApplyButtonShadow(primaryActionBtn);

    if (self.order.canAcceptDelivery) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_Accept") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(acceptActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (self.order.canConfirmPackageHandover) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_Pickup") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(pickupActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (self.order.canMarkInTransit) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_Transit") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(transitActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (self.order.canMarkDelivered) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_Deliver") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(deliverActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (self.order.canCollectCashPayment) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_CollectCash") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(cashActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else if (self.order.canMarkCompleted) {
        [primaryActionBtn setTitle:kLang(@"Deliv_QuickAction_Complete") forState:UIControlStateNormal];
        [primaryActionBtn addTarget:self action:@selector(completeActionTapped) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [primaryActionBtn setTitle:self.order.displayStatus forState:UIControlStateNormal];
        primaryActionBtn.enabled = NO;
        primaryActionBtn.alpha = 0.6;
    }
    [self.view addSubview:primaryActionBtn];

    // Shortcuts: Map & Call
    UIStackView *shortcutStack = [[UIStackView alloc] init];
    shortcutStack.translatesAutoresizingMaskIntoConstraints = NO;
    shortcutStack.axis = UILayoutConstraintAxisHorizontal;
    shortcutStack.spacing = 10.0;
    shortcutStack.distribution = UIStackViewDistributionFillEqually;
    [self.view addSubview:shortcutStack];

    UIButton *mapBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [mapBtn setTitle:[NSString stringWithFormat:@"🗺️ %@", kLang(@"Deliv_Action_Maps")] forState:UIControlStateNormal];
    mapBtn.titleLabel.font = [Styling fontBold:13.5];
    mapBtn.tintColor = [UIColor ppPrimary];
    mapBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(mapBtn, 16);
    [mapBtn addTarget:self action:@selector(mapShortcutTapped) forControlEvents:UIControlEventTouchUpInside];
    [shortcutStack addArrangedSubview:mapBtn];

    UIButton *callBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [callBtn setTitle:[NSString stringWithFormat:@"📞 %@", kLang(@"Deliv_Action_Call")] forState:UIControlStateNormal];
    callBtn.titleLabel.font = [Styling fontBold:13.5];
    callBtn.tintColor = [UIColor ppSuccess];
    callBtn.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(callBtn, 16);
    [callBtn addTarget:self action:@selector(callShortcutTapped) forControlEvents:UIControlEventTouchUpInside];
    [shortcutStack addArrangedSubview:callBtn];

    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [titleLabel.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],

        [headerDivider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [headerDivider.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerDivider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerDivider.heightAnchor constraintEqualToConstant:0.8],

        [scrollView.topAnchor constraintEqualToAnchor:headerDivider.bottomAnchor constant:12],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [scrollView.bottomAnchor constraintEqualToAnchor:shortcutStack.topAnchor constant:-12],

        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-10],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

        [shortcutStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [shortcutStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [shortcutStack.bottomAnchor constraintEqualToAnchor:primaryActionBtn.topAnchor constant:-10],
        [shortcutStack.heightAnchor constraintEqualToConstant:40],

        [primaryActionBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [primaryActionBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [primaryActionBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [primaryActionBtn.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (UIView *)buildLocationRowWithIcon:(NSString *)iconName color:(UIColor *)color title:(NSString *)title value:(NSString *)value {
    UIView *row = [[UIView alloc] init];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = color;
    [row addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontMedium:12.0];
    titleLbl.textColor = [UIColor ppTextSecondary];
    titleLbl.text = title;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:titleLbl];

    UILabel *valLbl = [[UILabel alloc] init];
    valLbl.translatesAutoresizingMaskIntoConstraints = NO;
    valLbl.font = [Styling fontBold:13.0];
    valLbl.textColor = [UIColor ppTextPrimary];
    valLbl.text = value;
    valLbl.numberOfLines = 2;
    valLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:valLbl];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:row.topAnchor constant:2],
        [icon.widthAnchor constraintEqualToConstant:18],
        [icon.heightAnchor constraintEqualToConstant:18],

        [titleLbl.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
        [titleLbl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [titleLbl.topAnchor constraintEqualToAnchor:row.topAnchor],

        [valLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [valLbl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:2],
        [valLbl.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];

    return row;
}

- (void)acceptActionTapped {
    [self executeActionNamed:@"accept"];
}

- (void)pickupActionTapped {
    [self executeActionNamed:@"pickup"];
}

- (void)transitActionTapped {
    [self executeActionNamed:@"transit"];
}

- (void)deliverActionTapped {
    [self executeActionNamed:@"deliver"];
}

- (void)cashActionTapped {
    [self executeActionNamed:@"cash"];
}

- (void)completeActionTapped {
    [self executeActionNamed:@"complete"];
}

- (void)executeActionNamed:(NSString *)action {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    __weak typeof(self) ws = self;
    PPDeliveryActionBlock callback = ^(BOOL success, NSString *msg, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [PPToast toast:kLang(@"Success") style:PPToastStyleSuccess haptic:YES duration:2.5];
                if (ws.onActionExecuted) ws.onActionExecuted();
                [ws dismissViewControllerAnimated:YES completion:nil];
            } else {
                [PPToast toast:err.localizedDescription ?: msg style:PPToastStyleError haptic:YES duration:3.0];
            }
        });
    };

    if ([action isEqualToString:@"accept"]) {
        [[PPDeliveryManager shared] acceptDeliveryOrder:self.order.orderId completion:callback];
    } else if ([action isEqualToString:@"pickup"]) {
        [[PPDeliveryManager shared] markOrderShipped:self.order.orderId note:nil completion:callback];
    } else if ([action isEqualToString:@"transit"]) {
        [[PPDeliveryManager shared] markOrderInTransit:self.order.orderId note:nil completion:callback];
    } else if ([action isEqualToString:@"deliver"]) {
        [[PPDeliveryManager shared] markOrderDelivered:self.order.orderId note:nil completion:callback];
    } else if ([action isEqualToString:@"cash"]) {
        [[PPDeliveryManager shared] collectCashPayment:self.order.orderId note:nil completion:callback];
    } else if ([action isEqualToString:@"complete"]) {
        [[PPDeliveryManager shared] markOrderCompleted:self.order.orderId note:nil completion:callback];
    }
}

- (void)mapShortcutTapped {
    [PPFunc pp_playTapEffect];
    NSString *loc = self.order.deliveryLocationPoint;
    if (loc.length) {
        NSArray *parts = [loc componentsSeparatedByString:@","];
        if (parts.count == 2) {
            double lat = [parts[0] doubleValue];
            double lng = [parts[1] doubleValue];
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%f,%f", lat, lng]];
            if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            return;
        }
    }
    NSString *addr = [self.order pp_exactDeliveryLocationText];
    if (addr.length) {
        NSString *enc = [addr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%@", enc]];
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)callShortcutTapped {
    [PPFunc pp_playTapEffect];
    NSString *phone = self.order.customerPhone;
    if (phone.length) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phone]];
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [PPToast toast:kLang(@"Deliv_Call_Unavailable") style:PPToastStyleWarning haptic:YES duration:2.5];
    }
}

@end

// MARK: - Category-Defining Delivery Operation Card Cell

@interface PPDeliveryOperationCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *orderNumberPill;
@property (nonatomic, strong) UIView *statusBadgeContainer;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UILabel *itemsCountPill;

@property (nonatomic, strong) UIImageView *pickupIcon;
@property (nonatomic, strong) UILabel *pickupLabel;
@property (nonatomic, strong) UIView *routeConnectorLine;
@property (nonatomic, strong) UIImageView *dropoffIcon;
@property (nonatomic, strong) UILabel *dropoffLabel;

@property (nonatomic, strong) UILabel *customerNameLabel;
@property (nonatomic, strong) UILabel *totalAmountLabel;
@property (nonatomic, strong) UIView *paymentBadge;
@property (nonatomic, strong) UILabel *paymentBadgeLabel;

@property (nonatomic, strong) UIButton *mapButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *detailsButton;

@property (nonatomic, strong) PPDeliveryOrderModel *order;
@property (nonatomic, copy) void (^onMapTapped)(PPDeliveryOrderModel *order);
@property (nonatomic, copy) void (^onCallTapped)(PPDeliveryOrderModel *order);
@property (nonatomic, copy) void (^onActionTapped)(PPDeliveryOrderModel *order);
@property (nonatomic, copy) void (^onDetailsTapped)(PPDeliveryOrderModel *order);

- (void)configureWithOrder:(PPDeliveryOrderModel *)order;
@end

@implementation PPDeliveryOperationCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self setupCardUI];
    }
    return self;
}

- (void)setupCardUI {
    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [UIColor ppSurface];
    PPApplyContinuousCorners(_cardView, PPCornerCard);
    PPApplyCardShadow(_cardView);
    _cardView.layer.borderWidth = 0.7;
    _cardView.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.7].CGColor;
    [self.contentView addSubview:_cardView];

    // 1. Top Strip: Order #, Status Pill, Items Count
    _orderNumberPill = [[UILabel alloc] init];
    _orderNumberPill.translatesAutoresizingMaskIntoConstraints = NO;
    _orderNumberPill.font = [Styling fontBold:12.0];
    _orderNumberPill.textColor = [UIColor ppTextPrimary];
    _orderNumberPill.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.4];
    _orderNumberPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_orderNumberPill, 8);
    _orderNumberPill.clipsToBounds = YES;
    [_cardView addSubview:_orderNumberPill];

    _statusBadgeContainer = [[UIView alloc] init];
    _statusBadgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_statusBadgeContainer, 10);
    [_cardView addSubview:_statusBadgeContainer];

    _statusBadgeLabel = [[UILabel alloc] init];
    _statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgeLabel.font = [Styling fontBold:11.5];
    _statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [_statusBadgeContainer addSubview:_statusBadgeLabel];

    _itemsCountPill = [[UILabel alloc] init];
    _itemsCountPill.translatesAutoresizingMaskIntoConstraints = NO;
    _itemsCountPill.font = [Styling fontMedium:11.0];
    _itemsCountPill.textColor = [UIColor ppTextSecondary];
    _itemsCountPill.textAlignment = NSTextAlignmentCenter;
    [_cardView addSubview:_itemsCountPill];

    // 2. Route Visual Journey
    UIView *routeBox = [[UIView alloc] init];
    routeBox.translatesAutoresizingMaskIntoConstraints = NO;
    routeBox.backgroundColor = [[UIColor ppBackground] colorWithAlphaComponent:0.5];
    PPApplyContinuousCorners(routeBox, PPCornerSmall);
    [_cardView addSubview:routeBox];

    _pickupIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"building.2.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]]];
    _pickupIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _pickupIcon.tintColor = [UIColor ppWarning];
    [routeBox addSubview:_pickupIcon];

    _pickupLabel = [[UILabel alloc] init];
    _pickupLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _pickupLabel.font = [Styling fontMedium:12.0];
    _pickupLabel.textColor = [UIColor ppTextSecondary];
    _pickupLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [routeBox addSubview:_pickupLabel];

    _routeConnectorLine = [[UIView alloc] init];
    _routeConnectorLine.translatesAutoresizingMaskIntoConstraints = NO;
    _routeConnectorLine.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.7];
    [routeBox addSubview:_routeConnectorLine];

    _dropoffIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]]];
    _dropoffIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _dropoffIcon.tintColor = [UIColor ppPrimary];
    [routeBox addSubview:_dropoffIcon];

    _dropoffLabel = [[UILabel alloc] init];
    _dropoffLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dropoffLabel.font = [Styling fontBold:12.5];
    _dropoffLabel.textColor = [UIColor ppTextPrimary];
    _dropoffLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [routeBox addSubview:_dropoffLabel];

    // 3. Customer & Financial Bar
    _customerNameLabel = [[UILabel alloc] init];
    _customerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _customerNameLabel.font = [Styling fontBold:14.0];
    _customerNameLabel.textColor = [UIColor ppTextPrimary];
    _customerNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_customerNameLabel];

    _totalAmountLabel = [[UILabel alloc] init];
    _totalAmountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _totalAmountLabel.font = [Styling fontBold:15.0];
    _totalAmountLabel.textColor = [UIColor ppPrimary];
    _totalAmountLabel.textAlignment = NSTextAlignmentRight;
    [_cardView addSubview:_totalAmountLabel];

    _paymentBadge = [[UIView alloc] init];
    _paymentBadge.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_paymentBadge, 8);
    [_cardView addSubview:_paymentBadge];

    _paymentBadgeLabel = [[UILabel alloc] init];
    _paymentBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _paymentBadgeLabel.font = [Styling fontBold:11.0];
    _paymentBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [_paymentBadge addSubview:_paymentBadgeLabel];

    // 4. Tactile Micro-Action Strip
    UIStackView *actionStrip = [[UIStackView alloc] init];
    actionStrip.translatesAutoresizingMaskIntoConstraints = NO;
    actionStrip.axis = UILayoutConstraintAxisHorizontal;
    actionStrip.spacing = 8.0;
    actionStrip.distribution = UIStackViewDistributionFillEqually;
    [_cardView addSubview:actionStrip];

    _mapButton = [self buildMicroActionButtonWithTitle:kLang(@"Deliv_Action_Maps") icon:@"map.fill" color:[UIColor ppInfo] selector:@selector(mapTapped)];
    _callButton = [self buildMicroActionButtonWithTitle:kLang(@"Deliv_Action_Call") icon:@"phone.fill" color:[UIColor ppSuccess] selector:@selector(callTapped)];
    _actionButton = [self buildMicroActionButtonWithTitle:kLang(@"Deliv_Action_Update") icon:@"bolt.fill" color:[UIColor ppPrimary] selector:@selector(actionTapped)];
    _detailsButton = [self buildMicroActionButtonWithTitle:kLang(@"Deliv_Action_Details") icon:@"ellipsis.circle.fill" color:[UIColor ppTextSecondary] selector:@selector(detailsTapped)];

    [actionStrip addArrangedSubview:_mapButton];
    [actionStrip addArrangedSubview:_callButton];
    [actionStrip addArrangedSubview:_actionButton];
    [actionStrip addArrangedSubview:_detailsButton];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],

        // Top Row
        [_orderNumberPill.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:12],
        [_orderNumberPill.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
        [_orderNumberPill.heightAnchor constraintEqualToConstant:22],
        [_orderNumberPill.widthAnchor constraintGreaterThanOrEqualToConstant:60],

        [_itemsCountPill.centerYAnchor constraintEqualToAnchor:_orderNumberPill.centerYAnchor],
        [_itemsCountPill.leadingAnchor constraintEqualToAnchor:_orderNumberPill.trailingAnchor constant:8],

        [_statusBadgeContainer.centerYAnchor constraintEqualToAnchor:_orderNumberPill.centerYAnchor],
        [_statusBadgeContainer.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],
        [_statusBadgeContainer.heightAnchor constraintEqualToConstant:22],

        [_statusBadgeLabel.leadingAnchor constraintEqualToAnchor:_statusBadgeContainer.leadingAnchor constant:8],
        [_statusBadgeLabel.trailingAnchor constraintEqualToAnchor:_statusBadgeContainer.trailingAnchor constant:-8],
        [_statusBadgeLabel.centerYAnchor constraintEqualToAnchor:_statusBadgeContainer.centerYAnchor],

        // Route Box
        [routeBox.topAnchor constraintEqualToAnchor:_orderNumberPill.bottomAnchor constant:10],
        [routeBox.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
        [routeBox.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],

        [_pickupIcon.topAnchor constraintEqualToAnchor:routeBox.topAnchor constant:8],
        [_pickupIcon.leadingAnchor constraintEqualToAnchor:routeBox.leadingAnchor constant:8],
        [_pickupIcon.widthAnchor constraintEqualToConstant:14],
        [_pickupIcon.heightAnchor constraintEqualToConstant:14],

        [_pickupLabel.centerYAnchor constraintEqualToAnchor:_pickupIcon.centerYAnchor],
        [_pickupLabel.leadingAnchor constraintEqualToAnchor:_pickupIcon.trailingAnchor constant:6],
        [_pickupLabel.trailingAnchor constraintEqualToAnchor:routeBox.trailingAnchor constant:-8],

        [_routeConnectorLine.topAnchor constraintEqualToAnchor:_pickupIcon.bottomAnchor constant:2],
        [_routeConnectorLine.centerXAnchor constraintEqualToAnchor:_pickupIcon.centerXAnchor],
        [_routeConnectorLine.widthAnchor constraintEqualToConstant:1.5],
        [_routeConnectorLine.heightAnchor constraintEqualToConstant:10],

        [_dropoffIcon.topAnchor constraintEqualToAnchor:_routeConnectorLine.bottomAnchor constant:2],
        [_dropoffIcon.centerXAnchor constraintEqualToAnchor:_pickupIcon.centerXAnchor],
        [_dropoffIcon.widthAnchor constraintEqualToConstant:14],
        [_dropoffIcon.heightAnchor constraintEqualToConstant:14],
        [_dropoffIcon.bottomAnchor constraintEqualToAnchor:routeBox.bottomAnchor constant:-8],

        [_dropoffLabel.centerYAnchor constraintEqualToAnchor:_dropoffIcon.centerYAnchor],
        [_dropoffLabel.leadingAnchor constraintEqualToAnchor:_dropoffIcon.trailingAnchor constant:6],
        [_dropoffLabel.trailingAnchor constraintEqualToAnchor:routeBox.trailingAnchor constant:-8],

        // Customer & Financial Bar
        [_customerNameLabel.topAnchor constraintEqualToAnchor:routeBox.bottomAnchor constant:10],
        [_customerNameLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],

        [_totalAmountLabel.centerYAnchor constraintEqualToAnchor:_customerNameLabel.centerYAnchor],
        [_totalAmountLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],
        [_totalAmountLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_customerNameLabel.trailingAnchor constant:8],

        [_paymentBadge.topAnchor constraintEqualToAnchor:_customerNameLabel.bottomAnchor constant:6],
        [_paymentBadge.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
        [_paymentBadge.heightAnchor constraintEqualToConstant:20],

        [_paymentBadgeLabel.leadingAnchor constraintEqualToAnchor:_paymentBadge.leadingAnchor constant:6],
        [_paymentBadgeLabel.trailingAnchor constraintEqualToAnchor:_paymentBadge.trailingAnchor constant:-6],
        [_paymentBadgeLabel.centerYAnchor constraintEqualToAnchor:_paymentBadge.centerYAnchor],

        // Action Strip
        [actionStrip.topAnchor constraintEqualToAnchor:_paymentBadge.bottomAnchor constant:12],
        [actionStrip.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:10],
        [actionStrip.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-10],
        [actionStrip.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-12],
        [actionStrip.heightAnchor constraintEqualToConstant:34],
    ]];
}

- (UIButton *)buildMicroActionButtonWithTitle:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color selector:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11.5 weight:UIImageSymbolWeightSemibold];
    [btn setImage:[UIImage systemImageNamed:iconName withConfiguration:cfg] forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontBold:11.5];
    btn.tintColor = color;
    btn.backgroundColor = [color colorWithAlphaComponent:0.09];
    PPApplyContinuousCorners(btn, 12);
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)configureWithOrder:(PPDeliveryOrderModel *)order {
    _order = order;
    _orderNumberPill.text = [NSString stringWithFormat:@"#%@", order.displayOrderNumber];
    _customerNameLabel.text = order.customerName.length ? order.customerName : kLang(@"Deliv_CustomerInfo");
    _totalAmountLabel.text = [order formattedTotal];
    _itemsCountPill.text = [NSString stringWithFormat:kLang(@"Deliv_ItemsInOrder"), (long)order.items.count];

    // Pickup & Dropoff
    NSString *pickup = [order pp_pickupLocationSummary];
    _pickupLabel.text = pickup.length ? pickup : kLang(@"Deliv_BranchPendingAssignment");
    NSString *dropoff = [order pp_visibleCustomerLocationSummary];
    _dropoffLabel.text = dropoff.length ? dropoff : kLang(@"Deliv_DeliveryAreaPending");

    // Status Pill
    NSString *statusStr = order.displayStatus;
    _statusBadgeLabel.text = statusStr;

    if ([order.deliveryStatus isEqualToString:PPDeliveryStatusInTransit]) {
        _statusBadgeContainer.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.12];
        _statusBadgeLabel.textColor = [UIColor ppInfo];
    } else if (order.isReady || [order.deliveryStatus isEqualToString:PPDeliveryStatusAwaitingHandover]) {
        _statusBadgeContainer.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.12];
        _statusBadgeLabel.textColor = [UIColor ppWarning];
    } else if ([order.deliveryStatus isEqualToString:PPDeliveryStatusDelivered] || [order.deliveryStatus isEqualToString:PPDeliveryStatusCompleted]) {
        _statusBadgeContainer.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        _statusBadgeLabel.textColor = [UIColor ppSuccess];
    } else {
        _statusBadgeContainer.backgroundColor = [[UIColor ppTextSecondary] colorWithAlphaComponent:0.10];
        _statusBadgeLabel.textColor = [UIColor ppTextSecondary];
    }

    // Payment Badge
    if (order.isCashOrder) {
        _paymentBadge.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.12];
        _paymentBadgeLabel.textColor = [UIColor ppWarning];
        _paymentBadgeLabel.text = [NSString stringWithFormat:@"💵 %@", kLang(@"Deliv_CashOnDelivery")];
    } else {
        _paymentBadge.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        _paymentBadgeLabel.textColor = [UIColor ppSuccess];
        _paymentBadgeLabel.text = [NSString stringWithFormat:@"💳 %@", kLang(@"Deliv_OnlinePayment")];
    }
}

- (void)mapTapped {
    if (self.onMapTapped) self.onMapTapped(self.order);
}

- (void)callTapped {
    if (self.onCallTapped) self.onCallTapped(self.order);
}

- (void)actionTapped {
    if (self.onActionTapped) self.onActionTapped(self.order);
}

- (void)detailsTapped {
    if (self.onDetailsTapped) self.onDetailsTapped(self.order);
}

@end

// MARK: - Reimagined Delivery Dashboard View Controller

@interface PPDeliveryDashboardViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

// Telemetry HUD
@property (nonatomic, strong) UIView *flightDeckHeader;
@property (nonatomic, strong) UILabel *inTransitCountBadge;
@property (nonatomic, strong) UILabel *readyCountBadge;
@property (nonatomic, strong) UILabel *deliveredCountBadge;
@property (nonatomic, strong) UILabel *codPendingCountBadge;

// Omni Search & Filter Capsule
@property (nonatomic, strong) UITextField *omniSearchField;
@property (nonatomic, strong) UIButton *clearSearchButton;
@property (nonatomic, strong) UILabel *resultsCountBadge;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *filterBadgeDot;

// Table & Empty State
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *emptyStateView;

// Data State
@property (nonatomic, copy) NSArray<PPDeliveryOrderModel *> *allOrders;
@property (nonatomic, copy) NSArray<PPDeliveryOrderModel *> *filteredOrders;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPDeliveryFilter currentStatusFilter;
@property (nonatomic, assign) PPDeliveryPaymentFilter currentPaymentFilter;
@property (nonatomic, assign) PPDeliverySortOrder currentSortOrder;
@property (nonatomic, assign) BOOL hasLoadedOnce;

@end

@implementation PPDeliveryDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.allOrders = @[];
    self.filteredOrders = @[];
    self.searchQuery = @"";
    self.currentStatusFilter = PPDeliveryFilterAll;
    self.currentPaymentFilter = PPDeliveryPaymentFilterAll;
    self.currentSortOrder = PPDeliverySortNewest;
    self.hasLoadedOnce = NO;

    [self setupTableView];
    [self setupEmptyState];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ordersDidChange:)
                                                 name:PPDeliveryOrdersDidChangeNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Deliv_Cockpit_Title") showBack:YES];
    [[PPDeliveryManager shared] startListeningForDeliveryOrders];
    [self reloadOrdersFromManager];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [[PPDeliveryManager shared] stopListening];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 210;
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 40, 0);
    _tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_tableView registerClass:PPDeliveryOperationCardCell.class forCellReuseIdentifier:@"PPDeliveryOperationCardCell"];
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.color = [UIColor ppPrimary];
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    [self rebuildFlightDeckHeader];
}

- (void)rebuildFlightDeckHeader {
    CGFloat screenW = CGRectGetWidth(self.view.bounds);
    if (screenW <= 0) screenW = UIScreen.mainScreen.bounds.size.width;

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 238)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // Subtitle Eyebrow
    UILabel *cockpitSubtitle = [[UILabel alloc] init];
    cockpitSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitSubtitle.text = kLang(@"Deliv_Cockpit_Subtitle");
    cockpitSubtitle.font = [Styling fontMedium:12.5];
    cockpitSubtitle.textColor = [UIColor ppTextSecondary];
    cockpitSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    [header addSubview:cockpitSubtitle];

    // 1. Dispatch Telemetry HUD (4 Cards)
    UIView *hudBox = [[UIView alloc] init];
    hudBox.translatesAutoresizingMaskIntoConstraints = NO;
    hudBox.backgroundColor = [UIColor ppSurface];
    hudBox.layer.borderWidth = 0.8;
    hudBox.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75].CGColor;
    PPApplyContinuousCorners(hudBox, PPCornerMedium);
    PPApplyCardShadow(hudBox);
    [header addSubview:hudBox];

    UIStackView *hudStack = [[UIStackView alloc] init];
    hudStack.translatesAutoresizingMaskIntoConstraints = NO;
    hudStack.axis = UILayoutConstraintAxisHorizontal;
    hudStack.spacing = 8.0;
    hudStack.distribution = UIStackViewDistributionFillEqually;
    [hudBox addSubview:hudStack];

    self.inTransitCountBadge = [[UILabel alloc] init];
    UIView *cardInTransit = [self buildHUDCardWithTitle:kLang(@"Deliv_HUD_InTransit")
                                                  badge:self.inTransitCountBadge
                                                   icon:@"car.fill"
                                                  color:[UIColor ppInfo]
                                            tapSelector:@selector(filterInTransitTapped)];

    self.readyCountBadge = [[UILabel alloc] init];
    UIView *cardReady = [self buildHUDCardWithTitle:kLang(@"Deliv_HUD_Ready")
                                              badge:self.readyCountBadge
                                               icon:@"shippingbox.fill"
                                              color:[UIColor ppWarning]
                                        tapSelector:@selector(filterReadyTapped)];

    self.deliveredCountBadge = [[UILabel alloc] init];
    UIView *cardDelivered = [self buildHUDCardWithTitle:kLang(@"Deliv_HUD_Delivered")
                                                  badge:self.deliveredCountBadge
                                                   icon:@"checkmark.circle.fill"
                                                  color:[UIColor ppSuccess]
                                            tapSelector:@selector(filterDeliveredTapped)];

    self.codPendingCountBadge = [[UILabel alloc] init];
    UIView *cardCOD = [self buildHUDCardWithTitle:kLang(@"Deliv_HUD_COD")
                                            badge:self.codPendingCountBadge
                                             icon:@"banknote.fill"
                                            color:[UIColor ppPrimary]
                                      tapSelector:@selector(filterCODTapped)];

    [hudStack addArrangedSubview:cardInTransit];
    [hudStack addArrangedSubview:cardReady];
    [hudStack addArrangedSubview:cardDelivered];
    [hudStack addArrangedSubview:cardCOD];

    // 2. Omni-Search & Filter Command Capsule
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    searchContainer.backgroundColor = [UIColor ppSurfaceElevated];
    searchContainer.layer.borderWidth = 0.8;
    searchContainer.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75].CGColor;
    PPApplyContinuousCorners(searchContainer, PPCornerMedium);
    PPApplyCardShadow(searchContainer);
    [header addSubview:searchContainer];

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.07];
    PPApplyContinuousCorners(iconBadge, 14);
    [searchContainer addSubview:iconBadge];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppPrimary];
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:searchIcon];

    self.omniSearchField = [[UITextField alloc] init];
    self.omniSearchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.omniSearchField.placeholder = kLang(@"Deliv_SearchOrders");
    self.omniSearchField.font = [Styling fontMedium:13.5];
    self.omniSearchField.textColor = [UIColor ppTextPrimary];
    self.omniSearchField.textAlignment = Language.alignmentForCurrentLanguage;
    self.omniSearchField.returnKeyType = UIReturnKeySearch;
    self.omniSearchField.delegate = self;
    [self.omniSearchField addTarget:self action:@selector(searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [searchContainer addSubview:self.omniSearchField];

    self.resultsCountBadge = [[UILabel alloc] init];
    self.resultsCountBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsCountBadge.font = [Styling fontBold:11.0];
    self.resultsCountBadge.textColor = [UIColor ppPrimary];
    self.resultsCountBadge.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.10];
    self.resultsCountBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.resultsCountBadge, 8);
    self.resultsCountBadge.clipsToBounds = YES;
    [searchContainer addSubview:self.resultsCountBadge];

    self.clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearSearchButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    self.clearSearchButton.tintColor = [UIColor ppTextTertiary];
    self.clearSearchButton.hidden = YES;
    [self.clearSearchButton addTarget:self action:@selector(clearSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [searchContainer addSubview:self.clearSearchButton];

    // Integrated Filter Button
    self.filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *fCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    [self.filterButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:fCfg] forState:UIControlStateNormal];
    [self.filterButton setTitle:[NSString stringWithFormat:@" %@", kLang(@"Deliv_Filter_Button")] forState:UIControlStateNormal];
    self.filterButton.titleLabel.font = [Styling fontBold:12.0];
    self.filterButton.tintColor = [UIColor ppTextSecondary];
    self.filterButton.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
    self.filterButton.layer.borderWidth = 0.7;
    self.filterButton.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
    self.filterButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    PPApplyContinuousCorners(self.filterButton, 15);
    [self.filterButton addTarget:self action:@selector(openFilterSheet) forControlEvents:UIControlEventTouchUpInside];
    [searchContainer addSubview:self.filterButton];

    self.filterBadgeDot = [[UIView alloc] init];
    self.filterBadgeDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterBadgeDot.backgroundColor = [UIColor ppPrimary];
    self.filterBadgeDot.layer.cornerRadius = 3.5;
    self.filterBadgeDot.hidden = YES;
    [self.filterButton addSubview:self.filterBadgeDot];

    [NSLayoutConstraint activateConstraints:@[
        [cockpitSubtitle.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [cockpitSubtitle.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [cockpitSubtitle.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],

        [hudBox.topAnchor constraintEqualToAnchor:cockpitSubtitle.bottomAnchor constant:10],
        [hudBox.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [hudBox.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [hudBox.heightAnchor constraintEqualToConstant:78],

        [hudStack.topAnchor constraintEqualToAnchor:hudBox.topAnchor constant:6],
        [hudStack.bottomAnchor constraintEqualToAnchor:hudBox.bottomAnchor constant:-6],
        [hudStack.leadingAnchor constraintEqualToAnchor:hudBox.leadingAnchor constant:8],
        [hudStack.trailingAnchor constraintEqualToAnchor:hudBox.trailingAnchor constant:-8],

        [searchContainer.topAnchor constraintEqualToAnchor:hudBox.bottomAnchor constant:12],
        [searchContainer.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [searchContainer.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [searchContainer.heightAnchor constraintEqualToConstant:46],

        [iconBadge.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor constant:8],
        [iconBadge.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:28],
        [iconBadge.heightAnchor constraintEqualToConstant:28],

        [searchIcon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [searchIcon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:14],
        [searchIcon.heightAnchor constraintEqualToConstant:14],

        [self.omniSearchField.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:8],
        [self.omniSearchField.trailingAnchor constraintEqualToAnchor:self.resultsCountBadge.leadingAnchor constant:-6],
        [self.omniSearchField.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],

        [self.resultsCountBadge.trailingAnchor constraintEqualToAnchor:self.clearSearchButton.leadingAnchor constant:-4],
        [self.resultsCountBadge.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.resultsCountBadge.heightAnchor constraintEqualToConstant:20],
        [self.resultsCountBadge.widthAnchor constraintGreaterThanOrEqualToConstant:26],

        [self.clearSearchButton.trailingAnchor constraintEqualToAnchor:self.filterButton.leadingAnchor constant:-8],
        [self.clearSearchButton.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.clearSearchButton.widthAnchor constraintEqualToConstant:22],
        [self.clearSearchButton.heightAnchor constraintEqualToConstant:22],

        [self.filterButton.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor constant:-7],
        [self.filterButton.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.filterButton.heightAnchor constraintEqualToConstant:32],
        [self.filterButton.widthAnchor constraintGreaterThanOrEqualToConstant:76],

        [self.filterBadgeDot.topAnchor constraintEqualToAnchor:self.filterButton.topAnchor constant:4],
        [self.filterBadgeDot.trailingAnchor constraintEqualToAnchor:self.filterButton.trailingAnchor constant:-4],
        [self.filterBadgeDot.widthAnchor constraintEqualToConstant:7],
        [self.filterBadgeDot.heightAnchor constraintEqualToConstant:7],
    ]];

    self.flightDeckHeader = header;
    self.tableView.tableHeaderView = header;
}

- (UIView *)buildHUDCardWithTitle:(NSString *)title badge:(UILabel *)badge icon:(NSString *)iconName color:(UIColor *)color tapSelector:(SEL)selector {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [[UIColor ppBackground] colorWithAlphaComponent:0.65];
    PPApplyContinuousCorners(card, PPCornerSmall);

    if (selector) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selector];
        [card addGestureRecognizer:tap];
        card.userInteractionEnabled = YES;
    }

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = color;
    [card addSubview:icon];

    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.font = [Styling fontBold:15.0];
    badge.textColor = [UIColor ppTextPrimary];
    badge.text = @"0";
    badge.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:badge];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontMedium:10.5];
    titleLbl.textColor = [UIColor ppTextSecondary];
    titleLbl.text = title;
    titleLbl.numberOfLines = 1;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:titleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [icon.widthAnchor constraintEqualToConstant:14],
        [icon.heightAnchor constraintEqualToConstant:14],

        [badge.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:3],
        [badge.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [badge.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],

        [titleLbl.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:2],
        [titleLbl.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [titleLbl.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
        [titleLbl.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-6],
    ]];

    return card;
}

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] init];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.35];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [_emptyStateView addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontBold:17.0];
    titleLbl.textColor = [UIColor ppTextPrimary];
    titleLbl.text = kLang(@"Deliv_EmptyTitle");
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [_emptyStateView addSubview:titleLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.font = [Styling fontRegular:13.5];
    subLbl.textColor = [UIColor ppTextSecondary];
    subLbl.text = kLang(@"Deliv_EmptySubtitle");
    subLbl.textAlignment = NSTextAlignmentCenter;
    subLbl.numberOfLines = 2;
    [_emptyStateView addSubview:subLbl];

    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshBtn setTitle:kLang(@"CommandCenter_Refresh") forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [Styling fontBold:13.5];
    refreshBtn.tintColor = [UIColor ppPrimary];
    refreshBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(refreshBtn, 16);
    [refreshBtn addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventTouchUpInside];
    [_emptyStateView addSubview:refreshBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:50],
        [_emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceXL],
        [_emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceXL],

        [icon.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [icon.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [icon.widthAnchor constraintEqualToConstant:56],
        [icon.heightAnchor constraintEqualToConstant:56],

        [titleLbl.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [titleLbl.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:6],
        [subLbl.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [subLbl.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [refreshBtn.topAnchor constraintEqualToAnchor:subLbl.bottomAnchor constant:16],
        [refreshBtn.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [refreshBtn.widthAnchor constraintEqualToConstant:140],
        [refreshBtn.heightAnchor constraintEqualToConstant:38],
        [refreshBtn.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor],
    ]];
}

#pragma mark - Data & Filtering

- (void)ordersDidChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadOrdersFromManager];
    });
}

- (void)handleRefresh {
    [self.refreshControl endRefreshing];
    [self reloadOrdersFromManager];
}

- (void)reloadOrdersFromManager {
    self.allOrders = [[PPDeliveryManager shared] allOrders] ?: @[];
    self.hasLoadedOnce = YES;
    [self updateCockpitUI];
}

- (void)updateCockpitUI {
    // 1. Calculate HUD Telemetry
    NSInteger inTransitCount = 0;
    NSInteger readyCount = 0;
    NSInteger deliveredCount = 0;
    NSInteger codCount = 0;

    for (PPDeliveryOrderModel *o in self.allOrders) {
        if ([o.deliveryStatus isEqualToString:PPDeliveryStatusInTransit]) inTransitCount++;
        if (o.isReady || [o.deliveryStatus isEqualToString:PPDeliveryStatusAwaitingHandover]) readyCount++;
        if ([o.deliveryStatus isEqualToString:PPDeliveryStatusDelivered] || [o.deliveryStatus isEqualToString:PPDeliveryStatusCompleted]) deliveredCount++;
        if (o.isCashOrder) codCount++;
    }

    self.inTransitCountBadge.text = [NSString stringWithFormat:@"%ld", (long)inTransitCount];
    self.readyCountBadge.text = [NSString stringWithFormat:@"%ld", (long)readyCount];
    self.deliveredCountBadge.text = [NSString stringWithFormat:@"%ld", (long)deliveredCount];
    self.codPendingCountBadge.text = [NSString stringWithFormat:@"%ld", (long)codCount];

    // 2. Filter Orders
    NSMutableArray *filtered = [NSMutableArray array];
    for (PPDeliveryOrderModel *order in self.allOrders) {
        // Status Filter
        BOOL statusMatch = YES;
        switch (self.currentStatusFilter) {
            case PPDeliveryFilterAll: statusMatch = YES; break;
            case PPDeliveryFilterReady: statusMatch = order.isReady; break;
            case PPDeliveryFilterPendingPickup: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusAwaitingHandover] || [order.deliveryStatus isEqualToString:PPDeliveryStatusPickedUp]; break;
            case PPDeliveryFilterInTransit: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusInTransit]; break;
            case PPDeliveryFilterDelivered: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusDelivered] || [order.deliveryStatus isEqualToString:PPDeliveryStatusCompleted]; break;
            case PPDeliveryFilterCancelled: statusMatch = [order.deliveryStatus isEqualToString:PPDeliveryStatusCancelled] || [order.deliveryStatus isEqualToString:PPDeliveryStatusFailed]; break;
        }
        if (!statusMatch) continue;

        // Payment Filter
        BOOL payMatch = YES;
        switch (self.currentPaymentFilter) {
            case PPDeliveryPaymentFilterAll: payMatch = YES; break;
            case PPDeliveryPaymentFilterCOD: payMatch = order.isCashOrder; break;
            case PPDeliveryPaymentFilterPrepaid: payMatch = !order.isCashOrder; break;
        }
        if (!payMatch) continue;

        // Search Filter
        if (self.searchQuery.length > 0) {
            NSString *q = self.searchQuery.lowercaseString;
            BOOL numMatch = [order.displayOrderNumber.lowercaseString containsString:q] || [order.orderId.lowercaseString containsString:q];
            BOOL nameMatch = [order.customerName.lowercaseString containsString:q];
            BOOL phoneMatch = [order.customerPhone containsString:q];
            BOOL addrMatch = [[order pp_visibleCustomerLocationSummary].lowercaseString containsString:q];
            BOOL branchMatch = [[order pp_pickupLocationSummary].lowercaseString containsString:q];
            if (!numMatch && !nameMatch && !phoneMatch && !addrMatch && !branchMatch) continue;
        }

        [filtered addObject:order];
    }

    // 3. Sort Orders
    if (self.currentSortOrder == PPDeliverySortAmountHighToLow) {
        [filtered sortUsingComparator:^NSComparisonResult(PPDeliveryOrderModel *a, PPDeliveryOrderModel *b) {
            return [@(b.totalAmount) compare:@(a.totalAmount)];
        }];
    } else if (self.currentSortOrder == PPDeliverySortAmountLowToHigh) {
        [filtered sortUsingComparator:^NSComparisonResult(PPDeliveryOrderModel *a, PPDeliveryOrderModel *b) {
            return [@(a.totalAmount) compare:@(b.totalAmount)];
        }];
    } else {
        // Newest First
        [filtered sortUsingComparator:^NSComparisonResult(PPDeliveryOrderModel *a, PPDeliveryOrderModel *b) {
            NSDate *da = a.createdAt ?: [NSDate distantPast];
            NSDate *db = b.createdAt ?: [NSDate distantPast];
            return [db compare:da];
        }];
    }

    self.filteredOrders = filtered.copy;
    self.resultsCountBadge.text = [NSString stringWithFormat:@"%ld", (long)self.filteredOrders.count];
    self.clearSearchButton.hidden = (self.searchQuery.length == 0);

    // Update Filter Button Visual Halo
    BOOL hasNonDefaultFilter = (self.currentStatusFilter != PPDeliveryFilterAll || self.currentPaymentFilter != PPDeliveryPaymentFilterAll || self.currentSortOrder != PPDeliverySortNewest);
    if (hasNonDefaultFilter) {
        self.filterButton.tintColor = [UIColor ppPrimary];
        self.filterButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.14];
        self.filterButton.layer.borderColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.45].CGColor;
        self.filterBadgeDot.hidden = NO;
    } else {
        self.filterButton.tintColor = [UIColor ppTextSecondary];
        self.filterButton.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
        self.filterButton.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
        self.filterBadgeDot.hidden = YES;
    }

    BOOL hasItems = self.filteredOrders.count > 0;
    self.emptyStateView.hidden = hasItems || !self.hasLoadedOnce;
    self.tableView.hidden = !hasItems && self.hasLoadedOnce && self.allOrders.count == 0;

    [self.tableView reloadData];
}

#pragma mark - Filter Actions

- (void)openFilterSheet {
    PPDeliveryFilterSheet *sheet = [[PPDeliveryFilterSheet alloc] initWithStatusFilter:self.currentStatusFilter
                                                                         paymentFilter:self.currentPaymentFilter
                                                                             sortOrder:self.currentSortOrder
                                                                             allOrders:self.allOrders];
    __weak typeof(self) ws = self;
    sheet.onApply = ^(PPDeliveryFilter statusFilter, PPDeliveryPaymentFilter paymentFilter, PPDeliverySortOrder sortOrder) {
        ws.currentStatusFilter = statusFilter;
        ws.currentPaymentFilter = paymentFilter;
        ws.currentSortOrder = sortOrder;
        [ws updateCockpitUI];
    };

    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)filterInTransitTapped {
    self.currentStatusFilter = PPDeliveryFilterInTransit;
    [PPFunc pp_playTapEffect];
    [self updateCockpitUI];
}

- (void)filterReadyTapped {
    self.currentStatusFilter = PPDeliveryFilterReady;
    [PPFunc pp_playTapEffect];
    [self updateCockpitUI];
}

- (void)filterDeliveredTapped {
    self.currentStatusFilter = PPDeliveryFilterDelivered;
    [PPFunc pp_playTapEffect];
    [self updateCockpitUI];
}

- (void)filterCODTapped {
    self.currentPaymentFilter = PPDeliveryPaymentFilterCOD;
    [PPFunc pp_playTapEffect];
    [self updateCockpitUI];
}

#pragma mark - Search

- (void)searchTextChanged:(UITextField *)sender {
    self.searchQuery = [sender.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self updateCockpitUI];
}

- (void)clearSearchTapped {
    self.omniSearchField.text = @"";
    self.searchQuery = @"";
    [self.omniSearchField resignFirstResponder];
    [self updateCockpitUI];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredOrders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryOperationCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPDeliveryOperationCardCell" forIndexPath:indexPath];
    PPDeliveryOrderModel *order = self.filteredOrders[indexPath.row];
    [cell configureWithOrder:order];

    __weak typeof(self) ws = self;
    cell.onMapTapped = ^(PPDeliveryOrderModel *targetOrder) {
        [ws openMapsForOrder:targetOrder];
    };
    cell.onCallTapped = ^(PPDeliveryOrderModel *targetOrder) {
        [ws callCustomerForOrder:targetOrder];
    };
    cell.onActionTapped = ^(PPDeliveryOrderModel *targetOrder) {
        [ws openQuickActionSheetForOrder:targetOrder];
    };
    cell.onDetailsTapped = ^(PPDeliveryOrderModel *targetOrder) {
        [ws openDetailsForOrder:targetOrder];
    };

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryOrderModel *order = self.filteredOrders[indexPath.row];
    [self openDetailsForOrder:order];
}

#pragma mark - Card Actions

- (void)openMapsForOrder:(PPDeliveryOrderModel *)order {
    [PPFunc pp_playTapEffect];
    NSString *loc = order.deliveryLocationPoint;
    if (loc.length) {
        NSArray *parts = [loc componentsSeparatedByString:@","];
        if (parts.count == 2) {
            double lat = [parts[0] doubleValue];
            double lng = [parts[1] doubleValue];
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%f,%f", lat, lng]];
            if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            return;
        }
    }
    NSString *addr = [order pp_exactDeliveryLocationText];
    if (addr.length) {
        NSString *enc = [addr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%@", enc]];
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)callCustomerForOrder:(PPDeliveryOrderModel *)order {
    [PPFunc pp_playTapEffect];
    NSString *phone = order.customerPhone;
    if (phone.length) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phone]];
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [PPToast toast:kLang(@"Deliv_Call_Unavailable") style:PPToastStyleWarning haptic:YES duration:2.5];
    }
}

- (void)openQuickActionSheetForOrder:(PPDeliveryOrderModel *)order {
    [PPFunc pp_playTapEffect];
    PPDeliveryQuickTransitionSheet *sheet = [[PPDeliveryQuickTransitionSheet alloc] initWithOrder:order];
    __weak typeof(self) ws = self;
    sheet.onActionExecuted = ^{
        [ws reloadOrdersFromManager];
    };
    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openDetailsForOrder:(PPDeliveryOrderModel *)order {
    [PPFunc pp_playTapEffect];
    PPDeliveryOrderDetailViewController *vc = [[PPDeliveryOrderDetailViewController alloc] initWithOrder:order];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
