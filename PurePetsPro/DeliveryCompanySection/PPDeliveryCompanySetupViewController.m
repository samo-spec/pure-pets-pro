#import "PPDeliveryCompanySetupViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPDeliveryCompanyDashboardViewController.h"
#import "JGProgressHUD.h"

#pragma mark - PPDeliveryCompanyCardView (Custom Tactile Control)

@interface PPDeliveryCompanyCardView : UIControl

@property (nonatomic, strong) PPDeliveryCompanyProfile *profile;
@property (nonatomic, assign) BOOL isCardSelected;
@property (nonatomic, assign) BOOL isCurrentlyConnected;
@property (nonatomic, copy) void (^onCardSelected)(PPDeliveryCompanyCardView *card);
@property (nonatomic, copy) void (^onCopyIDRequested)(PPDeliveryCompanyCardView *card, NSString *companyID);

@property (nonatomic, strong) UIView *avatarPlate;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UIImageView *avatarIcon;
@property (nonatomic, strong) UIView *availableDot;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *legalNameLabel;

@property (nonatomic, strong) UIView *idBadge;
@property (nonatomic, strong) UILabel *idLabel;
@property (nonatomic, strong) UIButton *iDDButton;

@property (nonatomic, strong) UIView *rolePill;
@property (nonatomic, strong) UILabel *roleLabel;

@property (nonatomic, strong) UIView *statusPill;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) UIView *connectedBanner;
@property (nonatomic, strong) UILabel *connectedBannerLabel;

@property (nonatomic, strong) UIImageView *selectionIndicator;

- (instancetype)initWithProfile:(PPDeliveryCompanyProfile *)profile;
- (void)updateSelectionStateAnimated:(BOOL)animated;

@end

@implementation PPDeliveryCompanyCardView

- (instancetype)initWithProfile:(PPDeliveryCompanyProfile *)profile {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _profile = profile;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        [self setupUI];
        [self configureWithProfile:profile];
        [self updateSelectionStateAnimated:NO];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(self, PPCornerCard);
    self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.layer.borderColor = PPHairlineColor().CGColor;
    PPApplyCardShadow(self);

    // 1. Avatar Plate
    self.avatarPlate = [[UIView alloc] init];
    self.avatarPlate.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarPlate.userInteractionEnabled = NO;
    PPApplyContinuousCorners(self.avatarPlate, PPCorner16);
    self.avatarPlate.backgroundColor = AppPrimaryClrWithAlpha(0.12);
    [self addSubview:self.avatarPlate];

    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarLabel.font = PPScaledFont(PPFontBold(18.0), UIFontTextStyleHeadline);
    self.avatarLabel.textColor = AppPrimaryClr;
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    [self.avatarPlate addSubview:self.avatarLabel];

    self.avatarIcon = [[UIImageView alloc] init];
    self.avatarIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarIcon.tintColor = AppPrimaryClr;
    self.avatarIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.avatarIcon.hidden = YES;
    [self.avatarPlate addSubview:self.avatarIcon];

    self.availableDot = [[UIView alloc] init];
    self.availableDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableDot.backgroundColor = [UIColor ppSuccess];
    PPApplyContinuousCorners(self.availableDot, 5.0);
    self.availableDot.layer.borderWidth = 1.5;
    self.availableDot.layer.borderColor = [UIColor ppElevatedSurface].CGColor;
    [self addSubview:self.availableDot];

    // 2. Selection Indicator
    self.selectionIndicator = [[UIImageView alloc] init];
    self.selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionIndicator.contentMode = UIViewContentModeScaleAspectFit;
    self.selectionIndicator.userInteractionEnabled = NO;
    [self addSubview:self.selectionIndicator];

    // 3. Text & Details Column
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = PPFontBold(16.0);
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 1;
    PPEnableDynamicType(self.titleLabel, UIFontTextStyleHeadline);
    [self addSubview:self.titleLabel];

    // Connected badge if active
    self.connectedBanner = [[UIView alloc] init];
    self.connectedBanner.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectedBanner.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(self.connectedBanner, 6.0);
    self.connectedBanner.hidden = YES;
    [self addSubview:self.connectedBanner];

    self.connectedBannerLabel = [[UILabel alloc] init];
    self.connectedBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectedBannerLabel.font = PPScaledFont(PPFontBold(11.0), UIFontTextStyleCaption2);
    self.connectedBannerLabel.textColor = [UIColor ppSuccess];
    self.connectedBannerLabel.text = kLang(@"DeliveryCompany_Setup_CurrentlyConnected");
    [self.connectedBanner addSubview:self.connectedBannerLabel];

    // Company ID Pill
    self.idBadge = [[UIView alloc] init];
    self.idBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.idBadge.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.85];
    PPApplyContinuousCorners(self.idBadge, 8.0);
    self.idBadge.layer.borderWidth = 0.5;
    self.idBadge.layer.borderColor = PPHairlineColor().CGColor;
    [self addSubview:self.idBadge];

    self.idLabel = [[UILabel alloc] init];
    self.idLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.idLabel.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightMedium];
    self.idLabel.textColor = SeconderyTextClr;
    self.idLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.idBadge addSubview:self.idLabel];

    self.iDDButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.iDDButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iDDButton setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    self.iDDButton.tintColor = AppTertiaryTextClr;
    [self.iDDButton addTarget:self action:@selector(copyButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.idBadge addSubview:self.iDDButton];

    // Meta Row: Role Pill + Status Pill
    self.rolePill = [[UIView alloc] init];
    self.rolePill.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.rolePill, 8.0);
    [self addSubview:self.rolePill];

    self.roleLabel = [[UILabel alloc] init];
    self.roleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.roleLabel.font = PPScaledFont(PPFontBold(11.0), UIFontTextStyleCaption1);
    self.roleLabel.textAlignment = NSTextAlignmentCenter;
    [self.rolePill addSubview:self.roleLabel];

    self.statusPill = [[UIView alloc] init];
    self.statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusPill.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.85];
    PPApplyContinuousCorners(self.statusPill, 8.0);
    [self addSubview:self.statusPill];

    self.statusDot = [[UIView alloc] init];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.statusDot, 3.5);
    [self.statusPill addSubview:self.statusDot];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = PPScaledFont(PPFontMedium(11.0), UIFontTextStyleCaption1);
    self.statusLabel.textColor = SeconderyTextClr;
    [self.statusPill addSubview:self.statusLabel];

    // Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Minimum card height
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:96.0],

        // Avatar
        [self.avatarPlate.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [self.avatarPlate.topAnchor constraintEqualToAnchor:self.topAnchor constant:14.0],
        [self.avatarPlate.widthAnchor constraintEqualToConstant:50.0],
        [self.avatarPlate.heightAnchor constraintEqualToConstant:50.0],

        [self.avatarLabel.centerXAnchor constraintEqualToAnchor:self.avatarPlate.centerXAnchor],
        [self.avatarLabel.centerYAnchor constraintEqualToAnchor:self.avatarPlate.centerYAnchor],
        [self.avatarIcon.centerXAnchor constraintEqualToAnchor:self.avatarPlate.centerXAnchor],
        [self.avatarIcon.centerYAnchor constraintEqualToAnchor:self.avatarPlate.centerYAnchor],
        [self.avatarIcon.widthAnchor constraintEqualToConstant:26.0],
        [self.avatarIcon.heightAnchor constraintEqualToConstant:26.0],

        [self.availableDot.trailingAnchor constraintEqualToAnchor:self.avatarPlate.trailingAnchor constant:2.0],
        [self.availableDot.bottomAnchor constraintEqualToAnchor:self.avatarPlate.bottomAnchor constant:2.0],
        [self.availableDot.widthAnchor constraintEqualToConstant:10.0],
        [self.availableDot.heightAnchor constraintEqualToConstant:10.0],

        // Selection Indicator (Trailing)
        [self.selectionIndicator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
        [self.selectionIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.selectionIndicator.widthAnchor constraintEqualToConstant:24.0],
        [self.selectionIndicator.heightAnchor constraintEqualToConstant:24.0],

        // Title and Connected Banner
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.avatarPlate.trailingAnchor constant:12.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectedBanner.leadingAnchor constant:-8.0],

        [self.connectedBanner.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.connectedBanner.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionIndicator.leadingAnchor constant:-10.0],
        [self.connectedBanner.heightAnchor constraintEqualToConstant:20.0],

        [self.connectedBannerLabel.leadingAnchor constraintEqualToAnchor:self.connectedBanner.leadingAnchor constant:7.0],
        [self.connectedBannerLabel.trailingAnchor constraintEqualToAnchor:self.connectedBanner.trailingAnchor constant:-7.0],
        [self.connectedBannerLabel.centerYAnchor constraintEqualToAnchor:self.connectedBanner.centerYAnchor],

        // Company ID Badge
        [self.idBadge.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6.0],
        [self.idBadge.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.idBadge.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionIndicator.leadingAnchor constant:-10.0],
        [self.idBadge.heightAnchor constraintEqualToConstant:24.0],

        [self.idLabel.leadingAnchor constraintEqualToAnchor:self.idBadge.leadingAnchor constant:7.0],
        [self.idLabel.centerYAnchor constraintEqualToAnchor:self.idBadge.centerYAnchor],

        [self.iDDButton.leadingAnchor constraintEqualToAnchor:self.idLabel.trailingAnchor constant:5.0],
        [self.iDDButton.trailingAnchor constraintEqualToAnchor:self.idBadge.trailingAnchor constant:-5.0],
        [self.iDDButton.centerYAnchor constraintEqualToAnchor:self.idBadge.centerYAnchor],
        [self.iDDButton.widthAnchor constraintEqualToConstant:16.0],
        [self.iDDButton.heightAnchor constraintEqualToConstant:16.0],

        // Meta Row (Role Pill + Status Pill)
        [self.rolePill.topAnchor constraintEqualToAnchor:self.idBadge.bottomAnchor constant:8.0],
        [self.rolePill.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.rolePill.heightAnchor constraintEqualToConstant:22.0],
        [self.rolePill.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-14.0],

        [self.roleLabel.leadingAnchor constraintEqualToAnchor:self.rolePill.leadingAnchor constant:8.0],
        [self.roleLabel.trailingAnchor constraintEqualToAnchor:self.rolePill.trailingAnchor constant:-8.0],
        [self.roleLabel.centerYAnchor constraintEqualToAnchor:self.rolePill.centerYAnchor],

        [self.statusPill.centerYAnchor constraintEqualToAnchor:self.rolePill.centerYAnchor],
        [self.statusPill.leadingAnchor constraintEqualToAnchor:self.rolePill.trailingAnchor constant:8.0],
        [self.statusPill.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionIndicator.leadingAnchor constant:-10.0],
        [self.statusPill.heightAnchor constraintEqualToConstant:22.0],

        [self.statusDot.leadingAnchor constraintEqualToAnchor:self.statusPill.leadingAnchor constant:7.0],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.statusPill.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:7.0],
        [self.statusDot.heightAnchor constraintEqualToConstant:7.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:5.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusPill.trailingAnchor constant:-7.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusPill.centerYAnchor],
    ]];

    [self addTarget:self action:@selector(cardTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureWithProfile:(PPDeliveryCompanyProfile *)profile {
    NSString *displayName = profile.name.length ? profile.name : (profile.legalName.length ? profile.legalName : profile.companyID);
    self.titleLabel.text = displayName;

    // Avatar Monogram
    if (displayName.length > 0) {
        NSArray *words = [displayName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableString *monogram = [NSMutableString string];
        for (NSString *word in words) {
            if (word.length > 0) {
                [monogram appendString:[word substringToIndex:1]];
                if (monogram.length >= 2) break;
            }
        }
        self.avatarLabel.text = monogram.uppercaseString;
        self.avatarLabel.hidden = NO;
        self.avatarIcon.hidden = YES;
    } else {
        self.avatarIcon.image = [UIImage systemImageNamed:@"shippingbox.fill"];
        self.avatarIcon.hidden = NO;
        self.avatarLabel.hidden = YES;
    }

    // Availability dot
    self.availableDot.backgroundColor = profile.available ? [UIColor ppSuccess] : AppTertiaryTextClr;

    // Company ID
    self.idLabel.text = [NSString stringWithFormat:@"# %@", profile.companyID ?: @""];

    // Role
    self.roleLabel.text = PPDeliveryCompanyRoleDisplayName(profile.role);
    if ([profile isOwner]) {
        self.rolePill.backgroundColor = [UIColor colorWithRed:0.55 green:0.22 blue:0.85 alpha:0.12];
        self.roleLabel.textColor = [UIColor colorWithRed:0.55 green:0.22 blue:0.85 alpha:1.0];
    } else if ([profile isDispatcher]) {
        self.rolePill.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.12];
        self.roleLabel.textColor = [UIColor ppInfo];
    } else if ([profile isDriver]) {
        self.rolePill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
        self.roleLabel.textColor = AppPrimaryClr;
    } else {
        self.rolePill.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.9];
        self.roleLabel.textColor = SeconderyTextClr;
    }

    // Status
    self.statusLabel.text = PPDeliveryCompanyStatusDisplayName(profile.status);
    self.statusDot.backgroundColor = PPDeliveryCompanyStatusColor(profile.status);

    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", displayName, self.roleLabel.text, self.statusLabel.text];
}

- (void)setIsCardSelected:(BOOL)isCardSelected {
    _isCardSelected = isCardSelected;
    [self updateSelectionStateAnimated:YES];
}

- (void)setIsCurrentlyConnected:(BOOL)isCurrentlyConnected {
    _isCurrentlyConnected = isCurrentlyConnected;
    self.connectedBanner.hidden = !isCurrentlyConnected;
}

- (void)updateSelectionStateAnimated:(BOOL)animated {
    void (^changes)(void) = ^{
        if (self.isCardSelected) {
            self.layer.borderColor = AppPrimaryClr.CGColor;
            self.layer.borderWidth = 2.0;
            self.backgroundColor = [UIColor ppElevatedSurface];
            self.selectionIndicator.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
            self.selectionIndicator.tintColor = AppPrimaryClr;
            self.selectionIndicator.transform = CGAffineTransformMakeScale(1.08, 1.08);
            self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
        } else {
            self.layer.borderColor = PPHairlineColor().CGColor;
            self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
            self.backgroundColor = [UIColor ppElevatedSurface];
            self.selectionIndicator.image = [UIImage systemImageNamed:@"circle"];
            self.selectionIndicator.tintColor = AppTertiaryTextClr;
            self.selectionIndicator.transform = CGAffineTransformIdentity;
            self.accessibilityTraits = UIAccessibilityTraitButton;
        }
    };

    if (animated && !PPMotionReduced()) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (PPMotionReduced()) return;
    if (highlighted) {
        PPTapFeedbackDown(self);
    } else {
        PPTapFeedbackUp(self);
    }
}

- (void)cardTapped {
    [PPFunc pp_playTapEffect];
    if (self.onCardSelected) {
        self.onCardSelected(self);
    }
}

- (void)copyButtonTapped {
    [PPFunc pp_playTapEffect];
    if (self.onCopyIDRequested) {
        self.onCopyIDRequested(self, self.profile.companyID ?: @"");
    }
}

@end

#pragma mark - PPDeliveryCompanySkeletonCardView (Loading Shimmer)

@interface PPDeliveryCompanySkeletonCardView : UIView
@end

@implementation PPDeliveryCompanySkeletonCardView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor ppElevatedSurface];
        PPApplyContinuousCorners(self, PPCornerCard);
        self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.layer.borderColor = PPHairlineColor().CGColor;
        [self setupUI];
        [self startPulsing];
    }
    return self;
}

