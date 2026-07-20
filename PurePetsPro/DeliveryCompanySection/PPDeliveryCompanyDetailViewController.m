#import "PPDeliveryCompanyDetailViewController.h"
#import "PPDeliveryCompanyService.h"

typedef NS_ENUM(NSInteger, PPDCDetailAction) {
    PPDCDetailActionAccept = 1,
    PPDCDetailActionReject,
    PPDCDetailActionAssign,
    PPDCDetailActionReassign,
    PPDCDetailActionComplete,
    PPDCDetailActionCancel,
    PPDCDetailActionDriverProgress,
};

@interface PPDeliveryCompanyDetailViewController ()
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, strong) PPDeliveryCompanyProfile *profile;
@property (nonatomic, strong) PPDeliveryCompanyRequest *request;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *stateView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *stateTitle;
@property (nonatomic, strong) UILabel *stateSubtitle;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) NSMutableArray<UIButton *> *actionButtons;
@property (nonatomic, assign) BOOL actionInFlight;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@end

@implementation PPDeliveryCompanyDetailViewController

- (instancetype)initWithRequestID:(NSString *)requestID profile:(PPDeliveryCompanyProfile *)profile {
    if (self = [super init]) {
        _requestID = [requestID copy];
        _profile = profile;
        _actionButtons = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.05];
    self.topGlowView.layer.cornerRadius = 120.0;
    self.topGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:self.topGlowView];

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.035];
    self.bottomGlowView.layer.cornerRadius = 150.0;
    self.bottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:self.bottomGlowView];
    [self buildUI];
    [self loadRequest];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryCompany_Detail_NavTitle") showBack:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];
    
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];
    
    self.stateView = [[UIView alloc] init];
    self.stateView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stateView];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AppPrimaryClr;
    [self.stateView addSubview:self.spinner];
    self.stateTitle = [self label:PPFontBold(19) color:PrimaryTextClr lines:2];
    self.stateTitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateTitle];
    self.stateSubtitle = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    self.stateSubtitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateSubtitle];
    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.backgroundColor = AppPrimaryClr;
    self.retryButton.layer.cornerRadius = 16.0;
    self.retryButton.titleLabel.font = PPFontBold(15);
    [self.retryButton setTitle:kLang(@"Retry") forState:UIControlStateNormal];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.retryButton addTarget:self action:@selector(loadRequest) forControlEvents:UIControlEventTouchUpInside];
    [self.stateView addSubview:self.retryButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.topGlowView.widthAnchor constraintEqualToConstant:240.0],
        [self.topGlowView.heightAnchor constraintEqualToConstant:240.0],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-70.0],
        [self.topGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:60.0],
        [self.bottomGlowView.widthAnchor constraintEqualToConstant:300.0],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:300.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:110.0],
        [self.bottomGlowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-90.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
        
        [self.stateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-24.0],
        [self.stateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:34.0],
        [self.stateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-34.0],
        [self.spinner.topAnchor constraintEqualToAnchor:self.stateView.topAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [self.stateTitle.topAnchor constraintEqualToAnchor:self.spinner.bottomAnchor constant:16.0],
        [self.stateTitle.leadingAnchor constraintEqualToAnchor:self.stateView.leadingAnchor],
        [self.stateTitle.trailingAnchor constraintEqualToAnchor:self.stateView.trailingAnchor],
        [self.stateSubtitle.topAnchor constraintEqualToAnchor:self.stateTitle.bottomAnchor constant:7.0],
        [self.stateSubtitle.leadingAnchor constraintEqualToAnchor:self.stateView.leadingAnchor],
        [self.stateSubtitle.trailingAnchor constraintEqualToAnchor:self.stateView.trailingAnchor],
        [self.retryButton.topAnchor constraintEqualToAnchor:self.stateSubtitle.bottomAnchor constant:16.0],
        [self.retryButton.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [self.retryButton.widthAnchor constraintGreaterThanOrEqualToConstant:120.0],
        [self.retryButton.heightAnchor constraintEqualToConstant:44.0],
        [self.retryButton.bottomAnchor constraintEqualToAnchor:self.stateView.bottomAnchor],
    ]];
}

