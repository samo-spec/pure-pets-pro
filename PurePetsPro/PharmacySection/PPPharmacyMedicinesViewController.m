#import "PPPharmacyMedicinesViewController.h"
#import "PPPharmacyMedicineEditorViewController.h"
#import "PPVetManager.h"
#import "PPFirebaseCompat.h"

#pragma mark - Stat Card

@interface _Pharma_PPStatCard : UIView
@property (nonatomic, strong) UILabel *Pharma_countLabel;
@property (nonatomic, strong) UILabel *Pharma_titleLabel;
- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title color:(UIColor *)color;
- (void)updateCount:(NSInteger)count;
@end

@implementation _Pharma_PPStatCard

- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title color:(UIColor *)color {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.backgroundColor = UIColor.clearColor;
        self.layer.shadowColor = AppShadowColor.CGColor;
        self.layer.shadowOpacity = 0.06;
        self.layer.shadowOffset = CGSizeMake(0, 10);
        self.layer.shadowRadius = 18.0;

        UIView *surfaceView = [[UIView alloc] init];
        surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        surfaceView.backgroundColor = AppForgroundColr;
        surfaceView.clipsToBounds = YES;
        surfaceView.layer.cornerRadius = 24.0;
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        surfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        [self addSubview:surfaceView];

        UIView *toneHalo = [[UIView alloc] init];
        toneHalo.translatesAutoresizingMaskIntoConstraints = NO;
        toneHalo.backgroundColor = [color colorWithAlphaComponent:0.11];
        toneHalo.layer.cornerRadius = 42.0;
        [surfaceView addSubview:toneHalo];

        UIView *iconWrap = [[UIView alloc] init];
        iconWrap.translatesAutoresizingMaskIntoConstraints = NO;
        iconWrap.backgroundColor = [color colorWithAlphaComponent:0.10];
        iconWrap.layer.cornerRadius = 16.0;
        iconWrap.layer.cornerCurve = kCACornerCurveContinuous;
        [surfaceView addSubview:iconWrap];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = color;
        UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
        iconView.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:iconConfig];
        [iconWrap addSubview:iconView];

        UIView *accentDot = [[UIView alloc] init];
        accentDot.translatesAutoresizingMaskIntoConstraints = NO;
        accentDot.backgroundColor = color;
        accentDot.layer.cornerRadius = 3.0;
        [surfaceView addSubview:accentDot];

        _Pharma_titleLabel = [[UILabel alloc] init];
        _Pharma_titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _Pharma_titleLabel.font = [Styling fontMedium:11.0];
        _Pharma_titleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.88];
        _Pharma_titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _Pharma_titleLabel.text = title;
        _Pharma_titleLabel.numberOfLines = 2;
        [surfaceView addSubview:_Pharma_titleLabel];

        _Pharma_countLabel = [[UILabel alloc] init];
        _Pharma_countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _Pharma_countLabel.font = [Styling fontBold:28.0];
        _Pharma_countLabel.textColor = PrimaryTextClr;
        _Pharma_countLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _Pharma_countLabel.text = @"0";
        [surfaceView addSubview:_Pharma_countLabel];

        [NSLayoutConstraint activateConstraints:@[
            [surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [toneHalo.widthAnchor constraintEqualToConstant:84.0],
            [toneHalo.heightAnchor constraintEqualToConstant:84.0],
            [toneHalo.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:-28.0],
            [toneHalo.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:18.0],

            [iconWrap.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:14.0],
            [iconWrap.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:14.0],
            [iconWrap.widthAnchor constraintEqualToConstant:32.0],
            [iconWrap.heightAnchor constraintEqualToConstant:32.0],

            [iconView.centerXAnchor constraintEqualToAnchor:iconWrap.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:14.0],
            [iconView.heightAnchor constraintEqualToConstant:14.0],

            [accentDot.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
            [accentDot.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],
            [accentDot.widthAnchor constraintEqualToConstant:6.0],
            [accentDot.heightAnchor constraintEqualToConstant:6.0],

            [_Pharma_titleLabel.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],
            [_Pharma_titleLabel.leadingAnchor constraintEqualToAnchor:iconWrap.trailingAnchor constant:10.0],
            [_Pharma_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:accentDot.leadingAnchor constant:-10.0],

            [_Pharma_countLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:14.0],
            [_Pharma_countLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-14.0],
            [_Pharma_countLabel.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-12.0],
            [_Pharma_countLabel.topAnchor constraintGreaterThanOrEqualToAnchor:_Pharma_titleLabel.bottomAnchor constant:10.0],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:24.0];
    self.layer.shadowPath = shadowPath.CGPath;
}

- (void)updateCount:(NSInteger)count {
    NSString *nextValue = [NSString stringWithFormat:@"%ld", (long)count];
    if ([self.Pharma_countLabel.text isEqualToString:nextValue]) return;
    [UIView transitionWithView:self.Pharma_countLabel duration:0.22 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.Pharma_countLabel.text = nextValue;
    } completion:nil];
}

@end

@interface PPPharmacyMedicineCell : UITableViewCell
- (void)configureWithMedicine:(PPVetMedicineModel *)medicine;
@end

@implementation PPPharmacyMedicineCell {
    UIView *_cardView;
    UIView *_imageShell;
    UIImageView *_medicineImageView;
    UILabel *_titleLabel;
    UILabel *_categoryLabel;
    UILabel *_descriptionLabel;
    UILabel *_animalTypesLabel;
    UILabel *_stockLabel;
    UILabel *_priceLabel;
    UILabel *_statusBadgeLabel;
    UILabel *_availabilityBadgeLabel;
    UIImageView *_chevronView;
    BOOL _isDisabledMedicine;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        _cardView = [[UIView alloc] init];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.backgroundColor = AppForgroundColr;
        _cardView.layer.cornerRadius = 22.0;
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
        _cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _cardView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
        _cardView.layer.shadowColor = AppShadowColor.CGColor;
        _cardView.layer.shadowOpacity = 0.045;
        _cardView.layer.shadowOffset = CGSizeMake(0, 8.0);
        _cardView.layer.shadowRadius = 16.0;
        [self.contentView addSubview:_cardView];

        _imageShell = [[UIView alloc] init];
        _imageShell.translatesAutoresizingMaskIntoConstraints = NO;
        _imageShell.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.065];
        _imageShell.layer.cornerRadius = 18.0;
        _imageShell.layer.cornerCurve = kCACornerCurveContinuous;
        _imageShell.clipsToBounds = YES;
        [_cardView addSubview:_imageShell];

        _medicineImageView = [[UIImageView alloc] init];
        _medicineImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
        _medicineImageView.clipsToBounds = YES;
        _medicineImageView.layer.cornerRadius = 16.0;
        _medicineImageView.layer.cornerCurve = kCACornerCurveContinuous;
        _medicineImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
        [_imageShell addSubview:_medicineImageView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontBold:16.5];
        _titleLabel.textColor = PrimaryTextClr;
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _titleLabel.numberOfLines = 2;
        [_cardView addSubview:_titleLabel];

        _categoryLabel = [[UILabel alloc] init];
        _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _categoryLabel.font = [Styling fontMedium:11.0];
        _categoryLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.78];
        _categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cardView addSubview:_categoryLabel];

        _descriptionLabel = [[UILabel alloc] init];
        _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _descriptionLabel.font = [Styling fontMedium:12.5];
        _descriptionLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.76];
        _descriptionLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _descriptionLabel.numberOfLines = 2;
        [_cardView addSubview:_descriptionLabel];

        _animalTypesLabel = [[UILabel alloc] init];
        _animalTypesLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _animalTypesLabel.font = [Styling fontMedium:11.0];
        _animalTypesLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.68];
        _animalTypesLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _animalTypesLabel.numberOfLines = 1;
        [_cardView addSubview:_animalTypesLabel];

        _stockLabel = [[UILabel alloc] init];
        _stockLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _stockLabel.font = [Styling fontMedium:11.5];
        _stockLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.72];
        _stockLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cardView addSubview:_stockLabel];

        _priceLabel = [[UILabel alloc] init];
        _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _priceLabel.font = [Styling fontBold:15.5];
        _priceLabel.textColor = PrimaryTextClr;
        _priceLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cardView addSubview:_priceLabel];

        _statusBadgeLabel = [[UILabel alloc] init];
        _statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadgeLabel.font = [Styling fontBold:10.0];
        _statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _statusBadgeLabel.layer.cornerRadius = 10.0;
        _statusBadgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
        _statusBadgeLabel.clipsToBounds = YES;
        [_cardView addSubview:_statusBadgeLabel];

        _availabilityBadgeLabel = [[UILabel alloc] init];
        _availabilityBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _availabilityBadgeLabel.font = [Styling fontBold:10.0];
        _availabilityBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _availabilityBadgeLabel.layer.cornerRadius = 10.0;
        _availabilityBadgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
        _availabilityBadgeLabel.clipsToBounds = YES;
        [_cardView addSubview:_availabilityBadgeLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold]]];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.28];
        [_cardView addSubview:_chevronView];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],

            [_imageShell.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:18.0],
            [_imageShell.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:18.0],
            [_imageShell.widthAnchor constraintEqualToConstant:76.0],
            [_imageShell.heightAnchor constraintEqualToConstant:76.0],

            [_medicineImageView.topAnchor constraintEqualToAnchor:_imageShell.topAnchor constant:4.0],
            [_medicineImageView.leadingAnchor constraintEqualToAnchor:_imageShell.leadingAnchor constant:4.0],
            [_medicineImageView.trailingAnchor constraintEqualToAnchor:_imageShell.trailingAnchor constant:-4.0],
            [_medicineImageView.bottomAnchor constraintEqualToAnchor:_imageShell.bottomAnchor constant:-4.0],

            [_categoryLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:17.0],
            [_categoryLabel.leadingAnchor constraintEqualToAnchor:_imageShell.trailingAnchor constant:16.0],
            [_categoryLabel.heightAnchor constraintEqualToConstant:18.0],
            [_categoryLabel.widthAnchor constraintGreaterThanOrEqualToConstant:42.0],
            [_categoryLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_statusBadgeLabel.leadingAnchor constant:-8.0],

            [_statusBadgeLabel.centerYAnchor constraintEqualToAnchor:_categoryLabel.centerYAnchor],
            [_statusBadgeLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-18.0],
            [_statusBadgeLabel.heightAnchor constraintEqualToConstant:20.0],
            [_statusBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:52.0],

            [_titleLabel.topAnchor constraintEqualToAnchor:_categoryLabel.bottomAnchor constant:7.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_categoryLabel.leadingAnchor],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_statusBadgeLabel.trailingAnchor],

            [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
            [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

            [_animalTypesLabel.topAnchor constraintEqualToAnchor:_descriptionLabel.bottomAnchor constant:8.0],
            [_animalTypesLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_animalTypesLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_availabilityBadgeLabel.leadingAnchor constant:-8.0],
            [_animalTypesLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-16.0],

            [_availabilityBadgeLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_availabilityBadgeLabel.heightAnchor constraintEqualToConstant:20.0],
            [_availabilityBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:84.0],

            [_stockLabel.topAnchor constraintEqualToAnchor:_imageShell.bottomAnchor constant:12.0],
            [_stockLabel.leadingAnchor constraintEqualToAnchor:_imageShell.leadingAnchor],
            [_stockLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_priceLabel.leadingAnchor constant:-10.0],
            [_stockLabel.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16.0],
            
          


            [_priceLabel.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16.0],
            [_priceLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],

            [_chevronView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16.0],
            [_chevronView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-18.0],
            [_chevronView.widthAnchor constraintEqualToConstant:14.0],
            [_chevronView.heightAnchor constraintEqualToConstant:18.0],
            
            [_availabilityBadgeLabel.bottomAnchor constraintEqualToAnchor:_chevronView.topAnchor constant:-8],
        ]];
    }
    return self;
}

