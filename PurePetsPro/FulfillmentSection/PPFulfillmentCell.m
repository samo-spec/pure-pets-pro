#import "PPFulfillmentCell.h"
#import "PPFulfillmentModel.h"

@interface PPFulfillmentCell ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *statusLineView;
@property (nonatomic, strong) UILabel *orderIdLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIView *amountPillView;
@property (nonatomic, strong) UIVisualEffectView *amountBlurView;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPFulfillmentCell

+ (NSString *)reuseIdentifier { return @"PPFulfillmentCell"; }
+ (CGFloat)preferredHeight { return 112.0; }

+ (UIColor *)pp_cellSurfaceColor {
    return [[UIColor ppSurface] colorWithAlphaComponent:0.94];
}

+ (UIColor *)pp_cellSurfaceBorderColor {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72];
}

+ (UIColor *)pp_cellPrimaryTextColor {
    return [UIColor ppTextPrimary];
}

+ (UIColor *)pp_cellSecondaryTextColorWithAlpha:(CGFloat)alpha {
    return [[UIColor ppTextSecondary] colorWithAlphaComponent:alpha];
}

+ (UIColor *)pp_amountPillColor {
    return [[UIColor ppMineralBeige] colorWithAlphaComponent:0.82];
}

+ (UIColor *)pp_amountTextColor {
    return [UIColor ppPremiumAccent];
}

- (UIBlurEffect *)pp_amountBlurEffect {
    if (@available(iOS 13.0, *)) {
        BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        _surfaceView = [[UIView alloc] init];
        _surfaceView.backgroundColor = [PPFulfillmentCell pp_cellSurfaceColor];
        _surfaceView.layer.cornerRadius = 24.0;
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        _surfaceView.layer.borderWidth = 0.5;
        _surfaceView.layer.borderColor = [PPFulfillmentCell pp_cellSurfaceBorderColor].CGColor;
        _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_surfaceView];

        _statusLineView = [[UIView alloc] init];
        _statusLineView.layer.cornerRadius = 2.0;
        _statusLineView.translatesAutoresizingMaskIntoConstraints = NO;
        [_surfaceView addSubview:_statusLineView];

        _orderIdLabel = [self labelWithFont:[Styling fontBold:17] color:[PPFulfillmentCell pp_cellPrimaryTextColor] lines:1];
        [_surfaceView addSubview:_orderIdLabel];

        _statusBadge = [self labelWithFont:[Styling fontBold:10] color:AppPrimaryClr lines:1];
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 10;
        _statusBadge.layer.cornerCurve = kCACornerCurveContinuous;
        _statusBadge.clipsToBounds = YES;
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        [_surfaceView addSubview:_statusBadge];

        _metaLabel = [self labelWithFont:[Styling fontRegular:12] color:[PPFulfillmentCell pp_cellSecondaryTextColorWithAlpha:0.82] lines:2];
        [_surfaceView addSubview:_metaLabel];

        _amountPillView = [[UIView alloc] init];
        _amountPillView.backgroundColor = [PPFulfillmentCell pp_amountPillColor];
        _amountPillView.layer.cornerRadius = 14.0;
        _amountPillView.layer.cornerCurve = kCACornerCurveContinuous;
        _amountPillView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _amountPillView.layer.borderColor = [[UIColor ppPremiumAccent] colorWithAlphaComponent:0.22].CGColor;
        _amountPillView.translatesAutoresizingMaskIntoConstraints = NO;
        [_surfaceView addSubview:_amountPillView];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *amountBlur = [[UIVisualEffectView alloc] initWithEffect:[self pp_amountBlurEffect]];
            amountBlur.translatesAutoresizingMaskIntoConstraints = NO;
            amountBlur.userInteractionEnabled = NO;
            amountBlur.layer.cornerRadius = 14.0;
            amountBlur.layer.masksToBounds = YES;
            self.amountBlurView = amountBlur;
            [_amountPillView addSubview:amountBlur];
            [NSLayoutConstraint activateConstraints:@[
                [amountBlur.topAnchor constraintEqualToAnchor:_amountPillView.topAnchor],
                [amountBlur.leadingAnchor constraintEqualToAnchor:_amountPillView.leadingAnchor],
                [amountBlur.trailingAnchor constraintEqualToAnchor:_amountPillView.trailingAnchor],
                [amountBlur.bottomAnchor constraintEqualToAnchor:_amountPillView.bottomAnchor],
            ]];
        }

        _amountLabel = [self labelWithFont:[Styling fontBold:14] color:[PPFulfillmentCell pp_amountTextColor] lines:1];
        _amountLabel.textAlignment = NSTextAlignmentCenter;
        _amountLabel.adjustsFontSizeToFitWidth = YES;
        _amountLabel.minimumScaleFactor = 0.72;
        [_amountPillView addSubview:_amountLabel];

        _dateLabel = [self labelWithFont:[Styling fontRegular:11] color:[PPFulfillmentCell pp_cellSecondaryTextColorWithAlpha:0.70] lines:1];
        [_surfaceView addSubview:_dateLabel];

        UIImage *chevron = [UIImage systemImageNamed:([Language isRTL] ? @"chevron.left" : @"chevron.right")];
        _chevronView = [[UIImageView alloc] initWithImage:chevron];
        _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.55];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        [_surfaceView addSubview:_chevronView];

        [NSLayoutConstraint activateConstraints:@[
            [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
            [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18],
            [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

            [_statusLineView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14],
            [_statusLineView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:18],
            [_statusLineView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-18],
            [_statusLineView.widthAnchor constraintEqualToConstant:4],

            [_orderIdLabel.leadingAnchor constraintEqualToAnchor:_statusLineView.trailingAnchor constant:13],
            [_orderIdLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:17],
            [_orderIdLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_statusBadge.leadingAnchor constant:-10],

            [_statusBadge.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-16],
            [_statusBadge.centerYAnchor constraintEqualToAnchor:_orderIdLabel.centerYAnchor],
            [_statusBadge.heightAnchor constraintEqualToConstant:22],
            [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:76],

            [_metaLabel.leadingAnchor constraintEqualToAnchor:_orderIdLabel.leadingAnchor],
            [_metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-12],
            [_metaLabel.topAnchor constraintEqualToAnchor:_orderIdLabel.bottomAnchor constant:7],

            [_amountPillView.leadingAnchor constraintEqualToAnchor:_orderIdLabel.leadingAnchor],
            [_amountPillView.topAnchor constraintEqualToAnchor:_metaLabel.bottomAnchor constant:7],
            [_amountPillView.trailingAnchor constraintLessThanOrEqualToAnchor:_dateLabel.leadingAnchor constant:-10],
            [_amountPillView.heightAnchor constraintEqualToConstant:28],
            [_amountPillView.widthAnchor constraintGreaterThanOrEqualToConstant:92],

            [_amountLabel.topAnchor constraintEqualToAnchor:_amountPillView.topAnchor constant:5],
            [_amountLabel.leadingAnchor constraintEqualToAnchor:_amountPillView.leadingAnchor constant:10],
            [_amountLabel.trailingAnchor constraintEqualToAnchor:_amountPillView.trailingAnchor constant:-10],
            [_amountLabel.bottomAnchor constraintEqualToAnchor:_amountPillView.bottomAnchor constant:-5],

            [_dateLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-10],
            [_dateLabel.centerYAnchor constraintEqualToAnchor:_amountPillView.centerYAnchor],

            [_chevronView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-16],
            [_chevronView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:13],
            [_chevronView.heightAnchor constraintEqualToConstant:18],
        ]];
    }
    return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyDynamicColors];
    }
}

