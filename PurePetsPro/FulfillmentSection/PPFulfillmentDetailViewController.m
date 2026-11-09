#import "PPFulfillmentDetailViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPMarketplaceBranchesViewController.h"
#import "PPFulfillmentModel.h"
#import "PPFulfillmentManager.h"
#import "PPFirebaseCompat.h"

@interface PPFulfillmentDetailViewController ()
@property (nonatomic, strong) PPFulfillmentModel *model;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIView *eventsContainer;
@property (nonatomic, strong) UIView *actionBar;

@property (nonatomic, strong) id<FIRListenerRegistration> eventsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> fulfillmentListener;
@property (nonatomic, assign) NSUInteger fulfillmentListenerGeneration;
@property (nonatomic, assign) NSUInteger eventsListenerGeneration;
@property (nonatomic, copy) NSString *listenerUID;
@property (nonatomic, assign) BOOL hasLiveFulfillmentState;
@property (nonatomic, strong) NSLayoutConstraint *scrollBottomConstraint;
@property (nonatomic, strong) UIStackView *phaseStack;
@property (nonatomic, assign) BOOL phasesExpanded;
@property (nonatomic, assign) BOOL mayDisplayDossier;
@property (nonatomic, copy) NSArray<NSDictionary *> *currentEvents;
@property (nonatomic, assign) BOOL eventsLoaded;
@property (nonatomic, assign) BOOL eventsFromCache;
@property (nonatomic, strong) NSError *eventsError;
@property (nonatomic, copy) NSString *liveMessage;
@property (nonatomic, copy) NSString *operationMessage;
@property (nonatomic, copy) NSString *pendingAction;
@property (nonatomic, copy) NSString *pendingFromStatus;
@property (nonatomic, copy) NSString *pendingTargetStatus;
@property (nonatomic, copy) NSString *pendingNote;
@property (nonatomic, copy) NSString *pendingUID;
@property (nonatomic, assign) BOOL submitting;
@property (nonatomic, assign) BOOL commandAccepted;
@property (nonatomic, assign) NSUInteger operationGeneration;
@property (nonatomic, strong) UIAlertController *reviewAlert;
@property (nonatomic, strong) UIAlertAction *reviewConfirm;
@property (nonatomic, assign) BOOL reviewRequiresNote;
@property (nonatomic, strong) FIRAuthStateDidChangeListenerHandle authListener;
- (void)observeFulfillment;
- (void)refreshActionBarFromLiveFulfillment;
- (void)removeActionBar;
- (void)performCanonicalFulfillmentAction:(NSString *)action
                                     note:(NSString *)note
                               completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;
- (BOOL)isFulfillmentV1ParentOrderData:(NSDictionary *)orderData;
- (void)finishSuccessfulFulfillmentAction;
@end

@implementation PPFulfillmentDetailViewController

- (instancetype)initWithModel:(PPFulfillmentModel *)model {
    if (self = [super init]) {
        _model = model;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.currentEvents = @[];
    self.mayDisplayDossier = YES;
    self.liveMessage = kLang(@"ProFulfillment_CheckingOrder");
    [self buildScrollView];
    [self renderDossier];
    [self observeFulfillment];
    [self observeEvents];
    NSString *entryUID = [FIRAuth auth].currentUser.uid ?: @"";
    __weak typeof(self) weakSelf = self;
    self.authListener = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || [entryUID isEqualToString:user.uid ?: @""]) return;
        self.operationGeneration++;
        self.submitting = NO;
        self.hasLiveFulfillmentState = NO;
        self.mayDisplayDossier = NO;
        [self clearPendingIntent];
        [self.fulfillmentListener remove];
        [self.eventsListener remove];
        self.fulfillmentListenerGeneration++;
        self.eventsListenerGeneration++;
        [self.reviewAlert dismissViewControllerAnimated:NO completion:nil];
        self.reviewAlert = nil;
        [self.stack.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.currentEvents = @[];
        self.liveMessage = kLang(@"ProFulfillment_OrderUnavailable");
        [self refreshActionBarFromLiveFulfillment];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Fulfillment_DetailTitle") showBack:YES];
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }

- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; }

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (!self.isViewLoaded) return;
    [self renderDossier];
}

- (void)renderDossier {
    CGPoint offset = self.scrollView.contentOffset;
    for (UIView *view in self.stack.arrangedSubviews.copy) {
        [self.stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    if (!self.mayDisplayDossier) { [self refreshActionBarFromLiveFulfillment]; return; }
    [self buildHeroSection];
    [self buildMoneySection];
    [self buildMetaSection];
    [self buildItemsSection];
    [self buildEventsSection];
    [self renderEvents:self.currentEvents ?: @[]];
    [self refreshActionBarFromLiveFulfillment];
    [self.view layoutIfNeeded];
    CGFloat maximum = MAX(-self.scrollView.adjustedContentInset.top, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.scrollView.adjustedContentInset.bottom);
    self.scrollView.contentOffset = CGPointMake(offset.x, MIN(MAX(offset.y, -self.scrollView.adjustedContentInset.top), maximum));
}

#pragma mark - View Building

- (void)buildScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];

    _stack = [[UIStackView alloc] init];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 16;
    _stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_stack];

    self.scrollBottomConstraint = [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        self.scrollBottomConstraint,

        [_stack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [_stack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [_stack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:14],
        [_stack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-28],
        [_stack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-32],
    ]];
}

