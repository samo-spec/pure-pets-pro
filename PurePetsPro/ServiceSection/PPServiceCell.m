//
//  PPServiceCell.m
//  PurePetsPro
//
//  NextGen V8 Studio-Grade Pet Service Atelier Card.
//  Continuous spatial curvature, species vector emblem, micro-stepper tap zone,
//  and tactile inline availability switch.
//

#import "PPServiceCell.h"
#import "PPServiceModel.h"
#import "UIImageView+WebCache.h"
#import "PPDesignTokens.h"
#import "Styling.h"
#import "Language.h"
#import "PPFunc.h"

static CGFloat const kCardRadius  = 18.0;
static CGFloat const kImageSize   = 76.0;
static CGFloat const kImageRadius = 15.0;

@interface PPServiceCell ()
@property (nonatomic, strong, readwrite) UIView *cardView;
@property (nonatomic, strong, readwrite) UIImageView *serviceImageView;
@property (nonatomic, strong) UIView *typeEmblemBg;
@property (nonatomic, strong) UIImageView *typeEmblemIcon;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong) UIButton *priceButton;
@property (nonatomic, strong) UIStackView *metaPillStack;
@property (nonatomic, strong) UIView *statusBadgeContainer;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong) UILabel *speciesPill;
@property (nonatomic, strong) UILabel *durationPill;
@property (nonatomic, strong, readwrite) UISwitch *inlineSwitch;
@property (nonatomic, strong) PPServiceModel *currentService;
@end

@implementation PPServiceCell

+ (NSString *)reuseID { return @"PPServiceCell"; }

