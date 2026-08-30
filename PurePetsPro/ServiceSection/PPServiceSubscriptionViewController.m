//
//  PPServiceSubscriptionViewController.m
//  PurePetsPro
//
//  Provider-facing read-only subscription status + upgrade CTA.
//  No admin-level plan editing — provider can view plan, status, dates
//  and request an upgrade.
//

#import "PPServiceSubscriptionViewController.h"
#import "PPServiceModel.h"
#import "PPFirebaseCompat.h"

@interface PPServiceSubscriptionViewController ()
@property (nonatomic, strong) PPServiceModel *service;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView  *contentStack;
@end

@implementation PPServiceSubscriptionViewController

- (instancetype)initWithService:(PPServiceModel *)service {
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    [self setupScrollView];
    [self setupPlanHeader];
    [self setupInfoRows];
    [self setupUpgradeCTA];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Serv_Sub_MyPlan") showBack:YES];
}

#pragma mark - Scroll View

- (void)setupScrollView {
    _scrollView = [UIScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _contentStack = [UIStackView new];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 16;
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-32],
        [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32],
    ]];
}

#pragma mark - Plan Header Card

- (void)setupPlanHeader {
    NSString *planName = [self localizedPlanName:self.service.subscriptionPlan ?: @"free"];
    BOOL isActive = self.service.subscriptionActive;
    UIColor *accentColor = isActive ? [UIColor ppSuccess] : [UIColor ppWarning];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 24;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.shadowColor = AppShadowColor.CGColor;
    card.layer.shadowOpacity = 0.06;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = 8;

    // Plan icon
    UIView *iconBg = [UIView new];
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    iconBg.backgroundColor = [accentColor colorWithAlphaComponent:0.15];
    iconBg.layer.cornerRadius = 28;
    [card addSubview:iconBg];

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"crown.fill"
                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]];
    icon.tintColor = accentColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBg addSubview:icon];

    UILabel *planLabel = [UILabel new];
    planLabel.translatesAutoresizingMaskIntoConstraints = NO;
    planLabel.text = planName;
    planLabel.font = [Styling fontBold:22];
    planLabel.textColor = PrimaryTextClr;
    planLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:planLabel];

    UILabel *statusLabel = [UILabel new];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.text = isActive ? kLang(@"Serv_Sub_Active") : kLang(@"Serv_Sub_Inactive");
    statusLabel.font = [Styling fontMedium:13];
    statusLabel.textColor = accentColor;
    statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconBg.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [iconBg.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconBg.widthAnchor constraintEqualToConstant:56],
        [iconBg.heightAnchor constraintEqualToConstant:56],
        [icon.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        [planLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [planLabel.leadingAnchor constraintEqualToAnchor:iconBg.trailingAnchor constant:16],
        [planLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [statusLabel.topAnchor constraintEqualToAnchor:planLabel.bottomAnchor constant:4],
        [statusLabel.leadingAnchor constraintEqualToAnchor:planLabel.leadingAnchor],
        [statusLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
    ]];

    [_contentStack addArrangedSubview:card];
}

#pragma mark - Info Rows

- (void)setupInfoRows {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterNoStyle;

    NSString *startStr = self.service.subscriptionStartDate ? [df stringFromDate:self.service.subscriptionStartDate] : @"—";
    NSString *endStr   = self.service.subscriptionEndDate   ? [df stringFromDate:self.service.subscriptionEndDate]   : @"—";

    NSArray *rows = @[
        @{@"label": kLang(@"Serv_Sub_Plan"),      @"value": [self localizedPlanName:self.service.subscriptionPlan ?: @"free"], @"icon": @"star.fill"},
        @{@"label": kLang(@"Serv_Sub_StartDate"),  @"value": startStr, @"icon": @"calendar"},
        @{@"label": kLang(@"Serv_Sub_EndDate"),    @"value": endStr,   @"icon": @"calendar.badge.clock"},
    ];

    for (NSDictionary *row in rows) {
        UIView *card = [self buildInfoRow:row[@"label"] value:row[@"value"] iconName:row[@"icon"]];
        [_contentStack addArrangedSubview:card];
    }
}

- (UIView *)buildInfoRow:(NSString *)label value:(NSString *)value iconName:(NSString *)iconName {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    UIView *iconBg = [UIView new];
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    iconBg.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    iconBg.layer.cornerRadius = 16;
    [card addSubview:iconBg];

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]];
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBg addSubview:icon];

    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = label;
    lbl.font = [Styling fontMedium:11];
    lbl.textColor = SeconderyTextClr;
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:lbl];

    UILabel *val = [UILabel new];
    val.translatesAutoresizingMaskIntoConstraints = NO;
    val.text = value;
    val.font = [Styling fontBold:14];
    val.textColor = PrimaryTextClr;
    val.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:val];

    [NSLayoutConstraint activateConstraints:@[
        [iconBg.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconBg.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconBg.widthAnchor constraintEqualToConstant:32],
        [iconBg.heightAnchor constraintEqualToConstant:32],
        [icon.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        [lbl.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [lbl.leadingAnchor constraintEqualToAnchor:iconBg.trailingAnchor constant:12],
        [lbl.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [val.topAnchor constraintEqualToAnchor:lbl.bottomAnchor constant:2],
        [val.leadingAnchor constraintEqualToAnchor:lbl.leadingAnchor],
        [val.trailingAnchor constraintEqualToAnchor:lbl.trailingAnchor],
        [val.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];

    return card;
}

#pragma mark - Upgrade CTA

- (void)setupUpgradeCTA {
    NSString *currentPlan = [self.service.subscriptionPlan lowercaseString] ?: @"free";
    if ([currentPlan isEqualToString:@"premium"]) return; // Already on highest plan

    UIButton *upgradeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    upgradeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [upgradeBtn setImage:[UIImage systemImageNamed:@"arrow.up.circle.fill" withConfiguration:cfg] forState:UIControlStateNormal];
    [upgradeBtn setTitle:[NSString stringWithFormat:@"  %@", kLang(@"Serv_Sub_Upgrade")] forState:UIControlStateNormal];
    [upgradeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    upgradeBtn.tintColor = UIColor.whiteColor;
    upgradeBtn.titleLabel.font = [Styling fontBold:15];
    upgradeBtn.backgroundColor = AppPrimaryClr;
    upgradeBtn.layer.cornerRadius = 26;
    upgradeBtn.layer.cornerCurve = kCACornerCurveContinuous;
    upgradeBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 32, 0, 32);
    [upgradeBtn addTarget:self action:@selector(upgradeTapped) forControlEvents:UIControlEventTouchUpInside];
    [upgradeBtn.heightAnchor constraintEqualToConstant:52].active = YES;

    // Spacer + button
    UIView *spacer = [UIView new];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer.heightAnchor constraintEqualToConstant:8].active = YES;
    [_contentStack addArrangedSubview:spacer];
    [_contentStack addArrangedSubview:upgradeBtn];
}

#pragma mark - Actions

- (void)upgradeTapped {
    [PPFunc pp_playTapEffect];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Serv_Sub_Upgrade_Title")
                                                                  message:kLang(@"Serv_Sub_Upgrade_Msg")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Helpers

- (NSString *)localizedPlanName:(NSString *)plan {
    NSString *p = [plan lowercaseString] ?: @"free";
    if ([p isEqualToString:@"basic"])   return kLang(@"Vet_Sub_Basic");
    if ([p isEqualToString:@"premium"]) return kLang(@"Vet_Sub_Premium");
    return kLang(@"Vet_Sub_Free");
}

@end
