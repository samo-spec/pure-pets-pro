//
//  PPServiceCell.m
//  PurePetsPro
//
//  Modern trending card-based service cell with type icon overlay,
//  glassmorphism-inspired card, capsule status badges, and verification dot.
//

#import "PPServiceCell.h"
#import "PPServiceModel.h"
#import "UIImageView+WebCache.h"

static CGFloat const kCardRadius     = 24.0;
static CGFloat const kImageSize      = 64.0;
static CGFloat const kImageRadius    = 18.0;
static CGFloat const kHPad           = 16.0;
static CGFloat const kVPad           = 16.0;
static CGFloat const kBadgeH         = 22.0;
static CGFloat const kBadgeRadius    = 11.0;
static CGFloat const kTypeIconSize   = 22.0;
static CGFloat const kVerifDotSize   = 8.0;

@interface PPServiceCell ()
@property (nonatomic, strong, readwrite) UIImageView *serviceImageView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong, readwrite) UILabel *statusBadge;
@property (nonatomic, strong, readwrite) UIView  *cardView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView  *typeIconBg;
@property (nonatomic, strong) UIImageView *typeIconView;
@property (nonatomic, strong) UIView  *verifDot;
@property (nonatomic, strong) UILabel *priceCurrencyLabel;
@end

@implementation PPServiceCell

+ (NSString *)reuseID { return @"PPServiceCell"; }

+ (CGFloat)preferredHeight { return 116.0; }

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
    // ── Card ──
    _cardView = [UIView new];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = AppForgroundColr;
    _cardView.layer.cornerRadius = kCardRadius;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    _cardView.layer.shadowOpacity = 0.06;
    _cardView.layer.shadowRadius = 16;
    _cardView.layer.shadowOffset = CGSizeMake(0, 6);
    _cardView.layer.borderWidth = 0.5;
    _cardView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    [self.contentView addSubview:_cardView];

    // ── Image ──
    _serviceImageView = [UIImageView new];
    _serviceImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _serviceImageView.contentMode = UIViewContentModeScaleAspectFill;
    _serviceImageView.clipsToBounds = YES;
    _serviceImageView.layer.cornerRadius = kImageRadius;
    _serviceImageView.layer.cornerCurve = kCACornerCurveContinuous;
    _serviceImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    [_cardView addSubview:_serviceImageView];

    // ── Type icon overlay (bottom-trailing of image) ──
    _typeIconBg = [UIView new];
    _typeIconBg.translatesAutoresizingMaskIntoConstraints = NO;
    _typeIconBg.backgroundColor = AppPrimaryClr;
    _typeIconBg.layer.cornerRadius = kTypeIconSize / 2.0;
    _typeIconBg.layer.borderWidth = 2.0;
    _typeIconBg.layer.borderColor = AppForgroundColr.CGColor;
    [_cardView addSubview:_typeIconBg];

    _typeIconView = [UIImageView new];
    _typeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _typeIconView.tintColor = UIColor.whiteColor;
    _typeIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_typeIconBg addSubview:_typeIconView];

    // ── Title ──
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:16];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_titleLabel];

    // ── Verification dot (next to title) ──
    _verifDot = [UIView new];
    _verifDot.translatesAutoresizingMaskIntoConstraints = NO;
    _verifDot.layer.cornerRadius = kVerifDotSize / 2.0;
    _verifDot.hidden = YES;
    [_cardView addSubview:_verifDot];

    // ── Subtitle ──
    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [Styling fontMedium:12];
    _subtitleLabel.textColor = SeconderyTextClr;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_subtitleLabel];

    // ── Status badge (capsule) ──
    _statusBadge = [UILabel new];
    _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadge.font = [Styling fontBold:10];
    _statusBadge.textColor = UIColor.whiteColor;
    _statusBadge.textAlignment = NSTextAlignmentCenter;
    _statusBadge.layer.cornerRadius = kBadgeRadius;
    _statusBadge.clipsToBounds = YES;
    [_cardView addSubview:_statusBadge];

    // ── Price ──
    _priceLabel = [UILabel new];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [Styling fontBold:15];
    _priceLabel.textColor = AppPrimaryClr;
    _priceLabel.textAlignment = NSTextAlignmentRight;
    [_cardView addSubview:_priceLabel];

    _priceCurrencyLabel = [UILabel new];
    _priceCurrencyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceCurrencyLabel.font = [Styling fontMedium:10];
    _priceCurrencyLabel.textColor = [AppPrimaryClr colorWithAlphaComponent:0.7];
    _priceCurrencyLabel.textAlignment = NSTextAlignmentRight;
    [_cardView addSubview:_priceCurrencyLabel];

    // ── Chevron ──
    _chevronView = [UIImageView new];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]];
    _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.3];
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [_cardView addSubview:_chevronView];

    // ── Layout ──
    CGFloat textLeading = kHPad + kImageSize + 14;

    [NSLayoutConstraint activateConstraints:@[
        // Card
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

        // Image
        [_serviceImageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:kHPad],
        [_serviceImageView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_serviceImageView.widthAnchor constraintEqualToConstant:kImageSize],
        [_serviceImageView.heightAnchor constraintEqualToConstant:kImageSize],

        // Type icon
        [_typeIconBg.trailingAnchor constraintEqualToAnchor:_serviceImageView.trailingAnchor constant:4],
        [_typeIconBg.bottomAnchor constraintEqualToAnchor:_serviceImageView.bottomAnchor constant:4],
        [_typeIconBg.widthAnchor constraintEqualToConstant:kTypeIconSize],
        [_typeIconBg.heightAnchor constraintEqualToConstant:kTypeIconSize],
        [_typeIconView.centerXAnchor constraintEqualToAnchor:_typeIconBg.centerXAnchor],
        [_typeIconView.centerYAnchor constraintEqualToAnchor:_typeIconBg.centerYAnchor],
        [_typeIconView.widthAnchor constraintEqualToConstant:12],
        [_typeIconView.heightAnchor constraintEqualToConstant:12],

        // Title
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:kVPad],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:textLeading],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_priceLabel.leadingAnchor constant:-8],

        // Verif dot
        [_verifDot.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_verifDot.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:6],
        [_verifDot.widthAnchor constraintEqualToConstant:kVerifDotSize],
        [_verifDot.heightAnchor constraintEqualToConstant:kVerifDotSize],

        // Subtitle
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-8],

        // Status badge
        [_statusBadge.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-kVPad],
        [_statusBadge.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_statusBadge.heightAnchor constraintEqualToConstant:kBadgeH],
        [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:64],

        // Price
        [_priceLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:kVPad],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-6],
        [_priceCurrencyLabel.topAnchor constraintEqualToAnchor:_priceLabel.bottomAnchor constant:0],
        [_priceCurrencyLabel.trailingAnchor constraintEqualToAnchor:_priceLabel.trailingAnchor],

        // Chevron
        [_chevronView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-kHPad],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:10],
        [_chevronView.heightAnchor constraintEqualToConstant:14],
    ]];
}

