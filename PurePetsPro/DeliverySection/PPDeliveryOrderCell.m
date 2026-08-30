//
//  PPDeliveryOrderCell.m
//  PurePetsPro
//
//  Premium minimal delivery order cell with calmer hierarchy and stronger amount focus.
//

#import "PPDeliveryOrderCell.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryManager.h"

NSString * const PPDeliveryOrderCellIdentifier = @"PPDeliveryOrderCell";

static CGFloat const kCardRadius = 28.0;
static CGFloat const kHorizontalInset = 16.0;
static CGFloat const kVerticalInset = 12.0;
static CGFloat const kInnerPadding = 18.0;
static CGFloat const kKindBadgeSize = 34.0;
static CGFloat const kStatusHeight = 24.0;
static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

@interface PPDeliveryOrderCell ()

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *accentOrbView;
@property (nonatomic, strong) UIView *bottomOrbView;
@property (nonatomic, strong) UIView *kindBadgeView;
@property (nonatomic, strong) UIImageView *typeIconView;

@property (nonatomic, strong) UILabel *orderNumberLabel;
@property (nonatomic, strong) UIView *statusPill;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) UILabel *customerNameLabel;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UIView *branchBadgeView;
@property (nonatomic, strong) UIImageView *branchIconView;
@property (nonatomic, strong) UILabel *branchLabel;
@property (nonatomic, strong) UILabel *metaLabel;

@property (nonatomic, strong) UIStackView *amountStack;
@property (nonatomic, strong) UIStackView *paymentRow;
@property (nonatomic, strong) UIView *paymentDotView;
@property (nonatomic, strong) UILabel *paymentLabel;
@property (nonatomic, strong) UILabel *totalAmountLabel;

@property (nonatomic, strong) UIView *disclosureContainer;
@property (nonatomic, strong) UIImageView *chevronImageView;

@end

@implementation PPDeliveryOrderCell

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

+ (CGFloat)preferredHeight {
    return 198.0;
}

#pragma mark - Setup

