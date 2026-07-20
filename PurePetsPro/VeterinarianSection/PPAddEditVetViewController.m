//
//  PPAddEditVetViewController.m
//  PurePetsAdmin
//

#import "PPAddEditVetViewController.h"
#import "PPVetModel.h"
#import "PPVetManager.h"
#import "PPFirebaseCompat.h"
#import <PhotosUI/PhotosUI.h>

@interface PPAddEditVetViewController () <UITextViewDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

@property (nonatomic, strong) UIView *heroArea;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
@property (nonatomic, strong, nullable) UIImage *selectedImage;

@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextView *descriptionView;
@property (nonatomic, strong) UILabel *descriptionPlaceholder;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *whatsappField;
@property (nonatomic, strong) UITextField *costField;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UITextField *kindField;

@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, assign) BOOL isEditing;
@end

@implementation PPAddEditVetViewController

#pragma mark - Premium Colors

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.97 green:0.96 blue:0.95 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.06];
    }];
}

- (UserModel *)pp_currentUser {
    return UsrMgr.currentUser;
}

- (BOOL)pp_canCreateVetProfile {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canPostVetProfilePermission;
}

- (BOOL)pp_canEditVetProfile {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canEditVetInfoPermission;
}

- (instancetype)initWithVet:(PPVetModel *)vet {
    self = [super init];
    if (self) {
        _vetToEdit = vet;
        _isEditing = (vet != nil);
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];
    [self pp_setupBackdropGlows];
    [self pp_buildUI];
    [self pp_applyValues];
    [self pp_configureNavigation];
}

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 110.0;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 100.0;
    [self.view insertSubview:self.bgGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-72.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    [self pp_updateGlowsForStyle];
}

- (void)pp_updateGlowsForStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.05 : 0.10];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 60.0;
    
    self.bgGlowBottom.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor systemOrangeColor].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 70.0;
}

- (void)pp_configureNavigation {
    [self pp_navBarWithOtherButton:nil title:@""];
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;
}