- (void)configureWithMedicine:(PPVetMedicineModel *)medicine {
    _isDisabledMedicine = medicine.isDisabled;
    _titleLabel.text = medicine.title.length ? medicine.title : @"—";
    NSString *categoryText = [[PPSafeString(medicine.category) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    _categoryLabel.text = categoryText.length ? categoryText : kLang(@"Pharmacy_Category_Other").uppercaseString;
    _descriptionLabel.text = medicine.medicineDescription.length ? medicine.medicineDescription : kLang(@"Pharmacy_Field_Description_Hint");

    NSString *stockText = [NSString stringWithFormat:@"%ld %@", (long)MAX(0, medicine.stockQuantity), kLang(@"Pharmacy_Field_Quantity")];
    _stockLabel.text = stockText;
    _animalTypesLabel.text = medicine.animalTypes.count ? [medicine.animalTypes componentsJoinedByString:@" · "] : kLang(@"Pharmacy_Field_AnimalTypes");

    NSString *currency = medicine.currency.length ? medicine.currency : @"QAR";
    _priceLabel.text = [NSString stringWithFormat:@"%.2f %@", medicine.price, currency];

    _statusBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", medicine.isPublished ? kLang(@"Pharmacy_Status_Published") : kLang(@"Pharmacy_Status_Draft")];
    UIColor *statusColor = medicine.isPublished ? AppPrimaryClr : [UIColor systemOrangeColor];
    _statusBadgeLabel.textColor = statusColor;
    _statusBadgeLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    BOOL isAvailable = medicine.isAvailable && medicine.stockQuantity > 0 && medicine.isPublished && !medicine.isDisabled;
    UIColor *availabilityColor = isAvailable ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    _availabilityBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", isAvailable ? kLang(@"Pharmacy_Status_Available") : kLang(@"Pharmacy_Status_NotAvailable")];
    _availabilityBadgeLabel.textColor = availabilityColor;
    _availabilityBadgeLabel.backgroundColor = [availabilityColor colorWithAlphaComponent:isAvailable ? 0.12 : 0.10];

    if (medicine.imageUrl.length > 0) {
        [_medicineImageView setImageWithURL:[NSURL URLWithString:medicine.imageUrl] placeholder:nil];
        _medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        _medicineImageView.image = [UIImage systemImageNamed:@"pills.fill"];
        _medicineImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
        _medicineImageView.contentMode = UIViewContentModeCenter;
    }

    _cardView.alpha = medicine.isDisabled ? 0.48 : 1.0;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self->_cardView.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self->_cardView.alpha = highlighted ? 0.82 : (self->_isDisabledMedicine ? 0.48 : 1.0);
    } completion:nil];
}

