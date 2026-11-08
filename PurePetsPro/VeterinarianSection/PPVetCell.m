// PPVetCell.m — NextGen V8 Clinical Passport
// UIKit / Arabic RTL & English LTR. No false "online" signal.
#import "PPVetCell.h"
#import "PPVetModel.h"
#import "PPFunc+Haptics.h"
#import "PPDesignTokens.h"
#import "UIImageView+WebCache.h"
#import <math.h>

@interface PPVetCell ()
@property (nonatomic, strong, readwrite) UIImageView *logoView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong, readwrite) UILabel *subscriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *costLabel;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *statusRail;
@property (nonatomic, strong) UIView *portraitSurface;
@property (nonatomic, strong) UIStackView *identityColumn;
@property (nonatomic, strong) UIStackView *feeColumn;
@property (nonatomic, strong) UIStackView *stateFeeBand;
@property (nonatomic, strong) UIView *feeSpacer;
@property (nonatomic, strong) UIStackView *actionDock;
@property (nonatomic, strong) NSLayoutConstraint *callWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *whatsappWidthConstraint;
@property (nonatomic, strong) UIButton *headerTapButton;
@property (nonatomic, strong) UIButton *profileActionButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *whatsappButton;
@property (nonatomic, strong) UIButton *statusToggleButton;
@property (nonatomic, strong) UILabel *feeCaptionLabel;
@property (nonatomic, strong) PPVetModel *currentVet;
@end

@implementation PPVetCell

