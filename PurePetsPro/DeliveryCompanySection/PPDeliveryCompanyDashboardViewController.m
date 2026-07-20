#import "PPDeliveryCompanyDashboardViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPDeliveryCompanyDetailViewController.h"
#import "PPDeliveryCompanyMembersViewController.h"
#import "PPDeliveryCompanySetupViewController.h"

@interface PPDeliveryCompanyRequestCell : UITableViewCell
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) UIView *statusLine;
@property (nonatomic, strong) UILabel *routeEyebrowLabel;
@property (nonatomic, strong) UILabel *orderLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *pickupLabel;
@property (nonatomic, strong) UILabel *dropoffLabel;
@property (nonatomic, strong) UILabel *driverLabel;
@property (nonatomic, strong) UILabel *feeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
- (void)configureWithRequest:(PPDeliveryCompanyRequest *)request;
@end

@implementation PPDeliveryCompanyRequestCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

        self.surface = [[UIView alloc] init];
        self.surface.translatesAutoresizingMaskIntoConstraints = NO;
        self.surface.backgroundColor = AppForgroundColr;
        self.surface.layer.cornerRadius = 28.0;
        self.surface.layer.cornerCurve = kCACornerCurveContinuous;
        self.surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
        self.surface.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.08].CGColor;
        self.surface.layer.shadowOpacity = 1.0;
        self.surface.layer.shadowRadius = 24.0;
        self.surface.layer.shadowOffset = CGSizeMake(0.0, 12.0);
        [self.contentView addSubview:self.surface];

        self.glowView = [[UIView alloc] init];
        self.glowView.translatesAutoresizingMaskIntoConstraints = NO;
        self.glowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.05];
        self.glowView.layer.cornerRadius = 54.0;
        self.glowView.layer.cornerCurve = kCACornerCurveContinuous;
        [self.surface addSubview:self.glowView];

        self.statusLine = [[UIView alloc] init];
        self.statusLine.translatesAutoresizingMaskIntoConstraints = NO;
        self.statusLine.layer.cornerRadius = 3.0;
        [self.surface addSubview:self.statusLine];

        self.routeEyebrowLabel = [self label:PPFontBold(10) color:[SeconderyTextClr colorWithAlphaComponent:0.84] lines:1];
        self.orderLabel = [self label:PPFontBold(18) color:PrimaryTextClr lines:1];
        self.statusLabel = [self label:PPFontBold(10) color:AppPrimaryClr lines:1];
        self.statusLabel.textAlignment = NSTextAlignmentCenter;
        self.statusLabel.layer.cornerRadius = 11.0;
        self.statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
        self.statusLabel.clipsToBounds = YES;
        self.pickupLabel = [self label:PPFontRegular(13) color:SeconderyTextClr lines:2];
        self.dropoffLabel = [self label:PPFontRegular(13) color:SeconderyTextClr lines:2];
        self.driverLabel = [self label:PPFontMedium(12) color:PrimaryTextClr lines:1];
        self.feeLabel = [self label:PPFontBold(12) color:AppPrimaryClr lines:1];
        self.dateLabel = [self label:PPFontRegular(11) color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:2];

        for (UIView *view in @[self.routeEyebrowLabel, self.orderLabel, self.statusLabel, self.pickupLabel, self.dropoffLabel, self.driverLabel, self.feeLabel, self.dateLabel]) {
            [self.surface addSubview:view];
        }

        [NSLayoutConstraint activateConstraints:@[
            [self.surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
            [self.surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [self.surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [self.surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],

            [self.glowView.widthAnchor constraintEqualToConstant:108.0],
            [self.glowView.heightAnchor constraintEqualToConstant:108.0],
            [self.glowView.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:-20.0],
            [self.glowView.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:18.0],

            [self.statusLine.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:22.0],
            [self.statusLine.leadingAnchor constraintEqualToAnchor:self.surface.leadingAnchor constant:16.0],
            [self.statusLine.bottomAnchor constraintEqualToAnchor:self.surface.bottomAnchor constant:-22.0],
            [self.statusLine.widthAnchor constraintEqualToConstant:5.0],

            [self.routeEyebrowLabel.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:18.0],
            [self.routeEyebrowLabel.leadingAnchor constraintEqualToAnchor:self.statusLine.trailingAnchor constant:14.0],
            [self.routeEyebrowLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],

            [self.orderLabel.topAnchor constraintEqualToAnchor:self.routeEyebrowLabel.bottomAnchor constant:6.0],
            [self.orderLabel.leadingAnchor constraintEqualToAnchor:self.statusLine.trailingAnchor constant:13.0],
            [self.orderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-10.0],

            [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.orderLabel.centerYAnchor],
            [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.statusLabel.heightAnchor constraintEqualToConstant:23.0],
            [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:82.0],

            [self.pickupLabel.topAnchor constraintEqualToAnchor:self.orderLabel.bottomAnchor constant:12.0],
            [self.pickupLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
            [self.pickupLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],

            [self.dropoffLabel.topAnchor constraintEqualToAnchor:self.pickupLabel.bottomAnchor constant:6.0],
            [self.dropoffLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
            [self.dropoffLabel.trailingAnchor constraintEqualToAnchor:self.pickupLabel.trailingAnchor],

            [self.driverLabel.topAnchor constraintEqualToAnchor:self.dropoffLabel.bottomAnchor constant:12.0],
            [self.driverLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
            [self.driverLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.feeLabel.leadingAnchor constant:-10.0],

            [self.feeLabel.centerYAnchor constraintEqualToAnchor:self.driverLabel.centerYAnchor],
            [self.feeLabel.trailingAnchor constraintEqualToAnchor:self.pickupLabel.trailingAnchor],

            [self.dateLabel.topAnchor constraintEqualToAnchor:self.driverLabel.bottomAnchor constant:8.0],
            [self.dateLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
            [self.dateLabel.trailingAnchor constraintEqualToAnchor:self.pickupLabel.trailingAnchor],
            [self.dateLabel.bottomAnchor constraintEqualToAnchor:self.surface.bottomAnchor constant:-17.0],
        ]];
    }
    return self;
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

- (void)configureWithRequest:(PPDeliveryCompanyRequest *)request {
    UIColor *statusColor = request.statusColor;
    self.statusLine.backgroundColor = statusColor;
    self.glowView.backgroundColor = [statusColor colorWithAlphaComponent:0.05];
    self.routeEyebrowLabel.text = kLang(@"DeliveryCompany_Dashboard_Eyebrow");
    self.statusLabel.text = request.statusDisplayName;
    self.statusLabel.textColor = statusColor;
    self.statusLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    self.orderLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Order_Format"), request.bestOrderNumber];
    self.pickupLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Pickup_Format"), request.pickupSummary];
    self.dropoffLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Dropoff_Format"), request.dropoffSummary];
    NSString *driver = request.assignedDriverName.length ? request.assignedDriverName : kLang(@"DeliveryCompany_Unassigned");
    self.driverLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Driver_Format"), driver];
    self.feeLabel.text = request.formattedFee;
    self.dateLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Dates_Format"),
                           PPDeliveryCompanyFormattedDate(request.createdAt),
                           PPDeliveryCompanyFormattedDate(request.updatedAt)];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@, %@",
                               self.orderLabel.text, self.statusLabel.text, self.pickupLabel.text, self.dropoffLabel.text];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:0.14 animations:^{
        self.surface.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self.surface.alpha = highlighted ? 0.88 : 1.0;
    }];
}

@end


@interface PPDeliveryCompanyDashboardViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PPHero *heroView;
@property (nonatomic, strong) UIView *heroTopGlowView;
@property (nonatomic, strong) UIView *heroBottomGlowView;
@property (nonatomic, strong) UIView *heroMetricSurface;
@property (nonatomic, strong) UILabel *companyLabel;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIControl *heroMembersControl;
@property (nonatomic, strong) UILabel *heroMembersTitleLabel;
@property (nonatomic, strong) UILabel *heroMembersSubtitleLabel;
@property (nonatomic, strong) UIScrollView *tabsScrollView;
@property (nonatomic, strong) UIStackView *tabsStack;
@property (nonatomic, copy) NSArray<NSNumber *> *filters;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *stateView;
@property (nonatomic, strong) UILabel *stateTitle;
@property (nonatomic, strong) UILabel *stateSubtitle;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIActivityIndicatorView *paginationSpinner;
@property (nonatomic, strong) PPDeliveryCompanyProfile *profile;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyRequest *> *requests;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyRequest *> *filteredRequests;
@property (nonatomic, copy, nullable) NSString *nextPageToken;
@property (nonatomic, assign) PPDeliveryCompanyDashboardFilter selectedFilter;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadingNextPage;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, strong) NSLayoutConstraint *heroMembersHeightConstraint;
@end

@implementation PPDeliveryCompanyDashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.requests = @[];
    self.filteredRequests = @[];
    self.tabButtons = [NSMutableArray array];
    [self buildUI];
    [self prepareEntrance];
    [self loadProfileAndRequests];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryCompany_NavTitle") showBack:YES];
    [self scrollTabsToLeadingEdgeIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
    [self scrollTabsToLeadingEdgeIfNeeded];
}

- (void)buildUI {
     self.heroView = [[PPHero alloc] init];
     self.heroView.translatesAutoresizingMaskIntoConstraints = NO;
     self.heroView.accentColor = AppPrimaryClr;
     [self.view addSubview:self.heroView];

     self.heroTopGlowView = [[UIView alloc] init];
     self.heroTopGlowView.translatesAutoresizingMaskIntoConstraints = NO;
     self.heroTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
     self.heroTopGlowView.layer.cornerRadius = 96.0;
     self.heroTopGlowView.layer.cornerCurve = kCACornerCurveContinuous;
     [self.heroView addSubview:self.heroTopGlowView];

     self.heroBottomGlowView = [[UIView alloc] init];
     self.heroBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
     self.heroBottomGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.04];
     self.heroBottomGlowView.layer.cornerRadius = 120.0;
     self.heroBottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
     [self.heroView addSubview:self.heroBottomGlowView];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
    iconSurface.layer.cornerRadius = 22.0;
    [self.heroView addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"truck.box.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    [iconSurface addSubview:icon];

    UILabel *eyebrow = [self label:PPFontBold(11) color:AppPrimaryClr lines:1];
    eyebrow.text = kLang(@"DeliveryCompany_Dashboard_Eyebrow");
    [self.heroView addSubview:eyebrow];

    self.companyLabel = [self label:PPFontBold(40) color:PrimaryTextClr lines:3];
    [self.heroView addSubview:self.companyLabel];

    self.roleLabel = [self label:PPFontRegular(14) color:SeconderyTextClr lines:2];
    [self.heroView addSubview:self.roleLabel];

    self.heroMetricSurface = [[UIView alloc] init];
    self.heroMetricSurface.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroMetricSurface.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.72];
    self.heroMetricSurface.layer.cornerRadius = 22.0;
    self.heroMetricSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroView addSubview:self.heroMetricSurface];

    self.countLabel = [self label:PPFontBold(22) color:PrimaryTextClr lines:1];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroMetricSurface addSubview:self.countLabel];
    UILabel *metricTitle = [self label:PPFontMedium(10) color:SeconderyTextClr lines:1];
    metricTitle.text = kLang(@"DeliveryCompany_Dashboard_Requests");
    metricTitle.textAlignment = NSTextAlignmentCenter;
    [self.heroMetricSurface addSubview:metricTitle];

