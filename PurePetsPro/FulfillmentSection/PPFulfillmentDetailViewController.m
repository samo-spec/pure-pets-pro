#import "PPFulfillmentDetailViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPMarketplaceBranchesViewController.h"
#import "PPFulfillmentModel.h"
#import "PPFulfillmentManager.h"
#import "PPFirebaseCompat.h"
#import <math.h>
#import <CoreFoundation/CoreFoundation.h>

// Presentation only: the controller supplies a canonical phase index and owns disclosure.
static UILabel *PPFulfillmentGrowingLabel(UIFont *font, UIColor *color) {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:font];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    return label;
}

@interface PPFulfillmentJourneyView : UIView
@property (nonatomic, copy) void (^disclosureRequested)(void);
@property (nonatomic, strong) UIStackView *route;
@property (nonatomic, copy) NSArray<UIView *> *phaseRows;
@property (nonatomic, strong) UIView *currentRow;
@property (nonatomic, strong) UIView *currentNode;
@property (nonatomic, strong) CAShapeLayer *currentRing;
@property (nonatomic, strong) UIButton *disclosureButton;
@property (nonatomic, strong) UILabel *historyHint;
@property (nonatomic, strong) UIViewPropertyAnimator *disclosureAnimator;
@property (nonatomic, strong) UIViewPropertyAnimator *arrivalAnimator;
@property (nonatomic, weak) UIView *layoutHost;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL disclosureTargetExpanded;
- (instancetype)initWithTitles:(NSArray<NSString *> *)titles currentIndex:(NSInteger)index nextStep:(NSString *)nextStep expanded:(BOOL)expanded;
- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)animateCurrentStage;
- (void)stopAnimations;
@end

