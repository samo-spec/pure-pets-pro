//
//  PPServiceRequestsViewController.m
//  PurePetsPro
//
//  SwiftyMax NextGen V10 Category-Defining Pet Service Bookings & Over-Follow Pipeline.
//  First-principles reinvention: Real-time telemetry, stage progression, direct customer
//  calling/messaging, pet clinical & grooming notes, and offline-resilient local persistence.
//

#import "PPServiceRequestsViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPFirebaseCompat.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "UIImageView+WebCache.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPFunc.h"
#import "PPAlertHelper.h"
#import <objc/runtime.h>

#pragma mark - PPServiceBookingCardCell (NextGen V10 Atelier Floor Card)

@interface PPServiceBookingCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *petImageView;
@property (nonatomic, strong) UIView *speciesTagBg;
@property (nonatomic, strong) UILabel *speciesTagLabel;
@property (nonatomic, strong) UILabel *petNameLabel;
@property (nonatomic, strong) UILabel *serviceTitleLabel;
@property (nonatomic, strong) UILabel *customerInfoLabel;
@property (nonatomic, strong) UILabel *dateTimeLabel;
@property (nonatomic, strong) UILabel *locationLabel;
@property (nonatomic, strong) UILabel *pricePill;
@property (nonatomic, strong) UIView *statusBadgeContainer;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UILabel *inclusionsLabel;
@property (nonatomic, strong) UIButton *callClientBtn;
@property (nonatomic, strong) UIButton *primaryActionBtn;
@property (nonatomic, strong) UIButton *secondaryActionBtn;
@property (nonatomic, copy, nullable) void(^onPrimaryAction)(PPServiceBookingItem *item);
@property (nonatomic, copy, nullable) void(^onSecondaryAction)(PPServiceBookingItem *item);
@property (nonatomic, copy, nullable) void(^onCallClient)(PPServiceBookingItem *item);
@property (nonatomic, strong) PPServiceBookingItem *item;
@end

@implementation PPServiceBookingCardCell

