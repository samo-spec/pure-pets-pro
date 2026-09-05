//
//  PPServiceTemplatePickerViewController.m
//  PurePetsPro
//
//  Curated professional starter templates for pet grooming, training, care, and boarding.
//  Enables service providers to launch high-converting offers in 5 seconds.
//

#import "PPServiceTemplatePickerViewController.h"
#import "PPServiceModel.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "PPFunc.h"

@interface PPServiceTemplateItem : NSObject
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *categoryName;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, assign) double price;
@property (nonatomic, assign) NSInteger petKindID;
@property (nonatomic, assign) PPServiceType type;
@property (nonatomic, copy) NSString *duration;
@end

@implementation PPServiceTemplateItem
@end

@interface PPServiceTemplateCardViewCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UILabel *pricePill;
@property (nonatomic, strong) UILabel *durationPill;
@property (nonatomic, strong) UIButton *useButton;
@property (nonatomic, copy, nullable) void(^onUse)(void);
@end

@implementation PPServiceTemplateCardViewCell

+ (NSString *)reuseID { return @"PPServiceTemplateCardViewCell"; }

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

    _iconView = [UIImageView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = AppPrimaryClr;
    _iconView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(_iconView, 14.0);
    [_cardView addSubview:_iconView];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:15.5];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_titleLabel];

    _categoryLabel = [UILabel new];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [Styling fontMedium:12.0];
    _categoryLabel.textColor = AppPrimaryClr;
    _categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_categoryLabel];

    _descLabel = [UILabel new];
    _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descLabel.font = [Styling fontRegular:12.5];
    _descLabel.textColor = SeconderyTextClr;
    _descLabel.numberOfLines = 3;
    _descLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_descLabel];

    _pricePill = [UILabel new];
    _pricePill.translatesAutoresizingMaskIntoConstraints = NO;
    _pricePill.font = [Styling fontBold:13.0];
    _pricePill.textColor = [UIColor ppSuccess];
    _pricePill.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    _pricePill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_pricePill, 10.0);
    _pricePill.clipsToBounds = YES;
    [_cardView addSubview:_pricePill];

    _durationPill = [UILabel new];
    _durationPill.translatesAutoresizingMaskIntoConstraints = NO;
    _durationPill.font = [Styling fontMedium:11.5];
    _durationPill.textColor = SeconderyTextClr;
    [_cardView addSubview:_durationPill];

    _useButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _useButton.translatesAutoresizingMaskIntoConstraints = NO;
    _useButton.backgroundColor = [UIColor ppPrimary];
    [_useButton setTitle:kLang(@"Serv_Use_Template") forState:UIControlStateNormal];
    [_useButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _useButton.titleLabel.font = [Styling fontBold:13.5];
    PPApplyContinuousCorners(_useButton, PPCornerMedium);
    [_useButton addTarget:self action:@selector(useTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_useButton];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_iconView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
        [_iconView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_iconView.widthAnchor constraintEqualToConstant:48.0],
        [_iconView.heightAnchor constraintEqualToConstant:48.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_pricePill.leadingAnchor constant:-8.0],

        [_categoryLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2.0],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],

        [_pricePill.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_pricePill.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_pricePill.heightAnchor constraintEqualToConstant:24.0],

        [_descLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:10.0],
        [_descLabel.leadingAnchor constraintEqualToAnchor:_iconView.leadingAnchor],
        [_descLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],

        [_durationPill.leadingAnchor constraintEqualToAnchor:_descLabel.leadingAnchor],
        [_durationPill.centerYAnchor constraintEqualToAnchor:_useButton.centerYAnchor],

        [_useButton.topAnchor constraintEqualToAnchor:_descLabel.bottomAnchor constant:12.0],
        [_useButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
        [_useButton.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-14.0],
        [_useButton.heightAnchor constraintEqualToConstant:36.0],
        [_useButton.widthAnchor constraintEqualToConstant:140.0],
    ]];
}

- (void)configureWithTemplate:(PPServiceTemplateItem *)item {
    _titleLabel.text = item.title;
    _categoryLabel.text = item.categoryName;
    _descLabel.text = item.desc;
    _pricePill.text = [NSString stringWithFormat:@"  %.0f QAR  ", item.price];
    _durationPill.text = [NSString stringWithFormat:@"⏱️ %@", item.duration];
    _iconView.image = [UIImage systemImageNamed:item.iconName
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold]];
}

- (void)useTapped {
    [PPFunc pp_playTapEffect];
    if (self.onUse) {
        self.onUse();
    }
}

@end

#pragma mark - Controller

@interface PPServiceTemplatePickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PPServiceTemplateItem *> *templates;
@end

@implementation PPServiceTemplatePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self setupTemplatesData];
    [self setupUI];
}

