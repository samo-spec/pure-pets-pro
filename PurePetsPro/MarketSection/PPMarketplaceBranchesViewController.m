#import "PPMarketplaceBranchesViewController.h"

static NSString * const PPMarketplaceErrorRecoverableUnavailableKey = @"PPMarketplaceErrorRecoverableUnavailable";

@interface PPMarketplaceBranchEditorViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) PPMarketplaceBranch * _Nullable branch;
@property (nonatomic, copy) void (^savedHandler)(void);
@property (nonatomic, strong) UITextField *nameArField;
@property (nonatomic, strong) UITextField *nameEnField;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UISwitch *defaultSwitch;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, assign) BOOL saving;
- (instancetype)initWithBranch:(PPMarketplaceBranch * _Nullable)branch;
@end

@interface PPMarketplaceBranchesViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIImageView *emptyIconView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIButton *emptyActionButton;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *addBranchButton;
@property (nonatomic, strong) UIButton *selectionDismissButton;
@property (nonatomic, strong) UIView *bottomSurface;
@property (nonatomic, copy) NSArray<PPMarketplaceBranch *> *branches;
@property (nonatomic, strong) PPMarketplaceBranch * _Nullable selectedBranch;
@property (nonatomic, copy) void (^ _Nullable selectionCompletion)(PPMarketplaceBranch *branch);
@property (nonatomic, assign) BOOL selectionMode;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL showingRecoverableLoadError;
@end

@implementation PPMarketplaceBranchesViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _branches = @[];
    }
    return self;
}

- (instancetype)initForSelectionWithCompletion:(void (^)(PPMarketplaceBranch *))completion {
    self = [self init];
    if (self) {
        _selectionMode = YES;
        _selectionCompletion = [completion copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = pp_canvasColor();
    //self.title = self.selectionMode ? kLang(@"MarketplaceBranches_SelectTitle") : kLang(@"MarketplaceBranches_Title");
    [self pp_buildUI];
    [self pp_loadBranches];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIButton *navButton = self.selectionMode ? self.selectionDismissButton : self.addBranchButton;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:navButton title:self.selectionMode ? kLang(@"MarketplaceBranches_SelectTitle") : kLang(@"MarketplaceBranches_Title") showBack:!self.selectionMode];
    if (!self.didAnimateEntrance) {
        [self pp_prepareEntranceState];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)pp_buildUI {
    self.addBranchButton = [self pp_makeAddBranchButton];
    self.selectionDismissButton = [self pp_makeSelectionDismissButton];

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.07];
    topGlow.layer.cornerRadius = 120.0;
    topGlow.userInteractionEnabled = NO;
    [self.view addSubview:topGlow];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 100.0;
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, self.selectionMode ? 112.0 : 36.0, 0.0);
    self.tableView.tableHeaderView = [self pp_buildHero];
    [self.view addSubview:self.tableView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AppPrimaryClr;
    [self.view addSubview:self.spinner];

    self.emptyView = [self pp_buildEmptyView];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyView.hidden = YES;
    [self.view addSubview:self.emptyView];

    self.bottomSurface = [[UIView alloc] init];
    self.bottomSurface.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSurface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.94];
    self.bottomSurface.layer.cornerRadius = 26.0;
    self.bottomSurface.layer.cornerCurve = kCACornerCurveContinuous;
    self.bottomSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.bottomSurface.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.10].CGColor;
    self.bottomSurface.hidden = !self.selectionMode;
    [self.view addSubview:self.bottomSurface];

    self.primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryButton.backgroundColor = AppPrimaryClr;
    self.primaryButton.layer.cornerRadius = 20.0;
    self.primaryButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.primaryButton.titleLabel.font = [Styling fontBold:15];
    [self.primaryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.primaryButton setTitle:kLang(@"MarketplaceBranches_ConfirmPickup") forState:UIControlStateNormal];
    [self.primaryButton addTarget:self action:@selector(pp_confirmSelection) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.primaryButton style:PPButtonAnimationStyleDefault];
    [self.bottomSurface addSubview:self.primaryButton];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:240.0],
        [topGlow.heightAnchor constraintEqualToConstant:240.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-96.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:100.0],

        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [self.emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:70.0],
        [self.emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [self.emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-32.0],

        [self.bottomSurface.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.bottomSurface.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [self.bottomSurface.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
        [self.bottomSurface.heightAnchor constraintEqualToConstant:76.0],

        [self.primaryButton.topAnchor constraintEqualToAnchor:self.bottomSurface.topAnchor constant:10.0],
        [self.primaryButton.leadingAnchor constraintEqualToAnchor:self.bottomSurface.leadingAnchor constant:10.0],
        [self.primaryButton.trailingAnchor constraintEqualToAnchor:self.bottomSurface.trailingAnchor constant:-10.0],
        [self.primaryButton.bottomAnchor constraintEqualToAnchor:self.bottomSurface.bottomAnchor constant:-10.0],
    ]];
    [self pp_updateSelectionButton];
}

