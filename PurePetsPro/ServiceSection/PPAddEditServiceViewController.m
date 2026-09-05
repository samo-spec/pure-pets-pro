//
//  PPAddEditServiceViewController.m
//  PurePetsPro
//
//  Category-defining service creation studio with live customer preview,
//  bespoke photography studio, species chips, pricing engine, and floating dock.
//

#import "PPAddEditServiceViewController.h"
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
#import <PhotosUI/PhotosUI.h>

@interface PPAddEditServiceViewController () <UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

// Scroll & Layout
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *floatingSaveDock;
@property (nonatomic, strong) UIButton *saveButton;

// Live Preview Card Elements
@property (nonatomic, strong) UIView *livePreviewCard;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *previewTitleLabel;
@property (nonatomic, strong) UILabel *previewSubtitleLabel;
@property (nonatomic, strong) UILabel *previewPriceLabel;
@property (nonatomic, strong) UILabel *previewSpeciesBadge;
@property (nonatomic, strong) UILabel *previewDurationBadge;

// Photo Studio
@property (nonatomic, strong) UIImageView *photoImageView;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, assign) BOOL hasNewPhotoSelected;

// Classification & Species
@property (nonatomic, assign) PPServiceType selectedType;
@property (nonatomic, assign) NSInteger selectedPetKindID;
@property (nonatomic, strong) NSMutableArray<UIButton *> *typeButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *speciesButtons;

// Inputs
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descPlaceholderLabel;
@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UISwitch *availabilitySwitch;

// Duration & Delivery
@property (nonatomic, copy) NSString *selectedDuration;
@property (nonatomic, copy) NSString *selectedDelivery;
@property (nonatomic, strong) NSMutableArray<UIButton *> *durationButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *deliveryButtons;

// Inclusions Checklist
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedInclusions;

@property (nonatomic, assign) BOOL isEditingMode;
@property (nonatomic, strong, nullable) PPServiceModel *templateModel;

@end

@implementation PPAddEditServiceViewController

- (instancetype)initWithService:(PPServiceModel * _Nullable)service {
    self = [super init];
    if (self) {
        _serviceToEdit = service;
        _isEditingMode = (service != nil);
    }
    return self;
}

- (instancetype)initWithTemplate:(PPServiceModel * _Nullable)templateModel {
    self = [super init];
    if (self) {
        _templateModel = templateModel;
        _isEditingMode = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.typeButtons = [NSMutableArray array];
    self.speciesButtons = [NSMutableArray array];
    self.durationButtons = [NSMutableArray array];
    self.deliveryButtons = [NSMutableArray array];
    self.selectedInclusions = [NSMutableSet set];

    // Default values
    self.selectedType = PPServiceTypeGrooming;
    self.selectedPetKindID = 1; // Dogs
    self.selectedDuration = Language.isRTL ? @"45 دقيقة" : @"45 min";
    self.selectedDelivery = Language.isRTL ? @"زيارة منزلية وفي المركز" : @"Home & Center";

    [self setupNavigation];
    [self setupScrollView];
    [self buildFormSections];
    [self setupFloatingSaveDock];
    [self populateInitialData];
    [self updateLivePreview];
}

#pragma mark - Navigation

- (void)setupNavigation {
    NSString *title = self.isEditingMode
        ? (Language.isRTL ? @"تعديل عرض الخدمة" : @"Edit Service")
        : (Language.isRTL ? @"إنشاء عرض خدمة جديد" : @"New Service Studio");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

#pragma mark - Scroll & Stack

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _scrollView.contentInset = UIEdgeInsetsMake(12, 0, 110, 0);
    [self.view addSubview:_scrollView];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 20.0;
    _contentStack.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:12.0],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-20.0],
        [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32.0],
    ]];
}

#pragma mark - Form Sections Builder

- (void)buildFormSections {
    // 1. Live Customer Preview Card
    [self buildLivePreviewSection];

    // 2. Photo Studio Section
    [self buildPhotoStudioSection];

    // 3. Classification & Species Section
    [self buildClassificationSection];

    // 4. Title & Description Section
    [self buildTitleAndDescriptionSection];

    // 5. Pricing & Currency Section
    [self buildPricingSection];

    // 6. Duration & Delivery Model Section
    [self buildDurationAndDeliverySection];

    // 7. Inclusions Checklist Section
    [self buildInclusionsSection];

    // 8. Instant Availability Switch Section
    [self buildAvailabilitySection];
}

#pragma mark - 1. Live Customer Preview Section