@implementation PPFulfillmentJourneyView

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles currentIndex:(NSInteger)index nextStep:(NSString *)nextStep expanded:(BOOL)expanded {
    if ((self = [super initWithFrame:CGRectZero])) {
        _currentIndex = index;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        UIStackView *body = [[UIStackView alloc] init];
        body.axis = UILayoutConstraintAxisVertical;
        body.spacing = 12;
        body.semanticContentAttribute = self.semanticContentAttribute;
        body.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:body];
        UILabel *counter = PPFulfillmentGrowingLabel([Styling fontMedium:13], [UIColor ppTextSecondary]);
        counter.text = [NSString localizedStringWithFormat:kLang(@"ProFulfillment_JourneyPhaseIndex"), (long)(index + 1), (long)titles.count];
        [body addArrangedSubview:counter];
        _route = [[UIStackView alloc] init];
        _route.axis = UILayoutConstraintAxisVertical;
        _route.spacing = 0;
        _route.semanticContentAttribute = self.semanticContentAttribute;
        [body addArrangedSubview:_route];
        NSArray<NSString *> *symbols = @[@"bell", @"shippingbox", @"cube.box", @"bicycle", @"creditcard", @"flag.checkered"];
        NSMutableArray<UIView *> *rows = [NSMutableArray array];
        for (NSUInteger i = 0; i < titles.count; i++) {
            BOOL current = (NSInteger)i == index;
            UIView *row = [[UIView alloc] init];
            row.layer.cornerRadius = 18;
            row.layer.cornerCurve = kCACornerCurveContinuous;
            row.backgroundColor = current ? [[UIColor ppPrimary] colorWithAlphaComponent:0.07] : UIColor.clearColor;
            row.isAccessibilityElement = YES;
            row.accessibilityTraits = UIAccessibilityTraitStaticText;
            row.accessibilityLabel = current ? [NSString stringWithFormat:kLang(@"ProFulfillment_JourneyCurrentLabel"), titles[i], nextStep ?: @""] : titles[i];
            row.accessibilityIdentifier = [NSString stringWithFormat:@"fulfillment.phase.%lu", (unsigned long)i];
            UIStackView *line = [[UIStackView alloc] init];
            line.axis = UILayoutConstraintAxisHorizontal;
            line.spacing = 12;
            line.alignment = UIStackViewAlignmentFill;
            line.semanticContentAttribute = self.semanticContentAttribute;
            line.translatesAutoresizingMaskIntoConstraints = NO;
            [row addSubview:line];
            UIView *markerColumn = [[UIView alloc] init];
            [markerColumn.widthAnchor constraintEqualToConstant:44].active = YES;
            [markerColumn.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
            UIView *connector = [[UIView alloc] init];
            connector.backgroundColor = [UIColor ppSurfaceBorder];
            connector.translatesAutoresizingMaskIntoConstraints = NO;
            [markerColumn addSubview:connector];
            UIView *node = [[UIView alloc] init];
            node.translatesAutoresizingMaskIntoConstraints = NO;
            node.isAccessibilityElement = NO;
            [markerColumn addSubview:node];
            UIView *disc = [[UIView alloc] init];
            disc.backgroundColor = current ? [UIColor ppPrimary] : [UIColor ppSecondarySurface];
            disc.layer.cornerRadius = 16;
            disc.translatesAutoresizingMaskIntoConstraints = NO;
            [node addSubview:disc];
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbols[MIN(i, symbols.count - 1)]]];
            icon.tintColor = current ? UIColor.whiteColor : [UIColor ppTextSecondary];
            icon.contentMode = UIViewContentModeScaleAspectFit;
            icon.translatesAutoresizingMaskIntoConstraints = NO;
            icon.isAccessibilityElement = NO;
            [disc addSubview:icon];
            [NSLayoutConstraint activateConstraints:@[
                [node.widthAnchor constraintEqualToConstant:44], [node.heightAnchor constraintEqualToConstant:44],
                [node.centerXAnchor constraintEqualToAnchor:markerColumn.centerXAnchor], [node.centerYAnchor constraintEqualToAnchor:markerColumn.centerYAnchor],
                [disc.widthAnchor constraintEqualToConstant:32], [disc.heightAnchor constraintEqualToConstant:32],
                [disc.centerXAnchor constraintEqualToAnchor:node.centerXAnchor], [disc.centerYAnchor constraintEqualToAnchor:node.centerYAnchor],
                [icon.widthAnchor constraintEqualToConstant:16], [icon.heightAnchor constraintEqualToConstant:16],
                [icon.centerXAnchor constraintEqualToAnchor:disc.centerXAnchor], [icon.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor],
                [connector.widthAnchor constraintEqualToConstant:1.5], [connector.centerXAnchor constraintEqualToAnchor:markerColumn.centerXAnchor],
                [connector.topAnchor constraintEqualToAnchor:(i == 0 ? markerColumn.centerYAnchor : markerColumn.topAnchor)],
                [connector.bottomAnchor constraintEqualToAnchor:(i == titles.count - 1 ? markerColumn.centerYAnchor : markerColumn.bottomAnchor)],
            ]];
            [line addArrangedSubview:markerColumn];
            UIStackView *words = [[UIStackView alloc] init];
            words.axis = UILayoutConstraintAxisVertical;
            words.spacing = 5;
            words.layoutMargins = UIEdgeInsetsMake(12, 0, 12, 0);
            words.layoutMarginsRelativeArrangement = YES;
            UILabel *title = PPFulfillmentGrowingLabel(current ? [Styling fontBold:20] : [Styling fontMedium:16], current ? [UIColor ppTextPrimary] : [UIColor ppTextSecondary]);
            title.text = titles[i];
            [words addArrangedSubview:title];
            if (current) {
                UILabel *detail = PPFulfillmentGrowingLabel([Styling fontRegular:14], [UIColor ppTextSecondary]);
                detail.text = nextStep;
                [words addArrangedSubview:detail];
                self.currentRow = row;
                self.currentNode = node;
                self.currentRing = [CAShapeLayer layer];
                self.currentRing.fillColor = UIColor.clearColor.CGColor;
                self.currentRing.strokeColor = [UIColor ppPrimary].CGColor;
                self.currentRing.lineWidth = 1.5;
                self.currentRing.strokeEnd = 1;
                [node.layer addSublayer:self.currentRing];
            }
            [line addArrangedSubview:words];
            [NSLayoutConstraint activateConstraints:@[
                [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:8],
                [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
                [line.topAnchor constraintEqualToAnchor:row.topAnchor], [line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            ]];
            [self.route addArrangedSubview:row];
            [rows addObject:row];
        }
        self.phaseRows = rows.copy;
        self.disclosureButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.disclosureButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[Styling fontBold:15]];
        self.disclosureButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        self.disclosureButton.titleLabel.numberOfLines = 0;
        self.disclosureButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.disclosureButton.semanticContentAttribute = self.semanticContentAttribute;
        self.disclosureButton.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
        self.disclosureButton.layer.cornerRadius = 14;
        self.disclosureButton.backgroundColor = [UIColor ppSecondarySurface];
        [self.disclosureButton setTitleColor:[UIColor ppTextPrimary] forState:UIControlStateNormal];
        [self.disclosureButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        self.disclosureButton.accessibilityIdentifier = @"fulfillment.phaseDisclosure";
        [self.disclosureButton addTarget:self action:@selector(disclosureTapped:) forControlEvents:UIControlEventTouchUpInside];
        [body addArrangedSubview:self.disclosureButton];
        self.historyHint = PPFulfillmentGrowingLabel([Styling fontRegular:13], [UIColor ppTextSecondary]);
        self.historyHint.text = kLang(@"ProFulfillment_JourneyHistoryHint");
        [body addArrangedSubview:self.historyHint];
        [NSLayoutConstraint activateConstraints:@[
            [body.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [body.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [body.topAnchor constraintEqualToAnchor:self.topAnchor], [body.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
        [self setExpanded:expanded animated:NO];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.currentRing.frame = self.currentNode.bounds;
    self.currentRing.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.currentNode.bounds, 1.5, 1.5)].CGPath;
}

- (void)disclosureTapped:(UIButton *)sender { if (self.disclosureRequested) self.disclosureRequested(); }

- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated {
    BOOL canAnimate = animated && self.window && !UIAccessibilityIsReduceMotionEnabled();
    if (canAnimate && self.disclosureAnimator.state == UIViewAnimatingStateActive) {
        self.expanded = expanded;
        [self updateDisclosureTitle];
        self.disclosureAnimator.reversed = expanded != self.disclosureTargetExpanded;
        return;
    }
    [self stopAnimations];
    self.expanded = expanded;
    [self updateDisclosureTitle];
    __weak UIView *layoutHost = self.layoutHost ?: self.superview;
    [layoutHost layoutIfNeeded];
    __weak typeof(self) weakSelf = self;
    void (^updates)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self applyDisclosureVisibility];
        [layoutHost layoutIfNeeded];
    };
    if (!canAnimate) { updates(); return; }
    self.disclosureTargetExpanded = expanded;
    self.disclosureAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.18 curve:UIViewAnimationCurveEaseInOut animations:updates];
    [self.disclosureAnimator addCompletion:^(UIViewAnimatingPosition position) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.disclosureAnimator = nil;
        [self settleDisclosureLayout];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.disclosureButton);
    }];
    [self.disclosureAnimator startAnimation];
}

