#import "PPDeliveryCompanyMembersViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPFirebaseCompat.h"
#import "PPUserMessagesViewController.h"
#import "ChatThreadModel.h"
#import <SDWebImage/UIImageView+WebCache.h>

typedef NS_ENUM(NSInteger, PPDeliveryCompanyInviteFieldType) {
    PPDeliveryCompanyInviteFieldTypeNone = 0,
    PPDeliveryCompanyInviteFieldTypeUID,
    PPDeliveryCompanyInviteFieldTypeEmail,
    PPDeliveryCompanyInviteFieldTypeMobile,
};

typedef NS_ENUM(NSInteger, PPDeliveryCompanyInviteVerificationState) {
    PPDeliveryCompanyInviteVerificationStateIdle = 0,
    PPDeliveryCompanyInviteVerificationStateNeedsAttention,
    PPDeliveryCompanyInviteVerificationStateReady,
    PPDeliveryCompanyInviteVerificationStateSubmitting,
    PPDeliveryCompanyInviteVerificationStateSuccess,
    PPDeliveryCompanyInviteVerificationStateFailure,
};

typedef void (^PPDeliveryCompanyInviteSubmitCompletion)(NSError * _Nullable error);
typedef void (^PPDeliveryCompanyInviteSubmitHandler)(NSString *identifier, NSString *role, PPDeliveryCompanyInviteSubmitCompletion completion);

static NSString *PPDCInviteTrimmedString(NSString *value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
}

static NSString *PPDCInviteDigitsOnly(NSString *value) {
    NSString *trimmed = PPDCInviteTrimmedString(value);
    if (trimmed.length == 0) return @"";
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    return [[trimmed componentsSeparatedByCharactersInSet:allowed.invertedSet] componentsJoinedByString:@""];
}

static BOOL PPDCInviteLooksLikeEmail(NSString *value) {
    NSString *trimmed = PPDCInviteTrimmedString(value).lowercaseString;
    if (trimmed.length < 5 || [trimmed containsString:@" "]) return NO;
    NSRange atRange = [trimmed rangeOfString:@"@"];
    NSRange dotRange = [trimmed rangeOfString:@"." options:NSBackwardsSearch];
    return atRange.location != NSNotFound &&
           dotRange.location != NSNotFound &&
           atRange.location > 0 &&
           dotRange.location > atRange.location + 1 &&
           dotRange.location < trimmed.length - 1;
}

static BOOL PPDCInviteLooksLikeMobile(NSString *value) {
    NSString *digits = PPDCInviteDigitsOnly(value);
    NSUInteger digitCount = [[digits stringByReplacingOccurrencesOfString:@"+" withString:@""] length];
    return digitCount >= 8 && digitCount <= 15;
}

