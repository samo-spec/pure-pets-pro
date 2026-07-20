//
//  PPAddEditServiceViewController.m
//  PurePetsPro
//
//  Modernized: premium profile-matching UI with hero header, accent-bar section
//  headers, card-style cells, decorative backdrop glows, floating save button.
//

#import "PPAddEditServiceViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPFirebaseCompat.h"
#import "PPRolePermission.h"

static NSString * const kTagTitle       = @"serviceTitle";
static NSString * const kTagDescription = @"serviceDescription";
static NSString * const kTagPrice       = @"servicePrice";
static NSString * const kTagType        = @"serviceType";
static NSString * const kTagCategory    = @"serviceCategory";
static NSString * const kTagImage       = @"serviceImage";
static NSString * const kTagKindID      = @"servicePetMainKindID";
static NSString * const kTagAvailable   = @"serviceAvailable";

@interface PPAddEditServiceViewController ()
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIButton *floatingSaveButton;
@end

@implementation PPAddEditServiceViewController

#pragma mark - Colors (matching profile VC design)

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
}

- (UIColor *)pp_brandColor {
    return AppPrimaryClr ?: [UIColor systemOrangeColor];
}

#pragma mark - Init

- (instancetype)initWithService:(PPServiceModel *)service {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    self = [super initWithForm:form style:UITableViewStyleGrouped];
    if (self) {
        _serviceToEdit = service;
        _isEditing = (service != nil);
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [self pp_canvasColor];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 88.0, 0);
    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 20.0, 0, 20.0);
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self pp_setupBackdropGlows];
    [self pp_buildHeroHeader];
    [self buildForm];
    [self pp_setupFloatingSaveButton];
    if (self.isEditing) [self populateForm];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *title = self.isEditing ? kLang(@"EditService") : kLang(@"AddService");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateGlowsForCurrentStyle];
        [self pp_updateSaveButtonStyle];
        [self.tableView reloadData];
    }
}

#pragma mark - Backdrop Glows

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 110.0;
    self.bgGlowTop.layer.masksToBounds = NO;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 100.0;
    self.bgGlowBottom.layer.masksToBounds = NO;
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

    [self pp_updateGlowsForCurrentStyle];
}

- (void)pp_updateGlowsForCurrentStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    self.bgGlowTop.backgroundColor = [UIColor colorWithRed:0.93 green:0.80 blue:0.69 alpha:isDark ? 0.06 : 0.12];
    self.bgGlowTop.layer.shadowColor = [UIColor colorWithRed:0.98 green:0.82 blue:0.60 alpha:1.0].CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.10;
    self.bgGlowTop.layer.shadowRadius = 64.0;
    self.bgGlowTop.layer.shadowOffset = CGSizeZero;

    self.bgGlowBottom.backgroundColor = [UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.03 : 0.08;
    self.bgGlowBottom.layer.shadowRadius = 72.0;
    self.bgGlowBottom.layer.shadowOffset = CGSizeZero;
}

#pragma mark - Hero Header

- (void)pp_buildHeroHeader {
    CGFloat headerW = self.view.bounds.size.width;
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, headerW, 178.0)];
    root.backgroundColor = UIColor.clearColor;

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self pp_surfaceColor];
    card.layer.cornerRadius = 28.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self pp_borderColor].CGColor;
    card.clipsToBounds = NO;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = isDark ? 0.025 : 0.065;
    card.layer.shadowRadius = 20.0;
    card.layer.shadowOffset = CGSizeMake(0, 12.0);
    [root addSubview:card];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:root.topAnchor constant:12.0],
        [card.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20.0],
        [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20.0],
        [card.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12.0]
    ]];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = [self pp_brandColor];
    accentBar.layer.cornerRadius = 2.0;
    [card addSubview:accentBar];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [[self pp_brandColor] colorWithAlphaComponent:isDark ? 0.16 : 0.10];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    NSString *iconName = self.isEditing ? @"pencil.and.outline" : @"cross.case.fill";
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image = [UIImage systemImageNamed:iconName
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]];
    iconView.tintColor = [self pp_brandColor];
    iconView.contentMode = UIViewContentModeCenter;
    [iconSurface addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:24];
    titleLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = self.isEditing ? kLang(@"EditService") : kLang(@"AddService");
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    [card addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontMedium:13];
    subtitleLabel.textColor = SeconderyTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = self.isEditing ? kLang(@"Serv_Edit_Subtitle") : kLang(@"Serv_Add_Subtitle");
    [card addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.topAnchor constraintEqualToAnchor:card.topAnchor constant:24.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:58.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [iconSurface.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:24.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [iconSurface.widthAnchor constraintEqualToConstant:74.0],
        [iconSurface.heightAnchor constraintEqualToConstant:74.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:iconSurface.topAnchor constant:8.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:7.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-22.0]
    ]];

    self.tableView.tableHeaderView = root;
}

