#import "PPDeliveryCompanySetupViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPDeliveryCompanyDashboardViewController.h"

@interface PPDeliveryCompanySetupViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroTopGlowView;
@property (nonatomic, strong) UIView *heroBottomGlowView;
@property (nonatomic, strong) UIView *formSurface;
@property (nonatomic, strong) UITextField *companyIDField;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *disconnectButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *connectedLabel;
@property (nonatomic, assign) BOOL isDiscoveringMemberships;
@property (nonatomic, assign) BOOL didAttemptAutoDiscovery;
@property (nonatomic, assign) BOOL didAutoOpenDashboard;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation PPDeliveryCompanySetupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self buildUI];
    [self renderState];
    [self prepareEntrance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryCompany_Setup_NavTitle") showBack:YES];
    [self renderState];
    [self refreshAutoDiscoveryIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 20.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    self.heroView = [self buildHero];
    self.formSurface = [self buildFormSurface];
    [self.contentStack addArrangedSubview:self.heroView];
    [self.contentStack addArrangedSubview:self.formSurface];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-30.0],
    ]];
}

- (UIView *)buildHero {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = AppForgroundColr;
    surface.layer.cornerRadius = 34.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    surface.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.07].CGColor;
    surface.layer.shadowOpacity = 1.0;
    surface.layer.shadowRadius = 28.0;
    surface.layer.shadowOffset = CGSizeMake(0.0, 14.0);

    self.heroTopGlowView = [[UIView alloc] init];
    self.heroTopGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    self.heroTopGlowView.layer.cornerRadius = 96.0;
    self.heroTopGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [surface addSubview:self.heroTopGlowView];

    self.heroBottomGlowView = [[UIView alloc] init];
    self.heroBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBottomGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.04];
    self.heroBottomGlowView.layer.cornerRadius = 120.0;
    self.heroBottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [surface addSubview:self.heroBottomGlowView];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [surface addSubview:iconSurface];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"building.2.crop.circle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.isAccessibilityElement = NO;
    [iconSurface addSubview:icon];

    UILabel *eyebrow = [self labelWithFont:PPFontBold(12) color:AppPrimaryClr lines:1];
    eyebrow.text = kLang(@"DeliveryCompany_Setup_Eyebrow");
    [surface addSubview:eyebrow];

    UILabel *title = [self labelWithFont:PPFontBold(36) color:PrimaryTextClr lines:3];
    title.text = kLang(@"DeliveryCompany_Setup_Title");
    [surface addSubview:title];

    UILabel *subtitle = [self labelWithFont:PPFontRegular(15) color:SeconderyTextClr lines:0];
    subtitle.text = kLang(@"DeliveryCompany_Setup_Subtitle");
    [surface addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [surface.heightAnchor constraintGreaterThanOrEqualToConstant:245.0],
        [self.heroTopGlowView.widthAnchor constraintEqualToConstant:188.0],
        [self.heroTopGlowView.heightAnchor constraintEqualToConstant:188.0],
        [self.heroTopGlowView.topAnchor constraintEqualToAnchor:surface.topAnchor constant:-56.0],
        [self.heroTopGlowView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:52.0],
        [self.heroBottomGlowView.widthAnchor constraintEqualToConstant:238.0],
        [self.heroBottomGlowView.heightAnchor constraintEqualToConstant:238.0],
        [self.heroBottomGlowView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:82.0],
        [self.heroBottomGlowView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:-72.0],
        [iconSurface.topAnchor constraintEqualToAnchor:surface.topAnchor constant:22.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [iconSurface.widthAnchor constraintEqualToConstant:52.0],
        [iconSurface.heightAnchor constraintEqualToConstant:52.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:24.0],
        [icon.heightAnchor constraintEqualToConstant:24.0],

        [eyebrow.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:22.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],

        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:5.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-22.0],
    ]];
    return surface;
}