- (void)loadRequest {
    self.scrollView.hidden = YES;
    self.stateView.hidden = NO;
    self.stateTitle.hidden = YES;
    self.stateSubtitle.hidden = YES;
    self.retryButton.hidden = YES;
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared getRequestWithID:self.requestID completion:^(PPDeliveryCompanyRequest * _Nullable request, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.spinner stopAnimating];
        if (error || !request) {
            [self showError:error.localizedDescription];
            return;
        }
        self.request = request;
        [self renderRequest];
    }];
}

- (void)showError:(NSString *)message {
    self.scrollView.hidden = YES;
    self.stateView.hidden = NO;
    self.stateTitle.hidden = NO;
    self.stateSubtitle.hidden = NO;
    self.retryButton.hidden = NO;
    self.stateTitle.text = kLang(@"DeliveryCompany_Error_Title");
    self.stateSubtitle.text = message.length ? message : kLang(@"DeliveryCompany_Error_Generic");
}

- (void)renderRequest {
    for (UIView *view in self.contentStack.arrangedSubviews) {
        [self.contentStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.actionButtons removeAllObjects];
    [self.contentStack addArrangedSubview:[self heroView]];
    [self.contentStack addArrangedSubview:[self routeSection]];
    [self.contentStack addArrangedSubview:[self assignmentSection]];
    [self.contentStack addArrangedSubview:[self informationSection]];
    [self.contentStack addArrangedSubview:[self timelineSection]];
    UIView *actions = [self actionsSection];
    if (actions) [self.contentStack addArrangedSubview:actions];
    self.stateView.hidden = YES;
    self.scrollView.hidden = NO;
    [self.view layoutIfNeeded];
}

- (UIView *)heroView {
    UIView *surface = [self surface];
    UIView *statusDot = [[UIView alloc] init];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = self.request.statusColor;
    statusDot.layer.cornerRadius = 5.0;
    [surface addSubview:statusDot];
    
    UILabel *eyebrow = [self label:PPFontBold(11) color:self.request.statusColor lines:1];
    eyebrow.text = self.request.statusDisplayName;
    [surface addSubview:eyebrow];
    UILabel *title = [self label:PPFontBold(34) color:PrimaryTextClr lines:3];
    title.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Order_Format"), self.request.bestOrderNumber];
    [surface addSubview:title];
    UILabel *subtitle = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    subtitle.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Detail_Updated_Format"),
                     PPDeliveryCompanyFormattedDate(self.request.updatedAt ?: self.request.createdAt)];
    [surface addSubview:subtitle];
    
    [NSLayoutConstraint activateConstraints:@[
        [statusDot.topAnchor constraintEqualToAnchor:surface.topAnchor constant:24.0],
        [statusDot.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [statusDot.widthAnchor constraintEqualToConstant:10.0],
        [statusDot.heightAnchor constraintEqualToConstant:10.0],
        [eyebrow.centerYAnchor constraintEqualToAnchor:statusDot.centerYAnchor],
        [eyebrow.leadingAnchor constraintEqualToAnchor:statusDot.trailingAnchor constant:9.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:14.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-22.0],
    ]];
    return surface;
}

- (UIView *)routeSection {
    UIView *surface = [self surface];
    UILabel *title = [self sectionTitle:kLang(@"DeliveryCompany_Detail_Route")];
    [surface addSubview:title];
    UIView *pickup = [self routeRowWithIcon:@"shippingbox.fill"
                                      title:kLang(@"DeliveryCompany_Pickup")
                                       text:self.request.pickupSummary
                                      color:UIColor.systemOrangeColor];
    UIView *dropoff = [self routeRowWithIcon:@"mappin.and.ellipse"
                                       title:kLang(@"DeliveryCompany_Dropoff")
                                        text:self.request.dropoffSummary
                                       color:UIColor.systemGreenColor];
    [surface addSubview:pickup];
    [surface addSubview:dropoff];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [pickup.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14.0],
        [pickup.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [pickup.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [dropoff.topAnchor constraintEqualToAnchor:pickup.bottomAnchor constant:10.0],
        [dropoff.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [dropoff.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [dropoff.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-20.0],
    ]];
    return surface;
}

- (UIView *)routeRowWithIcon:(NSString *)iconName title:(NSString *)title text:(NSString *)text color:(UIColor *)color {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.78];
    row.layer.cornerRadius = 20.0;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = color;
    [row addSubview:icon];
    UILabel *titleLabel = [self label:PPFontBold(12) color:PrimaryTextClr lines:1];
    titleLabel.text = title;
    [row addSubview:titleLabel];
    UILabel *textLabel = [self label:PPFontRegular(13) color:SeconderyTextClr lines:0];
    textLabel.text = text;
    [row addSubview:textLabel];
    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:row.topAnchor constant:15.0],
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:15.0],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-15.0],
        [textLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [textLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-15.0],
    ]];
    return row;
}

