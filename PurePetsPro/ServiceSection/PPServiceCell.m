//
//  PPServiceCell.m
//  PurePetsPro
//
//  Category-defining service card with spatial continuous curvature,
//  multi-tag pet species pills, inline availability switch, and live price badge.
//

#import "PPServiceCell.h"
#import "PPServiceModel.h"
#import "UIImageView+WebCache.h"

static CGFloat const kCardRadius     = 22.0;
static CGFloat const kImageSize      = 74.0;
static CGFloat const kImageRadius    = 18.0;
static CGFloat const kHPad           = 14.0;
static CGFloat const kVPad           = 14.0;

@interface PPServiceCell ()
@property (nonatomic, strong, readwrite) UIView *cardView;
@property (nonatomic, strong, readwrite) UIImageView *serviceImageView;
@property (nonatomic, strong) UIView *typeEmblemBg;
@property (nonatomic, strong) UIImageView *typeEmblemIcon;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *speciesPill;
@property (nonatomic, strong) UILabel *durationPill;
@property (nonatomic, strong, readwrite) UISwitch *inlineSwitch;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *pricePillBg;
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

#pragma mark - Build UI

- (void)buildUI {
    // ── Outer Card ──
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
    [_cardView addSubview:_serviceImageView];

    // ── Floating Type Emblem (bottom-trailing of image) ──
    _typeEmblemBg = [UIView new];
    _typeEmblemBg.translatesAutoresizingMaskIntoConstraints = NO;
    _typeEmblemBg.backgroundColor = AppPrimaryClr;
    _typeEmblemBg.layer.cornerRadius = 12.0;
    _typeEmblemBg.layer.borderWidth = 2.0;
    _typeEmblemBg.layer.borderColor = [UIColor ppElevatedSurface].CGColor;
    [_cardView addSubview:_typeEmblemBg];

    _typeEmblemIcon = [UIImageView new];
    _typeEmblemIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _typeEmblemIcon.tintColor = UIColor.whiteColor;
    _typeEmblemIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_typeEmblemBg addSubview:_typeEmblemIcon];

    // ── Title ──
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:15.5];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_titleLabel];

    // ── Species Tag Chip ──
    _speciesPill = [UILabel new];
    _speciesPill.translatesAutoresizingMaskIntoConstraints = NO;
    _speciesPill.font = [Styling fontBold:10];
    _speciesPill.textColor = AppPrimaryClr;
    _speciesPill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    _speciesPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_speciesPill, 6.0);
    _speciesPill.clipsToBounds = YES;
    [_cardView addSubview:_speciesPill];

    // ── Subtitle / Description ──
    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [Styling fontMedium:12];
    _subtitleLabel.textColor = SeconderyTextClr;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_subtitleLabel];

    // ── Price Pill Container ──
    _pricePillBg = [UIView new];
    _pricePillBg.translatesAutoresizingMaskIntoConstraints = NO;
    _pricePillBg.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(_pricePillBg, 11.0);
    [_cardView addSubview:_pricePillBg];

    _priceLabel = [UILabel new];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [Styling fontBold:13.5];
    _priceLabel.textColor = [UIColor ppSuccess];
    _priceLabel.textAlignment = NSTextAlignmentCenter;
    [_pricePillBg addSubview:_priceLabel];

    // ── Status Badge with Dot ──
    _statusBadge = [UILabel new];
    _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadge.font = [Styling fontBold:10.5];
    _statusBadge.textColor = SeconderyTextClr;
    _statusBadge.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_statusBadge];

    _statusDot = [UIView new];
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    _statusDot.layer.cornerRadius = 4.0;
    _statusDot.backgroundColor = [UIColor ppSuccess];
    [_cardView addSubview:_statusDot];

    // ── Duration Pill ──
    _durationPill = [UILabel new];
    _durationPill.translatesAutoresizingMaskIntoConstraints = NO;
    _durationPill.font = [Styling fontMedium:10.5];
    _durationPill.textColor = SeconderyTextClr;
    _durationPill.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_durationPill];

    // ── Inline Availability Switch ──
    _inlineSwitch = [[UISwitch alloc] init];
    _inlineSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _inlineSwitch.onTintColor = [UIColor ppSuccess];
    _inlineSwitch.transform = CGAffineTransformMakeScale(0.78, 0.78);
    [_inlineSwitch addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    [_cardView addSubview:_inlineSwitch];

    // ── Chevron ──
    _chevronView = [UIImageView new];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"
                                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightSemibold]];
    _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.35];
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [_cardView addSubview:_chevronView];

    // ── Auto Layout Constraints (Leading/Trailing Safe for RTL) ──
    [NSLayoutConstraint activateConstraints:@[
        // Card bounds
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

        // Image thumbnail
        [_serviceImageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:kHPad],
        [_serviceImageView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:kVPad],
        [_serviceImageView.widthAnchor constraintEqualToConstant:kImageSize],
        [_serviceImageView.heightAnchor constraintEqualToConstant:kImageSize],

        // Type Emblem
        [_typeEmblemBg.trailingAnchor constraintEqualToAnchor:_serviceImageView.trailingAnchor constant:5.0],
        [_typeEmblemBg.bottomAnchor constraintEqualToAnchor:_serviceImageView.bottomAnchor constant:5.0],
        [_typeEmblemBg.widthAnchor constraintEqualToConstant:24.0],
        [_typeEmblemBg.heightAnchor constraintEqualToConstant:24.0],
        [_typeEmblemIcon.centerXAnchor constraintEqualToAnchor:_typeEmblemBg.centerXAnchor],
        [_typeEmblemIcon.centerYAnchor constraintEqualToAnchor:_typeEmblemBg.centerYAnchor],
        [_typeEmblemIcon.widthAnchor constraintEqualToConstant:13.0],
        [_typeEmblemIcon.heightAnchor constraintEqualToConstant:13.0],

        // Title row
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:13.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_serviceImageView.trailingAnchor constant:14.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_speciesPill.leadingAnchor constant:-6.0],

        // Species tag pill
        [_speciesPill.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_speciesPill.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePillBg.leadingAnchor constant:-8.0],
        [_speciesPill.heightAnchor constraintEqualToConstant:19.0],

        // Price Pill
        [_pricePillBg.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:12.0],
        [_pricePillBg.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-kHPad],
        [_pricePillBg.heightAnchor constraintEqualToConstant:25.0],
        [_priceLabel.topAnchor constraintEqualToAnchor:_pricePillBg.topAnchor],
        [_priceLabel.bottomAnchor constraintEqualToAnchor:_pricePillBg.bottomAnchor],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_pricePillBg.leadingAnchor constant:10.0],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_pricePillBg.trailingAnchor constant:-10.0],

        // Subtitle / Description
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        // Bottom status & controls row
        [_statusDot.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_statusDot.centerYAnchor constraintEqualToAnchor:_statusBadge.centerYAnchor],
        [_statusDot.widthAnchor constraintEqualToConstant:8.0],
        [_statusDot.heightAnchor constraintEqualToConstant:8.0],

        [_statusBadge.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:6.0],
        [_statusBadge.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-12.0],

        [_durationPill.leadingAnchor constraintEqualToAnchor:_statusBadge.trailingAnchor constant:12.0],
        [_durationPill.centerYAnchor constraintEqualToAnchor:_statusBadge.centerYAnchor],

        // Chevron
        [_chevronView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-kHPad],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_statusBadge.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:8.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        // Inline Switch
        [_inlineSwitch.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_inlineSwitch.centerYAnchor constraintEqualToAnchor:_statusBadge.centerYAnchor],
    ]];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    if (self.onToggleAvailability) {
        self.onToggleAvailability(sender.isOn);
    }
}