+ (NSString *)reuseID { return @"PPVetCell"; }
+ (CGFloat)preferredHeight { return 198.0; } // UITableViewAutomaticDimension sets actual height.

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
    CGFloat inset = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 10.0 : 12.0;
    self.cardView = [UIView new];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [UIColor ppElevatedSurface];
    self.cardView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPApplyContinuousCorners(self.cardView, 22.0);
    self.cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.cardView.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72].CGColor;
    [self.contentView addSubview:self.cardView];

    // Continuous state rail carries the provider's ACTIVE/DISABLED state.
    // It intentionally never implies real-time availability.
    self.statusRail = [UIView new];
    self.statusRail.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusRail.backgroundColor = [UIColor ppSuccess];
    PPApplyContinuousCorners(self.statusRail, 2.0);
    [self.cardView addSubview:self.statusRail];

    self.portraitSurface = [UIView new];
    self.portraitSurface.translatesAutoresizingMaskIntoConstraints = NO;
    self.portraitSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(self.portraitSurface, 17.0);
    self.portraitSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.portraitSurface.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.7].CGColor;
    self.logoView = [UIImageView new];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.logoView, 15.0);
    [self.portraitSurface addSubview:self.logoView];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [Styling fontBold:18.0];
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.titleLabel, UIFontTextStyleHeadline);

    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [Styling fontMedium:12.5];
    self.subtitleLabel.textColor = SeconderyTextClr;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.subtitleLabel, UIFontTextStyleSubheadline);

    self.descriptionLabel = [UILabel new];
    self.descriptionLabel.font = [Styling fontRegular:12];
    self.descriptionLabel.textColor = SeconderyTextClr;
    self.descriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.descriptionLabel, UIFontTextStyleFootnote);

    self.subscriptionLabel = [UILabel new];
    self.subscriptionLabel.font = [Styling fontMedium:11];
    self.subscriptionLabel.textColor = SeconderyTextClr;
    self.subscriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.subscriptionLabel, UIFontTextStyleCaption1);

    self.identityColumn = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel, self.subtitleLabel, self.descriptionLabel, self.subscriptionLabel
    ]];
    self.identityColumn.translatesAutoresizingMaskIntoConstraints = NO;
    self.identityColumn.axis = UILayoutConstraintAxisVertical;
    self.identityColumn.alignment = UIStackViewAlignmentFill;
    self.identityColumn.spacing = 3;
    self.identityColumn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.identityColumn setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    chevron.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.7];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.isAccessibilityElement = NO;
    [chevron setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *profileHeader = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.portraitSurface, self.identityColumn, chevron
    ]];
    profileHeader.translatesAutoresizingMaskIntoConstraints = NO;
    profileHeader.axis = UILayoutConstraintAxisHorizontal;
    profileHeader.alignment = UIStackViewAlignmentTop;
    profileHeader.spacing = 10;
    profileHeader.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:profileHeader];

    // Explicit accessible profile target spanning the identity region.
    self.headerTapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.headerTapButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTapButton.backgroundColor = UIColor.clearColor;
    self.headerTapButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.headerTapButton addTarget:self action:@selector(openTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.headerTapButton];

    self.statusToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.statusToggleButton.titleLabel.font = [Styling fontBold:12];
    self.statusToggleButton.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    PPApplyContinuousCorners(self.statusToggleButton, 12);
    [self.statusToggleButton addTarget:self action:@selector(statusToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.statusToggleButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.feeCaptionLabel = [UILabel new];
    self.feeCaptionLabel.text = kLang(@"Vet_Roster_Fee_Label");
    self.feeCaptionLabel.textColor = SeconderyTextClr;
    self.feeCaptionLabel.font = [Styling fontMedium:11];
    self.feeCaptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.feeCaptionLabel, UIFontTextStyleCaption1);

    self.costLabel = [UILabel new];
    self.costLabel.textColor = PrimaryTextClr;
    self.costLabel.font = [Styling fontBold:16];
    self.costLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(self.costLabel, UIFontTextStyleSubheadline);

    self.feeColumn = [[UIStackView alloc] initWithArrangedSubviews:@[self.feeCaptionLabel, self.costLabel]];
    self.feeColumn.translatesAutoresizingMaskIntoConstraints = NO;
    self.feeColumn.axis = UILayoutConstraintAxisVertical;
    self.feeColumn.spacing = 2;

    self.feeSpacer = [UIView new];
    [self.feeSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.feeSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.stateFeeBand = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.statusToggleButton, self.feeSpacer, self.feeColumn
    ]];
    self.stateFeeBand.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateFeeBand.axis = UILayoutConstraintAxisHorizontal;
    self.stateFeeBand.alignment = UIStackViewAlignmentCenter;
    self.stateFeeBand.spacing = 8;
    self.stateFeeBand.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:self.stateFeeBand];

    UIView *divider = [UIView new];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.55];
    [self.cardView addSubview:divider];

    self.profileActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.profileActionButton.accessibilityLabel = kLang(@"Vet_Roster_View_Profile");
    [self.profileActionButton setTitle:kLang(@"Vet_Roster_View_Profile") forState:UIControlStateNormal];
    [self.profileActionButton setImage:[UIImage systemImageNamed:@"chevron.forward"] forState:UIControlStateNormal];
    self.profileActionButton.titleLabel.font = [Styling fontBold:13];
    self.profileActionButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.profileActionButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    self.profileActionButton.tintColor = AppPrimaryClr;
    self.profileActionButton.contentEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 9);
    PPApplyContinuousCorners(self.profileActionButton, 13);
    [self.profileActionButton addTarget:self action:@selector(openTapped) forControlEvents:UIControlEventTouchUpInside];

    UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    self.callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.callButton.tintColor = [UIColor ppInfo];
    self.callButton.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(self.callButton, 13);
    [self.callButton setImage:[UIImage systemImageNamed:@"phone.fill" withConfiguration:symbol] forState:UIControlStateNormal];
    self.callButton.accessibilityLabel = kLang(@"Vet_Action_Call");
    [self.callButton addTarget:self action:@selector(callTapped) forControlEvents:UIControlEventTouchUpInside];

    self.whatsappButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.whatsappButton.tintColor = [UIColor colorWithRed:0.12 green:0.64 blue:0.35 alpha:1];
    self.whatsappButton.backgroundColor = [self.whatsappButton.tintColor colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(self.whatsappButton, 13);
    [self.whatsappButton setImage:[UIImage systemImageNamed:@"message.fill" withConfiguration:symbol] forState:UIControlStateNormal];
    self.whatsappButton.accessibilityLabel = kLang(@"Vet_Action_WhatsApp");
    [self.whatsappButton addTarget:self action:@selector(whatsappTapped) forControlEvents:UIControlEventTouchUpInside];

    self.actionDock = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.profileActionButton, self.callButton, self.whatsappButton
    ]];
    self.actionDock.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionDock.axis = UILayoutConstraintAxisHorizontal;
    self.actionDock.alignment = UIStackViewAlignmentFill;
    self.actionDock.spacing = 8;
    self.actionDock.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:self.actionDock];
    [self.profileActionButton setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.callWidthConstraint = [self.callButton.widthAnchor constraintEqualToConstant:44.0];
    self.whatsappWidthConstraint = [self.whatsappButton.widthAnchor constraintEqualToConstant:44.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:inset],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-inset],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
        [self.statusRail.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:3],
        [self.statusRail.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:18],
        [self.statusRail.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-18],
        [self.statusRail.widthAnchor constraintEqualToConstant:4],
        [self.portraitSurface.widthAnchor constraintEqualToConstant:58],
        [self.portraitSurface.heightAnchor constraintEqualToConstant:58],
        [self.logoView.topAnchor constraintEqualToAnchor:self.portraitSurface.topAnchor constant:2],
        [self.logoView.bottomAnchor constraintEqualToAnchor:self.portraitSurface.bottomAnchor constant:-2],
        [self.logoView.leadingAnchor constraintEqualToAnchor:self.portraitSurface.leadingAnchor constant:2],
        [self.logoView.trailingAnchor constraintEqualToAnchor:self.portraitSurface.trailingAnchor constant:-2],
        [chevron.widthAnchor constraintEqualToConstant:12],
        [chevron.heightAnchor constraintEqualToConstant:18],
        [profileHeader.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:16],
        [profileHeader.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:17],
        [profileHeader.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-17],
        [self.headerTapButton.topAnchor constraintEqualToAnchor:profileHeader.topAnchor],
        [self.headerTapButton.leadingAnchor constraintEqualToAnchor:profileHeader.leadingAnchor],
        [self.headerTapButton.trailingAnchor constraintEqualToAnchor:profileHeader.trailingAnchor],
        [self.headerTapButton.bottomAnchor constraintEqualToAnchor:profileHeader.bottomAnchor],
        [self.stateFeeBand.topAnchor constraintEqualToAnchor:profileHeader.bottomAnchor constant:10],
        [self.stateFeeBand.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:17],
        [self.stateFeeBand.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-17],
        [self.statusToggleButton.heightAnchor constraintEqualToConstant:44.0],
        [divider.topAnchor constraintEqualToAnchor:self.stateFeeBand.bottomAnchor constant:9],
        [divider.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:17],
        [divider.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-17],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [self.actionDock.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:9],
        [self.actionDock.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:17],
        [self.actionDock.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-17],
        [self.actionDock.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14],
        [self.profileActionButton.heightAnchor constraintEqualToConstant:44.0],
        [self.callButton.heightAnchor constraintEqualToConstant:44.0],
        self.callWidthConstraint,
        [self.whatsappButton.heightAnchor constraintEqualToConstant:44.0],
        self.whatsappWidthConstraint,
    ]];
    self.canManageStatus = NO;
    [self pp_applyAccessibilityLayout];
}