- (UIView *)assignmentSection {
    UIView *surface = [self surface];
    UILabel *title = [self sectionTitle:kLang(@"DeliveryCompany_Detail_Assignment")];
    [surface addSubview:title];
    NSString *driver = self.request.assignedDriverName.length ? self.request.assignedDriverName : kLang(@"DeliveryCompany_Unassigned");
    UILabel *driverLabel = [self label:PPFontBold(18) color:PrimaryTextClr lines:2];
    driverLabel.text = driver;
    [surface addSubview:driverLabel];
    UILabel *role = [self label:PPFontRegular(13) color:SeconderyTextClr lines:2];
    role.text = self.request.assignedDriverUID.length ? kLang(@"DeliveryCompany_Detail_AssignedDriver") : kLang(@"DeliveryCompany_Detail_AssignmentPending");
    [surface addSubview:role];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    [surface addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [icon.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:16.0],
        [icon.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [icon.widthAnchor constraintEqualToConstant:38.0],
        [icon.heightAnchor constraintEqualToConstant:38.0],
        [driverLabel.topAnchor constraintEqualToAnchor:icon.topAnchor],
        [driverLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12.0],
        [driverLabel.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [role.topAnchor constraintEqualToAnchor:driverLabel.bottomAnchor constant:2.0],
        [role.leadingAnchor constraintEqualToAnchor:driverLabel.leadingAnchor],
        [role.trailingAnchor constraintEqualToAnchor:driverLabel.trailingAnchor],
        [role.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-20.0],
    ]];
    return surface;
}

- (UIView *)informationSection {
    UIView *surface = [self surface];
    UILabel *title = [self sectionTitle:kLang(@"DeliveryCompany_Detail_Information")];
    [surface addSubview:title];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    [surface addSubview:stack];
    [stack addArrangedSubview:[self infoRow:kLang(@"DeliveryCompany_Detail_RequestID") value:self.request.requestID]];
    [stack addArrangedSubview:[self infoRow:kLang(@"DeliveryCompany_Detail_Fee") value:self.request.formattedFee]];
    [stack addArrangedSubview:[self infoRow:kLang(@"DeliveryCompany_Detail_Created") value:PPDeliveryCompanyFormattedDate(self.request.createdAt)]];
    [stack addArrangedSubview:[self infoRow:kLang(@"DeliveryCompany_Detail_Updated") value:PPDeliveryCompanyFormattedDate(self.request.updatedAt)]];
    if (self.request.deliveryNote.length) {
        [stack addArrangedSubview:[self infoRow:kLang(@"DeliveryCompany_Detail_Note") value:self.request.deliveryNote]];
    }
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [stack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12.0],
        [stack.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-15.0],
    ]];
    return surface;
}

- (UIView *)infoRow:(NSString *)title value:(NSString *)value {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *titleLabel = [self label:PPFontMedium(12) color:SeconderyTextClr lines:1];
    titleLabel.text = title;
    [row addSubview:titleLabel];
    UILabel *valueLabel = [self label:PPFontMedium(13) color:PrimaryTextClr lines:0];
    valueLabel.text = value.length ? value : kLang(@"DeliveryCompany_NotAvailable");
    [row addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:48.0],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:0.34],
        [valueLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:10.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:12.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10.0],
    ]];
    return row;
}

- (UIView *)timelineSection {
    UIView *surface = [self surface];
    UILabel *title = [self sectionTitle:kLang(@"DeliveryCompany_Detail_Timeline")];
    [surface addSubview:title];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [surface addSubview:stack];
    if (!self.request.events.count) {
        UILabel *empty = [self label:PPFontRegular(13) color:SeconderyTextClr lines:0];
        empty.text = kLang(@"DeliveryCompany_Detail_NoEvents");
        [stack addArrangedSubview:empty];
    } else {
        for (PPDeliveryCompanyEvent *event in self.request.events) {
            [stack addArrangedSubview:[self eventView:event]];
        }
    }
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [stack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:15.0],
        [stack.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-20.0],
    ]];
    return surface;
}