@end

@interface PPPharmacyMedicinesViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UIView *heroContainer;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) UIView *heroSurfaceView;

@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIVisualEffectView *searchGlass;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<PPVetMedicineModel *> *allMedicines;
@property (nonatomic, copy) NSArray<PPVetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

static CGFloat const kHeroHeight = 172.0;

@implementation PPPharmacyMedicinesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.allMedicines = @[];
    self.filteredMedicines = @[];
    self.searchQuery = @"";

    [self pp_setupHero];
    [self pp_setupTableView];
    [self pp_setupEmptyState];
    [self pp_configureNavigation];
    [self pp_reloadMedicines];
}

- (void)pp_setupHero {
    _heroContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kHeroHeight)];
    _heroContainer.clipsToBounds = YES;
    _heroContainer.backgroundColor = AppBackgroundClr;
    [self.view addSubview:_heroContainer];



    _heroSurfaceView = [[PPHero alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.layer.cornerRadius = 28.0;
    [_heroContainer addSubview:_heroSurfaceView];



    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 16.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [_heroSurfaceView addSubview:iconSurface];

    _heroImageView = [[UIImageView alloc] init];
    _heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroImageView.contentMode = UIViewContentModeScaleAspectFit;
    _heroImageView.tintColor = AppPrimaryClr;
    _heroImageView.image = [UIImage systemImageNamed:@"pills.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold]];
    [iconSurface addSubview:_heroImageView];

    _heroTitleLabel = [[UILabel alloc] init];
    _heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _heroTitleLabel.font = [Styling fontBold:26.0];
    _heroTitleLabel.textColor = PrimaryTextClr;
    _heroTitleLabel.text = kLang(@"Pharmacy_Manage_Title");
    _heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_heroSurfaceView addSubview:_heroTitleLabel];

    _heroSubtitleLabel = [[UILabel alloc] init];
    _heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSubtitleLabel.font = [Styling fontMedium:13.0];
    _heroSubtitleLabel.textColor = SeconderyTextClr;
    _heroSubtitleLabel.numberOfLines = 2;
    _heroSubtitleLabel.alpha = 0.76;
    _heroSubtitleLabel.text = kLang(@"Pharmacy_Manage_Subtitle");
    _heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_heroSurfaceView addSubview:_heroSubtitleLabel];

    _searchGlass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    _searchGlass.translatesAutoresizingMaskIntoConstraints = NO;
    _searchGlass.layer.cornerRadius = 22.0;
    _searchGlass.clipsToBounds = YES;
    _searchGlass.hidden = PPIOS26();
    _searchGlass.layer.borderWidth = 1.0;
    _searchGlass.layer.borderColor = [PrimaryTextClr colorWithAlphaComponent:0.04].CGColor;
    [_heroSurfaceView addSubview:_searchGlass];
    

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.backgroundColor = UIColor.clearColor;

    // Fix Localization & Styling
    NSString *placeholder = kLang(@"Search");
    if ([placeholder containsString:@"_"] || [placeholder isEqualToString:@"Search"]) {
        placeholder = kLang(@"Pharmacy_Search_Placeholder");
    }
    if ([placeholder containsString:@"_"]) placeholder = @"Search...";
    _searchBar.placeholder = placeholder;

    UITextField *searchField = [_searchBar valueForKey:@"searchField"];
    if (searchField) {
        searchField.font = [Styling fontMedium:15.0];
        searchField.textColor = PrimaryTextClr;
    }

    [_heroContainer addSubview:_searchBar];

    [NSLayoutConstraint activateConstraints:@[

        [_heroContainer.heightAnchor constraintEqualToConstant:kHeroHeight],



        [_heroSurfaceView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [_heroSurfaceView.leadingAnchor constraintEqualToAnchor:_heroContainer.leadingAnchor constant:18.0],
        [_heroSurfaceView.trailingAnchor constraintEqualToAnchor:_heroContainer.trailingAnchor constant:-18.0],
        [_heroSurfaceView.bottomAnchor constraintEqualToAnchor:_heroContainer.bottomAnchor constant:-14.0],

        [iconSurface.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:22.0],
        [iconSurface.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:40.0],
        [iconSurface.widthAnchor constraintEqualToConstant:42.0],
        [iconSurface.heightAnchor constraintEqualToConstant:42.0],

        [_heroImageView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [_heroImageView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [_heroImageView.widthAnchor constraintEqualToConstant:22.0],
        [_heroImageView.heightAnchor constraintEqualToConstant:22.0],

        [_heroTitleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:14.0],
        [_heroTitleLabel.topAnchor constraintEqualToAnchor:iconSurface.topAnchor constant:-1.0],
        [_heroTitleLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-22.0],

        [_heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:_heroTitleLabel.leadingAnchor],
        [_heroSubtitleLabel.topAnchor constraintEqualToAnchor:_heroTitleLabel.bottomAnchor constant:4.0],
        [_heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:_heroTitleLabel.trailingAnchor],

        [_searchGlass.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:14.0],
        [_searchGlass.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-14.0],
        [_searchGlass.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-14.0],
        [_searchGlass.heightAnchor constraintEqualToConstant:48.0],
        
        [_searchBar.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:14.0],
        [_searchBar.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-14.0],
        [_searchBar.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-14.0],
        [_searchBar.heightAnchor constraintEqualToConstant:48.0],

 
    ]];
}

- (void)pp_setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 148.0;
    //self.tableView.contentInset = UIEdgeInsetsMake(kHeroHeight - 20.0, 0, 80.0, 0);
    [self.tableView registerClass:[PPPharmacyMedicineCell class] forCellReuseIdentifier:@"PPPharmacyMedicineCell"];
    [self.view insertSubview:self.tableView belowSubview:_heroContainer];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = AppPrimaryClr;
    [refresh addTarget:self action:@selector(pp_reloadMedicines) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}




- (void)pp_animateVisibleCells {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;

    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    [cells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, BOOL *stop) {
        cell.alpha = 0;
        cell.transform = CGAffineTransformMakeTranslation(0, 20);
        [UIView animateWithDuration:0.6 delay:0.05 * idx usingSpringWithDamping:0.8 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.alpha = 1;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_setupEmptyState {
    self.emptyContainer = [[UIView alloc] init];
    self.emptyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyContainer.hidden = YES;
    [self.view addSubview:self.emptyContainer];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pills.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:40 weight:UIImageSymbolWeightLight]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyContainer addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:22.0];
    label.textColor = PrimaryTextClr;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = kLang(@"Pharmacy_Empty_Title");
    [self.emptyContainer addSubview:label];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.font = [Styling fontMedium:15.0];
    subLabel.textColor = SeconderyTextClr;
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.numberOfLines = 0;
    subLabel.text = kLang(@"Pharmacy_Empty_List");
    [self.emptyContainer addSubview:subLabel];

    UIButton *cta = [UIButton buttonWithType:UIButtonTypeSystem];
    cta.translatesAutoresizingMaskIntoConstraints = NO;
    [cta setTitle:kLang(@"Pharmacy_Add_Title") forState:UIControlStateNormal];
    cta.titleLabel.font = [Styling fontBold:16.0];
    cta.tintColor = UIColor.whiteColor;
    cta.backgroundColor = AppPrimaryClr;
    cta.layer.cornerRadius = 26.0;
    cta.layer.cornerCurve = kCACornerCurveContinuous;
    cta.contentEdgeInsets = UIEdgeInsetsMake(0, 36.0, 0, 36.0);
    [cta addTarget:self action:@selector(addMedicineTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyContainer addSubview:cta];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyContainer.topAnchor constraintEqualToAnchor:self.tableView.topAnchor constant:kHeroHeight + 60.0],
        [self.emptyContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40.0],
        [self.emptyContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40.0],

        [icon.topAnchor constraintEqualToAnchor:self.emptyContainer.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:self.emptyContainer.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:100.0],
        [icon.heightAnchor constraintEqualToConstant:100.0],

        [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:24.0],
        [label.leadingAnchor constraintEqualToAnchor:self.emptyContainer.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:self.emptyContainer.trailingAnchor],

        [subLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:8.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:self.emptyContainer.leadingAnchor],
        [subLabel.trailingAnchor constraintEqualToAnchor:self.emptyContainer.trailingAnchor],

        [cta.topAnchor constraintEqualToAnchor:subLabel.bottomAnchor constant:36.0],
        [cta.centerXAnchor constraintEqualToAnchor:self.emptyContainer.centerXAnchor],
        [cta.heightAnchor constraintEqualToConstant:52.0],
        [cta.bottomAnchor constraintEqualToAnchor:self.emptyContainer.bottomAnchor],
    ]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat y = scrollView.contentOffset.y;
    CGFloat offset = y + scrollView.contentInset.top;

    // Parallax & Sticky Effect
    CGRect frame = _heroContainer.frame;
    if (y < -scrollView.contentInset.top) {
        CGFloat diff = -scrollView.contentInset.top - y;
        frame.size.height = kHeroHeight + diff;
        frame.origin.y = y + scrollView.contentInset.top;
        _heroContainer.frame = frame;
    } else {
        frame.origin.y = -offset * 0.4;
        _heroContainer.frame = frame;
    }

    // Sophisticated Fade Out
    CGFloat alpha = 1.0 - (offset / 120.0);
    _searchGlass.alpha = MAX(0, alpha);
    _heroTitleLabel.alpha = MAX(0, alpha);
    _heroSubtitleLabel.alpha = MAX(0, alpha);
}



- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_configureNavigation];
}

- (void)pp_configureNavigation {
    UIButton *addButton = [self pp_ButtonWithSystemName:@"plus" action:@selector(addMedicineTapped)];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:addButton title:@"" showBack:YES];
     self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (NSString *)pp_currentPartnerUID {
    UserModel *user = UsrMgr.currentUser;
    if (user.uid.length > 0) return user.uid;
    if (user.ID.length > 0) return user.ID;
    return [FIRAuth auth].currentUser.uid ?: @"";
}

- (void)pp_reloadMedicines {
    NSString *uid = [self pp_currentPartnerUID];
    if (uid.length == 0) {
        [self.tableView.refreshControl endRefreshing];
        self.allMedicines = @[];
        [self pp_applyFilter];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[PPVetManager sharedManager] fetchMedicinesForUserID:uid completion:^(NSArray<PPVetMedicineModel *> * _Nullable medicines, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.tableView.refreshControl endRefreshing];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            self.allMedicines = [medicines sortedArrayUsingComparator:^NSComparisonResult(PPVetMedicineModel *a, PPVetMedicineModel *b) {
                return [PPSafeString(a.title) localizedCaseInsensitiveCompare:PPSafeString(b.title)];
            }] ?: @[];
            [self pp_applyFilter];
        });
    }];
}

