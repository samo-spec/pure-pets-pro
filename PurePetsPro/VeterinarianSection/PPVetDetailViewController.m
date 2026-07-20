//
//  PPVetDetailViewController.m
//  PurePetsAdmin
//

#import "PPVetDetailViewController.h"
#import "PPVetModel.h"
#import "PPVetManager.h"
#import "PPAddEditVetViewController.h"
#import "PPVetSubscriptionViewController.h"
#import "PPFirebaseCompat.h"

@interface PPVetDetailInfoCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
- (void)configureWithTitle:(NSString *)title value:(NSString *)value borderColor:(UIColor *)borderColor;
@end

@implementation PPVetDetailInfoCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = UIColor.clearColor;

        _cardView = [[UIView alloc] init];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.layer.cornerRadius = 18.0;
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
        _cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        [self.contentView addSubview:_cardView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontMedium:13.0];
        _titleLabel.textColor = SeconderyTextClr;
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cardView addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [Styling fontBold:14.5];
        _valueLabel.textColor = PrimaryTextClr;
        _valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _valueLabel.numberOfLines = 0;
        [_cardView addSubview:_valueLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

            [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:18.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-18.0],

            [_valueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
            [_valueLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_valueLabel.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-14.0],
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title value:(NSString *)value borderColor:(UIColor *)borderColor {
    self.titleLabel.text = title;
    self.valueLabel.text = value;
    self.cardView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.94];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    }];
    self.cardView.layer.borderColor = borderColor.CGColor;
}

@end

@interface PPVetDetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PPVetModel *vet;
@property (nonatomic, strong) UIImageView *headerImageView;
@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *rows;
@property (nonatomic, strong) UIView *actionBar;
@end

@implementation PPVetDetailViewController

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.94];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
}

- (UserModel *)pp_currentUser {
    return UsrMgr.currentUser;
}

- (BOOL)pp_canEditProfile {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canEditVetInfoPermission;
}

- (BOOL)pp_canManageWorkspace {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canManageVetPermission;
}

- (instancetype)initWithVet:(PPVetModel *)vet {
    self = [super init];
    if (self) {
        _vet = vet;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];

    [self buildRows];
    [self setupHeaderImage];
    [self setupTableView];
    [self setupActionBar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIButton *editBtn = [self pp_canEditProfile] ? [self pp_ButtonWithSystemName:@"pencil" action:@selector(editTapped)] : nil;
    [self pp_navBarWithOtherButton:editBtn title:self.vet.title ?: kLang(@"Vet_Detail_Title")];
}

#pragma mark - Data

- (void)buildRows {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterNoStyle;

    NSMutableArray *r = [NSMutableArray array];

    [r addObject:@{@"label": kLang(@"Vet_Field_Name"),          @"value": self.vet.title ?: @"—"}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Type"),          @"value": [self.vet localizedTypeName]}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Phone"),         @"value": self.vet.phone ?: @"—"}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Whatsapp"),      @"value": self.vet.whatsapp ?: @"—"}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Description"),   @"value": self.vet.descriptionText ?: @"—"}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Cost"),          @"value": [NSString stringWithFormat:@"%.2f %@", self.vet.vetCost, kLang(@"QAR")]}];
    [r addObject:@{@"label": kLang(@"Vet_Field_AvailableDate"), @"value": self.vet.availableDate ? [df stringFromDate:self.vet.availableDate] : @"—"}];
    [r addObject:@{@"label": kLang(@"Vet_Field_Status"),        @"value": self.vet.isDisabled ? kLang(@"Vet_Status_Disabled") : kLang(@"Vet_Status_Active")}];
    [r addObject:@{@"label": kLang(@"Vet_Subscription"),        @"value": [self.vet localizedSubscriptionTierName]}];

    if (self.vet.subscriptionEndDate) {
        NSString *expiry = [df stringFromDate:self.vet.subscriptionEndDate];
        BOOL expired = [self.vet isSubscriptionExpired];
        NSString *expiryLabel = expired ? [NSString stringWithFormat:@"%@ (%@)", expiry, kLang(@"Vet_Sub_Expired")] : expiry;
        [r addObject:@{@"label": kLang(@"Vet_Sub_EndDate"), @"value": expiryLabel}];
    }

    if (self.vet.createdAt) {
        [r addObject:@{@"label": kLang(@"Vet_Field_CreatedAt"), @"value": [df stringFromDate:self.vet.createdAt]}];
    }

    self.rows = [r copy];
}

#pragma mark - UI