static BOOL PPDCInviteLooksLikeUID(NSString *value) {
    NSString *trimmed = PPDCInviteTrimmedString(value);
    if (trimmed.length < 6 || trimmed.length > 128) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."];
    return [trimmed rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

@interface PPDeliveryCompanyMemberCell : UITableViewCell
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIImageView *avatarPlaceholderIconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *contactLabel;
@property (nonatomic, strong) UILabel *availabilityLabel;
@property (nonatomic, strong) UILabel *activeCountLabel;
@property (nonatomic, strong) UIButton *disableButton;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, copy) dispatch_block_t disableHandler;
- (void)configure:(PPDeliveryCompanyMember *)member showDisable:(BOOL)showDisable;
@end

@implementation PPDeliveryCompanyMemberCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

        self.surface = [[UIView alloc] init];
        self.surface.translatesAutoresizingMaskIntoConstraints = NO;
        self.surface.backgroundColor = AppForgroundColr;
        self.surface.layer.cornerRadius = 28.0;
        self.surface.layer.cornerCurve = kCACornerCurveContinuous;
        self.surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
        self.surface.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.06].CGColor;
        self.surface.layer.shadowOpacity = 1.0;
        self.surface.layer.shadowRadius = 22.0;
        self.surface.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        [self.contentView addSubview:self.surface];

        self.glowView = [[UIView alloc] init];
        self.glowView.translatesAutoresizingMaskIntoConstraints = NO;
        self.glowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.05];
        self.glowView.layer.cornerRadius = 60.0;
        self.glowView.layer.cornerCurve = kCACornerCurveContinuous;
        [self.surface addSubview:self.glowView];

        self.avatarView = [[UIView alloc] init];
        self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        self.avatarView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
        self.avatarView.layer.cornerRadius = 24.0;
        self.avatarView.clipsToBounds = YES;
        [self.surface addSubview:self.avatarView];

        self.avatarImageView = [[UIImageView alloc] init];
        self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarImageView.clipsToBounds = YES;
        self.avatarImageView.hidden = YES;
        [self.avatarView addSubview:self.avatarImageView];

        self.avatarPlaceholderIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.fill"]];
        self.avatarPlaceholderIconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.avatarPlaceholderIconView.tintColor = AppPrimaryClr;
        [self.avatarView addSubview:self.avatarPlaceholderIconView];

        self.nameLabel = [self label:PPFontBold(17) color:PrimaryTextClr lines:1];
        self.roleLabel = [self label:PPFontBold(11) color:AppPrimaryClr lines:1];
        self.roleLabel.textAlignment = NSTextAlignmentCenter;
        self.roleLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
        self.roleLabel.layer.cornerRadius = 10.0;
        self.roleLabel.clipsToBounds = YES;
        self.contactLabel = [self label:PPFontRegular(12) color:SeconderyTextClr lines:1];
        self.availabilityLabel = [self label:PPFontMedium(12) color:SeconderyTextClr lines:1];
        self.activeCountLabel = [self label:PPFontMedium(11) color:SeconderyTextClr lines:1];

        self.disableButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.disableButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.disableButton.titleLabel.font = PPFontBold(12);
        self.disableButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.09];
        self.disableButton.layer.cornerRadius = 13.0;
        [self.disableButton setTitle:kLang(@"DeliveryCompany_Members_Disable") forState:UIControlStateNormal];
        [self.disableButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
        [self.disableButton addTarget:self action:@selector(disableTapped) forControlEvents:UIControlEventTouchUpInside];

        self.chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")]];
        self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        self.chevronView.tintColor = [PrimaryTextClr colorWithAlphaComponent:0.42];
        [self.surface addSubview:self.chevronView];

        for (UIView *view in @[self.nameLabel, self.roleLabel, self.contactLabel, self.availabilityLabel, self.activeCountLabel, self.disableButton]) {
            [self.surface addSubview:view];
        }

        [NSLayoutConstraint activateConstraints:@[
            [self.surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
            [self.surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [self.surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [self.surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],
            [self.glowView.widthAnchor constraintEqualToConstant:120.0],
            [self.glowView.heightAnchor constraintEqualToConstant:120.0],
            [self.glowView.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:-24.0],
            [self.glowView.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:22.0],
            [self.avatarView.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:18.0],
            [self.avatarView.leadingAnchor constraintEqualToAnchor:self.surface.leadingAnchor constant:16.0],
            [self.avatarView.widthAnchor constraintEqualToConstant:48.0],
            [self.avatarView.heightAnchor constraintEqualToConstant:48.0],
            [self.avatarImageView.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
            [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
            [self.avatarImageView.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
            [self.avatarImageView.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],
            [self.avatarPlaceholderIconView.centerXAnchor constraintEqualToAnchor:self.avatarView.centerXAnchor],
            [self.avatarPlaceholderIconView.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],
            [self.avatarPlaceholderIconView.widthAnchor constraintEqualToConstant:20.0],
            [self.avatarPlaceholderIconView.heightAnchor constraintEqualToConstant:20.0],

            [self.nameLabel.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:17.0],
            [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:12.0],
            [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.roleLabel.leadingAnchor constant:-8.0],
            [self.roleLabel.centerYAnchor constraintEqualToAnchor:self.nameLabel.centerYAnchor],
            [self.roleLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.roleLabel.heightAnchor constraintEqualToConstant:22.0],
            [self.roleLabel.widthAnchor constraintGreaterThanOrEqualToConstant:68.0],

            [self.contactLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:5.0],
            [self.contactLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
            [self.contactLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.availabilityLabel.topAnchor constraintEqualToAnchor:self.contactLabel.bottomAnchor constant:11.0],
            [self.availabilityLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
            [self.availabilityLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-8.0],
            [self.activeCountLabel.topAnchor constraintEqualToAnchor:self.availabilityLabel.bottomAnchor constant:5.0],
            [self.activeCountLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
            [self.activeCountLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.disableButton.leadingAnchor constant:-8.0],
            [self.activeCountLabel.bottomAnchor constraintEqualToAnchor:self.surface.bottomAnchor constant:-17.0],

            [self.disableButton.trailingAnchor constraintEqualToAnchor:self.chevronView.leadingAnchor constant:-10.0],
            [self.disableButton.centerYAnchor constraintEqualToAnchor:self.activeCountLabel.centerYAnchor],
            [self.disableButton.heightAnchor constraintEqualToConstant:34.0],
            [self.disableButton.widthAnchor constraintGreaterThanOrEqualToConstant:78.0],

            [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surface.centerYAnchor],
            [self.chevronView.widthAnchor constraintEqualToConstant:10.0],
            [self.chevronView.heightAnchor constraintEqualToConstant:16.0],
        ]];
    }
    return self;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)configure:(PPDeliveryCompanyMember *)member showDisable:(BOOL)showDisable {
    self.nameLabel.text = member.displayName.length ? member.displayName : member.uid;
    self.roleLabel.text = PPDeliveryCompanyRoleDisplayName(member.role);
    if (member.phone.length) {
        self.contactLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_Phone_Format"), member.phone];
    } else if (member.email.length) {
        self.contactLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_Email_Format"), member.email];
    } else {
        self.contactLabel.text = kLang(@"DeliveryCompany_Members_PhoneUnavailable");
    }

    NSString *availability = ![member.status isEqualToString:@"active"]
        ? kLang(@"DeliveryCompany_Members_Disabled")
        : (member.available ? kLang(@"DeliveryCompany_Members_Available") : kLang(@"DeliveryCompany_Members_Unavailable"));
    self.availabilityLabel.text = availability;
    self.availabilityLabel.textColor = [member.status isEqualToString:@"active"] && member.available ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
    self.activeCountLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_ActiveCount_Format"), (long)member.activeDeliveryCount];
    self.disableButton.hidden = !showDisable;
    self.chevronView.hidden = showDisable;
    [self pp_applyAvatarURL:member.photoURL];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", self.nameLabel.text, self.roleLabel.text, availability];
}

- (void)pp_applyAvatarURL:(NSString *)photoURL {
    [self.avatarImageView sd_cancelCurrentImageLoad];
    self.avatarImageView.image = nil;
    self.avatarImageView.hidden = YES;
    self.avatarImageView.alpha = 0.0;
    self.avatarPlaceholderIconView.hidden = NO;

    NSString *safeURL = [photoURL isKindOfClass:NSString.class]
        ? [photoURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    NSURL *url = safeURL.length > 0 ? [NSURL URLWithString:safeURL] : nil;
    if (!url) {
        return;
    }

    self.avatarImageView.hidden = NO;
    __weak typeof(self) weakSelf = self;
    [self.avatarImageView sd_setImageWithURL:url
                            placeholderImage:nil
                                     options:SDWebImageRetryFailed | SDWebImageScaleDownLargeImages
                                   completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!image || error) {
            self.avatarImageView.hidden = YES;
            self.avatarPlaceholderIconView.hidden = NO;
            return;
        }
        self.avatarPlaceholderIconView.hidden = YES;
        [UIView animateWithDuration:(cacheType == SDImageCacheTypeNone ? 0.22 : 0.0)
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.avatarImageView.alpha = 1.0;
        } completion:nil];
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.disableHandler = nil;
    self.surface.transform = CGAffineTransformIdentity;
    self.surface.alpha = 1.0;
    [self.avatarImageView sd_cancelCurrentImageLoad];
    self.avatarImageView.image = nil;
    self.avatarImageView.hidden = YES;
    self.avatarPlaceholderIconView.hidden = NO;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:0.14 animations:^{
        self.surface.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self.surface.alpha = highlighted ? 0.9 : 1.0;
    }];
}

- (void)disableTapped {
    [PPFunc pp_playTapEffect];
    if (self.disableHandler) self.disableHandler();
}

@end

@interface PPDeliveryCompanyInviteInputFieldView : UIControl
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *helperLabel;
@property (nonatomic, strong) UIImageView *statusImageView;
@property (nonatomic, assign) BOOL fieldValid;
- (instancetype)initWithTitle:(NSString *)title placeholder:(NSString *)placeholder icon:(NSString *)icon;
- (void)applyValidationStateWithMessage:(NSString *)message valid:(BOOL)valid highlighted:(BOOL)highlighted;
@end

@implementation PPDeliveryCompanyInviteInputFieldView

- (instancetype)initWithTitle:(NSString *)title placeholder:(NSString *)placeholder icon:(NSString *)icon {
    if (self = [super initWithFrame:CGRectZero]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

        self.surface = [[UIView alloc] init];
        self.surface.translatesAutoresizingMaskIntoConstraints = NO;
        self.surface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
        self.surface.layer.cornerRadius = 22.0;
        self.surface.layer.cornerCurve = kCACornerCurveContinuous;
        self.surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        [self addSubview:self.surface];

        UIView *iconSurface = [[UIView alloc] init];
        iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
        iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        iconSurface.layer.cornerRadius = 18.0;
        iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
        [self.surface addSubview:iconSurface];

        self.iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconView.tintColor = AppPrimaryClr;
        [iconSurface addSubview:self.iconView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = PPFontBold(13);
        self.titleLabel.textColor = PrimaryTextClr;
        self.titleLabel.text = title;
        self.titleLabel.adjustsFontForContentSizeCategory = YES;
        self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [self.surface addSubview:self.titleLabel];

        self.statusImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"circle"]];
        self.statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.statusImageView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.42];
        [self.surface addSubview:self.statusImageView];

        self.textField = [[UITextField alloc] init];
        self.textField.translatesAutoresizingMaskIntoConstraints = NO;
        self.textField.borderStyle = UITextBorderStyleNone;
        self.textField.font = PPFontMedium(17);
        self.textField.textColor = PrimaryTextClr;
        self.textField.tintColor = AppPrimaryClr;
        self.textField.placeholder = placeholder;
        self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.textField.adjustsFontForContentSizeCategory = YES;
        self.textField.textAlignment = Language.alignmentForCurrentLanguage;
        [self.surface addSubview:self.textField];

        self.helperLabel = [[UILabel alloc] init];
        self.helperLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.helperLabel.font = PPFontRegular(12);
        self.helperLabel.textColor = SeconderyTextClr;
        self.helperLabel.adjustsFontForContentSizeCategory = YES;
        self.helperLabel.numberOfLines = 0;
        self.helperLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [self.surface addSubview:self.helperLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.surface.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.surface.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.surface.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.surface.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [iconSurface.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:16.0],
            [iconSurface.leadingAnchor constraintEqualToAnchor:self.surface.leadingAnchor constant:16.0],
            [iconSurface.widthAnchor constraintEqualToConstant:36.0],
            [iconSurface.heightAnchor constraintEqualToConstant:36.0],
            [self.iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
            [self.iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
            [self.iconView.widthAnchor constraintEqualToConstant:18.0],
            [self.iconView.heightAnchor constraintEqualToConstant:18.0],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:14.0],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusImageView.leadingAnchor constant:-10.0],

            [self.statusImageView.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
            [self.statusImageView.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.statusImageView.widthAnchor constraintEqualToConstant:18.0],
            [self.statusImageView.heightAnchor constraintEqualToConstant:18.0],

            [self.textField.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10.0],
            [self.textField.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.textField.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],

            [self.helperLabel.topAnchor constraintEqualToAnchor:self.textField.bottomAnchor constant:8.0],
            [self.helperLabel.leadingAnchor constraintEqualToAnchor:self.textField.leadingAnchor],
            [self.helperLabel.trailingAnchor constraintEqualToAnchor:self.textField.trailingAnchor],
            [self.helperLabel.bottomAnchor constraintEqualToAnchor:self.surface.bottomAnchor constant:-14.0],
        ]];
    }
    return self;
}

- (void)applyValidationStateWithMessage:(NSString *)message valid:(BOOL)valid highlighted:(BOOL)highlighted {
    self.fieldValid = valid;
    self.helperLabel.text = message;
    UIColor *accent = valid ? UIColor.systemGreenColor : (highlighted ? UIColor.systemOrangeColor : SeconderyTextClr);
    self.helperLabel.textColor = accent;
    CGFloat borderAlpha = (valid || highlighted) ? 0.28 : 0.08;
    self.surface.layer.borderColor = [accent colorWithAlphaComponent:borderAlpha].CGColor;
    self.surface.backgroundColor = valid
        ? [UIColor.systemGreenColor colorWithAlphaComponent:0.055]
        : (highlighted ? [UIColor.systemOrangeColor colorWithAlphaComponent:0.05] : [AppForgroundColr colorWithAlphaComponent:0.96]);
    NSString *imageName = valid ? @"checkmark.circle.fill" : (highlighted ? @"exclamationmark.circle.fill" : @"circle");
    self.statusImageView.image = [UIImage systemImageNamed:imageName];
    self.statusImageView.tintColor = valid ? UIColor.systemGreenColor : (highlighted ? UIColor.systemOrangeColor : [SeconderyTextClr colorWithAlphaComponent:0.42]);
}

@end

@interface PPDeliveryCompanyInviteRoleButton : UIControl
@property (nonatomic, copy) NSString *role;
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *selectionView;
- (instancetype)initWithRole:(NSString *)role icon:(NSString *)icon subtitle:(NSString *)subtitle;
- (void)applySelected:(BOOL)selected enabled:(BOOL)enabled;
@end

@implementation PPDeliveryCompanyInviteRoleButton

- (instancetype)initWithRole:(NSString *)role icon:(NSString *)icon subtitle:(NSString *)subtitle {
    if (self = [super initWithFrame:CGRectZero]) {
        self.role = role;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        self.exclusiveTouch = YES;

        self.surface = [[UIView alloc] init];
        self.surface.translatesAutoresizingMaskIntoConstraints = NO;
        self.surface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98];
        self.surface.layer.cornerRadius = 22.0;
        self.surface.layer.cornerCurve = kCACornerCurveContinuous;
        self.surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        self.surface.userInteractionEnabled = NO;
        [self addSubview:self.surface];

        UIView *iconSurface = [[UIView alloc] init];
        iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
        iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        iconSurface.layer.cornerRadius = 18.0;
        iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
        iconSurface.userInteractionEnabled = NO;
        [self.surface addSubview:iconSurface];

        self.iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconView.tintColor = AppPrimaryClr;
        [iconSurface addSubview:self.iconView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = PPFontBold(15);
        self.titleLabel.textColor = PrimaryTextClr;
        self.titleLabel.text = PPDeliveryCompanyRoleDisplayName(role);
        self.titleLabel.adjustsFontForContentSizeCategory = YES;
        self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [self.surface addSubview:self.titleLabel];

        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.subtitleLabel.font = PPFontRegular(12);
        self.subtitleLabel.textColor = SeconderyTextClr;
        self.subtitleLabel.numberOfLines = 2;
        self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
        self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.subtitleLabel.text = subtitle;
        [self.surface addSubview:self.subtitleLabel];

        self.selectionView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
        self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
        self.selectionView.tintColor = AppPrimaryClr;
        self.selectionView.alpha = 0.0;
        [self.surface addSubview:self.selectionView];

        [NSLayoutConstraint activateConstraints:@[
            [self.surface.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.surface.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.surface.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.surface.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [self.heightAnchor constraintGreaterThanOrEqualToConstant:92.0],

            [iconSurface.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:16.0],
            [iconSurface.leadingAnchor constraintEqualToAnchor:self.surface.leadingAnchor constant:16.0],
            [iconSurface.widthAnchor constraintEqualToConstant:36.0],
            [iconSurface.heightAnchor constraintEqualToConstant:36.0],
            [self.iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
            [self.iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
            [self.iconView.widthAnchor constraintEqualToConstant:18.0],
            [self.iconView.heightAnchor constraintEqualToConstant:18.0],

            [self.selectionView.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:16.0],
            [self.selectionView.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.selectionView.widthAnchor constraintEqualToConstant:20.0],
            [self.selectionView.heightAnchor constraintEqualToConstant:20.0],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.surface.topAnchor constant:16.0],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionView.leadingAnchor constant:-10.0],

            [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6.0],
            [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.surface.trailingAnchor constant:-16.0],
            [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.surface.bottomAnchor constant:-16.0],
        ]];

        [self applySelected:NO enabled:YES];
    }
    return self;
}

- (void)applySelected:(BOOL)selected enabled:(BOOL)enabled {
    self.enabled = enabled;
    self.userInteractionEnabled = enabled;
    self.alpha = enabled ? 1.0 : 0.45;
    self.surface.backgroundColor = selected
        ? [AppPrimaryClr colorWithAlphaComponent:0.11]
        : [AppForgroundColr colorWithAlphaComponent:0.98];
    UIColor *borderBaseColor = selected ? AppPrimaryClr : SeconderyTextClr;
    CGFloat borderAlpha = selected ? 0.28 : 0.08;
    self.surface.layer.borderColor = [borderBaseColor colorWithAlphaComponent:borderAlpha].CGColor;
    self.selectionView.alpha = selected ? 1.0 : 0.0;
}

@end

@interface PPDeliveryCompanyInviteMemberSheetViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, copy) PPDeliveryCompanyInviteSubmitHandler submitHandler;
@property (nonatomic, copy) dispatch_block_t successHandler;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) PPHero *heroView;
@property (nonatomic, strong) UILabel *statusTitleLabel;
@property (nonatomic, strong) UILabel *statusSubtitleLabel;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) PPDeliveryCompanyInviteInputFieldView *uidFieldView;
@property (nonatomic, strong) PPDeliveryCompanyInviteInputFieldView *emailFieldView;
@property (nonatomic, strong) PPDeliveryCompanyInviteInputFieldView *mobileFieldView;
@property (nonatomic, strong) UILabel *roleLockLabel;
@property (nonatomic, strong) UIStackView *roleStackView;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyInviteRoleButton *> *roleButtons;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UILabel *footnoteLabel;
@property (nonatomic, copy) NSString *selectedRole;
@property (nonatomic, copy) NSString *resolvedIdentifier;
@property (nonatomic, assign) PPDeliveryCompanyInviteFieldType resolvedFieldType;
@property (nonatomic, assign) PPDeliveryCompanyInviteVerificationState verificationState;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@end

@implementation PPDeliveryCompanyInviteMemberSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildUI];
    [self prepareEntranceState];
    [self updateValidationState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat bottomInset = MAX(self.view.safeAreaInsets.bottom, 16.0) + 40.0;
    UIEdgeInsets insets = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.scrollView.contentInset, insets)) {
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    }
}