- (UIView *)eventView:(PPDeliveryCompanyEvent *)event {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = PPDeliveryCompanyStatusColor(event.toStatus.length ? event.toStatus : event.eventType);
    dot.layer.cornerRadius = 5.0;
    [row addSubview:dot];
    UILabel *title = [self label:PPFontBold(13) color:PrimaryTextClr lines:2];
    NSString *status = event.toStatus.length ? PPDeliveryCompanyStatusDisplayName(event.toStatus) : PPDeliveryCompanyStatusDisplayName(event.eventType);
    title.text = status.length ? status : event.eventType;
    [row addSubview:title];
    UILabel *meta = [self label:PPFontRegular(11) color:SeconderyTextClr lines:2];
    NSString *actor = event.actorName.length ? event.actorName : PPDeliveryCompanyRoleDisplayName(event.actorRole);
    meta.text = actor.length
    ? [NSString stringWithFormat:kLang(@"DeliveryCompany_Event_Meta_Format"), actor, PPDeliveryCompanyFormattedDate(event.createdAt)]
    : PPDeliveryCompanyFormattedDate(event.createdAt);
    [row addSubview:meta];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:52.0],
        [dot.topAnchor constraintEqualToAnchor:row.topAnchor constant:7.0],
        [dot.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [dot.widthAnchor constraintEqualToConstant:10.0],
        [dot.heightAnchor constraintEqualToConstant:10.0],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor],
        [title.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:12.0],
        [title.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [meta.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4.0],
        [meta.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [meta.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [meta.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor],
    ]];
    return row;
}

- (UIView *)actionsSection {
    NSMutableArray<NSDictionary *> *actions = [NSMutableArray array];
    NSString *status = self.request.status;
    if (self.profile.canDispatch) {
        if ([status isEqualToString:PPDeliveryCompanyStatusOffered]) {
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Accept"), @"id": @(PPDCDetailActionAccept), @"primary": @YES}];
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Reject"), @"id": @(PPDCDetailActionReject), @"destructive": @YES}];
        } else if ([status isEqualToString:PPDeliveryCompanyStatusAccepted]) {
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Assign"), @"id": @(PPDCDetailActionAssign), @"primary": @YES}];
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Cancel"), @"id": @(PPDCDetailActionCancel), @"destructive": @YES}];
        } else if ([status isEqualToString:PPDeliveryCompanyStatusAssigned]) {
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Reassign"), @"id": @(PPDCDetailActionReassign), @"primary": @YES}];
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Cancel"), @"id": @(PPDCDetailActionCancel), @"destructive": @YES}];
        } else if ([status isEqualToString:PPDeliveryCompanyStatusDelivered]) {
            [actions addObject:@{@"title": kLang(@"DeliveryCompany_Action_Complete"), @"id": @(PPDCDetailActionComplete), @"primary": @YES}];
        }
    } else if (self.profile.isDriver && self.request.nextDriverStatus.length) {
        [actions addObject:@{
            @"title": [self driverActionTitleForStatus:self.request.nextDriverStatus],
            @"id": @(PPDCDetailActionDriverProgress),
            @"primary": @YES
        }];
    }
    if (!actions.count) return nil;
    
    UIView *surface = [self surface];
    UILabel *title = [self sectionTitle:kLang(@"DeliveryCompany_Detail_Actions")];
    [surface addSubview:title];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    [surface addSubview:stack];
    for (NSDictionary *action in actions) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = [action[@"id"] integerValue];
        button.layer.cornerRadius = 18.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.titleLabel.font = PPFontBold(16);
        [button setTitle:action[@"title"] forState:UIControlStateNormal];
        BOOL destructive = [action[@"destructive"] boolValue];
        BOOL primary = [action[@"primary"] boolValue];
        button.backgroundColor = primary ? AppPrimaryClr : (destructive ? [UIColor.systemRedColor colorWithAlphaComponent:0.10] : AppBackgroundClr);
        [button setTitleColor:primary ? UIColor.whiteColor : (destructive ? UIColor.systemRedColor : PrimaryTextClr) forState:UIControlStateNormal];
        if (primary) {
            button.layer.shadowColor = [AppPrimaryClr colorWithAlphaComponent:0.22].CGColor;
            button.layer.shadowOpacity = 1.0;
            button.layer.shadowRadius = 16.0;
            button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        }
        [button addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:54.0].active = YES;
        [stack addArrangedSubview:button];
        [self.actionButtons addObject:button];
    }
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [title.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [stack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14.0],
        [stack.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-20.0],
    ]];
    return surface;
}