- (void)setupTemplatesData {
    self.templates = [NSMutableArray array];

    PPServiceTemplateItem *t1 = [PPServiceTemplateItem new];
    t1.iconName = @"scissors";
    t1.title = kLang(@"Serv_Template_Grooming_Title");
    t1.categoryName = Language.isRTL ? @"حلاقة وعناية" : @"Grooming & Bath";
    t1.desc = kLang(@"Serv_Template_Grooming_Desc");
    t1.price = 150.0;
    t1.petKindID = 1;
    t1.type = PPServiceTypeGrooming;
    t1.duration = Language.isRTL ? @"45 دقيقة" : @"45 min";
    [self.templates addObject:t1];

    PPServiceTemplateItem *t2 = [PPServiceTemplateItem new];
    t2.iconName = @"figure.walk";
    t2.title = kLang(@"Serv_Template_Training_Title");
    t2.categoryName = Language.isRTL ? @"تدريب وتأهيل" : @"Obedience & Training";
    t2.desc = kLang(@"Serv_Template_Training_Desc");
    t2.price = 250.0;
    t2.petKindID = 1;
    t2.type = PPServiceTypeTraining;
    t2.duration = Language.isRTL ? @"60 دقيقة" : @"60 min";
    [self.templates addObject:t2];

    PPServiceTemplateItem *t3 = [PPServiceTemplateItem new];
    t3.iconName = @"heart.text.square.fill";
    t3.title = kLang(@"Serv_Template_Bath_Title");
    t3.categoryName = Language.isRTL ? @"استحمام طبي وعناية" : @"Medicated Care";
    t3.desc = kLang(@"Serv_Template_Bath_Desc");
    t3.price = 120.0;
    t3.petKindID = 2;
    t3.type = PPServiceTypeGrooming;
    t3.duration = Language.isRTL ? @"40 دقيقة" : @"40 min";
    [self.templates addObject:t3];

    PPServiceTemplateItem *t4 = [PPServiceTemplateItem new];
    t4.iconName = @"house.fill";
    t4.title = kLang(@"Serv_Template_Boarding_Title");
    t4.categoryName = Language.isRTL ? @"فندقة واستضافة" : @"Pet Hotel & Boarding";
    t4.desc = kLang(@"Serv_Template_Boarding_Desc");
    t4.price = 180.0;
    t4.petKindID = 1;
    t4.type = PPServiceTypeGrooming;
    t4.duration = Language.isRTL ? @"يوم كامل (24 ساعة)" : @"Full Day (24 hrs)";
    [self.templates addObject:t4];
}

- (void)setupUI {
    UIView *grabber = [UIView new];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor ppSeparator];
    grabber.layer.cornerRadius = 2.5;
    [self.view addSubview:grabber];

    UILabel *headerTitle = [UILabel new];
    headerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    headerTitle.text = kLang(@"Serv_Template_Picker_Title");
    headerTitle.font = [Styling fontBold:18.0];
    headerTitle.textColor = PrimaryTextClr;
    headerTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:headerTitle];

    UILabel *headerSub = [UILabel new];
    headerSub.translatesAutoresizingMaskIntoConstraints = NO;
    headerSub.text = kLang(@"Serv_Template_Picker_Subtitle");
    headerSub.font = [Styling fontRegular:12.5];
    headerSub.textColor = SeconderyTextClr;
    headerSub.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:headerSub];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(8, 0, 40, 0);
    [_tableView registerClass:[PPServiceTemplateCardViewCell class] forCellReuseIdentifier:[PPServiceTemplateCardViewCell reuseID]];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10.0],
        [grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:40.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],

        [headerTitle.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:16.0],
        [headerTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [headerTitle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],

        [headerSub.topAnchor constraintEqualToAnchor:headerTitle.bottomAnchor constant:4.0],
        [headerSub.leadingAnchor constraintEqualToAnchor:headerTitle.leadingAnchor],
        [headerSub.trailingAnchor constraintEqualToAnchor:headerTitle.trailingAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:headerSub.bottomAnchor constant:12.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.templates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceTemplateCardViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceTemplateCardViewCell reuseID] forIndexPath:indexPath];
    PPServiceTemplateItem *item = self.templates[indexPath.row];
    [cell configureWithTemplate:item];

    __weak typeof(self) weakSelf = self;
    cell.onUse = ^{
        [weakSelf selectTemplate:item];
    };
    return cell;
}

- (void)selectTemplate:(PPServiceTemplateItem *)item {
    PPServiceModel *model = [[PPServiceModel alloc] init];
    model.title = item.title;
    model.category = item.categoryName;
    model.descriptionText = item.desc;
    model.price = item.price;
    model.currency = @"QAR";
    model.petMainKindID = item.petKindID;
    model.type = item.type;
    model.isAvailable = YES;

    if (self.onSelectTemplate) {
        self.onSelectTemplate(model);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