- (void)updateDisclosureTitle {
    [self.disclosureButton setTitle:kLang(self.expanded ? @"ProFulfillment_JourneyCollapse" : @"ProFulfillment_JourneyExpand") forState:UIControlStateNormal];
    self.disclosureButton.accessibilityValue = kLang(self.expanded ? @"ProFulfillment_Expanded" : @"ProFulfillment_Collapsed");
}

- (void)applyDisclosureVisibility {
    NSInteger first = MAX(0, MIN(self.currentIndex - 1, (NSInteger)self.phaseRows.count - 3));
    for (NSUInteger i = 0; i < self.phaseRows.count; i++) self.phaseRows[i].hidden = !self.expanded && ((NSInteger)i < first || (NSInteger)i >= first + 3);
    self.historyHint.hidden = !self.expanded;
}

- (void)settleDisclosureLayout {
    [UIView performWithoutAnimation:^{
        [self applyDisclosureVisibility];
        [self updateDisclosureTitle];
        [(self.layoutHost ?: self.superview) layoutIfNeeded];
    }];
}

- (void)animateCurrentStage {
    [self stopAnimations];
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) return;
    [self layoutIfNeeded];
    self.currentRow.alpha = 0.45;
    self.currentRow.transform = CGAffineTransformMakeTranslation(0, 5);
    __weak typeof(self) weakSelf = self;
    self.arrivalAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.20 curve:UIViewAnimationCurveEaseOut animations:^{
        weakSelf.currentRow.alpha = 1;
        weakSelf.currentRow.transform = CGAffineTransformIdentity;
    }];
    [self.arrivalAnimator startAnimation];
    CABasicAnimation *trace = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    trace.fromValue = @0; trace.toValue = @1; trace.duration = 0.20;
    trace.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.currentRing addAnimation:trace forKey:@"pp.fulfillment.currentTrace"];
}

- (void)stopAnimations {
    [self.disclosureAnimator stopAnimation:YES]; self.disclosureAnimator = nil;
    [self.arrivalAnimator stopAnimation:YES]; self.arrivalAnimator = nil;
    [self.currentRing removeAnimationForKey:@"pp.fulfillment.currentTrace"];
    [self.currentRow.layer removeAllAnimations];
    self.currentRow.alpha = 1;
    self.currentRow.transform = CGAffineTransformIdentity;
    [self settleDisclosureLayout];
}

- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self stopAnimations]; }
@end



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
@property (nonatomic, strong) PPFulfillmentJourneyView *journeyView;
@property (nonatomic, copy) NSString *lastPresentedJourneyStatus;
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
    self.mayDisplayDossier = [self isOwnedModel:self.model uid:[FIRAuth auth].currentUser.uid ?: @""];
    self.liveMessage = kLang(@"ProFulfillment_CheckingOrder");
    [self buildScrollView];
    [self renderDossier];
    [self observeFulfillment];
    [self observeEvents];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(journeyMotionPreferenceChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopJourneyMotion:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopJourneyMotion:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeJourneyMotion:) name:UIApplicationDidBecomeActiveNotification object:nil];
    NSString *entryUID = [FIRAuth auth].currentUser.uid ?: @"";
    __weak typeof(self) weakSelf = self;
    self.authListener = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || [entryUID isEqualToString:user.uid ?: @""]) return;
        self.operationGeneration++;
        self.submitting = NO;
        self.hasLiveFulfillmentState = NO;
        self.mayDisplayDossier = NO;
        self.operationMessage = nil;
        [self clearPendingIntent];
        [self.fulfillmentListener remove];
        [self.eventsListener remove];
        self.fulfillmentListenerGeneration++;
        self.eventsListenerGeneration++;
        [self.stack.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.currentEvents = @[];
        self.eventsContainer = nil;
        [self.journeyView stopAnimations];
        self.journeyView = nil;
        self.lastPresentedJourneyStatus = nil;
        self.liveMessage = kLang(@"ProFulfillment_OrderUnavailable");
        [self refreshActionBarFromLiveFulfillment];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Fulfillment_DetailTitle") showBack:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self animateJourneyIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.journeyView stopAnimations];
}

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
    [self.journeyView stopAnimations];
    self.journeyView = nil;
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
    [self animateJourneyIfNeeded];
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
    UIStackView *content = [self verticalStackWithSpacing:16];
    [surface addSubview:content];
    UILabel *reference = [self labelWithFont:[Styling fontBold:20] color:[UIColor ppTextPrimary] lines:0];
    reference.text = [self primaryOrderTitle];
    reference.accessibilityTraits = UIAccessibilityTraitHeader;
    [content addArrangedSubview:reference];
    UIStackView *statusLine = [[UIStackView alloc] init];
    statusLine.axis = UILayoutConstraintAxisHorizontal;
    statusLine.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIStackView *statusCapsule = [[UIStackView alloc] init];
    statusCapsule.layoutMargins = UIEdgeInsetsMake(7, 12, 7, 12);
    statusCapsule.layoutMarginsRelativeArrangement = YES;
    statusCapsule.backgroundColor = [self.model.statusColor colorWithAlphaComponent:0.10];
    statusCapsule.layer.cornerRadius = 12;
    [statusCapsule setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UILabel *status = [self labelWithFont:[Styling fontBold:15] color:[UIColor ppTextPrimary] lines:0];
    status.text = self.model.statusDisplayName;
    status.accessibilityIdentifier = @"fulfillment.exactStatus";
    [statusCapsule addArrangedSubview:status];
    [statusLine addArrangedSubview:statusCapsule];
    [statusLine addArrangedSubview:[[UIView alloc] init]];
    [content addArrangedSubview:statusLine];
    NSInteger current = self.model.lifecycleStageIndex;
    if (current == NSNotFound) {
        UILabel *exception = [self labelWithFont:[Styling fontMedium:16] color:[UIColor ppTextSecondary] lines:0];
        exception.text = kLang(self.model.isTerminal ? @"ProFulfillment_JourneyExceptionHint" : @"ProFulfillment_UnknownState");
        [content addArrangedSubview:exception];
    } else {
        NSArray *keys = @[@"ProFulfillment_PhaseNew", @"ProFulfillment_PhasePreparation", @"ProFulfillment_PhaseReady", @"ProFulfillment_PhaseTransit", @"ProFulfillment_PhaseDelivered", @"ProFulfillment_PhaseCompleted"];
        NSMutableArray<NSString *> *titles = [NSMutableArray array];
        for (NSString *key in keys) [titles addObject:kLang(key)];
        NSString *nextStep = self.model.requiresProviderAction
            ? [NSString stringWithFormat:kLang(@"ProFulfillment_NextAction"), self.model.nextActionForStatus]
            : self.model.waitingDescription;
        self.journeyView = [[PPFulfillmentJourneyView alloc] initWithTitles:titles currentIndex:current nextStep:nextStep expanded:self.phasesExpanded];
        self.journeyView.layoutHost = self.scrollView;
        __weak typeof(self) weakSelf = self;
        self.journeyView.disclosureRequested = ^{ [weakSelf togglePhases:nil]; };
        [content addArrangedSubview:self.journeyView];
    }
    [self pinContent:content toSurface:surface];
    [self.stack addArrangedSubview:surface];
}