- (void)buildHeroSection {
    UIView *surface = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [surface addSubview:content];
    UILabel *reference = [self labelWithFont:[Styling fontBold:27] color:[UIColor ppTextPrimary] lines:0];
    reference.text = [self primaryOrderTitle];
    reference.accessibilityTraits = UIAccessibilityTraitHeader;
    UILabel *status = [self labelWithFont:[Styling fontBold:20] color:self.model.statusColor lines:0];
    status.text = self.model.statusDisplayName;
    status.accessibilityIdentifier = @"fulfillment.exactStatus";
    UILabel *next = [self labelWithFont:[Styling fontRegular:16] color:[UIColor ppTextSecondary] lines:0];
    next.text = self.model.requiresProviderAction
        ? [NSString stringWithFormat:kLang(@"ProFulfillment_NextAction"), self.model.nextActionForStatus]
        : self.model.waitingDescription;
    for (UIView *view in @[reference, status, next]) [content addArrangedSubview:view];
    NSInteger current = self.model.lifecycleStageIndex;
    if (current == NSNotFound) {
        UILabel *exception = [self labelWithFont:[Styling fontMedium:15] color:[UIColor ppTextSecondary] lines:0];
        exception.text = kLang(self.model.isTerminal ? @"ProFulfillment_ExceptionBranch" : @"ProFulfillment_UnknownState");
        [content addArrangedSubview:exception];
    } else {
        UIButton *toggle = [self recoveryButton:kLang(self.phasesExpanded ? @"ProFulfillment_HidePhases" : @"ProFulfillment_ShowPhases") selector:@selector(togglePhases:)];
        toggle.accessibilityValue = kLang(self.phasesExpanded ? @"ProFulfillment_Expanded" : @"ProFulfillment_Collapsed");
        [content addArrangedSubview:toggle];
        self.phaseStack = [self verticalStackWithSpacing:10];
        self.phaseStack.hidden = !self.phasesExpanded;
        NSArray *keys = @[@"ProFulfillment_PhaseNew", @"ProFulfillment_PhasePreparation", @"ProFulfillment_PhaseReady", @"ProFulfillment_PhaseTransit", @"ProFulfillment_PhaseDelivered", @"ProFulfillment_PhaseCompleted"];
        for (NSUInteger i = 0; i < keys.count; i++) {
            BOOL selected = (NSInteger)i == current;
            UILabel *phase = [self labelWithFont:(selected ? [Styling fontBold:16] : [Styling fontRegular:15]) color:(selected ? [UIColor ppPrimary] : [UIColor ppTextSecondary]) lines:0];
            phase.text = selected ? [NSString stringWithFormat:kLang(@"ProFulfillment_CurrentPhase"), kLang(keys[i])] : kLang(keys[i]);
            [self.phaseStack addArrangedSubview:phase];
        }
        UILabel *caption = [self labelWithFont:[Styling fontRegular:13] color:[UIColor ppTextSecondary] lines:0];
        caption.text = kLang(@"ProFulfillment_PhasesCaption");
        [self.phaseStack addArrangedSubview:caption];
        [content addArrangedSubview:self.phaseStack];
    }
    [self pinContent:content toSurface:surface];
    [self.stack addArrangedSubview:surface];
}

- (void)togglePhases:(UIButton *)sender {
    self.phasesExpanded = !self.phasesExpanded;
    self.phaseStack.hidden = !self.phasesExpanded;
    [sender setTitle:kLang(self.phasesExpanded ? @"ProFulfillment_HidePhases" : @"ProFulfillment_ShowPhases") forState:UIControlStateNormal];
    sender.accessibilityValue = kLang(self.phasesExpanded ? @"ProFulfillment_Expanded" : @"ProFulfillment_Collapsed");
}

- (void)buildMoneySection {
    UIView *surface = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:14];
    [surface addSubview:content];
    [content addArrangedSubview:[self sectionTitle:kLang(@"ProFulfillment_OrderMoney")]];
    if (self.model.hasMoneyProjection) {
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_ProviderNet") value:[self moneyString:self.model.providerNet]]];
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_Subtotal") value:[self moneyString:self.model.subtotal]]];
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_PlatformCommission") value:[self moneyString:self.model.platformCommission]]];
    }
    UILabel *caption = [self labelWithFont:[Styling fontRegular:13] color:[UIColor ppTextSecondary] lines:0];
    caption.text = kLang(self.model.hasMoneyProjection ? @"ProFulfillment_OrderMoneyCaption" : @"ProFulfillment_MoneyUnavailable");
    [content addArrangedSubview:caption];
    [self pinContent:content toSurface:surface];
    [self.stack addArrangedSubview:surface];
}