self.heroMembersControl = [[UIControl alloc] init];
     self.heroMembersControl.translatesAutoresizingMaskIntoConstraints = NO;
     self.heroMembersControl.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.74];
     self.heroMembersControl.layer.cornerRadius = 24.0;
     self.heroMembersControl.layer.cornerCurve = kCACornerCurveContinuous;
     [self.heroMembersControl addTarget:self action:@selector(openMembers) forControlEvents:UIControlEventTouchUpInside];
     [self.heroMembersControl addTarget:self action:@selector(heroMembersPressDown) forControlEvents:UIControlEventTouchDown];
     [self.heroMembersControl addTarget:self action:@selector(heroMembersPressUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchDragExit | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
     [self.heroView addSubview:self.heroMembersControl];

    UIView *membersIconSurface = [[UIView alloc] init];
    membersIconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    membersIconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    membersIconSurface.layer.cornerRadius = 18.0;
    membersIconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroMembersControl addSubview:membersIconSurface];

    UIImageView *membersIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.3.fill"]];
    membersIcon.translatesAutoresizingMaskIntoConstraints = NO;
    membersIcon.tintColor = AppPrimaryClr;
    [membersIconSurface addSubview:membersIcon];

    self.heroMembersTitleLabel = [self label:PPFontBold(15) color:PrimaryTextClr lines:1];
    self.heroMembersTitleLabel.text = kLang(@"DeliveryCompany_Tab_Members");
    [self.heroMembersControl addSubview:self.heroMembersTitleLabel];

    self.heroMembersSubtitleLabel = [self label:PPFontRegular(12) color:SeconderyTextClr lines:2];
    self.heroMembersSubtitleLabel.text = kLang(@"DeliveryCompany_Dashboard_MembersShortcutSubtitle");
    [self.heroMembersControl addSubview:self.heroMembersSubtitleLabel];

    UIImageView *membersChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")]];
    membersChevron.translatesAutoresizingMaskIntoConstraints = NO;
    membersChevron.tintColor = [PrimaryTextClr colorWithAlphaComponent:0.76];
    [self.heroMembersControl addSubview:membersChevron];

    self.tabsScrollView = [[UIScrollView alloc] init];
    self.tabsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabsScrollView.showsHorizontalScrollIndicator = NO;
    self.tabsScrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.tabsScrollView];
    self.tabsStack = [[UIStackView alloc] init];
    self.tabsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabsStack.axis = UILayoutConstraintAxisHorizontal;
    self.tabsStack.spacing = 8.0;
    self.tabsStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.tabsScrollView addSubview:self.tabsStack];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.estimatedRowHeight = 186.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 26.0, 0.0);
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:PPDeliveryCompanyRequestCell.class forCellReuseIdentifier:@"PPDeliveryCompanyRequestCell"];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = AppPrimaryClr;
    [self.refreshControl addTarget:self action:@selector(refreshTriggered) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    self.paginationSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.paginationSpinner.color = AppPrimaryClr;
    self.paginationSpinner.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 48.0);
    self.tableView.tableFooterView = self.paginationSpinner;

    [self buildStateView];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [self.heroView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.heroView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.heroView.heightAnchor constraintEqualToConstant:256.0],

        [self.heroTopGlowView.widthAnchor constraintEqualToConstant:192.0],
        [self.heroTopGlowView.heightAnchor constraintEqualToConstant:192.0],
        [self.heroTopGlowView.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:-58.0],
        [self.heroTopGlowView.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:54.0],

        [self.heroBottomGlowView.widthAnchor constraintEqualToConstant:240.0],
        [self.heroBottomGlowView.heightAnchor constraintEqualToConstant:240.0],
        [self.heroBottomGlowView.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:84.0],
        [self.heroBottomGlowView.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:-72.0],

        [iconSurface.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:22.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:22.0],
        [iconSurface.widthAnchor constraintEqualToConstant:46.0],
        [iconSurface.heightAnchor constraintEqualToConstant:46.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:21.0],
        [icon.heightAnchor constraintEqualToConstant:21.0],

        [self.heroMetricSurface.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:22.0],
        [self.heroMetricSurface.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-20.0],
        [self.heroMetricSurface.widthAnchor constraintEqualToConstant:96.0],
        [self.heroMetricSurface.heightAnchor constraintEqualToConstant:72.0],
        [self.countLabel.topAnchor constraintEqualToAnchor:self.heroMetricSurface.topAnchor constant:9.0],
        [self.countLabel.leadingAnchor constraintEqualToAnchor:self.heroMetricSurface.leadingAnchor constant:8.0],
        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.heroMetricSurface.trailingAnchor constant:-8.0],
        [metricTitle.topAnchor constraintEqualToAnchor:self.countLabel.bottomAnchor constant:-2.0],
        [metricTitle.leadingAnchor constraintEqualToAnchor:self.heroMetricSurface.leadingAnchor constant:6.0],
        [metricTitle.trailingAnchor constraintEqualToAnchor:self.heroMetricSurface.trailingAnchor constant:-6.0],

        [eyebrow.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:18.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],
        [self.companyLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4.0],
        [self.companyLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.companyLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [self.roleLabel.topAnchor constraintEqualToAnchor:self.companyLabel.bottomAnchor constant:6.0],
        [self.roleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.roleLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],

        [self.heroMembersControl.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:18.0],
        [self.heroMembersControl.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-18.0],
        [self.heroMembersControl.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:-18.0],
        [self.roleLabel.bottomAnchor constraintEqualToAnchor:self.heroMembersControl.topAnchor constant:-12.0],
        [membersIconSurface.leadingAnchor constraintEqualToAnchor:self.heroMembersControl.leadingAnchor constant:14.0],
        [membersIconSurface.centerYAnchor constraintEqualToAnchor:self.heroMembersControl.centerYAnchor],
        [membersIconSurface.widthAnchor constraintEqualToConstant:36.0],
        [membersIconSurface.heightAnchor constraintEqualToConstant:36.0],
        [membersIcon.centerXAnchor constraintEqualToAnchor:membersIconSurface.centerXAnchor],
        [membersIcon.centerYAnchor constraintEqualToAnchor:membersIconSurface.centerYAnchor],
        [membersIcon.widthAnchor constraintEqualToConstant:18.0],
        [membersIcon.heightAnchor constraintEqualToConstant:18.0],
        [self.heroMembersTitleLabel.topAnchor constraintEqualToAnchor:self.heroMembersControl.topAnchor constant:13.0],
        [self.heroMembersTitleLabel.leadingAnchor constraintEqualToAnchor:membersIconSurface.trailingAnchor constant:12.0],
        [self.heroMembersTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:membersChevron.leadingAnchor constant:-10.0],
        [self.heroMembersSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroMembersTitleLabel.bottomAnchor constant:2.0],
        [self.heroMembersSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroMembersTitleLabel.leadingAnchor],
        [self.heroMembersSubtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:membersChevron.leadingAnchor constant:-10.0],
        [self.heroMembersSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroMembersControl.bottomAnchor constant:-13.0],
        [membersChevron.trailingAnchor constraintEqualToAnchor:self.heroMembersControl.trailingAnchor constant:-16.0],
        [membersChevron.centerYAnchor constraintEqualToAnchor:self.heroMembersControl.centerYAnchor],
        [membersChevron.widthAnchor constraintEqualToConstant:10.0],
        [membersChevron.heightAnchor constraintEqualToConstant:16.0],

        [self.tabsScrollView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:14.0],
        [self.tabsScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabsScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabsScrollView.heightAnchor constraintEqualToConstant:50.0],
        [self.tabsStack.topAnchor constraintEqualToAnchor:self.tabsScrollView.contentLayoutGuide.topAnchor],
        [self.tabsStack.bottomAnchor constraintEqualToAnchor:self.tabsScrollView.contentLayoutGuide.bottomAnchor],
        [self.tabsStack.leadingAnchor constraintEqualToAnchor:self.tabsScrollView.contentLayoutGuide.leadingAnchor constant:18.0],
        [self.tabsStack.trailingAnchor constraintEqualToAnchor:self.tabsScrollView.contentLayoutGuide.trailingAnchor constant:-18.0],
        [self.tabsStack.heightAnchor constraintEqualToAnchor:self.tabsScrollView.frameLayoutGuide.heightAnchor],

        [self.tableView.topAnchor constraintEqualToAnchor:self.tabsScrollView.bottomAnchor constant:4.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    self.heroMembersHeightConstraint = [self.heroMembersControl.heightAnchor constraintEqualToConstant:72.0];
    self.heroMembersHeightConstraint.active = YES;
}

- (void)buildStateView {
    self.stateView = [[UIView alloc] init];
    self.stateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateView.hidden = YES;
    [self.view addSubview:self.stateView];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    iconSurface.layer.cornerRadius = 25.0;
    [self.stateView addSubview:iconSurface];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    [iconSurface addSubview:icon];

    self.stateTitle = [self label:PPFontBold(19) color:PrimaryTextClr lines:2];
    self.stateTitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateTitle];
    self.stateSubtitle = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    self.stateSubtitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateSubtitle];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.titleLabel.font = PPFontBold(15);
    [self.retryButton setTitle:kLang(@"Retry") forState:UIControlStateNormal];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.retryButton.backgroundColor = AppPrimaryClr;
    self.retryButton.layer.cornerRadius = 16.0;
    [self.retryButton addTarget:self action:@selector(retryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stateView addSubview:self.retryButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AppPrimaryClr;
    [self.stateView addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.stateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stateView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-30.0],
        [self.stateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [self.stateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-32.0],
        [iconSurface.topAnchor constraintEqualToAnchor:self.stateView.topAnchor],
        [iconSurface.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [iconSurface.widthAnchor constraintEqualToConstant:50.0],
        [iconSurface.heightAnchor constraintEqualToConstant:50.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:24.0],
        [icon.heightAnchor constraintEqualToConstant:24.0],
        [self.stateTitle.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:16.0],
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
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.stateView.centerYAnchor],
    ]];
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

- (void)loadProfileAndRequests {
    PPDeliveryCompanyProfile *cached = PPDeliveryCompanyService.shared.verifiedProfile;
    if (cached.companyID.length) {
        [self applyProfile:cached];
        [self loadFirstPage];
        return;
    }
    [self showLoading];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared refreshConfiguredProfileWithCompletion:^(PPDeliveryCompanyProfile * _Nullable profile, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || !profile) {
            [self showMembershipError:error];
            return;
        }
        [self applyProfile:profile];
        [self loadFirstPage];
    }];
}

