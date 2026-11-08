//
//  PPVetCell.m — NextGen V8 clinical roster
//  PurePetsPro
//  A compact, accessible provider record with full-width profile selection
//  and individually accessible management/contact controls.
//

#import "PPVetCell.h"
#import "PPVetModel.h"
#import "PPFunc+Haptics.h"
#import "PPDesignTokens.h"
#import "UIImageView+WebCache.h"
#import <math.h>

static CGFloat const kRosterPortraitSize = 58.0;

@interface PPVetCell ()
@property (nonatomic, strong, readwrite) UIImageView *logoView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong, readwrite) UILabel *subscriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *costLabel;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *avatarRing;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UIButton *profileButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *whatsappButton;
@property (nonatomic, strong) UIButton *statusToggleButton;
@property (nonatomic, strong) PPVetModel *currentVet;
@end

@implementation PPVetCell

+ (NSString *)reuseID { return @"PPVetCell"; }
+ (CGFloat)preferredHeight { return 172.0; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    CGFloat horizontalInset = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 10.0 : 12.0;

    self.cardView = [UIView new];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(self.cardView, 20.0);
    self.cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.cardView.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72].CGColor;
    [self.contentView addSubview:self.cardView];

    self.avatarRing = [UIView new];
    self.avatarRing.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarRing.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.05];
    PPApplyContinuousCorners(self.avatarRing, 17.0);
    self.avatarRing.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.22].CGColor;
    self.avatarRing.layer.borderWidth = 1.0;

    self.logoView = [UIImageView new];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.logoView, 15.0);
    [self.avatarRing addSubview:self.logoView];

    self.onlineDot = [UIView new];
    self.onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.onlineDot.layer.cornerRadius = 6.0;
    self.onlineDot.layer.borderWidth = 2.0;
    self.onlineDot.layer.borderColor = [UIColor ppElevatedSurface].CGColor;
    [self.avatarRing addSubview:self.onlineDot];

    [NSLayoutConstraint activateConstraints:@[
        [self.avatarRing.widthAnchor constraintEqualToConstant:kRosterPortraitSize],
        [self.avatarRing.heightAnchor constraintEqualToConstant:kRosterPortraitSize],
        [self.logoView.leadingAnchor constraintEqualToAnchor:self.avatarRing.leadingAnchor constant:2.0],
        [self.logoView.trailingAnchor constraintEqualToAnchor:self.avatarRing.trailingAnchor constant:-2.0],
        [self.logoView.topAnchor constraintEqualToAnchor:self.avatarRing.topAnchor constant:2.0],
        [self.logoView.bottomAnchor constraintEqualToAnchor:self.avatarRing.bottomAnchor constant:-2.0],
        [self.onlineDot.widthAnchor constraintEqualToConstant:12.0],
        [self.onlineDot.heightAnchor constraintEqualToConstant:12.0],
        [self.onlineDot.bottomAnchor constraintEqualToAnchor:self.avatarRing.bottomAnchor constant:2.0],
        [self.onlineDot.trailingAnchor constraintEqualToAnchor:self.avatarRing.trailingAnchor constant:2.0],
    ]];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [Styling fontBold:17.0];
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    PPEnableDynamicType(self.titleLabel, UIFontTextStyleHeadline);

    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [Styling fontMedium:12.5];
    self.subtitleLabel.textColor = SeconderyTextClr;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 1;
    PPEnableDynamicType(self.subtitleLabel, UIFontTextStyleSubheadline);

    self.descriptionLabel = [UILabel new];
    self.descriptionLabel.font = [Styling fontRegular:12.0];
    self.descriptionLabel.textColor = SeconderyTextClr;
    self.descriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.descriptionLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 1;
    PPEnableDynamicType(self.descriptionLabel, UIFontTextStyleFootnote);

    UIStackView *identityStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.subtitleLabel, self.descriptionLabel]];
    identityStack.axis = UILayoutConstraintAxisVertical;
    identityStack.alignment = UIStackViewAlignmentFill;
    identityStack.spacing = 3.0;
    identityStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [identityStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [identityStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.costLabel = [UILabel new];
    self.costLabel.font = [Styling fontBold:11.0];
    self.costLabel.numberOfLines = 1;
    self.costLabel.textAlignment = NSTextAlignmentCenter;
    self.costLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    self.costLabel.textColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.costLabel, 9.0);
    PPEnableDynamicType(self.costLabel, UIFontTextStyleCaption1);
    [self.costLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.costLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // Consultation cost is supporting information, not a competing top-line
    // column. Keep the name and specialty readable on narrow Arabic screens.
    UIView *priceSpace = [UIView new];
    [priceSpace setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *priceRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.costLabel, priceSpace]];
    priceRow.axis = UILayoutConstraintAxisHorizontal;
    priceRow.alignment = UIStackViewAlignmentCenter;
    priceRow.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [identityStack addArrangedSubview:priceRow];

    UIStackView *profileRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.avatarRing, identityStack]];
    profileRow.translatesAutoresizingMaskIntoConstraints = NO;
    profileRow.axis = UILayoutConstraintAxisHorizontal;
    profileRow.alignment = UIStackViewAlignmentTop;
    profileRow.distribution = UIStackViewDistributionFill;
    profileRow.spacing = 10.0;
    profileRow.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:profileRow];
    [self.costLabel.heightAnchor constraintGreaterThanOrEqualToConstant:25.0].active = YES;

    UIView *divider = [UIView new];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.58];
    [self.cardView addSubview:divider];

    self.statusToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.statusToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusToggleButton.titleLabel.font = [Styling fontBold:12.0];
    PPApplyContinuousCorners(self.statusToggleButton, 12.0);
    [self.statusToggleButton addTarget:self action:@selector(statusToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    self.statusToggleButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);

    self.subscriptionLabel = [UILabel new];
    self.subscriptionLabel.font = [Styling fontMedium:11.0];
    self.subscriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.subscriptionLabel.numberOfLines = 1;
    self.subscriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    PPApplyContinuousCorners(self.subscriptionLabel, 10.0);
    self.subscriptionLabel.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.06];
    PPEnableDynamicType(self.subscriptionLabel, UIFontTextStyleCaption1);

    UIImageSymbolConfiguration *symbols = [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.callButton.tintColor = [UIColor ppInfo];
    self.callButton.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(self.callButton, 13.0);
    [self.callButton setImage:[UIImage systemImageNamed:@"phone.fill" withConfiguration:symbols] forState:UIControlStateNormal];
    self.callButton.accessibilityLabel = kLang(@"Vet_Action_Call");
    [self.callButton addTarget:self action:@selector(callTapped) forControlEvents:UIControlEventTouchUpInside];

    self.whatsappButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.whatsappButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.whatsappButton.tintColor = [UIColor colorWithRed:0.12 green:0.64 blue:0.35 alpha:1.0];
    self.whatsappButton.backgroundColor = [self.whatsappButton.tintColor colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(self.whatsappButton, 13.0);
    [self.whatsappButton setImage:[UIImage systemImageNamed:@"message.fill" withConfiguration:symbols] forState:UIControlStateNormal];
    self.whatsappButton.accessibilityLabel = kLang(@"Vet_Action_WhatsApp");
    [self.whatsappButton addTarget:self action:@selector(whatsappTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *flexibleSpace = [UIView new];
    [flexibleSpace setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [flexibleSpace setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *actionRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.statusToggleButton, self.subscriptionLabel, flexibleSpace, self.callButton, self.whatsappButton]];
    actionRow.translatesAutoresizingMaskIntoConstraints = NO;
    actionRow.axis = UILayoutConstraintAxisHorizontal;
    actionRow.alignment = UIStackViewAlignmentCenter;
    actionRow.distribution = UIStackViewDistributionFill;
    actionRow.spacing = 6.0;
    actionRow.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:actionRow];

    self.profileButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.profileButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileButton.backgroundColor = UIColor.clearColor;
    self.profileButton.accessibilityTraits = UIAccessibilityTraitButton;
    self.profileButton.accessibilityHint = kLang(@"Vet_Action_Open");
    [self.profileButton addTarget:self action:@selector(openTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.profileButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:horizontalInset],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-horizontalInset],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
        [profileRow.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:16.0],
        [profileRow.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:15.0],
        [profileRow.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-15.0],
        [self.profileButton.topAnchor constraintEqualToAnchor:profileRow.topAnchor],
        [self.profileButton.leadingAnchor constraintEqualToAnchor:profileRow.leadingAnchor],
        [self.profileButton.trailingAnchor constraintEqualToAnchor:profileRow.trailingAnchor],
        [self.profileButton.bottomAnchor constraintEqualToAnchor:profileRow.bottomAnchor],
        [divider.topAnchor constraintEqualToAnchor:profileRow.bottomAnchor constant:12.0],
        [divider.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:15.0],
        [divider.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-15.0],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [actionRow.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8.0],
        [actionRow.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:15.0],
        [actionRow.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-15.0],
        [actionRow.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [actionRow.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-12.0],
        [self.statusToggleButton.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [self.subscriptionLabel.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],
        [self.subscriptionLabel.widthAnchor constraintLessThanOrEqualToConstant:96.0],
        [self.callButton.widthAnchor constraintEqualToConstant:44.0],
        [self.callButton.heightAnchor constraintEqualToConstant:44.0],
        [self.whatsappButton.widthAnchor constraintEqualToConstant:44.0],
        [self.whatsappButton.heightAnchor constraintEqualToConstant:44.0],
    ]];
    self.canManageStatus = NO;
}

- (void)setCanManageStatus:(BOOL)canManageStatus {
    _canManageStatus = canManageStatus;
    self.statusToggleButton.enabled = canManageStatus;
    self.statusToggleButton.accessibilityHint = canManageStatus ? kLang(@"Vet_Field_Status") : nil;
}

- (void)configureWithVet:(PPVetModel *)vet {
    self.currentVet = vet;
    self.titleLabel.text = vet.title.length ? vet.title : kLang(@"Vet_Section_Title");

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *practiceType = [vet localizedTypeName];
    if (practiceType.length) [parts addObject:practiceType];
    if (vet.animalTypes.count) [parts addObject:[vet.animalTypes componentsJoinedByString:@", "]];
    self.subtitleLabel.text = [parts componentsJoinedByString:@" · "];
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.descriptionLabel.text = vet.descriptionText;
    self.descriptionLabel.hidden = vet.descriptionText.length == 0;
    self.titleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 2;
    self.subtitleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 1;
    self.descriptionLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 1;

    BOOL disabled = vet.isDisabled;
    NSString *status = disabled ? kLang(@"Vet_Status_Disabled") : kLang(@"Vet_Status_Active");
    [self.statusToggleButton setTitle:status forState:UIControlStateNormal];
    UIColor *statusColor = disabled ? [UIColor ppError] : [UIColor ppSuccess];
    [self.statusToggleButton setTitleColor:statusColor forState:UIControlStateNormal];
    self.statusToggleButton.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    self.onlineDot.backgroundColor = statusColor;
    self.avatarRing.layer.borderColor = [statusColor colorWithAlphaComponent:0.30].CGColor;

    NSString *tierName = [vet localizedSubscriptionTierName];
    self.subscriptionLabel.text = [NSString stringWithFormat:@"  %@  ", tierName.length ? tierName : kLang(@"Vet_Subscription")];
    BOOL expired = [vet isSubscriptionExpired];
    self.subscriptionLabel.textColor = expired ? [UIColor ppError] : SeconderyTextClr;

    if (vet.vetCost > 0) {
        BOOL hasCents = fabs(vet.vetCost - round(vet.vetCost)) > 0.001;
        self.costLabel.text = [NSString stringWithFormat:hasCents ? @"  %.2f %@  " : @"  %.0f %@  ", vet.vetCost, [Language isRTL] ? @"ر.ق" : @"QAR"];
        self.costLabel.textColor = AppPrimaryClr;
        self.costLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    } else {
        self.costLabel.text = [Language isRTL] ? @"  مجاني  " : @"  Free  ";
        self.costLabel.textColor = [UIColor ppSuccess];
        self.costLabel.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.10];
    }

    self.callButton.hidden = (vet.phone.length == 0);
    self.whatsappButton.hidden = (vet.whatsapp.length == 0);
    if (vet.logoURL.length) {
        [self.logoView setImageFromUrl:vet.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
    } else {
        self.logoView.image = [UIImage systemImageNamed:@"stethoscope"];
        self.logoView.tintColor = AppPrimaryClr;
    }
    self.profileButton.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.titleLabel.text, status];
    [self updateSelectedAppearanceAnimated:NO];
}

- (void)setSplitSelected:(BOOL)selected animated:(BOOL)animated {
    if (_isSplitSelected == selected) return;
    _isSplitSelected = selected;
    [self updateSelectedAppearanceAnimated:animated];
}

- (void)updateSelectedAppearanceAnimated:(BOOL)animated {
    void (^apply)(void) = ^{
        self.cardView.layer.borderColor = self.isSplitSelected ? AppPrimaryClr.CGColor : [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72].CGColor;
        self.cardView.layer.borderWidth = self.isSplitSelected ? 1.5 : 1.0 / UIScreen.mainScreen.scale;
        self.cardView.backgroundColor = self.isSplitSelected ? [AppPrimaryClr colorWithAlphaComponent:0.045] : [UIColor ppElevatedSurface];
    };
    if (animated && !PPMotionReduced()) PPAnimateRespectingMotion(PPAnimDurationNormal, apply, nil);
    else apply();
}

- (void)openTapped {
    [PPFunc pp_playTapEffect];
    if (self.currentVet && self.onOpenTapped) self.onOpenTapped(self.currentVet);
}
- (void)callTapped {
    [PPFunc pp_playTapEffect];
    if (self.currentVet && self.onCallTapped) self.onCallTapped(self.currentVet);
}
- (void)whatsappTapped {
    [PPFunc pp_playTapEffect];
    if (self.currentVet && self.onWhatsAppTapped) self.onWhatsAppTapped(self.currentVet);
}
- (void)statusToggleTapped {
    if (!self.canManageStatus) return;
    [PPFunc pp_playTapEffect];
    if (self.currentVet && self.onToggleStatusTapped) self.onToggleStatusTapped(self.currentVet);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.currentVet = nil;
    self.logoView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.descriptionLabel.text = nil;
    self.costLabel.text = nil;
    self.profileButton.accessibilityLabel = nil;
    self.onOpenTapped = nil;
    self.onCallTapped = nil;
    self.onWhatsAppTapped = nil;
    self.onToggleStatusTapped = nil;
    self.canManageStatus = NO;
    self.isSplitSelected = NO;
    [self updateSelectedAppearanceAnimated:NO];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (PPMotionReduced() || UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.transform = CGAffineTransformIdentity;
        return;
    }
    PPAnimateRespectingMotion(PPAnimDurationFast, ^{
        self.cardView.transform = highlighted ? CGAffineTransformMakeScale(0.992, 0.992) : CGAffineTransformIdentity;
    }, nil);
}

@end