- (void)buildMetaSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:kLang(@"Fulfillment_OrderContext")]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_OrderID") value:self.model.parentOrderId]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_CustomerID") value:[self shortID:self.model.parentUserId length:12]]];
    if (self.model.ownerID.length > 0) {
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_OwnerID") value:[self shortID:self.model.ownerID length:12]]];
    }
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_CreatedAt") value:[self mediumDateString:self.model.createdAt]]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_UpdatedAt") value:[self mediumDateString:self.model.updatedAt]]];
    if (self.model.adminOverrideReason.length > 0) {
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_AdminOverride") value:self.model.adminOverrideReason]];
    }

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildItemsSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Fulfillment_Items"), (long)self.model.items.count]]];

    if (self.model.items.count == 0) {
        UILabel *empty = [self labelWithFont:[Styling fontRegular:13] color:SeconderyTextClr lines:0];
        empty.text = kLang(@"Fulfillment_NoItems");
        [content addArrangedSubview:empty];
    } else {
        for (NSInteger i = 0; i < self.model.items.count; i++) {
            NSDictionary *item = PPSafeDict(self.model.items[i]);
            [content addArrangedSubview:[self itemRow:item index:i]];
        }
    }

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildEventsSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:kLang(@"Fulfillment_Events")]];

    _eventsContainer = [[UIView alloc] init];
    _eventsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [content addArrangedSubview:_eventsContainer];

    UILabel *placeholder = [self labelWithFont:[Styling fontRegular:13] color:SeconderyTextClr lines:1];
    placeholder.text = kLang(@"Fulfillment_Loading");
    [_eventsContainer addSubview:placeholder];

    [NSLayoutConstraint activateConstraints:@[
        [_eventsContainer.heightAnchor constraintGreaterThanOrEqualToConstant:22],
        [placeholder.leadingAnchor constraintEqualToAnchor:_eventsContainer.leadingAnchor],
        [placeholder.trailingAnchor constraintEqualToAnchor:_eventsContainer.trailingAnchor],
        [placeholder.topAnchor constraintEqualToAnchor:_eventsContainer.topAnchor],
        [placeholder.bottomAnchor constraintEqualToAnchor:_eventsContainer.bottomAnchor],
    ]];

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildActionBar {
    self.actionBar = [self sectionSurface];
    self.actionBar.layer.cornerRadius = 0;
    [self.view addSubview:self.actionBar];
    UIScrollView *dockScroll = [[UIScrollView alloc] init];
    dockScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionBar addSubview:dockScroll];
    UIStackView *content = [self verticalStackWithSpacing:10];
    [dockScroll addSubview:content];
    UILabel *state = [self labelWithFont:[Styling fontMedium:14] color:[UIColor ppTextSecondary] lines:0];
    state.text = self.submitting ? kLang(@"ProFulfillment_VerifyingAction") : (self.operationMessage.length ? self.operationMessage : self.liveMessage);
    state.accessibilityIdentifier = @"fulfillment.commandState";
    if (state.text.length) [content addArrangedSubview:state];
    if (self.pendingAction.length) {
        if (!self.submitting) {
            [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_RecheckResult") selector:@selector(recheckPending:)]];
            if (!self.commandAccepted) [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_RetrySameAction") selector:@selector(retryPending:)]];
        }
    } else if (self.hasLiveFulfillmentState) {
        NSArray<NSString *> *actions = self.model.availableActions;
        NSString *first = actions.firstObject;
        BOOL positive = first.length && ![first isEqualToString:@"cancel_request"] && ![first isEqualToString:@"reject"];
        if (positive) [content addArrangedSubview:[self buttonForAction:first]];
        if (actions.count > (positive ? 1 : 0)) [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_OtherActions") selector:@selector(showOtherActions:)]];
    } else {
        [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_Refresh") selector:@selector(refreshOrder:)]];
    }
    [self.scrollBottomConstraint setActive:NO];
    self.scrollBottomConstraint = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.actionBar.topAnchor];
    NSLayoutConstraint *fittedHeight = [dockScroll.heightAnchor constraintEqualToAnchor:content.heightAnchor constant:24];
    fittedHeight.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.actionBar.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor multiplier:0.45],
        [dockScroll.leadingAnchor constraintEqualToAnchor:self.actionBar.leadingAnchor],
        [dockScroll.trailingAnchor constraintEqualToAnchor:self.actionBar.trailingAnchor],
        [dockScroll.topAnchor constraintEqualToAnchor:self.actionBar.topAnchor],
        [dockScroll.bottomAnchor constraintEqualToAnchor:self.actionBar.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:dockScroll.contentLayoutGuide.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:dockScroll.contentLayoutGuide.trailingAnchor constant:-16],
        [content.topAnchor constraintEqualToAnchor:dockScroll.contentLayoutGuide.topAnchor constant:12],
        [content.bottomAnchor constraintEqualToAnchor:dockScroll.contentLayoutGuide.bottomAnchor constant:-12],
        [content.widthAnchor constraintEqualToAnchor:dockScroll.frameLayoutGuide.widthAnchor constant:-32],
        fittedHeight, self.scrollBottomConstraint,
    ]];
}

- (UIButton *)recoveryButton:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[Styling fontBold:16]];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
    button.layer.cornerRadius = 14;
    button.backgroundColor = [UIColor ppSecondarySurface];
    [button setTitleColor:[UIColor ppTextPrimary] forState:UIControlStateNormal];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)showOtherActions:(UIButton *)sender {
    if (self.submitting || self.pendingAction.length || !self.hasLiveFulfillmentState) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"ProFulfillment_OtherActions") message:self.model.statusDisplayName preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSString *action in self.model.availableActions) {
        if (![action isEqualToString:@"reject"] && ![action isEqualToString:@"cancel_request"]) continue;
        [sheet addAction:[UIAlertAction actionWithTitle:[self displayNameForAction:action] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *choice) { [weakSelf dismissViewControllerAnimated:YES completion:^{ [weakSelf confirmAction:action]; }]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"ProFulfillment_KeepOrder") style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)refreshOrder:(UIButton *)sender { [self observeFulfillment]; }
- (void)recheckPending:(UIButton *)sender { [self verifyPendingIntent]; }
- (void)retryPending:(UIButton *)sender { [self executeAction:self.pendingAction note:self.pendingNote]; }

- (void)refreshActionBarFromLiveFulfillment {
    [self removeActionBar];
    [self buildActionBar];
}

- (void)removeActionBar {
    [self.scrollBottomConstraint setActive:NO];
    [self.actionBar removeFromSuperview];
    self.actionBar = nil;
}

#pragma mark - Component Helpers

- (UIView *)sectionSurface {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor ppSurface];
    view.layer.cornerRadius = PPCornerCard;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    view.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

- (UIStackView *)verticalStackWithSpacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

- (void)pinContent:(UIView *)content toSurface:(UIView *)surface {
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-16],
        [content.topAnchor constraintEqualToAnchor:surface.topAnchor constant:16],
        [content.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-16],
    ]];
}

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

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *label = [self labelWithFont:[Styling fontBold:15] color:PrimaryTextClr lines:1];
    label.text = text;
    return label;
}

