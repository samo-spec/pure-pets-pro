//
//  PPVetCell.m
//  PurePetsPro
//
//  Reinvented from first principles for iPhone & iPad.
//

#import "PPVetCell.h"
#import "PPVetModel.h"
#import "PPFunc+Haptics.h"
#import "PPDesignTokens.h"
#import "UIImageView+WebCache.h"

static CGFloat const kCellLogoSize    = 66.0;
static CGFloat const kCellRingWidth   = 2.5;

@interface PPVetCell ()
@property (nonatomic, strong, readwrite) UIImageView *logoView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong, readwrite) UILabel *subscriptionLabel;
@property (nonatomic, strong, readwrite) UILabel *costLabel;
@property (nonatomic, strong, readwrite) UIView *cardView;
@property (nonatomic, strong) UIView *avatarRing;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *whatsappButton;
@property (nonatomic, strong) UIButton *statusToggleButton;
@property (nonatomic, strong) PPVetModel *currentVet;
@property (nonatomic, strong) NSLayoutConstraint *cardLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardTrailingConstraint;
@end

@implementation PPVetCell

+ (NSString *)reuseID { return @"PPVetCell"; }

+ (CGFloat)preferredHeight { return 172.0; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self buildUI];
    }
    return self;
}

#pragma mark - Build UI