+ (NSString *)reuseID { return @"PPServiceBookingCardCell"; }

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
    _cardView = [UIView new];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(_cardView, PPCornerCard);
    _cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _cardView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(_cardView);
    [self.contentView addSubview:_cardView];

    _petImageView = [UIImageView new];
    _petImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _petImageView.contentMode = UIViewContentModeScaleAspectFill;
    _petImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_petImageView, 16.0);
    _petImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    [_cardView addSubview:_petImageView];

    _speciesTagBg = [UIView new];
    _speciesTagBg.translatesAutoresizingMaskIntoConstraints = NO;
    _speciesTagBg.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(_speciesTagBg, 6.0);
    [_cardView addSubview:_speciesTagBg];

    _speciesTagLabel = [UILabel new];
    _speciesTagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _speciesTagLabel.font = [Styling fontBold:9.5];
    _speciesTagLabel.textColor = AppPrimaryClr;
    _speciesTagLabel.textAlignment = NSTextAlignmentCenter;
    [_speciesTagBg addSubview:_speciesTagLabel];

    _pricePill = [UILabel new];
    _pricePill.translatesAutoresizingMaskIntoConstraints = NO;
    _pricePill.font = [Styling fontBold:13.5];
    _pricePill.textColor = [UIColor ppSuccess];
    _pricePill.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    _pricePill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_pricePill, 10.0);
    _pricePill.clipsToBounds = YES;
    [_cardView addSubview:_pricePill];

    _petNameLabel = [UILabel new];
    _petNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _petNameLabel.font = [Styling fontBold:16.0];
    _petNameLabel.textColor = PrimaryTextClr;
    _petNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_petNameLabel];

    _serviceTitleLabel = [UILabel new];
    _serviceTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _serviceTitleLabel.font = [Styling fontMedium:13.0];
    _serviceTitleLabel.textColor = AppPrimaryClr;
    _serviceTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_serviceTitleLabel];

    // Status pill
    _statusBadgeContainer = [UIView new];
    _statusBadgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgeContainer.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(_statusBadgeContainer, 6.0);
    [_cardView addSubview:_statusBadgeContainer];

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

    // Customer & direct calling button
    _customerInfoLabel = [UILabel new];
    _customerInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _customerInfoLabel.font = [Styling fontRegular:12.5];
    _customerInfoLabel.textColor = SeconderyTextClr;
    _customerInfoLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_customerInfoLabel];

    _callClientBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _callClientBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_callClientBtn setImage:[UIImage systemImageNamed:@"phone.circle.fill"
                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    _callClientBtn.tintColor = [UIColor ppSuccess];
    [_callClientBtn addTarget:self action:@selector(callBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_callClientBtn];

    _dateTimeLabel = [UILabel new];
    _dateTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateTimeLabel.font = [Styling fontMedium:12.0];
    _dateTimeLabel.textColor = SeconderyTextClr;
    _dateTimeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_dateTimeLabel];

    _locationLabel = [UILabel new];
    _locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _locationLabel.font = [Styling fontRegular:12.0];
    _locationLabel.textColor = SeconderyTextClr;
    _locationLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_locationLabel];

    _inclusionsLabel = [UILabel new];
    _inclusionsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _inclusionsLabel.font = [Styling fontRegular:11.5];
    _inclusionsLabel.textColor = [UIColor ppTextTertiary];
    _inclusionsLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _inclusionsLabel.numberOfLines = 1;
    _inclusionsLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardView addSubview:_inclusionsLabel];

    _secondaryActionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _secondaryActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _secondaryActionBtn.backgroundColor = [UIColor ppSurface];
    [_secondaryActionBtn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    _secondaryActionBtn.titleLabel.font = [Styling fontMedium:13.0];
    _secondaryActionBtn.layer.borderWidth = 1.0;
    _secondaryActionBtn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_secondaryActionBtn, PPCornerMedium);
    [_secondaryActionBtn addTarget:self action:@selector(secondaryBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_secondaryActionBtn];

    _primaryActionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _primaryActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _primaryActionBtn.backgroundColor = [UIColor ppPrimary];
    [_primaryActionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _primaryActionBtn.titleLabel.font = [Styling fontBold:13.0];
    PPApplyContinuousCorners(_primaryActionBtn, PPCornerMedium);
    PPApplyButtonShadow(_primaryActionBtn);
    [_primaryActionBtn addTarget:self action:@selector(primaryBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_primaryActionBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_petImageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_petImageView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_petImageView.widthAnchor constraintEqualToConstant:66.0],
        [_petImageView.heightAnchor constraintEqualToConstant:66.0],

        [_speciesTagBg.centerXAnchor constraintEqualToAnchor:_petImageView.centerXAnchor],
        [_speciesTagBg.topAnchor constraintEqualToAnchor:_petImageView.bottomAnchor constant:4.0],
        [_speciesTagBg.heightAnchor constraintEqualToConstant:18.0],
        [_speciesTagLabel.leadingAnchor constraintEqualToAnchor:_speciesTagBg.leadingAnchor constant:6.0],
        [_speciesTagLabel.trailingAnchor constraintEqualToAnchor:_speciesTagBg.trailingAnchor constant:-6.0],
        [_speciesTagLabel.centerYAnchor constraintEqualToAnchor:_speciesTagBg.centerYAnchor],

        [_pricePill.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_pricePill.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_pricePill.heightAnchor constraintEqualToConstant:26.0],

        [_petNameLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_petNameLabel.leadingAnchor constraintEqualToAnchor:_petImageView.trailingAnchor constant:12.0],
        [_petNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePill.leadingAnchor constant:-8.0],

        [_serviceTitleLabel.topAnchor constraintEqualToAnchor:_petNameLabel.bottomAnchor constant:2.0],
        [_serviceTitleLabel.leadingAnchor constraintEqualToAnchor:_petNameLabel.leadingAnchor],
        [_serviceTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePill.leadingAnchor constant:-8.0],

        [_statusBadgeContainer.topAnchor constraintEqualToAnchor:_serviceTitleLabel.bottomAnchor constant:4.0],
        [_statusBadgeContainer.leadingAnchor constraintEqualToAnchor:_petNameLabel.leadingAnchor],
        [_statusBadgeContainer.heightAnchor constraintEqualToConstant:20.0],

        [_statusDot.leadingAnchor constraintEqualToAnchor:_statusBadgeContainer.leadingAnchor constant:6.0],
        [_statusDot.centerYAnchor constraintEqualToAnchor:_statusBadgeContainer.centerYAnchor],
        [_statusDot.widthAnchor constraintEqualToConstant:7.0],
        [_statusDot.heightAnchor constraintEqualToConstant:7.0],

        [_statusBadge.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:4.0],
        [_statusBadge.trailingAnchor constraintEqualToAnchor:_statusBadgeContainer.trailingAnchor constant:-6.0],
        [_statusBadge.centerYAnchor constraintEqualToAnchor:_statusBadgeContainer.centerYAnchor],

        [_customerInfoLabel.topAnchor constraintEqualToAnchor:_statusBadgeContainer.bottomAnchor constant:8.0],
        [_customerInfoLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_customerInfoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_callClientBtn.leadingAnchor constant:-8.0],

        [_callClientBtn.centerYAnchor constraintEqualToAnchor:_customerInfoLabel.centerYAnchor],
        [_callClientBtn.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_callClientBtn.widthAnchor constraintEqualToConstant:28.0],
        [_callClientBtn.heightAnchor constraintEqualToConstant:28.0],

        [_dateTimeLabel.topAnchor constraintEqualToAnchor:_customerInfoLabel.bottomAnchor constant:4.0],
        [_dateTimeLabel.leadingAnchor constraintEqualToAnchor:_customerInfoLabel.leadingAnchor],
        [_dateTimeLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_locationLabel.topAnchor constraintEqualToAnchor:_dateTimeLabel.bottomAnchor constant:4.0],
        [_locationLabel.leadingAnchor constraintEqualToAnchor:_customerInfoLabel.leadingAnchor],
        [_locationLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_inclusionsLabel.topAnchor constraintEqualToAnchor:_locationLabel.bottomAnchor constant:4.0],
        [_inclusionsLabel.leadingAnchor constraintEqualToAnchor:_customerInfoLabel.leadingAnchor],
        [_inclusionsLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_secondaryActionBtn.topAnchor constraintEqualToAnchor:_inclusionsLabel.bottomAnchor constant:12.0],
        [_secondaryActionBtn.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_secondaryActionBtn.heightAnchor constraintEqualToConstant:38.0],
        [_secondaryActionBtn.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-14.0],

        [_primaryActionBtn.topAnchor constraintEqualToAnchor:_secondaryActionBtn.topAnchor],
        [_primaryActionBtn.leadingAnchor constraintEqualToAnchor:_secondaryActionBtn.trailingAnchor constant:10.0],
        [_primaryActionBtn.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_primaryActionBtn.widthAnchor constraintEqualToAnchor:_secondaryActionBtn.widthAnchor],
        [_primaryActionBtn.heightAnchor constraintEqualToConstant:38.0],
    ]];
}