- (void)pp_applyFilter {
    NSString *query = [[PPSafeString(self.searchQuery) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.filteredMedicines = self.allMedicines;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPVetMedicineModel *medicine, NSDictionary<NSString *,id> * _Nullable bindings) {
            NSString *haystack = [@[PPSafeString(medicine.title), PPSafeString(medicine.medicineDescription), PPSafeString(medicine.category)] componentsJoinedByString:@" "].lowercaseString;
            return [haystack containsString:query];
        }];
        self.filteredMedicines = [self.allMedicines filteredArrayUsingPredicate:predicate];
    }

    self.emptyContainer.hidden = (self.filteredMedicines.count > 0 || self.allMedicines.count == 0);
    [self.tableView reloadData];

    if (self.filteredMedicines.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_animateVisibleCells];
        });
    }

    if (self.allMedicines.count == 0) {
        self.emptyContainer.hidden = NO;
        self.tableView.hidden = YES;
    } else {
        self.tableView.hidden = NO;
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchQuery = searchText ?: @"";
    [self pp_applyFilter];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredMedicines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPPharmacyMedicineCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPPharmacyMedicineCell" forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.filteredMedicines.count) {
        [cell configureWithMedicine:self.filteredMedicines[indexPath.row]];
    }
    return cell;
}