- (UIButton *)pp_makeAddBranchButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [button setImage:[UIImage systemImageNamed:@"plus" withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = AppPrimaryClr;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
    button.layer.cornerRadius = 22.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 12.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    button.accessibilityLabel = kLang(@"MarketplaceBranches_Add");
    [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [button addTarget:self action:@selector(pp_addBranch) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)pp_makeSelectionDismissButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    [button setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = PrimaryTextClr;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
    button.layer.cornerRadius = 22.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.10;
    button.layer.shadowRadius = 12.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    button.accessibilityLabel = kLang(@"Cancel");
    [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [button addTarget:self action:@selector(pp_cancelSelection) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)pp_buildHero {
    CGFloat width = MAX(CGRectGetWidth(self.view.bounds), UIScreen.mainScreen.bounds.size.width);
    PPHero *root = [[PPHero alloc] initWithFrame:CGRectMake(0, 0, width, 170.0)];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 32.0;
    [root addSubview:iconSurface];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"building.2"
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    [iconSurface addSubview:icon];

    UILabel *eyebrow = [self pp_label:kLang(@"MarketplaceBranches_Eyebrow") font:[Styling fontBold:11] color:AppPrimaryClr lines:1];
    UILabel *title = [self pp_label:self.selectionMode ? kLang(@"MarketplaceBranches_SelectHero") : kLang(@"MarketplaceBranches_Hero")
                               font:[Styling fontBold:26]
                              color:PrimaryTextClr
                              lines:2];
    UILabel *subtitle = [self pp_label:self.selectionMode ? kLang(@"MarketplaceBranches_SelectSubtitle") : kLang(@"MarketplaceBranches_Subtitle")
                                  font:[Styling fontMedium:13]
                                 color:SeconderyTextClr
                                 lines:2];
    for (UIView *view in @[eyebrow, title, subtitle]) [root addSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:22.0],
        [iconSurface.topAnchor constraintEqualToAnchor:root.topAnchor constant:12.0],
        [iconSurface.widthAnchor constraintEqualToConstant:64.0],
        [iconSurface.heightAnchor constraintEqualToConstant:64.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [eyebrow.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:16.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:iconSurface.leadingAnchor],
        [eyebrow.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-22.0],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:6.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-22.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-22.0],
    ]];
    return root;
}

- (UIView *)pp_buildEmptyView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 9.0;
    self.emptyIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"building.2.crop.circle"
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightLight]]];
    self.emptyIconView.tintColor = AppPrimaryClr;
    self.emptyTitleLabel = [self pp_label:kLang(@"MarketplaceBranches_EmptyTitle") font:[Styling fontBold:18] color:PrimaryTextClr lines:2];
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel = [self pp_label:kLang(@"MarketplaceBranches_EmptySubtitle") font:[Styling fontMedium:13] color:SeconderyTextClr lines:3];
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:kLang(@"MarketplaceBranches_Add") forState:UIControlStateNormal];
    [button setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    button.titleLabel.font = [Styling fontBold:14];
    [button addTarget:self action:@selector(pp_emptyActionTapped) forControlEvents:UIControlEventTouchUpInside];
    self.emptyActionButton = button;
    [stack addArrangedSubview:self.emptyIconView];
    [stack addArrangedSubview:self.emptyTitleLabel];
    [stack addArrangedSubview:self.emptySubtitleLabel];
    [stack addArrangedSubview:button];
    return stack;
}