- (void)setupUI {
    self.backgroundColor = AppClearClr;
    self.contentView.backgroundColor = AppClearClr;
 
    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.layer.cornerRadius = kCardRadius;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.layer.shadowColor = AppShadowColor.CGColor;
    _cardView.layer.shadowOpacity = 0.09;
    _cardView.layer.shadowRadius = 24.0;
    _cardView.layer.shadowOffset = CGSizeMake(0, 12);
    [self.contentView addSubview:_cardView];

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = [UIColor ppSurface];
    _surfaceView.clipsToBounds = YES;
    _surfaceView.layer.cornerRadius = kCardRadius;
    _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _surfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    [_cardView addSubview:_surfaceView];

    _accentOrbView = [[UIView alloc] init];
    _accentOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentOrbView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    _accentOrbView.alpha = 1.0;
    _accentOrbView.layer.cornerRadius = 54.0;
    [_surfaceView addSubview:_accentOrbView];

    _bottomOrbView = [[UIView alloc] init];
    _bottomOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomOrbView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.04];
    _bottomOrbView.alpha = 1.0;
    _bottomOrbView.layer.cornerRadius = 44.0;
    [_surfaceView addSubview:_bottomOrbView];

    _kindBadgeView = [[UIView alloc] init];
    _kindBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _kindBadgeView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    _kindBadgeView.layer.cornerRadius = kKindBadgeSize / 2.0;
    _kindBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    _kindBadgeView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _kindBadgeView.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.12].CGColor;
    [_surfaceView addSubview:_kindBadgeView];

    _typeIconView = [[UIImageView alloc] init];
    _typeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _typeIconView.contentMode = UIViewContentModeScaleAspectFit;
    _typeIconView.tintColor = AppPrimaryClr;
    [_kindBadgeView addSubview:_typeIconView];

    _orderNumberLabel = [self labelWithFont:[UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold]
                                      color:[AppPrimaryClr colorWithAlphaComponent:0.92]];
    _orderNumberLabel.adjustsFontSizeToFitWidth = YES;
    _orderNumberLabel.minimumScaleFactor = 0.82;
    _orderNumberLabel.numberOfLines = 2;
    _statusPill = [[UIView alloc] init];
    _statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    _statusPill.layer.cornerRadius = kStatusHeight / 2.0;
    _statusPill.layer.cornerCurve = kCACornerCurveContinuous;
    _statusPill.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [_surfaceView addSubview:_statusPill];

    _statusLabel = [self labelWithFont:PPFontBold(11) color:[UIColor ppSuccess]];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_statusPill addSubview:_statusLabel];

    _customerNameLabel = [self labelWithFont:PPFontBold(18) color:PrimaryTextClr];
    _customerNameLabel.numberOfLines = 1;

    _addressLabel = [self labelWithFont:PPFontRegular(13) color:[SeconderyTextClr colorWithAlphaComponent:0.92]];
    _addressLabel.numberOfLines = 2;

    _branchBadgeView = [[UIView alloc] init];
    _branchBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _branchBadgeView.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.10];
    _branchBadgeView.layer.cornerRadius = 14.0;
    _branchBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    _branchBadgeView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _branchBadgeView.layer.borderColor = [[UIColor ppWarning] colorWithAlphaComponent:0.16].CGColor;
    [_surfaceView addSubview:_branchBadgeView];

    _branchIconView = [[UIImageView alloc] init];
    _branchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _branchIconView.contentMode = UIViewContentModeScaleAspectFit;
    _branchIconView.tintColor = [UIColor ppWarning];
    UIImageSymbolConfiguration *branchIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
    _branchIconView.image = [[UIImage systemImageNamed:@"building.2.fill"] imageWithConfiguration:branchIconConfig];
    [_branchBadgeView addSubview:_branchIconView];

    _branchLabel = [self labelWithFont:PPFontBold(11) color:[UIColor ppWarning]];
    _branchLabel.numberOfLines = 2;
    _branchLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [_branchBadgeView addSubview:_branchLabel];

    _metaLabel = [self labelWithFont:PPFontMedium(12) color:[SeconderyTextClr colorWithAlphaComponent:0.82]];
    _metaLabel.numberOfLines = 1;

    _paymentDotView = [[UIView alloc] init];
    _paymentDotView.translatesAutoresizingMaskIntoConstraints = NO;
    _paymentDotView.layer.cornerRadius = 3.0;

    _paymentLabel = [self labelWithFont:PPFontBold(11) color:AppPrimaryClr];
    _paymentLabel.textAlignment = NSTextAlignmentRight;

    _paymentRow = [[UIStackView alloc] initWithArrangedSubviews:@[_paymentDotView, _paymentLabel]];
    _paymentRow.translatesAutoresizingMaskIntoConstraints = NO;
    _paymentRow.axis = UILayoutConstraintAxisHorizontal;
    _paymentRow.alignment = UIStackViewAlignmentCenter;
    _paymentRow.spacing = 6.0;
 
    _totalAmountLabel = [self labelWithFont:PPFontBold(20) color:PrimaryTextClr];
    _totalAmountLabel.textAlignment = NSTextAlignmentRight;
    _totalAmountLabel.adjustsFontSizeToFitWidth = YES;
    _totalAmountLabel.minimumScaleFactor = 0.72;

    _amountStack = [[UIStackView alloc] initWithArrangedSubviews:@[_paymentRow, _totalAmountLabel]];
    _amountStack.translatesAutoresizingMaskIntoConstraints = NO;
    _amountStack.axis = UILayoutConstraintAxisVertical;
    _amountStack.alignment = UIStackViewAlignmentTrailing;
    _amountStack.spacing = 4.0;
     [_surfaceView addSubview:_amountStack];

    _disclosureContainer = [[UIView alloc] init];
    _disclosureContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _disclosureContainer.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.06];
    _disclosureContainer.layer.cornerRadius = 14.0;
    _disclosureContainer.layer.cornerCurve = kCACornerCurveContinuous;
    [_surfaceView addSubview:_disclosureContainer];

    _chevronImageView = [[UIImageView alloc] init];
    _chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
    _chevronImageView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.45];
    NSString *chevronName = PPIsRL ? @"chevron.left" : @"chevron.right";
    UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    _chevronImageView.image = [[UIImage systemImageNamed:chevronName] imageWithConfiguration:chevronConfig];
    [_disclosureContainer addSubview:_chevronImageView];

    for (UIView *view in @[
        _orderNumberLabel,
        _customerNameLabel,
        _addressLabel,
        _metaLabel
    ]) {
        [_surfaceView addSubview:view];
    }

    [self setupConstraints];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
     return label;
}