- (void)configureWithItem:(PPServiceBookingItem *)item {
    _item = item;
    BOOL isRTL = Language.isRTL;

    _petNameLabel.text = [NSString stringWithFormat:@"🐾 %@ · %@", item.petName ?: @"—", item.petBreed ?: @""];
    _serviceTitleLabel.text = item.serviceTitle ?: @"";
    _customerInfoLabel.text = [NSString stringWithFormat:@"👤 %@ · %@", item.customerName ?: (isRTL ? @"عميل PurePets" : @"PurePets Client"), item.customerPhone ?: @""];
    _dateTimeLabel.text = [NSString stringWithFormat:@"🗓️ %@", item.bookingDateText ?: @""];
    _locationLabel.text = [NSString stringWithFormat:@"📍 %@", item.locationText ?: (isRTL ? @"الدوحة، قطر" : @"Doha, Qatar")];
    _pricePill.text = [NSString stringWithFormat:@"  %.0f %@  ", item.price, item.currency ?: @"QAR"];

    if (item.inclusionsText.length > 0) {
        _inclusionsLabel.text = [NSString stringWithFormat:@"✨ %@", item.inclusionsText];
        _inclusionsLabel.hidden = NO;
    } else {
        _inclusionsLabel.hidden = YES;
    }

    // Species tag
    NSString *sp = isRTL ? @"أليف" : @"Pet";
    if (item.petKindID == 1) sp = isRTL ? @"كلاب" : @"Dog";
    else if (item.petKindID == 2) sp = isRTL ? @"قطط" : @"Cat";
    else if (item.petKindID == 3) sp = isRTL ? @"طيور" : @"Bird";
    _speciesTagLabel.text = sp;

    // Status styling & actions
    UIColor *accent = [item statusAccentColor];
    _statusDot.backgroundColor = accent;
    _statusBadge.textColor = accent;
    _statusBadge.text = [item localizedStatusText];
    _statusBadgeContainer.backgroundColor = [accent colorWithAlphaComponent:0.10];

    NSString *st = item.status.lowercaseString;
    _primaryActionBtn.enabled = YES;
    if ([st isEqualToString:@"new"]) {
        [_primaryActionBtn setTitle:isRTL ? @"قبول وتأكيد الحجز" : @"Accept Booking" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSuccess];
        [_secondaryActionBtn setTitle:isRTL ? @"اعتذار / رفض" : @"Decline" forState:UIControlStateNormal];
    } else if ([st isEqualToString:@"scheduled"]) {
        [_primaryActionBtn setTitle:isRTL ? @"بدء تقديم الجلسة" : @"Start Session" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppPrimary];
        [_secondaryActionBtn setTitle:isRTL ? @"اتصال بالعميل" : @"Call Client" forState:UIControlStateNormal];
    } else if ([st isEqualToString:@"in_progress"]) {
        [_primaryActionBtn setTitle:isRTL ? @"إتمام الخدمة بنجاح" : @"Mark Completed" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSuccess];
        [_secondaryActionBtn setTitle:isRTL ? @"مراسلة العميل" : @"Message Client" forState:UIControlStateNormal];
    } else {
        [_primaryActionBtn setTitle:isRTL ? @"تم الإنجاز" : @"Completed" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSecondarySurface];
        _primaryActionBtn.enabled = NO;
        [_secondaryActionBtn setTitle:isRTL ? @"عرض الإيصال" : @"View Receipt" forState:UIControlStateNormal];
    }

    if (item.petPhotoURL.length > 0) {
        [_petImageView sd_setImageWithURL:[NSURL URLWithString:item.petPhotoURL]
                         placeholderImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    } else {
        _petImageView.image = [UIImage systemImageNamed:@"pawprint.fill"
                                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightRegular]];
        _petImageView.tintColor = AppPrimaryClr;
        _petImageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)callBtnTapped {
    [PPFunc pp_playTapEffect];
    if (self.onCallClient && self.item) {
        self.onCallClient(self.item);
    }
}

- (void)primaryBtnTapped {
    [PPFunc pp_playTapEffect];
    if (self.onPrimaryAction && self.item) {
        self.onPrimaryAction(self.item);
    }
}

- (void)secondaryBtnTapped {
    [PPFunc pp_playTapEffect];
    if (self.onSecondaryAction && self.item) {
        self.onSecondaryAction(self.item);
    }
}

@end

#pragma mark - PPServiceBookingDetailSheet (Inspector Modal)

@interface PPServiceBookingDetailSheet : UIViewController
@property (nonatomic, strong) PPServiceBookingItem *item;
@property (nonatomic, copy, nullable) void(^onStatusChanged)(PPServiceBookingItem *item);
@end

@implementation PPServiceBookingDetailSheet

- (instancetype)initWithItem:(PPServiceBookingItem *)item {
    if (self = [super init]) {
        _item = [item copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *grabber = [UIView new];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor ppSeparator];
    grabber.layer.cornerRadius = 2.5;
    [self.view addSubview:grabber];

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scroll];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10.0],
        [grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:40.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],

        [scroll.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:12.0],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-30.0],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-32.0],
    ]];

    BOOL isRTL = Language.isRTL;

    // Header Card
    UIView *petCard = [self makeCard];
    UILabel *petTitle = [UILabel new];
    petTitle.translatesAutoresizingMaskIntoConstraints = NO;
    petTitle.text = [NSString stringWithFormat:@"🐾 %@ (%@)", self.item.petName ?: @"—", self.item.petBreed ?: @""];
    petTitle.font = [Styling fontBold:18.0];
    petTitle.textColor = PrimaryTextClr;
    petTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [petCard addSubview:petTitle];

    UILabel *servLabel = [UILabel new];
    servLabel.translatesAutoresizingMaskIntoConstraints = NO;
    servLabel.text = [NSString stringWithFormat:@"✨ %@", self.item.serviceTitle ?: @""];
    servLabel.font = [Styling fontBold:14.0];
    servLabel.textColor = AppPrimaryClr;
    servLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [petCard addSubview:servLabel];

    UILabel *priceLabel = [UILabel new];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    priceLabel.text = [NSString stringWithFormat:@"%.0f %@", self.item.price, self.item.currency ?: @"QAR"];
    priceLabel.font = [Styling fontBold:15.0];
    priceLabel.textColor = [UIColor ppSuccess];
    [petCard addSubview:priceLabel];

    [NSLayoutConstraint activateConstraints:@[
        [petTitle.topAnchor constraintEqualToAnchor:petCard.topAnchor constant:16.0],
        [petTitle.leadingAnchor constraintEqualToAnchor:petCard.leadingAnchor constant:16.0],
        [petTitle.trailingAnchor constraintLessThanOrEqualToAnchor:priceLabel.leadingAnchor constant:-8.0],

        [priceLabel.centerYAnchor constraintEqualToAnchor:petTitle.centerYAnchor],
        [priceLabel.trailingAnchor constraintEqualToAnchor:petCard.trailingAnchor constant:-16.0],

        [servLabel.topAnchor constraintEqualToAnchor:petTitle.bottomAnchor constant:6.0],
        [servLabel.leadingAnchor constraintEqualToAnchor:petTitle.leadingAnchor],
        [servLabel.trailingAnchor constraintEqualToAnchor:petCard.trailingAnchor constant:-16.0],
        [servLabel.bottomAnchor constraintEqualToAnchor:petCard.bottomAnchor constant:-16.0],
    ]];
    [stack addArrangedSubview:petCard];

    // Pet Care & Temperament Notes
    UIView *notesCard = [self makeCard];
    UILabel *notesHeader = [UILabel new];
    notesHeader.translatesAutoresizingMaskIntoConstraints = NO;
    notesHeader.text = isRTL ? @"📋 تعليمات وملاحظات العناية الخاصة" : @"Care & Special Instructions";
    notesHeader.font = [Styling fontBold:14.0];
    notesHeader.textColor = PrimaryTextClr;
    notesHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [notesCard addSubview:notesHeader];

    UILabel *notesBody = [UILabel new];
    notesBody.translatesAutoresizingMaskIntoConstraints = NO;
    notesBody.text = self.item.petNotes.length > 0 ? self.item.petNotes : (isRTL ? @"لا توجد شروط أو حساسيات خاصة مسجلة لهذا الأليف." : @"No special allergies or requirements noted.");
    notesBody.font = [Styling fontRegular:13.0];
    notesBody.textColor = SeconderyTextClr;
    notesBody.numberOfLines = 0;
    notesBody.textAlignment = Language.alignmentForCurrentLanguage;
    [notesCard addSubview:notesBody];

    [NSLayoutConstraint activateConstraints:@[
        [notesHeader.topAnchor constraintEqualToAnchor:notesCard.topAnchor constant:14.0],
        [notesHeader.leadingAnchor constraintEqualToAnchor:notesCard.leadingAnchor constant:16.0],
        [notesHeader.trailingAnchor constraintEqualToAnchor:notesCard.trailingAnchor constant:-16.0],

        [notesBody.topAnchor constraintEqualToAnchor:notesHeader.bottomAnchor constant:8.0],
        [notesBody.leadingAnchor constraintEqualToAnchor:notesCard.leadingAnchor constant:16.0],
        [notesBody.trailingAnchor constraintEqualToAnchor:notesCard.trailingAnchor constant:-16.0],
        [notesBody.bottomAnchor constraintEqualToAnchor:notesCard.bottomAnchor constant:-14.0],
    ]];
    [stack addArrangedSubview:notesCard];

    // Customer & Appointment Info
    UIView *custCard = [self makeCard];
    UILabel *custHeader = [UILabel new];
    custHeader.translatesAutoresizingMaskIntoConstraints = NO;
    custHeader.text = isRTL ? @"👤 بيانات العميل والحجز" : @"Client & Appointment Details";
    custHeader.font = [Styling fontBold:14.0];
    custHeader.textColor = PrimaryTextClr;
    custHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [custCard addSubview:custHeader];

    UILabel *custDetails = [UILabel new];
    custDetails.translatesAutoresizingMaskIntoConstraints = NO;
    custDetails.font = [Styling fontRegular:13.0];
    custDetails.textColor = SeconderyTextClr;
    custDetails.numberOfLines = 0;
    custDetails.textAlignment = Language.alignmentForCurrentLanguage;
    custDetails.text = [NSString stringWithFormat:@"%@: %@\n%@: %@\n%@: %@\n%@: %@",
                        isRTL ? @"الاسم" : @"Name", self.item.customerName ?: @"—",
                        isRTL ? @"الهاتف" : @"Phone", self.item.customerPhone ?: @"—",
                        isRTL ? @"الموعد" : @"Schedule", self.item.bookingDateText ?: @"—",
                        isRTL ? @"الموقع" : @"Location", self.item.locationText ?: @"—"];
    [custCard addSubview:custDetails];

    [NSLayoutConstraint activateConstraints:@[
        [custHeader.topAnchor constraintEqualToAnchor:custCard.topAnchor constant:14.0],
        [custHeader.leadingAnchor constraintEqualToAnchor:custCard.leadingAnchor constant:16.0],
        [custHeader.trailingAnchor constraintEqualToAnchor:custCard.trailingAnchor constant:-16.0],

        [custDetails.topAnchor constraintEqualToAnchor:custHeader.bottomAnchor constant:8.0],
        [custDetails.leadingAnchor constraintEqualToAnchor:custCard.leadingAnchor constant:16.0],
        [custDetails.trailingAnchor constraintEqualToAnchor:custCard.trailingAnchor constant:-16.0],
        [custDetails.bottomAnchor constraintEqualToAnchor:custCard.bottomAnchor constant:-14.0],
    ]];
    [stack addArrangedSubview:custCard];

    // Direct Call Action in sheet
    UIButton *callBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    callBtn.translatesAutoresizingMaskIntoConstraints = NO;
    callBtn.backgroundColor = [UIColor ppSuccess];
    [callBtn setTitle:isRTL ? @"📞 اتصال مباشر بالعميل" : @"📞 Call Client Directly" forState:UIControlStateNormal];
    [callBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    callBtn.titleLabel.font = [Styling fontBold:14.5];
    PPApplyContinuousCorners(callBtn, PPCornerMedium);
    [callBtn addTarget:self action:@selector(callClient) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[[callBtn.heightAnchor constraintEqualToConstant:46.0]]];
    [stack addArrangedSubview:callBtn];
}