- (void)setupUI {
    UIView *avatarPlaceholder = [self placeholderWithRadius:PPCorner16];
    UIView *titlePlaceholder = [self placeholderWithRadius:6.0];
    UIView *idPlaceholder = [self placeholderWithRadius:6.0];
    UIView *pillPlaceholder1 = [self placeholderWithRadius:8.0];
    UIView *pillPlaceholder2 = [self placeholderWithRadius:8.0];
    UIView *circlePlaceholder = [self placeholderWithRadius:12.0];

    [self addSubview:avatarPlaceholder];
    [self addSubview:titlePlaceholder];
    [self addSubview:idPlaceholder];
    [self addSubview:pillPlaceholder1];
    [self addSubview:pillPlaceholder2];
    [self addSubview:circlePlaceholder];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [avatarPlaceholder.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [avatarPlaceholder.topAnchor constraintEqualToAnchor:self.topAnchor constant:14.0],
        [avatarPlaceholder.widthAnchor constraintEqualToConstant:50.0],
        [avatarPlaceholder.heightAnchor constraintEqualToConstant:50.0],

        [titlePlaceholder.leadingAnchor constraintEqualToAnchor:avatarPlaceholder.trailingAnchor constant:12.0],
        [titlePlaceholder.topAnchor constraintEqualToAnchor:self.topAnchor constant:18.0],
        [titlePlaceholder.widthAnchor constraintEqualToConstant:140.0],
        [titlePlaceholder.heightAnchor constraintEqualToConstant:16.0],

        [idPlaceholder.leadingAnchor constraintEqualToAnchor:titlePlaceholder.leadingAnchor],
        [idPlaceholder.topAnchor constraintEqualToAnchor:titlePlaceholder.bottomAnchor constant:8.0],
        [idPlaceholder.widthAnchor constraintEqualToConstant:100.0],
        [idPlaceholder.heightAnchor constraintEqualToConstant:12.0],

        [pillPlaceholder1.leadingAnchor constraintEqualToAnchor:titlePlaceholder.leadingAnchor],
        [pillPlaceholder1.topAnchor constraintEqualToAnchor:idPlaceholder.bottomAnchor constant:10.0],
        [pillPlaceholder1.widthAnchor constraintEqualToConstant:70.0],
        [pillPlaceholder1.heightAnchor constraintEqualToConstant:20.0],
        [pillPlaceholder1.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-14.0],

        [pillPlaceholder2.leadingAnchor constraintEqualToAnchor:pillPlaceholder1.trailingAnchor constant:8.0],
        [pillPlaceholder2.centerYAnchor constraintEqualToAnchor:pillPlaceholder1.centerYAnchor],
        [pillPlaceholder2.widthAnchor constraintEqualToConstant:60.0],
        [pillPlaceholder2.heightAnchor constraintEqualToConstant:20.0],

        [circlePlaceholder.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
        [circlePlaceholder.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [circlePlaceholder.widthAnchor constraintEqualToConstant:24.0],
        [circlePlaceholder.heightAnchor constraintEqualToConstant:24.0],
    ]];
}

- (UIView *)placeholderWithRadius:(CGFloat)radius {
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.9];
    PPApplyContinuousCorners(view, radius);
    return view;
}