- (void)pp_buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 100, 0);
    [self.view addSubview:self.scrollView];

    _heroArea = [[UIView alloc] init];
    _heroArea.translatesAutoresizingMaskIntoConstraints = NO;
    _heroArea.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:_heroArea];
    
    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = [self pp_surfaceColor];
    heroCard.layer.cornerRadius = 34.0;
    heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    heroCard.layer.borderWidth = 1.0;
    heroCard.layer.borderColor = [self pp_borderColor].CGColor;
    heroCard.clipsToBounds = YES;
    
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    heroCard.layer.shadowColor = UIColor.blackColor.CGColor;
    heroCard.layer.shadowOpacity = isDark ? 0.03 : 0.08;
    heroCard.layer.shadowRadius = 24.0;
    heroCard.layer.shadowOffset = CGSizeMake(0, 14.0);
    [_heroArea addSubview:heroCard];
    
    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    accentBar.layer.cornerRadius = 3.0;
    [heroCard addSubview:accentBar];

    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    _logoImageView.layer.cornerRadius = 34.0;
    _logoImageView.layer.cornerCurve = kCACornerCurveContinuous;
    _logoImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    _logoImageView.layer.borderWidth = 2.0;
    _logoImageView.layer.borderColor = [UIColor whiteColor].CGColor;
    _logoImageView.userInteractionEnabled = YES;
    [heroCard addSubview:_logoImageView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickImageTapped)];
    [_logoImageView addGestureRecognizer:tap];

    _imagePickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *camCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [_imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:camCfg] forState:UIControlStateNormal];
    _imagePickerButton.tintColor = AppPrimaryClr;
    _imagePickerButton.backgroundColor = [self pp_surfaceColor];
    _imagePickerButton.layer.cornerRadius = 16.0;
    _imagePickerButton.layer.borderWidth = 1.0;
    _imagePickerButton.layer.borderColor = [self pp_borderColor].CGColor;
    _imagePickerButton.layer.shadowColor = UIColor.blackColor.CGColor;
    _imagePickerButton.layer.shadowOpacity = 0.1;
    _imagePickerButton.layer.shadowOffset = CGSizeMake(0, 4);
    _imagePickerButton.layer.shadowRadius = 8.0;
    [_imagePickerButton addTarget:self action:@selector(pickImageTapped) forControlEvents:UIControlEventTouchUpInside];
    [heroCard addSubview:_imagePickerButton];

    UILabel *heroTitle = [[UILabel alloc] init];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.font = [Styling fontBold:26.0];
    heroTitle.textColor = PrimaryTextClr;
    heroTitle.textAlignment = NSTextAlignmentCenter;
    heroTitle.numberOfLines = 2;
    heroTitle.text = self.isEditing ? kLang(@"Vet_Edit_Title") : kLang(@"Vet_Add_Title");
    [heroCard addSubview:heroTitle];
    
    UILabel *heroSubtitle = [[UILabel alloc] init];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroSubtitle.font = [Styling fontMedium:13.0];
    heroSubtitle.textColor = SeconderyTextClr;
    heroSubtitle.textAlignment = NSTextAlignmentCenter;
    heroSubtitle.numberOfLines = 2;
    heroSubtitle.text = self.isEditing ? kLang(@"Vet_Edit_Subtitle") : kLang(@"Vet_Add_Subtitle");
    [heroCard addSubview:heroSubtitle];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 36.0;
    [self.scrollView addSubview:self.contentStack];

    [self pp_setupFormSections];

    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:kLang(@"Vet_Action_Save") forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:17.0];
    _saveButton.tintColor = UIColor.whiteColor;
    _saveButton.backgroundColor = AppPrimaryClr;
    _saveButton.layer.cornerRadius = 28.0;
    _saveButton.layer.cornerCurve = kCACornerCurveContinuous;
    _saveButton.layer.shadowColor = AppPrimaryClr.CGColor;
    _saveButton.layer.shadowOpacity = isDark ? 0.15 : 0.3;
    _saveButton.layer.shadowRadius = 16.0;
    _saveButton.layer.shadowOffset = CGSizeMake(0, 8);
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_heroArea.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [_heroArea.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor],
        [_heroArea.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor],
        [_heroArea.heightAnchor constraintEqualToConstant:320.0],

        [heroCard.topAnchor constraintEqualToAnchor:_heroArea.topAnchor constant:12.0],
        [heroCard.leadingAnchor constraintEqualToAnchor:_heroArea.leadingAnchor constant:20.0],
        [heroCard.trailingAnchor constraintEqualToAnchor:_heroArea.trailingAnchor constant:-20.0],
        [heroCard.bottomAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:-12.0],
        
        [accentBar.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:20.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [_logoImageView.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [_logoImageView.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [_logoImageView.widthAnchor constraintEqualToConstant:108.0],
        [_logoImageView.heightAnchor constraintEqualToConstant:108.0],

        [_imagePickerButton.bottomAnchor constraintEqualToAnchor:_logoImageView.bottomAnchor constant:0.0],
        [_imagePickerButton.trailingAnchor constraintEqualToAnchor:_logoImageView.trailingAnchor constant:6.0],
        [_imagePickerButton.widthAnchor constraintEqualToConstant:32.0],
        [_imagePickerButton.heightAnchor constraintEqualToConstant:32.0],

        [heroTitle.topAnchor constraintEqualToAnchor:_logoImageView.bottomAnchor constant:12.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],
        
        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:4.0],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [self.contentStack.topAnchor constraintEqualToAnchor:_heroArea.bottomAnchor constant:20.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-40.0],

        [_saveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [_saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [_saveButton.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12.0],
        [_saveButton.heightAnchor constraintEqualToConstant:56.0],
    ]];
}

- (void)pp_setupFormSections {
    // Basic Info
    UIView *titleRow = [self pp_textFieldWithPlaceholder:kLang(@"Vet_Field_Name") icon:@"person.fill" field:&_titleField];
    
    // Type Segment
    UIView *typeBlock = [[UIView alloc] init];
    typeBlock.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *typeHeader = [self pp_sectionHeader:kLang(@"Vet_Field_Type") subtitle:kLang(@"Vet_Field_Type_Hint") icon:@"list.bullet.circle.fill"];
    
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[kLang(@"Vet_Type_Personal"), kLang(@"Vet_Type_Company")]];
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.selectedSegmentTintColor = AppPrimaryClr;
    [self.typeSegment setTitleTextAttributes:@{
        NSForegroundColorAttributeName: PrimaryTextClr,
        NSFontAttributeName: [Styling fontBold:14.0]
    } forState:UIControlStateNormal];
    [self.typeSegment setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [Styling fontBold:14.0]
    } forState:UIControlStateSelected];
    UIView *typeSurface = [self pp_surfaceFieldContainerWithView:self.typeSegment contentInsets:UIEdgeInsetsMake(7.0, 10.0, 7.0, 10.0)];
    
    [typeBlock addSubview:typeHeader];
    [typeBlock addSubview:typeSurface];
    [NSLayoutConstraint activateConstraints:@[
        [typeHeader.topAnchor constraintEqualToAnchor:typeBlock.topAnchor],
        [typeHeader.leadingAnchor constraintEqualToAnchor:typeBlock.leadingAnchor],
        [typeHeader.trailingAnchor constraintEqualToAnchor:typeBlock.trailingAnchor],
        [typeSurface.topAnchor constraintEqualToAnchor:typeHeader.bottomAnchor constant:12.0],
        [typeSurface.leadingAnchor constraintEqualToAnchor:typeBlock.leadingAnchor],
        [typeSurface.trailingAnchor constraintEqualToAnchor:typeBlock.trailingAnchor],
        [typeSurface.bottomAnchor constraintEqualToAnchor:typeBlock.bottomAnchor],
    ]];

    // Description
    UIView *descBlock = [[UIView alloc] init];
    descBlock.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *descHeader = [self pp_sectionHeader:kLang(@"Vet_Field_Description") subtitle:kLang(@"Vet_Field_Description_Hint") icon:@"doc.text.fill"];
    self.descriptionView = [self pp_textView];
    [descBlock addSubview:descHeader];
    [descBlock addSubview:self.descriptionView];
    [NSLayoutConstraint activateConstraints:@[
        [descHeader.topAnchor constraintEqualToAnchor:descBlock.topAnchor],
        [descHeader.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor],
        [descHeader.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor],
        [self.descriptionView.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:12.0],
        [self.descriptionView.leadingAnchor constraintEqualToAnchor:descBlock.leadingAnchor],
        [self.descriptionView.trailingAnchor constraintEqualToAnchor:descBlock.trailingAnchor],
        [self.descriptionView.bottomAnchor constraintEqualToAnchor:descBlock.bottomAnchor],
    ]];

    // Contact Info
    UIView *phoneRow = [self pp_textFieldWithPlaceholder:kLang(@"Vet_Field_Phone") icon:@"phone.fill" field:&_phoneField];
    self.phoneField.keyboardType = UIKeyboardTypePhonePad;
    UIView *whatsappRow = [self pp_textFieldWithPlaceholder:kLang(@"Vet_Field_Whatsapp") icon:@"message.fill" field:&_whatsappField];
    self.whatsappField.keyboardType = UIKeyboardTypePhonePad;

    // Financial & Date
    UIView *costRow = [self pp_textFieldWithPlaceholder:kLang(@"Vet_Field_Cost") icon:@"banknote.fill" field:&_costField];
    self.costField.keyboardType = UIKeyboardTypeDecimalPad;
    
    // Date Picker Container
    UIView *dateBlock = [[UIView alloc] init];
    dateBlock.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *dateHeader = [self pp_sectionHeader:kLang(@"Vet_Field_AvailableDate") subtitle:nil icon:@"calendar"];
    
    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    if (@available(iOS 13.4, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    UIView *dateSurface = [self pp_surfaceAccessoryRowWithIcon:@"calendar" control:self.datePicker];
    
    [dateBlock addSubview:dateHeader];
    [dateBlock addSubview:dateSurface];
    [NSLayoutConstraint activateConstraints:@[
        [dateHeader.topAnchor constraintEqualToAnchor:dateBlock.topAnchor],
        [dateHeader.leadingAnchor constraintEqualToAnchor:dateBlock.leadingAnchor],
        [dateHeader.trailingAnchor constraintEqualToAnchor:dateBlock.trailingAnchor],
        [dateSurface.topAnchor constraintEqualToAnchor:dateHeader.bottomAnchor constant:12.0],
        [dateSurface.leadingAnchor constraintEqualToAnchor:dateBlock.leadingAnchor],
        [dateSurface.trailingAnchor constraintEqualToAnchor:dateBlock.trailingAnchor],
        [dateSurface.bottomAnchor constraintEqualToAnchor:dateBlock.bottomAnchor]
    ]];

    // Pet Kind
    UIView *kindRow = [self pp_textFieldWithPlaceholder:kLang(@"Vet_Field_PetKindID") icon:@"pawprint.fill" field:&_kindField];
    self.kindField.keyboardType = UIKeyboardTypeNumberPad;

    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Vet_Section_Info") subtitle:kLang(@"Vet_Section_Info_Hint") icon:@"info.circle.fill" views:@[titleRow, typeBlock]]];
    [self.contentStack addArrangedSubview:descBlock];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Vet_Section_Contact") subtitle:kLang(@"Vet_Section_Contact_Hint") icon:@"person.crop.circle.badge.exclamationmark" views:@[phoneRow, whatsappRow]]];
    [self.contentStack addArrangedSubview:[self pp_sectionBlockWithTitle:kLang(@"Vet_Section_Details") subtitle:kLang(@"Vet_Section_Details_Hint") icon:@"dollarsign.circle.fill" views:@[costRow, dateBlock, kindRow]]];
}

- (UIView *)pp_sectionBlockWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [stack addArrangedSubview:[self pp_sectionHeader:title subtitle:subtitle icon:iconName]];
    for (UIView *v in views) [stack addArrangedSubview:v];
    return stack;
}

- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = AppPrimaryClr;
    bar.layer.cornerRadius = 2.0;
    [container addSubview:bar];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [container addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontBold:14];
    titleLbl.textColor = PrimaryTextClr;
    titleLbl.text = title;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLbl.font = [Styling fontMedium:11];
    subtitleLbl.textColor = SeconderyTextClr;
    subtitleLbl.text = subtitle;
    subtitleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLbl.numberOfLines = 2;
    subtitleLbl.alpha = 0.7;
    [container addSubview:subtitleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.widthAnchor constraintEqualToConstant:28.0],
        [bar.heightAnchor constraintEqualToConstant:4.0],

        [icon.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:9.0],
        [icon.widthAnchor constraintEqualToConstant:16.0],
        [icon.heightAnchor constraintEqualToConstant:16.0],

        [titleLbl.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6.0],
        [titleLbl.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4.0],
        [subtitleLbl.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
        [subtitleLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [subtitleLbl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (UIView *)pp_textFieldWithPlaceholder:(NSString *)placeholder icon:(NSString *)iconName field:(UITextField * _Nullable __strong *)fieldPtr {
    UIView *container = [self pp_surfaceContainer];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:icon];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.textColor = PrimaryTextClr;
    field.font = [Styling fontBold:15.0];
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                   attributes:@{NSForegroundColorAttributeName : [SeconderyTextClr colorWithAlphaComponent:0.3]}];
    // Arabic digits → English digits normalization for numeric keyboards
    [field addTarget:self action:@selector(pp_normalizeArabicDigitsForField:) forControlEvents:UIControlEventEditingChanged];
    [container addSubview:field];
    if (fieldPtr) *fieldPtr = field;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
        [field.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12.0],
        [field.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [field.topAnchor constraintEqualToAnchor:container.topAnchor],
        [field.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)pp_surfaceContainer {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [self pp_surfaceColor];
    container.layer.cornerRadius = 20.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [self pp_borderColor].CGColor;
    [container.heightAnchor constraintEqualToConstant:58.0].active = YES;
    return container;
}

- (UIView *)pp_surfaceFieldContainerWithView:(UIView *)contentView contentInsets:(UIEdgeInsets)contentInsets {
    UIView *container = [self pp_surfaceContainer];
    [container addSubview:contentView];
    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:container.topAnchor constant:contentInsets.top],
        [contentView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:contentInsets.left],
        [contentView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-contentInsets.right],
        [contentView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-contentInsets.bottom],
    ]];
    return container;
}