- (void)buildUI {
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
    self.closeButton.layer.cornerRadius = 18.0;
    self.closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    self.closeButton.tintColor = PrimaryTextClr;
    self.closeButton.accessibilityLabel = kLang(@"Close");
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    self.heroView = [[PPHero alloc] init];
    self.heroView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroView.accentColor = AppPrimaryClr;
    [self.view addSubview:self.heroView];

    UIView *heroGlow = [[UIView alloc] init];
    heroGlow.translatesAutoresizingMaskIntoConstraints = NO;
    heroGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    heroGlow.layer.cornerRadius = 112.0;
    heroGlow.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroView addSubview:heroGlow];

    UILabel *eyebrow = [self label:PPFontBold(11) color:AppPrimaryClr lines:1];
    eyebrow.text = kLang(@"DeliveryCompany_Members_InviteSheet_Eyebrow");
    [self.heroView addSubview:eyebrow];

    UILabel *titleLabel = [self label:PPFontBold(30) color:PrimaryTextClr lines:2];
    titleLabel.text = kLang(@"DeliveryCompany_Members_InviteSheet_Title");
    [self.heroView addSubview:titleLabel];

    UILabel *subtitleLabel = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    subtitleLabel.text = kLang(@"DeliveryCompany_Members_InviteSheet_Subtitle");
    [self.heroView addSubview:subtitleLabel];

    UIView *statusCard = [[UIView alloc] init];
    statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    statusCard.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.74];
    statusCard.layer.cornerRadius = 26.0;
    statusCard.layer.cornerCurve = kCACornerCurveContinuous;
    statusCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    statusCard.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    [self.heroView addSubview:statusCard];

    UIView *statusIconSurface = [[UIView alloc] init];
    statusIconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    statusIconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    statusIconSurface.layer.cornerRadius = 20.0;
    statusIconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [statusCard addSubview:statusIconSurface];

    self.statusIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shield.lefthalf.filled"]];
    self.statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconView.tintColor = AppPrimaryClr;
    [statusIconSurface addSubview:self.statusIconView];

    self.statusTitleLabel = [self label:PPFontBold(15) color:PrimaryTextClr lines:1];
    [statusCard addSubview:self.statusTitleLabel];

    self.statusSubtitleLabel = [self label:PPFontRegular(12) color:SeconderyTextClr lines:0];
    [statusCard addSubview:self.statusSubtitleLabel];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.delaysContentTouches = NO;
    self.scrollView.canCancelContentTouches = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    UIView *fieldsCard = [self sectionCard];
    [self.contentView addSubview:fieldsCard];
    UILabel *fieldsTitle = [self label:PPFontBold(16) color:PrimaryTextClr lines:1];
    fieldsTitle.text = kLang(@"DeliveryCompany_Members_InviteSheet_IdentityTitle");
    [fieldsCard addSubview:fieldsTitle];
    UILabel *fieldsSubtitle = [self label:PPFontRegular(12) color:SeconderyTextClr lines:0];
    fieldsSubtitle.text = kLang(@"DeliveryCompany_Members_InviteSheet_IdentitySubtitle");
    [fieldsCard addSubview:fieldsSubtitle];

    UIStackView *fieldsStack = [[UIStackView alloc] init];
    fieldsStack.translatesAutoresizingMaskIntoConstraints = NO;
    fieldsStack.axis = UILayoutConstraintAxisVertical;
    fieldsStack.spacing = 12.0;
    [fieldsCard addSubview:fieldsStack];

    self.uidFieldView = [[PPDeliveryCompanyInviteInputFieldView alloc] initWithTitle:kLang(@"DeliveryCompany_Members_InviteSheet_UIDTitle")
                                                                          placeholder:kLang(@"DeliveryCompany_Members_InviteSheet_UIDPlaceholder")
                                                                                 icon:@"number"];
    self.uidFieldView.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.uidFieldView.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.uidFieldView.textField.keyboardType = UIKeyboardTypeASCIICapable;
    self.uidFieldView.textField.returnKeyType = UIReturnKeyNext;
    self.uidFieldView.textField.delegate = self;
    [self.uidFieldView.textField addTarget:self action:@selector(textFieldValueChanged:) forControlEvents:UIControlEventEditingChanged];
    [fieldsStack addArrangedSubview:self.uidFieldView];

    self.emailFieldView = [[PPDeliveryCompanyInviteInputFieldView alloc] initWithTitle:kLang(@"DeliveryCompany_Members_InviteSheet_EmailTitle")
                                                                            placeholder:kLang(@"DeliveryCompany_Members_InviteSheet_EmailPlaceholder")
                                                                                   icon:@"envelope.fill"];
    self.emailFieldView.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailFieldView.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailFieldView.textField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailFieldView.textField.returnKeyType = UIReturnKeyNext;
    self.emailFieldView.textField.delegate = self;
    [self.emailFieldView.textField addTarget:self action:@selector(textFieldValueChanged:) forControlEvents:UIControlEventEditingChanged];
    [fieldsStack addArrangedSubview:self.emailFieldView];

    self.mobileFieldView = [[PPDeliveryCompanyInviteInputFieldView alloc] initWithTitle:kLang(@"DeliveryCompany_Members_InviteSheet_MobileTitle")
                                                                             placeholder:kLang(@"DeliveryCompany_Members_InviteSheet_MobilePlaceholder")
                                                                                    icon:@"phone.fill"];
    self.mobileFieldView.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.mobileFieldView.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.mobileFieldView.textField.keyboardType = UIKeyboardTypePhonePad;
    self.mobileFieldView.textField.returnKeyType = UIReturnKeyDone;
    self.mobileFieldView.textField.delegate = self;
    [self.mobileFieldView.textField addTarget:self action:@selector(textFieldValueChanged:) forControlEvents:UIControlEventEditingChanged];
    [fieldsStack addArrangedSubview:self.mobileFieldView];

    UIView *rolesCard = [self sectionCard];
    [self.contentView addSubview:rolesCard];
    UILabel *rolesTitle = [self label:PPFontBold(16) color:PrimaryTextClr lines:1];
    rolesTitle.text = kLang(@"DeliveryCompany_Members_InviteSheet_RoleTitle");
    [rolesCard addSubview:rolesTitle];
    self.roleLockLabel = [self label:PPFontRegular(12) color:SeconderyTextClr lines:0];
    [rolesCard addSubview:self.roleLockLabel];

    self.roleStackView = [[UIStackView alloc] init];
    self.roleStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.roleStackView.axis = UILayoutConstraintAxisVertical;
    self.roleStackView.spacing = 10.0;
    [rolesCard addSubview:self.roleStackView];

    NSArray<NSDictionary *> *roleConfigs = @[
        @{@"role": PPDeliveryCompanyRoleDriver, @"icon": @"car.fill", @"subtitle": kLang(@"DeliveryCompany_Members_InviteSheet_RoleSubtitle_Driver")},
        @{@"role": PPDeliveryCompanyRoleDispatcher, @"icon": @"point.3.filled.connected.trianglepath.dotted", @"subtitle": kLang(@"DeliveryCompany_Members_InviteSheet_RoleSubtitle_Dispatcher")},
        @{@"role": PPDeliveryCompanyRoleViewer, @"icon": @"eye.fill", @"subtitle": kLang(@"DeliveryCompany_Members_InviteSheet_RoleSubtitle_Viewer")},
        @{@"role": PPDeliveryCompanyRoleOwner, @"icon": @"crown.fill", @"subtitle": kLang(@"DeliveryCompany_Members_InviteSheet_RoleSubtitle_Owner")}
    ];
    NSMutableArray *roleButtons = [NSMutableArray array];
    for (NSDictionary *config in roleConfigs) {
        PPDeliveryCompanyInviteRoleButton *button = [[PPDeliveryCompanyInviteRoleButton alloc] initWithRole:config[@"role"]
                                                                                                        icon:config[@"icon"]
                                                                                                    subtitle:config[@"subtitle"]];
        [button addTarget:self action:@selector(roleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.roleStackView addArrangedSubview:button];
        [roleButtons addObject:button];
    }
    self.roleButtons = roleButtons.copy;

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.submitButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.98];
    self.submitButton.layer.cornerRadius = 24.0;
    self.submitButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.submitButton.titleLabel.font = PPFontBold(16);
    [self.submitButton setTitle:kLang(@"DeliveryCompany_Members_InviteSheet_Submit") forState:UIControlStateNormal];
    [self.submitButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.submitButton setImage:[UIImage systemImageNamed:@"person.badge.plus"] forState:UIControlStateNormal];
    self.submitButton.tintColor = UIColor.whiteColor;
    self.submitButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 8.0);
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.submitButton];

    self.footnoteLabel = [self label:PPFontRegular(12) color:SeconderyTextClr lines:0];
    self.footnoteLabel.textAlignment = NSTextAlignmentCenter;
    self.footnoteLabel.text = kLang(@"DeliveryCompany_Members_InviteSheet_Footnote");
    [self.contentView addSubview:self.footnoteLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [self.closeButton.widthAnchor constraintEqualToConstant:36.0],
        [self.closeButton.heightAnchor constraintEqualToConstant:36.0],

        [self.heroView.topAnchor constraintEqualToAnchor:self.closeButton.bottomAnchor constant:10.0],
        [self.heroView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.heroView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:14.0],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [heroGlow.widthAnchor constraintEqualToConstant:224.0],
        [heroGlow.heightAnchor constraintEqualToConstant:224.0],
        [heroGlow.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:-62.0],
        [heroGlow.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:60.0],

        [eyebrow.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:22.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:20.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-20.0],
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:6.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [statusCard.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [statusCard.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:18.0],
        [statusCard.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-18.0],
        [statusCard.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:-18.0],

        [statusIconSurface.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:14.0],
        [statusIconSurface.centerYAnchor constraintEqualToAnchor:statusCard.centerYAnchor],
        [statusIconSurface.widthAnchor constraintEqualToConstant:40.0],
        [statusIconSurface.heightAnchor constraintEqualToConstant:40.0],
        [self.statusIconView.centerXAnchor constraintEqualToAnchor:statusIconSurface.centerXAnchor],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:statusIconSurface.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:18.0],
        [self.statusTitleLabel.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:14.0],
        [self.statusTitleLabel.leadingAnchor constraintEqualToAnchor:statusIconSurface.trailingAnchor constant:12.0],
        [self.statusTitleLabel.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-14.0],
        [self.statusSubtitleLabel.topAnchor constraintEqualToAnchor:self.statusTitleLabel.bottomAnchor constant:4.0],
        [self.statusSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.statusTitleLabel.leadingAnchor],
        [self.statusSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.statusTitleLabel.trailingAnchor],
        [self.statusSubtitleLabel.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-14.0],

        [fieldsCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [fieldsCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [fieldsCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [fieldsTitle.topAnchor constraintEqualToAnchor:fieldsCard.topAnchor constant:18.0],
        [fieldsTitle.leadingAnchor constraintEqualToAnchor:fieldsCard.leadingAnchor constant:18.0],
        [fieldsTitle.trailingAnchor constraintEqualToAnchor:fieldsCard.trailingAnchor constant:-18.0],
        [fieldsSubtitle.topAnchor constraintEqualToAnchor:fieldsTitle.bottomAnchor constant:6.0],
        [fieldsSubtitle.leadingAnchor constraintEqualToAnchor:fieldsTitle.leadingAnchor],
        [fieldsSubtitle.trailingAnchor constraintEqualToAnchor:fieldsTitle.trailingAnchor],
        [fieldsStack.topAnchor constraintEqualToAnchor:fieldsSubtitle.bottomAnchor constant:14.0],
        [fieldsStack.leadingAnchor constraintEqualToAnchor:fieldsTitle.leadingAnchor],
        [fieldsStack.trailingAnchor constraintEqualToAnchor:fieldsTitle.trailingAnchor],
        [fieldsStack.bottomAnchor constraintEqualToAnchor:fieldsCard.bottomAnchor constant:-18.0],

        [rolesCard.topAnchor constraintEqualToAnchor:fieldsCard.bottomAnchor constant:14.0],
        [rolesCard.leadingAnchor constraintEqualToAnchor:fieldsCard.leadingAnchor],
        [rolesCard.trailingAnchor constraintEqualToAnchor:fieldsCard.trailingAnchor],
        [rolesTitle.topAnchor constraintEqualToAnchor:rolesCard.topAnchor constant:18.0],
        [rolesTitle.leadingAnchor constraintEqualToAnchor:rolesCard.leadingAnchor constant:18.0],
        [rolesTitle.trailingAnchor constraintEqualToAnchor:rolesCard.trailingAnchor constant:-18.0],
        [self.roleLockLabel.topAnchor constraintEqualToAnchor:rolesTitle.bottomAnchor constant:6.0],
        [self.roleLockLabel.leadingAnchor constraintEqualToAnchor:rolesTitle.leadingAnchor],
        [self.roleLockLabel.trailingAnchor constraintEqualToAnchor:rolesTitle.trailingAnchor],
        [self.roleStackView.topAnchor constraintEqualToAnchor:self.roleLockLabel.bottomAnchor constant:14.0],
        [self.roleStackView.leadingAnchor constraintEqualToAnchor:rolesTitle.leadingAnchor],
        [self.roleStackView.trailingAnchor constraintEqualToAnchor:rolesTitle.trailingAnchor],
        [self.roleStackView.bottomAnchor constraintEqualToAnchor:rolesCard.bottomAnchor constant:-18.0],

        [self.submitButton.topAnchor constraintEqualToAnchor:rolesCard.bottomAnchor constant:16.0],
        [self.submitButton.leadingAnchor constraintEqualToAnchor:rolesCard.leadingAnchor],
        [self.submitButton.trailingAnchor constraintEqualToAnchor:rolesCard.trailingAnchor],
        [self.submitButton.heightAnchor constraintEqualToConstant:56.0],

        [self.footnoteLabel.topAnchor constraintEqualToAnchor:self.submitButton.bottomAnchor constant:10.0],
        [self.footnoteLabel.leadingAnchor constraintEqualToAnchor:self.submitButton.leadingAnchor constant:4.0],
        [self.footnoteLabel.trailingAnchor constraintEqualToAnchor:self.submitButton.trailingAnchor constant:-4.0],
        [self.footnoteLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-26.0],
    ]];
}

- (UIView *)sectionCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 30.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    card.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.04].CGColor;
    card.layer.shadowOpacity = 1.0;
    card.layer.shadowRadius = 18.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    return card;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    return label;
}