#pragma mark - Floating Save Button

- (void)pp_setupFloatingSaveButton {
    self.floatingSaveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.floatingSaveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.floatingSaveButton setTitle:kLang(@"Serv_Action_Save") forState:UIControlStateNormal];
    self.floatingSaveButton.titleLabel.font = [Styling fontBold:17];
    self.floatingSaveButton.layer.cornerRadius = 28.0;
    self.floatingSaveButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.floatingSaveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.floatingSaveButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.floatingSaveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.floatingSaveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [self.floatingSaveButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [self.floatingSaveButton.heightAnchor constraintEqualToConstant:56.0]
    ]];

    [self pp_updateSaveButtonStyle];
}

- (void)pp_updateSaveButtonStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.floatingSaveButton.backgroundColor = [self pp_brandColor];
    [self.floatingSaveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.floatingSaveButton.layer.shadowColor = [self pp_brandColor].CGColor;
    self.floatingSaveButton.layer.shadowOpacity = isDark ? 0.15 : 0.30;
    self.floatingSaveButton.layer.shadowRadius = 14.0;
    self.floatingSaveButton.layer.shadowOffset = CGSizeMake(0, 8.0);
}

#pragma mark - Section Headers (accent bar style)

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = nil;
    NSString *subtitle = nil;
    NSString *iconName = nil;

    switch (section) {
        case 0:
            title = kLang(@"Serv_Section_Info");
            subtitle = kLang(@"Serv_Section_Info_Hint");
            iconName = @"doc.text.fill";
            break;
        case 1:
            title = kLang(@"Serv_Section_Classification");
            subtitle = kLang(@"Serv_Section_Classification_Hint");
            iconName = @"tag.fill";
            break;
        case 2:
            title = kLang(@"Serv_Section_Availability");
            subtitle = kLang(@"Serv_Section_Availability_Hint");
            iconName = @"checkmark.circle.fill";
            break;
        case 3:
            title = kLang(@"Serv_Section_Media");
            subtitle = kLang(@"Serv_Section_Media_Hint");
            iconName = @"photo.fill";
            break;
        default:
            return nil;
    }

    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    // Accent bar
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [self pp_brandColor];
    bar.layer.cornerRadius = 2.0;
    [container addSubview:bar];

    // Section icon
    UIImageView *sectionIcon = [[UIImageView alloc] init];
    sectionIcon.translatesAutoresizingMaskIntoConstraints = NO;
    sectionIcon.image = [UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
    sectionIcon.tintColor = [self pp_brandColor];
    sectionIcon.contentMode = UIViewContentModeCenter;
    [container addSubview:sectionIcon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [Styling fontBold:14];
    titleLbl.textColor = PrimaryTextClr ?: UIColor.labelColor;
    titleLbl.text = title;
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLbl.font = [Styling fontMedium:11];
    subtitleLbl.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    subtitleLbl.text = subtitle;
    subtitleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLbl.numberOfLines = 2;
    [container addSubview:subtitleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor constant:16.0],
        [bar.widthAnchor constraintEqualToConstant:28.0],
        [bar.heightAnchor constraintEqualToConstant:4.0],

        [sectionIcon.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [sectionIcon.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:9.0],
        [sectionIcon.widthAnchor constraintEqualToConstant:16.0],
        [sectionIcon.heightAnchor constraintEqualToConstant:16.0],

        [titleLbl.leadingAnchor constraintEqualToAnchor:sectionIcon.trailingAnchor constant:6.0],
        [titleLbl.centerYAnchor constraintEqualToAnchor:sectionIcon.centerYAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],

        [subtitleLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4.0],
        [subtitleLbl.leadingAnchor constraintEqualToAnchor:sectionIcon.leadingAnchor],
        [subtitleLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [subtitleLbl.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-8.0]
    ]];

    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section >= 4) return 0.01;
    return 68.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 8.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}