+ (CGFloat)preferredHeight { return 138.0; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    // ── Outer Card Surface ──
    _cardView = [UIView new];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(_cardView, kCardRadius);
    _cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _cardView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(_cardView);
    [self.contentView addSubview:_cardView];

    // ── Photo Thumbnail ──
    _serviceImageView = [UIImageView new];
    _serviceImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _serviceImageView.contentMode = UIViewContentModeScaleAspectFill;
    _serviceImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_serviceImageView, kImageRadius);
    _serviceImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    _serviceImageView.layer.borderWidth = 0.5;
    _serviceImageView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.18].CGColor;
    [_cardView addSubview:_serviceImageView];

    // ── Type Emblem (Small circular badge at corner of image) ──
    _typeEmblemBg = [UIView new];
    _typeEmblemBg.translatesAutoresizingMaskIntoConstraints = NO;
    _typeEmblemBg.backgroundColor = AppPrimaryClr;
    _typeEmblemBg.layer.cornerRadius = 11.0;
    _typeEmblemBg.layer.borderWidth = 1.5;
    _typeEmblemBg.layer.borderColor = [UIColor ppElevatedSurface].CGColor;
    [_cardView addSubview:_typeEmblemBg];

    _typeEmblemIcon = [UIImageView new];
    _typeEmblemIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _typeEmblemIcon.tintColor = UIColor.whiteColor;
    _typeEmblemIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_typeEmblemBg addSubview:_typeEmblemIcon];

    // ── Price Pill Button (Tappable for Quick Pricing Stepper) ──
    _priceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _priceButton.translatesAutoresizingMaskIntoConstraints = NO;
    _priceButton.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(_priceButton, 12.0);
    _priceButton.layer.borderWidth = 0.5;
    _priceButton.layer.borderColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.25].CGColor;
    [_priceButton addTarget:self action:@selector(priceButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_priceButton];

    _priceLabel = [UILabel new];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [Styling fontBold:13.5];
    _priceLabel.textColor = [UIColor ppSuccess];
    _priceLabel.textAlignment = NSTextAlignmentCenter;
    [_priceButton addSubview:_priceLabel];

    // ── Title ──
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:15.5];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_titleLabel];

    // ── Subtitle / Description ──
    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [Styling fontRegular:12.0];
    _subtitleLabel.textColor = SeconderyTextClr;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_subtitleLabel];

    // ── Bottom Controls Row: Horizontal Stack for Metadata ──
    _metaPillStack = [[UIStackView alloc] init];
    _metaPillStack.translatesAutoresizingMaskIntoConstraints = NO;
    _metaPillStack.axis = UILayoutConstraintAxisHorizontal;
    _metaPillStack.alignment = UIStackViewAlignmentCenter;
    _metaPillStack.spacing = 6.0;
    [_cardView addSubview:_metaPillStack];

    // Status Badge with Dot inside an integrated container
    _statusBadgeContainer = [UIView new];
    _statusBadgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgeContainer.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(_statusBadgeContainer, 6.0);

    _statusDot = [UIView new];
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    _statusDot.layer.cornerRadius = 3.5;
    _statusDot.backgroundColor = [UIColor ppSuccess];
    [_statusBadgeContainer addSubview:_statusDot];

    _statusBadge = [UILabel new];
    _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadge.font = [Styling fontBold:10.5];
    _statusBadge.textColor = [UIColor ppSuccess];
    _statusBadge.textAlignment = Language.alignmentForCurrentLanguage;
    [_statusBadgeContainer addSubview:_statusBadge];

    [NSLayoutConstraint activateConstraints:@[
        [_statusDot.leadingAnchor constraintEqualToAnchor:_statusBadgeContainer.leadingAnchor constant:6.0],
        [_statusDot.centerYAnchor constraintEqualToAnchor:_statusBadgeContainer.centerYAnchor],
        [_statusDot.widthAnchor constraintEqualToConstant:7.0],
        [_statusDot.heightAnchor constraintEqualToConstant:7.0],

        [_statusBadge.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:4.0],
        [_statusBadge.trailingAnchor constraintEqualToAnchor:_statusBadgeContainer.trailingAnchor constant:-6.0],
        [_statusBadge.centerYAnchor constraintEqualToAnchor:_statusBadgeContainer.centerYAnchor],

        [_statusBadgeContainer.heightAnchor constraintEqualToConstant:20.0]
    ]];

    [_metaPillStack addArrangedSubview:_statusBadgeContainer];

    // Species Tag Chip
    _speciesPill = [UILabel new];
    _speciesPill.translatesAutoresizingMaskIntoConstraints = NO;
    _speciesPill.font = [Styling fontBold:10.0];
    _speciesPill.textColor = AppPrimaryClr;
    _speciesPill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    _speciesPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_speciesPill, 6.0);
    _speciesPill.clipsToBounds = YES;
    [NSLayoutConstraint activateConstraints:@[
        [_speciesPill.heightAnchor constraintEqualToConstant:20.0]
    ]];
    [_metaPillStack addArrangedSubview:_speciesPill];

    // Duration Pill
    _durationPill = [UILabel new];
    _durationPill.translatesAutoresizingMaskIntoConstraints = NO;
    _durationPill.font = [Styling fontMedium:10.5];
    _durationPill.textColor = SeconderyTextClr;
    _durationPill.textAlignment = Language.alignmentForCurrentLanguage;
    [_metaPillStack addArrangedSubview:_durationPill];

    // ── Inline Availability Switch (Pinned at Trailing Edge) ──
    _inlineSwitch = [[UISwitch alloc] init];
    _inlineSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _inlineSwitch.onTintColor = [UIColor ppSuccess];
    _inlineSwitch.transform = CGAffineTransformMakeScale(0.74, 0.74);
    [_inlineSwitch addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    [_cardView addSubview:_inlineSwitch];

    // ── Unbreakable Auto Layout Constraints ──
    NSLayoutConstraint *cardHeight = [_cardView.heightAnchor constraintEqualToConstant:126.0];
    cardHeight.priority = UILayoutPriorityDefaultHigh; // 750

    [NSLayoutConstraint activateConstraints:@[
        // Card bounds
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
        cardHeight,

        // Image thumbnail (Centered vertically on leading side)
        [_serviceImageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12.0],
        [_serviceImageView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_serviceImageView.widthAnchor constraintEqualToConstant:kImageSize],
        [_serviceImageView.heightAnchor constraintEqualToConstant:kImageSize],

        // Type Emblem on corner of image
        [_typeEmblemBg.trailingAnchor constraintEqualToAnchor:_serviceImageView.trailingAnchor constant:3.0],
        [_typeEmblemBg.bottomAnchor constraintEqualToAnchor:_serviceImageView.bottomAnchor constant:3.0],
        [_typeEmblemBg.widthAnchor constraintEqualToConstant:22.0],
        [_typeEmblemBg.heightAnchor constraintEqualToConstant:22.0],
        [_typeEmblemIcon.centerXAnchor constraintEqualToAnchor:_typeEmblemBg.centerXAnchor],
        [_typeEmblemIcon.centerYAnchor constraintEqualToAnchor:_typeEmblemBg.centerYAnchor],
        [_typeEmblemIcon.widthAnchor constraintEqualToConstant:12.0],
        [_typeEmblemIcon.heightAnchor constraintEqualToConstant:12.0],

        // Price Button pinned to top-trailing
        [_priceButton.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:12.0],
        [_priceButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12.0],
        [_priceButton.heightAnchor constraintEqualToConstant:26.0],

        [_priceLabel.topAnchor constraintEqualToAnchor:_priceButton.topAnchor],
        [_priceLabel.bottomAnchor constraintEqualToAnchor:_priceButton.bottomAnchor],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_priceButton.leadingAnchor constant:9.0],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_priceButton.trailingAnchor constant:-9.0],

        // Title row (From image trailing to price leading)
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:13.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_serviceImageView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_priceButton.leadingAnchor constant:-8.0],

        // Subtitle / Description (Below title, bounded by card trailing)
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12.0],

        // Inline Switch pinned at bottom-trailing
        [_inlineSwitch.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-8.0],
        [_inlineSwitch.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-8.0],

        // Meta pill stack on bottom-leading (Never collides with switch)
        [_metaPillStack.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaPillStack.centerYAnchor constraintEqualToAnchor:_inlineSwitch.centerYAnchor],
        [_metaPillStack.trailingAnchor constraintLessThanOrEqualToAnchor:_inlineSwitch.leadingAnchor constant:-6.0]
    ]];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    BOOL isLive = sender.isOn;
    _statusDot.backgroundColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    _statusBadge.text = isLive ? ([Language isRTL] ? @"متاح" : @"Live") : ([Language isRTL] ? @"متوقف" : @"Paused");
    _statusBadge.textColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    _statusBadgeContainer.backgroundColor = isLive ? [[UIColor ppSuccess] colorWithAlphaComponent:0.08] : [[UIColor ppWarning] colorWithAlphaComponent:0.08];

    if (self.onToggleAvailability) {
        self.onToggleAvailability(isLive);
    }
}