- (void)buildUI {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat hPad = isPad ? 24.0 : 16.0;

    // ── Card Surface ──
    _cardView = [UIView new];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = AppForgroundColr;
    PPApplyContinuousCorners(_cardView, PPCornerCard);
    PPApplyCardShadow(_cardView);
    PPApplyCardBorder(_cardView);
    [self.contentView addSubview:_cardView];

    // ── Avatar ring ──
    _avatarRing = [UIView new];
    _avatarRing.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat ringSize = kCellLogoSize + kCellRingWidth * 2;
    _avatarRing.layer.cornerRadius = ringSize / 2.0;
    _avatarRing.layer.borderWidth = kCellRingWidth;
    _avatarRing.layer.borderColor = AppPrimaryClr.CGColor;
    _avatarRing.backgroundColor = UIColor.clearColor;
    [_cardView addSubview:_avatarRing];

    // ── Logo ──
    _logoView = [UIImageView new];
    _logoView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoView.contentMode = UIViewContentModeScaleAspectFill;
    _logoView.clipsToBounds = YES;
    _logoView.layer.cornerRadius = kCellLogoSize / 2.0;
    _logoView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    [_cardView addSubview:_logoView];

    // ── Live status dot ──
    _onlineDot = [UIView new];
    _onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    _onlineDot.layer.cornerRadius = 6.0;
    _onlineDot.layer.borderWidth = 2.0;
    _onlineDot.layer.borderColor = AppForgroundColr.CGColor;
    [_cardView addSubview:_onlineDot];

    // ── Title ──
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:17];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_titleLabel];

    // ── Subtitle (Practice type & Species) ──
    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [Styling fontMedium:12.5];
    _subtitleLabel.textColor = SeconderyTextClr;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.numberOfLines = 1;
    [_cardView addSubview:_subtitleLabel];

    // ── Bio Snippet ──
    _descriptionLabel = [UILabel new];
    _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionLabel.font = [Styling fontRegular:12];
    _descriptionLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.75];
    _descriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _descriptionLabel.numberOfLines = 1;
    [_cardView addSubview:_descriptionLabel];

    // ── Consultation Fee Label ──
    _costLabel = [UILabel new];
    _costLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _costLabel.font = [Styling fontBold:13];
    _costLabel.textColor = AppPrimaryClr;
    _costLabel.textAlignment = Language.isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;
    [_cardView addSubview:_costLabel];

    // ── Bottom Action Toolbar ──
    _statusToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _statusToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    _statusToggleButton.titleLabel.font = [Styling fontBold:11.5];
    PPApplyContinuousCorners(_statusToggleButton, PPCornerPill);
    _statusToggleButton.contentEdgeInsets = UIEdgeInsetsMake(4, 10, 4, 10);
    [_statusToggleButton addTarget:self action:@selector(statusToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_statusToggleButton];

    _subscriptionLabel = [UILabel new];
    _subscriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subscriptionLabel.font = [Styling fontBold:10.5];
    _subscriptionLabel.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_subscriptionLabel, PPCornerPill);
    _subscriptionLabel.layer.borderWidth = 1.0;
    [_cardView addSubview:_subscriptionLabel];

    _callButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _callButton.translatesAutoresizingMaskIntoConstraints = NO;
    _callButton.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.10];
    _callButton.tintColor = [UIColor ppInfo];
    PPApplyContinuousCorners(_callButton, PPCornerPill);
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
    [_callButton setImage:[UIImage systemImageNamed:@"phone.fill" withConfiguration:symCfg] forState:UIControlStateNormal];
    [_callButton setTitle:[Language isRTL] ? @" اتصال" : @" Call" forState:UIControlStateNormal];
    _callButton.titleLabel.font = [Styling fontBold:11];
    _callButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 10);
    [_callButton addTarget:self action:@selector(callTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_callButton];

    _whatsappButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _whatsappButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *waGreen = [UIColor colorWithRed:37.0/255.0 green:211.0/255.0 blue:102.0/255.0 alpha:1.0];
    _whatsappButton.backgroundColor = [waGreen colorWithAlphaComponent:0.12];
    _whatsappButton.tintColor = waGreen;
    PPApplyContinuousCorners(_whatsappButton, PPCornerPill);
    [_whatsappButton setImage:[UIImage systemImageNamed:@"message.circle.fill" withConfiguration:symCfg] forState:UIControlStateNormal];
    [_whatsappButton setTitle:[Language isRTL] ? @" واتساب" : @" WhatsApp" forState:UIControlStateNormal];
    _whatsappButton.titleLabel.font = [Styling fontBold:11];
    _whatsappButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 10);
    [_whatsappButton addTarget:self action:@selector(whatsappTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_whatsappButton];

    CGFloat textLeading = 16.0 + ringSize + 12.0;

    self.cardLeadingConstraint = [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:hPad];
    self.cardTrailingConstraint = [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-hPad];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7],
        self.cardLeadingConstraint,
        self.cardTrailingConstraint,
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7],

        // Avatar ring
        [_avatarRing.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_avatarRing.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16.0],
        [_avatarRing.widthAnchor constraintEqualToConstant:ringSize],
        [_avatarRing.heightAnchor constraintEqualToConstant:ringSize],

        // Logo
        [_logoView.centerXAnchor constraintEqualToAnchor:_avatarRing.centerXAnchor],
        [_logoView.centerYAnchor constraintEqualToAnchor:_avatarRing.centerYAnchor],
        [_logoView.widthAnchor constraintEqualToConstant:kCellLogoSize],
        [_logoView.heightAnchor constraintEqualToConstant:kCellLogoSize],

        // Online dot
        [_onlineDot.bottomAnchor constraintEqualToAnchor:_avatarRing.bottomAnchor constant:-1],
        [_onlineDot.trailingAnchor constraintEqualToAnchor:_avatarRing.trailingAnchor constant:-1],
        [_onlineDot.widthAnchor constraintEqualToConstant:12.0],
        [_onlineDot.heightAnchor constraintEqualToConstant:12.0],

        // Cost Label (top trailing)
        [_costLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16.0],
        [_costLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],

        // Title
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:15.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:textLeading],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_costLabel.leadingAnchor constant:-8],

        // Subtitle
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],

        // Description
        [_descriptionLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:3],
        [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],

        // Action Toolbar
        [_statusToggleButton.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-12.0],
        [_statusToggleButton.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_statusToggleButton.heightAnchor constraintEqualToConstant:28.0],

        [_subscriptionLabel.centerYAnchor constraintEqualToAnchor:_statusToggleButton.centerYAnchor],
        [_subscriptionLabel.leadingAnchor constraintEqualToAnchor:_statusToggleButton.trailingAnchor constant:8.0],
        [_subscriptionLabel.heightAnchor constraintEqualToConstant:26.0],

        [_whatsappButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_whatsappButton.centerYAnchor constraintEqualToAnchor:_statusToggleButton.centerYAnchor],
        [_whatsappButton.heightAnchor constraintEqualToConstant:28.0],

        [_callButton.trailingAnchor constraintEqualToAnchor:_whatsappButton.leadingAnchor constant:-6.0],
        [_callButton.centerYAnchor constraintEqualToAnchor:_statusToggleButton.centerYAnchor],
        [_callButton.heightAnchor constraintEqualToConstant:28.0],
    ]];
}

#pragma mark - Configure