#pragma mark - Cell Styling

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 4) {
        cell.hidden = YES;
        cell.clipsToBounds = YES;
        cell.contentView.hidden = YES;
        return;
    }

    static const CGFloat kCardH = 20.0;
    static const CGFloat kCardV = 5.0;
    static const NSInteger kCardTag = 8802;

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    cell.clipsToBounds = NO;
    cell.contentView.clipsToBounds = NO;
    cell.contentView.backgroundColor = UIColor.clearColor;

    /* Card background view with inset */
    UIView *card = [cell.contentView viewWithTag:kCardTag];
    if (!card) {
        card = [[UIView alloc] init];
        card.tag = kCardTag;
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.userInteractionEnabled = NO;
        [cell.contentView insertSubview:card atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:kCardV],
            [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-kCardV],
            [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:kCardH],
            [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-kCardH],
        ]];
    }
    card.backgroundColor = [self pp_surfaceColor];
    card.layer.cornerRadius = 18.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [self pp_borderColor].CGColor;

    cell.layer.shadowColor = UIColor.blackColor.CGColor;
    cell.layer.shadowOpacity = isDark ? 0.015 : 0.035;
    cell.layer.shadowRadius = 10.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    cell.layer.masksToBounds = NO;

    cell.preservesSuperviewLayoutMargins = NO;
    cell.layoutMargins = UIEdgeInsetsMake(0, kCardH + 16, 0, kCardH + 16);

    cell.textLabel.font = [Styling fontBold:14.5];
    cell.textLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
    cell.detailTextLabel.font = [Styling fontMedium:13.5];
    cell.detailTextLabel.textColor = SeconderyTextClr ?: UIColor.secondaryLabelColor;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.layer.shadowOpacity = 0;
}

#pragma mark - Form

- (void)buildForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];

    // ── Section 0: Service Information ──
    XLFormSectionDescriptor *content = [XLFormSectionDescriptor formSection];
    [form addFormSection:content];

    XLFormRowDescriptor *title = [XLFormRowDescriptor formRowDescriptorWithTag:kTagTitle rowType:XLFormRowDescriptorTypeText title:kLang(@"Serv_Field_Title")];
    title.required = YES;
    [content addFormRow:title];

    XLFormRowDescriptor *desc = [XLFormRowDescriptor formRowDescriptorWithTag:kTagDescription rowType:XLFormRowDescriptorTypeTextView title:kLang(@"Serv_Field_Description")];
    desc.required = YES;
    [content addFormRow:desc];

    XLFormRowDescriptor *price = [XLFormRowDescriptor formRowDescriptorWithTag:kTagPrice rowType:XLFormRowDescriptorTypeDecimal title:kLang(@"Serv_Field_Price")];
    price.value = @(0.0);
    [content addFormRow:price];

    XLFormRowDescriptor *kindRow = [XLFormRowDescriptor formRowDescriptorWithTag:kTagKindID rowType:XLFormRowDescriptorTypeInteger title:kLang(@"Serv_Field_PetKind")];
    kindRow.value = @(0);
    [content addFormRow:kindRow];

    // ── Section 1: Classification ──
    XLFormSectionDescriptor *classSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:classSection];

    XLFormRowDescriptor *type = [XLFormRowDescriptor formRowDescriptorWithTag:kTagType rowType:XLFormRowDescriptorTypeSelectorSegmentedControl title:kLang(@"Serv_Field_Type")];
    type.selectorOptions = @[
        [XLFormOptionsObject formOptionsObjectWithValue:@(PPServiceTypeTraining) displayText:kLang(@"typeTraining")],
        [XLFormOptionsObject formOptionsObjectWithValue:@(PPServiceTypeGrooming) displayText:kLang(@"typeGrooming")]
    ];
    type.value = type.selectorOptions.firstObject;
    [classSection addFormRow:type];

    XLFormRowDescriptor *cat = [XLFormRowDescriptor formRowDescriptorWithTag:kTagCategory rowType:XLFormRowDescriptorTypeText title:kLang(@"Serv_Field_Category")];
    [classSection addFormRow:cat];

    // ── Section 2: Availability ──
    XLFormSectionDescriptor *availSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:availSection];

    XLFormRowDescriptor *availRow = [XLFormRowDescriptor formRowDescriptorWithTag:kTagAvailable rowType:XLFormRowDescriptorTypeBooleanSwitch title:kLang(@"Serv_Field_Available")];
    availRow.value = @YES;
    [availSection addFormRow:availRow];

    // ── Section 3: Media ──
    XLFormSectionDescriptor *mediaSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:mediaSection];

    XLFormRowDescriptor *imgRow = [XLFormRowDescriptor formRowDescriptorWithTag:kTagImage rowType:XLFormRowDescriptorTypePPImageCollection title:kLang(@"Serv_Field_Image")];
    imgRow.cellConfigAtConfigure[@"maxImages"] = @(1);
    if (self.isEditing && self.serviceToEdit.imageURL.length > 0) {
        imgRow.cellConfigAtConfigure[@"preloadImageURL"] = self.serviceToEdit.imageURL;
    }
    [mediaSection addFormRow:imgRow];

    // ── Section 4: Hidden save row (floating button replaces it) ──
    XLFormSectionDescriptor *btnSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:btnSection];

    XLFormRowDescriptor *save = [XLFormRowDescriptor formRowDescriptorWithTag:@"save" rowType:XLFormRowDescriptorTypeButton title:@""];
    save.action.formSelector = @selector(saveTapped);
    save.height = 0.01;
    [btnSection addFormRow:save];

    self.form = form;

    for (XLFormSectionDescriptor *sec in form.formSections) {
        for (XLFormRowDescriptor *row in sec.formRows) {
            [Styling applyGlobalStyleToRow:row];
        }
    }
}