- (void)priceButtonTapped {
    [PPFunc pp_playTapEffect];
    if (self.onTapPricing) {
        self.onTapPricing();
    }
}

#pragma mark - Configuration

- (void)configureWithService:(PPServiceModel *)service {
    _currentService = service;

    self.titleLabel.text = service.title ?: @"—";
    self.subtitleLabel.text = (service.descriptionText.length > 0) ? service.descriptionText : [service localizedTypeName];

    // Formatted Price in QAR with Beiruti numerals
    NSString *curr = service.currency.length > 0 ? service.currency : kLang(@"Serv_Currency");
    self.priceLabel.text = [NSString stringWithFormat:@"%.0f %@", service.price, curr];

    // Species Badge
    NSString *speciesName = kLang(@"Serv_Pet_All");
    if (service.petMainKindID == 1) {
        speciesName = [NSString stringWithFormat:@"🐕 %@", kLang(@"Serv_Pet_Dogs")];
    } else if (service.petMainKindID == 2) {
        speciesName = [NSString stringWithFormat:@"🐈 %@", kLang(@"Serv_Pet_Cats")];
    } else if (service.petMainKindID == 3) {
        speciesName = [NSString stringWithFormat:@"🦜 %@", kLang(@"Serv_Pet_Birds")];
    }
    self.speciesPill.text = [NSString stringWithFormat:@"  %@  ", speciesName];

    // Type Emblem Icon
    NSString *iconName = @"scissors";
    if (service.type == PPServiceTypeTraining) {
        iconName = @"figure.walk";
    }
    self.typeEmblemIcon.image = [UIImage systemImageNamed:iconName
                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]];

    // Duration
    self.durationPill.text = [NSString stringWithFormat:@"⏱ %@", [Language isRTL] ? @"45 دقيقة" : @"45 min"];

    // Availability State
    BOOL isLive = service.isLive;
    self.inlineSwitch.on = isLive;
    self.statusDot.backgroundColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    self.statusBadge.text = isLive ? ([Language isRTL] ? @"متاح" : @"Live") : ([Language isRTL] ? @"متوقف" : @"Paused");
    self.statusBadge.textColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    self.statusBadgeContainer.backgroundColor = isLive ? [[UIColor ppSuccess] colorWithAlphaComponent:0.08] : [[UIColor ppWarning] colorWithAlphaComponent:0.08];

    // Image loading
    if (service.imageURL.length > 0) {
        [self.serviceImageView sd_setImageWithURL:[NSURL URLWithString:service.imageURL]
                                placeholderImage:[UIImage imageNamed:@"placeholder_service"]];
    } else {
        self.serviceImageView.image = [UIImage imageNamed:@"placeholder_service"];
    }
}

@end