- (UIView *)detailRowWithTitle:(NSString *)title value:(NSString *)value {
    UIStackView *row = [self verticalStackWithSpacing:3];
    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:13] color:[UIColor ppTextSecondary] lines:0];
    titleLabel.text = title;
    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:17] color:[UIColor ppTextPrimary] lines:0];
    valueLabel.text = value.length ? value : @"—";
    [row addArrangedSubview:titleLabel];
    [row addArrangedSubview:valueLabel];
    return row;
}

- (UIView *)itemRow:(NSDictionary *)item index:(NSInteger)index {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisVertical;
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentFill;
    row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *ordinal = [self labelWithFont:[Styling fontBold:12] color:AppPrimaryClr lines:1];
    ordinal.text = [NSString stringWithFormat:@"%ld", (long)(index + 1)];
    ordinal.textAlignment = NSTextAlignmentCenter;
    ordinal.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
    ordinal.layer.cornerRadius = 15;
    ordinal.layer.cornerCurve = kCACornerCurveContinuous;
    ordinal.clipsToBounds = YES;


    [row addArrangedSubview:ordinal];

    UIStackView *infoStack = [[UIStackView alloc] init];
    infoStack.axis = UILayoutConstraintAxisVertical;
    infoStack.spacing = 3;
    infoStack.alignment = UIStackViewAlignmentFill;
    infoStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *name = [self labelWithFont:[Styling fontMedium:13] color:PrimaryTextClr lines:2];
    NSString *fallback = [NSString stringWithFormat:@"%@ %ld", kLang(@"Fulfillment_Item"), (long)(index + 1)];
    name.text = PPSafeString(item[@"name"]).length > 0 ? PPSafeString(item[@"name"]) : fallback;
    [infoStack addArrangedSubview:name];

    NSString *variantDesc = PPSafeString(item[@"variantDescription"]);
    if (variantDesc.length == 0) {
        variantDesc = PPSafeString(item[@"variantTitle"]);
    }
    if (variantDesc.length == 0) {
        variantDesc = PPSafeString(item[@"variantOptionLabel"]);
    }
    if (variantDesc.length == 0 && [item[@"selectedOptionsSnapshot"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *snap = item[@"selectedOptionsSnapshot"];
        NSMutableArray *parts = [NSMutableArray array];
        for (id key in snap) {
            id val = snap[key];
            if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
                [parts addObject:val];
            } else if ([val isKindOfClass:[NSDictionary class]]) {
                NSString *nameAr = val[@"nameAr"];
                NSString *nameEn = val[@"nameEn"];
                NSString *str = Language.isRTL ? (nameAr.length ? nameAr : nameEn) : (nameEn.length ? nameEn : nameAr);
                if (str.length > 0) [parts addObject:str];
            }
        }
        if (parts.count > 0) {
            variantDesc = [parts componentsJoinedByString:@" • "];
        }
    }
    if (variantDesc.length == 0 && [item[@"variantColor"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *vc = item[@"variantColor"];
        NSString *cName = Language.isRTL ? vc[@"nameAr"] : vc[@"nameEn"];
        if (cName.length > 0) variantDesc = cName;
    }

    if (variantDesc.length > 0) {
        UIView *chip = [[UIView alloc] init];
        chip.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
        chip.layer.cornerRadius = 6;
        chip.layer.cornerCurve = kCACornerCurveContinuous;

        UILabel *chipLbl = [self labelWithFont:[Styling fontBold:11] color:AppPrimaryClr lines:1];
        chipLbl.text = variantDesc;
        chipLbl.translatesAutoresizingMaskIntoConstraints = NO;
        [chip addSubview:chipLbl];

        [NSLayoutConstraint activateConstraints:@[
            [chipLbl.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:6],
            [chipLbl.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-6],
            [chipLbl.topAnchor constraintEqualToAnchor:chip.topAnchor constant:2],
            [chipLbl.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-2],
        ]];
        [infoStack addArrangedSubview:chip];
    }
    [row addArrangedSubview:infoStack];


    UILabel *price = [self labelWithFont:[Styling fontBold:12] color:SeconderyTextClr lines:1];
    NSInteger qty = PPSafeNumber(item[@"quantity"]).integerValue;
    if (qty <= 0) qty = PPSafeNumber(item[@"qty"]).integerValue;
    if (qty <= 0) qty = 1;
    double amount = PPSafeNumber(item[@"price"]).doubleValue;
    price.text = [NSString localizedStringWithFormat:kLang(@"ProFulfillment_ItemQuantityPrice"), (long)qty, [self moneyString:amount]];
    [price setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:price];

    return row;
}

- (UIButton *)buttonForAction:(NSString *)action {
    UIButton *button = [self recoveryButton:[self displayNameForAction:action] selector:@selector(actionTapped:)];
    button.accessibilityIdentifier = action;
    button.backgroundColor = [UIColor ppPrimary];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    return button;
}

#pragma mark - Data Formatting

- (NSString *)primaryOrderTitle {
    NSString *orderNumber = self.model.parentOrderNumber.length > 0 ? self.model.parentOrderNumber : [self shortID:self.model.fulfillmentID length:14];
    return [NSString stringWithFormat:@"%@ %@", kLang(@"Fulfillment_OrderID"), orderNumber.length > 0 ? orderNumber : @"-"];
}

- (NSString *)shortID:(NSString *)value length:(NSUInteger)length {
    if (value.length == 0) return @"-";
    return [value substringToIndex:MIN(length, value.length)];
}

- (NSString *)moneyString:(double)value {
    if (!self.model.currency.length) return kLang(@"ProFulfillment_MoneyUnavailable");
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:[Language isRTL] ? @"ar_QA" : @"en_QA"];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = self.model.currency;
    return [formatter stringFromNumber:@(value)] ?: @"—";
}

- (NSString *)mediumDateString:(NSDate *)date {
    if (!date) return @"—";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:[Language isRTL] ? @"ar_QA" : @"en_QA"];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

- (NSString *)eventDateString:(id)value {
    NSDate *date = [value isKindOfClass:NSDate.class] ? value : ([value respondsToSelector:@selector(dateValue)] ? [value dateValue] : nil);
    return date ? [self mediumDateString:date] : @"";
}

#pragma mark - Events

- (void)observeFulfillment {
    [self.fulfillmentListener remove];
    self.fulfillmentListener = nil;
    NSUInteger generation = ++self.fulfillmentListenerGeneration;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *fulfillmentID = self.model.fulfillmentID ?: @"";
    self.listenerUID = uid;
    self.hasLiveFulfillmentState = NO;
    self.liveMessage = kLang(@"ProFulfillment_CheckingOrder");
    [self refreshActionBarFromLiveFulfillment];
    if (!uid.length || !fulfillmentID.length) return;
    __weak typeof(self) weakSelf = self;
    self.fulfillmentListener = [[PPFulfillmentManager sharedManager] observeFulfillmentWithID:fulfillmentID stateHandler:^(PPFulfillmentModel *model, NSError *error, BOOL fromCache) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.fulfillmentListenerGeneration || ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || ![self.listenerUID isEqualToString:uid]) return;
        BOOL owns = [self isOwnedModel:model uid:uid];
        self.hasLiveFulfillmentState = !error && model && !fromCache && owns;
        self.liveMessage = kLang(error || !model || !owns ? @"ProFulfillment_OrderUnavailable" : (fromCache ? @"ProFulfillment_CachedOrder" : @"ProFulfillment_ServerConfirmed"));
        if (!error && owns && [model.fulfillmentID isEqualToString:fulfillmentID]) {
            self.model = model;
            self.mayDisplayDossier = YES;
            [self renderDossier];
        } else {
            self.mayDisplayDossier = NO;
            // Authorization loss removes the previously displayed private dossier.
            self.currentEvents = @[];
            for (UIView *view in self.stack.arrangedSubviews.copy) { [self.stack removeArrangedSubview:view]; [view removeFromSuperview]; }
            [self refreshActionBarFromLiveFulfillment];
        }
    }];
}

