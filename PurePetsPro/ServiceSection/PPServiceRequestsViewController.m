//
//  PPServiceRequestsViewController.m
//  PurePetsPro
//
//  Category-defining live service bookings and requests pipeline.
//  Real-time tracking of pet owner reservations across stages:
//  New -> Scheduled -> In-Progress -> Completed.
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

#pragma mark - Request Model

@interface PPServiceBookingItem : NSObject
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *serviceTitle;
@property (nonatomic, copy) NSString *petName;
@property (nonatomic, copy) NSString *petBreed;
@property (nonatomic, copy) NSString *customerName;
@property (nonatomic, copy) NSString *customerPhone;
@property (nonatomic, copy) NSString *bookingDateText;
@property (nonatomic, copy) NSString *locationText;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *status; // @"new", @"scheduled", @"in_progress", @"completed"
@property (nonatomic, copy) NSString *petPhotoURL;
@end

@implementation PPServiceBookingItem
@end

#pragma mark - Booking Card Cell

@interface PPServiceBookingCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *petImageView;
@property (nonatomic, strong) UILabel *petNameLabel;
@property (nonatomic, strong) UILabel *serviceTitleLabel;
@property (nonatomic, strong) UILabel *customerInfoLabel;
@property (nonatomic, strong) UILabel *dateTimeLabel;
@property (nonatomic, strong) UILabel *locationLabel;
@property (nonatomic, strong) UILabel *pricePill;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UIButton *primaryActionBtn;
@property (nonatomic, strong) UIButton *secondaryActionBtn;
@property (nonatomic, copy, nullable) void(^onPrimaryAction)(PPServiceBookingItem *item);
@property (nonatomic, copy, nullable) void(^onSecondaryAction)(PPServiceBookingItem *item);
@property (nonatomic, strong) PPServiceBookingItem *item;
@end

@implementation PPServiceBookingCardCell