- (void)applyProfile:(PPDeliveryCompanyProfile *)profile {
    self.profile = profile;
    NSString *name = profile.name.length ? profile.name : (profile.legalName.length ? profile.legalName : profile.companyID);
    self.companyLabel.text = name;
    NSString *role = PPDeliveryCompanyRoleDisplayName(profile.role);
    self.roleLabel.text = profile.isDriver
        ? [NSString stringWithFormat:kLang(@"DeliveryCompany_Dashboard_DriverSubtitle_Format"), role]
        : [NSString stringWithFormat:kLang(@"DeliveryCompany_Dashboard_Subtitle_Format"), role];
    self.heroMembersControl.hidden = !profile.canViewMembers;
    self.heroMembersHeightConstraint.constant = profile.canViewMembers ? 72.0 : 0.0;
    self.selectedFilter = profile.isDriver ? PPDeliveryCompanyDashboardFilterAssigned : PPDeliveryCompanyDashboardFilterNewRequests;
    self.filters = profile.isDriver
        ? @[@(PPDeliveryCompanyDashboardFilterAssigned),
            @(PPDeliveryCompanyDashboardFilterInProgress),
            @(PPDeliveryCompanyDashboardFilterDelivered),
            @(PPDeliveryCompanyDashboardFilterCompleted),
            @(PPDeliveryCompanyDashboardFilterCancelledRejected)]
        : @[@(PPDeliveryCompanyDashboardFilterNewRequests),
            @(PPDeliveryCompanyDashboardFilterAccepted),
            @(PPDeliveryCompanyDashboardFilterAssigned),
            @(PPDeliveryCompanyDashboardFilterInProgress),
            @(PPDeliveryCompanyDashboardFilterDelivered),
            @(PPDeliveryCompanyDashboardFilterCompleted),
            @(PPDeliveryCompanyDashboardFilterCancelledRejected)];
    [self rebuildTabs];
}

