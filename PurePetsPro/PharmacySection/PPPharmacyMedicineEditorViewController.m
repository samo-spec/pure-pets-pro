//
//  PPPharmacyMedicineEditorViewController.m
//  Pure Pets Pro
//
//  Created from absolute first principles. Flagship medical editor
//  with card sections, category chips selector, animal targets multi-select,
//  camera/photo picker, and haptic feedback.
//

#import "PPPharmacyMedicineEditorViewController.h"
#import "PPVetManager.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "UIImageView+WebCache.h"
#import "PPHUD.h"
#import "PPFunc.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface PPPharmacyMedicineEditorViewController () <UITextFieldDelegate, UITextViewDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong, nullable) PPVetMedicineModel *medicine;
@property (nonatomic, copy) PPPharmacyMedicineEditorCompletion completion;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

// Photo Picker
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong) UIImage *selectedImage;

// Fields
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextField *categoryField;
@property (nonatomic, strong) UITextView *descTextView;
@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UITextField *stockField;
@property (nonatomic, strong) UISwitch *availableSwitch;
@property (nonatomic, strong) UISwitch *publishedSwitch;

// Animal Types & Category Chips
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *selectedAnimals;
@property (nonatomic, strong) UIStackView *animalChipsStack;
@property (nonatomic, strong) UIStackView *categoryChipsStack;

@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation PPPharmacyMedicineEditorViewController

- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine completion:(PPPharmacyMedicineEditorCompletion)completion {
    self = [super init];
    if (self) {
        _medicine = [medicine copy];
        _completion = [completion copy];
        _selectedAnimals = [NSMutableOrderedSet orderedSet];
        if (_medicine.animalTypes.count > 0) {
            [_selectedAnimals addObjectsFromArray:_medicine.animalTypes];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    NSString *navTitle = self.medicine ? kLang(@"Pharmacy_Edit_Title") : kLang(@"Pharmacy_Add_Title");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:navTitle
                    showBack:YES];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.contentInset = UIEdgeInsetsMake(16, 0, 110, 0);
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_scrollView];
    
    _stackView = [[UIStackView alloc] init];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = 18;
    _stackView.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_stackView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [_stackView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16],
        [_stackView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16],
        [_stackView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_stackView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32]
    ]];
    
    [self buildPhotoHeader];
    [self buildBasicInfoSection];
    [self buildPricingSection];
    [self buildAnimalsSection];
    [self buildOptionsSection];
    [self buildSaveButton];
    
    [self populateData];
}