- (void)startPulsing {
    if (PPMotionReduced()) return;
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @(0.35);
    pulse.toValue = @(0.85);
    pulse.duration = 0.85;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.layer addAnimation:pulse forKey:@"shimmerPulse"];
}

@end

#pragma mark - PPDeliveryCompanySetupViewController Main Implementation

@interface PPDeliveryCompanySetupViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIStackView *contentStack;

// Hero section
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroTopGlowView;
@property (nonatomic, strong) UIView *heroBottomGlowView;
@property (nonatomic, strong) UIView *heroIconSurface;
@property (nonatomic, strong) UIImageView *heroIcon;
@property (nonatomic, strong) UIView *heroStatusPill;
@property (nonatomic, strong) UIView *heroStatusDot;
@property (nonatomic, strong) UILabel *heroStatusLabel;
@property (nonatomic, strong) UILabel *heroEyebrow;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;

// Active Connected Card (when connected)
@property (nonatomic, strong) UIView *connectedFleetCard;
@property (nonatomic, strong) UILabel *connectedFleetNameLabel;
@property (nonatomic, strong) UILabel *connectedFleetRoleLabel;
@property (nonatomic, strong) UILabel *connectedFleetIDLabel;
@property (nonatomic, strong) UIButton *connectedFleetDashboardButton;
@property (nonatomic, strong) UIButton *connectedFleetDisconnectButton;

// Discovered Companies Section (The Core List)
@property (nonatomic, strong) UIView *availableCompaniesContainer;
@property (nonatomic, strong) UIStackView *availableCompaniesHeaderStack;
@property (nonatomic, strong) UILabel *availableCompaniesSectionTitle;
@property (nonatomic, strong) UIView *availableCompaniesBadge;
@property (nonatomic, strong) UILabel *availableCompaniesBadgeLabel;
@property (nonatomic, strong) UIButton *refreshDiscoveryButton;
@property (nonatomic, strong) UIStackView *cardsStackView;
@property (nonatomic, strong) NSMutableArray<PPDeliveryCompanyCardView *> *cardViews;
@property (nonatomic, strong) NSMutableArray<PPDeliveryCompanySkeletonCardView *> *skeletonViews;
@property (nonatomic, strong) UIView *emptyDiscoveredView;

// Manual Entry Accordion Card
@property (nonatomic, strong) UIView *manualAccordionCard;
@property (nonatomic, strong) UIControl *manualHeaderControl;
@property (nonatomic, strong) UILabel *manualHeaderTitle;
@property (nonatomic, strong) UILabel *manualHeaderSubtitle;
@property (nonatomic, strong) UIImageView *manualChevron;
@property (nonatomic, strong) UIView *manualContentContainer;
@property (nonatomic, strong) UITextField *companyIDField;
@property (nonatomic, strong) UIButton *pasteClipboardButton;
@property (nonatomic, strong) UIButton *manualVerifyButton;
@property (nonatomic, assign) BOOL isManualExpanded;

// Bottom Action Bar
@property (nonatomic, strong) UIView *bottomActionBar;
@property (nonatomic, strong) UIButton *primaryActionButton;
@property (nonatomic, strong) UIActivityIndicatorView *primarySpinner;
@property (nonatomic, strong) UIButton *secondaryDisconnectButton;

// State tracking
@property (nonatomic, copy, nullable) NSString *selectedCompanyID;
@property (nonatomic, assign) BOOL isDiscoveringMemberships;
@property (nonatomic, assign) BOOL didAttemptAutoDiscovery;
@property (nonatomic, assign) BOOL didAutoOpenDashboard;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL isConnectingAction;

@end

@implementation PPDeliveryCompanySetupViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.cardViews = [NSMutableArray array];
    self.skeletonViews = [NSMutableArray array];

    PPDeliveryCompanyProfile *current = PPDeliveryCompanyService.shared.verifiedProfile;
    if (current.companyID.length > 0) {
        self.selectedCompanyID = current.companyID;
    }

    [self buildUI];
    [self renderStateAnimated:NO];
    [self prepareEntrance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryCompany_Setup_NavTitle") showBack:YES];
    [self renderStateAnimated:NO];
    [self refreshAutoDiscoveryForce:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

#pragma mark - UI Architecture

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.scrollView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = AppPrimaryClr;
    [self.refreshControl addTarget:self action:@selector(handlePullToRefresh) forControlEvents:UIControlEventValueChanged];
    self.scrollView.refreshControl = self.refreshControl;

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceLG;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    // Build Modular Components
    self.heroView = [self buildHeroView];
    self.connectedFleetCard = [self buildConnectedFleetCard];
    self.availableCompaniesContainer = [self buildAvailableCompaniesSection];
    self.manualAccordionCard = [self buildManualAccordionCard];
    self.bottomActionBar = [self buildBottomActionBar];

    [self.contentStack addArrangedSubview:self.heroView];
    [self.contentStack addArrangedSubview:self.connectedFleetCard];
    [self.contentStack addArrangedSubview:self.availableCompaniesContainer];
    [self.contentStack addArrangedSubview:self.manualAccordionCard];
    [self.contentStack addArrangedSubview:self.bottomActionBar];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
    ]];
}

#pragma mark - 1. Ambient Hero Header