- (UILabel *)pp_label:(NSString *)text font:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)pp_loadBranches {
    self.loading = YES;
    [self.spinner startAnimating];
    self.emptyView.hidden = YES;
    __weak typeof(self) weakSelf = self;
    [[PPProviderMarketplaceManager sharedManager] listMarketplaceBranchesWithCompletion:^(NSArray<PPMarketplaceBranch *> *branches, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loading = NO;
        [self.spinner stopAnimating];
        if (error) {
            BOOL recoverable = [error.userInfo[PPMarketplaceErrorRecoverableUnavailableKey] boolValue];
            [self pp_applyEmptyStateForLoadError:error recoverable:recoverable];
            if (!recoverable) {
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription];
            }
            self.branches = @[];
            self.selectedBranch = nil;
        } else {
            [self pp_applyEmptyStateForLoadError:nil recoverable:NO];
            self.branches = branches ?: @[];
            NSMutableArray<PPMarketplaceBranch *> *activeBranches = [NSMutableArray array];
            for (PPMarketplaceBranch *branch in self.branches) {
                if (branch.active) [activeBranches addObject:branch];
            }
            NSArray<PPMarketplaceBranch *> *active = activeBranches.copy;
            if (self.selectionMode && active.count == 1) {
                self.selectedBranch = active.firstObject;
            } else if (self.selectionMode && active.count > 1 &&
                       ![active containsObject:self.selectedBranch]) {
                self.selectedBranch = nil;
            }
        }
        self.emptyView.hidden = self.branches.count > 0;
        [self.tableView reloadData];
        [self pp_updateSelectionButton];
    }];
}

- (void)pp_applyEmptyStateForLoadError:(NSError *)error recoverable:(BOOL)recoverable {
    self.showingRecoverableLoadError = recoverable && error != nil;
    if (self.showingRecoverableLoadError) {
        self.emptyIconView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"
                                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightLight]];
        self.emptyTitleLabel.text = kLang(@"MarketplaceBranches_LoadUnavailableTitle");
        self.emptySubtitleLabel.text = error.localizedDescription.length ? error.localizedDescription : kLang(@"MarketplaceBranches_LoadUnavailableSubtitle");
        [self.emptyActionButton setTitle:kLang(@"Retry") forState:UIControlStateNormal];
        return;
    }
    self.emptyIconView.image = [UIImage systemImageNamed:@"building.2.crop.circle"
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightLight]];
    self.emptyTitleLabel.text = kLang(@"MarketplaceBranches_EmptyTitle");
    self.emptySubtitleLabel.text = kLang(@"MarketplaceBranches_EmptySubtitle");
    [self.emptyActionButton setTitle:kLang(@"MarketplaceBranches_Add") forState:UIControlStateNormal];
}

- (void)pp_emptyActionTapped {
    if (self.showingRecoverableLoadError) {
        [PPFunc pp_playTapEffect];
        [self pp_loadBranches];
        return;
    }
    [self pp_addBranch];
}

- (void)pp_updateSelectionButton {
    self.primaryButton.enabled = self.selectedBranch != nil;
    self.primaryButton.alpha = self.primaryButton.enabled ? 1.0 : 0.42;
}

- (void)pp_addBranch {
    [PPFunc pp_playTapEffect];
    [self pp_presentEditorForBranch:nil];
}

