//
//  PPProPriorityFulfillmentCard.m
//  PurePetsPro
//
//  Created on 31/08/2026.
//

#import "PPProPriorityFulfillmentCard.h"
#import "PPDesignTokens.h"
#import "Styling.h"
#import "PPFunc+Haptics.h"

@interface PPProPriorityFulfillmentCard ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *badgeView;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIImageView *actionArrowView;
@property (nonatomic, strong) UILabel *actionTitleLabel;

@end

@implementation PPProPriorityFulfillmentCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_setupUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_setupUI];
    }
    return self;
}

- (void)pp_setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIColor *themeTeal = [UIColor colorWithRed:0.306 green:0.529 blue:0.549 alpha:1.0]; // #4E878C

    // Card Container
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.125 green:0.176 blue:0.192 alpha:1.0];
        }
        return [UIColor colorWithRed:0.894 green:0.937 blue:0.941 alpha:1.0]; // #E4EFF0
    }];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.20 green:0.28 blue:0.30 alpha:1.0];
        }
        return [UIColor colorWithRed:0.81 green:0.88 blue:0.89 alpha:1.0]; // #CFE1E3
    }].CGColor;
    container.layer.cornerRadius = 26.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.clipsToBounds = YES;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self addSubview:container];
    self.containerView = container;

    // Top Section - Icon Squircle
    UIView *iconBox = [[UIView alloc] init];
    iconBox.translatesAutoresizingMaskIntoConstraints = NO;
    iconBox.backgroundColor = themeTeal;
    iconBox.layer.cornerRadius = 17.0;
    iconBox.layer.cornerCurve = kCACornerCurveContinuous;
    iconBox.clipsToBounds = YES;
    [container addSubview:iconBox];
    self.iconContainerView = iconBox;

    UIImageView *iconIV = [[UIImageView alloc] init];
    iconIV.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:23.0 weight:UIImageSymbolWeightSemibold];
    iconIV.image = [UIImage systemImageNamed:@"shippingbox.fill" withConfiguration:symConfig];
    iconIV.tintColor = UIColor.whiteColor;
    iconIV.contentMode = UIViewContentModeScaleAspectFit;
    [iconBox addSubview:iconIV];
    self.iconImageView = iconIV;

    // Top Section - Eyebrow & Title Stack
    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [Styling fontBold:12.5];
    eyebrow.textColor = themeTeal;
    eyebrow.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrow.text = kLang(@"PriorityFulfillmentEyebrow") ?: @"طلب إنجاز حديث";
    self.eyebrowLabel = eyebrow;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [Styling fontBold:20.0];
    title.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.94 green:0.95 blue:0.96 alpha:1.0];
        }
        return [UIColor colorWithRed:0.12 green:0.14 blue:0.17 alpha:1.0];
    }];
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.text = kLang(@"Fulfillment_Title") ?: @"طلبات الإنجاز";
    self.titleLabel = title;

    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, title]];
    titleStack.translatesAutoresizingMaskIntoConstraints = NO;
    titleStack.axis = UILayoutConstraintAxisVertical;
    titleStack.alignment = UIStackViewAlignmentFill;
    titleStack.spacing = 3.0;
    titleStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [container addSubview:titleStack];

    // Top Section - Badge Capsule
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.18 green:0.27 blue:0.29 alpha:1.0];
        }
        return [UIColor colorWithRed:0.83 green:0.90 blue:0.91 alpha:1.0];
    }];
    badge.layer.cornerRadius = 13.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.clipsToBounds = YES;
    [container addSubview:badge];
    self.badgeView = badge;

    UILabel *badgeLbl = [[UILabel alloc] init];
    badgeLbl.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLbl.font = [Styling fontBold:13.0];
    badgeLbl.textColor = themeTeal;
    badgeLbl.textAlignment = NSTextAlignmentCenter;
    badgeLbl.text = @"جديد";
    [badge addSubview:badgeLbl];
    self.badgeLabel = badgeLbl;

    // Middle Section - Subtitle
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.font = [Styling fontMedium:14.0];
    sub.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.72 green:0.77 blue:0.80 alpha:1.0];
        }
        return [UIColor colorWithRed:0.41 green:0.46 blue:0.49 alpha:1.0];
    }];
    sub.textAlignment = Language.alignmentForCurrentLanguage;
    sub.numberOfLines = 0;
    sub.text = kLang(@"PriorityFulfillmentSubtitle") ?: @"تابع أحدث طلبات الإنجاز والتجهيز المباشر للمتجر والخدمات.";
    [container addSubview:sub];
    self.subtitleLabel = sub;

    // Bottom Section - Action Button
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = themeTeal;
    btn.layer.cornerRadius = 17.0;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.clipsToBounds = YES;
    [btn addTarget:self action:@selector(pp_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [btn addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [container addSubview:btn];
    self.actionButton = btn;

    UILabel *btnTitle = [[UILabel alloc] init];
    btnTitle.translatesAutoresizingMaskIntoConstraints = NO;
    btnTitle.font = [Styling fontBold:15.5];
    btnTitle.textColor = UIColor.whiteColor;
    btnTitle.textAlignment = Language.alignmentForCurrentLanguage;
    btnTitle.text = kLang(@"ReviewFulfillment") ?: @"مراجعة طلبات الإنجاز";
    btnTitle.userInteractionEnabled = NO;
    [btn addSubview:btnTitle];
    self.actionTitleLabel = btnTitle;

    UIImageView *arrowIV = [[UIImageView alloc] init];
    arrowIV.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *arrConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightBold];
    arrowIV.image = [UIImage systemImageNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right") withConfiguration:arrConfig];
    arrowIV.tintColor = UIColor.whiteColor;
    arrowIV.contentMode = UIViewContentModeScaleAspectFit;
    arrowIV.userInteractionEnabled = NO;
    [btn addSubview:arrowIV];
    self.actionArrowView = arrowIV;

    // Tap gesture on card
    UITapGestureRecognizer *cardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_cardTapped:)];
    [container addGestureRecognizer:cardTap];

    // Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Container
        [container.topAnchor constraintEqualToAnchor:self.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        // Top Row: Icon Box (trailing in RTL, leading in LTR)
        [iconBox.topAnchor constraintEqualToAnchor:container.topAnchor constant:18.0],
        [iconBox.widthAnchor constraintEqualToConstant:54.0],
        [iconBox.heightAnchor constraintEqualToConstant:54.0],

        [iconIV.centerXAnchor constraintEqualToAnchor:iconBox.centerXAnchor],
        [iconIV.centerYAnchor constraintEqualToAnchor:iconBox.centerYAnchor],
        [iconIV.widthAnchor constraintEqualToConstant:26.0],
        [iconIV.heightAnchor constraintEqualToConstant:26.0],

        // Top Row: Title Stack
        [titleStack.centerYAnchor constraintEqualToAnchor:iconBox.centerYAnchor],

        // Top Row: Badge Capsule (leading in RTL, trailing in LTR)
        [badge.centerYAnchor constraintEqualToAnchor:iconBox.centerYAnchor],
        [badge.heightAnchor constraintEqualToConstant:26.0],
        [badgeLbl.topAnchor constraintEqualToAnchor:badge.topAnchor],
        [badgeLbl.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor],
        [badgeLbl.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:10.0],
        [badgeLbl.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-10.0],

        // Subtitle
        [sub.topAnchor constraintEqualToAnchor:iconBox.bottomAnchor constant:14.0],
        [sub.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [sub.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],

        // Action Button
        [btn.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:16.0],
        [btn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [btn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [btn.heightAnchor constraintEqualToConstant:50.0],
        [btn.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-18.0],

        // Inside Action Button
        [arrowIV.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [arrowIV.widthAnchor constraintEqualToConstant:20.0],
        [arrowIV.heightAnchor constraintEqualToConstant:20.0],

        [btnTitle.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
    ]];

    if (Language.isRTL) {
        [NSLayoutConstraint activateConstraints:@[
            [iconBox.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
            [titleStack.trailingAnchor constraintEqualToAnchor:iconBox.leadingAnchor constant:-12.0],
            [titleStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:badge.trailingAnchor constant:10.0],
            [badge.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],

            [btnTitle.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-20.0],
            [arrowIV.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:18.0],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [iconBox.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
            [titleStack.leadingAnchor constraintEqualToAnchor:iconBox.trailingAnchor constant:12.0],
            [titleStack.trailingAnchor constraintLessThanOrEqualToAnchor:badge.leadingAnchor constant:-10.0],
            [badge.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],

            [btnTitle.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:20.0],
            [arrowIV.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-18.0],
        ]];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            self.containerView.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.20 green:0.28 blue:0.30 alpha:1.0];
                }
                return [UIColor colorWithRed:0.81 green:0.88 blue:0.89 alpha:1.0];
            }].CGColor;
        }
    }
}

- (void)updateWithFulfillmentModel:(nullable PPFulfillmentModel *)model pendingCount:(NSInteger)pendingCount {
    if (model) {
        self.eyebrowLabel.text = kLang(@"PriorityFulfillmentEyebrow") ?: @"طلب إنجاز حديث";
        
        NSString *orderNum = model.parentOrderNumber.length ? model.parentOrderNumber : (model.fulfillmentID.length > 6 ? [model.fulfillmentID substringToIndex:6] : model.fulfillmentID);
        self.titleLabel.text = [NSString stringWithFormat:@"%@ #%@", kLang(@"Fulfillment_OrderPrefix") ?: @"طلب", orderNum ?: @""];
        
        NSString *statusName = [model statusDisplayName];
        self.badgeLabel.text = statusName.length ? statusName : (pendingCount > 0 ? [NSString stringWithFormat:@"%ld", (long)pendingCount] : @"جديد");
        self.badgeView.hidden = NO;
        
        NSString *currency = model.currency.length ? model.currency : @"ر.ق";
        double amount = model.providerNet > 0 ? model.providerNet : model.subtotal;
        NSInteger count = model.itemCount > 0 ? model.itemCount : model.items.count;
        if (count <= 0) count = 1;
        
        if (amount > 0) {
            self.subtitleLabel.text = [NSString stringWithFormat:@"%ld %@ · %.2f %@", (long)count, kLang(@"Items_Count_Label") ?: @"منتجات", amount, currency];
        } else {
            self.subtitleLabel.text = [NSString stringWithFormat:kLang(@"PriorityFulfillmentOrderSubtitleFormat") ?: @"طلب إنجاز برقم #%@ بانتظار المتابعة والتجهيز.", orderNum ?: @""];
        }
        
        self.actionTitleLabel.text = kLang(@"ReviewFulfillmentOrder") ?: @"عرض تفاصيل الطلب";
    } else {
        self.eyebrowLabel.text = kLang(@"PriorityFulfillmentEyebrow") ?: @"طلب إنجاز حديث";
        self.titleLabel.text = kLang(@"Fulfillment_Title") ?: @"طلبات الإنجاز";
        if (pendingCount > 0) {
            self.badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)pendingCount];
            self.badgeView.hidden = NO;
        } else {
            self.badgeLabel.text = @"جديد";
            self.badgeView.hidden = NO;
        }
        self.subtitleLabel.text = kLang(@"PriorityFulfillmentSubtitle") ?: @"تابع أحدث طلبات الإنجاز والتجهيز المباشر للمتجر والخدمات.";
        self.actionTitleLabel.text = kLang(@"ReviewFulfillment") ?: @"مراجعة طلبات الإنجاز";
    }
}

#pragma mark - Actions & Feedback

- (void)pp_buttonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        sender.transform = CGAffineTransformMakeScale(0.97, 0.97);
        sender.alpha = 0.90;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.20 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)pp_buttonTapped:(UIButton *)sender {
    [self pp_buttonTouchUp:sender];
    [PPFunc pp_playTapEffect];
    if (self.actionHandler) {
        self.actionHandler();
    }
}

- (void)pp_cardTapped:(UITapGestureRecognizer *)gesture {
    [PPFunc pp_playTapEffect];
    if (self.actionHandler) {
        self.actionHandler();
    }
}

@end