- (void)rebuildTabs {
    for (UIView *view in self.tabsStack.arrangedSubviews) {
        [self.tabsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.tabButtons removeAllObjects];
    for (NSNumber *value in self.filters) {
        PPDeliveryCompanyDashboardFilter filter = value.integerValue;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = filter;
        button.titleLabel.font = PPFontBold(13);
        button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 16.0, 10.0, 16.0);
        button.layer.cornerRadius = 20.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        [button setTitle:PPDeliveryCompanyFilterTitle(filter) forState:UIControlStateNormal];
        [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:36.0].active = YES;
        [self.tabsStack addArrangedSubview:button];
        [self.tabButtons addObject:button];
    }
    [self updateTabAppearance];
    [self scrollTabsToLeadingEdgeIfNeeded];
}

- (void)scrollTabsToLeadingEdgeIfNeeded {
    if (!Language.isRTL) return;
    [self.tabsScrollView layoutIfNeeded];
    CGFloat maxOffsetX = self.tabsScrollView.contentSize.width - self.tabsScrollView.bounds.size.width;
    if (maxOffsetX > 0) {
        [self.tabsScrollView setContentOffset:CGPointMake(maxOffsetX, 0) animated:NO];
    }
}

- (void)updateTabAppearance {
    for (UIButton *button in self.tabButtons) {
        BOOL selected = button.tag == self.selectedFilter;
        button.backgroundColor = selected ? AppPrimaryClr : [AppForgroundColr colorWithAlphaComponent:0.92];
        button.layer.borderColor = (selected ? [AppPrimaryClr colorWithAlphaComponent:0.20] : [SeconderyTextClr colorWithAlphaComponent:0.09]).CGColor;
        button.layer.shadowColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.22].CGColor : UIColor.clearColor.CGColor;
        button.layer.shadowOpacity = selected ? 1.0 : 0.0;
        button.layer.shadowRadius = selected ? 16.0 : 0.0;
        button.layer.shadowOffset = selected ? CGSizeMake(0.0, 8.0) : CGSizeZero;
        [button setTitleColor:selected ? UIColor.whiteColor : PrimaryTextClr forState:UIControlStateNormal];
        button.accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    }
}