- (void)prepareEntranceState {
    if (self.didRunEntrance) return;
    self.didPrepareEntrance = YES;
    self.heroView.alpha = 0.0;
    self.heroView.transform = CGAffineTransformMakeScale(1.03, 1.03);
    self.uidFieldView.alpha = 0.0;
    self.uidFieldView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.emailFieldView.alpha = 0.0;
    self.emailFieldView.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    self.mobileFieldView.alpha = 0.0;
    self.mobileFieldView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
    self.roleStackView.alpha = 0.0;
    self.roleStackView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.submitButton.alpha = 0.0;
    self.submitButton.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)runEntranceIfNeeded {
    if (self.didRunEntrance) return;
    self.didRunEntrance = YES;
    [self.view layoutIfNeeded];
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    if (reduceMotion) {
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
        self.uidFieldView.alpha = 1.0;
        self.uidFieldView.transform = CGAffineTransformIdentity;
        self.emailFieldView.alpha = 1.0;
        self.emailFieldView.transform = CGAffineTransformIdentity;
        self.mobileFieldView.alpha = 1.0;
        self.mobileFieldView.transform = CGAffineTransformIdentity;
        self.roleStackView.alpha = 1.0;
        self.roleStackView.transform = CGAffineTransformIdentity;
        self.submitButton.alpha = 1.0;
        self.submitButton.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.32 delay:0.08 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.uidFieldView.alpha = 1.0;
        self.uidFieldView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.32 delay:0.12 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.emailFieldView.alpha = 1.0;
        self.emailFieldView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.32 delay:0.16 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.mobileFieldView.alpha = 1.0;
        self.mobileFieldView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.34 delay:0.20 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.roleStackView.alpha = 1.0;
        self.roleStackView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.44
                          delay:0.26
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.submitButton.alpha = 1.0;
        self.submitButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)textFieldValueChanged:(UITextField *)textField {
    [self updateValidationState];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.uidFieldView.textField) {
        [self.emailFieldView.textField becomeFirstResponder];
    } else if (textField == self.emailFieldView.textField) {
        [self.mobileFieldView.textField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)roleButtonTapped:(PPDeliveryCompanyInviteRoleButton *)sender {
    if (self.verificationState != PPDeliveryCompanyInviteVerificationStateReady &&
        self.verificationState != PPDeliveryCompanyInviteVerificationStateSuccess &&
        self.verificationState != PPDeliveryCompanyInviteVerificationStateFailure) {
        return;
    }
    [PPFunc pp_playTapEffect];
    self.selectedRole = sender.role;
    [self updateRoleSelection];
    [self updateSubmitButtonState];
}

- (void)updateValidationState {
    NSString *uid = PPDCInviteTrimmedString(self.uidFieldView.textField.text);
    NSString *email = PPDCInviteTrimmedString(self.emailFieldView.textField.text).lowercaseString;
    NSString *mobile = PPDCInviteTrimmedString(self.mobileFieldView.textField.text);

    BOOL hasUID = uid.length > 0;
    BOOL hasEmail = email.length > 0;
    BOOL hasMobile = mobile.length > 0;

    BOOL uidValid = hasUID && PPDCInviteLooksLikeUID(uid);
    BOOL emailValid = hasEmail && PPDCInviteLooksLikeEmail(email);
    BOOL mobileValid = hasMobile && PPDCInviteLooksLikeMobile(mobile);

    [self.uidFieldView applyValidationStateWithMessage:(uidValid ? kLang(@"DeliveryCompany_Members_InviteSheet_UIDValid") : (hasUID ? kLang(@"DeliveryCompany_Members_InviteSheet_UIDInvalid") : kLang(@"DeliveryCompany_Members_InviteSheet_UIDHint")))
                                                 valid:uidValid
                                           highlighted:(hasUID && !uidValid)];
    [self.emailFieldView applyValidationStateWithMessage:(emailValid ? kLang(@"DeliveryCompany_Members_InviteSheet_EmailValid") : (hasEmail ? kLang(@"DeliveryCompany_Members_InviteSheet_EmailInvalid") : kLang(@"DeliveryCompany_Members_InviteSheet_EmailHint")))
                                                   valid:emailValid
                                             highlighted:(hasEmail && !emailValid)];
    [self.mobileFieldView applyValidationStateWithMessage:(mobileValid ? kLang(@"DeliveryCompany_Members_InviteSheet_MobileValid") : (hasMobile ? kLang(@"DeliveryCompany_Members_InviteSheet_MobileInvalid") : kLang(@"DeliveryCompany_Members_InviteSheet_MobileHint")))
                                                    valid:mobileValid
                                              highlighted:(hasMobile && !mobileValid)];

    self.resolvedIdentifier = @"";
    self.resolvedFieldType = PPDeliveryCompanyInviteFieldTypeNone;
    if (uidValid) {
        self.resolvedIdentifier = uid;
        self.resolvedFieldType = PPDeliveryCompanyInviteFieldTypeUID;
    } else if (emailValid) {
        self.resolvedIdentifier = email;
        self.resolvedFieldType = PPDeliveryCompanyInviteFieldTypeEmail;
    } else if (mobileValid) {
        self.resolvedIdentifier = mobile;
        self.resolvedFieldType = PPDeliveryCompanyInviteFieldTypeMobile;
    }

    BOOL hasAnyInput = hasUID || hasEmail || hasMobile;
    BOOL hasAnyInvalidInput = (hasUID && !uidValid) || (hasEmail && !emailValid) || (hasMobile && !mobileValid);
    BOOL ready = self.resolvedIdentifier.length > 0 && !hasAnyInvalidInput;

    if (!hasAnyInput) {
        [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateIdle error:nil];
    } else if (ready) {
        [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateReady error:nil];
    } else {
        [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateNeedsAttention error:nil];
    }

    if (!ready) {
        self.selectedRole = nil;
    }
    [self updateRoleSelection];
    [self updateSubmitButtonState];
}

- (void)updateVerificationStatus:(PPDeliveryCompanyInviteVerificationState)state error:(NSError *)error {
    self.verificationState = state;
    UIColor *accent = AppPrimaryClr;
    NSString *iconName = @"shield.lefthalf.filled";
    NSString *title = @"";
    NSString *subtitle = @"";

    switch (state) {
        case PPDeliveryCompanyInviteVerificationStateIdle:
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusIdleTitle");
            subtitle = kLang(@"DeliveryCompany_Members_InviteSheet_StatusIdleSubtitle");
            break;
        case PPDeliveryCompanyInviteVerificationStateNeedsAttention:
            accent = UIColor.systemOrangeColor;
            iconName = @"exclamationmark.shield.fill";
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusNeedsAttentionTitle");
            subtitle = kLang(@"DeliveryCompany_Members_InviteSheet_StatusNeedsAttentionSubtitle");
            break;
        case PPDeliveryCompanyInviteVerificationStateReady: {
            accent = UIColor.systemGreenColor;
            iconName = @"checkmark.shield.fill";
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusReadyTitle");
            NSString *methodKey = @"DeliveryCompany_Members_InviteSheet_MethodUID";
            if (self.resolvedFieldType == PPDeliveryCompanyInviteFieldTypeEmail) {
                methodKey = @"DeliveryCompany_Members_InviteSheet_MethodEmail";
            } else if (self.resolvedFieldType == PPDeliveryCompanyInviteFieldTypeMobile) {
                methodKey = @"DeliveryCompany_Members_InviteSheet_MethodMobile";
            }
            subtitle = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_InviteSheet_StatusReadySubtitle_Format"),
                        self.resolvedIdentifier ?: @"",
                        kLang(methodKey)];
            break;
        }
        case PPDeliveryCompanyInviteVerificationStateSubmitting:
            accent = AppPrimaryClr;
            iconName = @"hourglass.circle.fill";
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusSubmittingTitle");
            subtitle = kLang(@"DeliveryCompany_Members_InviteSheet_StatusSubmittingSubtitle");
            break;
        case PPDeliveryCompanyInviteVerificationStateSuccess:
            accent = UIColor.systemGreenColor;
            iconName = @"checkmark.seal.fill";
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusSuccessTitle");
            subtitle = kLang(@"DeliveryCompany_Members_InviteSheet_StatusSuccessSubtitle");
            break;
        case PPDeliveryCompanyInviteVerificationStateFailure:
            accent = UIColor.systemRedColor;
            iconName = @"xmark.shield.fill";
            title = kLang(@"DeliveryCompany_Members_InviteSheet_StatusFailureTitle");
            subtitle = error.localizedDescription.length ? error.localizedDescription : kLang(@"DeliveryCompany_Members_InviteSheet_StatusFailureSubtitle");
            break;
    }

    self.statusTitleLabel.text = title;
    self.statusSubtitleLabel.text = subtitle;
    self.statusTitleLabel.textColor = accent;
    self.statusSubtitleLabel.textColor = (state == PPDeliveryCompanyInviteVerificationStateFailure) ? [UIColor.systemRedColor colorWithAlphaComponent:0.9] : SeconderyTextClr;
    self.statusIconView.image = [UIImage systemImageNamed:iconName];
    self.statusIconView.tintColor = accent;
}

- (void)updateRoleSelection {
    BOOL rolesEnabled = self.verificationState == PPDeliveryCompanyInviteVerificationStateReady ||
                        self.verificationState == PPDeliveryCompanyInviteVerificationStateSuccess ||
                        self.verificationState == PPDeliveryCompanyInviteVerificationStateFailure;
    self.roleLockLabel.text = rolesEnabled
        ? kLang(@"DeliveryCompany_Members_InviteSheet_RoleUnlocked")
        : kLang(@"DeliveryCompany_Members_InviteSheet_RoleLocked");
    self.roleLockLabel.textColor = rolesEnabled ? SeconderyTextClr : UIColor.systemOrangeColor;

    for (PPDeliveryCompanyInviteRoleButton *button in self.roleButtons) {
        [button applySelected:[button.role isEqualToString:self.selectedRole] enabled:rolesEnabled];
    }
}

- (void)updateSubmitButtonState {
    BOOL ready = self.resolvedIdentifier.length > 0 &&
                 self.selectedRole.length > 0 &&
                 self.verificationState != PPDeliveryCompanyInviteVerificationStateSubmitting;
    self.submitButton.enabled = ready;
    self.submitButton.alpha = ready ? 1.0 : 0.48;
    NSString *title = (self.verificationState == PPDeliveryCompanyInviteVerificationStateSubmitting)
        ? kLang(@"DeliveryCompany_Members_InviteSheet_Submitting")
        : kLang(@"DeliveryCompany_Members_InviteSheet_Submit");
    [self.submitButton setTitle:title forState:UIControlStateNormal];
}

- (void)submitTapped {
    if (self.resolvedIdentifier.length == 0 || self.selectedRole.length == 0 || !self.submitHandler) return;
    [self.view endEditing:YES];
    [PPFunc pp_playTapEffect];
    [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateSubmitting error:nil];
    [self updateSubmitButtonState];

    __weak typeof(self) weakSelf = self;
    self.submitHandler(self.resolvedIdentifier, self.selectedRole, ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error) {
                [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateFailure error:error];
                [self updateSubmitButtonState];
                return;
            }

            [self updateVerificationStatus:PPDeliveryCompanyInviteVerificationStateSuccess error:nil];
            self.submitButton.enabled = NO;
            self.submitButton.alpha = 1.0;
            [self.submitButton setTitle:kLang(@"DeliveryCompany_Members_InviteSheet_SuccessButton") forState:UIControlStateNormal];
            [PPFunc pp_playSuccessEffect];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.successHandler) self.successHandler();
                [self dismissViewControllerAnimated:YES completion:nil];
            });
        });
    });
}