- (BOOL)isOwnedModel:(PPFulfillmentModel *)model uid:(NSString *)uid {
    return model && uid.length && (([model.ownerType isEqualToString:@"partner"] && [model.ownerID isEqualToString:uid]) || [PPFulfillmentManager isOfficialPlatformFulfillment:model forUID:uid]);
}

- (void)observeEvents {
    [self.eventsListener remove];
    NSUInteger generation = ++self.eventsListenerGeneration;
    NSString *uid = self.listenerUID ?: @"";
    if (!uid.length || !self.model.fulfillmentID.length) return;
    __weak typeof(self) weakSelf = self;
    self.eventsListener = [[PPFulfillmentManager sharedManager] observeEventsForFulfillmentID:self.model.fulfillmentID stateHandler:^(NSArray<NSDictionary *> *events, NSError *error, BOOL fromCache) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.eventsListenerGeneration || ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || ![self.listenerUID isEqualToString:uid]) return;
            self.eventsLoaded = YES;
            self.eventsError = error;
            self.eventsFromCache = fromCache;
            self.currentEvents = events ?: @[];
            if (self.mayDisplayDossier) [self renderEvents:self.currentEvents];
        });
    }];
}

- (void)renderEvents:(NSArray<NSDictionary *> *)events {
    if (!self.eventsContainer) return;
    [self.eventsContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    UIStackView *content = [self verticalStackWithSpacing:16];
    [self.eventsContainer addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.eventsContainer.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.eventsContainer.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:self.eventsContainer.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.eventsContainer.bottomAnchor],
    ]];
    NSString *message = !self.eventsLoaded ? kLang(@"Fulfillment_Loading") : (self.eventsError ? kLang(@"ProFulfillment_HistoryError") : (self.eventsFromCache ? kLang(@"ProFulfillment_CachedHistory") : (events.count ? kLang(@"ProFulfillment_HistoryCaption") : kLang(@"Fulfillment_NoEvents"))));
    UILabel *state = [self labelWithFont:[Styling fontRegular:14] color:[UIColor ppTextSecondary] lines:0];
    state.text = message;
    [content addArrangedSubview:state];
    if (self.eventsError || self.eventsFromCache) [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_RefreshHistory") selector:@selector(refreshHistory:)]];
    for (id event in events) if ([event isKindOfClass:NSDictionary.class]) [content addArrangedSubview:[self eventRow:event]];
}

- (void)refreshHistory:(UIButton *)sender {
    self.eventsLoaded = NO;
    self.eventsError = nil;
    [self renderEvents:self.currentEvents];
    [self observeEvents];
}