- (NSString *)driverActionTitleForStatus:(NSString *)status {
    if ([status isEqualToString:PPDeliveryCompanyStatusPickedUp]) return kLang(@"DeliveryCompany_Action_PickedUp");
    if ([status isEqualToString:PPDeliveryCompanyStatusInTransit]) return kLang(@"DeliveryCompany_Action_InTransit");
    if ([status isEqualToString:PPDeliveryCompanyStatusDelivered]) return kLang(@"DeliveryCompany_Action_Delivered");
    return kLang(@"DeliveryCompany_Action_Update");
}

- (void)actionTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    if (self.actionInFlight) return;
    switch (sender.tag) {
        case PPDCDetailActionAccept:
        {
            [self confirmTitle:kLang(@"DeliveryCompany_Confirm_Accept_Title")
                       message:kLang(@"DeliveryCompany_Confirm_Accept_Message")
                   destructive:NO
                        action:^{ [self performAccept]; }];
            break;
        }
        case PPDCDetailActionReject:{
            [self promptReasonWithTitle:kLang(@"DeliveryCompany_Confirm_Reject_Title") action:^(NSString *reason) { [self performReject:reason]; }];
            break;
        }
        case PPDCDetailActionAssign:{
            [self chooseDriverForReassignment:NO source:sender];
            break;}
        case PPDCDetailActionReassign:{
            [self chooseDriverForReassignment:YES source:sender];
            break;}
        case PPDCDetailActionComplete:{
            [self confirmTitle:kLang(@"DeliveryCompany_Confirm_Complete_Title")
                       message:kLang(@"DeliveryCompany_Confirm_Complete_Message")
                   destructive:NO
                        action:^{ [self performComplete]; }];
            break;}
        case PPDCDetailActionCancel:{
            [self promptReasonWithTitle:kLang(@"DeliveryCompany_Confirm_Cancel_Title") action:^(NSString *reason) { [self performCancel:reason]; }];
            break;}
        case PPDCDetailActionDriverProgress:{
            [self performDriverProgress];
            break;}
    }
}

- (void)confirmTitle:(NSString *)title message:(NSString *)message destructive:(BOOL)destructive action:(dispatch_block_t)action {
    [PPAlertHelper showConfirmationIn:self
                                title:title
                             subtitle:message
                          placeholder:nil
                        confirmButton:kLang(@"Confirm")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:action
                          cancelBlock:nil];
}

- (void)promptReasonWithTitle:(NSString *)title action:(void (^)(NSString *reason))action {
    [PPAlertHelper showTextPromptIn:self
                              title:title
                           subtitle:kLang(@"DeliveryCompany_Reason_Subtitle")
                        placeholder:kLang(@"DeliveryCompany_Reason_Placeholder")
                        initialText:nil
                        confirmText:kLang(@"Confirm")
                         cancelText:kLang(@"Cancel")
                         completion:^(NSString * _Nullable text) {
        if (action) action(text ?: @"");
    }];
}

- (void)chooseDriverForReassignment:(BOOL)reassign source:(UIView *)source {
    [self setActionLoading:YES];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared listMembersForCompanyID:self.profile.companyID completion:^(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self setActionLoading:NO];
        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"DeliveryCompany_Error_Title") subtitle:error.localizedDescription];
            return;
        }
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPDeliveryCompanyMember *member, NSDictionary *bindings) {
            return member.isActiveDriver && ![member.uid isEqualToString:self.request.assignedDriverUID];
        }];
        NSArray *drivers = [members filteredArrayUsingPredicate:predicate];
        if (!drivers.count) {
            [PPAlertHelper showInfoIn:self title:kLang(@"DeliveryCompany_NoDrivers_Title") subtitle:kLang(@"DeliveryCompany_NoDrivers_Subtitle")];
            return;
        }
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:reassign ? kLang(@"DeliveryCompany_Action_Reassign") : kLang(@"DeliveryCompany_Action_Assign")
                                                                       message:kLang(@"DeliveryCompany_SelectDriver")
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        for (PPDeliveryCompanyMember *driver in drivers) {
            NSString *title = [NSString stringWithFormat:kLang(@"DeliveryCompany_DriverChoice_Format"), driver.displayName.length ? driver.displayName : driver.uid, (long)driver.activeDeliveryCount];
            [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                [self performDriverAssignment:driver reassign:reassign];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        sheet.popoverPresentationController.sourceView = source;
        sheet.popoverPresentationController.sourceRect = source.bounds;
        [self presentViewController:sheet animated:YES completion:nil];
    }];
}