- (UIView *)pp_surfaceAccessoryRowWithIcon:(NSString *)iconName control:(UIView *)control {
    UIView *container = [self pp_surfaceContainer];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:icon];
    [container addSubview:control];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
        [control.leadingAnchor constraintGreaterThanOrEqualToAnchor:icon.trailingAnchor constant:12.0],
        [control.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [control.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
    ]];

    return container;
}

- (UITextView *)pp_textView {
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = [self pp_surfaceColor];
    textView.layer.cornerRadius = 20.0;
    textView.layer.cornerCurve = kCACornerCurveContinuous;
    textView.layer.borderWidth = 1.0;
    textView.layer.borderColor = [self pp_borderColor].CGColor;
    textView.textColor = PrimaryTextClr;
    textView.font = [Styling fontBold:15.0];
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    textView.delegate = self;
    textView.textContainerInset = UIEdgeInsetsMake(18.0, 14.0, 18.0, 14.0);
    [textView.heightAnchor constraintEqualToConstant:140.0].active = YES;

    self.descriptionPlaceholder = [[UILabel alloc] init];
    self.descriptionPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionPlaceholder.font = [Styling fontBold:15.0];
    self.descriptionPlaceholder.textColor = [SeconderyTextClr colorWithAlphaComponent:0.3];
    self.descriptionPlaceholder.text = kLang(@"Vet_Field_Description");
    [textView addSubview:self.descriptionPlaceholder];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionPlaceholder.topAnchor constraintEqualToAnchor:textView.topAnchor constant:18.0],
        [self.descriptionPlaceholder.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:18.0],
    ]];

    return textView;
}