- (UIView *)eventRow:(NSDictionary *)event {
    UIStackView *row = [self verticalStackWithSpacing:4];
    NSString *action = PPSafeString(event[@"action"]);
    UILabel *title = [self labelWithFont:[Styling fontBold:16] color:[UIColor ppTextPrimary] lines:0];
    title.text = action.length ? [self displayNameForAction:action] : kLang(@"ProFulfillment_StatusUpdate");
    [row addArrangedSubview:title];
    NSString *from = PPSafeString(event[@"fromStatus"]);
    NSString *to = PPSafeString(event[@"toStatus"]);
    if (to.length) {
        UILabel *change = [self labelWithFont:[Styling fontRegular:15] color:[UIColor ppTextSecondary] lines:0];
        change.text = from.length ? [NSString stringWithFormat:kLang(@"ProFulfillment_StatusChange"), [PPFulfillmentModel displayNameForStatus:from], [PPFulfillmentModel displayNameForStatus:to]] : [PPFulfillmentModel displayNameForStatus:to];
        [row addArrangedSubview:change];
    }
    NSString *note = PPSafeString(event[@"note"]);
    if (note.length) { UILabel *label = [self labelWithFont:[Styling fontRegular:14] color:[UIColor ppTextSecondary] lines:0]; label.text = note; [row addArrangedSubview:label]; }
    UILabel *date = [self labelWithFont:[Styling fontRegular:13] color:[UIColor ppTextSecondary] lines:0];
    date.text = [self eventDateString:event[@"createdAt"]];
    [row addArrangedSubview:date];
    return row;
}

#pragma mark - Actions

- (NSString *)displayNameForAction:(NSString *)action {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"accept":            @"Fulfillment_Accept",
            @"reject":            @"Fulfillment_Reject",
            @"start_preparing":   @"Fulfillment_StartPreparing",
            @"mark_ready":        @"Fulfillment_MarkReady",
            @"request_delivery":  @"Fulfillment_RequestDelivery",
            @"confirm_handover":  @"Fulfillment_ConfirmHandover",
            @"cancel_request":    @"Fulfillment_CancelRequest",
        };
    });
    NSString *key = map[action];
    return key.length > 0 ? kLang(key) : action;
}

- (NSString *)displayNameForStatusValue:(NSString *)status { return [PPFulfillmentModel displayNameForStatus:status]; }

- (void)actionTapped:(UIButton *)sender {
    NSString *action = sender.accessibilityIdentifier;
    if (self.submitting || self.pendingAction.length || !self.hasLiveFulfillmentState || ![self.model.availableActions containsObject:action]) return;
    [self confirmAction:action];
}

- (void)confirmAction:(NSString *)action {
    if (self.submitting || self.pendingAction.length || self.presentedViewController || !self.hasLiveFulfillmentState || ![self.model.availableActions containsObject:action]) return;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *source = [self.model.status copy];
    NSString *target = [PPFulfillmentModel targetStatusForAction:action];
    NSString *fulfillmentID = [self.model.fulfillmentID copy];
    if (!target.length || ![self isOwnedModel:self.model uid:uid]) return;
    BOOL official = [PPFulfillmentManager isOfficialPlatformFulfillment:self.model forUID:uid];
    self.reviewRequiresNote = official;
    NSString *message = [NSString stringWithFormat:kLang(@"ProFulfillment_ReviewTransition"), self.model.statusDisplayName, [PPFulfillmentModel displayNameForStatus:target]];
    if ([action isEqualToString:@"confirm_handover"]) message = [message stringByAppendingFormat:@"\n\n%@", kLang(@"ProFulfillment_HandoverReview")];
    if (official) message = [message stringByAppendingFormat:@"\n\n%@", kLang(@"Fulfillment_StaffNoteMessage")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self displayNameForAction:action] message:message preferredStyle:UIAlertControllerStyleAlert];
    self.reviewAlert = alert;
    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = kLang(official ? @"Fulfillment_StaffNotePlaceholder" : @"Fulfillment_NoteOptional");
        field.textAlignment = Language.alignmentForCurrentLanguage;
        field.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        field.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[Styling fontRegular:17]];
        field.adjustsFontForContentSizeCategory = YES;
        [field addTarget:weakSelf action:@selector(reviewNoteChanged:) forControlEvents:UIControlEventEditingChanged];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ProFulfillment_KeepOrder") style:UIAlertActionStyleCancel handler:^(UIAlertAction *choice) { weakSelf.reviewAlert = nil; weakSelf.reviewConfirm = nil; }]];
    BOOL destructive = [action isEqualToString:@"reject"] || [action isEqualToString:@"cancel_request"];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:[self displayNameForAction:action] style:(destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault) handler:^(UIAlertAction *choice) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *note = [self.reviewAlert.textFields.firstObject.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        self.reviewAlert = nil; self.reviewConfirm = nil;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || !self.hasLiveFulfillmentState || ![self.model.fulfillmentID isEqualToString:fulfillmentID] || ![self.model.status isEqualToString:source] || ![self.model.availableActions containsObject:action]) {
            self.operationMessage = kLang(@"ProFulfillment_StateChanged");
            [self observeFulfillment];
            return;
        }
        if ((official && note.length < 3) || note.length > 512) return;
        self.pendingAction = action; self.pendingFromStatus = source; self.pendingTargetStatus = target;
        self.pendingNote = note; self.pendingUID = uid; self.commandAccepted = NO;
        [self executeAction:action note:note];
    }];
    self.reviewConfirm = confirm;
    confirm.enabled = !official;
    [alert addAction:confirm];
    alert.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reviewNoteChanged:(UITextField *)field {
    NSUInteger length = [field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length;
    self.reviewConfirm.enabled = length <= 512 && (!self.reviewRequiresNote || length >= 3);
}

- (void)executeAction:(NSString *)action note:(NSString *)note {
    if (self.submitting || !self.pendingAction.length || ![action isEqualToString:self.pendingAction] || ![note ?: @"" isEqualToString:self.pendingNote ?: @""]) return;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (![uid isEqualToString:self.pendingUID] || !self.hasLiveFulfillmentState || ![self isOwnedModel:self.model uid:uid]) return;
    self.submitting = YES;
    self.operationMessage = nil;
    NSUInteger generation = ++self.operationGeneration;
    [self refreshActionBarFromLiveFulfillment];
    __weak typeof(self) weakSelf = self;
    [self performCanonicalFulfillmentAction:action note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.operationGeneration || ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:self.pendingUID]) return;
        self.submitting = NO;
        if (!success) {
            BOOL conflict = error.code == FIRFunctionsErrorCodeFailedPrecondition || error.code == FIRFunctionsErrorCodeAborted || error.code == 409;
            BOOL denied = error.code == FIRFunctionsErrorCodePermissionDenied || error.code == FIRFunctionsErrorCodeUnauthenticated || error.code == FIRFunctionsErrorCodeInvalidArgument;
            if (conflict || denied) {
                [self clearPendingIntent];
                self.operationMessage = kLang(conflict ? @"ProFulfillment_StateChanged" : @"ProFulfillment_ActionDenied");
                [self observeFulfillment];
            } else {
                // Preserve the frozen source/action/note. Manager derives the same durable intent ID on retry.
                self.operationMessage = kLang(@"ProFulfillment_ActionUncertain");
                [self refreshActionBarFromLiveFulfillment];
            }
            return;
        }
        self.commandAccepted = YES;
        [self verifyPendingIntent];
    }];
}