- (void)pp_applyDynamicColors {
    self.surfaceView.backgroundColor = [PPFulfillmentCell pp_cellSurfaceColor];
    self.surfaceView.layer.borderColor = [PPFulfillmentCell pp_cellSurfaceBorderColor].CGColor;
    self.orderIdLabel.textColor = [PPFulfillmentCell pp_cellPrimaryTextColor];
    self.metaLabel.textColor = [PPFulfillmentCell pp_cellSecondaryTextColorWithAlpha:0.82];
    self.dateLabel.textColor = [PPFulfillmentCell pp_cellSecondaryTextColorWithAlpha:0.70];
    self.amountPillView.backgroundColor = [PPFulfillmentCell pp_amountPillColor];
    self.amountLabel.textColor = [PPFulfillmentCell pp_amountTextColor];
    if (@available(iOS 13.0, *)) {
        self.amountBlurView.effect = [self pp_amountBlurEffect];
    }
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    NSTimeInterval duration = animated ? 0.16 : 0.0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.surfaceView.transform = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
        self.surfaceView.alpha = highlighted ? 0.86 : 1.0;
    } completion:nil];
}

- (void)configureWithModel:(PPFulfillmentModel *)model {
    NSString *fallbackID = model.parentOrderId.length > 0 ? [model.parentOrderId substringToIndex:MIN(10, model.parentOrderId.length)] : @"";
    NSString *orderNumber = model.parentOrderNumber.length > 0 ? model.parentOrderNumber : fallbackID;
    self.orderIdLabel.text = [NSString stringWithFormat:@"%@ %@", kLang(@"Fulfillment_OrderID"), orderNumber.length > 0 ? orderNumber : @"-"];

    self.statusBadge.text = [NSString stringWithFormat:@"  %@  ", [model statusDisplayName]];
    self.statusBadge.textColor = model.statusColor;
    self.statusBadge.backgroundColor = [model.statusColor colorWithAlphaComponent:0.11];
    self.statusLineView.backgroundColor = model.statusColor;

    NSString *parentID = model.parentOrderId.length > 0 ? [model.parentOrderId substringToIndex:MIN(12, model.parentOrderId.length)] : @"-";
    self.metaLabel.text = [NSString stringWithFormat:@"%@ %ld  /  %@ %@", kLang(@"Fulfillment_Items"), (long)model.itemCount, kLang(@"Fulfillment_Reference"), parentID];

    self.amountLabel.text = [NSString stringWithFormat:@"%.0f %@", model.providerNet, model.currency.length > 0 ? model.currency : @"QAR"];

    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateStyle = NSDateFormatterMediumStyle;
        df.doesRelativeDateFormatting = YES;
    });
    self.dateLabel.text = model.createdAt ? [df stringFromDate:model.createdAt] : @"";
}

@end
