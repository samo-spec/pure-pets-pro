//
//  PPServiceScheduleViewController.m
//  PurePetsPro
//
//  SwiftyMax NextGen V10 Operating Schedule Studio & Salon Duty Matrix.
//  Weekly shift hours, booking capacity per shift, and Master Vacation Mode with persistent storage.
//

#import "PPServiceScheduleViewController.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPFunc.h"
#import "PPAlertHelper.h"

static NSString * const kScheduleMatrixKey = @"pp_provider_schedule_matrix_v1";
static NSString * const kVacationModeKey = @"pp_provider_vacation_mode_v1";

static NSString *PPServiceScheduleScopedKey(NSString *baseKey) {
    return [PPProSessionCoordinator scopedDefaultsKey:baseKey forUID:[PPProSessionCoordinator.shared activeUID]];
}

@interface PPDayScheduleItem : NSObject <NSCopying>
@property (nonatomic, copy) NSString *dayName;
@property (nonatomic, assign) BOOL isWorking;
@property (nonatomic, copy) NSString *hoursRange;
@property (nonatomic, assign) NSInteger maxBookings;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

@implementation PPDayScheduleItem

- (id)copyWithZone:(NSZone *)zone {
    PPDayScheduleItem *item = [[PPDayScheduleItem allocWithZone:zone] init];
    item.dayName = self.dayName;
    item.isWorking = self.isWorking;
    item.hoursRange = self.hoursRange;
    item.maxBookings = self.maxBookings;
    return item;
}

- (NSDictionary *)toDictionary {
    return @{
        @"dayName": self.dayName ?: @"",
        @"isWorking": @(self.isWorking),
        @"hoursRange": self.hoursRange ?: @"",
        @"maxBookings": @(self.maxBookings)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    PPDayScheduleItem *item = [PPDayScheduleItem new];
    item.dayName = dict[@"dayName"] ?: @"";
    item.isWorking = [dict[@"isWorking"] boolValue];
    item.hoursRange = dict[@"hoursRange"] ?: @"9:00 AM - 8:00 PM";
    item.maxBookings = [dict[@"maxBookings"] integerValue] > 0 ? [dict[@"maxBookings"] integerValue] : 6;
    return item;
}

@end

@interface PPServiceScheduleViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *vacationSwitch;
@property (nonatomic, strong) UILabel *vacationStatusLabel;
@property (nonatomic, strong) NSMutableArray<PPDayScheduleItem *> *scheduleDays;
@property (nonatomic, strong) UIView *vacationCard;
@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation PPServiceScheduleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self loadScheduleData];
    [self setupNavigation];
    [self setupTableView];
    [self setupFloatingSaveDock];
}

- (void)loadScheduleData {
    self.scheduleDays = [NSMutableArray array];
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:PPServiceScheduleScopedKey(kScheduleMatrixKey)];
    if ([raw isKindOfClass:[NSArray class]] && raw.count == 7) {
        for (NSDictionary *d in raw) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                [self.scheduleDays addObject:[PPDayScheduleItem fromDictionary:d]];
            }
        }
    } else {
        [self setupDefaultSchedule];
    }
}

- (void)setupDefaultSchedule {
    [self.scheduleDays removeAllObjects];
    NSArray *days = Language.isRTL
        ? @[@"الأحد", @"الإثنين", @"الثلاثاء", @"الأربعاء", @"الخميس", @"الجمعة", @"السبت"]
        : @[@"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday"];

    for (NSInteger i = 0; i < days.count; i++) {
        PPDayScheduleItem *item = [PPDayScheduleItem new];
        item.dayName = days[i];
        item.isWorking = (i != 5); // Friday off by default in Qatar
        item.hoursRange = Language.isRTL ? @"9:00 ص - 8:00 م" : @"9:00 AM - 8:00 PM";
        item.maxBookings = 6;
        [self.scheduleDays addObject:item];
    }
}

