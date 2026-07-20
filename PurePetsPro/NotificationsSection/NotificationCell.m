//
//  NotificationCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// NotificationCell.m
#import "NotificationCell.h"
#import "Styling.h"
#import "Language.h"

@implementation NotificationCell {
    UIView *_surfaceView;
    UIView *_iconShellView;
    UIImageView *_iconView;
    UIView *_dot;
    UILabel *_title;
    UILabel *_body;
    UILabel *_time;
    UIView *_statusPillView;
    UILabel *_statusLabel;
    UIImageView *_chevronView;
}

+ (NSString *)reuseId { return @"NotificationCell"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.preservesSuperviewLayoutMargins = NO;
        self.layoutMargins = UIEdgeInsetsZero;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        _surfaceView = [UIView new];
        _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        _surfaceView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
        _surfaceView.layer.cornerRadius = 26.0;
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        _surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _surfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        _surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
        _surfaceView.layer.shadowOpacity = 0.04;
        _surfaceView.layer.shadowRadius = 14.0;
        _surfaceView.layer.shadowOffset = CGSizeMake(0, 8.0);
        [self.contentView addSubview:_surfaceView];

        _iconShellView = [UIView new];
        _iconShellView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconShellView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        _iconShellView.layer.cornerRadius = 22.0;
        _iconShellView.layer.cornerCurve = kCACornerCurveContinuous;
        [_surfaceView addSubview:_iconShellView];

        _iconView = [UIImageView new];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
        _iconView.image = [UIImage systemImageNamed:@"bell.badge.fill"];
        [_iconShellView addSubview:_iconView];

        _dot = [UIView new];
        _dot.translatesAutoresizingMaskIntoConstraints = NO;
        _dot.backgroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
        _dot.layer.cornerRadius = 4.5;
        _dot.layer.cornerCurve = kCACornerCurveContinuous;
        [_surfaceView addSubview:_dot];

        _title = [UILabel new];
        _title.translatesAutoresizingMaskIntoConstraints = NO;
        _title.font = [Styling fontBold:16];
        _title.textColor = PrimaryTextClr ?: UIColor.labelColor;
        _title.numberOfLines = 2;
        _title.textAlignment = [Language alignmentForCurrentLanguage];

        _body = [UILabel new];
        _body.translatesAutoresizingMaskIntoConstraints = NO;
        _body.font = [Styling fontMedium:13];
        _body.textColor = [SeconderyTextClr colorWithAlphaComponent:0.88];
        _body.numberOfLines = 2;
        _body.textAlignment = [Language alignmentForCurrentLanguage];

        _time = [UILabel new];
        _time.translatesAutoresizingMaskIntoConstraints = NO;
        _time.font = [Styling fontMedium:11];
        _time.textColor = [SeconderyTextClr colorWithAlphaComponent:0.74];
        _time.textAlignment = [Language alignmentForCurrentLanguage];

        _statusPillView = [UIView new];
        _statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
        _statusPillView.layer.cornerRadius = 12.0;
        _statusPillView.layer.cornerCurve = kCACornerCurveContinuous;
        [_surfaceView addSubview:_statusPillView];

        _statusLabel = [UILabel new];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = [Styling fontBold:10];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        [_statusPillView addSubview:_statusLabel];

        _chevronView = [UIImageView new];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
        _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.36];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [_surfaceView addSubview:_chevronView];

        UIStackView *copyStack = [[UIStackView alloc] initWithArrangedSubviews:@[_title, _body, _time]];
        copyStack.translatesAutoresizingMaskIntoConstraints = NO;
        copyStack.axis = UILayoutConstraintAxisVertical;
        copyStack.alignment = UIStackViewAlignmentFill;
        copyStack.spacing = 4.0;
        copyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [_surfaceView addSubview:copyStack];

        [NSLayoutConstraint activateConstraints:@[
            [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
            [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

            [_iconShellView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:16.0],
            [_iconShellView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:18.0],
            [_iconShellView.widthAnchor constraintEqualToConstant:44.0],
            [_iconShellView.heightAnchor constraintEqualToConstant:44.0],

            [_iconView.centerXAnchor constraintEqualToAnchor:_iconShellView.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:_iconShellView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:19.0],
            [_iconView.heightAnchor constraintEqualToConstant:19.0],

            [_dot.widthAnchor constraintEqualToConstant:9.0],
            [_dot.heightAnchor constraintEqualToConstant:9.0],
            [_dot.trailingAnchor constraintEqualToAnchor:_iconShellView.trailingAnchor constant:1.0],
            [_dot.topAnchor constraintEqualToAnchor:_iconShellView.topAnchor constant:-1.0],

            [copyStack.leadingAnchor constraintEqualToAnchor:_iconShellView.trailingAnchor constant:14.0],
            [copyStack.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:16.0],
            [copyStack.trailingAnchor constraintLessThanOrEqualToAnchor:_statusPillView.leadingAnchor constant:-10.0],
            [copyStack.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-16.0],

            [_statusPillView.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
            [_statusPillView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
            [_statusPillView.heightAnchor constraintEqualToConstant:24.0],
            [_statusPillView.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],

            [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusPillView.leadingAnchor constant:10.0],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_statusPillView.trailingAnchor constant:-10.0],
            [_statusLabel.centerYAnchor constraintEqualToAnchor:_statusPillView.centerYAnchor],

            [_chevronView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-16.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:10.0],
            [_chevronView.heightAnchor constraintEqualToConstant:16.0],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _title.text = nil;
    _body.text = nil;
    _time.text = nil;
    _statusLabel.text = nil;
    _dot.hidden = YES;
}

- (void)configure:(NotificationModel *)m {
    BOOL unread = !m.isRead;
    _dot.hidden = !unread;
    _title.text = [m pp_localizedTitleForCurrentLanguage];
    _body.text = [m pp_localizedBodyForCurrentLanguage];
    _title.font = unread ? [Styling fontBold:16] : [Styling fontMedium:16];
    _statusLabel.text = unread ? kLang(@"Unread") : kLang(@"Read");

    NSDate *d = m.createdAt ?: [NSDate date];
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    _time.text = [fmt stringFromDate:d];

    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *secondary = SeconderyTextClr ?: UIColor.secondaryLabelColor;
    _title.textColor = unread ? accent : (PrimaryTextClr ?: UIColor.labelColor);
    _surfaceView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    _surfaceView.layer.borderColor = [secondary colorWithAlphaComponent:unread ? 0.14 : 0.07].CGColor;
    _surfaceView.layer.shadowOpacity = unread ? 0.06 : 0.025;
    _iconShellView.backgroundColor = [accent colorWithAlphaComponent:unread ? 0.12 : 0.07];
    _iconView.tintColor = unread ? accent : [secondary colorWithAlphaComponent:0.74];
    _statusPillView.backgroundColor = unread ? [accent colorWithAlphaComponent:0.11] : [secondary colorWithAlphaComponent:0.08];
    _statusLabel.textColor = unread ? accent : [secondary colorWithAlphaComponent:0.82];
    _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
    _chevronView.tintColor = [secondary colorWithAlphaComponent:0.36];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_setPressed:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_setPressed:selected animated:animated];
}

- (void)pp_setPressed:(BOOL)pressed animated:(BOOL)animated {
    void (^changes)(void) = ^{
        self->_surfaceView.transform = pressed ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self->_surfaceView.alpha = pressed ? 0.86 : 1.0;
    };
    if (animated) {
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:changes completion:nil];
    } else {
        changes();
    }
}
@end