- (void)pp_presentEditorForBranch:(PPMarketplaceBranch *)branch {
    PPMarketplaceBranchEditorViewController *editor = [[PPMarketplaceBranchEditorViewController alloc] initWithBranch:branch];
    __weak typeof(self) weakSelf = self;
    editor.savedHandler = ^{
        [weakSelf pp_loadBranches];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 16.0, *)) {
        UISheetPresentationControllerDetent *detent =
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"marketplaceBranchEditor89"
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return context.maximumDetentValue * 0.89;
        }];
        nav.sheetPresentationController.detents = @[detent];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
        nav.sheetPresentationController.preferredCornerRadius = 30.0;
    } else if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pp_confirmSelection {
    if (!self.selectedBranch) return;
    [PPFunc pp_playTapEffect];
    PPMarketplaceBranch *branch = self.selectedBranch;
    void (^completion)(PPMarketplaceBranch *) = self.selectionCompletion;
    UIViewController *presentedContainer = self.navigationController ?: self;
    [presentedContainer dismissViewControllerAnimated:YES completion:^{
        if (completion) completion(branch);
    }];
}

- (void)pp_cancelSelection {
    UIViewController *presentedContainer = self.navigationController ?: self;
    [presentedContainer dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.branches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    PPMarketplaceBranch *branch = self.branches[indexPath.row];
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", branch.displayName, branch.address];

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.88];
    surface.layer.cornerRadius = 22.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    BOOL selected = [branch.branchID isEqualToString:self.selectedBranch.branchID];
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = selected
        ? [AppPrimaryClr colorWithAlphaComponent:0.45].CGColor
        : UIColor.clearColor.CGColor;
    surface.alpha = branch.active ? 1.0 : 0.50;
    [cell.contentView addSubview:surface];

    UIView *marker = [[UIView alloc] init];
    marker.translatesAutoresizingMaskIntoConstraints = NO;
    marker.backgroundColor = selected ? AppPrimaryClr : UIColor.clearColor;
    marker.layer.cornerRadius = 2.5;
    [surface addSubview:marker];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = selected
        ? [AppPrimaryClr colorWithAlphaComponent:0.12]
        : [SeconderyTextClr colorWithAlphaComponent:0.07];
    iconSurface.layer.cornerRadius = 18.0;
    [surface addSubview:iconSurface];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"mappin"
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = selected ? AppPrimaryClr : SeconderyTextClr;
    [iconSurface addSubview:icon];

    UILabel *name = [self pp_label:branch.displayName font:[Styling fontBold:16] color:PrimaryTextClr lines:1];
    UILabel *address = [self pp_label:branch.address font:[Styling fontMedium:12] color:SeconderyTextClr lines:2];
    [surface addSubview:name];
    [surface addSubview:address];

    UILabel *badge;
    if (branch.defaultBranch) {
        badge = [self pp_label:kLang(@"MarketplaceBranches_Default") font:[Styling fontBold:9] color:AppPrimaryClr lines:1];
        badge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    } else if (branch.code.length > 0) {
        badge = [self pp_label:branch.code font:[Styling fontMedium:9] color:SeconderyTextClr lines:1];
        badge.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.06];
    }
    if (badge) {
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 8.0;
        badge.clipsToBounds = YES;
        [surface addSubview:badge];
    }

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6.0],
        [surface.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6.0],
        [surface.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:18.0],
        [surface.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-18.0],

        [marker.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [marker.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [marker.widthAnchor constraintEqualToConstant:selected ? 5.0 : 0.0],
        [marker.heightAnchor constraintEqualToConstant:selected ? 32.0 : 0.0],

        [iconSurface.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:selected ? 18.0 : 16.0],
        [iconSurface.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [iconSurface.widthAnchor constraintEqualToConstant:40.0],
        [iconSurface.heightAnchor constraintEqualToConstant:40.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [name.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
        [name.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-16.0],
        [name.topAnchor constraintEqualToAnchor:surface.topAnchor constant:16.0],

        [address.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [address.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-16.0],
        [address.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:3.0],
        [address.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-14.0],
    ]];

    if (badge) {
        [NSLayoutConstraint activateConstraints:@[
            [badge.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-14.0],
            [badge.topAnchor constraintEqualToAnchor:surface.topAnchor constant:14.0],
            [badge.heightAnchor constraintEqualToConstant:20.0],
        ]];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PPMarketplaceBranch *branch = self.branches[indexPath.row];
    [PPFunc pp_playTapEffect];
    if (self.selectionMode) {
        if (!branch.active) return;
        self.selectedBranch = branch;
        [self.tableView reloadData];
        [self pp_updateSelectionButton];
        return;
    }
    [self pp_presentEditorForBranch:branch];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selectionMode) return nil;
    PPMarketplaceBranch *branch = self.branches[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *toggle = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:branch.active ? kLang(@"MarketplaceBranches_Deactivate") : kLang(@"MarketplaceBranches_Activate")
                                                                        handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[PPProviderMarketplaceManager sharedManager] setMarketplaceBranchID:branch.branchID active:!branch.active completion:^(BOOL success, NSString *message, NSError *error) {
            if (error) [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:error.localizedDescription];
            if (success) [weakSelf pp_loadBranches];
            completionHandler(success);
        }];
    }];
    toggle.backgroundColor = branch.active ? [UIColor ppWarning] : [UIColor ppSuccess];
    return [UISwipeActionsConfiguration configurationWithActions:@[toggle]];
}

- (void)pp_prepareEntranceState {
    UIView *header = self.tableView.tableHeaderView;
    header.alpha = 0.0;
    header.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    for (UIView *sub in header.subviews) {
        sub.alpha = 0.0;
        sub.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    }
}

- (void)pp_runEntranceIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        UIView *header = self.tableView.tableHeaderView;
        header.alpha = 1.0;
        header.transform = CGAffineTransformIdentity;
        for (UIView *sub in header.subviews) {
            sub.alpha = 1.0;
            sub.transform = CGAffineTransformIdentity;
        }
        [self.tableView.visibleCells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, BOOL *stop) {
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        }];
        return;
    }
    UIView *header = self.tableView.tableHeaderView;
    [UIView animateWithDuration:0.50 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        header.alpha = 1.0;
        header.transform = CGAffineTransformIdentity;
        for (UIView *sub in header.subviews) {
            sub.alpha = 1.0;
            sub.transform = CGAffineTransformIdentity;
        }
    } completion:nil];
    [self.tableView.visibleCells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, BOOL *stop) {
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
        [UIView animateWithDuration:0.42 delay:0.06 + (0.04 * idx) options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end

#pragma mark - Editor

@implementation PPMarketplaceBranchEditorViewController

- (instancetype)initWithBranch:(PPMarketplaceBranch *)branch {
    self = [super init];
    if (self) _branch = branch;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = pp_canvasColor();
    self.title = self.branch ? kLang(@"MarketplaceBranches_Edit") : kLang(@"MarketplaceBranches_Add");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(pp_cancel)];
    [self pp_buildEditor];
}

- (void)pp_buildEditor {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UILabel *eyebrow = [self pp_label:kLang(@"MarketplaceBranches_EditorEyebrow") font:[Styling fontBold:11] color:AppPrimaryClr lines:1];
    UILabel *title = [self pp_label:kLang(@"MarketplaceBranches_EditorTitle") font:[Styling fontBold:26] color:PrimaryTextClr lines:2];
    UILabel *subtitle = [self pp_label:kLang(@"MarketplaceBranches_EditorSubtitle") font:[Styling fontMedium:13] color:SeconderyTextClr lines:3];

    self.nameArField = [self pp_field:kLang(@"MarketplaceBranches_NameAr") value:self.branch.nameAr keyboard:UIKeyboardTypeDefault];
    self.nameEnField = [self pp_field:kLang(@"MarketplaceBranches_NameEn") value:self.branch.nameEn keyboard:UIKeyboardTypeDefault];
    self.addressField = [self pp_field:kLang(@"MarketplaceBranches_Address") value:self.branch.address keyboard:UIKeyboardTypeDefault];
    self.phoneField = [self pp_field:kLang(@"MarketplaceBranches_Phone") value:self.branch.phone keyboard:UIKeyboardTypePhonePad];
    self.nameArField.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.nameArField.textAlignment = NSTextAlignmentRight;

    UIStackView *defaultRow = [[UIStackView alloc] init];
    defaultRow.axis = UILayoutConstraintAxisHorizontal;
    defaultRow.alignment = UIStackViewAlignmentCenter;
    defaultRow.spacing = 12.0;
    defaultRow.layoutMargins = UIEdgeInsetsMake(15, 16, 15, 16);
    defaultRow.layoutMarginsRelativeArrangement = YES;
    defaultRow.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.90];
    defaultRow.layer.cornerRadius = 20.0;
    defaultRow.layer.cornerCurve = kCACornerCurveContinuous;
    UILabel *defaultLabel = [self pp_label:kLang(@"MarketplaceBranches_DefaultLabel") font:[Styling fontBold:14] color:PrimaryTextClr lines:2];
    self.defaultSwitch = [[UISwitch alloc] init];
    self.defaultSwitch.onTintColor = AppPrimaryClr;
    self.defaultSwitch.on = self.branch.defaultBranch;
    [defaultRow addArrangedSubview:defaultLabel];
    [defaultRow addArrangedSubview:self.defaultSwitch];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [Styling fontBold:16];
    self.saveButton.backgroundColor = AppPrimaryClr;
    self.saveButton.layer.cornerRadius = 22.0;
    self.saveButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.saveButton addTarget:self action:@selector(pp_save) forControlEvents:UIControlEventTouchUpInside];
    [self.saveButton.heightAnchor constraintEqualToConstant:56.0].active = YES;
    [PPButtonHelper attachTapAnimationToButton:self.saveButton style:PPButtonAnimationStyleDefault];

    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrow, title, subtitle,
        self.nameArField, self.nameEnField, self.addressField, self.phoneField,
        defaultRow, self.saveButton
    ]];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 14.0;
    [content addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-30.0],
    ]];
}