- (void)clearPendingIntent {
    self.pendingAction = nil; self.pendingFromStatus = nil; self.pendingTargetStatus = nil;
    self.pendingNote = nil; self.pendingUID = nil; self.commandAccepted = NO;
}

- (void)verifyPendingIntent {
    if (self.submitting || !self.pendingAction.length || ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:self.pendingUID]) return;
    self.submitting = YES;
    NSUInteger generation = ++self.operationGeneration;
    NSString *uid = self.pendingUID;
    NSString *fulfillmentID = self.model.fulfillmentID;
    [self refreshActionBarFromLiveFulfillment];
    __weak typeof(self) weakSelf = self;
    [[PPFulfillmentManager sharedManager] fetchFulfillmentWithID:fulfillmentID completion:^(PPFulfillmentModel *model, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.operationGeneration || ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        self.submitting = NO;
        if (error || ![self isOwnedModel:model uid:uid] || ![model.fulfillmentID isEqualToString:fulfillmentID]) {
            self.hasLiveFulfillmentState = NO;
            BOOL denied = error.code == FIRFirestoreErrorCodePermissionDenied || error.code == FIRFirestoreErrorCodeUnauthenticated;
            self.operationMessage = kLang(denied ? @"ProFulfillment_ActionDenied" : @"ProFulfillment_ReadbackPending");
            if (denied) {
                [self clearPendingIntent];
                self.mayDisplayDossier = NO;
                [self renderDossier];
            } else [self refreshActionBarFromLiveFulfillment];
            return;
        }
        self.model = model;
        self.mayDisplayDossier = YES;
        self.hasLiveFulfillmentState = YES;
        if (self.commandAccepted && [model.status isEqualToString:self.pendingTargetStatus]) {
            [self finishSuccessfulFulfillmentAction];
        } else if (![model.status isEqualToString:self.pendingFromStatus] && ![model.status isEqualToString:self.pendingTargetStatus]) {
            [self clearPendingIntent];
            self.operationMessage = kLang(@"ProFulfillment_ResultChanged");
        } else {
            self.operationMessage = kLang(self.commandAccepted ? @"ProFulfillment_ReadbackPending" : @"ProFulfillment_ActionUncertain");
        }
        [self renderDossier];
    }];
}

- (void)presentMarketplaceBranchPickerForAction:(NSString *)action note:(NSString *)note {
    __weak typeof(self) weakSelf = self;
    PPMarketplaceBranchesViewController *picker =
        [[PPMarketplaceBranchesViewController alloc] initForSelectionWithCompletion:^(PPMarketplaceBranch *branch) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Fulfillment_Updating") subtitle:nil];
        [self executeMarketplaceDeliveryRequestWithAction:action note:note branch:branch];
    }];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:picker];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 16.0, *)) {
        UISheetPresentationControllerDetent *detent =
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"marketplacePickupBranch89"
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return context.maximumDetentValue * 0.89;
        }];
        navigationController.sheetPresentationController.detents = @[detent];
        navigationController.sheetPresentationController.prefersGrabberVisible = YES;
        navigationController.sheetPresentationController.preferredCornerRadius = 30.0;
    } else if (@available(iOS 15.0, *)) {
        navigationController.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        navigationController.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)executeMarketplaceDeliveryRequestWithAction:(NSString *)action
                                               note:(NSString *)note
                                             branch:(PPMarketplaceBranch *)branch {
    __weak typeof(self) weakSelf = self;
    [self fetchParentOrderDataWithCompletion:^(NSDictionary * _Nullable orderData, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || orderData.count == 0) {
            [PPHUD dismiss];
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic")];
            return;
        }

        // Fulfillment V1 owns delivery through providerTransitionFulfillment.
        // The legacy company-delivery callable is fenced by Infra for V1 parents.
        if ([self isFulfillmentV1ParentOrderData:orderData]) {
            [self executeStandardFulfillmentAction:action note:note];
            return;
        }

        NSMutableDictionary *pickupAddress = [[branch pickupAddressPayload] mutableCopy];
        NSMutableDictionary *dropoffAddress = [[self firstAddressPayloadInDictionary:orderData
                                                                                keys:@[@"shippingAddressSnapshot", @"deliveryRequestAddressSnapshot", @"shippingAddress", @"deliveryAddress", @"address"]] mutableCopy];

        NSString *requestNote = note.length > 0
            ? note
            : [self firstStringInDictionary:orderData keys:@[@"deliveryNotes", @"notes", @"note"]];

        [self performCanonicalFulfillmentAction:action note:note completion:^(BOOL transitionSucceeded, NSString *message, NSError *transitionError) {
            __strong typeof(weakSelf) innerSelf = weakSelf;
            if (!innerSelf) return;
            if (!transitionSucceeded) {
                [PPHUD dismiss];
                [PPAlertHelper showErrorIn:innerSelf title:kLang(@"Error") subtitle:message ?: transitionError.localizedDescription];
                return;
            }

            [[PPDeliveryCompanyService shared] createRequestForOrderID:innerSelf.model.parentOrderId
                                                              companyID:nil
                                                  marketplaceProviderID:innerSelf.model.ownerID
                                                              branchID:branch.branchID
                                                          pickupAddress:pickupAddress.copy
                                                         dropoffAddress:dropoffAddress.copy
                                                            deliveryFee:[innerSelf firstNumberInDictionary:orderData keys:@[@"shippingFee", @"deliveryFee", @"shippingCost"]]
                                                          paymentStatus:[innerSelf firstStringInDictionary:orderData keys:@[@"paymentStatus"]]
                                                        paymentProvider:[innerSelf firstStringInDictionary:orderData keys:@[@"paymentProvider"]]
                                                           deliveryNote:requestNote
                                                             completion:^(__unused NSDictionary * _Nullable result, NSError * _Nullable requestError) {
                if (requestError && ![innerSelf shouldIgnoreExistingCompanyRequestError:requestError]) {
                    [PPHUD dismiss];
                    [PPAlertHelper showErrorIn:innerSelf title:kLang(@"Error") subtitle:requestError.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic")];
                    return;
                }
                [innerSelf finishSuccessfulFulfillmentAction];
            }];
        }];
    }];
}