- (void)togglePhases:(UIButton *)sender {
    self.phasesExpanded = !self.phasesExpanded;
    [self.journeyView setExpanded:self.phasesExpanded animated:YES];
}

- (void)animateJourneyIfNeeded {
    if (!self.journeyView || !self.hasLiveFulfillmentState || !self.mayDisplayDossier || !self.view.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    BOOL changed = ![self.lastPresentedJourneyStatus isEqualToString:self.model.status];
    self.lastPresentedJourneyStatus = self.model.status;
    if (changed && !UIAccessibilityIsReduceMotionEnabled()) [self.journeyView animateCurrentStage];
}

- (void)journeyMotionPreferenceChanged:(NSNotification *)notification {
    [self.journeyView stopAnimations];
    // Current marker, labels and disclosure state carry the complete meaning without motion.
}

- (void)stopJourneyMotion:(NSNotification *)notification { [self.journeyView stopAnimations]; }
- (void)resumeJourneyMotion:(NSNotification *)notification { [self animateJourneyIfNeeded]; }

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
    UIStackView *content = [self verticalStackWithSpacing:18];
    [section addSubview:content];
    UIStackView *heading = [[UIStackView alloc] init];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.alignment = UIStackViewAlignmentFirstBaseline;
    heading.spacing = 12;
    heading.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UILabel *title = [self sectionTitle:kLang(@"ProFulfillment_ManifestTitle")];
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    [heading addArrangedSubview:title];
    UILabel *count = [self labelWithFont:[Styling fontBold:17] color:[UIColor ppTextSecondary] lines:0];
    count.text = [[self manifestNumberFormatter] stringFromNumber:@(self.model.items.count)];
    count.accessibilityLabel = [NSString localizedStringWithFormat:kLang(@"ProFulfillment_ManifestCount"), (long)self.model.items.count];
    [count setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [heading addArrangedSubview:count];
    [content addArrangedSubview:heading];
    if (self.model.items.count == 0) {
        UILabel *empty = [self labelWithFont:[Styling fontRegular:15] color:[UIColor ppTextSecondary] lines:0];
        empty.text = kLang(@"Fulfillment_NoItems");
        [content addArrangedSubview:empty];
    } else {
        for (NSInteger i = 0; i < self.model.items.count; i++) {
            if (i > 0) { UIView *divider = [[UIView alloc] init]; divider.backgroundColor = [UIColor ppSurfaceBorder]; [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES; [content addArrangedSubview:divider]; }
            [content addArrangedSubview:[self itemRow:PPSafeDict(self.model.items[i]) index:i]];
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
    if (self.pendingAction.length && !self.commandAccepted && !self.submitting && !self.hasLiveFulfillmentState) {
        state.text = [NSString stringWithFormat:@"%@\n%@", state.text ?: @"", kLang(@"ProFulfillment_RetryNeedsLive")];
    }
    state.accessibilityIdentifier = @"fulfillment.commandState";
    if (state.text.length) [content addArrangedSubview:state];
    if (self.pendingAction.length) {
        if (!self.submitting) {
            [content addArrangedSubview:[self recoveryButton:kLang(@"ProFulfillment_RecheckResult") selector:@selector(recheckPending:)]];
            if (!self.commandAccepted) {
                UIButton *retry = [self recoveryButton:kLang(@"ProFulfillment_RetrySameAction") selector:@selector(retryPending:)];
                retry.enabled = self.hasLiveFulfillmentState;
                retry.alpha = retry.enabled ? 1.0 : 0.5;
                if (!retry.enabled) retry.accessibilityHint = kLang(@"ProFulfillment_RetryNeedsLive");
                [content addArrangedSubview:retry];
            }
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
    NSMutableArray<NSString *> *secondaryActions = [NSMutableArray array];
    NSMutableArray<NSString *> *actionTitles = [NSMutableArray array];
    NSMutableArray<NSNumber *> *actionStyles = [NSMutableArray array];

    for (NSString *action in self.model.availableActions) {
        if (![action isEqualToString:@"reject"] && ![action isEqualToString:@"cancel_request"]) continue;
        [secondaryActions addObject:action];
        [actionTitles addObject:[self displayNameForAction:action]];
        [actionStyles addObject:@(PPAlertActionStyleDestructive)];
    }
    if (secondaryActions.count == 0) return;

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showActionSheetIn:self
                               title:kLang(@"ProFulfillment_OtherActions")
                            subtitle:self.model.statusDisplayName
                             actions:actionTitles
                        actionStyles:actionStyles
                         cancelTitle:kLang(@"ProFulfillment_KeepOrder")
                          completion:^(NSInteger index) {
        if (index >= 0 && index < (NSInteger)secondaryActions.count) {
            [weakSelf confirmAction:secondaryActions[index]];
        }
    }];
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

- (NSNumberFormatter *)manifestNumberFormatter {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar_QA" : @"en_QA"];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = 6;
    return formatter;
}

- (NSNumber *)manifestNumber:(id)value {
    if ([value isKindOfClass:NSNumber.class]) {
        if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return nil;
        return isfinite([value doubleValue]) ? value : nil;
    }
    if (![value isKindOfClass:NSString.class] || ![value length]) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:value];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number = 0;
    return [scanner scanDouble:&number] && scanner.isAtEnd && isfinite(number) ? @(number) : nil;
}

- (NSString *)manifestVariantForItem:(NSDictionary *)item {
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
                NSString *nameAr = PPSafeString(val[@"nameAr"]);
                NSString *nameEn = PPSafeString(val[@"nameEn"]);
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
        NSString *cName = PPSafeString(Language.isRTL ? vc[@"nameAr"] : vc[@"nameEn"]);
        if (cName.length > 0) variantDesc = cName;
    }

    return variantDesc ?: @"";
}

- (UIView *)itemRow:(NSDictionary *)item index:(NSInteger)index {
    UIStackView *row = [self verticalStackWithSpacing:14];
    BOOL accessibleSize = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    UIStackView *identity = [[UIStackView alloc] init];
    identity.axis = accessibleSize ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    identity.spacing = 12;
    identity.alignment = accessibleSize ? UIStackViewAlignmentLeading : UIStackViewAlignmentTop;
    identity.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIStackView *ordinalTile = [[UIStackView alloc] init];
    ordinalTile.layoutMargins = UIEdgeInsetsMake(10, 12, 10, 12);
    ordinalTile.layoutMarginsRelativeArrangement = YES;
    ordinalTile.backgroundColor = [UIColor ppSecondarySurface];
    ordinalTile.layer.cornerRadius = 14;
    ordinalTile.accessibilityElementsHidden = YES;
    [ordinalTile.widthAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [ordinalTile.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [ordinalTile setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UILabel *ordinal = [self labelWithFont:[Styling fontBold:17] color:[UIColor ppPrimary] lines:0];
    ordinal.text = [[self manifestNumberFormatter] stringFromNumber:@(index + 1)];
    ordinal.textAlignment = NSTextAlignmentCenter;
    [ordinalTile addArrangedSubview:ordinal];
    [identity addArrangedSubview:ordinalTile];
    UIStackView *words = [self verticalStackWithSpacing:6];
    NSString *nameText = PPSafeString(item[@"name"]);
    if (!nameText.length) nameText = [NSString stringWithFormat:@"%@ %@", kLang(@"Fulfillment_Item"), ordinal.text];
    UILabel *name = [self labelWithFont:[Styling fontBold:18] color:[UIColor ppTextPrimary] lines:0];
    name.text = nameText;
    [words addArrangedSubview:name];
    NSString *variant = [self manifestVariantForItem:item];
    if (variant.length) { UILabel *label = [self labelWithFont:[Styling fontRegular:14] color:[UIColor ppTextSecondary] lines:0]; label.text = variant; [words addArrangedSubview:label]; }
    [identity addArrangedSubview:words];
    if (accessibleSize) [words.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    [row addArrangedSubview:identity];

    NSNumber *quantity = [self manifestNumber:item[@"quantity"]];
    if (quantity.doubleValue <= 0) quantity = [self manifestNumber:item[@"qty"]];
    if (quantity.doubleValue <= 0) quantity = nil;
    NSString *quantityText = quantity ? [[self manifestNumberFormatter] stringFromNumber:quantity] : kLang(@"ProFulfillment_ManifestUnavailable");
    NSNumber *price = [self manifestNumber:item[@"price"]];
    NSString *priceText = price && price.doubleValue >= 0 && self.model.currency.length ? [self moneyString:price.doubleValue] : kLang(@"ProFulfillment_ManifestUnavailable");
    UIStackView *metrics = [[UIStackView alloc] init];
    metrics.axis = accessibleSize ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    metrics.spacing = 16;
    metrics.alignment = accessibleSize ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    metrics.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIStackView *quantityMetric = [self verticalStackWithSpacing:3];
    quantityMetric.layoutMargins = UIEdgeInsetsMake(8, 12, 8, 12);
    quantityMetric.layoutMarginsRelativeArrangement = YES;
    quantityMetric.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.07];
    quantityMetric.layer.cornerRadius = 12;
    [quantityMetric setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UILabel *quantityTitle = [self labelWithFont:[Styling fontMedium:12] color:[UIColor ppTextSecondary] lines:0];
    quantityTitle.text = kLang(@"ProFulfillment_ManifestQuantity");
    UILabel *quantityValue = [self labelWithFont:[Styling fontBold:18] color:[UIColor ppTextPrimary] lines:0];
    quantityValue.text = quantityText;
    [quantityMetric addArrangedSubview:quantityTitle]; [quantityMetric addArrangedSubview:quantityValue];
    [metrics addArrangedSubview:quantityMetric];
    if (!accessibleSize) [metrics addArrangedSubview:[[UIView alloc] init]];
    UIStackView *priceMetric = [self verticalStackWithSpacing:3];
    UILabel *priceTitle = [self labelWithFont:[Styling fontMedium:12] color:[UIColor ppTextSecondary] lines:0];
    priceTitle.text = kLang(@"ProFulfillment_ManifestUnitPrice");
    UILabel *priceValue = [self labelWithFont:[Styling fontBold:20] color:[UIColor ppTextPrimary] lines:0];
    priceValue.text = priceText;
    [priceMetric addArrangedSubview:priceTitle]; [priceMetric addArrangedSubview:priceValue];
    [metrics addArrangedSubview:priceMetric];
    if (accessibleSize) [priceMetric.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    [row addArrangedSubview:metrics];
    row.isAccessibilityElement = YES;
    row.accessibilityTraits = UIAccessibilityTraitStaticText;
    row.accessibilityLabel = [@[nameText, variant, [NSString stringWithFormat:@"%@: %@", quantityTitle.text, quantityText], [NSString stringWithFormat:@"%@: %@", priceTitle.text, priceText]] componentsJoinedByString:@". "];
    row.accessibilityIdentifier = [NSString stringWithFormat:@"fulfillment.manifest.%ld", (long)index];
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
            [self.journeyView stopAnimations];
            self.journeyView = nil;
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
    if (!note.length) note = PPSafeString(PPSafeDict(event[@"metadata"])[@"note"]);
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
    return key.length > 0 ? kLang(key) : kLang(@"ProFulfillment_StatusUpdate");
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
    self.reviewRequiresNote = NO;
    NSString *message = [NSString stringWithFormat:kLang(@"ProFulfillment_ReviewTransition"), self.model.statusDisplayName, [PPFulfillmentModel displayNameForStatus:target]];
    if ([action isEqualToString:@"confirm_handover"]) message = [message stringByAppendingFormat:@"\n\n%@", kLang(@"ProFulfillment_HandoverReview")];
    if (official) message = [message stringByAppendingFormat:@"\n\n%@", kLang(@"Fulfillment_StaffNoteMessage")];

    BOOL destructive = [action isEqualToString:@"reject"] || [action isEqualToString:@"cancel_request"];
    NSString *placeholder = kLang(@"Fulfillment_NoteOptional");
    NSString *confirmTitle = [self displayNameForAction:action];
    NSString *cancelTitle = kLang(@"ProFulfillment_KeepOrder");

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showTextFieldAlertIn:self
                                  title:confirmTitle
                               subtitle:message
                            placeholder:placeholder
                            initialText:nil
                            confirmText:confirmTitle
                             cancelText:cancelTitle
                            destructive:destructive
                             completion:^(NSString * _Nullable text, BOOL didConfirm) {
        if (!didConfirm) return;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *note = [text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || !self.hasLiveFulfillmentState || ![self.model.fulfillmentID isEqualToString:fulfillmentID] || ![self.model.status isEqualToString:source] || ![self.model.availableActions containsObject:action]) {
            self.operationMessage = kLang(@"ProFulfillment_StateChanged");
            [self observeFulfillment];
            return;
        }
        if (note.length < 3) {
            note = [PPFulfillmentModel autoGeneratedNoteForAction:action targetStatus:target];
        }
        if (note.length > 512) {
            note = [note substringToIndex:512];
        }
        self.pendingAction = action;
        self.pendingFromStatus = source;
        self.pendingTargetStatus = target;
        self.pendingNote = note;
        self.pendingUID = uid;
        self.commandAccepted = NO;
        [self executeAction:action note:note];
    }];
}

- (void)executeAction:(NSString *)action note:(NSString *)note {
    if (self.submitting || !self.pendingAction.length || ![action isEqualToString:self.pendingAction] || ![note ?: @"" isEqualToString:self.pendingNote ?: @""]) return;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (![uid isEqualToString:self.pendingUID] || ![self isOwnedModel:self.model uid:uid]) return;
    if (!self.hasLiveFulfillmentState) {
        self.operationMessage = kLang(@"ProFulfillment_RetryNeedsLive");
        [self refreshActionBarFromLiveFulfillment];
        return;
    }
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
            BOOL callableError = [error.domain isEqualToString:FIRFunctionsErrorDomain];
            NSString *serverMessage = [message ?: error.localizedDescription ?: @"" lowercaseString];
            BOOL staleStatus = (callableError && error.code == FIRFunctionsErrorCodeFailedPrecondition &&
                [serverMessage containsString:@"fulfillment status changed"]);
            BOOL localConflict = [error.domain isEqualToString:@"PurePetsPro.Fulfillment"] && error.code == 409;
            BOOL localRejection = [error.domain isEqualToString:@"PPFulfillmentManager"] &&
                [@[@400, @401, @403, @404, @422] containsObject:@(error.code)];
            BOOL definitiveRejection = callableError && [@[@(FIRFunctionsErrorCodeFailedPrecondition),
                @(FIRFunctionsErrorCodePermissionDenied), @(FIRFunctionsErrorCodeUnauthenticated),
                @(FIRFunctionsErrorCodeInvalidArgument), @(FIRFunctionsErrorCodeNotFound),
                @(FIRFunctionsErrorCodeAlreadyExists)] containsObject:@(error.code)];
            if (staleStatus || localConflict || localRejection || definitiveRejection) {
                [self clearPendingIntent];
                self.operationMessage = staleStatus || localConflict ? kLang(@"ProFulfillment_StateChanged") : (localRejection ? kLang(@"ProFulfillment_ActionDenied") : [self blockerMessageForError:error serverMessage:serverMessage]);
                [self observeFulfillment];
            } else {
                // Preserve the frozen source/action/note. Manager derives the same durable intent ID on retry.
                self.operationMessage = kLang([error.domain isEqualToString:@"PPFulfillmentManager"] && error.code == 502 ? @"ProFulfillment_InvalidReceipt" : @"ProFulfillment_ActionUncertain");
                [self refreshActionBarFromLiveFulfillment];
            }
            return;
        }
        self.commandAccepted = YES;
        [self verifyPendingIntent];
    }];
}

- (NSString *)blockerMessageForError:(NSError *)error serverMessage:(NSString *)serverMessage {
    NSDictionary *details = PPSafeDict(error.userInfo[FIRFunctionsErrorDetailsKey]);
    NSString *domainCode = PPSafeString(details[@"domainCode"]);
    // These codes belong to Infra's cancellation engine, not to a local status machine.
    NSDictionary<NSString *, NSString *> *reasons = @{
        @"FULFILLMENT_RETURN_REQUIRED": @"ProFulfillment_ReturnRequired",
        @"FULFILLMENT_RESERVATION_REVIEW_REQUIRED": @"ProFulfillment_ReservationReview",
        @"FULFILLMENT_CANCELLATION_REVIEW_REQUIRED": @"ProFulfillment_CancellationReview",
        @"FULFILLMENT_CASH_RECONCILIATION_REQUIRED": @"ProFulfillment_CashReview",
        @"FULFILLMENT_DELIVERY_EVIDENCE_REQUIRED": @"ProFulfillment_DeliveryEvidenceRequired"
    };
    NSString *key = reasons[domainCode];
    if (key.length) return kLang(key);
    // Released provider preconditions predate domain codes; match only their known messages.
    if ([serverMessage containsString:@"payment must be confirmed"]) return kLang(@"ProFulfillment_PaymentRequired");
    if ([serverMessage containsString:@"no delivery driver has been assigned"]) return kLang(@"ProFulfillment_DriverRequired");
    if ([serverMessage containsString:@"fulfillmentversion 1"] || [serverMessage containsString:@"parent order"] || [serverMessage containsString:@"parent projection"]) return kLang(@"ProFulfillment_OrderReviewRequired");
    if (error.code == FIRFunctionsErrorCodePermissionDenied || error.code == FIRFunctionsErrorCodeUnauthenticated) return kLang(@"ProFulfillment_ActionDenied");
    if (error.code == FIRFunctionsErrorCodeNotFound) return kLang(@"ProFulfillment_OrderUnavailable");
    return kLang(@"ProFulfillment_ActionBlocked");
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

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.journeyView stopAnimations];
    if (self.authListener) [[FIRAuth auth] removeAuthStateDidChangeListener:self.authListener];
    self.operationGeneration++;
    self.fulfillmentListenerGeneration += 1;
    self.eventsListenerGeneration += 1;
    [self.fulfillmentListener remove];
    [self.eventsListener remove];
}

@end