#pragma mark - Configuration

- (void)configureWithService:(PPServiceModel *)service {
    _currentService = service;

    self.titleLabel.text = service.title ?: @"—";
    self.subtitleLabel.text = (service.descriptionText.length > 0) ? service.descriptionText : [service localizedTypeName];

    // Formatted Price in QAR
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

    // Type emblem icon
    NSString *iconName = @"scissors";
    if (service.type == PPServiceTypeTraining) {
        iconName = @"figure.walk";
    } else if ([service.category.lowercaseString containsString:@"health"] || [service.category.lowercaseString containsString:@"clinic"]) {
        iconName = @"heart.text.square.fill";
    } else if ([service.category.lowercaseString containsString:@"board"] || [service.category.lowercaseString containsString:@"hotel"]) {
        iconName = @"house.fill";
    }
    self.typeEmblemIcon.image = [UIImage systemImageNamed:iconName
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]];

    // Status dot & badge
    BOOL live = service.isLive;
    self.inlineSwitch.on = live;

    if (service.isBlocked) {
        self.statusDot.backgroundColor = [UIColor ppError];
        self.statusBadge.text = kLang(@"statusBlocked");
        self.statusBadge.textColor = [UIColor ppError];
    } else if (service.isDisabled) {
        self.statusDot.backgroundColor = [UIColor ppError];
        self.statusBadge.text = kLang(@"statusDisabled");
        self.statusBadge.textColor = [UIColor ppError];
    } else if (!service.isAvailable) {
        self.statusDot.backgroundColor = [UIColor ppWarning];
        self.statusBadge.text = kLang(@"Serv_Unavailable");
        self.statusBadge.textColor = [UIColor ppWarning];
    } else {
        self.statusDot.backgroundColor = [UIColor ppSuccess];
        self.statusBadge.text = kLang(@"Serv_Available");
        self.statusBadge.textColor = [UIColor ppSuccess];
    }

    // Duration micro-badge
    self.durationPill.text = [NSString stringWithFormat:@"⏱️ %@", [NSString stringWithFormat:kLang(@"Serv_Duration_Format"), (long)45]];

    // Photo Loading with smooth shimmer
    if (service.imageURL.length > 0) {
        [self.serviceImageView sd_setImageWithURL:[NSURL URLWithString:service.imageURL]
                                placeholderImage:[UIImage systemImageNamed:@"sparkles"]];
        self.serviceImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.3];
    } else {
        self.serviceImageView.image = [UIImage systemImageNamed:@"sparkles"
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightLight]];
        self.serviceImageView.tintColor = AppPrimaryClr;
        self.serviceImageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.cardView.transform = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    } completion:nil];
}

@end