- (void)setupHeaderImage {
    CGFloat headerH = 322.0;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, headerH)];
    header.backgroundColor = UIColor.clearColor;
    self.tableHeaderView = header;

    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.userInteractionEnabled = NO;
    glow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    glow.layer.cornerRadius = 92.0;
    glow.layer.shadowColor = AppPrimaryClr.CGColor;
    glow.layer.shadowOpacity = 0.10;
    glow.layer.shadowRadius = 58.0;
    [header addSubview:glow];

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [self pp_surfaceColor];
    surface.layer.cornerRadius = 34.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [self pp_borderColor].CGColor;
    surface.layer.shadowColor = AppShadowColor.CGColor;
    surface.layer.shadowOpacity = 0.08;
    surface.layer.shadowRadius = 24.0;
    surface.layer.shadowOffset = CGSizeMake(0, 14.0);
    [header addSubview:surface];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    accentBar.layer.cornerRadius = 3.0;
    [surface addSubview:accentBar];

    _headerImageView = [[UIImageView alloc] init];
    _headerImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _headerImageView.contentMode = UIViewContentModeScaleAspectFill;
    _headerImageView.clipsToBounds = YES;
    _headerImageView.layer.cornerRadius = 38.0;
    _headerImageView.layer.cornerCurve = kCACornerCurveContinuous;
    _headerImageView.layer.borderWidth = 2.0;
    _headerImageView.layer.borderColor = UIColor.whiteColor.CGColor;
    _headerImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    [surface addSubview:_headerImageView];

    if (self.vet.logoURL.length > 0) {
        [_headerImageView setImageFromUrl:self.vet.logoURL
                         placeholderImage:@"veterinary"
                                      Blr:YES
                               Shimmering:YES
                               completion:nil];
    } else {
        _headerImageView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        _headerImageView.tintColor = AppPrimaryClr;
        _headerImageView.contentMode = UIViewContentModeCenter;
    }

    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [Styling fontBold:11.0];
    eyebrow.textColor = AppPrimaryClr;
    eyebrow.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrow.text = [kLang(@"Vet_Detail_Title") uppercaseString];
    [surface addSubview:eyebrow];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [Styling fontBold:26.0];
    title.textColor = PrimaryTextClr;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.numberOfLines = 2;
    title.text = self.vet.title.length ? self.vet.title : kLang(@"Vet_Detail_Title");
    [surface addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [Styling fontMedium:13.0];
    subtitle.textColor = [SeconderyTextClr colorWithAlphaComponent:0.82];
    subtitle.textAlignment = Language.alignmentForCurrentLanguage;
    subtitle.numberOfLines = 2;
    NSMutableArray *parts = [NSMutableArray array];
    NSString *typeName = [self.vet localizedTypeName];
    if (typeName.length) [parts addObject:typeName];
    if (self.vet.phone.length) [parts addObject:self.vet.phone];
    subtitle.text = [parts componentsJoinedByString:@"  ·  "];
    [surface addSubview:subtitle];

    UILabel *status = [[UILabel alloc] init];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.font = [Styling fontBold:11.0];
    BOOL disabled = self.vet.isDisabled;
    UIColor *statusColor = disabled ? UIColor.systemRedColor : AppPrimaryClr;
    status.textColor = statusColor;
    status.textAlignment = NSTextAlignmentCenter;
    status.text = [NSString stringWithFormat:@"  %@  ", disabled ? kLang(@"Vet_Status_Disabled") : kLang(@"Vet_Status_Active")];
    status.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    status.layer.cornerRadius = 13.0;
    status.layer.cornerCurve = kCACornerCurveContinuous;
    status.clipsToBounds = YES;
    [surface addSubview:status];

    UILabel *cost = [[UILabel alloc] init];
    cost.translatesAutoresizingMaskIntoConstraints = NO;
    cost.font = [Styling fontBold:18.0];
    cost.textColor = PrimaryTextClr;
    cost.textAlignment = Language.alignmentForCurrentLanguage;
    cost.text = self.vet.vetCost > 0 ? [NSString stringWithFormat:@"%.0f %@", self.vet.vetCost, kLang(@"QAR")] : [self.vet localizedSubscriptionTierName];
    [surface addSubview:cost];

    [NSLayoutConstraint activateConstraints:@[
        [glow.widthAnchor constraintEqualToConstant:184.0],
        [glow.heightAnchor constraintEqualToConstant:184.0],
        [glow.topAnchor constraintEqualToAnchor:header.topAnchor constant:-40.0],
        [glow.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:60.0],

        [surface.topAnchor constraintEqualToAnchor:header.topAnchor constant:14.0],
        [surface.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18.0],
        [surface.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [surface.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-18.0],

        [accentBar.topAnchor constraintEqualToAnchor:surface.topAnchor constant:20.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [accentBar.widthAnchor constraintEqualToConstant:70.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [_headerImageView.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:18.0],
        [_headerImageView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [_headerImageView.widthAnchor constraintEqualToConstant:112.0],
        [_headerImageView.heightAnchor constraintEqualToConstant:112.0],

        [eyebrow.topAnchor constraintEqualToAnchor:_headerImageView.topAnchor constant:4.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:_headerImageView.trailingAnchor constant:18.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],

        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:7.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [status.topAnchor constraintEqualToAnchor:_headerImageView.bottomAnchor constant:22.0],
        [status.leadingAnchor constraintEqualToAnchor:_headerImageView.leadingAnchor],
        [status.heightAnchor constraintEqualToConstant:26.0],
        [status.widthAnchor constraintGreaterThanOrEqualToConstant:84.0],

        [cost.centerYAnchor constraintEqualToAnchor:status.centerYAnchor],
        [cost.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [cost.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 74;
    _tableView.tableHeaderView = self.tableHeaderView;
    _tableView.showsVerticalScrollIndicator = NO;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-84],
    ]];
}

- (void)setupActionBar {
    CGFloat barH = 76;
    _actionBar = [[UIView alloc] init];
    _actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    _actionBar.backgroundColor = UIColor.clearColor;

    [self.view addSubview:_actionBar];
    [NSLayoutConstraint activateConstraints:@[
        [_actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [_actionBar.heightAnchor constraintEqualToConstant:barH],
    ]];

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [self pp_surfaceColor];
    surface.layer.cornerRadius = 28.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [self pp_borderColor].CGColor;
    surface.layer.shadowColor = AppShadowColor.CGColor;
    surface.layer.shadowOpacity = 0.10;
    surface.layer.shadowRadius = 20.0;
    surface.layer.shadowOffset = CGSizeMake(0, 10.0);
    [_actionBar addSubview:surface];

    // Action buttons
    NSArray *icons    = @[@"phone.fill", @"message.fill", @"square.and.pencil", @"creditcard.circle"];
    NSArray *actions  = @[@"callTapped", @"whatsappTapped", @"editTapped", @"subscriptionTapped"];
    NSArray *colors   = @[UIColor.systemGreenColor, UIColor.systemTealColor, UIColor.systemBlueColor, AppPrimaryClr];

    CGFloat btnSize = 44;
    CGFloat spacing = 24;
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = spacing;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSUInteger i = 0; i < icons.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setImage:[UIImage systemImageNamed:icons[i]] forState:UIControlStateNormal];
        btn.tintColor = UIColor.whiteColor;
        btn.backgroundColor = colors[i];
        btn.layer.cornerRadius = btnSize / 2.0;
        btn.clipsToBounds = YES;
        [btn addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];
        [NSLayoutConstraint activateConstraints:@[
            [btn.widthAnchor constraintEqualToConstant:btnSize],
            [btn.heightAnchor constraintEqualToConstant:btnSize],
        ]];
        [stack addArrangedSubview:btn];
    }

    [surface addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [surface.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor constant:18.0],
        [surface.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor constant:-18.0],
        [surface.topAnchor constraintEqualToAnchor:_actionBar.topAnchor constant:8.0],
        [surface.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor constant:-8.0],
        [stack.centerXAnchor constraintEqualToAnchor:surface.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
    ]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPVetDetailInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:@"detail"];
    if (!cell) {
        cell = [[PPVetDetailInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"detail"];
    }
    NSDictionary *row = self.rows[indexPath.row];
    [cell configureWithTitle:row[@"label"] value:row[@"value"] borderColor:[self pp_borderColor]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 8.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.clearColor;
    return view;
}

#pragma mark - Actions

- (void)editTapped {
    if (![self pp_canEditProfile]) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
        return;
    }
    [PPFunc pp_playTapEffect];
    PPAddEditVetViewController *vc = [[PPAddEditVetViewController alloc] initWithVet:self.vet];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)subscriptionTapped {
    if (![self pp_canManageWorkspace]) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
        return;
    }
    [PPFunc pp_playTapEffect];
    PPVetSubscriptionViewController *vc = [[PPVetSubscriptionViewController alloc] initWithVet:self.vet];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)callTapped {
    NSString *phone = [self.vet.phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (phone.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Vet_No_Phone")];
        return;
    }
    NSURL *url = [NSURL URLWithString:[@"tel://" stringByAppendingString:phone]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)whatsappTapped {
    NSString *wa = [self.vet.whatsapp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (wa.length == 0) wa = [self.vet.phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (wa.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Vet_No_Phone")];
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://wa.me/%@", wa]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