#pragma mark - Configure

- (void)configureWithService:(PPServiceModel *)service {
    self.titleLabel.text = service.title ?: @"—";
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@ · %@",
                               [service localizedTypeName],
                               service.category ?: @""];

    // Price
    self.priceLabel.text = [NSString stringWithFormat:@"%.2f", service.price];
    self.priceCurrencyLabel.text = kLang(@"Serv_Currency");

    // Type icon
    NSString *iconName = (service.type == PPServiceTypeGrooming) ? @"scissors" : @"figure.walk";
    self.typeIconView.image = [UIImage systemImageNamed:iconName
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold]];

    // Status badge — provider-facing availability
    if (service.isBlocked) {
        [self applyBadge:kLang(@"statusBlocked") color:[UIColor ppError]];
    } else if (service.isDisabled) {
        [self applyBadge:kLang(@"statusDisabled") color:[UIColor ppError]];
    } else if (!service.isAvailable) {
        [self applyBadge:kLang(@"Serv_Unavailable") color:[UIColor ppWarning]];
    } else {
        [self applyBadge:kLang(@"Serv_Available") color:[UIColor ppSuccess]];
    }

    // Verification dot
    NSString *v = [service.verificationStatus lowercaseString] ?: @"";
    if ([v isEqualToString:@"verified"]) {
        self.verifDot.hidden = NO;
        self.verifDot.backgroundColor = [UIColor ppSuccess];
    } else if ([v isEqualToString:@"pending"] || [v isEqualToString:@"pending_review"]) {
        self.verifDot.hidden = NO;
        self.verifDot.backgroundColor = [UIColor ppWarning];
    } else if ([v isEqualToString:@"rejected"] || [v isEqualToString:@"blocked"]) {
        self.verifDot.hidden = NO;
        self.verifDot.backgroundColor = [UIColor ppError];
    } else {
        self.verifDot.hidden = YES;
    }

    // Image
    if (service.imageURL.length > 0) {
        [self.serviceImageView sd_setImageWithURL:[NSURL URLWithString:service.imageURL]
                               placeholderImage:[UIImage systemImageNamed:@"sparkles"]];
    } else {
        self.serviceImageView.image = [UIImage systemImageNamed:@"sparkles"];
        self.serviceImageView.tintColor = AppPrimaryClr;
        self.serviceImageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)applyBadge:(NSString *)text color:(UIColor *)color {
    self.statusBadge.text = [NSString stringWithFormat:@"  %@  ", text];
    self.statusBadge.backgroundColor = [color colorWithAlphaComponent:0.15];
    self.statusBadge.textColor = color;
    self.statusBadge.layer.cornerRadius = kBadgeRadius;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.cardView.transform = highlighted ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
    } completion:nil];
}

@end