- (void)tabTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedFilter = sender.tag;
    [self updateTabAppearance];
    [self applyCurrentFilterAndMaybeContinue];
}

- (void)openMembers {
    if (!self.profile.canViewMembers) return;
    [PPFunc pp_playTapEffect];
    PPDeliveryCompanyMembersViewController *controller = [[PPDeliveryCompanyMembersViewController alloc] initWithProfile:self.profile];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)loadFirstPage {
    if (!self.profile.companyID.length) return;
    self.requests = @[];
    self.filteredRequests = @[];
    self.nextPageToken = nil;
    self.loading = YES;
    [self showLoading];
    [self requestPageWithToken:nil append:NO];
}

- (void)loadNextPage {
    if (self.loading || self.loadingNextPage || !self.nextPageToken.length) return;
    self.loadingNextPage = YES;
    [self.paginationSpinner startAnimating];
    [self requestPageWithToken:self.nextPageToken append:YES];
}

- (void)requestPageWithToken:(NSString *)token append:(BOOL)append {
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared listRequestsForProfile:self.profile
                                             nextPageToken:token
                                                completion:^(NSArray<PPDeliveryCompanyRequest *> * _Nullable requests, NSString * _Nullable nextPageToken, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loading = NO;
        self.loadingNextPage = NO;
        [self.refreshControl endRefreshing];
        [self.paginationSpinner stopAnimating];
        if (error) {
            if (append && self.requests.count) {
                [PPToast toast:error.localizedDescription style:PPToastStyleError haptic:NO duration:2.0];
                return;
            }
            [self showError:error.localizedDescription];
            return;
        }
        self.requests = append ? [self.requests arrayByAddingObjectsFromArray:requests ?: @[]] : (requests ?: @[]);
        self.nextPageToken = nextPageToken;
        self.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.requests.count];
        [self applyCurrentFilterAndMaybeContinue];
    }];
}