- (UIView *)buildHeroView {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPStyleCardSurface(surface, PPCornerHero);

    self.heroTopGlowView = [[UIView alloc] init];
    self.heroTopGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTopGlowView.backgroundColor = AppPrimaryClrWithAlpha(0.08);
    PPApplyContinuousCorners(self.heroTopGlowView, 96.0);
    [surface addSubview:self.heroTopGlowView];

    self.heroBottomGlowView = [[UIView alloc] init];
    self.heroBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBottomGlowView.backgroundColor = AppPrimaryClrWithAlpha(0.04);
    PPApplyContinuousCorners(self.heroBottomGlowView, 120.0);
    [surface addSubview:self.heroBottomGlowView];

    self.heroIconSurface = [[UIView alloc] init];
    self.heroIconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(self.heroIconSurface, PPCornerCard, 0.12);
    [surface addSubview:self.heroIconSurface];

    self.heroIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.circle.fill"]];
    self.heroIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIcon.tintColor = AppPrimaryClr;
    self.heroIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.heroIconSurface addSubview:self.heroIcon];

    // Status Pill at Top Trailing
    self.heroStatusPill = [[UIView alloc] init];
    self.heroStatusPill.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatusPill.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    PPApplyContinuousCorners(self.heroStatusPill, 13.0);
    [surface addSubview:self.heroStatusPill];

    self.heroStatusDot = [[UIView alloc] init];
    self.heroStatusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatusDot.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.heroStatusDot, 4.0);
    [self.heroStatusPill addSubview:self.heroStatusDot];

    self.heroStatusLabel = [self labelWithFont:PPFontBold(11.5) color:AppPrimaryClr lines:1];
    PPEnableDynamicType(self.heroStatusLabel, UIFontTextStyleCaption1);
    self.heroStatusLabel.text = kLang(@"DeliveryCompany_Setup_ActiveFleet");
    [self.heroStatusPill addSubview:self.heroStatusLabel];

    self.heroEyebrow = [self labelWithFont:PPFontBold(PPFontFootnote) color:AppPrimaryClr lines:1];
    self.heroEyebrow.text = kLang(@"DeliveryCompany_Setup_Eyebrow");
    PPEnableDynamicType(self.heroEyebrow, UIFontTextStyleFootnote);
    [surface addSubview:self.heroEyebrow];

    self.heroTitle = [self labelWithFont:PPFontBold(32.0) color:PrimaryTextClr lines:2];
    self.heroTitle.text = kLang(@"DeliveryCompany_Setup_Title");
    PPEnableDynamicType(self.heroTitle, UIFontTextStyleLargeTitle);
    [surface addSubview:self.heroTitle];

    self.heroSubtitle = [self labelWithFont:PPFontRegular(PPFontCallout) color:SeconderyTextClr lines:0];
    self.heroSubtitle.text = kLang(@"DeliveryCompany_Setup_Subtitle");
    PPEnableDynamicType(self.heroSubtitle, UIFontTextStyleCallout);
    [surface addSubview:self.heroSubtitle];

    [NSLayoutConstraint activateConstraints:@[
        [surface.heightAnchor constraintGreaterThanOrEqualToConstant:230.0],

        [self.heroTopGlowView.widthAnchor constraintEqualToConstant:190.0],
        [self.heroTopGlowView.heightAnchor constraintEqualToConstant:190.0],
        [self.heroTopGlowView.topAnchor constraintEqualToAnchor:surface.topAnchor constant:-50.0],
        [self.heroTopGlowView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:45.0],

        [self.heroBottomGlowView.widthAnchor constraintEqualToConstant:240.0],
        [self.heroBottomGlowView.heightAnchor constraintEqualToConstant:240.0],
        [self.heroBottomGlowView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:70.0],
        [self.heroBottomGlowView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:-65.0],

        [self.heroIconSurface.topAnchor constraintEqualToAnchor:surface.topAnchor constant:22.0],
        [self.heroIconSurface.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [self.heroIconSurface.widthAnchor constraintEqualToConstant:50.0],
        [self.heroIconSurface.heightAnchor constraintEqualToConstant:50.0],

        [self.heroIcon.centerXAnchor constraintEqualToAnchor:self.heroIconSurface.centerXAnchor],
        [self.heroIcon.centerYAnchor constraintEqualToAnchor:self.heroIconSurface.centerYAnchor],
        [self.heroIcon.widthAnchor constraintEqualToConstant:26.0],
        [self.heroIcon.heightAnchor constraintEqualToConstant:26.0],

        [self.heroStatusPill.centerYAnchor constraintEqualToAnchor:self.heroIconSurface.centerYAnchor],
        [self.heroStatusPill.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [self.heroStatusPill.heightAnchor constraintEqualToConstant:26.0],

        [self.heroStatusDot.leadingAnchor constraintEqualToAnchor:self.heroStatusPill.leadingAnchor constant:9.0],
        [self.heroStatusDot.centerYAnchor constraintEqualToAnchor:self.heroStatusPill.centerYAnchor],
        [self.heroStatusDot.widthAnchor constraintEqualToConstant:8.0],
        [self.heroStatusDot.heightAnchor constraintEqualToConstant:8.0],

        [self.heroStatusLabel.leadingAnchor constraintEqualToAnchor:self.heroStatusDot.trailingAnchor constant:6.0],
        [self.heroStatusLabel.trailingAnchor constraintEqualToAnchor:self.heroStatusPill.trailingAnchor constant:-10.0],
        [self.heroStatusLabel.centerYAnchor constraintEqualToAnchor:self.heroStatusPill.centerYAnchor],

        [self.heroEyebrow.topAnchor constraintEqualToAnchor:self.heroIconSurface.bottomAnchor constant:20.0],
        [self.heroEyebrow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [self.heroEyebrow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],

        [self.heroTitle.topAnchor constraintEqualToAnchor:self.heroEyebrow.bottomAnchor constant:6.0],
        [self.heroTitle.leadingAnchor constraintEqualToAnchor:self.heroEyebrow.leadingAnchor],
        [self.heroTitle.trailingAnchor constraintEqualToAnchor:self.heroEyebrow.trailingAnchor],

        [self.heroSubtitle.topAnchor constraintEqualToAnchor:self.heroTitle.bottomAnchor constant:10.0],
        [self.heroSubtitle.leadingAnchor constraintEqualToAnchor:self.heroEyebrow.leadingAnchor],
        [self.heroSubtitle.trailingAnchor constraintEqualToAnchor:self.heroEyebrow.trailingAnchor],
        [self.heroSubtitle.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-22.0],
    ]];

    return surface;
}

#pragma mark - 2. Active Connected Fleet Card

- (UIView *)buildConnectedFleetCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPStyleCardSurface(card, PPCornerCard);
    card.layer.borderColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.35].CGColor;
    card.layer.borderWidth = 1.5;

    // Header Tag
    UIView *activePill = [[UIView alloc] init];
    activePill.translatesAutoresizingMaskIntoConstraints = NO;
    activePill.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(activePill, 10.0);
    [card addSubview:activePill];

    UIView *activeDot = [[UIView alloc] init];
    activeDot.translatesAutoresizingMaskIntoConstraints = NO;
    activeDot.backgroundColor = [UIColor ppSuccess];
    PPApplyContinuousCorners(activeDot, 4.0);
    [activePill addSubview:activeDot];

    UILabel *activePillLabel = [self labelWithFont:PPFontBold(11.5) color:[UIColor ppSuccess] lines:1];
    PPEnableDynamicType(activePillLabel, UIFontTextStyleCaption1);
    activePillLabel.text = kLang(@"DeliveryCompany_Setup_ActiveFleet");
    [activePill addSubview:activePillLabel];

    self.connectedFleetNameLabel = [self labelWithFont:PPFontBold(18.0) color:PrimaryTextClr lines:1];
    PPEnableDynamicType(self.connectedFleetNameLabel, UIFontTextStyleTitle3);
    [card addSubview:self.connectedFleetNameLabel];

    self.connectedFleetRoleLabel = [self labelWithFont:PPFontMedium(13.0) color:SeconderyTextClr lines:1];
    PPEnableDynamicType(self.connectedFleetRoleLabel, UIFontTextStyleSubheadline);
    [card addSubview:self.connectedFleetRoleLabel];

    self.connectedFleetIDLabel = [self labelWithFont:[UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightMedium] color:AppTertiaryTextClr lines:1];
    [card addSubview:self.connectedFleetIDLabel];

    // Dashboard Fast Action
    self.connectedFleetDashboardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.connectedFleetDashboardButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectedFleetDashboardButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.connectedFleetDashboardButton, PPCornerMedium);
    [self.connectedFleetDashboardButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.connectedFleetDashboardButton.titleLabel.font = PPScaledFont(PPFontBold(16.0), UIFontTextStyleHeadline);
    [self.connectedFleetDashboardButton setTitle:kLang(@"DeliveryCompany_Setup_OpenDashboard") forState:UIControlStateNormal];
    [self.connectedFleetDashboardButton setImage:[UIImage systemImageNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"] forState:UIControlStateNormal];
    self.connectedFleetDashboardButton.tintColor = UIColor.whiteColor;
    self.connectedFleetDashboardButton.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    [self.connectedFleetDashboardButton addTarget:self action:@selector(openDashboard) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.connectedFleetDashboardButton];

    // Disconnect Link
    self.connectedFleetDisconnectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.connectedFleetDisconnectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectedFleetDisconnectButton setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
    self.connectedFleetDisconnectButton.titleLabel.font = PPScaledFont(PPFontMedium(13.5), UIFontTextStyleCallout);
    [self.connectedFleetDisconnectButton setTitle:kLang(@"DeliveryCompany_Setup_Disconnect") forState:UIControlStateNormal];
    [self.connectedFleetDisconnectButton addTarget:self action:@selector(disconnectTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.connectedFleetDisconnectButton];

    [NSLayoutConstraint activateConstraints:@[
        [activePill.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [activePill.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [activePill.heightAnchor constraintEqualToConstant:24.0],

        [activeDot.leadingAnchor constraintEqualToAnchor:activePill.leadingAnchor constant:8.0],
        [activeDot.centerYAnchor constraintEqualToAnchor:activePill.centerYAnchor],
        [activeDot.widthAnchor constraintEqualToConstant:8.0],
        [activeDot.heightAnchor constraintEqualToConstant:8.0],

        [activePillLabel.leadingAnchor constraintEqualToAnchor:activeDot.trailingAnchor constant:6.0],
        [activePillLabel.trailingAnchor constraintEqualToAnchor:activePill.trailingAnchor constant:-10.0],
        [activePillLabel.centerYAnchor constraintEqualToAnchor:activePill.centerYAnchor],

        [self.connectedFleetNameLabel.topAnchor constraintEqualToAnchor:activePill.bottomAnchor constant:12.0],
        [self.connectedFleetNameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [self.connectedFleetNameLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [self.connectedFleetRoleLabel.topAnchor constraintEqualToAnchor:self.connectedFleetNameLabel.bottomAnchor constant:4.0],
        [self.connectedFleetRoleLabel.leadingAnchor constraintEqualToAnchor:self.connectedFleetNameLabel.leadingAnchor],
        [self.connectedFleetRoleLabel.trailingAnchor constraintEqualToAnchor:self.connectedFleetNameLabel.trailingAnchor],

        [self.connectedFleetIDLabel.topAnchor constraintEqualToAnchor:self.connectedFleetRoleLabel.bottomAnchor constant:6.0],
        [self.connectedFleetIDLabel.leadingAnchor constraintEqualToAnchor:self.connectedFleetNameLabel.leadingAnchor],
        [self.connectedFleetIDLabel.trailingAnchor constraintEqualToAnchor:self.connectedFleetNameLabel.trailingAnchor],

        [self.connectedFleetDashboardButton.topAnchor constraintEqualToAnchor:self.connectedFleetIDLabel.bottomAnchor constant:16.0],
        [self.connectedFleetDashboardButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [self.connectedFleetDashboardButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [self.connectedFleetDashboardButton.heightAnchor constraintEqualToConstant:50.0],

        [self.connectedFleetDisconnectButton.topAnchor constraintEqualToAnchor:self.connectedFleetDashboardButton.bottomAnchor constant:10.0],
        [self.connectedFleetDisconnectButton.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.connectedFleetDisconnectButton.heightAnchor constraintEqualToConstant:32.0],
        [self.connectedFleetDisconnectButton.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],
    ]];

    card.hidden = YES;
    return card;
}

#pragma mark - 3. Available Companies Section (Tactile List)

- (UIView *)buildAvailableCompaniesSection {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    // Header Stack: Title + Count Badge + Refresh Button
    self.availableCompaniesHeaderStack = [[UIStackView alloc] init];
    self.availableCompaniesHeaderStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableCompaniesHeaderStack.axis = UILayoutConstraintAxisHorizontal;
    self.availableCompaniesHeaderStack.alignment = UIStackViewAlignmentCenter;
    self.availableCompaniesHeaderStack.spacing = 8.0;
    self.availableCompaniesHeaderStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [container addSubview:self.availableCompaniesHeaderStack];

    self.availableCompaniesSectionTitle = [self labelWithFont:PPFontBold(PPFontTitle3) color:PrimaryTextClr lines:1];
    self.availableCompaniesSectionTitle.text = kLang(@"DeliveryCompany_Setup_AvailableCompanies_Title");
    PPEnableDynamicType(self.availableCompaniesSectionTitle, UIFontTextStyleTitle3);
    [self.availableCompaniesHeaderStack addArrangedSubview:self.availableCompaniesSectionTitle];

    self.availableCompaniesBadge = [[UIView alloc] init];
    self.availableCompaniesBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableCompaniesBadge.backgroundColor = AppPrimaryClrWithAlpha(0.12);
    PPApplyContinuousCorners(self.availableCompaniesBadge, 10.0);
    [self.availableCompaniesHeaderStack addArrangedSubview:self.availableCompaniesBadge];

    self.availableCompaniesBadgeLabel = [self labelWithFont:PPFontBold(11.0) color:AppPrimaryClr lines:1];
    PPEnableDynamicType(self.availableCompaniesBadgeLabel, UIFontTextStyleCaption2);
    [self.availableCompaniesBadge addSubview:self.availableCompaniesBadgeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.availableCompaniesBadgeLabel.leadingAnchor constraintEqualToAnchor:self.availableCompaniesBadge.leadingAnchor constant:8.0],
        [self.availableCompaniesBadgeLabel.trailingAnchor constraintEqualToAnchor:self.availableCompaniesBadge.trailingAnchor constant:-8.0],
        [self.availableCompaniesBadgeLabel.topAnchor constraintEqualToAnchor:self.availableCompaniesBadge.topAnchor constant:3.0],
        [self.availableCompaniesBadgeLabel.bottomAnchor constraintEqualToAnchor:self.availableCompaniesBadge.bottomAnchor constant:-3.0],
    ]];

    // Spacer to push refresh button to trailing
    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:UILayoutPriorityFittingSizeLevel forAxis:UILayoutConstraintAxisHorizontal];
    [self.availableCompaniesHeaderStack addArrangedSubview:spacer];

    self.refreshDiscoveryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.refreshDiscoveryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshDiscoveryButton setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];
    self.refreshDiscoveryButton.tintColor = AppPrimaryClr;
    self.refreshDiscoveryButton.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(self.refreshDiscoveryButton, 18.0);
    self.refreshDiscoveryButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.refreshDiscoveryButton.layer.borderColor = PPHairlineColor().CGColor;
    [self.refreshDiscoveryButton addTarget:self action:@selector(refreshDiscoveryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.availableCompaniesHeaderStack addArrangedSubview:self.refreshDiscoveryButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.refreshDiscoveryButton.widthAnchor constraintEqualToConstant:36.0],
        [self.refreshDiscoveryButton.heightAnchor constraintEqualToConstant:36.0],
    ]];

    // Subtitle
    UILabel *sectionSubtitle = [self labelWithFont:PPFontRegular(13.0) color:SeconderyTextClr lines:0];
    sectionSubtitle.text = kLang(@"DeliveryCompany_Setup_AvailableCompanies_Subtitle");
    PPEnableDynamicType(sectionSubtitle, UIFontTextStyleFootnote);
    [container addSubview:sectionSubtitle];

    // Vertical Cards Stack
    self.cardsStackView = [[UIStackView alloc] init];
    self.cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardsStackView.axis = UILayoutConstraintAxisVertical;
    self.cardsStackView.spacing = PPSpaceMD;
    self.cardsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [container addSubview:self.cardsStackView];

    // Empty State Card
    self.emptyDiscoveredView = [self buildEmptyDiscoveredView];

    [NSLayoutConstraint activateConstraints:@[
        [self.availableCompaniesHeaderStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.availableCompaniesHeaderStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.availableCompaniesHeaderStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [sectionSubtitle.topAnchor constraintEqualToAnchor:self.availableCompaniesHeaderStack.bottomAnchor constant:4.0],
        [sectionSubtitle.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [sectionSubtitle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [self.cardsStackView.topAnchor constraintEqualToAnchor:sectionSubtitle.bottomAnchor constant:12.0],
        [self.cardsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.cardsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.cardsStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)buildEmptyDiscoveredView {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(card, PPCornerCard);

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppTertiaryTextClr;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];

    UILabel *title = [self labelWithFont:PPFontBold(15.0) color:PrimaryTextClr lines:1];
    PPEnableDynamicType(title, UIFontTextStyleHeadline);
    title.text = kLang(@"DeliveryCompany_Setup_EmptyDiscoveredTitle");
    title.textAlignment = NSTextAlignmentCenter;
    [card addSubview:title];

    UILabel *sub = [self labelWithFont:PPFontRegular(12.5) color:SeconderyTextClr lines:0];
    PPEnableDynamicType(sub, UIFontTextStyleFootnote);
    sub.text = kLang(@"DeliveryCompany_Setup_EmptyDiscoveredSubtitle");
    sub.textAlignment = NSTextAlignmentCenter;
    [card addSubview:sub];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:22.0],
        [icon.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:32.0],
        [icon.heightAnchor constraintEqualToConstant:32.0],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:10.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [sub.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-22.0],
    ]];

    return card;
}

#pragma mark - 4. Manual Entry Accordion Card

- (UIView *)buildManualAccordionCard {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPStyleCardSurface(surface, PPCornerCard);

    UIStackView *accordionStack = [[UIStackView alloc] init];
    accordionStack.translatesAutoresizingMaskIntoConstraints = NO;
    accordionStack.axis = UILayoutConstraintAxisVertical;
    accordionStack.spacing = 0;
    accordionStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [surface addSubview:accordionStack];

    // Header Trigger Control
    self.manualHeaderControl = [[UIControl alloc] init];
    self.manualHeaderControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.manualHeaderControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.manualHeaderControl addTarget:self action:@selector(toggleManualAccordion) forControlEvents:UIControlEventTouchUpInside];
    [accordionStack addArrangedSubview:self.manualHeaderControl];

    UIImageView *keyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"key.horizontal.fill"]];
    keyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    keyIcon.tintColor = AppPrimaryClr;
    keyIcon.contentMode = UIViewContentModeScaleAspectFit;
    keyIcon.userInteractionEnabled = NO;
    [self.manualHeaderControl addSubview:keyIcon];

    self.manualHeaderTitle = [self labelWithFont:PPFontBold(15.0) color:PrimaryTextClr lines:1];
    self.manualHeaderTitle.text = kLang(@"DeliveryCompany_Setup_ManualEntry_Header");
    PPEnableDynamicType(self.manualHeaderTitle, UIFontTextStyleHeadline);
    [self.manualHeaderControl addSubview:self.manualHeaderTitle];

    self.manualHeaderSubtitle = [self labelWithFont:PPFontRegular(12.5) color:SeconderyTextClr lines:1];
    self.manualHeaderSubtitle.text = kLang(@"DeliveryCompany_Setup_ManualEntry_Subtitle");
    PPEnableDynamicType(self.manualHeaderSubtitle, UIFontTextStyleCaption1);
    [self.manualHeaderControl addSubview:self.manualHeaderSubtitle];

    self.manualChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    self.manualChevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.manualChevron.tintColor = AppTertiaryTextClr;
    self.manualChevron.contentMode = UIViewContentModeScaleAspectFit;
    self.manualChevron.userInteractionEnabled = NO;
    [self.manualHeaderControl addSubview:self.manualChevron];

    // Collapsible Content
    self.manualContentContainer = [[UIView alloc] init];
    self.manualContentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.manualContentContainer.clipsToBounds = YES;
    self.manualContentContainer.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [accordionStack addArrangedSubview:self.manualContentContainer];

    // Text Field Surface
    UIView *fieldSurface = [[UIView alloc] init];
    fieldSurface.translatesAutoresizingMaskIntoConstraints = NO;
    fieldSurface.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.85];
    PPApplyContinuousCorners(fieldSurface, PPCornerMedium);
    fieldSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    fieldSurface.layer.borderColor = PPHairlineColor().CGColor;
    [self.manualContentContainer addSubview:fieldSurface];

    UIImageView *hashIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"number"]];
    hashIcon.translatesAutoresizingMaskIntoConstraints = NO;
    hashIcon.tintColor = AppTertiaryTextClr;
    hashIcon.contentMode = UIViewContentModeScaleAspectFit;
    [fieldSurface addSubview:hashIcon];

    self.companyIDField = [[UITextField alloc] init];
    self.companyIDField.translatesAutoresizingMaskIntoConstraints = NO;
    self.companyIDField.font = PPFontMedium(PPFontBody);
    self.companyIDField.textColor = PrimaryTextClr;
    self.companyIDField.placeholder = kLang(@"DeliveryCompany_Setup_CompanyIDPlaceholder");
    self.companyIDField.textAlignment = Language.alignmentForCurrentLanguage;
    self.companyIDField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.companyIDField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.companyIDField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.companyIDField.returnKeyType = UIReturnKeyDone;
    self.companyIDField.delegate = self;
    [self.companyIDField addTarget:self action:@selector(textFieldDidChange) forControlEvents:UIControlEventEditingChanged];
    PPEnableDynamicTypeForTextField(self.companyIDField, UIFontTextStyleBody);
    [fieldSurface addSubview:self.companyIDField];

    // "Paste" Fast Action Button
    self.pasteClipboardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pasteClipboardButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.pasteClipboardButton.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    PPApplyContinuousCorners(self.pasteClipboardButton, 8.0);
    [self.pasteClipboardButton setTitle:kLang(@"DeliveryCompany_Setup_PasteAction") forState:UIControlStateNormal];
    [self.pasteClipboardButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    self.pasteClipboardButton.titleLabel.font = PPScaledFont(PPFontBold(11.5), UIFontTextStyleCaption1);
    [self.pasteClipboardButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    self.pasteClipboardButton.tintColor = AppPrimaryClr;
    [self.pasteClipboardButton addTarget:self action:@selector(pasteClipboardTapped) forControlEvents:UIControlEventTouchUpInside];
    [fieldSurface addSubview:self.pasteClipboardButton];

    UILabel *hintLabel = [self labelWithFont:PPFontRegular(12.0) color:SeconderyTextClr lines:0];
    hintLabel.text = kLang(@"DeliveryCompany_Setup_ManualEntry_Hint");
    PPEnableDynamicType(hintLabel, UIFontTextStyleFootnote);
    [self.manualContentContainer addSubview:hintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accordionStack.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [accordionStack.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [accordionStack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [accordionStack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        // Header
        [self.manualHeaderControl.heightAnchor constraintEqualToConstant:68.0],

        [keyIcon.leadingAnchor constraintEqualToAnchor:self.manualHeaderControl.leadingAnchor constant:16.0],
        [keyIcon.centerYAnchor constraintEqualToAnchor:self.manualHeaderControl.centerYAnchor],
        [keyIcon.widthAnchor constraintEqualToConstant:22.0],
        [keyIcon.heightAnchor constraintEqualToConstant:22.0],

        [self.manualHeaderTitle.topAnchor constraintEqualToAnchor:self.manualHeaderControl.topAnchor constant:14.0],
        [self.manualHeaderTitle.leadingAnchor constraintEqualToAnchor:keyIcon.trailingAnchor constant:12.0],
        [self.manualHeaderTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.manualChevron.leadingAnchor constant:-10.0],

        [self.manualHeaderSubtitle.topAnchor constraintEqualToAnchor:self.manualHeaderTitle.bottomAnchor constant:3.0],
        [self.manualHeaderSubtitle.leadingAnchor constraintEqualToAnchor:self.manualHeaderTitle.leadingAnchor],
        [self.manualHeaderSubtitle.trailingAnchor constraintEqualToAnchor:self.manualHeaderTitle.trailingAnchor],

        [self.manualChevron.trailingAnchor constraintEqualToAnchor:self.manualHeaderControl.trailingAnchor constant:-18.0],
        [self.manualChevron.centerYAnchor constraintEqualToAnchor:self.manualHeaderControl.centerYAnchor],
        [self.manualChevron.widthAnchor constraintEqualToConstant:16.0],
        [self.manualChevron.heightAnchor constraintEqualToConstant:16.0],

        // Content
        [fieldSurface.topAnchor constraintEqualToAnchor:self.manualContentContainer.topAnchor constant:2.0],
        [fieldSurface.leadingAnchor constraintEqualToAnchor:self.manualContentContainer.leadingAnchor constant:16.0],
        [fieldSurface.trailingAnchor constraintEqualToAnchor:self.manualContentContainer.trailingAnchor constant:-16.0],
        [fieldSurface.heightAnchor constraintEqualToConstant:56.0],

        [hashIcon.leadingAnchor constraintEqualToAnchor:fieldSurface.leadingAnchor constant:14.0],
        [hashIcon.centerYAnchor constraintEqualToAnchor:fieldSurface.centerYAnchor],
        [hashIcon.widthAnchor constraintEqualToConstant:18.0],
        [hashIcon.heightAnchor constraintEqualToConstant:18.0],

        [self.companyIDField.leadingAnchor constraintEqualToAnchor:hashIcon.trailingAnchor constant:10.0],
        [self.companyIDField.trailingAnchor constraintEqualToAnchor:self.pasteClipboardButton.leadingAnchor constant:-8.0],
        [self.companyIDField.centerYAnchor constraintEqualToAnchor:fieldSurface.centerYAnchor],

        [self.pasteClipboardButton.trailingAnchor constraintEqualToAnchor:fieldSurface.trailingAnchor constant:-10.0],
        [self.pasteClipboardButton.centerYAnchor constraintEqualToAnchor:fieldSurface.centerYAnchor],
        [self.pasteClipboardButton.heightAnchor constraintEqualToConstant:32.0],

        [hintLabel.topAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor constant:10.0],
        [hintLabel.leadingAnchor constraintEqualToAnchor:fieldSurface.leadingAnchor],
        [hintLabel.trailingAnchor constraintEqualToAnchor:fieldSurface.trailingAnchor],
        [hintLabel.bottomAnchor constraintEqualToAnchor:self.manualContentContainer.bottomAnchor constant:-16.0],
    ]];

    // Initially collapsed if we have discovered companies, or expanded if zero
    self.isManualExpanded = NO;
    self.manualContentContainer.hidden = YES;

    return surface;
}

#pragma mark - 5. Bottom Primary Action Bar

- (UIView *)buildBottomActionBar {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.primaryActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.primaryActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryActionButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.primaryActionButton, PPCornerMedium);
    self.primaryActionButton.layer.shadowColor = AppPrimaryClrWithAlpha(0.26).CGColor;
    self.primaryActionButton.layer.shadowOpacity = 1.0;
    self.primaryActionButton.layer.shadowRadius = PPShadowButtonRadius;
    self.primaryActionButton.layer.shadowOffset = CGSizeMake(0.0, PPShadowButtonOffsetY);
    [self.primaryActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.primaryActionButton.titleLabel.font = PPScaledFont(PPFontBold(17.0), UIFontTextStyleHeadline);
    self.primaryActionButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.primaryActionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.primaryActionButton.titleLabel.minimumScaleFactor = 0.8;
    [self.primaryActionButton addTarget:self action:@selector(primaryActionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [surface addSubview:self.primaryActionButton];

    self.primarySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.primarySpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.primarySpinner.color = UIColor.whiteColor;
    self.primarySpinner.hidesWhenStopped = YES;
    [self.primaryActionButton addSubview:self.primarySpinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.primaryActionButton.topAnchor constraintEqualToAnchor:surface.topAnchor constant:4.0],
        [self.primaryActionButton.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [self.primaryActionButton.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [self.primaryActionButton.heightAnchor constraintEqualToConstant:56.0],
        [self.primaryActionButton.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-4.0],

        [self.primarySpinner.centerXAnchor constraintEqualToAnchor:self.primaryActionButton.centerXAnchor],
        [self.primarySpinner.centerYAnchor constraintEqualToAnchor:self.primaryActionButton.centerYAnchor],
    ]];

    return surface;
}

#pragma mark - State Management & Presentation

- (void)renderStateAnimated:(BOOL)animated {
    PPDeliveryCompanyProfile *verified = PPDeliveryCompanyService.shared.verifiedProfile;
    BOOL isConnected = verified.companyID.length > 0;
    NSArray<PPDeliveryCompanyProfile *> *discovered = PPDeliveryCompanyService.shared.discoveredProfiles ?: @[];

    // 1. Update Hero Status & Text
    if (isConnected) {
        self.heroStatusPill.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        self.heroStatusDot.backgroundColor = [UIColor ppSuccess];
        self.heroStatusLabel.text = kLang(@"DeliveryCompany_Setup_ActiveFleet");
        self.heroStatusLabel.textColor = [UIColor ppSuccess];
        self.heroTitle.text = kLang(@"DeliveryCompany_Setup_ConnectedHeroTitle");
        NSString *companyName = verified.name.length ? verified.name : verified.legalName;
        self.heroSubtitle.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_Connected_Format"),
                                  companyName.length ? companyName : verified.companyID,
                                  PPDeliveryCompanyRoleDisplayName(verified.role)];
    } else if (self.isDiscoveringMemberships) {
        self.heroStatusPill.backgroundColor = AppPrimaryClrWithAlpha(0.10);
        self.heroStatusDot.backgroundColor = AppPrimaryClr;
        self.heroStatusLabel.text = kLang(@"DeliveryCompany_Setup_Scanning");
        self.heroStatusLabel.textColor = AppPrimaryClr;
        self.heroTitle.text = kLang(@"DeliveryCompany_Setup_Title");
        self.heroSubtitle.text = kLang(@"DeliveryCompany_Setup_DiscoveryLoading");
    } else if (discovered.count > 0) {
        self.heroStatusPill.backgroundColor = AppPrimaryClrWithAlpha(0.10);
        self.heroStatusDot.backgroundColor = AppPrimaryClr;
        self.heroStatusLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_AvailableCompanies_Count_Format"), (unsigned long)discovered.count];
        self.heroStatusLabel.textColor = AppPrimaryClr;
        self.heroTitle.text = kLang(@"DeliveryCompany_Setup_TitleAvailable");
        self.heroSubtitle.text = kLang(@"DeliveryCompany_Setup_AvailableCompanies_Subtitle");
    } else {
        self.heroStatusPill.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.9];
        self.heroStatusDot.backgroundColor = AppTertiaryTextClr;
        self.heroStatusLabel.text = kLang(@"DeliveryCompany_Setup_NotLinked");
        self.heroStatusLabel.textColor = SeconderyTextClr;
        self.heroTitle.text = kLang(@"DeliveryCompany_Setup_Title");
        self.heroSubtitle.text = kLang(@"DeliveryCompany_Setup_Subtitle");
    }

    // 2. Connected Fleet VIP Card
    if (isConnected) {
        self.connectedFleetCard.hidden = NO;
        NSString *companyName = verified.name.length ? verified.name : verified.legalName;
        self.connectedFleetNameLabel.text = companyName.length ? companyName : verified.companyID;
        self.connectedFleetRoleLabel.text = [NSString stringWithFormat:@"%@ • %@",
                                             PPDeliveryCompanyRoleDisplayName(verified.role),
                                             PPDeliveryCompanyStatusDisplayName(verified.status)];
        self.connectedFleetIDLabel.text = [NSString stringWithFormat:@"ID: %@", verified.companyID];
    } else {
        self.connectedFleetCard.hidden = YES;
    }

    // 3. Render Available Companies List or Skeletons
    [self rebuildDiscoveredCompaniesList];

    // 4. Update Primary Button Title & Action State
    [self updatePrimaryActionButtonState];
}

- (void)rebuildDiscoveredCompaniesList {
    // Clear old card views from stack
    for (UIView *v in self.cardsStackView.arrangedSubviews) {
        [self.cardsStackView removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.cardViews removeAllObjects];
    [self.skeletonViews removeAllObjects];

    if (self.isDiscoveringMemberships) {
        self.emptyDiscoveredView.hidden = YES;
        self.availableCompaniesBadgeLabel.text = @"…";

        // Show 2 Shimmer Skeletons
        for (NSInteger i = 0; i < 2; i++) {
            PPDeliveryCompanySkeletonCardView *skeleton = [[PPDeliveryCompanySkeletonCardView alloc] init];
            [self.cardsStackView addArrangedSubview:skeleton];
            [self.skeletonViews addObject:skeleton];
        }
        return;
    }

    NSArray<PPDeliveryCompanyProfile *> *profiles = PPDeliveryCompanyService.shared.discoveredProfiles ?: @[];
    PPDeliveryCompanyProfile *verified = PPDeliveryCompanyService.shared.verifiedProfile;

    self.availableCompaniesBadgeLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)profiles.count];

    if (profiles.count == 0) {
        [self.cardsStackView addArrangedSubview:self.emptyDiscoveredView];
        self.emptyDiscoveredView.hidden = NO;
        // Auto-expand manual accordion if empty and not connected
        if (!self.isManualExpanded && verified.companyID.length == 0) {
            [self setManualExpanded:YES animated:YES];
        }
        return;
    }

    self.emptyDiscoveredView.hidden = YES;

    // Ensure selectedCompanyID has a valid default
    if (self.selectedCompanyID.length == 0) {
        if (verified.companyID.length > 0) {
            self.selectedCompanyID = verified.companyID;
        } else if (profiles.count > 0) {
            self.selectedCompanyID = profiles.firstObject.companyID;
        }
    }

    __weak typeof(self) weakSelf = self;
    for (PPDeliveryCompanyProfile *profile in profiles) {
        PPDeliveryCompanyCardView *card = [[PPDeliveryCompanyCardView alloc] initWithProfile:profile];
        BOOL isSelected = [profile.companyID isEqualToString:self.selectedCompanyID];
        BOOL isConnected = [profile.companyID isEqualToString:verified.companyID];

        card.isCardSelected = isSelected;
        card.isCurrentlyConnected = isConnected;

        card.onCardSelected = ^(PPDeliveryCompanyCardView *c) {
            [weakSelf handleCardSelected:c];
        };

        card.onCopyIDRequested = ^(PPDeliveryCompanyCardView *c, NSString *cid) {
            [weakSelf copyCompanyIDToClipboard:cid];
        };

        [self.cardsStackView addArrangedSubview:card];
        [self.cardViews addObject:card];
    }
}

- (void)handleCardSelected:(PPDeliveryCompanyCardView *)card {
    NSString *companyID = card.profile.companyID;
    BOOL wasAlreadySelected = [self.selectedCompanyID isEqualToString:companyID];

    self.selectedCompanyID = companyID;
    self.companyIDField.text = companyID;

    // Update all cards selection state with spring
    for (PPDeliveryCompanyCardView *c in self.cardViews) {
        c.isCardSelected = [c.profile.companyID isEqualToString:companyID];
    }

    [self updatePrimaryActionButtonState];

    // Double tap or re-tapping selected card directly executes connection
    if (wasAlreadySelected) {
        [self primaryActionButtonTapped];
    }
}

- (void)updatePrimaryActionButtonState {
    PPDeliveryCompanyProfile *verified = PPDeliveryCompanyService.shared.verifiedProfile;
    PPDeliveryCompanyProfile *selectedProfile = [self profileForSelectedID];

    if (self.isConnectingAction) {
        self.primaryActionButton.enabled = NO;
        self.primaryActionButton.titleLabel.alpha = 0.0;
        [self.primarySpinner startAnimating];
        return;
    }

    self.primaryActionButton.enabled = YES;
    self.primaryActionButton.titleLabel.alpha = 1.0;
    [self.primarySpinner stopAnimating];

    if (selectedProfile != nil) {
        if ([selectedProfile.companyID isEqualToString:verified.companyID]) {
            [self.primaryActionButton setTitle:kLang(@"DeliveryCompany_Setup_OpenSelectedDashboard") forState:UIControlStateNormal];
        } else {
            NSString *name = selectedProfile.name.length ? selectedProfile.name : selectedProfile.companyID;
            NSString *title = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_ConnectToCompany_Format"), name];
            [self.primaryActionButton setTitle:title forState:UIControlStateNormal];
        }
    } else {
        NSString *manual = [self.companyIDField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (manual.length > 0) {
            [self.primaryActionButton setTitle:kLang(@"DeliveryCompany_Setup_Connect") forState:UIControlStateNormal];
        } else if (verified.companyID.length > 0) {
            [self.primaryActionButton setTitle:kLang(@"DeliveryCompany_Setup_OpenDashboard") forState:UIControlStateNormal];
        } else {
            [self.primaryActionButton setTitle:kLang(@"DeliveryCompany_Setup_ChooseCompany") forState:UIControlStateNormal];
        }
    }
}

- (PPDeliveryCompanyProfile * _Nullable)profileForSelectedID {
    if (self.selectedCompanyID.length == 0) return nil;
    NSArray<PPDeliveryCompanyProfile *> *profiles = PPDeliveryCompanyService.shared.discoveredProfiles ?: @[];
    for (PPDeliveryCompanyProfile *p in profiles) {
        if ([p.companyID isEqualToString:self.selectedCompanyID]) {
            return p;
        }
    }
    if ([PPDeliveryCompanyService.shared.verifiedProfile.companyID isEqualToString:self.selectedCompanyID]) {
        return PPDeliveryCompanyService.shared.verifiedProfile;
    }
    return nil;
}

#pragma mark - Actions

- (void)primaryActionButtonTapped {
    [PPFunc pp_playTapEffect];

    PPDeliveryCompanyProfile *verified = PPDeliveryCompanyService.shared.verifiedProfile;
    PPDeliveryCompanyProfile *selectedProfile = [self profileForSelectedID];

    // If selected is already active & verified, open dashboard directly
    if (selectedProfile && [selectedProfile.companyID isEqualToString:verified.companyID]) {
        [self openDashboard];
        return;
    }

    // If selected from discovered profiles, activate instantly!
    if (selectedProfile != nil) {
        [PPDeliveryCompanyService.shared storeVerifiedProfile:selectedProfile];
        [self renderStateAnimated:YES];

        JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
        hud.textLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_Connected_Format"),
                              selectedProfile.name.length ? selectedProfile.name : selectedProfile.companyID,
                              PPDeliveryCompanyRoleDisplayName(selectedProfile.role)];
        [hud showInView:self.view];
        [hud dismissAfterDelay:1.2];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openDashboard];
        });
        return;
    }

    // Manual ID flow
    NSString *manualID = [self.companyIDField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (manualID.length == 0) {
        if (verified.companyID.length > 0) {
            [self openDashboard];
            return;
        }
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"DeliveryCompany_Setup_CompanyIDRequired")
                          subtitle:kLang(@"DeliveryCompany_Setup_ManualEntry_Hint")];
        return;
    }

    // Verify manual ID through backend
    [self.view endEditing:YES];
    self.isConnectingAction = YES;
    [self updatePrimaryActionButtonState];

    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared verifyAndStoreCompanyID:manualID completion:^(PPDeliveryCompanyProfile * _Nullable profile, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isConnectingAction = NO;
        [self updatePrimaryActionButtonState];

        if (error || !profile) {
            [PPAlertHelper showErrorIn:self
                                 title:kLang(@"DeliveryCompany_Setup_UnableToConnect")
                              subtitle:error.localizedDescription];
            return;
        }

        self.selectedCompanyID = profile.companyID;
        [self renderStateAnimated:YES];
        [PPAlertHelper showSuccessIn:self
                               title:kLang(@"DeliveryCompany_Setup_Connected")
                            subtitle:kLang(@"DeliveryCompany_Setup_ConnectedSubtitle")];
        [self openDashboard];
    }];
}

