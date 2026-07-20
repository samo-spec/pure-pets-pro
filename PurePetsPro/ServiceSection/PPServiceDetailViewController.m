//
//  PPServiceDetailViewController.m
//  PurePetsPro
//
//  Pharmacy-style detail surface: centered hero, ambient backdrop glows,
//  grouped metadata sections, and floating primary/secondary actions.
//

#import "PPServiceDetailViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPAddEditServiceViewController.h"
#import "PPServiceSubscriptionViewController.h"
#import "PPFirebaseCompat.h"

@interface PPServiceDetailViewController ()
@property (nonatomic, strong) PPServiceModel *service;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIView *heroArea;
@property (nonatomic, strong) UIImageView *headerImageView;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;
@property (nonatomic, strong) UILabel *heroPriceBadge;
@property (nonatomic, strong) UIView *actionBar;
@end

@implementation PPServiceDetailViewController

#pragma mark - Premium Colors

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.10 green:0.10 blue:0.11 alpha:1.0];
        }
        return [UIColor colorWithRed:0.97 green:0.96 blue:0.95 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.94];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.88];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.06];
    }];
}

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
    self.view.backgroundColor = [self pp_canvasColor];
    [self pp_setupBackdropGlows];
    [self pp_configureNavigation];
    [self setupScrollView];
    [self setupHeroHeader];
    [self setupInfoSections];
    [self setupActionBar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_configureNavigation];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = [self pp_canvasColor];
        [self pp_updateGlowsForStyle];
    }
}

#pragma mark - Navigation & Background

- (void)pp_configureNavigation {
    [self pp_navBarWithOtherButton:nil title:@""];
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 110.0;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 100.0;
    [self.view insertSubview:self.bgGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-72.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0],
    ]];

    [self pp_updateGlowsForStyle];
}

- (void)pp_updateGlowsForStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.05 : 0.10];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 60.0;

    self.bgGlowBottom.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = UIColor.systemOrangeColor.CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 70.0;
}

#pragma mark - Formatting

- (NSString *)pp_displayText:(NSString *)text {
    NSString *trimmed = [PPSafeString(text) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : @"—";
}

- (NSString *)pp_priceText {
    return [NSString stringWithFormat:@"%.2f %@", self.service.price, kLang(@"Serv_Currency")];
}

- (NSString *)pp_formattedDate:(NSDate *)date {
    if (!date) return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:date];
}

- (NSString *)pp_subscriptionStateText {
    NSString *status = self.service.subscriptionStatus.lowercaseString ?: @"";
    if ([status isEqualToString:@"active"] || [status isEqualToString:@"enabled"] || [status isEqualToString:@"live"]) {
        return kLang(@"Serv_Sub_Active");
    }
    if ([status isEqualToString:@"inactive"] || [status isEqualToString:@"disabled"] || [status isEqualToString:@"expired"] || [status isEqualToString:@"ended"]) {
        return kLang(@"Serv_Sub_Inactive");
    }
    if (self.service.subscriptionStatus.length > 0) {
        return self.service.subscriptionStatus;
    }
    return self.service.subscriptionActive ? kLang(@"Serv_Sub_Active") : kLang(@"Serv_Sub_Inactive");
}

- (UIColor *)pp_availabilityAccentColor {
    return self.service.isLive ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
}

- (UIColor *)pp_verificationAccentColor {
    NSString *status = self.service.verificationStatus.lowercaseString ?: @"";
    if ([status isEqualToString:@"verified"]) return UIColor.systemGreenColor;
    if ([status isEqualToString:@"rejected"] || [status isEqualToString:@"blocked"]) return UIColor.systemRedColor;
    return AppPrimaryClr;
}

#pragma mark - Scroll Container

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 112, 0);
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 36.0;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-40.0],
    ]];
}

#pragma mark - Hero Header