- (void)buildLivePreviewSection {
    UIView *card = [self makeSectionCard];
    
    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Serv_Live_Preview") icon:@"sparkles"];
    [card addSubview:header];

    _livePreviewCard = [UIView new];
    _livePreviewCard.translatesAutoresizingMaskIntoConstraints = NO;
    _livePreviewCard.backgroundColor = [UIColor ppSurface];
    PPApplyContinuousCorners(_livePreviewCard, PPCornerCard);
    _livePreviewCard.layer.borderWidth = 1.0;
    _livePreviewCard.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.25].CGColor;
    PPApplyCardShadow(_livePreviewCard);
    [card addSubview:_livePreviewCard];

    _previewImageView = [UIImageView new];
    _previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    _previewImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_previewImageView, 14.0);
    _previewImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    _previewImageView.image = [UIImage systemImageNamed:@"sparkles"];
    _previewImageView.tintColor = AppPrimaryClr;
    [_livePreviewCard addSubview:_previewImageView];

    _previewTitleLabel = [UILabel new];
    _previewTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _previewTitleLabel.font = [Styling fontBold:15.5];
    _previewTitleLabel.textColor = PrimaryTextClr;
    _previewTitleLabel.text = Language.isRTL ? @"اسم الخدمة الاحترافية" : @"Service Title";
    _previewTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_livePreviewCard addSubview:_previewTitleLabel];

    _previewSubtitleLabel = [UILabel new];
    _previewSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _previewSubtitleLabel.font = [Styling fontMedium:12.0];
    _previewSubtitleLabel.textColor = SeconderyTextClr;
    _previewSubtitleLabel.text = Language.isRTL ? @"حلاقة وعناية · وصف موجز للخدمة" : @"Grooming · Description";
    _previewSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _previewSubtitleLabel.numberOfLines = 2;
    [_livePreviewCard addSubview:_previewSubtitleLabel];

    _previewPriceLabel = [UILabel new];
    _previewPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _previewPriceLabel.font = [Styling fontBold:13.5];
    _previewPriceLabel.textColor = [UIColor ppSuccess];
    _previewPriceLabel.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    _previewPriceLabel.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_previewPriceLabel, 10.0);
    _previewPriceLabel.clipsToBounds = YES;
    _previewPriceLabel.text = @" 150 QAR ";
    [_livePreviewCard addSubview:_previewPriceLabel];

    _previewSpeciesBadge = [UILabel new];
    _previewSpeciesBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _previewSpeciesBadge.font = [Styling fontBold:10.5];
    _previewSpeciesBadge.textColor = AppPrimaryClr;
    _previewSpeciesBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(_previewSpeciesBadge, 6.0);
    _previewSpeciesBadge.clipsToBounds = YES;
    _previewSpeciesBadge.text = @" 🐕 كلاب ";
    [_livePreviewCard addSubview:_previewSpeciesBadge];

    _previewDurationBadge = [UILabel new];
    _previewDurationBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _previewDurationBadge.font = [Styling fontMedium:11.0];
    _previewDurationBadge.textColor = SeconderyTextClr;
    _previewDurationBadge.text = @"⏱️ 45 دقيقة";
    [_livePreviewCard addSubview:_previewDurationBadge];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [_livePreviewCard.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [_livePreviewCard.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [_livePreviewCard.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [_livePreviewCard.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],

        [_previewImageView.leadingAnchor constraintEqualToAnchor:_livePreviewCard.leadingAnchor constant:12.0],
        [_previewImageView.topAnchor constraintEqualToAnchor:_livePreviewCard.topAnchor constant:12.0],
        [_previewImageView.widthAnchor constraintEqualToConstant:64.0],
        [_previewImageView.heightAnchor constraintEqualToConstant:64.0],

        [_previewTitleLabel.topAnchor constraintEqualToAnchor:_livePreviewCard.topAnchor constant:12.0],
        [_previewTitleLabel.leadingAnchor constraintEqualToAnchor:_previewImageView.trailingAnchor constant:12.0],
        [_previewTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_previewPriceLabel.leadingAnchor constant:-8.0],

        [_previewPriceLabel.topAnchor constraintEqualToAnchor:_livePreviewCard.topAnchor constant:12.0],
        [_previewPriceLabel.trailingAnchor constraintEqualToAnchor:_livePreviewCard.trailingAnchor constant:-12.0],
        [_previewPriceLabel.heightAnchor constraintEqualToConstant:24.0],

        [_previewSubtitleLabel.topAnchor constraintEqualToAnchor:_previewTitleLabel.bottomAnchor constant:3.0],
        [_previewSubtitleLabel.leadingAnchor constraintEqualToAnchor:_previewTitleLabel.leadingAnchor],
        [_previewSubtitleLabel.trailingAnchor constraintEqualToAnchor:_livePreviewCard.trailingAnchor constant:-12.0],

        [_previewSpeciesBadge.leadingAnchor constraintEqualToAnchor:_previewTitleLabel.leadingAnchor],
        [_previewSpeciesBadge.topAnchor constraintEqualToAnchor:_previewSubtitleLabel.bottomAnchor constant:8.0],
        [_previewSpeciesBadge.bottomAnchor constraintEqualToAnchor:_livePreviewCard.bottomAnchor constant:-12.0],

        [_previewDurationBadge.leadingAnchor constraintEqualToAnchor:_previewSpeciesBadge.trailingAnchor constant:10.0],
        [_previewDurationBadge.centerYAnchor constraintEqualToAnchor:_previewSpeciesBadge.centerYAnchor],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 2. Photo Studio Section

- (void)buildPhotoStudioSection {
    UIView *card = [self makeSectionCard];

    UILabel *header = [self makeSectionHeaderTitle:Language.isRTL ? @"صورة الخدمة الاحترافية" : @"Service Photography" icon:@"camera.fill"];
    [card addSubview:header];

    _photoImageView = [UIImageView new];
    _photoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _photoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _photoImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_photoImageView, 18.0);
    _photoImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    _photoImageView.layer.borderWidth = 1.5;
    _photoImageView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _photoImageView.userInteractionEnabled = YES;
    [card addSubview:_photoImageView];

    UITapGestureRecognizer *tapPhoto = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changePhotoTapped)];
    [_photoImageView addGestureRecognizer:tapPhoto];

    UIImageView *cameraBadge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"camera.circle.fill"
                                                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightBold]]];
    cameraBadge.translatesAutoresizingMaskIntoConstraints = NO;
    cameraBadge.tintColor = AppPrimaryClr;
    [_photoImageView addSubview:cameraBadge];

    UILabel *photoPrompt = [UILabel new];
    photoPrompt.translatesAutoresizingMaskIntoConstraints = NO;
    photoPrompt.text = Language.isRTL ? @"اضغط لإضافة صورة جذابة للخدمة من الكاميرا أو المعرض" : @"Tap to upload a service photo";
    photoPrompt.font = [Styling fontRegular:12.0];
    photoPrompt.textColor = SeconderyTextClr;
    photoPrompt.textAlignment = NSTextAlignmentCenter;
    [card addSubview:photoPrompt];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [_photoImageView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [_photoImageView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [_photoImageView.widthAnchor constraintEqualToConstant:140.0],
        [_photoImageView.heightAnchor constraintEqualToConstant:110.0],

        [cameraBadge.centerXAnchor constraintEqualToAnchor:_photoImageView.centerXAnchor],
        [cameraBadge.centerYAnchor constraintEqualToAnchor:_photoImageView.centerYAnchor],

        [photoPrompt.topAnchor constraintEqualToAnchor:_photoImageView.bottomAnchor constant:8.0],
        [photoPrompt.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [photoPrompt.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [photoPrompt.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 3. Classification & Species Section

- (void)buildClassificationSection {
    UIView *card = [self makeSectionCard];

    UILabel *typeHeader = [self makeSectionHeaderTitle:Language.isRTL ? @"نوع الخدمة والتخصص" : @"Service Category" icon:@"square.grid.2x2.fill"];
    [card addSubview:typeHeader];

    UIStackView *typeStack = [UIStackView new];
    typeStack.translatesAutoresizingMaskIntoConstraints = NO;
    typeStack.axis = UILayoutConstraintAxisHorizontal;
    typeStack.distribution = UIStackViewDistributionFillEqually;
    typeStack.spacing = 8.0;
    [card addSubview:typeStack];

    NSArray *types = Language.isRTL
        ? @[@"✂️ حلاقة", @"🦮 تدريب", @"🩺 رعاية", @"🏡 فندقة"]
        : @[@"✂️ Grooming", @"🦮 Training", @"🩺 Care", @"🏡 Hotel"];

    for (NSInteger i = 0; i < types.count; i++) {
        UIButton *btn = [self makePillButtonWithTitle:types[i] tag:i];
        [btn addTarget:self action:@selector(typePillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [typeStack addArrangedSubview:btn];
        [self.typeButtons addObject:btn];
    }

    UILabel *speciesHeader = [self makeSectionHeaderTitle:Language.isRTL ? @"الحيوانات المستهدفة" : @"Target Species" icon:@"pawprint.fill"];
    speciesHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:speciesHeader];

    UIStackView *speciesStack = [UIStackView new];
    speciesStack.translatesAutoresizingMaskIntoConstraints = NO;
    speciesStack.axis = UILayoutConstraintAxisHorizontal;
    speciesStack.distribution = UIStackViewDistributionFillEqually;
    speciesStack.spacing = 8.0;
    [card addSubview:speciesStack];

    NSArray *species = Language.isRTL
        ? @[@"🐕 الكلاب", @"🐈 القطط", @"🦜 الطيور", @"🐾 الجميع"]
        : @[@"🐕 Dogs", @"🐈 Cats", @"🦜 Birds", @"🐾 All Pets"];

    for (NSInteger i = 0; i < species.count; i++) {
        UIButton *btn = [self makePillButtonWithTitle:species[i] tag:i + 1];
        [btn addTarget:self action:@selector(speciesPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [speciesStack addArrangedSubview:btn];
        [self.speciesButtons addObject:btn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [typeHeader.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [typeHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [typeHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [typeStack.topAnchor constraintEqualToAnchor:typeHeader.bottomAnchor constant:10.0],
        [typeStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [typeStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [typeStack.heightAnchor constraintEqualToConstant:38.0],

        [speciesHeader.topAnchor constraintEqualToAnchor:typeStack.bottomAnchor constant:16.0],
        [speciesHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [speciesHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [speciesStack.topAnchor constraintEqualToAnchor:speciesHeader.bottomAnchor constant:10.0],
        [speciesStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [speciesStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [speciesStack.heightAnchor constraintEqualToConstant:38.0],
        [speciesStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 4. Title & Description Section

- (void)buildTitleAndDescriptionSection {
    UIView *card = [self makeSectionCard];

    UILabel *header = [self makeSectionHeaderTitle:Language.isRTL ? @"تفاصيل العرض والمواصفات" : @"Service Title & Details" icon:@"text.alignleft"];
    [card addSubview:header];

    _titleField = [UITextField new];
    _titleField.translatesAutoresizingMaskIntoConstraints = NO;
    _titleField.font = [Styling fontBold:15.0];
    _titleField.textColor = PrimaryTextClr;
    _titleField.placeholder = Language.isRTL ? @"مثال: باقة الحلاقة الملكية مع الحمام الطبي" : @"e.g. Royal Grooming & Medicated Bath";
    _titleField.backgroundColor = [UIColor ppSurface];
    _titleField.layer.borderWidth = 1.0;
    _titleField.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_titleField, PPCornerMedium);
    _titleField.textAlignment = Language.alignmentForCurrentLanguage;
    _titleField.delegate = self;
    [_titleField addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];

    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 44)];
    _titleField.leftView = pad;
    _titleField.leftViewMode = UITextFieldViewModeAlways;
    [card addSubview:_titleField];

    _descriptionView = [UITextView new];
    _descriptionView.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionView.font = [Styling fontRegular:13.5];
    _descriptionView.textColor = PrimaryTextClr;
    _descriptionView.backgroundColor = [UIColor ppSurface];
    _descriptionView.layer.borderWidth = 1.0;
    _descriptionView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_descriptionView, PPCornerMedium);
    _descriptionView.textAlignment = Language.alignmentForCurrentLanguage;
    _descriptionView.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
    _descriptionView.delegate = self;
    [card addSubview:_descriptionView];

    _descPlaceholderLabel = [UILabel new];
    _descPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descPlaceholderLabel.font = [Styling fontRegular:13.0];
    _descPlaceholderLabel.textColor = [UIColor ppTextTertiary];
    _descPlaceholderLabel.text = Language.isRTL
        ? @"اكتب وصفاً مفصلاً لما تشمله هذه الخدمة والنتائج التي سيحصل عليها أليف العميل..."
        : @"Write full details about what this service includes and expected results...";
    _descPlaceholderLabel.numberOfLines = 2;
    _descPlaceholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_descriptionView addSubview:_descPlaceholderLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [_titleField.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [_titleField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [_titleField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [_titleField.heightAnchor constraintEqualToConstant:46.0],

        [_descriptionView.topAnchor constraintEqualToAnchor:_titleField.bottomAnchor constant:10.0],
        [_descriptionView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [_descriptionView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [_descriptionView.heightAnchor constraintEqualToConstant:86.0],
        [_descriptionView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],

        [_descPlaceholderLabel.topAnchor constraintEqualToAnchor:_descriptionView.topAnchor constant:12.0],
        [_descPlaceholderLabel.leadingAnchor constraintEqualToAnchor:_descriptionView.leadingAnchor constant:14.0],
        [_descPlaceholderLabel.trailingAnchor constraintEqualToAnchor:_descriptionView.trailingAnchor constant:-14.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 5. Pricing Section

- (void)buildPricingSection {
    UIView *card = [self makeSectionCard];

    UILabel *header = [self makeSectionHeaderTitle:Language.isRTL ? @"سعر الخدمة بالريال القطري" : @"Pricing Engine (QAR)" icon:@"creditcard.fill"];
    [card addSubview:header];

    _priceField = [UITextField new];
    _priceField.translatesAutoresizingMaskIntoConstraints = NO;
    _priceField.font = [Styling fontBold:18.0];
    _priceField.textColor = [UIColor ppSuccess];
    _priceField.keyboardType = UIKeyboardTypeDecimalPad;
    _priceField.text = @"150";
    _priceField.backgroundColor = [UIColor ppSurface];
    _priceField.layer.borderWidth = 1.0;
    _priceField.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_priceField, PPCornerMedium);
    _priceField.textAlignment = NSTextAlignmentCenter;
    [_priceField addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
    [card addSubview:_priceField];

    UILabel *currBadge = [UILabel new];
    currBadge.text = @"  QAR / ر.ق  ";
    currBadge.font = [Styling fontBold:12.0];
    currBadge.textColor = AppPrimaryClr;
    [currBadge sizeToFit];
    _priceField.rightView = currBadge;
    _priceField.rightViewMode = UITextFieldViewModeAlways;

    UIStackView *presetStack = [UIStackView new];
    presetStack.translatesAutoresizingMaskIntoConstraints = NO;
    presetStack.axis = UILayoutConstraintAxisHorizontal;
    presetStack.distribution = UIStackViewDistributionFillEqually;
    presetStack.spacing = 8.0;
    [card addSubview:presetStack];

    NSArray *presets = @[@"80", @"120", @"150", @"200", @"250"];
    for (NSString *val in presets) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:[NSString stringWithFormat:@"%@ ر.ق", val] forState:UIControlStateNormal];
        [btn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
        btn.titleLabel.font = [Styling fontMedium:12.5];
        btn.backgroundColor = [UIColor ppSurface];
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        PPApplyContinuousCorners(btn, 10.0);
        objc_setAssociatedObject(btn, "preset_val", val, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
        [presetStack addArrangedSubview:btn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [_priceField.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [_priceField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [_priceField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [_priceField.heightAnchor constraintEqualToConstant:48.0],

        [presetStack.topAnchor constraintEqualToAnchor:_priceField.bottomAnchor constant:10.0],
        [presetStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [presetStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [presetStack.heightAnchor constraintEqualToConstant:34.0],
        [presetStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 6. Duration & Delivery Model Section

- (void)buildDurationAndDeliverySection {
    UIView *card = [self makeSectionCard];

    UILabel *durHeader = [self makeSectionHeaderTitle:Language.isRTL ? @"المدة الزمنية التقديرية" : @"Estimated Duration" icon:@"clock.fill"];
    [card addSubview:durHeader];

    UIStackView *durStack = [UIStackView new];
    durStack.translatesAutoresizingMaskIntoConstraints = NO;
    durStack.axis = UILayoutConstraintAxisHorizontal;
    durStack.distribution = UIStackViewDistributionFillEqually;
    durStack.spacing = 8.0;
    [card addSubview:durStack];

    NSArray *durs = Language.isRTL
        ? @[@"30 دقيقة", @"45 دقيقة", @"60 دقيقة", @"يوم كامل"]
        : @[@"30 min", @"45 min", @"60 min", @"Full Day"];

    for (NSInteger i = 0; i < durs.count; i++) {
        UIButton *btn = [self makePillButtonWithTitle:durs[i] tag:i];
        [btn addTarget:self action:@selector(durationTapped:) forControlEvents:UIControlEventTouchUpInside];
        [durStack addArrangedSubview:btn];
        [self.durationButtons addObject:btn];
    }

    UILabel *delHeader = [self makeSectionHeaderTitle:Language.isRTL ? @"موقع تقديم الخدمة" : @"Service Location" icon:@"mappin.circle.fill"];
    delHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:delHeader];

    UIStackView *delStack = [UIStackView new];
    delStack.translatesAutoresizingMaskIntoConstraints = NO;
    delStack.axis = UILayoutConstraintAxisHorizontal;
    delStack.distribution = UIStackViewDistributionFillEqually;
    delStack.spacing = 8.0;
    [card addSubview:delStack];

    NSArray *dels = Language.isRTL
        ? @[@"زيارة منزلية", @"في المركز", @"كلاهما متاح"]
        : @[@"Home Visit", @"At Center", @"Both"];

    for (NSInteger i = 0; i < dels.count; i++) {
        UIButton *btn = [self makePillButtonWithTitle:dels[i] tag:i];
        [btn addTarget:self action:@selector(deliveryTapped:) forControlEvents:UIControlEventTouchUpInside];
        [delStack addArrangedSubview:btn];
        [self.deliveryButtons addObject:btn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [durHeader.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [durHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [durHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [durStack.topAnchor constraintEqualToAnchor:durHeader.bottomAnchor constant:10.0],
        [durStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [durStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [durStack.heightAnchor constraintEqualToConstant:36.0],

        [delHeader.topAnchor constraintEqualToAnchor:durStack.bottomAnchor constant:16.0],
        [delHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [delHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [delStack.topAnchor constraintEqualToAnchor:delHeader.bottomAnchor constant:10.0],
        [delStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [delStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [delStack.heightAnchor constraintEqualToConstant:36.0],
        [delStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 7. Inclusions Section

- (void)buildInclusionsSection {
    UIView *card = [self makeSectionCard];

    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Serv_Inclusions_Title") icon:@"checkmark.seal.fill"];
    [card addSubview:header];

    NSArray *tags = Language.isRTL
        ? @[@"شامبو طبي مخصص", @"تقليم وصنفرة الأظافر", @"تنظيف وتعقيم الأذن", @"تجفيف وتسريح آمن", @"تعطير فاخر للأليف", @"متابعة وتقييم صحي"]
        : @[@"Medicated Shampoo", @"Nail Trimming", @"Ear Cleansing", @"Blow Dry & Styling", @"Pet Fragrance", @"Health Inspection"];

    UIStackView *rowsStack = [UIStackView new];
    rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowsStack.axis = UILayoutConstraintAxisVertical;
    rowsStack.spacing = 8.0;
    [card addSubview:rowsStack];

    for (NSInteger i = 0; i < tags.count; i += 2) {
        UIStackView *row = [UIStackView new];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 8.0;

        UIButton *b1 = [self makeChecklistButtonWithTitle:tags[i]];
        [row addArrangedSubview:b1];

        if (i + 1 < tags.count) {
            UIButton *b2 = [self makeChecklistButtonWithTitle:tags[i+1]];
            [row addArrangedSubview:b2];
        }
        [rowsStack addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [rowsStack.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12.0],
        [rowsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [rowsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [rowsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - 8. Availability Section

- (void)buildAvailabilitySection {
    UIView *card = [self makeSectionCard];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = Language.isRTL ? @"تفعيل ونشر الخدمة للعملاء فوراً" : @"Publish & Activate Immediately";
    title.font = [Styling fontBold:14.5];
    title.textColor = PrimaryTextClr;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:title];

    UILabel *sub = [UILabel new];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = Language.isRTL ? @"ستكون الخدمة جاهزة لاستقبال طلبات الحجز بمجرد النقر على حفظ." : @"Service will be visible in search upon saving.";
    sub.font = [Styling fontRegular:12.0];
    sub.textColor = SeconderyTextClr;
    sub.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:sub];

    _availabilitySwitch = [UISwitch new];
    _availabilitySwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _availabilitySwitch.onTintColor = [UIColor ppSuccess];
    _availabilitySwitch.on = YES;
    [card addSubview:_availabilitySwitch];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:_availabilitySwitch.leadingAnchor constant:-12.0],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3.0],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [sub.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],

        [_availabilitySwitch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [_availabilitySwitch.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    [self.contentStack addArrangedSubview:card];
}

#pragma mark - Floating Save Dock

- (void)setupFloatingSaveDock {
    _floatingSaveDock = [UIView new];
    _floatingSaveDock.translatesAutoresizingMaskIntoConstraints = NO;
    _floatingSaveDock.backgroundColor = [UIColor ppSurfaceOverlay];
    [self.view addSubview:_floatingSaveDock];

    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.backgroundColor = [UIColor ppPrimary];
    NSString *btnTitle = self.isEditingMode
        ? (Language.isRTL ? @"حفظ التعديلات وتحديث العرض" : @"Save Changes")
        : (Language.isRTL ? @"نشر الخدمة في تطبيق PurePets" : @"Publish Service Offer");
    [_saveButton setTitle:btnTitle forState:UIControlStateNormal];
    [_saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(_saveButton, PPCornerMedium);
    PPApplyButtonShadow(_saveButton);
    [_saveButton addTarget:self action:@selector(saveServiceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_floatingSaveDock addSubview:_saveButton];

    [NSLayoutConstraint activateConstraints:@[
        [_floatingSaveDock.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_floatingSaveDock.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_floatingSaveDock.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_floatingSaveDock.heightAnchor constraintEqualToConstant:94.0],

        [_saveButton.topAnchor constraintEqualToAnchor:_floatingSaveDock.topAnchor constant:10.0],
        [_saveButton.leadingAnchor constraintEqualToAnchor:_floatingSaveDock.leadingAnchor constant:16.0],
        [_saveButton.trailingAnchor constraintEqualToAnchor:_floatingSaveDock.trailingAnchor constant:-16.0],
        [_saveButton.heightAnchor constraintEqualToConstant:50.0],
    ]];
}

#pragma mark - Data Initializer

- (void)populateInitialData {
    PPServiceModel *src = self.serviceToEdit ?: self.templateModel;
    if (src) {
        self.titleField.text = src.title;
        self.descriptionView.text = src.descriptionText;
        self.descPlaceholderLabel.hidden = (src.descriptionText.length > 0);
        self.priceField.text = [NSString stringWithFormat:@"%.0f", src.price];
        self.selectedType = src.type;
        self.selectedPetKindID = src.petMainKindID > 0 ? src.petMainKindID : 1;
        self.availabilitySwitch.on = src.isAvailable;

        if (src.imageURL.length > 0) {
            [self.photoImageView sd_setImageWithURL:[NSURL URLWithString:src.imageURL]];
            [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:src.imageURL]];
        }
    }

    [self updateSelectionStyles];
}

- (void)updateLivePreview {
    NSString *t = self.titleField.text.length > 0 ? self.titleField.text : (Language.isRTL ? @"اسم الخدمة" : @"Service Title");
    self.previewTitleLabel.text = t;

    NSString *d = self.descriptionView.text.length > 0 ? self.descriptionView.text : (Language.isRTL ? @"وصف الخدمة ومميزاتها" : @"Service overview");
    self.previewSubtitleLabel.text = d;

    NSString *p = self.priceField.text.length > 0 ? self.priceField.text : @"0";
    self.previewPriceLabel.text = [NSString stringWithFormat:@"  %@ QAR  ", p];

    NSString *sp = Language.isRTL ? @"🐾 الجميع" : @"All Pets";
    if (self.selectedPetKindID == 1) sp = Language.isRTL ? @"🐕 كلاب" : @"Dogs";
    else if (self.selectedPetKindID == 2) sp = Language.isRTL ? @"🐈 قطط" : @"Cats";
    else if (self.selectedPetKindID == 3) sp = Language.isRTL ? @"🦜 طيور" : @"Birds";
    self.previewSpeciesBadge.text = [NSString stringWithFormat:@"  %@  ", sp];

    self.previewDurationBadge.text = [NSString stringWithFormat:@"⏱️ %@", self.selectedDuration];
}

#pragma mark - Actions & Delegations

- (void)textChanged {
    self.descPlaceholderLabel.hidden = (self.descriptionView.text.length > 0);
    [self updateLivePreview];
}

- (void)textViewDidChange:(UITextView *)textView {
    [self textChanged];
}

- (void)typePillTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedType = (PPServiceType)sender.tag;
    [self updateSelectionStyles];
    [self updateLivePreview];
}

- (void)speciesPillTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedPetKindID = sender.tag;
    [self updateSelectionStyles];
    [self updateLivePreview];
}

- (void)durationTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedDuration = [sender titleForState:UIControlStateNormal];
    [self updateSelectionStyles];
    [self updateLivePreview];
}

- (void)deliveryTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.selectedDelivery = [sender titleForState:UIControlStateNormal];
    [self updateSelectionStyles];
}

- (void)presetTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *val = objc_getAssociatedObject(sender, "preset_val");
    if (val) {
        self.priceField.text = val;
        [self updateLivePreview];
    }
}

- (void)inclusionToggled:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *text = [sender titleForState:UIControlStateNormal];
    if ([self.selectedInclusions containsObject:text]) {
        [self.selectedInclusions removeObject:text];
        sender.backgroundColor = [UIColor ppSurface];
        [sender setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
        sender.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    } else {
        [self.selectedInclusions addObject:text];
        sender.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
        [sender setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        sender.layer.borderColor = AppPrimaryClr.CGColor;
    }
}

- (void)updateSelectionStyles {
    for (UIButton *btn in self.typeButtons) {
        BOOL isSel = (btn.tag == (NSInteger)self.selectedType);
        [self applySelectionStyle:isSel toButton:btn];
    }

    for (UIButton *btn in self.speciesButtons) {
        BOOL isSel = (btn.tag == self.selectedPetKindID);
        [self applySelectionStyle:isSel toButton:btn];
    }

    for (UIButton *btn in self.durationButtons) {
        BOOL isSel = [[btn titleForState:UIControlStateNormal] isEqualToString:self.selectedDuration];
        [self applySelectionStyle:isSel toButton:btn];
    }

    for (UIButton *btn in self.deliveryButtons) {
        BOOL isSel = [[btn titleForState:UIControlStateNormal] isEqualToString:self.selectedDelivery];
        [self applySelectionStyle:isSel toButton:btn];
    }
}

- (void)applySelectionStyle:(BOOL)selected toButton:(UIButton *)btn {
    if (selected) {
        btn.backgroundColor = [UIColor ppPrimary];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.layer.borderWidth = 0.0;
        PPApplyButtonShadow(btn);
    } else {
        btn.backgroundColor = [UIColor ppSurface];
        [btn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        btn.layer.shadowOpacity = 0.0;
    }
}

#pragma mark - Photo Picking

- (void)changePhotoTapped {
    [PPFunc pp_playTapEffect];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:Language.isRTL ? @"صورة الخدمة" : @"Service Photo"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:Language.isRTL ? @"التقاط صورة بالكاميرا" : @"Take Photo"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self openImagePickerWithSource:UIImagePickerControllerSourceTypeCamera];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:Language.isRTL ? @"اختيار من المعرض" : @"Choose from Library"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self openImagePickerWithSource:UIImagePickerControllerSourceTypePhotoLibrary];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openImagePickerWithSource:(UIImagePickerControllerSourceType)source {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = source;
    picker.delegate = self;
    picker.allowsEditing = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (img) {
        self.selectedImage = img;
        self.hasNewPhotoSelected = YES;
        self.photoImageView.image = img;
        self.previewImageView.image = img;
    }
}

#pragma mark - Save Operation

- (void)saveServiceTapped {
    [PPFunc pp_playTapEffect];

    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        [PPHUD showError:Language.isRTL ? @"يرجى كتابة عنوان الخدمة" : @"Please enter service title"];
        [self.titleField becomeFirstResponder];
        return;
    }

    double price = [self.priceField.text doubleValue];
    if (price <= 0.0) {
        [PPHUD showError:Language.isRTL ? @"يرجى إدخال سعر صالح للخدمة" : @"Please enter a valid price"];
        [self.priceField becomeFirstResponder];
        return;
    }

    NSString *desc = [self.descriptionView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    PPServiceModel *model = self.serviceToEdit ?: [[PPServiceModel alloc] init];
    model.title = title;
    model.descriptionText = desc;
    model.price = price;
    model.currency = @"QAR";
    model.type = self.selectedType;
    model.petMainKindID = self.selectedPetKindID;
    model.isAvailable = self.availabilitySwitch.isOn;

    if (self.selectedType == PPServiceTypeGrooming) {
        model.category = Language.isRTL ? @"حلاقة وعناية" : @"Grooming";
    } else {
        model.category = Language.isRTL ? @"تدريب وسلوك" : @"Training";
    }

    [PPHUD showIndeterminateIn:self.view title:Language.isRTL ? @"جارٍ نشر وتحديث الخدمة..." : @"Publishing Service..." subtitle:nil];

    __weak typeof(self) weakSelf = self;
    if (self.isEditingMode) {
        [[PPServiceManager sharedManager] updateService:model image:self.selectedImage completion:^(NSError * _Nullable error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:Language.isRTL ? @"تم تحديث الخدمة بنجاح" : @"Service updated successfully"];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            }
        }];
    } else {
        [[PPServiceManager sharedManager] addService:model image:self.selectedImage completion:^(NSError * _Nullable error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:Language.isRTL ? @"تم إنشاء ونشر الخدمة بنجاح!" : @"Service published successfully!"];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            }
        }];
    }
}

#pragma mark - UI Factory Helpers

- (UIView *)makeSectionCard {
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(card, PPCornerCard);
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(card);
    return card;
}

- (UILabel *)makeSectionHeaderTitle:(NSString *)title icon:(NSString *)iconName {
    UILabel *header = [UILabel new];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.text = [NSString stringWithFormat:@"%@  %@", iconName ? @"" : @"", title];
    header.font = [Styling fontBold:14.5];
    header.textColor = PrimaryTextClr;
    header.textAlignment = Language.alignmentForCurrentLanguage;
    return header;
}

- (UIButton *)makePillButtonWithTitle:(NSString *)title tag:(NSInteger)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = tag;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontBold:12.5];
    PPApplyContinuousCorners(btn, 10.0);
    return btn;
}

- (UIButton *)makeChecklistButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontMedium:12.0];
    btn.backgroundColor = [UIColor ppSurface];
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(btn, 10.0);
    btn.contentEdgeInsets = UIEdgeInsetsMake(8, 10, 8, 10);
    [btn addTarget:self action:@selector(inclusionToggled:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

@end