- (void)setupNavigation {
    NSString *title = kLang(@"Serv_Schedule_Title");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(12, 0, 110, 0);

    // Setup Header: Vacation Mode Card
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 140)];
    header.backgroundColor = UIColor.clearColor;

    _vacationCard = [UIView new];
    _vacationCard.translatesAutoresizingMaskIntoConstraints = NO;
    _vacationCard.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(_vacationCard, PPCornerCard);
    _vacationCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _vacationCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(_vacationCard);
    [header addSubview:_vacationCard];

    UIImageView *vacationIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"airplane.departure"]];
    vacationIcon.translatesAutoresizingMaskIntoConstraints = NO;
    vacationIcon.tintColor = [UIColor ppWarning];
    vacationIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_vacationCard addSubview:vacationIcon];

    UILabel *vacTitle = [UILabel new];
    vacTitle.translatesAutoresizingMaskIntoConstraints = NO;
    vacTitle.text = kLang(@"Serv_Vacation_Mode");
    vacTitle.font = [Styling fontBold:16.0];
    vacTitle.textColor = PrimaryTextClr;
    vacTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [_vacationCard addSubview:vacTitle];

    _vacationStatusLabel = [UILabel new];
    _vacationStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _vacationStatusLabel.text = kLang(@"Serv_Vacation_Mode_Desc");
    _vacationStatusLabel.font = [Styling fontRegular:12.0];
    _vacationStatusLabel.textColor = SeconderyTextClr;
    _vacationStatusLabel.numberOfLines = 2;
    _vacationStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_vacationCard addSubview:_vacationStatusLabel];

    BOOL isVacationOn = [[NSUserDefaults standardUserDefaults] boolForKey:PPServiceScheduleScopedKey(kVacationModeKey)];
    _vacationSwitch = [UISwitch new];
    _vacationSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _vacationSwitch.onTintColor = [UIColor ppWarning];
    _vacationSwitch.on = isVacationOn;
    [_vacationSwitch addTarget:self action:@selector(vacationToggled:) forControlEvents:UIControlEventValueChanged];
    [_vacationCard addSubview:_vacationSwitch];

    if (isVacationOn) {
        _vacationCard.layer.borderColor = [UIColor ppWarning].CGColor;
    }

    [NSLayoutConstraint activateConstraints:@[
        [_vacationCard.topAnchor constraintEqualToAnchor:header.topAnchor constant:8.0],
        [_vacationCard.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [_vacationCard.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [_vacationCard.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0],

        [vacationIcon.leadingAnchor constraintEqualToAnchor:_vacationCard.leadingAnchor constant:16.0],
        [vacationIcon.topAnchor constraintEqualToAnchor:_vacationCard.topAnchor constant:18.0],
        [vacationIcon.widthAnchor constraintEqualToConstant:24.0],
        [vacationIcon.heightAnchor constraintEqualToConstant:24.0],

        [vacTitle.centerYAnchor constraintEqualToAnchor:vacationIcon.centerYAnchor],
        [vacTitle.leadingAnchor constraintEqualToAnchor:vacationIcon.trailingAnchor constant:10.0],
        [vacTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_vacationSwitch.leadingAnchor constant:-10.0],

        [_vacationSwitch.trailingAnchor constraintEqualToAnchor:_vacationCard.trailingAnchor constant:-16.0],
        [_vacationSwitch.centerYAnchor constraintEqualToAnchor:vacationIcon.centerYAnchor],

        [_vacationStatusLabel.topAnchor constraintEqualToAnchor:vacTitle.bottomAnchor constant:8.0],
        [_vacationStatusLabel.leadingAnchor constraintEqualToAnchor:vacationIcon.leadingAnchor],
        [_vacationStatusLabel.trailingAnchor constraintEqualToAnchor:_vacationCard.trailingAnchor constant:-16.0],
    ]];

    _tableView.tableHeaderView = header;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupFloatingSaveDock {
    UIView *dock = [UIView new];
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    dock.backgroundColor = [UIColor ppSurfaceOverlay];
    [self.view addSubview:dock];

    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.backgroundColor = [UIColor ppPrimary];
    [_saveButton setTitle:Language.isRTL ? @"حفظ مصفوفة المواعيد والتوفر" : @"Save Availability Matrix" forState:UIControlStateNormal];
    [_saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:15.5];
    PPApplyContinuousCorners(_saveButton, PPCornerMedium);
    PPApplyButtonShadow(_saveButton);
    [_saveButton addTarget:self action:@selector(saveScheduleTapped) forControlEvents:UIControlEventTouchUpInside];
    [dock addSubview:_saveButton];

    [NSLayoutConstraint activateConstraints:@[
        [dock.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dock.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dock.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [dock.heightAnchor constraintEqualToConstant:94.0],

        [_saveButton.topAnchor constraintEqualToAnchor:dock.topAnchor constant:10.0],
        [_saveButton.leadingAnchor constraintEqualToAnchor:dock.leadingAnchor constant:16.0],
        [_saveButton.trailingAnchor constraintEqualToAnchor:dock.trailingAnchor constant:-16.0],
        [_saveButton.heightAnchor constraintEqualToConstant:50.0],
    ]];
}

- (void)vacationToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:PPServiceScheduleScopedKey(kVacationModeKey)];

    if (sender.isOn) {
        _vacationCard.layer.borderColor = [UIColor ppWarning].CGColor;
        [PPToast toast:Language.isRTL ? @"تم تفعيل وضع الإجازة: الحجوزات معلقة مؤقتاً" : @"Vacation Mode activated"
                 style:PPToastStyleWarning
                haptic:YES
              duration:2.0
              position:PPToastPositionBottom
                inView:self.view];
    } else {
        _vacationCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        [PPToast toast:Language.isRTL ? @"تم استئناف استقبال الحجوزات وفق الجدول" : @"Schedule resumed"
                 style:PPToastStyleSuccess
                haptic:YES
              duration:2.0
              position:PPToastPositionBottom
                inView:self.view];
    }
}

- (void)saveScheduleTapped {
    [PPFunc pp_playTapEffect];
    [PPHUD showIndeterminateIn:self.view title:Language.isRTL ? @"جارٍ حفظ الجدول..." : @"Saving Schedule..." subtitle:nil];

    // Persist schedule matrix to durable local storage
    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:self.scheduleDays.count];
    for (PPDayScheduleItem *item in self.scheduleDays) {
        [raw addObject:[item toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[raw copy] forKey:PPServiceScheduleScopedKey(kScheduleMatrixKey)];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [PPHUD dismiss];
        [PPHUD showSuccess:Language.isRTL ? @"تم تحديث جدول العمل وساعات التوفر" : @"Schedule updated successfully"];
    });
}