- (void)handlePullToRefresh {
    [PPFunc pp_playTapEffect];
    [self refreshAutoDiscoveryForce:YES];
}

- (void)refreshDiscoveryTapped {
    [PPFunc pp_playTapEffect];
    // Rotate refresh icon
    if (!PPMotionReduced()) {
        [UIView animateWithDuration:0.5 animations:^{
            self.refreshDiscoveryButton.transform = CGAffineTransformMakeRotation(M_PI);
        } completion:^(__unused BOOL finished) {
            self.refreshDiscoveryButton.transform = CGAffineTransformIdentity;
        }];
    }
    [self refreshAutoDiscoveryForce:YES];
}

- (void)refreshAutoDiscoveryForce:(BOOL)force {
    if (!force && self.didAttemptAutoDiscovery) {
        return;
    }
    self.didAttemptAutoDiscovery = YES;
    self.isDiscoveringMemberships = YES;
    [self renderStateAnimated:NO];

    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isDiscoveringMemberships = NO;
        [self.refreshControl endRefreshing];

        if (error) {
            [self renderStateAnimated:YES];
            return;
        }

        // Auto select first company if none selected
        if (self.selectedCompanyID.length == 0 && profiles.count > 0) {
            self.selectedCompanyID = profiles.firstObject.companyID;
        }

        [self renderStateAnimated:YES];
    }];
}