- (BOOL)isFulfillmentV1ParentOrderData:(NSDictionary *)orderData {
    id rawVersion = [orderData isKindOfClass:NSDictionary.class] ? orderData[@"fulfillmentVersion"] : nil;
    return [rawVersion respondsToSelector:@selector(integerValue)] && [rawVersion integerValue] == 1;
}

- (void)fetchParentOrderDataWithCompletion:(void (^)(NSDictionary * _Nullable orderData, NSError * _Nullable error))completion {
    NSString *orderID = self.model.parentOrderId ?: @"";
    if (orderID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.Fulfillment"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Generic")}];
        if (completion) completion(nil, error);
        return;
    }

    FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            if (!snapshot.exists) {
                NSError *notFound = [NSError errorWithDomain:@"PurePetsPro.Fulfillment"
                                                        code:2
                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Generic")}];
                if (completion) completion(nil, notFound);
                return;
            }
            if (completion) completion(PPSafeDict(snapshot.data), nil);
        });
    }];
}

- (NSDictionary *)firstAddressPayloadInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSDictionary *address = [self addressPayloadFromValue:dictionary[key]];
        if (address.count > 0) {
            return address;
        }
    }
    return @{};
}

- (NSDictionary *)addressPayloadFromValue:(id)value {
    if ([value isKindOfClass:NSDictionary.class]) {
        return (NSDictionary *)value;
    }
    NSString *stringValue = [value isKindOfClass:NSString.class] ? [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (stringValue.length > 0) {
        return @{@"displayName": stringValue};
    }
    return @{};
}

- (NSString *)firstStringInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSString *value = PPSafeString(dictionary[key]);
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

- (double)firstNumberInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value respondsToSelector:@selector(doubleValue)]) {
            return [value doubleValue];
        }
    }
    return 0.0;
}

- (BOOL)shouldIgnoreExistingCompanyRequestError:(NSError *)error {
    NSString *message = [error.localizedDescription lowercaseString];
    return [message containsString:@"already exists"] || [message containsString:@"already-exists"];
}

- (void)executeStandardFulfillmentAction:(NSString *)action note:(NSString *)note {
    __weak typeof(self) weakSelf = self;
    [self performCanonicalFulfillmentAction:action note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            [PPHUD dismiss];
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
            return;
        }
        [self finishSuccessfulFulfillmentAction];
    }];
}

- (void)performCanonicalFulfillmentAction:(NSString *)action
                                     note:(NSString *)note
                               completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (!self.hasLiveFulfillmentState || ![self.listenerUID isEqualToString:uid] || ![self isOwnedModel:self.model uid:uid] || ![self.pendingUID isEqualToString:uid] || ![self.pendingAction isEqualToString:action]) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.Fulfillment" code:409 userInfo:@{NSLocalizedDescriptionKey:kLang(@"DeliveryStateChangedReload")}];
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }
    if ([PPFulfillmentManager isOfficialPlatformFulfillment:self.model forUID:uid]) {
        [[PPFulfillmentManager sharedManager] performOfficialPlatformTransitionAction:action fulfillmentID:self.model.fulfillmentID expectedStatus:self.pendingFromStatus note:self.pendingNote completion:completion];
    } else {
        [[PPFulfillmentManager sharedManager] performTransitionAction:action fulfillmentID:self.model.fulfillmentID expectedStatus:self.pendingFromStatus commandID:nil note:self.pendingNote completion:completion];
    }
}

- (void)finishSuccessfulFulfillmentAction {
    [PPHUD dismiss];
    [self clearPendingIntent];
    self.operationMessage = kLang(@"ProFulfillment_ActionVerified");
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.operationMessage);
}

#pragma mark - Motion

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.authListener) [[FIRAuth auth] removeAuthStateDidChangeListener:self.authListener];
    self.operationGeneration++;
    self.fulfillmentListenerGeneration += 1;
    self.eventsListenerGeneration += 1;
    [self.fulfillmentListener remove];
    [self.eventsListener remove];
}

@end