#pragma mark - Table View DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.scheduleDays.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"PPDayScheduleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.backgroundColor = UIColor.clearColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UIView *card = [UIView new];
        card.tag = 100;
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = [UIColor ppElevatedSurface];
        PPApplyContinuousCorners(card, PPCornerMedium);
        card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        [cell.contentView addSubview:card];

        UILabel *dayL = [UILabel new];
        dayL.tag = 101;
        dayL.translatesAutoresizingMaskIntoConstraints = NO;
        dayL.font = [Styling fontBold:15.0];
        dayL.textColor = PrimaryTextClr;
        dayL.textAlignment = Language.alignmentForCurrentLanguage;
        [card addSubview:dayL];

        UILabel *hoursL = [UILabel new];
        hoursL.tag = 102;
        hoursL.translatesAutoresizingMaskIntoConstraints = NO;
        hoursL.font = [Styling fontMedium:12.5];
        hoursL.textColor = AppPrimaryClr;
        hoursL.textAlignment = Language.alignmentForCurrentLanguage;
        [card addSubview:hoursL];

        UILabel *capL = [UILabel new];
        capL.tag = 104;
        capL.translatesAutoresizingMaskIntoConstraints = NO;
        capL.font = [Styling fontRegular:11.0];
        capL.textColor = SeconderyTextClr;
        capL.textAlignment = Language.alignmentForCurrentLanguage;
        [card addSubview:capL];

        UISwitch *sw = [UISwitch new];
        sw.tag = 103;
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        sw.onTintColor = [UIColor ppSuccess];
        [sw addTarget:self action:@selector(daySwitchToggled:) forControlEvents:UIControlEventValueChanged];
        [card addSubview:sw];

        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4.0],
            [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16.0],
            [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16.0],
            [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4.0],

            [dayL.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
            [dayL.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
            [dayL.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10.0],

            [hoursL.topAnchor constraintEqualToAnchor:dayL.bottomAnchor constant:3.0],
            [hoursL.leadingAnchor constraintEqualToAnchor:dayL.leadingAnchor],
            [hoursL.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10.0],

            [capL.topAnchor constraintEqualToAnchor:hoursL.bottomAnchor constant:2.0],
            [capL.leadingAnchor constraintEqualToAnchor:dayL.leadingAnchor],
            [capL.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],

            [sw.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
            [sw.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        ]];
    }

    PPDayScheduleItem *item = self.scheduleDays[indexPath.row];
    UIView *card = [cell.contentView viewWithTag:100];
    UILabel *dayL = (UILabel *)[card viewWithTag:101];
    UILabel *hoursL = (UILabel *)[card viewWithTag:102];
    UISwitch *sw = (UISwitch *)[card viewWithTag:103];
    UILabel *capL = (UILabel *)[card viewWithTag:104];

    dayL.text = item.dayName;
    hoursL.text = item.isWorking ? item.hoursRange : (Language.isRTL ? @"يوم عطلة مغلق" : @"Closed / Day Off");
    hoursL.textColor = item.isWorking ? AppPrimaryClr : SeconderyTextClr;
    capL.text = item.isWorking ? [NSString stringWithFormat:Language.isRTL ? @"الحد الأقصى: %ld حجوزات / وردية" : @"Max Capacity: %ld bookings / shift", (long)item.maxBookings] : @"";
    sw.on = item.isWorking;
    sw.tag = 1000 + indexPath.row;

    return cell;
}

- (void)daySwitchToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    NSInteger index = sender.tag - 1000;
    if (index >= 0 && index < (NSInteger)self.scheduleDays.count) {
        PPDayScheduleItem *item = self.scheduleDays[index];
        item.isWorking = sender.isOn;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [PPFunc pp_playTapEffect];
    PPDayScheduleItem *item = self.scheduleDays[indexPath.row];
    if (!item.isWorking) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.dayName
                                                                   message:Language.isRTL ? @"اختر ساعات العمل والوردية لهذا اليوم:" : @"Select Shift Hours:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *options = Language.isRTL ? @[
        @"8:00 ص - 4:00 م (صباحي)",
        @"9:00 ص - 8:00 م (دوام كامل)",
        @"10:00 ص - 10:00 م (مسائي ممتد)",
        @"4:00 م - 10:00 م (فترة مسائية)"
    ] : @[
        @"8:00 AM - 4:00 PM (Morning)",
        @"9:00 AM - 8:00 PM (Full Day)",
        @"10:00 AM - 10:00 PM (Extended)",
        @"4:00 PM - 10:00 PM (Evening)"
    ];

    for (NSString *opt in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:opt style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            item.hoursRange = opt;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