- (void)copyCompanyIDToClipboard:(NSString *)companyID {
    if (companyID.length == 0) return;
    UIPasteboard.generalPasteboard.string = companyID;

    JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
    hud.textLabel.text = kLang(@"DeliveryCompany_Setup_CopiedToClipboard");
    [hud showInView:self.view];
    [hud dismissAfterDelay:1.2];
}

- (void)pasteClipboardTapped {
    [PPFunc pp_playTapEffect];
    NSString *pasteString = UIPasteboard.generalPasteboard.string;
    NSString *cleaned = [pasteString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleaned.length > 0) {
        self.companyIDField.text = cleaned;
        self.selectedCompanyID = nil; // Clear card selection to focus manual input
        for (PPDeliveryCompanyCardView *c in self.cardViews) {
            c.isCardSelected = NO;
        }
        [self updatePrimaryActionButtonState];

        JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
        hud.textLabel.text = cleaned;
        [hud showInView:self.view];
        [hud dismissAfterDelay:1.0];
    }
}

- (void)toggleManualAccordion {
    [PPFunc pp_playTapEffect];
    [self setManualExpanded:!self.isManualExpanded animated:YES];
}

- (void)setManualExpanded:(BOOL)expanded animated:(BOOL)animated {
    _isManualExpanded = expanded;
    self.manualContentContainer.hidden = !expanded;

    void (^changes)(void) = ^{
        self.manualChevron.transform = expanded ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };

    if (animated && !PPMotionReduced()) {
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)disconnectTapped {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"DeliveryCompany_Setup_DisconnectTitle")
                             subtitle:kLang(@"DeliveryCompany_Setup_DisconnectSubtitle")
                          placeholder:nil
                        confirmButton:kLang(@"DeliveryCompany_Setup_Disconnect")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{
        [PPDeliveryCompanyService.shared disconnectCompany];
        weakSelf.selectedCompanyID = nil;
        [weakSelf renderStateAnimated:YES];
    } cancelBlock:nil];
}