- (void)buildPhotoHeader {
    UIView *card = [self makeSectionCard];
    
    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_imageView, 26.0);
    _imageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapImg = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickImage)];
    [_imageView addGestureRecognizer:tapImg];
    [card addSubview:_imageView];
    
    _imagePickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    _imagePickerButton.backgroundColor = [UIColor ppPrimary];
    [_imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill"] forState:UIControlStateNormal];
    _imagePickerButton.tintColor = UIColor.whiteColor;
    PPApplyContinuousCorners(_imagePickerButton, 18.0);
    PPApplyButtonShadow(_imagePickerButton);
    [_imagePickerButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_imagePickerButton];
    
    UILabel *hintLbl = [[UILabel alloc] init];
    hintLbl.translatesAutoresizingMaskIntoConstraints = NO;
    hintLbl.text = [Language isRTL] ? @"اضغط لإضافة أو تغيير صورة المستحضر" : @"Tap to choose medicine image";
    hintLbl.font = [Styling fontMedium:12.5];
    hintLbl.textColor = [UIColor ppTextSecondary];
    hintLbl.textAlignment = NSTextAlignmentCenter;
    [card addSubview:hintLbl];
    
    [NSLayoutConstraint activateConstraints:@[
        [_imageView.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [_imageView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [_imageView.widthAnchor constraintEqualToConstant:110],
        [_imageView.heightAnchor constraintEqualToConstant:110],
        
        [_imagePickerButton.trailingAnchor constraintEqualToAnchor:_imageView.trailingAnchor constant:6],
        [_imagePickerButton.bottomAnchor constraintEqualToAnchor:_imageView.bottomAnchor constant:6],
        [_imagePickerButton.widthAnchor constraintEqualToConstant:36],
        [_imagePickerButton.heightAnchor constraintEqualToConstant:36],
        
        [hintLbl.topAnchor constraintEqualToAnchor:_imageView.bottomAnchor constant:12],
        [hintLbl.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [hintLbl.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [hintLbl.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [_stackView addArrangedSubview:card];
}

- (void)buildBasicInfoSection {
    UIView *card = [self makeSectionCard];
    
    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Pharmacy_Section_Basic")];
    [card addSubview:header];
    
    _titleField = [self makeStyledFieldWithPlaceholder:kLang(@"Pharmacy_Field_Title") icon:@"pill.fill"];
    [card addSubview:_titleField];
    
    _categoryField = [self makeStyledFieldWithPlaceholder:kLang(@"Pharmacy_Field_Category") icon:@"tag.fill"];
    [card addSubview:_categoryField];
    
    // Category Suggestion Rail
    UIScrollView *catScroll = [[UIScrollView alloc] init];
    catScroll.translatesAutoresizingMaskIntoConstraints = NO;
    catScroll.showsHorizontalScrollIndicator = NO;
    catScroll.alwaysBounceHorizontal = YES;
    [card addSubview:catScroll];
    
    _categoryChipsStack = [[UIStackView alloc] init];
    _categoryChipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryChipsStack.axis = UILayoutConstraintAxisHorizontal;
    _categoryChipsStack.spacing = 6;
    _categoryChipsStack.alignment = UIStackViewAlignmentCenter;
    [catScroll addSubview:_categoryChipsStack];
    
    NSArray *suggestions = @[
        kLang(@"Pharmacy_Category_Vitamins"),
        kLang(@"Pharmacy_Category_Antibiotics"),
        kLang(@"Pharmacy_Category_Deworming"),
        kLang(@"Pharmacy_Category_Vaccines"),
        kLang(@"Pharmacy_Category_FirstAid"),
        kLang(@"Pharmacy_Category_SkinCoat"),
        kLang(@"Pharmacy_Category_EyeEar"),
        kLang(@"Pharmacy_Category_Digestive"),
        kLang(@"Pharmacy_Category_PainRelief"),
        kLang(@"Pharmacy_Category_Other")
    ];
    for (NSString *s in suggestions) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        chip.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        chip.titleLabel.font = [Styling fontBold:11.5];
        [chip setTitle:s forState:UIControlStateNormal];
        [chip setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
        chip.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(chip, PPCornerPill);
        [chip addTarget:self action:@selector(categoryChipPicked:) forControlEvents:UIControlEventTouchUpInside];
        [_categoryChipsStack addArrangedSubview:chip];
    }
    
    UILabel *descHeader = [[UILabel alloc] init];
    descHeader.translatesAutoresizingMaskIntoConstraints = NO;
    descHeader.text = kLang(@"Pharmacy_Field_Description");
    descHeader.font = [Styling fontMedium:12.5];
    descHeader.textColor = [UIColor ppTextSecondary];
    descHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:descHeader];
    
    _descTextView = [[UITextView alloc] init];
    _descTextView.translatesAutoresizingMaskIntoConstraints = NO;
    _descTextView.font = [Styling fontRegular:15.0];
    _descTextView.textColor = [UIColor ppTextPrimary];
    _descTextView.backgroundColor = [UIColor ppSurface];
    _descTextView.layer.borderWidth = 1.0;
    _descTextView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _descTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    _descTextView.textAlignment = Language.alignmentForCurrentLanguage;
    PPApplyContinuousCorners(_descTextView, PPCornerMedium);
    [card addSubview:_descTextView];
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [_titleField.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [_titleField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_titleField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_titleField.heightAnchor constraintEqualToConstant:50],
        
        [_categoryField.topAnchor constraintEqualToAnchor:_titleField.bottomAnchor constant:12],
        [_categoryField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_categoryField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_categoryField.heightAnchor constraintEqualToConstant:50],
        
        [catScroll.topAnchor constraintEqualToAnchor:_categoryField.bottomAnchor constant:8],
        [catScroll.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [catScroll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [catScroll.heightAnchor constraintEqualToConstant:32],
        
        [_categoryChipsStack.topAnchor constraintEqualToAnchor:catScroll.topAnchor],
        [_categoryChipsStack.leadingAnchor constraintEqualToAnchor:catScroll.leadingAnchor],
        [_categoryChipsStack.trailingAnchor constraintEqualToAnchor:catScroll.trailingAnchor],
        [_categoryChipsStack.bottomAnchor constraintEqualToAnchor:catScroll.bottomAnchor],
        [_categoryChipsStack.heightAnchor constraintEqualToAnchor:catScroll.heightAnchor],
        
        [descHeader.topAnchor constraintEqualToAnchor:catScroll.bottomAnchor constant:12],
        [descHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [descHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [_descTextView.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:6],
        [_descTextView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_descTextView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_descTextView.heightAnchor constraintEqualToConstant:90],
        [_descTextView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [_stackView addArrangedSubview:card];
}

- (void)categoryChipPicked:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.categoryField.text = [sender titleForState:UIControlStateNormal];
}

- (void)buildPricingSection {
    UIView *card = [self makeSectionCard];
    
    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Pharmacy_Section_Pricing")];
    [card addSubview:header];
    
    _priceField = [self makeStyledFieldWithPlaceholder:kLang(@"Pharmacy_Field_Price") icon:@"banknote.fill"];
    _priceField.keyboardType = UIKeyboardTypeDecimalPad;
    [card addSubview:_priceField];
    
    _stockField = [self makeStyledFieldWithPlaceholder:kLang(@"Pharmacy_Field_Quantity") icon:@"number"];
    _stockField.keyboardType = UIKeyboardTypeNumberPad;
    [card addSubview:_stockField];
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [_priceField.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [_priceField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_priceField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_priceField.heightAnchor constraintEqualToConstant:50],
        
        [_stockField.topAnchor constraintEqualToAnchor:_priceField.bottomAnchor constant:12],
        [_stockField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_stockField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_stockField.heightAnchor constraintEqualToConstant:50],
        [_stockField.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [_stackView addArrangedSubview:card];
}

- (void)buildAnimalsSection {
    UIView *card = [self makeSectionCard];
    
    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Pharmacy_Field_AnimalTypes")];
    [card addSubview:header];
    
    UILabel *subHeader = [[UILabel alloc] init];
    subHeader.translatesAutoresizingMaskIntoConstraints = NO;
    subHeader.text = kLang(@"Pharmacy_Field_AnimalTypes_Hint");
    subHeader.font = [Styling fontMedium:12.0];
    subHeader.textColor = [UIColor ppTextSecondary];
    subHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:subHeader];
    
    UIScrollView *animalsScroll = [[UIScrollView alloc] init];
    animalsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    animalsScroll.showsHorizontalScrollIndicator = NO;
    animalsScroll.alwaysBounceHorizontal = YES;
    [card addSubview:animalsScroll];
    
    _animalChipsStack = [[UIStackView alloc] init];
    _animalChipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _animalChipsStack.axis = UILayoutConstraintAxisHorizontal;
    _animalChipsStack.spacing = 8;
    _animalChipsStack.alignment = UIStackViewAlignmentCenter;
    [animalsScroll addSubview:_animalChipsStack];
    
    NSArray *animals = @[
        @{@"name": kLang(@"Pharmacy_Animal_Cats"), @"emoji": @"🐱"},
        @{@"name": kLang(@"Pharmacy_Animal_Dogs"), @"emoji": @"🐶"},
        @{@"name": kLang(@"Pharmacy_Animal_Birds"), @"emoji": @"🦜"},
        @{@"name": kLang(@"Pharmacy_Animal_Horses"), @"emoji": @"🐎"},
        @{@"name": kLang(@"Pharmacy_Animal_Rabbits"), @"emoji": @"🐰"},
        @{@"name": kLang(@"Pharmacy_Animal_Falcons"), @"emoji": @"🦅"}
    ];
    
    for (NSDictionary *dict in animals) {
        NSString *name = dict[@"name"];
        NSString *title = [NSString stringWithFormat:@"%@ %@", dict[@"emoji"], name];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.contentEdgeInsets = UIEdgeInsetsMake(7, 12, 7, 12);
        btn.titleLabel.font = [Styling fontBold:12.5];
        [btn setTitle:title forState:UIControlStateNormal];
        PPApplyContinuousCorners(btn, PPCornerPill);
        btn.tag = [animals indexOfObject:dict];
        
        BOOL isSel = [self.selectedAnimals containsObject:name];
        [self updateAnimalButton:btn isSelected:isSel];
        
        [btn addTarget:self action:@selector(animalChipToggled:) forControlEvents:UIControlEventTouchUpInside];
        [_animalChipsStack addArrangedSubview:btn];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [subHeader.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:4],
        [subHeader.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [subHeader.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [animalsScroll.topAnchor constraintEqualToAnchor:subHeader.bottomAnchor constant:12],
        [animalsScroll.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [animalsScroll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [animalsScroll.heightAnchor constraintEqualToConstant:38],
        [animalsScroll.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        
        [_animalChipsStack.topAnchor constraintEqualToAnchor:animalsScroll.topAnchor],
        [_animalChipsStack.leadingAnchor constraintEqualToAnchor:animalsScroll.leadingAnchor],
        [_animalChipsStack.trailingAnchor constraintEqualToAnchor:animalsScroll.trailingAnchor],
        [_animalChipsStack.bottomAnchor constraintEqualToAnchor:animalsScroll.bottomAnchor],
        [_animalChipsStack.heightAnchor constraintEqualToAnchor:animalsScroll.heightAnchor]
    ]];
    
    [_stackView addArrangedSubview:card];
}

- (void)updateAnimalButton:(UIButton *)btn isSelected:(BOOL)isSelected {
    if (isSelected) {
        btn.backgroundColor = [UIColor ppPrimary];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.layer.borderWidth = 0;
        PPApplyButtonShadow(btn);
    } else {
        btn.backgroundColor = [UIColor ppSurface];
        [btn setTitleColor:[UIColor ppTextSecondary] forState:UIControlStateNormal];
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        btn.layer.shadowOpacity = 0;
    }
}

- (void)animalChipToggled:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSArray *animals = @[
        kLang(@"Pharmacy_Animal_Cats"),
        kLang(@"Pharmacy_Animal_Dogs"),
        kLang(@"Pharmacy_Animal_Birds"),
        kLang(@"Pharmacy_Animal_Horses"),
        kLang(@"Pharmacy_Animal_Rabbits"),
        kLang(@"Pharmacy_Animal_Falcons")
    ];
    if (sender.tag < animals.count) {
        NSString *name = animals[sender.tag];
        if ([self.selectedAnimals containsObject:name]) {
            [self.selectedAnimals removeObject:name];
            [self updateAnimalButton:sender isSelected:NO];
        } else {
            [self.selectedAnimals addObject:name];
            [self updateAnimalButton:sender isSelected:YES];
        }
    }
}

- (void)buildOptionsSection {
    UIView *card = [self makeSectionCard];
    
    UILabel *header = [self makeSectionHeaderTitle:kLang(@"Pharmacy_Section_Options")];
    [card addSubview:header];
    
    _availableSwitch = [[UISwitch alloc] init];
    _availableSwitch.onTintColor = [UIColor ppPrimary];
    UIView *availRow = [self makeSwitchRowWithTitle:kLang(@"Pharmacy_Field_Availability")
                                           subtitle:kLang(@"Pharmacy_Status_Available")
                                             switch:_availableSwitch];
    [card addSubview:availRow];
    
    _publishedSwitch = [[UISwitch alloc] init];
    _publishedSwitch.onTintColor = [UIColor ppPrimary];
    UIView *pubRow = [self makeSwitchRowWithTitle:kLang(@"Pharmacy_Field_Published")
                                         subtitle:[Language isRTL] ? @"الظهور في نتائج البحث العامة" : @"Display in search catalog"
                                           switch:_publishedSwitch];
    [card addSubview:pubRow];
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [availRow.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [availRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [availRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [pubRow.topAnchor constraintEqualToAnchor:availRow.bottomAnchor constant:12],
        [pubRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [pubRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [pubRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [_stackView addArrangedSubview:card];
}

- (UIView *)makeSwitchRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle switch:(UISwitch *)switchControl {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor ppSurface];
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(row, PPCornerMedium);
    
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = title;
    titleLbl.font = [Styling fontBold:15.0];
    titleLbl.textColor = [UIColor ppTextPrimary];
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:titleLbl];
    
    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text = subtitle;
    subLbl.font = [Styling fontMedium:12.0];
    subLbl.textColor = [UIColor ppTextSecondary];
    subLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:subLbl];
    
    switchControl.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:switchControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [titleLbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:switchControl.leadingAnchor constant:-12],
        
        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:2],
        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [subLbl.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        
        [switchControl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [switchControl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    return row;
}

- (UIView *)makeSectionCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppSurfaceElevated];
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(card, PPCornerCard);
    PPApplyCardShadow(card);
    return card;
}

- (UILabel *)makeSectionHeaderTitle:(NSString *)title {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title;
    lbl.font = [Styling fontBold:16.0];
    lbl.textColor = [UIColor ppTextPrimary];
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    return lbl;
}

- (UITextField *)makeStyledFieldWithPlaceholder:(NSString *)placeholder icon:(NSString *)iconName {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.font = [Styling fontMedium:15.0];
    field.textColor = [UIColor ppTextPrimary];
    field.backgroundColor = [UIColor ppSurface];
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    field.textAlignment = Language.alignmentForCurrentLanguage;
    PPApplyContinuousCorners(field, PPCornerMedium);
    
    UIView *padView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 42, 50)];
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(14, 15, 20, 20)];
    icon.image = [UIImage systemImageNamed:iconName];
    icon.tintColor = [UIColor ppPrimary];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [padView addSubview:icon];
    
    if ([Language isRTL]) {
        field.rightView = padView;
        field.rightViewMode = UITextFieldViewModeAlways;
        field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 50)];
        field.leftViewMode = UITextFieldViewModeAlways;
    } else {
        field.leftView = padView;
        field.leftViewMode = UITextFieldViewModeAlways;
        field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 50)];
        field.rightViewMode = UITextFieldViewModeAlways;
    }
    return field;
}

- (void)buildSaveButton {
    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.backgroundColor = [UIColor ppPrimary];
    [_saveButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    [_saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:17.0];
    PPApplyContinuousCorners(_saveButton, PPCornerMedium);
    PPApplyButtonShadow(_saveButton);
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_saveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_saveButton.heightAnchor constraintEqualToConstant:54],
        [_saveButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12]
    ]];
}

- (void)populateData {
    if (!self.medicine) {
        self.availableSwitch.on = YES;
        self.publishedSwitch.on = YES;
        return;
    }
    
    self.titleField.text = self.medicine.title;
    self.descTextView.text = self.medicine.medicineDescription;
    self.categoryField.text = self.medicine.category;
    if (self.medicine.price > 0) {
        self.priceField.text = [NSString stringWithFormat:@"%.2f", self.medicine.price];
    }
    self.stockField.text = [NSString stringWithFormat:@"%ld", (long)MAX(0, self.medicine.stockQuantity)];
    self.availableSwitch.on = self.medicine.isAvailable;
    self.publishedSwitch.on = self.medicine.isPublished;
    
    if (self.medicine.imageUrl.length > 0) {
        [self.imageView sd_setImageWithURL:[NSURL URLWithString:self.medicine.imageUrl]
                          placeholderImage:[UIImage systemImageNamed:@"pills.fill"]];
    }
}

#pragma mark - Photo Picking

- (void)pickImage {
    [PPFunc pp_playTapEffect];
    
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[Language isRTL] ? @"التقاط بالكاميرا" : @"Take Photo"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            picker.delegate = self;
            [self presentViewController:picker animated:YES completion:nil];
        }]];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:[Language isRTL] ? @"اختيار من الصور" : @"Photo Library"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        if (@available(iOS 14.0, *)) {
            PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
            config.selectionLimit = 1;
            config.filter = [PHPickerFilter imagesFilter];
            PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
            picker.delegate = self;
            [self presentViewController:picker animated:YES completion:nil];
        } else {
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            picker.delegate = self;
            [self presentViewController:picker animated:YES completion:nil];
        }
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    
    NSItemProvider *provider = results.firstObject.itemProvider;
    if ([provider canLoadObjectOfClass:[UIImage class]]) {
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
            if ([object isKindOfClass:[UIImage class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.selectedImage = (UIImage *)object;
                    self.imageView.image = self.selectedImage;
                });
            }
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (img) {
        self.selectedImage = img;
        self.imageView.image = img;
    }
}

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    
    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:[Language isRTL] ? @"يرجى إدخال اسم المستحضر الطبي" : @"Please enter medicine title"];
        return;
    }
    
    double price = [self.priceField.text doubleValue];
    if (price <= 0) {
        [PPHUD showError:kLang(@"Error") subtitle:[Language isRTL] ? @"يرجى إدخال سعر صحيح للدواء" : @"Please enter valid price"];
        return;
    }
    
    PPVetMedicineModel *edited = self.medicine ? [self.medicine copy] : [[PPVetMedicineModel alloc] init];
    edited.title = title;
    edited.medicineDescription = self.descTextView.text;
    edited.category = [self.categoryField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    edited.price = price;
    edited.stockQuantity = MAX(0, [self.stockField.text integerValue]);
    edited.isAvailable = self.availableSwitch.isOn && (edited.stockQuantity > 0);
    edited.isPublished = self.publishedSwitch.isOn;
    edited.animalTypes = self.selectedAnimals.array;
    edited.currency = self.medicine.currency ?: @"QAR";
    
    if (self.completion) {
        self.completion(edited, self.selectedImage);
    }
}

@end