@end

@interface PPDeliveryCompanyMemberSheetViewController : UIViewController
@property (nonatomic, strong) PPDeliveryCompanyMember *member;
@property (nonatomic, copy) dispatch_block_t contactHandler;
@property (nonatomic, copy) dispatch_block_t chatHandler;
- (instancetype)initWithMember:(PPDeliveryCompanyMember *)member;
@end

@implementation PPDeliveryCompanyMemberSheetViewController

- (instancetype)initWithMember:(PPDeliveryCompanyMember *)member {
    if (self = [super init]) {
        _member = member;
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildUI];
}

- (void)buildUI {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    UIView *hero = [[UIView alloc] init];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    hero.backgroundColor = AppForgroundColr;
    hero.layer.cornerRadius = 34.0;
    hero.layer.cornerCurve = kCACornerCurveContinuous;
    hero.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    hero.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    hero.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.07].CGColor;
    hero.layer.shadowOpacity = 1.0;
    hero.layer.shadowRadius = 28.0;
    hero.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [contentView addSubview:hero];

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    topGlow.layer.cornerRadius = 92.0;
    [hero addSubview:topGlow];

    UIView *avatar = [[UIView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
    avatar.layer.cornerRadius = 28.0;
    avatar.clipsToBounds = YES;
    [hero addSubview:avatar];

    UIImageView *avatarImageView = [[UIImageView alloc] init];
    avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.hidden = YES;
    [avatar addSubview:avatarImageView];

    UIImageView *avatarIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    avatarIcon.translatesAutoresizingMaskIntoConstraints = NO;
    avatarIcon.tintColor = AppPrimaryClr;
    [avatar addSubview:avatarIcon];
    [self pp_loadAvatarIntoImageView:avatarImageView fallbackIconView:avatarIcon];

    UILabel *eyebrow = [self label:PPFontBold(11) color:AppPrimaryClr lines:1];
    eyebrow.text = [self.member.role isEqualToString:PPDeliveryCompanyRoleDriver]
        ? kLang(@"DeliveryCompany_Members_Sheet_DriverEyebrow")
        : kLang(@"DeliveryCompany_Members_Sheet_MemberEyebrow");
    [hero addSubview:eyebrow];

    UILabel *titleLabel = [self label:PPFontBold(30) color:PrimaryTextClr lines:2];
    titleLabel.text = self.member.displayName.length ? self.member.displayName : self.member.uid;
    [hero addSubview:titleLabel];

    UILabel *subtitleLabel = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    subtitleLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_Sheet_Subtitle_Format"), PPDeliveryCompanyRoleDisplayName(self.member.role)];
    [hero addSubview:subtitleLabel];

    UIView *statusPill = [self pillWithText:[self availabilityText] color:[self availabilityColor]];
    [hero addSubview:statusPill];

    UIStackView *metricsRow = [[UIStackView alloc] init];
    metricsRow.translatesAutoresizingMaskIntoConstraints = NO;
    metricsRow.axis = UILayoutConstraintAxisHorizontal;
    metricsRow.spacing = 10.0;
    metricsRow.distribution = UIStackViewDistributionFillEqually;
    [hero addSubview:metricsRow];

    [metricsRow addArrangedSubview:[self metricCardWithTitle:kLang(@"DeliveryCompany_Members_Sheet_ActiveDeliveries")
                                                       value:[NSString stringWithFormat:@"%ld", (long)self.member.activeDeliveryCount]]];
    [metricsRow addArrangedSubview:[self metricCardWithTitle:kLang(@"DeliveryCompany_Members_Sheet_AssignmentState")
                                                       value:(self.member.canReceiveAssignments ? kLang(@"DeliveryCompany_Members_Sheet_AssignmentsOn") : kLang(@"DeliveryCompany_Members_Sheet_AssignmentsOff"))]];

    UIView *contactCard = [self infoCardWithTitle:kLang(@"DeliveryCompany_Members_Sheet_ContactSection")];
    [contentView addSubview:contactCard];
    UIStackView *contactStack = (UIStackView *)[contactCard viewWithTag:1001];
    [contactStack addArrangedSubview:[self infoRowWithTitle:kLang(@"DeliveryCompany_Members_Sheet_UID") value:(self.member.uid.length ? self.member.uid : kLang(@"DeliveryCompany_NotAvailable"))]];
    [contactStack addArrangedSubview:[self infoRowWithTitle:kLang(@"DeliveryCompany_Members_Sheet_Phone") value:(self.member.phone.length ? self.member.phone : kLang(@"DeliveryCompany_NotAvailable"))]];
    [contactStack addArrangedSubview:[self infoRowWithTitle:kLang(@"DeliveryCompany_Members_Sheet_Email") value:(self.member.email.length ? self.member.email : kLang(@"DeliveryCompany_NotAvailable"))]];
    NSString *lastSeen = self.member.online
        ? kLang(@"DeliveryCompany_Members_Sheet_OnlineNow")
        : (self.member.lastSeenAt ? PPDeliveryCompanyFormattedDate(self.member.lastSeenAt) : kLang(@"DeliveryCompany_NotAvailable"));
    [contactStack addArrangedSubview:[self infoRowWithTitle:kLang(@"DeliveryCompany_Members_Sheet_LastSeen") value:lastSeen]];

    UIView *actionsCard = [self infoCardWithTitle:kLang(@"DeliveryCompany_Members_Sheet_ActionsSection")];
    [contentView addSubview:actionsCard];
    UIStackView *actionsStack = (UIStackView *)[actionsCard viewWithTag:1001];
    UIStackView *buttonRow = [[UIStackView alloc] init];
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 12.0;
    buttonRow.distribution = UIStackViewDistributionFillEqually;
    [actionsStack addArrangedSubview:buttonRow];

    UIButton *callButton = [self actionButtonWithTitle:kLang(@"DeliveryCompany_Members_Sheet_Call")
                                                  icon:@"phone.fill"
                                                 color:UIColor.systemGreenColor
                                                action:@selector(callTapped)];
    callButton.enabled = self.member.phone.length > 0;
    callButton.alpha = callButton.enabled ? 1.0 : 0.48;
    [buttonRow addArrangedSubview:callButton];

    UIButton *chatButton = [self actionButtonWithTitle:kLang(@"DeliveryCompany_Members_Sheet_Chat")
                                                  icon:@"message.fill"
                                                 color:UIColor.systemBlueColor
                                                action:@selector(chatTapped)];
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    BOOL canChat = self.member.uid.length > 0 && ![self.member.uid isEqualToString:currentUID];
    chatButton.enabled = canChat;
    chatButton.alpha = canChat ? 1.0 : 0.48;
    [buttonRow addArrangedSubview:chatButton];

    UILabel *footnote = [self label:PPFontRegular(12) color:SeconderyTextClr lines:0];
    footnote.text = kLang(@"DeliveryCompany_Members_Sheet_Footnote");
    [actionsStack addArrangedSubview:footnote];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

        [hero.topAnchor constraintEqualToAnchor:contentView.safeAreaLayoutGuide.topAnchor constant:18.0],
        [hero.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [hero.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],

        [topGlow.widthAnchor constraintEqualToConstant:184.0],
        [topGlow.heightAnchor constraintEqualToConstant:184.0],
        [topGlow.topAnchor constraintEqualToAnchor:hero.topAnchor constant:-58.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:42.0],

        [avatar.topAnchor constraintEqualToAnchor:hero.topAnchor constant:24.0],
        [avatar.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:22.0],
        [avatar.widthAnchor constraintEqualToConstant:56.0],
        [avatar.heightAnchor constraintEqualToConstant:56.0],
        [avatarImageView.topAnchor constraintEqualToAnchor:avatar.topAnchor],
        [avatarImageView.leadingAnchor constraintEqualToAnchor:avatar.leadingAnchor],
        [avatarImageView.trailingAnchor constraintEqualToAnchor:avatar.trailingAnchor],
        [avatarImageView.bottomAnchor constraintEqualToAnchor:avatar.bottomAnchor],
        [avatarIcon.centerXAnchor constraintEqualToAnchor:avatar.centerXAnchor],
        [avatarIcon.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [avatarIcon.widthAnchor constraintEqualToConstant:28.0],
        [avatarIcon.heightAnchor constraintEqualToConstant:28.0],

        [eyebrow.topAnchor constraintEqualToAnchor:avatar.bottomAnchor constant:18.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-22.0],
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [statusPill.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [statusPill.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metricsRow.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:18.0],
        [metricsRow.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:18.0],
        [metricsRow.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-18.0],
        [metricsRow.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-18.0],

        [contactCard.topAnchor constraintEqualToAnchor:hero.bottomAnchor constant:14.0],
        [contactCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [contactCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [actionsCard.topAnchor constraintEqualToAnchor:contactCard.bottomAnchor constant:14.0],
        [actionsCard.leadingAnchor constraintEqualToAnchor:contactCard.leadingAnchor],
        [actionsCard.trailingAnchor constraintEqualToAnchor:contactCard.trailingAnchor],
        [actionsCard.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0],
    ]];
}

- (void)pp_loadAvatarIntoImageView:(UIImageView *)imageView fallbackIconView:(UIImageView *)fallbackIconView {
    NSString *safeURL = [self.member.photoURL isKindOfClass:NSString.class]
        ? [self.member.photoURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    NSURL *url = safeURL.length > 0 ? [NSURL URLWithString:safeURL] : nil;
    if (!url) {
        return;
    }

    imageView.hidden = NO;
    imageView.alpha = 0.0;
    __weak typeof(imageView) weakImageView = imageView;
    __weak typeof(fallbackIconView) weakFallbackIconView = fallbackIconView;
    [imageView sd_setImageWithURL:url
                  placeholderImage:nil
                           options:SDWebImageRetryFailed | SDWebImageScaleDownLargeImages
                         completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        UIImageView *strongImageView = weakImageView;
        UIImageView *strongFallbackIconView = weakFallbackIconView;
        if (!strongImageView || !strongFallbackIconView) return;
        if (!image || error) {
            strongImageView.hidden = YES;
            strongFallbackIconView.hidden = NO;
            return;
        }
        strongFallbackIconView.hidden = YES;
        [UIView animateWithDuration:(cacheType == SDImageCacheTypeNone ? 0.24 : 0.0)
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            strongImageView.alpha = 1.0;
        } completion:nil];
    }];
}

- (UIView *)pillWithText:(NSString *)text color:(UIColor *)color {
    UILabel *label = [self label:PPFontBold(11) color:color lines:1];
    label.text = [NSString stringWithFormat:@"  %@  ", text];
    label.backgroundColor = [color colorWithAlphaComponent:0.11];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 11.0;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    return label;
}

- (UIView *)metricCardWithTitle:(NSString *)title value:(NSString *)value {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.7];
    card.layer.cornerRadius = 22.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *valueLabel = [self label:PPFontBold(21) color:PrimaryTextClr lines:1];
    valueLabel.textAlignment = NSTextAlignmentCenter;
    valueLabel.text = value;
    [card addSubview:valueLabel];

    UILabel *titleLabel = [self label:PPFontMedium(10) color:SeconderyTextClr lines:2];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = title;
    [card addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintEqualToConstant:82.0],
        [valueLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8.0],
        [titleLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:2.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
    ]];
    return card;
}

- (UIView *)infoCardWithTitle:(NSString *)title {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 28.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    card.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.05].CGColor;
    card.layer.shadowOpacity = 1.0;
    card.layer.shadowRadius = 20.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UILabel *titleLabel = [self label:PPFontBold(16) color:PrimaryTextClr lines:1];
    titleLabel.text = title;
    [card addSubview:titleLabel];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.tag = 1001;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [stack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
    ]];
    return card;
}