- (void)performAccept {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        [PPDeliveryCompanyService.shared acceptRequestID:self.requestID completion:completion];
    }];
}
- (void)performReject:(NSString *)reason {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        [PPDeliveryCompanyService.shared rejectRequestID:self.requestID reason:reason completion:completion];
    }];
}
- (void)performDriverAssignment:(PPDeliveryCompanyMember *)driver reassign:(BOOL)reassign {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        if (reassign) [PPDeliveryCompanyService.shared reassignRequestID:self.requestID driverUID:driver.uid completion:completion];
        else [PPDeliveryCompanyService.shared assignRequestID:self.requestID driverUID:driver.uid completion:completion];
    }];
}
- (void)performComplete {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        [PPDeliveryCompanyService.shared completeRequestID:self.requestID completion:completion];
    }];
}
- (void)performCancel:(NSString *)reason {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        [PPDeliveryCompanyService.shared cancelRequestID:self.requestID reason:reason completion:completion];
    }];
}

- (void)performDriverProgress {
    NSString *nextStatus = self.request.nextDriverStatus;
    if (!nextStatus.length) return;
    if ([nextStatus isEqualToString:PPDeliveryCompanyStatusDelivered]) {
        [PPAlertHelper showTextPromptIn:self
                                  title:kLang(@"DeliveryCompany_Confirm_Delivered_Title")
                               subtitle:kLang(@"DeliveryCompany_Confirm_Delivered_Message")
                            placeholder:kLang(@"DeliveryCompany_ReceiverName_Placeholder")
                            initialText:nil
                            confirmText:kLang(@"Confirm")
                             cancelText:kLang(@"Cancel")
                             completion:^(NSString * _Nullable text) {
            [self performStatusUpdate:nextStatus receiverName:text];
        }];
        return;
    }
    [self confirmTitle:[self driverActionTitleForStatus:nextStatus]
               message:kLang(@"DeliveryCompany_Confirm_Status_Message")
           destructive:NO
                action:^{ [self performStatusUpdate:nextStatus receiverName:nil]; }];
}

- (void)performStatusUpdate:(NSString *)status receiverName:(NSString *)receiverName {
    [self performServiceAction:^(PPDeliveryCompanyActionCompletion completion) {
        [PPDeliveryCompanyService.shared updateRequestID:self.requestID toStatus:status receiverName:receiverName completion:completion];
    }];
}

- (void)performServiceAction:(void (^)(PPDeliveryCompanyActionCompletion completion))operation {
    if (!operation) return;
    [self setActionLoading:YES];
    __weak typeof(self) weakSelf = self;
    operation(^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self setActionLoading:NO];
        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"DeliveryCompany_Error_Title") subtitle:error.localizedDescription];
            return;
        }
        [PPFunc pp_playSuccessEffect];
        [PPToast toast:kLang(@"DeliveryCompany_Action_Success") style:PPToastStyleSuccess haptic:NO duration:1.8];
        if ([result[@"dismissedForCompany"] boolValue]) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        [self loadRequest];
    });
}

- (void)setActionLoading:(BOOL)loading {
    self.actionInFlight = loading;
    for (UIButton *button in self.actionButtons) {
        button.enabled = !loading;
        button.alpha = loading ? 0.55 : 1.0;
    }
}

- (UIView *)surface {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = AppForgroundColr;
    surface.layer.cornerRadius = 30.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    surface.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.06].CGColor;
    surface.layer.shadowOpacity = 1.0;
    surface.layer.shadowRadius = 22.0;
    surface.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    return surface;
}

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *label = [self label:PPFontBold(17) color:PrimaryTextClr lines:2];
    label.text = text;
    return label;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)runEntranceIfNeeded {
    if (self.didAnimateEntrance || self.scrollView.hidden || UIAccessibilityIsReduceMotionEnabled()) return;
    self.didAnimateEntrance = YES;
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0, 12.0);
    [UIView animateWithDuration:0.46 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