- (void)applyCurrentFilterAndMaybeContinue {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPDeliveryCompanyRequest *request, NSDictionary *bindings) {
        return [request matchesFilter:self.selectedFilter];
    }];
    self.filteredRequests = [self.requests filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
    if (self.filteredRequests.count == 0 && self.nextPageToken.length && !self.loadingNextPage) {
        [self loadNextPage];
        return;
    }
    if (self.filteredRequests.count == 0) {
        [self showEmpty];
    } else {
        [self hideState];
        self.tableView.hidden = NO;
    }
}

- (void)refreshTriggered {
    [self loadFirstPage];
}

- (void)retryTapped {
    [PPFunc pp_playTapEffect];
    if (!self.profile.companyID.length) [self loadProfileAndRequests];
    else [self loadFirstPage];
}

- (void)showLoading {
    self.tableView.hidden = YES;
    self.stateView.hidden = NO;
    self.stateTitle.hidden = YES;
    self.stateSubtitle.hidden = YES;
    self.retryButton.hidden = YES;
    [self.spinner startAnimating];
}

- (void)showEmpty {
    self.tableView.hidden = YES;
    self.stateView.hidden = NO;
    [self.spinner stopAnimating];
    self.stateTitle.hidden = NO;
    self.stateSubtitle.hidden = NO;
    self.retryButton.hidden = YES;
    self.stateTitle.text = kLang(@"DeliveryCompany_Empty_Title");
    self.stateSubtitle.text = kLang(@"DeliveryCompany_Empty_Subtitle");
}