- (UIView *)infoRowWithTitle:(NSString *)title value:(NSString *)value {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self label:PPFontMedium(12) color:SeconderyTextClr lines:1];
    titleLabel.text = title;
    [row addSubview:titleLabel];

    UILabel *valueLabel = [self label:PPFontBold(14) color:PrimaryTextClr lines:0];
    valueLabel.text = value;
    [row addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    return row;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title icon:(NSString *)icon color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [color colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 20.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = PPFontBold(15);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    button.tintColor = color;
    button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 8.0);
    [button.heightAnchor constraintEqualToConstant:56.0].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (NSString *)availabilityText {
    if (![self.member.status isEqualToString:@"active"]) return kLang(@"DeliveryCompany_Members_Disabled");
    return self.member.available ? kLang(@"DeliveryCompany_Members_Available") : kLang(@"DeliveryCompany_Members_Unavailable");
}

- (UIColor *)availabilityColor {
    if (![self.member.status isEqualToString:@"active"]) return UIColor.systemOrangeColor;
    return self.member.available ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
}

- (void)callTapped {
    [PPFunc pp_playTapEffect];
    if (self.contactHandler) self.contactHandler();
}

- (void)chatTapped {
    [PPFunc pp_playTapEffect];
    if (self.chatHandler) self.chatHandler();
}

@end

@interface PPDeliveryCompanyMembersViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PPDeliveryCompanyProfile *profile;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyMember *> *members;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *headerTopGlowView;
@property (nonatomic, strong) UIView *headerBottomGlowView;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UIButton *inviteButton;
@property (nonatomic, strong) NSLayoutConstraint *inviteButtonHeightConstraint;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *stateView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *stateTitle;
@property (nonatomic, strong) UILabel *stateSubtitle;
@property (nonatomic, strong) UIButton *retryButton;
@end

@implementation PPDeliveryCompanyMembersViewController

- (instancetype)initWithProfile:(PPDeliveryCompanyProfile *)profile {
    if (self = [super init]) {
        _profile = profile;
        _members = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildUI];
    [self loadMembers];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryCompany_Members_NavTitle") showBack:YES];
}

- (void)buildUI {
    self.headerView = [[UIView alloc] init];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerView.backgroundColor = AppForgroundColr;
    self.headerView.layer.cornerRadius = 34.0;
    self.headerView.layer.cornerCurve = kCACornerCurveContinuous;
    self.headerView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.headerView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    self.headerView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.07].CGColor;
    self.headerView.layer.shadowOpacity = 1.0;
    self.headerView.layer.shadowRadius = 28.0;
    self.headerView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.view addSubview:self.headerView];

    self.headerTopGlowView = [[UIView alloc] init];
    self.headerTopGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    self.headerTopGlowView.layer.cornerRadius = 96.0;
    self.headerTopGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.headerView addSubview:self.headerTopGlowView];

    self.headerBottomGlowView = [[UIView alloc] init];
    self.headerBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerBottomGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.04];
    self.headerBottomGlowView.layer.cornerRadius = 120.0;
    self.headerBottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.headerView addSubview:self.headerBottomGlowView];

    UILabel *eyebrow = [self label:PPFontBold(11) color:AppPrimaryClr lines:1];
    eyebrow.text = kLang(@"DeliveryCompany_Members_Eyebrow");
    [self.headerView addSubview:eyebrow];

    UILabel *title = [self label:PPFontBold(34) color:PrimaryTextClr lines:2];
    title.text = kLang(@"DeliveryCompany_Members_Title");
    [self.headerView addSubview:title];

    UILabel *subtitle = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    subtitle.text = kLang(@"DeliveryCompany_Members_Subtitle");
    [self.headerView addSubview:subtitle];

    self.countLabel = [self label:PPFontBold(24) color:PrimaryTextClr lines:1];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.65];
    self.countLabel.layer.cornerRadius = 22.0;
    self.countLabel.clipsToBounds = YES;
    [self.headerView addSubview:self.countLabel];

    self.summaryLabel = [self label:PPFontMedium(12) color:SeconderyTextClr lines:2];
    [self.headerView addSubview:self.summaryLabel];

    self.inviteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.inviteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.inviteButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.96];
    self.inviteButton.layer.cornerRadius = 22.0;
    self.inviteButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.inviteButton.titleLabel.font = PPFontBold(15);
    [self.inviteButton setTitle:kLang(@"DeliveryCompany_Members_InviteHero") forState:UIControlStateNormal];
    [self.inviteButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.inviteButton setImage:[UIImage systemImageNamed:@"person.badge.plus"] forState:UIControlStateNormal];
    self.inviteButton.tintColor = UIColor.whiteColor;
    self.inviteButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 8.0);
    [self.inviteButton addTarget:self action:@selector(inviteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.inviteButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 152.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    [self.tableView registerClass:PPDeliveryCompanyMemberCell.class forCellReuseIdentifier:@"PPDeliveryCompanyMemberCell"];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = AppPrimaryClr;
    [self.refreshControl addTarget:self action:@selector(loadMembers) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    [self buildStateView];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.headerTopGlowView.widthAnchor constraintEqualToConstant:192.0],
        [self.headerTopGlowView.heightAnchor constraintEqualToConstant:192.0],
        [self.headerTopGlowView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:-58.0],
        [self.headerTopGlowView.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:54.0],
        [self.headerBottomGlowView.widthAnchor constraintEqualToConstant:240.0],
        [self.headerBottomGlowView.heightAnchor constraintEqualToConstant:240.0],
        [self.headerBottomGlowView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:84.0],
        [self.headerBottomGlowView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:-72.0],
        [eyebrow.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:22.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:20.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-20.0],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.countLabel.leadingAnchor constant:-14.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.countLabel.leadingAnchor constant:-14.0],

        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-18.0],
        [self.countLabel.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.countLabel.widthAnchor constraintEqualToConstant:74.0],
        [self.countLabel.heightAnchor constraintEqualToConstant:58.0],

        [self.summaryLabel.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:14.0],
        [self.summaryLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.summaryLabel.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-20.0],

        [self.inviteButton.topAnchor constraintEqualToAnchor:self.summaryLabel.bottomAnchor constant:14.0],
        [self.inviteButton.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.inviteButton.widthAnchor constraintGreaterThanOrEqualToConstant:184.0],
        [self.inviteButton.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-20.0],

        [self.tableView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:10.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    self.inviteButtonHeightConstraint = [self.inviteButton.heightAnchor constraintEqualToConstant:52.0];
    self.inviteButtonHeightConstraint.active = YES;
}