- (UIView *)buildFormSurface {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
    surface.layer.cornerRadius = 30.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
    surface.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.05].CGColor;
    surface.layer.shadowOpacity = 1.0;
    surface.layer.shadowRadius = 22.0;
    surface.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UILabel *sectionTitle = [self labelWithFont:PPFontBold(18) color:PrimaryTextClr lines:2];
    sectionTitle.text = kLang(@"DeliveryCompany_Setup_FormTitle");
    [surface addSubview:sectionTitle];

    UILabel *sectionSubtitle = [self labelWithFont:PPFontRegular(13) color:SeconderyTextClr lines:0];
    sectionSubtitle.text = kLang(@"DeliveryCompany_Setup_FormSubtitle");
    [surface addSubview:sectionSubtitle];

    UIView *fieldSurface = [[UIView alloc] init];
    fieldSurface.translatesAutoresizingMaskIntoConstraints = NO;
    fieldSurface.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.80];
    fieldSurface.layer.cornerRadius = 20.0;
    fieldSurface.layer.cornerCurve = kCACornerCurveContinuous;
    fieldSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    fieldSurface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.12].CGColor;
    [surface addSubview:fieldSurface];

    UIImageView *fieldIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"number"]];
    fieldIcon.translatesAutoresizingMaskIntoConstraints = NO;
    fieldIcon.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.72];
    fieldIcon.contentMode = UIViewContentModeScaleAspectFit;
    [fieldSurface addSubview:fieldIcon];

    self.companyIDField = [[UITextField alloc] init];
    self.companyIDField.translatesAutoresizingMaskIntoConstraints = NO;
    self.companyIDField.font = PPFontMedium(16);
    self.companyIDField.textColor = PrimaryTextClr;
    self.companyIDField.placeholder = kLang(@"DeliveryCompany_Setup_CompanyIDPlaceholder");
    self.companyIDField.textAlignment = Language.alignmentForCurrentLanguage;
    self.companyIDField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.companyIDField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.companyIDField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.companyIDField.returnKeyType = UIReturnKeyDone;
    self.companyIDField.delegate = self;
    self.companyIDField.accessibilityLabel = kLang(@"DeliveryCompany_Setup_CompanyID");
    [fieldSurface addSubview:self.companyIDField];

    self.connectedLabel = [self labelWithFont:PPFontMedium(13) color:UIColor.systemGreenColor lines:0];
    self.connectedLabel.hidden = YES;
    [surface addSubview:self.connectedLabel];

    self.primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryButton.backgroundColor = AppPrimaryClr;
    self.primaryButton.layer.cornerRadius = 20.0;
    self.primaryButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.primaryButton.layer.shadowColor = [AppPrimaryClr colorWithAlphaComponent:0.24].CGColor;
    self.primaryButton.layer.shadowOpacity = 1.0;
    self.primaryButton.layer.shadowRadius = 16.0;
    self.primaryButton.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.primaryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.primaryButton.titleLabel.font = PPFontBold(17);
    [self.primaryButton addTarget:self action:@selector(primaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [surface addSubview:self.primaryButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = UIColor.whiteColor;
    self.spinner.hidesWhenStopped = YES;
    [self.primaryButton addSubview:self.spinner];

    self.disconnectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.disconnectButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.disconnectButton.titleLabel.font = PPFontMedium(15);
    self.disconnectButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.08];
    self.disconnectButton.layer.cornerRadius = 16.0;
    self.disconnectButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.disconnectButton setTitle:kLang(@"DeliveryCompany_Setup_Disconnect") forState:UIControlStateNormal];
    [self.disconnectButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    [self.disconnectButton addTarget:self action:@selector(disconnectTapped) forControlEvents:UIControlEventTouchUpInside];
    self.disconnectButton.hidden = YES;
    [surface addSubview:self.disconnectButton];

    [NSLayoutConstraint activateConstraints:@[
        [sectionTitle.topAnchor constraintEqualToAnchor:surface.topAnchor constant:22.0],
        [sectionTitle.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [sectionTitle.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],

        [sectionSubtitle.topAnchor constraintEqualToAnchor:sectionTitle.bottomAnchor constant:5.0],
        [sectionSubtitle.leadingAnchor constraintEqualToAnchor:sectionTitle.leadingAnchor],
        [sectionSubtitle.trailingAnchor constraintEqualToAnchor:sectionTitle.trailingAnchor],

        [fieldSurface.topAnchor constraintEqualToAnchor:sectionSubtitle.bottomAnchor constant:18.0],
        [fieldSurface.leadingAnchor constraintEqualToAnchor:sectionTitle.leadingAnchor],
        [fieldSurface.trailingAnchor constraintEqualToAnchor:sectionTitle.trailingAnchor],
        [fieldSurface.heightAnchor constraintEqualToConstant:60.0],

        [fieldIcon.leadingAnchor constraintEqualToAnchor:fieldSurface.leadingAnchor constant:16.0],
        [fieldIcon.centerYAnchor constraintEqualToAnchor:fieldSurface.centerYAnchor],
        [fieldIcon.widthAnchor constraintEqualToConstant:18.0],
        [fieldIcon.heightAnchor constraintEqualToConstant:18.0],

        [self.companyIDField.leadingAnchor constraintEqualToAnchor:fieldIcon.trailingAnchor constant:12.0],
        [self.companyIDField.trailingAnchor constraintEqualToAnchor:fieldSurface.trailingAnchor constant:-14.0],
        [self.companyIDField.topAnchor constraintEqualToAnchor:fieldSurface.topAnchor],
        [self.companyIDField.bottomAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor],

        [self.connectedLabel.topAnchor constraintEqualToAnchor:fieldSurface.bottomAnchor constant:12.0],
        [self.connectedLabel.leadingAnchor constraintEqualToAnchor:sectionTitle.leadingAnchor],
        [self.connectedLabel.trailingAnchor constraintEqualToAnchor:sectionTitle.trailingAnchor],

        [self.primaryButton.topAnchor constraintEqualToAnchor:self.connectedLabel.bottomAnchor constant:16.0],
        [self.primaryButton.leadingAnchor constraintEqualToAnchor:sectionTitle.leadingAnchor],
        [self.primaryButton.trailingAnchor constraintEqualToAnchor:sectionTitle.trailingAnchor],
        [self.primaryButton.heightAnchor constraintEqualToConstant:58.0],

        [self.spinner.centerXAnchor constraintEqualToAnchor:self.primaryButton.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.primaryButton.centerYAnchor],

        [self.disconnectButton.topAnchor constraintEqualToAnchor:self.primaryButton.bottomAnchor constant:8.0],
        [self.disconnectButton.leadingAnchor constraintEqualToAnchor:sectionTitle.leadingAnchor],
        [self.disconnectButton.trailingAnchor constraintEqualToAnchor:sectionTitle.trailingAnchor],
        [self.disconnectButton.heightAnchor constraintEqualToConstant:46.0],
        [self.disconnectButton.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-18.0],
    ]];
    return surface;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.numberOfLines = lines;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)renderState {
    PPDeliveryCompanyProfile *profile = PPDeliveryCompanyService.shared.verifiedProfile;
    BOOL connected = profile.companyID.length > 0;
    self.companyIDField.text = connected ? profile.companyID : PPDeliveryCompanyService.shared.configuredCompanyID;
    self.companyIDField.enabled = !connected;
    self.disconnectButton.hidden = !connected;
    if (connected) {
        NSString *companyName = profile.name.length ? profile.name : profile.legalName;
        self.connectedLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_Connected_Format"),
                                    companyName.length ? companyName : profile.companyID,
                                    PPDeliveryCompanyRoleDisplayName(profile.role)];
        self.connectedLabel.textColor = UIColor.systemGreenColor;
        self.connectedLabel.hidden = NO;
        [self.primaryButton setTitle:kLang(@"DeliveryCompany_Setup_OpenDashboard") forState:UIControlStateNormal];
    } else if (self.isDiscoveringMemberships) {
        self.connectedLabel.text = kLang(@"DeliveryCompany_Setup_DiscoveryLoading");
        self.connectedLabel.textColor = SeconderyTextClr;
        self.connectedLabel.hidden = NO;
        [self.primaryButton setTitle:kLang(@"DeliveryCompany_Setup_Connect") forState:UIControlStateNormal];
    } else if (PPDeliveryCompanyService.shared.discoveredProfiles.count > 1) {
        self.connectedLabel.text = [NSString stringWithFormat:kLang(@"DeliveryCompany_Setup_MultipleCompanies_Format"), PPDeliveryCompanyService.shared.discoveredProfiles.count];
        self.connectedLabel.textColor = AppPrimaryClr;
        self.connectedLabel.hidden = NO;
        [self.primaryButton setTitle:kLang(@"DeliveryCompany_Setup_ChooseCompany") forState:UIControlStateNormal];
    } else {
        self.connectedLabel.text = @"";
        self.connectedLabel.hidden = YES;
        [self.primaryButton setTitle:kLang(@"DeliveryCompany_Setup_Connect") forState:UIControlStateNormal];
    }
}

- (void)setLoading:(BOOL)loading {
    self.primaryButton.enabled = !loading;
    self.companyIDField.enabled = !loading && PPDeliveryCompanyService.shared.verifiedProfile == nil;
    self.primaryButton.titleLabel.alpha = loading ? 0.0 : 1.0;
    loading ? [self.spinner startAnimating] : [self.spinner stopAnimating];
}

- (void)primaryTapped {
    [PPFunc pp_playTapEffect];
    PPDeliveryCompanyProfile *profile = PPDeliveryCompanyService.shared.verifiedProfile;
    if (profile.companyID.length) {
        [self openDashboard];
        return;
    }

    NSString *manualCompanyID = [self.companyIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (manualCompanyID.length == 0 && PPDeliveryCompanyService.shared.discoveredProfiles.count > 1) {
        [self presentCompanyPicker];
        return;
    }

    if (manualCompanyID.length == 0 && PPDeliveryCompanyService.shared.discoveredProfiles.count == 1) {
        [PPDeliveryCompanyService.shared storeVerifiedProfile:PPDeliveryCompanyService.shared.discoveredProfiles.firstObject];
        [self renderState];
        [self openDashboard];
        return;
    }

    [self.view endEditing:YES];
    [self setLoading:YES];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared verifyAndStoreCompanyID:manualCompanyID
                                                  completion:^(PPDeliveryCompanyProfile * _Nullable verified, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self setLoading:NO];
        if (error || !verified) {
            [PPAlertHelper showErrorIn:self title:kLang(@"DeliveryCompany_Setup_UnableToConnect") subtitle:error.localizedDescription];
            return;
        }
        [self renderState];
        [PPAlertHelper showSuccessIn:self title:kLang(@"DeliveryCompany_Setup_Connected") subtitle:kLang(@"DeliveryCompany_Setup_ConnectedSubtitle")];
        [self openDashboard];
    }];
}