- (void)pp_applyValues {
    if (!self.isEditing) {
        self.logoImageView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.logoImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
        self.logoImageView.contentMode = UIViewContentModeCenter;
        return;
    }

    PPVetModel *v = self.vetToEdit;
    self.titleField.text = v.title ?: @"";
    self.phoneField.text = v.phone ?: @"";
    self.whatsappField.text = v.whatsapp ?: @"";
    self.descriptionView.text = v.descriptionText ?: @"";
    self.costField.text = v.vetCost > 0 ? [NSString stringWithFormat:@"%.2f", v.vetCost] : @"";
    self.datePicker.date = v.availableDate ?: [NSDate date];
    self.kindField.text = [NSString stringWithFormat:@"%ld", (long)v.petMainKindID];
    
    self.typeSegment.selectedSegmentIndex = (v.type == PPVetTypeCompany) ? 1 : 0;
    
    [self pp_updateDescriptionPlaceholder];

    if (v.logoURL.length > 0) {
        [self.logoImageView setImageFromUrl:v.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
        self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        self.logoImageView.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.logoImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
        self.logoImageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self pp_updateGlowsForStyle];
        self.saveButton.layer.shadowColor = AppPrimaryClr.CGColor;
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self pp_updateDescriptionPlaceholder];
}

- (void)pp_updateDescriptionPlaceholder {
    self.descriptionPlaceholder.hidden = self.descriptionView.text.length > 0;
}

#pragma mark - Save

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    
    if ((self.isEditing && ![self pp_canEditVetProfile]) || (!self.isEditing && ![self pp_canCreateVetProfile])) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
        return;
    }

    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Vet_Validation_NameRequired")];
        return;
    }

    PPVetModel *model = self.vetToEdit ? [self.vetToEdit copy] : [[PPVetModel alloc] init];
    model.title           = title;
    model.phone           = PPSafeString(self.phoneField.text);
    model.whatsapp        = PPSafeString(self.whatsappField.text);
    model.descriptionText = PPSafeString(self.descriptionView.text);
    model.vetCost         = [self.costField.text doubleValue];
    model.availableDate   = self.datePicker.date;
    model.petMainKindID   = [self.kindField.text integerValue];
    model.type            = (self.typeSegment.selectedSegmentIndex == 1) ? PPVetTypeCompany : PPVetTypePersonal;

    if (!self.isEditing) {
        model.userID = [FIRAuth auth].currentUser.uid ?: @"";
        model.canEditProfile = YES;
        model.canPostServices = YES;
        model.canPostMedicines = NO;
        model.verificationStatus = @"pending";
    }
    
    if (model.animalTypes.count == 0 && model.petMainKindID > 0) {
        model.animalTypes = @[[NSString stringWithFormat:@"%ld", (long)model.petMainKindID]];
    }
    model.readyToContact = model.phone.length > 0 || model.whatsapp.length > 0;

    [PPHUD showIndeterminateIn:self.view title:kLang(@"Vet_Saving") subtitle:nil];

    __weak typeof(self) weakSelf = self;
    PPVetVoidBlock done = ^(NSError *error) {
        [PPHUD dismiss];
        if (error) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            return;
        }
        [PPHUD showSuccess:kLang(@"Success_Title") subtitle:self.isEditing ? kLang(@"Vet_Updated_Success") : kLang(@"Vet_Added_Success")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf.navigationController popViewControllerAnimated:YES];
        });
    };

    if (self.isEditing) {
        [[PPVetManager sharedManager] updateVet:model image:self.selectedImage completion:done];
    } else {
        [[PPVetManager sharedManager] addVet:model image:self.selectedImage completion:done];
    }
}

#pragma mark - Image Picker

- (void)pickImageTapped {
    [PPFunc pp_playTapEffect];
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *first = results.firstObject;
    if ([first.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        __weak typeof(self) weakSelf = self;
        [first.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if ([object isKindOfClass:[UIImage class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.selectedImage = (UIImage *)object;
                    weakSelf.logoImageView.image = weakSelf.selectedImage;
                    weakSelf.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
                });
            }
        }];
    }
}

- (void)pp_normalizeArabicDigitsForField:(UITextField *)textField {
    NSString *raw = textField.text;
    if (!raw.length) return;
    
    NSString *normalized = [PPFunc normalizedNumericString:raw];
    if (![normalized isEqualToString:raw]) {
        textField.text = normalized;
    }
}

@end
