//
//  PPAdoptPetCell.m
//  PurePetsPro
//

#import "PPAdoptPetCell.h"
#import "PPFirebaseCompat.h"
#import "UIImageView+WebCache.h"

@interface PPAdoptPetCell ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIImageView *petImageView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPAdoptPetCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.petImageView sd_cancelCurrentImageLoad];
    self.petImageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    self.petImageView.tintColor = AppPrimaryClr;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
}

- (void)setupUI {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat cornerRadius = isPad ? 26.0 : 22.0;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _surfaceView = [UIView new];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = AppForgroundColr;
    _surfaceView.layer.cornerRadius = cornerRadius;
    _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _surfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    _surfaceView.layer.shadowColor = (AppShadowColor).CGColor;
    _surfaceView.layer.shadowOpacity = 0.055;
    _surfaceView.layer.shadowRadius = isPad ? 22.0 : 16.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0, isPad ? 10.0 : 6.0);
    [self.contentView addSubview:_surfaceView];

    CGFloat imageSize = isPad ? 80.0 : 68.0;
    _petImageView = [UIImageView new];
    _petImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _petImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.07];
    _petImageView.tintColor = AppPrimaryClr;
    _petImageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    _petImageView.contentMode = UIViewContentModeScaleAspectFill;
    _petImageView.clipsToBounds = YES;
    _petImageView.layer.cornerRadius = isPad ? 22.0 : 18.0;
    _petImageView.layer.cornerCurve = kCACornerCurveContinuous;
    _petImageView.layer.borderWidth = 1.0;
    _petImageView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    [_surfaceView addSubview:_petImageView];

    _petTitle = [UILabel new];
    _petTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _petTitle.font = [Styling fontBold:isPad ? 18.0 : 16.5];
    _petTitle.textColor = PrimaryTextClr;
    _petTitle.textAlignment = Language.alignmentForCurrentLanguage;
    _petTitle.numberOfLines = 1;
    [_surfaceView addSubview:_petTitle];

    _petDescription = [UILabel new];
    _petDescription.translatesAutoresizingMaskIntoConstraints = NO;
    _petDescription.font = [Styling fontRegular:isPad ? 14.0 : 13.0];
    _petDescription.textColor = [SeconderyTextClr colorWithAlphaComponent:0.86];
    _petDescription.textAlignment = Language.alignmentForCurrentLanguage;
    _petDescription.numberOfLines = 2;
    [_surfaceView addSubview:_petDescription];

    _adopterInfoLabel = [UILabel new];
    _adopterInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _adopterInfoLabel.font = [Styling fontMedium:isPad ? 13.0 : 12.0];
    _adopterInfoLabel.textColor = SeconderyTextClr;
    _adopterInfoLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _adopterInfoLabel.numberOfLines = 1;
    [_surfaceView addSubview:_adopterInfoLabel];

    _statusLabel = [UILabel new];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [Styling fontBold:11.5];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.layer.cornerRadius = 12.0;
    _statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    _statusLabel.clipsToBounds = YES;
    [_surfaceView addSubview:_statusLabel];

    _metaLabel = [UILabel new];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = [Styling fontMedium:11.5];
    _metaLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.70];
    _metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_surfaceView addSubview:_metaLabel];

    _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"]];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.35];
    [_surfaceView addSubview:_chevronView];

    CGFloat horizontalMargin = isPad ? 28.0 : 16.0;

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:horizontalMargin],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-horizontalMargin],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_petImageView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [_petImageView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_petImageView.widthAnchor constraintEqualToConstant:imageSize],
        [_petImageView.heightAnchor constraintEqualToConstant:imageSize],

        [_statusLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:14.0],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_statusLabel.heightAnchor constraintEqualToConstant:24.0],
        [_statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [_petTitle.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:14.0],
        [_petTitle.leadingAnchor constraintEqualToAnchor:_petImageView.trailingAnchor constant:13.0],
        [_petTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_statusLabel.leadingAnchor constant:-10.0],

        [_petDescription.topAnchor constraintEqualToAnchor:_petTitle.bottomAnchor constant:4.0],
        [_petDescription.leadingAnchor constraintEqualToAnchor:_petTitle.leadingAnchor],
        [_petDescription.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-38.0],

        [_adopterInfoLabel.topAnchor constraintEqualToAnchor:_petDescription.bottomAnchor constant:6.0],
        [_adopterInfoLabel.leadingAnchor constraintEqualToAnchor:_petTitle.leadingAnchor],
        [_adopterInfoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_adopterInfoLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_surfaceView.bottomAnchor constant:-14.0],

        [_metaLabel.centerYAnchor constraintEqualToAnchor:_statusLabel.centerYAnchor],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_statusLabel.leadingAnchor constant:-8.0],

        [_chevronView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_chevronView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-16.0],
        [_chevronView.widthAnchor constraintEqualToConstant:9.0],
        [_chevronView.heightAnchor constraintEqualToConstant:16.0],
    ]];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    CGFloat scale = highlighted ? 0.985 : 1.0;
    NSTimeInterval duration = animated ? 0.18 : 0.0;
    [UIView animateWithDuration:duration animations:^{
        self.surfaceView.transform = CGAffineTransformMakeScale(scale, scale);
        self.surfaceView.alpha = highlighted ? 0.92 : 1.0;
    }];
}