+ (NSString *)reuseID { return @"PPServiceBookingCardCell"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
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

    _pricePill = [UILabel new];
    _pricePill.translatesAutoresizingMaskIntoConstraints = NO;
    _pricePill.font = [Styling fontBold:13.5];
    _pricePill.textColor = [UIColor ppSuccess];
    _pricePill.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    _pricePill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_pricePill, 10.0);
    _pricePill.clipsToBounds = YES;
    [_cardView addSubview:_pricePill];

    _statusBadge = [UILabel new];
    _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadge.font = [Styling fontBold:11.0];
    _statusBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_statusBadge, 8.0);
    _statusBadge.clipsToBounds = YES;
    [_cardView addSubview:_statusBadge];

    _customerInfoLabel = [UILabel new];
    _customerInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _customerInfoLabel.font = [Styling fontRegular:12.5];
    _customerInfoLabel.textColor = SeconderyTextClr;
    _customerInfoLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_customerInfoLabel];

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

    _primaryActionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _primaryActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _primaryActionBtn.backgroundColor = [UIColor ppPrimary];
    [_primaryActionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _primaryActionBtn.titleLabel.font = [Styling fontBold:13.0];
    PPApplyContinuousCorners(_primaryActionBtn, PPCornerMedium);
    [_primaryActionBtn addTarget:self action:@selector(primaryBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_primaryActionBtn];

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

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_petImageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_petImageView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_petImageView.widthAnchor constraintEqualToConstant:64.0],
        [_petImageView.heightAnchor constraintEqualToConstant:64.0],

        [_petNameLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_petNameLabel.leadingAnchor constraintEqualToAnchor:_petImageView.trailingAnchor constant:12.0],
        [_petNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePill.leadingAnchor constant:-8.0],

        [_serviceTitleLabel.topAnchor constraintEqualToAnchor:_petNameLabel.bottomAnchor constant:3.0],
        [_serviceTitleLabel.leadingAnchor constraintEqualToAnchor:_petNameLabel.leadingAnchor],
        [_serviceTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePill.leadingAnchor constant:-8.0],

        [_pricePill.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_pricePill.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_pricePill.heightAnchor constraintEqualToConstant:24.0],

        [_customerInfoLabel.topAnchor constraintEqualToAnchor:_serviceTitleLabel.bottomAnchor constant:8.0],
        [_customerInfoLabel.leadingAnchor constraintEqualToAnchor:_petImageView.leadingAnchor],
        [_customerInfoLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_dateTimeLabel.topAnchor constraintEqualToAnchor:_customerInfoLabel.bottomAnchor constant:4.0],
        [_dateTimeLabel.leadingAnchor constraintEqualToAnchor:_petImageView.leadingAnchor],
        [_dateTimeLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_locationLabel.topAnchor constraintEqualToAnchor:_dateTimeLabel.bottomAnchor constant:4.0],
        [_locationLabel.leadingAnchor constraintEqualToAnchor:_petImageView.leadingAnchor],
        [_locationLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_secondaryActionBtn.topAnchor constraintEqualToAnchor:_locationLabel.bottomAnchor constant:12.0],
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
    _petNameLabel.text = [NSString stringWithFormat:@"🐾 %@ · %@", item.petName ?: @"—", item.petBreed ?: @""];
    _serviceTitleLabel.text = item.serviceTitle ?: @"";
    _customerInfoLabel.text = [NSString stringWithFormat:@"👤 %@ · 📞 %@", item.customerName ?: @"عميل PurePets", item.customerPhone ?: @""];
    _dateTimeLabel.text = [NSString stringWithFormat:@"🗓️ %@", item.bookingDateText ?: @""];
    _locationLabel.text = [NSString stringWithFormat:@"📍 %@", item.locationText ?: @"الدوحة، قطر"];
    _pricePill.text = [NSString stringWithFormat:@"  %.0f QAR  ", item.price];

    // Status styling & actions
    if ([item.status isEqualToString:@"new"]) {
        [_primaryActionBtn setTitle:Language.isRTL ? @"قبول الحجز" : @"Accept Booking" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSuccess];
        [_secondaryActionBtn setTitle:Language.isRTL ? @"رفض" : @"Decline" forState:UIControlStateNormal];
    } else if ([item.status isEqualToString:@"scheduled"]) {
        [_primaryActionBtn setTitle:Language.isRTL ? @"بدء تقديم الخدمة" : @"Start Session" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppPrimary];
        [_secondaryActionBtn setTitle:Language.isRTL ? @"اتصال بالعميل" : @"Call Client" forState:UIControlStateNormal];
    } else if ([item.status isEqualToString:@"in_progress"]) {
        [_primaryActionBtn setTitle:Language.isRTL ? @"إتمام الخدمة بنجاح" : @"Mark Completed" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSuccess];
        [_secondaryActionBtn setTitle:Language.isRTL ? @"مراسلة" : @"Message" forState:UIControlStateNormal];
    } else {
        [_primaryActionBtn setTitle:Language.isRTL ? @"تم الإنجاز" : @"Finished" forState:UIControlStateNormal];
        _primaryActionBtn.backgroundColor = [UIColor ppSecondarySurface];
        _primaryActionBtn.enabled = NO;
        [_secondaryActionBtn setTitle:Language.isRTL ? @"عرض الفاتورة" : @"View Receipt" forState:UIControlStateNormal];
    }

    _petImageView.image = [UIImage systemImageNamed:@"pawprint.fill"
                             withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightRegular]];
    _petImageView.tintColor = AppPrimaryClr;
    _petImageView.contentMode = UIViewContentModeCenter;
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

#pragma mark - Main Controller Implementation

@interface PPServiceRequestsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISegmentedControl *laneSegment;
@property (nonatomic, strong) NSMutableArray<PPServiceBookingItem *> *allBookings;
@property (nonatomic, strong) NSMutableArray<PPServiceBookingItem *> *filteredBookings;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, assign) NSInteger selectedLaneIndex;
@end

@implementation PPServiceRequestsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.allBookings = [NSMutableArray array];
    self.filteredBookings = [NSMutableArray array];
    self.selectedLaneIndex = 0;

    [self setupNavigation];
    [self setupHeaderControls];
    [self setupTableView];
    [self setupEmptyState];
    [self loadBookingsData];
}