- (void)configureWithVet:(PPVetModel *)vet {
    _currentVet = vet;

    // Title
    self.titleLabel.text = vet.title.length ? vet.title : ([Language isRTL] ? @"طبيب بيطري معتمد" : @"Licensed Veterinarian");

    // Subtitle
    NSMutableArray *parts = [NSMutableArray array];
    NSString *typeName = [vet localizedTypeName];
    if (typeName.length) [parts addObject:typeName];
    if (vet.animalTypes.count) {
        [parts addObject:[vet.animalTypes componentsJoinedByString:@", "]];
    }
    self.subtitleLabel.text = [parts componentsJoinedByString:@" · "];

    // Description snippet
    self.descriptionLabel.text = vet.descriptionText.length
        ? vet.descriptionText
        : ([Language isRTL] ? @"متوفر للاستشارات والفحوصات الطبية المعتمدة" : @"Available for veterinary consultations & care");

    // Status toggle & active appearance
    BOOL disabled = vet.isDisabled;
    if (disabled) {
        [self.statusToggleButton setTitle:[Language isRTL] ? @"● معطل" : @"● Disabled" forState:UIControlStateNormal];
        [self.statusToggleButton setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
        self.statusToggleButton.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.10];
        self.onlineDot.backgroundColor = [UIColor ppError];
        self.avatarRing.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.2].CGColor;
        self.cardView.alpha = 0.72;
    } else {
        [self.statusToggleButton setTitle:[Language isRTL] ? @"● نشط" : @"● Active" forState:UIControlStateNormal];
        [self.statusToggleButton setTitleColor:[UIColor ppSuccess] forState:UIControlStateNormal];
        self.statusToggleButton.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        self.onlineDot.backgroundColor = [UIColor ppSuccess];
        self.avatarRing.layer.borderColor = AppPrimaryClr.CGColor;
        self.cardView.alpha = 1.0;
    }

    // Subscription Pill
    NSString *tierName = [vet localizedSubscriptionTierName];
    BOOL expired = [vet isSubscriptionExpired];
    self.subscriptionLabel.text = [NSString stringWithFormat:@"  %@  ", tierName.length ? tierName : ([Language isRTL] ? @"اشتراك ساري" : @"Active Tier")];
    if (expired) {
        self.subscriptionLabel.textColor = [UIColor ppError];
        self.subscriptionLabel.layer.borderColor = [UIColor ppError].CGColor;
    } else {
        self.subscriptionLabel.textColor = AppPrimaryClr;
        self.subscriptionLabel.layer.borderColor = [[self pp_accentColor] colorWithAlphaComponent:0.35].CGColor;
    }

    // Consultation Fee
    if (vet.vetCost > 0) {
        self.costLabel.text = [NSString stringWithFormat:@"%.0f %@", vet.vetCost, [Language isRTL] ? @"ر.ق" : @"QAR"];
        self.costLabel.hidden = NO;
    } else {
        self.costLabel.text = [Language isRTL] ? @"مجاني" : @"Free";
        self.costLabel.hidden = NO;
    }

    // Call and WhatsApp direct buttons
    self.callButton.hidden = (vet.phone.length == 0);
    self.whatsappButton.hidden = (vet.whatsapp.length == 0);

    // Doctor Avatar
    if (vet.logoURL.length > 0) {
        [self.logoView setImageFromUrl:vet.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
    } else {
        self.logoView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.logoView.tintColor = AppPrimaryClr;
    }
}

- (UIColor *)pp_accentColor {
    return AppPrimaryClr;
}

#pragma mark - Actions

- (void)callTapped {
    [PPFunc pp_playTapEffect];
    if (self.onCallTapped && self.currentVet) {
        self.onCallTapped(self.currentVet);
    }
}

- (void)whatsappTapped {
    [PPFunc pp_playTapEffect];
    if (self.onWhatsAppTapped && self.currentVet) {
        self.onWhatsAppTapped(self.currentVet);
    }
}

- (void)statusToggleTapped {
    [PPFunc pp_playTapEffect];
    if (self.onToggleStatusTapped && self.currentVet) {
        self.onToggleStatusTapped(self.currentVet);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.logoView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.descriptionLabel.text = nil;
    self.costLabel.text = nil;
    self.currentVet = nil;
    self.onCallTapped = nil;
    self.onWhatsAppTapped = nil;
    self.onToggleStatusTapped = nil;
    self.cardView.alpha = 1.0;
}

#pragma mark - Selection Feedback

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    CGFloat scale = highlighted ? 0.98 : 1.0;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
}

@end