- (void)setupConstraints {
    UIView *card = self.cardView;
    UIView *surface = self.surfaceView;

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kVerticalInset],
        [card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kHorizontalInset],
        [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kHorizontalInset],
        [card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kVerticalInset],

        [surface.topAnchor constraintEqualToAnchor:card.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],

        [_accentOrbView.widthAnchor constraintEqualToConstant:108.0],
        [_accentOrbView.heightAnchor constraintEqualToConstant:108.0],
        [_accentOrbView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:-30.0],
        [_accentOrbView.topAnchor constraintEqualToAnchor:surface.topAnchor constant:-42.0],

        [_bottomOrbView.widthAnchor constraintEqualToConstant:88.0],
        [_bottomOrbView.heightAnchor constraintEqualToConstant:88.0],
        [_bottomOrbView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:26.0],
        [_bottomOrbView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:34.0],

        [_kindBadgeView.topAnchor constraintEqualToAnchor:surface.topAnchor constant:kInnerPadding],
        [_kindBadgeView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:kInnerPadding],
        [_kindBadgeView.widthAnchor constraintEqualToConstant:kKindBadgeSize],
        [_kindBadgeView.heightAnchor constraintEqualToConstant:kKindBadgeSize],

        [_typeIconView.centerXAnchor constraintEqualToAnchor:_kindBadgeView.centerXAnchor],
        [_typeIconView.centerYAnchor constraintEqualToAnchor:_kindBadgeView.centerYAnchor],
        [_typeIconView.widthAnchor constraintEqualToConstant:14.0],
        [_typeIconView.heightAnchor constraintEqualToConstant:14.0],

        [_statusPill.topAnchor constraintEqualToAnchor:surface.topAnchor constant:kInnerPadding],
        [_statusPill.trailingAnchor constraintEqualToAnchor:_disclosureContainer.leadingAnchor constant:-10.0],
        [_statusPill.heightAnchor constraintEqualToConstant:kStatusHeight],

        [_statusLabel.topAnchor constraintEqualToAnchor:_statusPill.topAnchor constant:4.0],
        [_statusLabel.bottomAnchor constraintEqualToAnchor:_statusPill.bottomAnchor constant:-4.0],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusPill.leadingAnchor constant:10.0],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_statusPill.trailingAnchor constant:-10.0],

        [_disclosureContainer.centerYAnchor constraintEqualToAnchor:_statusPill.centerYAnchor],
        [_disclosureContainer.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-kInnerPadding],
        [_disclosureContainer.widthAnchor constraintEqualToConstant:28.0],
        [_disclosureContainer.heightAnchor constraintEqualToConstant:28.0],

        [_chevronImageView.centerXAnchor constraintEqualToAnchor:_disclosureContainer.centerXAnchor],
        [_chevronImageView.centerYAnchor constraintEqualToAnchor:_disclosureContainer.centerYAnchor],
        [_chevronImageView.widthAnchor constraintEqualToConstant:10.0],
        [_chevronImageView.heightAnchor constraintEqualToConstant:12.0],

        [_orderNumberLabel.centerYAnchor constraintEqualToAnchor:_kindBadgeView.centerYAnchor],
        [_orderNumberLabel.leadingAnchor constraintEqualToAnchor:_kindBadgeView.trailingAnchor constant:10.0],
        [_orderNumberLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_statusPill.leadingAnchor constant:-10.0],

        [_amountStack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-kInnerPadding],
        [_amountStack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-kInnerPadding],
        [_amountStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:surface.centerXAnchor constant:18.0],

        [_paymentDotView.widthAnchor constraintEqualToConstant:6.0],
        [_paymentDotView.heightAnchor constraintEqualToConstant:6.0],

        [_customerNameLabel.topAnchor constraintEqualToAnchor:_kindBadgeView.bottomAnchor constant:12.0],
        [_customerNameLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:kInnerPadding],
        [_customerNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_amountStack.leadingAnchor constant:-18.0],

        [_addressLabel.topAnchor constraintEqualToAnchor:_customerNameLabel.bottomAnchor constant:5.0],
        [_addressLabel.leadingAnchor constraintEqualToAnchor:_customerNameLabel.leadingAnchor],
        [_addressLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_amountStack.leadingAnchor constant:-18.0],

        [_branchBadgeView.topAnchor constraintEqualToAnchor:_addressLabel.bottomAnchor constant:10.0],
        [_branchBadgeView.leadingAnchor constraintEqualToAnchor:_customerNameLabel.leadingAnchor],
        [_branchBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:_amountStack.leadingAnchor constant:-18.0],

        [_branchIconView.leadingAnchor constraintEqualToAnchor:_branchBadgeView.leadingAnchor constant:12.0],
        [_branchIconView.centerYAnchor constraintEqualToAnchor:_branchBadgeView.centerYAnchor],
        [_branchIconView.widthAnchor constraintEqualToConstant:13.0],
        [_branchIconView.heightAnchor constraintEqualToConstant:13.0],

        [_branchLabel.topAnchor constraintEqualToAnchor:_branchBadgeView.topAnchor constant:8.0],
        [_branchLabel.bottomAnchor constraintEqualToAnchor:_branchBadgeView.bottomAnchor constant:-8.0],
        [_branchLabel.leadingAnchor constraintEqualToAnchor:_branchIconView.trailingAnchor constant:8.0],
        [_branchLabel.trailingAnchor constraintEqualToAnchor:_branchBadgeView.trailingAnchor constant:-12.0],

        [_metaLabel.topAnchor constraintEqualToAnchor:_branchBadgeView.bottomAnchor constant:10.0],
        [_metaLabel.leadingAnchor constraintEqualToAnchor:_customerNameLabel.leadingAnchor],
        [_metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_amountStack.leadingAnchor constant:-18.0],
        [_metaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-kInnerPadding],
    ]];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds cornerRadius:kCardRadius];
    self.cardView.layer.shadowPath = shadowPath.CGPath;
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];

    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.alpha = 1.0;
    self.orderNumberLabel.text = nil;
    self.statusLabel.text = nil;
    self.customerNameLabel.text = nil;
    self.addressLabel.text = nil;
    self.branchLabel.text = nil;
    self.metaLabel.text = nil;
    self.paymentLabel.text = nil;
    self.totalAmountLabel.text = nil;
    self.typeIconView.image = nil;
}