- (UIView *)makeCard {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(v, PPCornerMedium);
    v.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    v.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    return v;
}

- (void)callClient {
    [PPFunc pp_playTapEffect];
    if (self.item.customerPhone.length > 0) {
        NSString *cleaned = [[self.item.customerPhone componentsSeparatedByCharactersInSet:
                              [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
                             componentsJoinedByString:@""];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", cleaned]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

@end

#pragma mark - Main Controller Implementation

@interface PPServiceRequestsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIView *telemetryCockpitView;
@property (nonatomic, strong) UILabel *totalRevenueLabel;
@property (nonatomic, strong) UILabel *activeBookingsCountLabel;
@property (nonatomic, strong) UISegmentedControl *laneSegment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray<PPServiceBookingItem *> *allBookings;
@property (nonatomic, strong) NSMutableArray<PPServiceBookingItem *> *filteredBookings;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyTitle;
@property (nonatomic, strong) UILabel *emptySubtitle;
@property (nonatomic, strong) UIButton *emptyActionBtn;
@property (nonatomic, assign) NSInteger selectedLaneIndex;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) id<FIRListenerRegistration> bookingsListener;
@end

@implementation PPServiceRequestsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.allBookings = [NSMutableArray array];
    self.filteredBookings = [NSMutableArray array];
    self.selectedLaneIndex = self.initialStageIndex >= 0 ? self.initialStageIndex : 0;
    self.searchQuery = @"";

    [self setupNavigation];
    [self setupTelemetryCockpit];
    [self setupSearchBar];
    [self setupTableView];
    [self setupEmptyState];
    [self startObservingBookings];
}

- (void)dealloc {
    if (self.bookingsListener) {
        [self.bookingsListener remove];
        self.bookingsListener = nil;
    }
}

- (void)setupNavigation {
    NSString *title = Language.isRTL ? @"متابعة طلبات وحجوزات الخدمة" : @"Service Pipeline & Bookings";
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

- (void)setupTelemetryCockpit {
    _telemetryCockpitView = [UIView new];
    _telemetryCockpitView.translatesAutoresizingMaskIntoConstraints = NO;
    _telemetryCockpitView.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(_telemetryCockpitView, PPCornerMedium);
    _telemetryCockpitView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _telemetryCockpitView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(_telemetryCockpitView);
    [self.view addSubview:_telemetryCockpitView];

    // Pipeline Revenue Ticker
    UILabel *revTitle = [UILabel new];
    revTitle.translatesAutoresizingMaskIntoConstraints = NO;
    revTitle.text = Language.isRTL ? @"💰 إجمالي إيرادات المسار المتوقعة" : @"💰 Total Pipeline Yield";
    revTitle.font = [Styling fontMedium:12.0];
    revTitle.textColor = SeconderyTextClr;
    revTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [_telemetryCockpitView addSubview:revTitle];

    _totalRevenueLabel = [UILabel new];
    _totalRevenueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _totalRevenueLabel.text = @"0 QAR";
    _totalRevenueLabel.font = [Styling fontBold:16.0];
    _totalRevenueLabel.textColor = [UIColor ppSuccess];
    [_telemetryCockpitView addSubview:_totalRevenueLabel];

    _activeBookingsCountLabel = [UILabel new];
    _activeBookingsCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _activeBookingsCountLabel.text = Language.isRTL ? @"4 حجوزات نشطة" : @"4 Active";
    _activeBookingsCountLabel.font = [Styling fontMedium:12.0];
    _activeBookingsCountLabel.textColor = AppPrimaryClr;
    [_telemetryCockpitView addSubview:_activeBookingsCountLabel];

    // Lane segmented controller
    NSArray *items = Language.isRTL
        ? @[@"الجديدة (0)", @"المؤكدة (0)", @"الجارية (0)", @"المكتملة"]
        : @[@"New (0)", @"Scheduled (0)", @"Active (0)", @"Done"];

    _laneSegment = [[UISegmentedControl alloc] initWithItems:items];
    _laneSegment.translatesAutoresizingMaskIntoConstraints = NO;
    _laneSegment.selectedSegmentIndex = self.selectedLaneIndex;
    _laneSegment.selectedSegmentTintColor = [UIColor ppPrimary];
    [_laneSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [Styling fontBold:12.5]} forState:UIControlStateSelected];
    [_laneSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor ppTextSecondary], NSFontAttributeName: [Styling fontMedium:12.5]} forState:UIControlStateNormal];
    [_laneSegment addTarget:self action:@selector(laneChanged:) forControlEvents:UIControlEventValueChanged];
    [_telemetryCockpitView addSubview:_laneSegment];

    [NSLayoutConstraint activateConstraints:@[
        [_telemetryCockpitView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [_telemetryCockpitView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [_telemetryCockpitView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [revTitle.topAnchor constraintEqualToAnchor:_telemetryCockpitView.topAnchor constant:12.0],
        [revTitle.leadingAnchor constraintEqualToAnchor:_telemetryCockpitView.leadingAnchor constant:14.0],

        [_totalRevenueLabel.centerYAnchor constraintEqualToAnchor:revTitle.centerYAnchor],
        [_totalRevenueLabel.trailingAnchor constraintEqualToAnchor:_telemetryCockpitView.trailingAnchor constant:-14.0],

        [_activeBookingsCountLabel.topAnchor constraintEqualToAnchor:revTitle.bottomAnchor constant:2.0],
        [_activeBookingsCountLabel.leadingAnchor constraintEqualToAnchor:revTitle.leadingAnchor],

        [_laneSegment.topAnchor constraintEqualToAnchor:_activeBookingsCountLabel.bottomAnchor constant:10.0],
        [_laneSegment.leadingAnchor constraintEqualToAnchor:_telemetryCockpitView.leadingAnchor constant:10.0],
        [_laneSegment.trailingAnchor constraintEqualToAnchor:_telemetryCockpitView.trailingAnchor constant:-10.0],
        [_laneSegment.heightAnchor constraintEqualToConstant:38.0],
        [_laneSegment.bottomAnchor constraintEqualToAnchor:_telemetryCockpitView.bottomAnchor constant:-10.0],
    ]];
}

- (void)setupSearchBar {
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = Language.isRTL ? @"بحث باسم الحيوان، السلالة، أو هاتف العميل..." : @"Search pet, breed, or phone...";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.delegate = self;
    [self.view addSubview:_searchBar];

    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:_telemetryCockpitView.bottomAnchor constant:4.0],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8.0],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [_searchBar.heightAnchor constraintEqualToConstant:44.0],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 240.0;
    _tableView.contentInset = UIEdgeInsetsMake(8, 0, 40, 0);
    [_tableView registerClass:[PPServiceBookingCardCell class] forCellReuseIdentifier:[PPServiceBookingCardCell reuseID]];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.tintColor = [UIColor ppPrimary];
    [_refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupEmptyState {
    _emptyView = [UIView new];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.hidden = YES;
    [self.view addSubview:_emptyView];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"calendar.badge.clock"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [_emptyView addSubview:icon];

    _emptyTitle = [UILabel new];
    _emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitle.text = kLang(@"Serv_Requests_Empty_Title");
    _emptyTitle.font = [Styling fontBold:16.0];
    _emptyTitle.textColor = PrimaryTextClr;
    _emptyTitle.textAlignment = NSTextAlignmentCenter;
    [_emptyView addSubview:_emptyTitle];

    _emptySubtitle = [UILabel new];
    _emptySubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitle.text = kLang(@"Serv_Requests_Empty_Subtitle");
    _emptySubtitle.font = [Styling fontRegular:13.0];
    _emptySubtitle.textColor = SeconderyTextClr;
    _emptySubtitle.textAlignment = NSTextAlignmentCenter;
    _emptySubtitle.numberOfLines = 2;
    [_emptyView addSubview:_emptySubtitle];

    _emptyActionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _emptyActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyActionBtn.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    [_emptyActionBtn setTitle:Language.isRTL ? @"مشاركة رابط الخدمات لجذب حجوزات" : @"Share Services to Get Bookings" forState:UIControlStateNormal];
    [_emptyActionBtn setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    _emptyActionBtn.titleLabel.font = [Styling fontBold:13.5];
    PPApplyContinuousCorners(_emptyActionBtn, PPCornerMedium);
    [_emptyActionBtn addTarget:self action:@selector(shareServicesTapped) forControlEvents:UIControlEventTouchUpInside];
    [_emptyView addSubview:_emptyActionBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:50.0],
        [_emptyView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [_emptyView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],

        [icon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:56.0],
        [icon.heightAnchor constraintEqualToConstant:56.0],

        [_emptyTitle.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12.0],
        [_emptyTitle.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptyTitle.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptySubtitle.topAnchor constraintEqualToAnchor:_emptyTitle.bottomAnchor constant:6.0],
        [_emptySubtitle.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptySubtitle.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptyActionBtn.topAnchor constraintEqualToAnchor:_emptySubtitle.bottomAnchor constant:16.0],
        [_emptyActionBtn.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [_emptyActionBtn.heightAnchor constraintEqualToConstant:40.0],
        [_emptyActionBtn.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor constant:20.0],
        [_emptyActionBtn.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor constant:-20.0],
        [_emptyActionBtn.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];
}

#pragma mark - Real-Time Observation

- (void)startObservingBookings {
    NSString *ownerID = [FIRAuth auth].currentUser.uid ?: @"";
    __weak typeof(self) weakSelf = self;
    self.bookingsListener = [[PPServiceManager sharedManager] observeBookingsForOwnerID:ownerID onChange:^(NSArray<PPServiceBookingItem *> * _Nullable bookings, NSError * _Nullable error) {
        if (!weakSelf) return;
        [weakSelf.refreshControl endRefreshing];
        if (bookings) {
            [weakSelf.allBookings removeAllObjects];
            [weakSelf.allBookings addObjectsFromArray:bookings];
            [weakSelf updateTelemetry];
            [weakSelf filterBookings];
        }
    }];
}

- (void)onRefresh {
    [self startObservingBookings];
}

- (void)updateTelemetry {
    NSInteger newCount = 0;
    NSInteger schedCount = 0;
    NSInteger progCount = 0;
    NSInteger doneCount = 0;
    double totalRevenue = 0.0;

    for (PPServiceBookingItem *b in self.allBookings) {
        NSString *st = b.status.lowercaseString;
        if ([st isEqualToString:@"new"]) newCount++;
        else if ([st isEqualToString:@"scheduled"]) schedCount++;
        else if ([st isEqualToString:@"in_progress"]) progCount++;
        else if ([st isEqualToString:@"completed"]) doneCount++;

        if (![st isEqualToString:@"declined"]) {
            totalRevenue += b.price;
        }
    }

    self.totalRevenueLabel.text = [NSString stringWithFormat:@"%.0f QAR", totalRevenue];
    self.activeBookingsCountLabel.text = [NSString stringWithFormat:Language.isRTL ? @"%ld حجز نشط ومكتمل" : @"%ld Active Bookings", (long)(newCount + schedCount + progCount)];

    BOOL isRTL = Language.isRTL;
    [self.laneSegment setTitle:[NSString stringWithFormat:@"%@ (%ld)", isRTL ? @"الجديدة" : @"New", (long)newCount] forSegmentAtIndex:0];
    [self.laneSegment setTitle:[NSString stringWithFormat:@"%@ (%ld)", isRTL ? @"المؤكدة" : @"Scheduled", (long)schedCount] forSegmentAtIndex:1];
    [self.laneSegment setTitle:[NSString stringWithFormat:@"%@ (%ld)", isRTL ? @"الجارية" : @"In-Prog", (long)progCount] forSegmentAtIndex:2];
    [self.laneSegment setTitle:[NSString stringWithFormat:@"%@ (%ld)", isRTL ? @"المكتملة" : @"Done", (long)doneCount] forSegmentAtIndex:3];
}

- (void)laneChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedLaneIndex = sender.selectedSegmentIndex;
    [self filterBookings];
}

- (void)filterBookings {
    [self.filteredBookings removeAllObjects];
    NSString *statusFilter = @"new";
    if (self.selectedLaneIndex == 1) statusFilter = @"scheduled";
    else if (self.selectedLaneIndex == 2) statusFilter = @"in_progress";
    else if (self.selectedLaneIndex == 3) statusFilter = @"completed";

    NSString *q = [self.searchQuery stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;

    for (PPServiceBookingItem *item in self.allBookings) {
        if ([item.status isEqualToString:statusFilter]) {
            if (self.initialServiceID.length > 0 && ![item.serviceID isEqualToString:self.initialServiceID]) {
                // Scoped filter if navigated from specific service
                continue;
            }
            if (q.length > 0) {
                BOOL matchName = [item.petName.lowercaseString containsString:q];
                BOOL matchBreed = [item.petBreed.lowercaseString containsString:q];
                BOOL matchCust = [item.customerName.lowercaseString containsString:q];
                BOOL matchPhone = [item.customerPhone containsString:q];
                BOOL matchServ = [item.serviceTitle.lowercaseString containsString:q];
                if (!matchName && !matchBreed && !matchCust && !matchPhone && !matchServ) {
                    continue;
                }
            }
            [self.filteredBookings addObject:item];
        }
    }

    self.emptyView.hidden = (self.filteredBookings.count > 0);
    [self.tableView reloadData];
}

#pragma mark - Search Bar Delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchQuery = searchText ?: @"";
    [self filterBookings];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table View DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredBookings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceBookingCardCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceBookingCardCell reuseID] forIndexPath:indexPath];
    PPServiceBookingItem *item = self.filteredBookings[indexPath.row];
    [cell configureWithItem:item];

    __weak typeof(self) weakSelf = self;
    cell.onPrimaryAction = ^(PPServiceBookingItem *target) {
        [weakSelf handlePrimaryActionForItem:target];
    };
    cell.onSecondaryAction = ^(PPServiceBookingItem *target) {
        [weakSelf handleSecondaryActionForItem:target];
    };
    cell.onCallClient = ^(PPServiceBookingItem *target) {
        [weakSelf callClientForItem:target];
    };

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [PPFunc pp_playTapEffect];
    PPServiceBookingItem *item = self.filteredBookings[indexPath.row];
    PPServiceBookingDetailSheet *sheet = [[PPServiceBookingDetailSheet alloc] initWithItem:item];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Booking Actions

- (void)handlePrimaryActionForItem:(PPServiceBookingItem *)item {
    NSString *nextStatus = @"";
    NSString *successMsg = @"";

    if ([item.status isEqualToString:@"new"]) {
        nextStatus = @"scheduled";
        successMsg = Language.isRTL ? @"تم قبول الحجز وتأكيده للعميل" : @"Booking confirmed";
    } else if ([item.status isEqualToString:@"scheduled"]) {
        nextStatus = @"in_progress";
        successMsg = Language.isRTL ? @"بدأت الجلسة بنجاح" : @"Session started";
    } else if ([item.status isEqualToString:@"in_progress"]) {
        nextStatus = @"completed";
        successMsg = Language.isRTL ? @"تم إتمام الخدمة بنجاح" : @"Service marked completed";
    }

    if (nextStatus.length > 0) {
        [[PPServiceManager sharedManager] updateBookingStatus:item.requestID status:nextStatus completion:^(NSError * _Nullable error) {
            if (error) {
                [PPHUD showError:error.localizedDescription];
            } else {
                [PPHUD showSuccess:successMsg];
            }
        }];
    }
}

- (void)handleSecondaryActionForItem:(PPServiceBookingItem *)item {
    if ([item.status isEqualToString:@"new"]) {
        // Decline confirmation
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:Language.isRTL ? @"الاعتذار عن الحجز" : @"Decline Booking"
                                                                       message:Language.isRTL ? @"هل أنت متأكد من الاعتذار عن هذا الحجز؟ سيتم إشعار العميل فوراً." : @"Are you sure you want to decline this request?"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:Language.isRTL ? @"تأكيد الاعتذار" : @"Confirm Decline"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction * _Nonnull action) {
            [[PPServiceManager sharedManager] updateBookingStatus:item.requestID status:@"declined" completion:^(NSError * _Nullable error) {
                if (error) {
                    [PPHUD showError:error.localizedDescription];
                } else {
                    [PPHUD showSuccess:Language.isRTL ? @"تم الاعتذار عن الحجز" : @"Booking declined"];
                }
            }];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self callClientForItem:item];
    }
}

- (void)callClientForItem:(PPServiceBookingItem *)item {
    if (item.customerPhone.length > 0) {
        NSString *cleaned = [[item.customerPhone componentsSeparatedByCharactersInSet:
                              [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
                             componentsJoinedByString:@""];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", cleaned]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    } else {
        [PPToast toast:Language.isRTL ? @"رقم هاتف العميل غير متوفر" : @"Phone number unavailable"
                 style:PPToastStyleWarning
                haptic:YES
              duration:2.0
              position:PPToastPositionBottom
                inView:self.view];
    }
}

- (void)shareServicesTapped {
    [PPFunc pp_playTapEffect];
    NSString *shareText = Language.isRTL
        ? @"احجز أفضل خدمات العناية والحلاقة لحيوانك الأليف عبر تطبيق PurePets!"
        : @"Book top-rated pet grooming and care on PurePets!";
    UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:@[shareText] applicationActivities:nil];
    [self presentViewController:act animated:YES completion:nil];
}

@end