- (PPVetMedicineModel *)pp_medicineAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.filteredMedicines.count) {
        return nil;
    }
    return self.filteredMedicines[indexPath.row];
}

- (void)addMedicineTapped {
    [PPFunc pp_playTapEffect];
    [self pp_openEditorForMedicine:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [PPFunc pp_playTapEffect];
    [self pp_openEditorForMedicine:[self pp_medicineAtIndexPath:indexPath]];
}

- (void)pp_openEditorForMedicine:(PPVetMedicineModel *)medicine {
    __weak typeof(self) weakSelf = self;
    PPPharmacyMedicineEditorViewController *editor = [[PPPharmacyMedicineEditorViewController alloc] initWithMedicine:medicine completion:^(PPVetMedicineModel *editedMedicine, UIImage * _Nullable image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
        void (^completion)(NSError * _Nullable) = ^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                if (error) {
                    [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                    return;
                }
                NSString *subtitle = medicine ? kLang(@"Pharmacy_Updated_Success") : kLang(@"Pharmacy_Added_Success");
                [PPHUD showSuccess:kLang(@"Updated") subtitle:subtitle];
                [self.navigationController popViewControllerAnimated:YES];
                [self pp_reloadMedicines];
            });
        };

        if (medicine) {
            [[PPVetManager sharedManager] updateMedicine:editedMedicine image:image completion:completion];
        } else {
            [[PPVetManager sharedManager] addMedicine:editedMedicine image:image completion:completion];
        }
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        PPVetMedicineModel *medicine = [weakSelf pp_medicineAtIndexPath:indexPath];
        if (!medicine) {
            completionHandler(NO);
            return;
        }

        [PPAlertHelper showConfirmationIn:weakSelf
                                    title:kLang(@"Pharmacy_Delete_Confirm_Title")
                                 subtitle:kLang(@"Pharmacy_Delete_Confirm_Msg")
                              placeholder:nil
                            confirmButton:kLang(@"Delete")
                             cancelButton:kLang(@"Cancel")
                             confirmBlock:^{
            [PPHUD showIndeterminateIn:weakSelf.view title:kLang(@"Deleting") subtitle:nil];
            [[PPVetManager sharedManager] deleteMedicine:medicine completion:^(NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [PPHUD dismiss];
                    if (error) {
                        [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                        return;
                    }
                    [PPHUD showSuccess:kLang(@"Deleted") subtitle:kLang(@"Pharmacy_Deleted_Success")];
                    [weakSelf pp_reloadMedicines];
                });
            }];
        } cancelBlock:nil];
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash.circle.fill"];
    deleteAction.backgroundColor = self.view.backgroundColor;
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

@end