- (void)pp_applyAccessibilityLayout {
    BOOL expanded = PPIsAccessibilityTextSize();
    self.stateFeeBand.axis = expanded ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.stateFeeBand.alignment = expanded ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    self.feeSpacer.hidden = expanded;
    self.actionDock.axis = expanded ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.actionDock.alignment = UIStackViewAlignmentFill;

    // On large-text sizes secondary actions become full-width labeled controls.
    // Normal sizes retain compact 44 x 44 icon controls.
    self.callWidthConstraint.active = !expanded;
    self.whatsappWidthConstraint.active = !expanded;
    [self.callButton setTitle:expanded ? kLang(@"Vet_Action_Call") : nil forState:UIControlStateNormal];
    [self.whatsappButton setTitle:expanded ? kLang(@"Vet_Action_WhatsApp") : nil forState:UIControlStateNormal];
    self.callButton.titleLabel.font = [Styling fontMedium:13.0];
    self.whatsappButton.titleLabel.font = [Styling fontMedium:13.0];
    self.callButton.contentEdgeInsets = expanded ? UIEdgeInsetsMake(0, 12, 0, 12) : UIEdgeInsetsZero;
    self.whatsappButton.contentEdgeInsets = expanded ? UIEdgeInsetsMake(0, 12, 0, 12) : UIEdgeInsetsZero;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        [self pp_applyAccessibilityLayout];
    }
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
    NSString *type = [vet localizedTypeName];
    if (type.length) [parts addObject:type];
    if (vet.animalTypes.count) [parts addObject:[vet.animalTypes componentsJoinedByString:@", "]];
    self.subtitleLabel.text = [parts componentsJoinedByString:@" · "];
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.descriptionLabel.text = vet.descriptionText;
    self.descriptionLabel.hidden = vet.descriptionText.length == 0;
    BOOL expanded = PPIsAccessibilityTextSize();
    [self pp_applyAccessibilityLayout];
    self.titleLabel.numberOfLines = expanded ? 0 : 2;
    self.subtitleLabel.numberOfLines = expanded ? 0 : 1;
    self.descriptionLabel.numberOfLines = expanded ? 0 : 1;
    self.subscriptionLabel.numberOfLines = expanded ? 0 : 1;
    self.costLabel.numberOfLines = expanded ? 0 : 1;

    NSString *tier = [vet localizedSubscriptionTierName];
    self.subscriptionLabel.text = tier.length ? tier : kLang(@"Vet_Subscription");
    self.subscriptionLabel.textColor = [vet isSubscriptionExpired] ? [UIColor ppError] : SeconderyTextClr;

    BOOL disabled = vet.isDisabled;
    UIColor *statusColor = disabled ? [UIColor ppError] : [UIColor ppSuccess];
    NSString *status = disabled ? kLang(@"Vet_Status_Disabled") : kLang(@"Vet_Status_Active");
    [self.statusToggleButton setTitle:status forState:UIControlStateNormal];
    [self.statusToggleButton setTitleColor:statusColor forState:UIControlStateNormal];
    self.statusToggleButton.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    self.statusToggleButton.accessibilityLabel = status;
    self.statusRail.backgroundColor = statusColor;

    self.feeCaptionLabel.text = kLang(@"Vet_Roster_Fee_Label");
    if (vet.vetCost > 0) {
        BOOL cents = fabs(vet.vetCost - round(vet.vetCost)) > 0.001;
        self.costLabel.text = [NSString stringWithFormat:cents ? @"%.2f %@" : @"%.0f %@", vet.vetCost, [Language isRTL] ? @"ر.ق" : @"QAR"];
        self.costLabel.textColor = PrimaryTextClr;
    } else {
        self.costLabel.text = [Language isRTL] ? @"مجاني" : @"Free";
        self.costLabel.textColor = [UIColor ppSuccess];
    }

    self.callButton.hidden = (vet.phone.length == 0);
    self.whatsappButton.hidden = (vet.whatsapp.length == 0);
    if (vet.logoURL.length) {
        [self.logoView setImageFromUrl:vet.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
    } else {
        self.logoView.image = [UIImage systemImageNamed:vet.type == PPVetTypeCompany ? @"cross.case.fill" : @"stethoscope"];
        self.logoView.tintColor = AppPrimaryClr;
    }
    self.headerTapButton.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.titleLabel.text, status];
    self.profileActionButton.accessibilityLabel = [NSString stringWithFormat:@"%@ — %@", kLang(@"Vet_Roster_View_Profile"), self.titleLabel.text];
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
    if (animated && !PPMotionReduced() && !UIAccessibilityIsReduceMotionEnabled()) PPAnimateRespectingMotion(PPAnimDurationNormal, apply, nil);
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
    self.subscriptionLabel.text = nil;
    self.costLabel.text = nil;
    self.headerTapButton.accessibilityLabel = nil;
    self.profileActionButton.accessibilityLabel = kLang(@"Vet_Roster_View_Profile");
    self.onOpenTapped = nil;
    self.onCallTapped = nil;
    self.onWhatsAppTapped = nil;
    self.onToggleStatusTapped = nil;
    self.canManageStatus = NO;
    self.isSplitSelected = NO;
    self.cardView.transform = CGAffineTransformIdentity;
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