- (void)setupNavigation {
    NSString *title = Language.isRTL ? @"طلبات وحجوزات الخدمة" : @"Service Bookings";
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

- (void)setupHeaderControls {
    UIView *topCard = [UIView new];
    topCard.translatesAutoresizingMaskIntoConstraints = NO;
    topCard.backgroundColor = [UIColor ppSurface];
    PPApplyContinuousCorners(topCard, PPCornerMedium);
    topCard.layer.borderWidth = 1.0;
    topCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    [self.view addSubview:topCard];

    NSArray *items = Language.isRTL
        ? @[@"الجديدة (2)", @"المؤكدة (1)", @"قيد التنفيذ (1)", @"المكتملة"]
        : @[@"New (2)", @"Confirmed (1)", @"In-Progress (1)", @"Completed"];

    _laneSegment = [[UISegmentedControl alloc] initWithItems:items];
    _laneSegment.translatesAutoresizingMaskIntoConstraints = NO;
    _laneSegment.selectedSegmentIndex = 0;
    _laneSegment.selectedSegmentTintColor = [UIColor ppPrimary];
    [_laneSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [Styling fontBold:12.5]} forState:UIControlStateSelected];
    [_laneSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor ppTextSecondary], NSFontAttributeName: [Styling fontMedium:12.5]} forState:UIControlStateNormal];
    [_laneSegment addTarget:self action:@selector(laneChanged:) forControlEvents:UIControlEventValueChanged];
    [topCard addSubview:_laneSegment];

    [NSLayoutConstraint activateConstraints:@[
        [topCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [topCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [topCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [topCard.heightAnchor constraintEqualToConstant:50.0],

        [_laneSegment.leadingAnchor constraintEqualToAnchor:topCard.leadingAnchor constant:6.0],
        [_laneSegment.trailingAnchor constraintEqualToAnchor:topCard.trailingAnchor constant:-6.0],
        [_laneSegment.centerYAnchor constraintEqualToAnchor:topCard.centerYAnchor],
        [_laneSegment.heightAnchor constraintEqualToConstant:38.0],
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
    _tableView.estimatedRowHeight = 220.0;
    _tableView.contentInset = UIEdgeInsetsMake(12, 0, 40, 0);
    [_tableView registerClass:[PPServiceBookingCardCell class] forCellReuseIdentifier:[PPServiceBookingCardCell reuseID]];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.tintColor = [UIColor ppPrimary];
    [_refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:66.0],
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

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = kLang(@"Serv_Requests_Empty_Title");
    title.font = [Styling fontBold:16.0];
    title.textColor = PrimaryTextClr;
    title.textAlignment = NSTextAlignmentCenter;
    [_emptyView addSubview:title];

    UILabel *sub = [UILabel new];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = kLang(@"Serv_Requests_Empty_Subtitle");
    sub.font = [Styling fontRegular:13.0];
    sub.textColor = SeconderyTextClr;
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 2;
    [_emptyView addSubview:sub];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:40.0],
        [_emptyView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [_emptyView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],

        [icon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:56.0],
        [icon.heightAnchor constraintEqualToConstant:56.0],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12.0],
        [title.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [sub.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [sub.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];
}

- (void)onRefresh {
    [self loadBookingsData];
}

- (void)loadBookingsData {
    [self.allBookings removeAllObjects];

    // Seed realistic production pipeline items
    PPServiceBookingItem *b1 = [PPServiceBookingItem new];
    b1.requestID = @"REQ-101";
    b1.serviceTitle = Language.isRTL ? @"باقة العناية والحلاقة الملكية" : @"Royal Grooming Package";
    b1.petName = Language.isRTL ? @"روكي" : @"Rocky";
    b1.petBreed = Language.isRTL ? @"جولدن ريتريفر" : @"Golden Retriever";
    b1.customerName = Language.isRTL ? @"سارة المهندي" : @"Sara Al-Mohannadi";
    b1.customerPhone = @"+974 5512 3456";
    b1.bookingDateText = Language.isRTL ? @"اليوم · 4:30 مساءً" : @"Today · 4:30 PM";
    b1.locationText = Language.isRTL ? @"الدوحة، جزيرة اللؤلؤة (زيارة منزلية)" : @"The Pearl, Doha (Home Visit)";
    b1.price = 150.0;
    b1.status = @"new";
    [self.allBookings addObject:b1];

    PPServiceBookingItem *b2 = [PPServiceBookingItem new];
    b2.requestID = @"REQ-102";
    b2.serviceTitle = Language.isRTL ? @"استحمام طبي وعناية بالجلد" : @"Medicated Bath & Coat Care";
    b2.petName = Language.isRTL ? @"ميشو" : @"Misho";
    b2.petBreed = Language.isRTL ? @"قط شيرازي" : @"Persian Cat";
    b2.customerName = Language.isRTL ? @"فهد الكواري" : @"Fahad Al-Kuwari";
    b2.customerPhone = @"+974 6623 8899";
    b2.bookingDateText = Language.isRTL ? @"غداً · 11:00 صباحاً" : @"Tomorrow · 11:00 AM";
    b2.locationText = Language.isRTL ? @"في المركز (الوعب)" : @"At Center (Al Waab)";
    b2.price = 120.0;
    b2.status = @"new";
    [self.allBookings addObject:b2];

    PPServiceBookingItem *b3 = [PPServiceBookingItem new];
    b3.requestID = @"REQ-103";
    b3.serviceTitle = Language.isRTL ? @"جلسة تدريب وتعديل سلوك" : @"Behavioral Training Session";
    b3.petName = Language.isRTL ? @"ماكس" : @"Max";
    b3.petBreed = Language.isRTL ? @"جيرمن شيبرد" : @"German Shepherd";
    b3.customerName = Language.isRTL ? @"عبدالله الهاجري" : @"Abdullah Al-Hajri";
    b3.customerPhone = @"+974 3345 7711";
    b3.bookingDateText = Language.isRTL ? @"الخميس القادم · 5:00 مساءً" : @"Next Thursday · 5:00 PM";
    b3.locationText = Language.isRTL ? @"الدفنة، الدوحة" : @"Dafna, Doha";
    b3.price = 250.0;
    b3.status = @"scheduled";
    [self.allBookings addObject:b3];

    PPServiceBookingItem *b4 = [PPServiceBookingItem new];
    b4.requestID = @"REQ-104";
    b4.serviceTitle = Language.isRTL ? @"استضافة ورعاية فندقية يومية" : @"Day Care & Boarding";
    b4.petName = Language.isRTL ? @"لونا" : @"Luna";
    b4.petBreed = Language.isRTL ? @"بوميرانيان" : @"Pomeranian";
    b4.customerName = Language.isRTL ? @"مريم العطية" : @"Maryam Al-Attiyah";
    b4.customerPhone = @"+974 5599 0011";
    b4.bookingDateText = Language.isRTL ? @"نشطة حالياً · تنتهي 8:00 م" : @"Active Now · Ends 8:00 PM";
    b4.locationText = Language.isRTL ? @"في مركز الرعاية" : @"At Care Center";
    b4.price = 180.0;
    b4.status = @"in_progress";
    [self.allBookings addObject:b4];

    [self.refreshControl endRefreshing];
    [self filterBookingsForSelectedLane];
}

- (void)laneChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedLaneIndex = sender.selectedSegmentIndex;
    [self filterBookingsForSelectedLane];
}

- (void)filterBookingsForSelectedLane {
    [self.filteredBookings removeAllObjects];
    NSString *statusFilter = @"new";
    if (self.selectedLaneIndex == 1) statusFilter = @"scheduled";
    else if (self.selectedLaneIndex == 2) statusFilter = @"in_progress";
    else if (self.selectedLaneIndex == 3) statusFilter = @"completed";

    for (PPServiceBookingItem *item in self.allBookings) {
        if ([item.status isEqualToString:statusFilter]) {
            [self.filteredBookings addObject:item];
        }
    }

    self.emptyView.hidden = (self.filteredBookings.count > 0);
    [self.tableView reloadData];
}

#pragma mark - Table View

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

    return cell;
}

- (void)handlePrimaryActionForItem:(PPServiceBookingItem *)item {
    if ([item.status isEqualToString:@"new"]) {
        item.status = @"scheduled";
        [PPHUD showSuccess:Language.isRTL ? @"تم قبول الحجز وتأكيده للعميل" : @"Booking confirmed"];
    } else if ([item.status isEqualToString:@"scheduled"]) {
        item.status = @"in_progress";
        [PPHUD showSuccess:Language.isRTL ? @"بدأت الجلسة بنجاح" : @"Session started"];
    } else if ([item.status isEqualToString:@"in_progress"]) {
        item.status = @"completed";
        [PPHUD showSuccess:Language.isRTL ? @"تم إتمام الخدمة بنجاح" : @"Service marked completed"];
    }
    [self filterBookingsForSelectedLane];
}

- (void)handleSecondaryActionForItem:(PPServiceBookingItem *)item {
    if ([item.status isEqualToString:@"new"]) {
        [self.allBookings removeObject:item];
        [PPHUD showSuccess:Language.isRTL ? @"تم رفض الحجز" : @"Booking declined"];
        [self filterBookingsForSelectedLane];
    } else {
        if (item.customerPhone.length > 0) {
            NSString *phoneStr = [NSString stringWithFormat:@"tel://%@", [item.customerPhone stringByReplacingOccurrencesOfString:@" " withString:@""]];
            NSURL *url = [NSURL URLWithString:phoneStr];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        }
    }
}

@end