- (void)refreshAutoDiscoveryIfNeeded {
    if (self.didAttemptAutoDiscovery) {
        return;
    }
    self.didAttemptAutoDiscovery = YES;
    self.isDiscoveringMemberships = YES;
    [self renderState];

    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.isDiscoveringMemberships = NO;
        if (error) {
            [self renderState];
            return;
        }

        if (PPDeliveryCompanyService.shared.verifiedProfile.companyID.length == 0 && profiles.count == 1) {
            [PPDeliveryCompanyService.shared storeVerifiedProfile:profiles.firstObject];
            [self renderState];
            if (!self.didAutoOpenDashboard) {
                self.didAutoOpenDashboard = YES;
                [self openDashboard];
            }
            return;
        }

        [self renderState];
    }];
}

- (void)presentCompanyPicker {
    NSArray<PPDeliveryCompanyProfile *> *profiles = PPDeliveryCompanyService.shared.discoveredProfiles ?: @[];
    if (profiles.count == 0) {
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"DeliveryCompany_Setup_ChooseCompanyTitle")
                                                                   message:kLang(@"DeliveryCompany_Setup_ChooseCompanySubtitle")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (PPDeliveryCompanyProfile *profile in profiles) {
        NSString *companyName = profile.name.length ? profile.name : (profile.legalName.length ? profile.legalName : profile.companyID);
        NSString *title = [NSString stringWithFormat:@"%@  %@", companyName, profile.companyID];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.companyIDField.text = profile.companyID;
            [PPDeliveryCompanyService.shared storeVerifiedProfile:profile];
            [self renderState];
            [self openDashboard];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.primaryButton;
        sheet.popoverPresentationController.sourceRect = self.primaryButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)disconnectTapped {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"DeliveryCompany_Setup_DisconnectTitle")
                             subtitle:kLang(@"DeliveryCompany_Setup_DisconnectSubtitle")
                          placeholder:nil
                        confirmButton:kLang(@"DeliveryCompany_Setup_Disconnect")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{
        [PPDeliveryCompanyService.shared disconnectCompany];
        [weakSelf renderState];
    } cancelBlock:nil];
}

- (void)openDashboard {
    PPDeliveryCompanyDashboardViewController *controller = [[PPDeliveryCompanyDashboardViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self primaryTapped];
    return YES;
}

- (void)prepareEntrance {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    self.heroView.alpha = 0.0;
    self.heroView.transform = CGAffineTransformMakeTranslation(0, 12.0);
    self.formSurface.alpha = 0.0;
    self.formSurface.transform = CGAffineTransformMakeTranslation(0, 16.0);
}

- (void)runEntranceIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroView.alpha = self.formSurface.alpha = 1.0;
        return;
    }
    [UIView animateWithDuration:0.42 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroView.alpha = 1.0;
        self.heroView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.48 delay:0.08 usingSpringWithDamping:0.90 initialSpringVelocity:0.35 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.formSurface.alpha = 1.0;
        self.formSurface.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