- (void)configureWithAdoptPet:(PPAdoptPetModel *)pet {
    self.petTitle.text = pet.title.length > 0 ? pet.title : kLang(@"AdoptPro_Untitled");
    self.petDescription.text = pet.descriptionText.length > 0 ? pet.descriptionText : kLang(@"AdoptPro_NoDescription");
    self.adopterInfoLabel.text = pet.isAdopted && pet.adopterName.length > 0
        ? [NSString stringWithFormat:kLang(@"Adopted_By_Format"), pet.adopterName]
        : [self ownerMetaForPet:pet];
    self.metaLabel.text = pet.ageMonths > 0 ? [NSString stringWithFormat:kLang(@"AdoptPro_AgeMonths_Format"), (long)pet.ageMonths] : @"";
    [self configureStatusForPet:pet];

    NSString *firstURL = pet.imageURLs.firstObject;
    if (firstURL.length > 0) {
        [self.petImageView sd_setImageWithURL:[NSURL URLWithString:firstURL]
                             placeholderImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    } else {
        self.petImageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.petTitle.text ?: @"", self.statusLabel.text ?: @""];
}

- (NSString *)ownerMetaForPet:(PPAdoptPetModel *)pet {
    if (pet.ownerID.length == 0) {
        return kLang(@"AdoptPro_OwnerUnknown");
    }
    NSString *shortID = pet.ownerID.length > 8 ? [pet.ownerID substringToIndex:8] : pet.ownerID;
    return [NSString stringWithFormat:kLang(@"AdoptPro_Owner_Format"), shortID];
}

- (void)configureStatusForPet:(PPAdoptPetModel *)pet {
    UIColor *accent = [self statusColorForPet:pet];
    self.statusLabel.text = [NSString stringWithFormat:@"  %@  ", [self statusTextForPet:pet]];
    self.statusLabel.textColor = accent;
    self.statusLabel.backgroundColor = [accent colorWithAlphaComponent:0.12];
}

- (NSString *)statusTextForPet:(PPAdoptPetModel *)pet {
    if (pet.isDeleted) return kLang(@"AdoptPro_Status_Deleted");
    if (pet.isBlocked) return kLang(@"AdoptPro_Status_Blocked");
    if (pet.visibility == 1 || [pet.status isEqualToString:@"hidden"]) return kLang(@"AdoptPro_Status_Hidden");
    if (pet.isAdopted || [pet.status isEqualToString:@"adopted"]) return kLang(@"AdoptPro_Status_Adopted");
    return kLang(@"AdoptPro_Status_Available");
}

- (UIColor *)statusColorForPet:(PPAdoptPetModel *)pet {
    if (pet.isDeleted || pet.isBlocked) return [UIColor ppError];
    if (pet.visibility == 1 || [pet.status isEqualToString:@"hidden"]) return [UIColor ppWarning];
    if (pet.isAdopted || [pet.status isEqualToString:@"adopted"]) return [UIColor ppSuccess];
    return AppPrimaryClr;
}

@end