- (void)buildStateView {
    self.stateView = [[UIView alloc] init];
    self.stateView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stateView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AppPrimaryClr;
    [self.stateView addSubview:self.spinner];

    self.stateTitle = [self label:PPFontBold(18) color:PrimaryTextClr lines:2];
    self.stateTitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateTitle];

    self.stateSubtitle = [self label:PPFontRegular(14) color:SeconderyTextClr lines:0];
    self.stateSubtitle.textAlignment = NSTextAlignmentCenter;
    [self.stateView addSubview:self.stateSubtitle];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.backgroundColor = AppPrimaryClr;
    self.retryButton.layer.cornerRadius = 15.0;
    self.retryButton.titleLabel.font = PPFontBold(15);
    [self.retryButton setTitle:kLang(@"Retry") forState:UIControlStateNormal];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.retryButton addTarget:self action:@selector(loadMembers) forControlEvents:UIControlEventTouchUpInside];
    [self.stateView addSubview:self.retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.stateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stateView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
        [self.stateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:34.0],
        [self.stateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-34.0],
        [self.spinner.topAnchor constraintEqualToAnchor:self.stateView.topAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [self.stateTitle.topAnchor constraintEqualToAnchor:self.spinner.bottomAnchor constant:15.0],
        [self.stateTitle.leadingAnchor constraintEqualToAnchor:self.stateView.leadingAnchor],
        [self.stateTitle.trailingAnchor constraintEqualToAnchor:self.stateView.trailingAnchor],
        [self.stateSubtitle.topAnchor constraintEqualToAnchor:self.stateTitle.bottomAnchor constant:6.0],
        [self.stateSubtitle.leadingAnchor constraintEqualToAnchor:self.stateView.leadingAnchor],
        [self.stateSubtitle.trailingAnchor constraintEqualToAnchor:self.stateView.trailingAnchor],
        [self.retryButton.topAnchor constraintEqualToAnchor:self.stateSubtitle.bottomAnchor constant:15.0],
        [self.retryButton.centerXAnchor constraintEqualToAnchor:self.stateView.centerXAnchor],
        [self.retryButton.widthAnchor constraintGreaterThanOrEqualToConstant:120.0],
        [self.retryButton.heightAnchor constraintEqualToConstant:44.0],
        [self.retryButton.bottomAnchor constraintEqualToAnchor:self.stateView.bottomAnchor],
    ]];
}