- (void)setupHeroHeader {
    self.heroArea = [[UIView alloc] init];
    self.heroArea.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroArea.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.heroArea];

    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = [self pp_surfaceColor];
    heroCard.layer.cornerRadius = 34.0;
    heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    heroCard.layer.borderWidth = 1.0;
    heroCard.layer.borderColor = [self pp_borderColor].CGColor;
    heroCard.clipsToBounds = YES;

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    heroCard.layer.shadowColor = UIColor.blackColor.CGColor;
    heroCard.layer.shadowOpacity = isDark ? 0.03 : 0.08;
    heroCard.layer.shadowRadius = 24.0;
    heroCard.layer.shadowOffset = CGSizeMake(0, 14.0);
    [self.heroArea addSubview:heroCard];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    accentBar.layer.cornerRadius = 3.0;
    [heroCard addSubview:accentBar];

    self.headerImageView = [[UIImageView alloc] init];
    self.headerImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.headerImageView.clipsToBounds = YES;
    self.headerImageView.layer.cornerRadius = 34.0;
    self.headerImageView.layer.cornerCurve = kCACornerCurveContinuous;
    self.headerImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    self.headerImageView.layer.borderWidth = 2.0;
    self.headerImageView.layer.borderColor = [UIColor whiteColor].CGColor;
    [heroCard addSubview:self.headerImageView];

    if (self.service.imageURL.length > 0) {
        [self.headerImageView setImageFromUrl:self.service.imageURL placeholderImage:@"sparkles"];
    } else {
        self.headerImageView.image = [UIImage systemImageNamed:@"sparkles"
                                             withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:44 weight:UIImageSymbolWeightLight]];
        self.headerImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.30];
        self.headerImageView.contentMode = UIViewContentModeCenter;
    }

    self.heroTitle = [[UILabel alloc] init];
    self.heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitle.text = [self pp_displayText:self.service.title];
    self.heroTitle.font = [Styling fontBold:26.0];
    self.heroTitle.textColor = PrimaryTextClr;
    self.heroTitle.textAlignment = NSTextAlignmentCenter;
    self.heroTitle.numberOfLines = 2;
    [heroCard addSubview:self.heroTitle];

    self.heroSubtitle = [[UILabel alloc] init];
    self.heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitle.text = kLang(@"Serv_Detail_Subtitle");
    self.heroSubtitle.font = [Styling fontMedium:13.0];
    self.heroSubtitle.textColor = SeconderyTextClr;
    self.heroSubtitle.textAlignment = NSTextAlignmentCenter;
    self.heroSubtitle.numberOfLines = 2;
    [heroCard addSubview:self.heroSubtitle];

    self.heroPriceBadge = [[UILabel alloc] init];
    self.heroPriceBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroPriceBadge.text = [NSString stringWithFormat:@"  %@  ", [self pp_priceText]];
    self.heroPriceBadge.font = [Styling fontBold:13.0];
    self.heroPriceBadge.textColor = AppPrimaryClr;
    self.heroPriceBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    self.heroPriceBadge.layer.cornerRadius = 14.0;
    self.heroPriceBadge.clipsToBounds = YES;
    self.heroPriceBadge.textAlignment = NSTextAlignmentCenter;
    [heroCard addSubview:self.heroPriceBadge];

    UIStackView *statusStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self pp_badgePillWithText:[self.service localizedAvailabilityStatus] tintColor:[self pp_availabilityAccentColor]],
        [self pp_badgePillWithText:[self.service localizedVerificationStatus] tintColor:[self pp_verificationAccentColor]]
    ]];
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusStack.axis = UILayoutConstraintAxisHorizontal;
    statusStack.spacing = 8.0;
    statusStack.alignment = UIStackViewAlignmentCenter;
    statusStack.distribution = UIStackViewDistributionFillProportionally;
    statusStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [heroCard addSubview:statusStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroArea.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.heroArea.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor],
        [self.heroArea.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor],
        [self.heroArea.heightAnchor constraintEqualToConstant:352.0],

        [heroCard.topAnchor constraintEqualToAnchor:self.heroArea.topAnchor constant:12.0],
        [heroCard.leadingAnchor constraintEqualToAnchor:self.heroArea.leadingAnchor constant:20.0],
        [heroCard.trailingAnchor constraintEqualToAnchor:self.heroArea.trailingAnchor constant:-20.0],
        [heroCard.bottomAnchor constraintEqualToAnchor:self.heroArea.bottomAnchor constant:-12.0],

        [accentBar.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:20.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [self.headerImageView.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [self.headerImageView.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [self.headerImageView.widthAnchor constraintEqualToConstant:108.0],
        [self.headerImageView.heightAnchor constraintEqualToConstant:108.0],

        [self.heroTitle.topAnchor constraintEqualToAnchor:self.headerImageView.bottomAnchor constant:12.0],
        [self.heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [self.heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [self.heroSubtitle.topAnchor constraintEqualToAnchor:self.heroTitle.bottomAnchor constant:4.0],
        [self.heroSubtitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [self.heroSubtitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [self.heroPriceBadge.topAnchor constraintEqualToAnchor:self.heroSubtitle.bottomAnchor constant:12.0],
        [self.heroPriceBadge.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [self.heroPriceBadge.heightAnchor constraintEqualToConstant:28.0],

        [statusStack.topAnchor constraintEqualToAnchor:self.heroPriceBadge.bottomAnchor constant:12.0],
        [statusStack.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [statusStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [statusStack.trailingAnchor constraintLessThanOrEqualToAnchor:heroCard.trailingAnchor constant:-24.0],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.heroArea.bottomAnchor constant:20.0],
    ]];
}

#pragma mark - Detail Sections

- (void)setupInfoSections {
    NSMutableArray<UIView *> *overviewViews = [NSMutableArray array];
    [overviewViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Title")
                                                   value:[self pp_displayText:self.service.title]
                                                iconName:@"textformat"]];
    [overviewViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Type")
                                                   value:[self pp_displayText:[self.service localizedTypeName]]
                                                iconName:@"tag.fill"]];
    [overviewViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Category")
                                                   value:[self pp_displayText:self.service.category]
                                                iconName:@"folder.fill"]];
    [overviewViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Description")
                                                   value:[self pp_displayText:self.service.descriptionText]
                                                iconName:@"doc.text.fill"]];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Serv_Section_Overview")
                                                                subtitle:kLang(@"Serv_Section_Overview_Hint")
                                                                    icon:@"square.text.square"
                                                                   views:overviewViews]];

    NSMutableArray<UIView *> *statusViews = [NSMutableArray array];
    [statusViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Price")
                                                 value:[self pp_priceText]
                                              iconName:@"banknote.fill"]];
    [statusViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Availability")
                                                 value:[self.service localizedAvailabilityStatus]
                                              iconName:@"checkmark.circle.fill"]];
    [statusViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_Verification")
                                                 value:[self.service localizedVerificationStatus]
                                              iconName:@"checkmark.shield.fill"]];
    if (self.service.subscriptionPlan.length > 0) {
        [statusViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Sub_Plan")
                                                     value:[self pp_displayText:self.service.subscriptionPlan]
                                                  iconName:@"crown.fill"]];
    }
    if (self.service.subscriptionPlan.length > 0 || self.service.subscriptionStatus.length > 0 || self.service.subscriptionActive) {
        [statusViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Action_Subscription")
                                                     value:[self pp_subscriptionStateText]
                                                  iconName:@"crown.fill"]];
    }
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Serv_Section_Status")
                                                                subtitle:kLang(@"Serv_Section_Status_Hint")
                                                                    icon:@"checkmark.seal.fill"
                                                                   views:statusViews]];

    NSMutableArray<UIView *> *timelineViews = [NSMutableArray array];
    NSString *createdAtText = [self pp_formattedDate:self.service.createdAt];
    if (createdAtText.length > 0) {
        [timelineViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_CreatedAt")
                                                       value:createdAtText
                                                    iconName:@"calendar"]];
    }
    NSString *updatedAtText = [self pp_formattedDate:self.service.updatedAt];
    if (updatedAtText.length > 0) {
        [timelineViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Field_UpdatedAt")
                                                       value:updatedAtText
                                                    iconName:@"clock.fill"]];
    }
    NSString *subscriptionStart = [self pp_formattedDate:self.service.subscriptionStartDate];
    if (subscriptionStart.length > 0) {
        [timelineViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Sub_StartDate")
                                                       value:subscriptionStart
                                                    iconName:@"calendar.badge.plus"]];
    }
    NSString *subscriptionEnd = [self pp_formattedDate:self.service.subscriptionEndDate];
    if (subscriptionEnd.length > 0) {
        [timelineViews addObject:[self pp_detailCardWithLabel:kLang(@"Serv_Sub_EndDate")
                                                       value:subscriptionEnd
                                                    iconName:@"calendar.badge.minus"]];
    }

    if (timelineViews.count > 0) {
        [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Serv_Section_Timeline")
                                                                    subtitle:kLang(@"Serv_Section_Timeline_Hint")
                                                                        icon:@"calendar.circle.fill"
                                                                       views:timelineViews]];
    }
}