#pragma mark - Configure

- (void)configureWithOrder:(PPDeliveryOrderModel *)order {
    NSString *bestOrderNumber = [order bestOrderNumber];
    self.orderNumberLabel.text = [NSString stringWithFormat:kLang(@"OrderNumber"), bestOrderNumber];
    self.customerNameLabel.text = order.customerName.length ? order.customerName : @"—";

    BOOL shouldHideAddress = order.deliveryUserId.length == 0 &&
                             ([@[PPDeliveryStatusRequested, PPDeliveryStatusReadyToShip] containsObject:[order.deliveryStatus lowercaseString]]);
    NSString *visibleAddress = order.deliveryAddress.length ? order.deliveryAddress : order.pickupAddress;
    NSString *addressText = shouldHideAddress
        ? kLang(@"Deliv_AddressHidden")
        : (visibleAddress.length ? visibleAddress : @"—");
    self.addressLabel.text = addressText;

    NSString *itemsText = [NSString stringWithFormat:kLang(@"Items_Count"), (long)order.items.count];
    NSString *branchDisplay = order.branchName.length ? order.branchName : order.branchID;
    BOOL isNonOfficialMarketplaceProvider = order.marketplaceProviderID.length > 0 &&
                                            ![order.marketplaceProviderID isEqualToString:PPDeliveryOfficialSupportUserID] &&
                                            ![order.marketplaceProviderID isEqualToString:@"platform"];
    if (isNonOfficialMarketplaceProvider) {
        UIImageSymbolConfiguration *providerIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        self.branchIconView.image = [[UIImage systemImageNamed:@"person.badge.plus.fill"] imageWithConfiguration:providerIconConfig];
        self.branchIconView.tintColor = AppPrimaryClr;
        self.branchBadgeView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        self.branchBadgeView.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.16].CGColor;
        
        // Try to get provider name from cache, then from order, then fallback to ID
        NSString *providerName = order.marketplaceProviderName.length ? order.marketplaceProviderName : 
            [[PPDeliveryManager shared] providerDisplayNameForID:order.marketplaceProviderID];
        if (providerName.length == 0) {
            providerName = order.marketplaceProviderID;
        }
        
        self.branchLabel.textColor = AppPrimaryClr;
        self.branchLabel.text = [NSString stringWithFormat:kLang(@"Deliv_ProviderTakeBackSource"), providerName];
        self.metaLabel.text = branchDisplay.length ? [NSString stringWithFormat:kLang(@"Deliv_BranchPickupSource"), branchDisplay] : itemsText;
    } else {
        UIImageSymbolConfiguration *branchIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        self.branchIconView.image = [[UIImage systemImageNamed:@"building.2.fill"] imageWithConfiguration:branchIconConfig];
        self.branchIconView.tintColor = [UIColor ppWarning];
        self.branchBadgeView.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.10];
        self.branchBadgeView.layer.borderColor = [[UIColor ppWarning] colorWithAlphaComponent:0.16].CGColor;
        self.branchLabel.textColor = [UIColor ppWarning];
        if (branchDisplay.length == 0) {
            branchDisplay = kLang(@"Deliv_BranchPendingAssignment");
        }
        self.branchLabel.text = [NSString stringWithFormat:kLang(@"Deliv_BranchPickupSource"), branchDisplay];
        self.metaLabel.text = itemsText;
    }

    self.totalAmountLabel.text = [order formattedTotal];

    UIColor *statusColor = [self colorForStatus:order.deliveryStatus];
    self.statusPill.backgroundColor = [statusColor colorWithAlphaComponent:0.12];
    self.statusPill.layer.borderColor = [statusColor colorWithAlphaComponent:0.18].CGColor;
    self.statusLabel.textColor = statusColor;
    self.statusLabel.text = [order displayStatus];
    self.accentOrbView.backgroundColor = [statusColor colorWithAlphaComponent:0.10];

    BOOL isCash = [order isCashOrder];
    UIColor *paymentColor = isCash ? [UIColor ppSuccess] : [UIColor ppInfo];
    self.paymentDotView.backgroundColor = paymentColor;
    self.paymentLabel.textColor = paymentColor;
    self.paymentLabel.text = isCash ? kLang(@"CashPayment") : kLang(@"OnlinePayment");

    BOOL isDelivery = order.deliveryAddress.length > 0;
    UIColor *kindColor = isDelivery ? AppPrimaryClr : SeconderyTextClr;
    NSString *iconName = isDelivery ? @"shippingbox.fill" : @"bag.fill";
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
    self.typeIconView.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:iconConfig];
    self.kindBadgeView.backgroundColor = [kindColor colorWithAlphaComponent:isDelivery ? 0.10 : 0.07];
    self.kindBadgeView.layer.borderColor = [kindColor colorWithAlphaComponent:0.16].CGColor;
    self.typeIconView.tintColor = isDelivery ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.90];
}

