#import "PPFulfillmentCell.h"
#import "PPFulfillmentModel.h"

@interface PPFulfillmentCell ()
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UILabel *referenceLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *itemsLabel;
@property (nonatomic, strong) UILabel *nextLabel;
@property (nonatomic, strong) UILabel *moneyLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@end

@implementation PPFulfillmentCell

+ (NSString *)reuseIdentifier { return @"PPFulfillmentCell"; }
+ (CGFloat)preferredHeight { return 180.0; } // Estimate only; rows grow with content.

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        _surface = [[UIView alloc] init];
        _surface.backgroundColor = [UIColor ppSurface];
        _surface.layer.cornerRadius = PPCornerCard;
        _surface.layer.cornerCurve = kCACornerCurveContinuous;
        _surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _surface.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_surface];

        UIStackView *content = [[UIStackView alloc] init];
        content.axis = UILayoutConstraintAxisVertical;
        content.spacing = 8.0;
        content.semanticContentAttribute = self.semanticContentAttribute;
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [_surface addSubview:content];
        _referenceLabel = [self labelWithFont:[Styling fontBold:21] color:[UIColor ppTextPrimary]];
        _statusLabel = [self labelWithFont:[Styling fontBold:15] color:[UIColor ppTextSecondary]];
        _itemsLabel = [self labelWithFont:[Styling fontRegular:15] color:[UIColor ppTextSecondary]];
        _nextLabel = [self labelWithFont:[Styling fontBold:17] color:[UIColor ppPrimary]];
        _moneyLabel = [self labelWithFont:[Styling fontMedium:14] color:[UIColor ppTextPrimary]];
        _dateLabel = [self labelWithFont:[Styling fontRegular:13] color:[UIColor ppTextSecondary]];
        for (UILabel *label in @[_referenceLabel, _statusLabel, _itemsLabel, _nextLabel, _moneyLabel, _dateLabel]) {
            label.isAccessibilityElement = NO;
            [content addArrangedSubview:label];
        }
        [content setCustomSpacing:14.0 afterView:_itemsLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
            [content.leadingAnchor constraintEqualToAnchor:_surface.leadingAnchor constant:18],
            [content.trailingAnchor constraintEqualToAnchor:_surface.trailingAnchor constant:-18],
            [content.topAnchor constraintEqualToAnchor:_surface.topAnchor constant:18],
            [content.bottomAnchor constraintEqualToAnchor:_surface.bottomAnchor constant:-18],
        ]];
        [self updateBorder];
    }
    return self;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:font];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    return label;
}

- (void)configureWithModel:(PPFulfillmentModel *)model {
    NSString *reference = model.parentOrderNumber.length ? model.parentOrderNumber : model.fulfillmentID;
    self.referenceLabel.text = [NSString stringWithFormat:kLang(@"ProFulfillment_OrderReference"), reference ?: @"—"];
    self.statusLabel.text = model.statusDisplayName;
    self.statusLabel.textColor = model.statusColor;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (id item in model.items) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *name = PPSafeString(item[@"name"]);
        if (name.length) [names addObject:name];
        if (names.count == 2) break;
    }
    NSString *count = [NSString localizedStringWithFormat:kLang(@"ProFulfillment_ItemCount"), (long)model.itemCount];
    self.itemsLabel.text = names.count ? [NSString stringWithFormat:@"%@ · %@", count, [NSListFormatter localizedStringByJoiningStrings:names]] : count;
    self.nextLabel.text = model.requiresProviderAction
        ? [NSString stringWithFormat:kLang(@"ProFulfillment_NextAction"), model.nextActionForStatus]
        : model.waitingDescription;
    self.nextLabel.textColor = model.requiresProviderAction ? [UIColor ppPrimary] : [UIColor ppTextSecondary];
    NSNumberFormatter *money = [[NSNumberFormatter alloc] init];
    money.locale = [NSLocale localeWithLocaleIdentifier:[Language isRTL] ? @"ar_QA" : @"en_QA"];
    money.numberStyle = NSNumberFormatterCurrencyStyle;
    money.currencyCode = model.currency;
    self.moneyLabel.text = model.hasMoneyProjection
        ? [NSString stringWithFormat:@"%@: %@", kLang(@"Fulfillment_ProviderNet"), [money stringFromNumber:@(model.providerNet)]]
        : kLang(@"ProFulfillment_MoneyUnavailable");
    NSDateFormatter *date = [[NSDateFormatter alloc] init];
    date.locale = money.locale;
    date.dateStyle = NSDateFormatterMediumStyle;
    date.timeStyle = NSDateFormatterShortStyle;
    NSDate *updated = model.updatedAt ?: model.createdAt;
    self.dateLabel.text = updated ? [NSString stringWithFormat:@"%@: %@", kLang(@"Fulfillment_UpdatedAt"), [date stringFromDate:updated]] : nil;
    self.dateLabel.hidden = !updated;
    self.accessibilityLabel = [@[self.referenceLabel.text ?: @"", self.statusLabel.text ?: @"", self.itemsLabel.text ?: @"", self.nextLabel.text ?: @"", self.moneyLabel.text ?: @"", self.dateLabel.text ?: @""] componentsJoinedByString:@". "];
    self.accessibilityHint = kLang(@"ProFulfillment_OpenDossier");
    self.accessibilityIdentifier = [@"fulfillment.order." stringByAppendingString:model.fulfillmentID ?: @""];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.accessibilityLabel = nil;
    self.accessibilityIdentifier = nil;
    self.surface.backgroundColor = [UIColor ppSurface];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    // Native press feedback remains immediate and static under Reduce Motion.
    self.surface.backgroundColor = highlighted ? [UIColor ppSecondarySurface] : [UIColor ppSurface];
}

- (void)updateBorder { self.surface.layer.borderColor = [UIColor ppSurfaceBorder].CGColor; }
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateBorder];
}
@end