- (UIView *)pp_sectionBlockWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [stack addArrangedSubview:[self pp_sectionHeader:title subtitle:subtitle icon:iconName]];
    for (UIView *view in views) {
        [stack addArrangedSubview:view];
    }
    return stack;
}

- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = AppPrimaryClr;
    bar.layer.cornerRadius = 2.0;
    [container addSubview:bar];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [container addSubview:icon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:14.0];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontMedium:11.0];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.alpha = 0.7;
    subtitleLabel.text = subtitle;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.widthAnchor constraintEqualToConstant:28.0],
        [bar.heightAnchor constraintEqualToConstant:4.0],

        [icon.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:9.0],
        [icon.widthAnchor constraintEqualToConstant:16.0],
        [icon.heightAnchor constraintEqualToConstant:16.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)pp_detailCardWithLabel:(NSString *)label value:(NSString *)value iconName:(NSString *)iconName {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self pp_surfaceColor];
    card.layer.cornerRadius = 20.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self pp_borderColor].CGColor;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.75];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:iconView];

    UILabel *labelView = [[UILabel alloc] init];
    labelView.translatesAutoresizingMaskIntoConstraints = NO;
    labelView.font = [Styling fontMedium:11.0];
    labelView.textColor = SeconderyTextClr;
    labelView.textAlignment = Language.alignmentForCurrentLanguage;
    labelView.text = label;
    [card addSubview:labelView];

    UILabel *valueView = [[UILabel alloc] init];
    valueView.translatesAutoresizingMaskIntoConstraints = NO;
    valueView.font = [Styling fontBold:15.0];
    valueView.textColor = PrimaryTextClr;
    valueView.textAlignment = Language.alignmentForCurrentLanguage;
    valueView.text = [self pp_displayText:value];
    valueView.numberOfLines = 0;
    [card addSubview:valueView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [iconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [iconView.widthAnchor constraintEqualToConstant:20.0],
        [iconView.heightAnchor constraintEqualToConstant:20.0],

        [labelView.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [labelView.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12.0],
        [labelView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [valueView.topAnchor constraintEqualToAnchor:labelView.bottomAnchor constant:4.0],
        [valueView.leadingAnchor constraintEqualToAnchor:labelView.leadingAnchor],
        [valueView.trailingAnchor constraintEqualToAnchor:labelView.trailingAnchor],
        [valueView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];

    return card;
}

- (UIView *)pp_badgePillWithText:(NSString *)text tintColor:(UIColor *)tintColor {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = [NSString stringWithFormat:@"  %@  ", [self pp_displayText:text]];
    label.font = [Styling fontBold:11.0];
    label.textColor = tintColor;
    label.backgroundColor = [tintColor colorWithAlphaComponent:0.10];
    label.layer.cornerRadius = 13.0;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    [label.heightAnchor constraintEqualToConstant:26.0].active = YES;
    return label;
}

#pragma mark - Action Bar

- (void)setupActionBar {
    self.actionBar = [[UIView alloc] init];
    self.actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionBar.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.actionBar];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 12.0;
    [self.actionBar addSubview:stack];

    UIButton *editButton = [self pp_actionButtonWithTitle:kLang(@"Serv_Action_Edit")
                                               systemName:@"pencil"
                                                   filled:YES
                                                   action:@selector(editTapped)];
    [stack addArrangedSubview:editButton];

    UIButton *subscriptionButton = [self pp_actionButtonWithTitle:kLang(@"Serv_Sub_MyPlan")
                                                       systemName:@"crown.fill"
                                                           filled:NO
                                                           action:@selector(subscriptionTapped)];
    [stack addArrangedSubview:subscriptionButton];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [self.actionBar.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12.0],
        [self.actionBar.heightAnchor constraintEqualToConstant:56.0],

        [stack.topAnchor constraintEqualToAnchor:self.actionBar.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.actionBar.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.actionBar.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.actionBar.bottomAnchor],
    ]];
}

- (UIButton *)pp_actionButtonWithTitle:(NSString *)title systemName:(NSString *)systemName filled:(BOOL)filled action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    [button setImage:[UIImage systemImageNamed:systemName withConfiguration:cfg] forState:UIControlStateNormal];
    [button setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    button.titleLabel.font = [Styling fontBold:14.0];
    button.layer.cornerRadius = 28.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    if (filled) {
        button.tintColor = UIColor.whiteColor;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.backgroundColor = AppPrimaryClr;
        button.layer.shadowColor = AppPrimaryClr.CGColor;
        button.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.15 : 0.28;
        button.layer.shadowRadius = 16.0;
        button.layer.shadowOffset = CGSizeMake(0, 8.0);
    } else {
        button.tintColor = AppPrimaryClr;
        [button setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        button.backgroundColor = [self pp_surfaceColor];
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [self pp_borderColor].CGColor;
    }

    return button;
}

#pragma mark - Actions

- (void)editTapped {
    [PPFunc pp_playTapEffect];
    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:self.service];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)subscriptionTapped {
    [PPFunc pp_playTapEffect];
    PPServiceSubscriptionViewController *vc = [[PPServiceSubscriptionViewController alloc] initWithService:self.service];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