- (UIColor *)colorForStatus:(NSString *)status {
    NSString *lower = [status lowercaseString];
    if ([@[PPDeliveryStatusReadyToShip, PPDeliveryStatusRequested, PPDeliveryStatusAwaitingHandover] containsObject:lower]) {
        return [UIColor ppWarning];
    }
    if ([lower isEqualToString:PPDeliveryStatusPickedUp] || [lower isEqualToString:PPDeliveryStatusInTransit]) {
        return [UIColor ppQuickActionCommunity];
    }
    if ([@[PPDeliveryStatusDelivered, PPDeliveryStatusPaymentPending, PPDeliveryStatusPaymentConfirmed, PPDeliveryStatusCompleted] containsObject:lower]) {
        return [UIColor ppSuccess];
    }
    if ([@[PPDeliveryStatusCancelled, PPDeliveryStatusFailed, PPDeliveryStatusReturnedToStore] containsObject:lower]) {
        return [UIColor ppError];
    }
    if ([@[@"processing", @"preparing", @"packed", @"confirmed", @"paid"] containsObject:lower]) {
        return [UIColor ppInfo];
    }
    return [UIColor ppTextSecondary];
}

#pragma mark - Interaction

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = highlighted
            ? CGAffineTransformMakeScale(0.975, 0.975)
            : CGAffineTransformIdentity;
        self.cardView.alpha = highlighted ? 0.96 : 1.0;
    } completion:nil];
}

@end