- (void)openDashboard {
    PPDeliveryCompanyDashboardViewController *controller = [[PPDeliveryCompanyDashboardViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Text Field Delegate

- (void)textFieldDidChange {
    NSString *text = [self.companyIDField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0) {
        // Deselect cards if user is typing custom ID
        self.selectedCompanyID = nil;
        for (PPDeliveryCompanyCardView *c in self.cardViews) {
            c.isCardSelected = NO;
        }
    }
    [self updatePrimaryActionButtonState];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self primaryActionButtonTapped];
    return YES;
}

#pragma mark - Helper

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

#pragma mark - Motion & Entrance Choreography

- (void)prepareEntrance {
    if (PPMotionReduced()) return;
    self.heroView.alpha = 0.0;
    self.heroView.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.availableCompaniesContainer.alpha = 0.0;
    self.availableCompaniesContainer.transform = CGAffineTransformMakeTranslation(0, 18.0);
    self.manualAccordionCard.alpha = 0.0;
    self.manualAccordionCard.transform = CGAffineTransformMakeTranslation(0, 22.0);
}

- (void)runEntranceIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;

    if (PPMotionReduced()) {
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
        self.availableCompaniesContainer.alpha = 1.0;
        self.availableCompaniesContainer.transform = CGAffineTransformIdentity;
        self.manualAccordionCard.alpha = 1.0;
        self.manualAccordionCard.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.44
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.50
                          delay:0.06
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.availableCompaniesContainer.alpha = 1.0;
        self.availableCompaniesContainer.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.52
                          delay:0.12
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.manualAccordionCard.alpha = 1.0;
        self.manualAccordionCard.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