- (void)loadMembers {
    
    self.tableView.hidden = YES;
    self.stateView.hidden = NO;
    self.stateTitle.hidden = self.stateSubtitle.hidden = self.retryButton.hidden = YES;
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared listMembersForCompanyID:self.profile.companyID completion:^(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.refreshControl endRefreshing];
        [self.spinner stopAnimating];
        if (error) {
            self.stateTitle.hidden = self.stateSubtitle.hidden = self.retryButton.hidden = NO;
            self.stateTitle.text = kLang(@"DeliveryCompany_Error_Title");
            self.stateSubtitle.text = error.localizedDescription;
            return;
        }
        self.members = members ?: @[];
        self.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.members.count];
        [self updateHeroSummary];
        [self.tableView reloadData];
        if (!self.members.count) {
            self.stateTitle.hidden = self.stateSubtitle.hidden = NO;
            self.retryButton.hidden = YES;
            self.stateTitle.text = kLang(@"DeliveryCompany_Members_EmptyTitle");
            self.stateSubtitle.text = kLang(@"DeliveryCompany_Members_EmptySubtitle");
            return;
        }
        self.stateView.hidden = YES;
        self.tableView.hidden = NO;
    }];
}

- (void)updateHeroSummary {
    NSInteger activeDrivers = 0;
    NSInteger availableMembers = 0;
    for (PPDeliveryCompanyMember *member in self.members) {
        if (member.isActiveDriver) activeDrivers += 1;
        if ([member.status isEqualToString:@"active"] && member.available) availableMembers += 1;
    }
    self.summaryLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Members_Summary_Format"),
                              (long)activeDrivers,
                              (long)availableMembers];
    self.inviteButton.hidden = !self.profile.canManageMembers;
    self.inviteButtonHeightConstraint.constant = self.profile.canManageMembers ? 52.0 : 0.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.members.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryCompanyMember *member = self.members[indexPath.row];
    PPDeliveryCompanyMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPDeliveryCompanyMemberCell" forIndexPath:indexPath];
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    BOOL canDisable = self.profile.canManageMembers &&
                      [member.status isEqualToString:@"active"] &&
                      ![member.uid isEqualToString:currentUID] &&
                      ![member.role isEqualToString:PPDeliveryCompanyRoleOwner];
    [cell configure:member showDisable:canDisable];
    __weak typeof(self) weakSelf = self;
    cell.disableHandler = ^{
        [weakSelf confirmDisableMember:member];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [PPFunc pp_playTapEffect];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self presentMemberSheetForMember:self.members[indexPath.row]];
}

- (void)presentMemberSheetForMember:(PPDeliveryCompanyMember *)member {
    PPDeliveryCompanyMemberSheetViewController *controller = [[PPDeliveryCompanyMemberSheetViewController alloc] initWithMember:member];
    __weak typeof(self) weakSelf = self;
    controller.contactHandler = ^{
        [weakSelf callMember:member];
    };
    controller.chatHandler = ^{
        [weakSelf openChatWithMember:member fromController:controller];
    };
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = controller.sheetPresentationController;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 38.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetentIdentifier const detentIdentifier = @"deliveryCompanyMemberDetail89";
            UISheetPresentationControllerDetent *detent =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:detentIdentifier
                                                                       resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                return context.maximumDetentValue * 0.89;
            }];
            sheet.detents = @[detent];
            sheet.selectedDetentIdentifier = detentIdentifier;
        } else {
            sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        }
    }
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)confirmDisableMember:(PPDeliveryCompanyMember *)member {
    NSString *name = member.displayName.length ? member.displayName : member.uid;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"DeliveryCompany_Members_DisableTitle")
                             subtitle:[NSString stringWithFormat:kLang(@"DeliveryCompany_Members_DisableMessage_Format"), name]
                          placeholder:nil
                        confirmButton:kLang(@"DeliveryCompany_Members_Disable")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{ [self disableMember:member]; }
                          cancelBlock:nil];
}

- (void)disableMember:(PPDeliveryCompanyMember *)member {
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared disableMemberUID:member.uid companyID:self.profile.companyID completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"DeliveryCompany_Error_Title") subtitle:error.localizedDescription];
            return;
        }
        [PPFunc pp_playSuccessEffect];
        [PPToast toast:kLang(@"DeliveryCompany_Members_DisabledSuccess") style:PPToastStyleSuccess haptic:NO duration:1.8];
        [self loadMembers];
    }];
}

- (void)inviteTapped {
    if (!self.profile.canManageMembers) return;
    [PPFunc pp_playTapEffect];
    PPDeliveryCompanyInviteMemberSheetViewController *controller = [[PPDeliveryCompanyInviteMemberSheetViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationPageSheet;
    controller.modalInPresentation = YES;
    __weak typeof(self) weakSelf = self;
    controller.submitHandler = ^(NSString *identifier, NSString *role, PPDeliveryCompanyInviteSubmitCompletion completion) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (completion) completion([NSError errorWithDomain:@"PPDeliveryCompanyMembers" code:-1 userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Title")}]);
            return;
        }
        [PPDeliveryCompanyService.shared inviteMemberIdentifier:identifier role:role companyID:self.profile.companyID completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
            if (completion) completion(error);
        }];
    };
    controller.successHandler = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPToast toast:kLang(@"DeliveryCompany_Members_InviteSuccess") style:PPToastStyleSuccess haptic:NO duration:1.8];
        [self loadMembers];
    };
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = controller.sheetPresentationController;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 42.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetentIdentifier const tallDetentIdentifier = @"deliveryCompanyInviteTall";
            UISheetPresentationControllerDetent *tallDetent =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:tallDetentIdentifier
                                                                       resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                return context.maximumDetentValue * 0.98;
            }];
            sheet.detents = @[tallDetent];
            sheet.selectedDetentIdentifier = tallDetentIdentifier;
        } else {
            sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        }
    }
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)callMember:(PPDeliveryCompanyMember *)member {
    NSString *phone = member.phone ?: @"";
    if (phone.length == 0) {
        [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_CallUnavailable")];
        return;
    }
    NSString *cleaned = [[phone componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]] componentsJoinedByString:@""];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", cleaned]];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_CallUnavailable")];
    }
}

- (void)openChatWithMember:(PPDeliveryCompanyMember *)member fromController:(UIViewController *)presentedController {
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (member.uid.length == 0 || [member.uid isEqualToString:currentUID]) {
        [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_ChatUnavailable")];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *threadID = ([currentUID compare:member.uid] == NSOrderedAscending)
        ? [NSString stringWithFormat:@"%@_%@", currentUID, member.uid]
        : [NSString stringWithFormat:@"%@_%@", member.uid, currentUID];
    FIRDocumentReference *threadRef = [[db collectionWithPath:@"Chats"] documentWithPath:threadID];

    __weak typeof(self) weakSelf = self;
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error) {
                [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_ChatUnavailable")];
                return;
            }

            FIRUser *authenticatedUser = [FIRAuth auth].currentUser;
            UserModel *currentUser = [UserManager shared].currentUser;
            BOOL sessionMatchesCurrentUser =
                ([currentUser.uid isEqualToString:currentUID] || [currentUser.ID isEqualToString:currentUID]);
            NSString *currentName = sessionMatchesCurrentUser && currentUser.PPBestDisplayName.length
                ? currentUser.PPBestDisplayName
                : (authenticatedUser.displayName.length ? authenticatedUser.displayName : currentUID);
            NSString *currentPhotoURL = sessionMatchesCurrentUser && currentUser.UserImageUrl.absoluteString.length
                ? currentUser.UserImageUrl.absoluteString
                : (authenticatedUser.photoURL.absoluteString ?: @"");

            NSDictionary *metadata = @{
                @"conversationType": @"provider_chat",
                @"threadType": @"provider_chat",
                @"supportThread": @(NO),
                @"supportUserId": member.uid,
                @"customerId": currentUID,
                @"supportDisplayName": currentName,
                @"supportPhotoUrl": currentPhotoURL,
                @"supportStatus": @"active",
                @"sourcePlatform": @"pro_ios",
                @"sourceScreen": @"delivery_company_members",
                @"sourceType": @"company_member",
                @"sourceEntityId": self.profile.companyID ?: @""
            };

            void (^openChat)(void) = ^{
                [presentedController dismissViewControllerAnimated:YES completion:^{
                    [self openMemberChatThreadWithID:threadID member:member];
                }];
            };

            if (snapshot.exists) {
                NSDictionary *existingData = snapshot.data ?: @{};
                NSArray *members = existingData[@"members"];
                if (![members isKindOfClass:NSArray.class] ||
                    ![members containsObject:currentUID] ||
                    ![members containsObject:member.uid]) {
                    [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_ChatUnavailable")];
                    return;
                }
                [threadRef setData:metadata merge:YES completion:^(NSError * _Nullable mergeError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (mergeError) {
                            [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_ChatUnavailable")];
                            return;
                        }
                        openChat();
                    });
                }];
                return;
            }

            NSMutableDictionary *payload = [@{
                @"members": @[currentUID, member.uid],
                @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
                @"lastMessage": @"",
                @"lastUpdated": [FIRFieldValue fieldValueForServerTimestamp],
                @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
                @"mutedBy": @[],
                @"binnedBy": @[],
                @"reportedBy": @[],
                @"reportCount": @0,
                @"messagesCount": @0
            } mutableCopy];
            [payload addEntriesFromDictionary:metadata];

            [threadRef setData:payload completion:^(NSError * _Nullable createError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (createError) {
                        [PPToast toast:kLang(@"DeliveryCompany_Members_Sheet_ChatUnavailable")];
                        return;
                    }
                    openChat();
                });
            }];
        });
    }];
}

- (void)openMemberChatThreadWithID:(NSString *)threadID member:(PPDeliveryCompanyMember *)member {
    ChatThreadModel *thread = [[ChatThreadModel alloc] init];
    thread.ID = threadID;
    thread.conversationType = @"provider_chat";
    thread.supportUserID = member.uid ?: @"";
    thread.customerId = [FIRAuth auth].currentUser.uid ?: @"";
    thread.supportDisplayName = member.displayName.length ? member.displayName : member.uid;
    thread.memberIDs = @[thread.customerId ?: @"", member.uid ?: @""];

    UserModel *memberUser = [UserModel new];
    memberUser.ID = member.uid;
    memberUser.UserName = member.displayName.length ? member.displayName : member.uid;
    thread.otherUser = memberUser;

    PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
    [self.navigationController pushViewController:messagesVC animated:YES];
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

@end