- (void)populateForm {
    PPServiceModel *s = self.serviceToEdit;
    [self.form formRowWithTag:kTagTitle].value       = s.title;
    [self.form formRowWithTag:kTagDescription].value  = s.descriptionText;
    [self.form formRowWithTag:kTagPrice].value        = @(s.price);
    [self.form formRowWithTag:kTagCategory].value     = s.category;
    [self.form formRowWithTag:kTagKindID].value       = @(s.petMainKindID);
    [self.form formRowWithTag:kTagAvailable].value     = @(s.isAvailable);

    XLFormRowDescriptor *typeRow = [self.form formRowWithTag:kTagType];
    for (XLFormOptionsObject *opt in typeRow.selectorOptions) {
        if ([opt.formValue integerValue] == s.type) {
            typeRow.value = opt;
            break;
        }
    }
}

#pragma mark - Permission Check

- (BOOL)validatePermissions {
    FIRUser *currentUser = [FIRAuth auth].currentUser;
    if (!currentUser) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Serv_Not_Authenticated")];
        return NO;
    }

    UserModel *me = [UserManager shared].currentUser;
    BOOL allowed = NO;
    if (me.canOfferServices) allowed = YES;
    else if ([me hasPermissionNamed:kPermManageServices]) allowed = YES;
    else if ([me hasPermissionNamed:kPermAdminAll]) allowed = YES;
    else if (me.isSuperAdmin || me.isAdmin || me.role == UserRoleSuperAdmin || me.role == UserRoleAdmin) allowed = YES;

    if (!allowed) {
        [PPAlertHelper showConfirmationIn:self
                                   title:kLang(@"Serv_No_Permission")
                                subtitle:kLang(@"Serv_No_Permission_Msg")
                             placeholder:nil
                           confirmButton:kLang(@"OK")
                            cancelButton:nil
                            confirmBlock:nil
                             cancelBlock:nil];
        return NO;
    }

    if (self.isEditing && self.serviceToEdit.serviceOwnerID.length > 0) {
        if (![currentUser.uid isEqualToString:self.serviceToEdit.serviceOwnerID]) {
            BOOL isAdmin = me.isSuperAdmin || me.isAdmin || me.role == UserRoleSuperAdmin || me.role == UserRoleAdmin || [me hasPermissionNamed:kPermAdminAll] || [me hasPermissionNamed:kPermManageServices];
            if (!isAdmin) {
                [PPHUD showError:kLang(@"Error") subtitle:kLang(@"Serv_Ownership_Error")];
                return NO;
            }
        }
    }

    return YES;
}

#pragma mark - Actions

- (void)saveTapped {
    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        [self showFormValidationError:errors.firstObject];
        return;
    }

    if (![self validatePermissions]) return;

    NSDictionary *v = [self formValues];
    PPServiceModel *model = self.isEditing ? [self.serviceToEdit copy] : [[PPServiceModel alloc] init];

    model.title           = PPSafeString(v[kTagTitle]);
    model.descriptionText = PPSafeString(v[kTagDescription]);
    model.price           = [v[kTagPrice] doubleValue];
    model.category        = PPSafeString(v[kTagCategory]);
    model.petMainKindID   = [v[kTagKindID] integerValue];
    model.isAvailable     = [v[kTagAvailable] boolValue];

    id typeVal = v[kTagType];
    if ([typeVal respondsToSelector:@selector(formValue)]) {
        model.type = [[typeVal formValue] integerValue];
    }

    if (!self.isEditing) {
        model.serviceOwnerID = [FIRAuth auth].currentUser.uid ?: @"";
    }

    UIImage *img = nil;
    id imgVal = v[kTagImage];
    if ([imgVal isKindOfClass:[UIImage class]]) {
        img = (UIImage *)imgVal;
    }

    [PPHUD showIndeterminateIn:self.view title:kLang(@"Serv_Saving") subtitle:nil];

    __weak typeof(self) weakSelf = self;
    PPServiceVoidBlock done = ^(NSError *error) {
        [PPHUD dismiss];
        if (error) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            [PPHUD showSuccess:kLang(@"Saved")];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.navigationController popViewControllerAnimated:YES];
            });
        }
    };

    if (self.isEditing) {
        [[PPServiceManager sharedManager] updateService:model image:img completion:done];
    } else {
        [[PPServiceManager sharedManager] addService:model image:img completion:done];
    }
}

@end