- (void)showError:(NSString *)message {
    self.tableView.hidden = YES;
    self.stateView.hidden = NO;
    [self.spinner stopAnimating];
    self.stateTitle.hidden = NO;
    self.stateSubtitle.hidden = NO;
    self.retryButton.hidden = NO;
    [self.retryButton setTitle:kLang(@"Retry") forState:UIControlStateNormal];
    [self.retryButton removeTarget:self action:@selector(openSetup) forControlEvents:UIControlEventTouchUpInside];
    [self.retryButton removeTarget:self action:@selector(retryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.retryButton addTarget:self action:@selector(retryTapped) forControlEvents:UIControlEventTouchUpInside];
    self.stateTitle.text = kLang(@"DeliveryCompany_Error_Title");
    self.stateSubtitle.text = message.length ? message : kLang(@"DeliveryCompany_Error_Generic");
}

- (void)showMembershipError:(NSError *)error {
    [self showError:error.localizedDescription ?: kLang(@"DeliveryCompany_Setup_VerificationRequired")];
    [self.retryButton setTitle:kLang(@"DeliveryCompany_Setup_Configure") forState:UIControlStateNormal];
    [self.retryButton removeTarget:self action:@selector(retryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.retryButton addTarget:self action:@selector(openSetup) forControlEvents:UIControlEventTouchUpInside];
}

- (void)openSetup {
    PPDeliveryCompanySetupViewController *controller = [[PPDeliveryCompanySetupViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)hideState {
    self.stateView.hidden = YES;
    [self.spinner stopAnimating];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryCompanyRequestCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPDeliveryCompanyRequestCell" forIndexPath:indexPath];
    [cell configureWithRequest:self.filteredRequests[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryCompanyRequest *request = self.filteredRequests[indexPath.row];
    PPDeliveryCompanyDetailViewController *controller = [[PPDeliveryCompanyDetailViewController alloc] initWithRequestID:request.requestID profile:self.profile];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.filteredRequests.count - 3) [self loadNextPage];
}

- (void)prepareEntrance {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    self.heroView.alpha = 0.0;
    self.heroView.transform = CGAffineTransformMakeTranslation(0, 12.0);
    self.tabsScrollView.alpha = 0.0;
    self.tabsScrollView.transform = CGAffineTransformMakeTranslation(0, 8.0);
}

- (void)runEntranceIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroView.alpha = self.tabsScrollView.alpha = 1.0;
        return;
    }
    [UIView animateWithDuration:0.44 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.36 delay:0.08 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.tabsScrollView.alpha = 1.0;
        self.tabsScrollView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)heroMembersPressDown {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.12 animations:^{
        self.heroMembersControl.transform = CGAffineTransformMakeScale(0.985, 0.985);
        self.heroMembersControl.alpha = 0.92;
    }];
}

- (void)heroMembersPressUp {
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroMembersControl.transform = CGAffineTransformIdentity;
        self.heroMembersControl.alpha = 1.0;
    } completion:nil];
}

@end