- (UITextField *)pp_field:(NSString *)placeholder value:(NSString *)value keyboard:(UIKeyboardType)keyboard {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.text = value;
    field.keyboardType = keyboard;
    field.font = [Styling fontMedium:15];
    field.textColor = PrimaryTextClr;
    field.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.90];
    field.layer.cornerRadius = 20.0;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    field.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.09].CGColor;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 1)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [field.heightAnchor constraintEqualToConstant:56.0].active = YES;
    return field;
}

- (UILabel *)pp_label:(NSString *)text font:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)pp_save {
    if (self.saving) return;
    NSString *nameAr = [self.nameArField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *nameEn = [self.nameEnField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *address = [self.addressField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ((nameAr.length == 0 && nameEn.length == 0) || address.length == 0) {
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"MarketplaceBranches_Required")];
        return;
    }
    self.saving = YES;
    self.saveButton.enabled = NO;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
    __weak typeof(self) weakSelf = self;
    [[PPProviderMarketplaceManager sharedManager] saveMarketplaceBranchWithID:self.branch.branchID
                                                                       nameAr:nameAr
                                                                       nameEn:nameEn
                                                                      address:address
                                                                        phone:self.phoneField.text ?: @""
                                                                    isDefault:self.defaultSwitch.on
                                                                   completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.saving = NO;
        self.saveButton.enabled = YES;
        [PPHUD dismiss];
        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription];
            return;
        }
        [PPToast toast:kLang(@"MarketplaceBranches_Saved") style:PPToastStyleSuccess haptic:YES duration:1.8];
        if (self.savedHandler) self.savedHandler();
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)pp_cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
