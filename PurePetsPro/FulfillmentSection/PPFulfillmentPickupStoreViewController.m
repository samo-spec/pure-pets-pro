#import "PPFulfillmentPickupStoreViewController.h"
#import "PPFulfillmentManager.h"
#import "PPFulfillmentModel.h"
#import "PPFirebaseCompat.h"
#import <math.h>

static NSString *PPPickupText(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

static NSDictionary *PPPickupDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static UILabel *PPPickupLabel(CGFloat size, BOOL bold, UIColor *color) {
    UILabel *label = UILabel.new;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:bold ? [Styling fontBold:size] : [Styling fontMedium:size]];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.textColor = color;
    return label;
}

@interface PPFulfillmentPickupStoreViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PPFulfillmentModel *fulfillment;
@property (nonatomic, copy) NSString *sessionUID;
@property (nonatomic, copy) void (^completion)(NSString * _Nullable);
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *selectionLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong) UIButton *pageButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSDictionary *currentChoice;
@property (nonatomic, strong) NSDictionary *selectedChoice;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *stores;
@property (nonatomic, strong) NSMutableSet<NSString *> *seenCursors;
@property (nonatomic, copy) NSString *nextCursor;
@property (nonatomic, copy) NSString *failedCursor;
@property (nonatomic, copy) NSString *loadError;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loaded;
@property (nonatomic) BOOL closed;
@property (nonatomic) BOOL blocked;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) FIRAuthStateDidChangeListenerHandle authHandle;
@end

@implementation PPFulfillmentPickupStoreViewController

- (instancetype)initWithFulfillment:(PPFulfillmentModel *)fulfillment completion:(void (^)(NSString *))completion {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        // Freeze request identity rather than retaining the detail's mutable model.
        _fulfillment = PPFulfillmentModel.new;
        _fulfillment.fulfillmentID = [fulfillment.fulfillmentID copy];
        _fulfillment.status = [fulfillment.status copy];
        _fulfillment.ownerID = [fulfillment.ownerID copy];
        _fulfillment.ownerType = [fulfillment.ownerType copy];
        _fulfillment.parentOrderNumber = [fulfillment.parentOrderNumber copy];
        _sessionUID = PPPickupText(FIRAuth.auth.currentUser.uid);
        _completion = [completion copy];
        _stores = NSMutableArray.new;
        _seenCursors = NSMutableSet.new;
    }
    return self;
}

- (BOOL)sessionCurrent {
    return self.sessionUID.length && [PPPickupText(FIRAuth.auth.currentUser.uid) isEqualToString:self.sessionUID];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kLang(@"ProPickup_NavigationTitle");
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kLang(@"Cancel")
        style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationController.navigationBar.tintColor = [UIColor ppPrimary];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.semanticContentAttribute = self.view.semanticContentAttribute;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 108;
    self.table.accessibilityIdentifier = @"fulfillment.pickup.stores";
    [self.view addSubview:self.table];

    UIView *dock = UIView.new;
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    dock.backgroundColor = [UIColor ppSurface];
    [self.view addSubview:dock];
    UIStackView *actions = [[UIStackView alloc] init];
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 10;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [dock addSubview:actions];
    self.selectionLabel = PPPickupLabel(14, NO, [UIColor ppTextSecondary]);
    [actions addArrangedSubview:self.selectionLabel];
    self.continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = UIButtonConfiguration.filledButtonConfiguration;
    configuration.title = kLang(@"ProPickup_Continue");
    configuration.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"ProPickup_Continue")
        attributes:@{NSFontAttributeName:[[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
            scaledFontForFont:[Styling fontBold:18]]}];
    configuration.baseBackgroundColor = [UIColor ppPrimary];
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(16, 20, 16, 20);
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    self.continueButton.configuration = configuration;
    self.continueButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.continueButton.titleLabel.numberOfLines = 0;
    self.continueButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.continueButton.accessibilityIdentifier = @"fulfillment.pickup.continue";
    self.continueButton.accessibilityHint = kLang(@"ProPickup_ContinueHint");
    [self.continueButton addTarget:self action:@selector(continueWithStore) forControlEvents:UIControlEventTouchUpInside];
    [self.continueButton.heightAnchor constraintGreaterThanOrEqualToConstant:56].active = YES;
    [actions addArrangedSubview:self.continueButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:dock.topAnchor],
        [dock.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dock.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dock.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [actions.topAnchor constraintEqualToAnchor:dock.topAnchor constant:16],
        [actions.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [actions.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [actions.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12]
    ]];
    [self buildHeader];
    [self buildFooter];
    __weak typeof(self) weakSelf = self;
    self.authHandle = [FIRAuth.auth addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.closed || [self sessionCurrent]) return;
        self.generation++;
        self.loading = NO;
        self.blocked = YES;
        self.selectedChoice = nil;
        self.currentChoice = nil;
        [self.stores removeAllObjects];
        self.nextCursor = nil;
        self.loadError = kLang(@"ProPickup_SessionChanged");
        [self render];
    }];
    [self loadPage:nil];
}

- (void)buildHeader {
    UIView *header = UIView.new;
    UIStackView *stack = UIStackView.new;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:stack];
    UILabel *context = PPPickupLabel(14, YES, [UIColor ppPrimary]);
    NSString *reference = self.fulfillment.parentOrderNumber;
    context.text = reference.length ? [NSString stringWithFormat:kLang(@"ProPickup_OrderReference"), reference] : kLang(@"ProPickup_Eyebrow");
    [stack addArrangedSubview:context];
    UILabel *title = PPPickupLabel(28, YES, [UIColor ppTextPrimary]);
    title.text = kLang(@"ProPickup_Title");
    title.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:title];
    self.hintLabel = PPPickupLabel(17, NO, [UIColor ppTextSecondary]);
    self.hintLabel.text = kLang(@"ProPickup_Intro");
    [stack addArrangedSubview:self.hintLabel];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12]
    ]];
    self.table.tableHeaderView = header;
}

- (void)buildFooter {
    UIView *footer = UIView.new;
    UIStackView *stack = UIStackView.new;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:stack];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    [stack addArrangedSubview:self.spinner];
    self.statusLabel = PPPickupLabel(16, NO, [UIColor ppTextSecondary]);
    self.statusLabel.accessibilityIdentifier = @"fulfillment.pickup.status";
    [stack addArrangedSubview:self.statusLabel];
    self.pageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pageButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[Styling fontBold:17]];
    self.pageButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.pageButton.titleLabel.numberOfLines = 0;
    self.pageButton.tintColor = [UIColor ppPrimary];
    [self.pageButton.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    [self.pageButton addTarget:self action:@selector(retryOrLoadMore) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:self.pageButton];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:footer.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-20]
    ]];
    self.table.tableFooterView = footer;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // The selected row already names the location. Give the scrollable choices
    // room when accessibility type or a compact-height window enlarges the dock.
    BOOL hideSummary = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ||
        self.view.bounds.size.height < 500;
    if (self.selectionLabel.hidden != hideSummary) self.selectionLabel.hidden = hideSummary;
    if (!self.table.tableHeaderView || !self.table.tableFooterView) return;
    for (UIView *view in @[self.table.tableHeaderView, self.table.tableFooterView]) {
        CGFloat width = self.table.bounds.size.width;
        if (width <= 0) continue;
        CGFloat height = [view systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
            withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
        if (fabs(view.frame.size.height - height) > 0.5 || fabs(view.frame.size.width - width) > 0.5) {
            view.frame = CGRectMake(0, 0, width, height);
            if (view == self.table.tableHeaderView) self.table.tableHeaderView = view;
            else self.table.tableFooterView = view;
        }
    }
}

- (NSDictionary *)choiceWithAddress:(id)rawAddress branchID:(id)rawBranch source:(NSString *)source current:(BOOL)current {
    NSDictionary *address = PPPickupDictionary(rawAddress);
    NSString *formatted = PPPickupText(address[@"formattedAddress"]);
    NSString *branch = PPPickupText(rawBranch);
    BOOL validBranch = branch.length && branch.length <= 200 && [branch rangeOfString:@"/"].location == NSNotFound;
    if (!formatted.length || (!current && !validBranch) || (rawBranch != nil && rawBranch != NSNull.null && !validBranch)) return nil;
    NSDictionary *names = PPPickupDictionary(address[@"branchName"]);
    BOOL rtl = Language.semanticAttributeForCurrentLanguage == UISemanticContentAttributeForceRightToLeft;
    NSString *name = PPPickupText(names[rtl ? @"ar" : @"en"]);
    if (!name.length) name = PPPickupText(names[rtl ? @"en" : @"ar"]);
    if (!name.length) name = kLang(@"ProPickup_Location");
    return @{@"branchId":validBranch ? branch : NSNull.null, @"name":name, @"address":formatted, @"source":source ?: @""};
}

- (void)loadPage:(NSString *)cursor {
    if (self.loading || self.closed || self.blocked || ![self sessionCurrent]) return;
    BOOL firstPage = cursor == nil;
    self.loading = YES;
    self.loadError = nil;
    self.failedCursor = cursor;
    if (firstPage) {
        self.loaded = NO;
        self.currentChoice = nil;
        self.selectedChoice = nil;
        self.nextCursor = nil;
        [self.stores removeAllObjects];
        [self.seenCursors removeAllObjects];
    }
    NSUInteger generation = ++self.generation;
    [self render];
    __weak typeof(self) weakSelf = self;
    [[PPFulfillmentManager sharedManager] fetchPickupOptionsForFulfillment:self.fulfillment afterBranchID:cursor
        completion:^(NSDictionary *data, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.closed || generation != self.generation || ![self sessionCurrent]) return;
        self.loading = NO;
        if (error) {
            BOOL denied = [error.domain isEqualToString:FIRFunctionsErrorDomain] &&
                (error.code == FIRFunctionsErrorCodePermissionDenied || error.code == FIRFunctionsErrorCodeUnauthenticated);
            BOOL stale = [error.domain isEqualToString:FIRFunctionsErrorDomain] &&
                (error.code == FIRFunctionsErrorCodeFailedPrecondition || error.code == FIRFunctionsErrorCodeNotFound);
            if (denied || stale) {
                self.blocked = YES;
                self.selectedChoice = nil;
                self.currentChoice = nil;
                [self.stores removeAllObjects];
                self.nextCursor = nil;
            }
            self.loadError = kLang(denied ? @"ProPickup_Denied" : (stale ? @"ProPickup_SelectionInvalid" : @"ProPickup_LoadFailed"));
            [self render];
            return;
        }
        self.loaded = YES;
        if (firstPage) {
            NSDictionary *current = PPPickupDictionary(data[@"current"]);
            self.currentChoice = [self choiceWithAddress:current[@"pickupAddress"] branchID:current[@"pickupBranchId"]
                source:PPPickupText(current[@"pickupStoreSource"]) current:YES];
            self.selectedChoice = self.currentChoice;
        }
        NSMutableSet *ids = NSMutableSet.new;
        NSString *currentID = PPPickupText(self.currentChoice[@"branchId"]);
        if (currentID.length) [ids addObject:currentID];
        for (NSDictionary *row in self.stores) [ids addObject:row[@"branchId"]];
        for (id raw in data[@"stores"]) {
            NSDictionary *row = PPPickupDictionary(raw);
            NSDictionary *choice = [self choiceWithAddress:row[@"pickupAddress"] branchID:row[@"branchId"] source:@"" current:NO];
            if (choice && ![ids containsObject:choice[@"branchId"]]) {
                [self.stores addObject:choice];
                [ids addObject:choice[@"branchId"]];
            }
        }
        if (cursor.length) [self.seenCursors addObject:cursor];
        NSString *next = PPPickupText(data[@"nextCursor"]);
        if (next.length > 200 || [next rangeOfString:@"/"].location != NSNotFound || [self.seenCursors containsObject:next]) {
            self.nextCursor = nil;
            self.loadError = kLang(@"ProPickup_LoadFailed");
        } else self.nextCursor = next.length ? next : nil;
        [self render];
    }];
}

- (void)render {
    [self.table reloadData];
    self.hintLabel.text = kLang(self.loaded && !self.currentChoice ? @"ProPickup_CurrentUnavailable" : @"ProPickup_Intro");
    self.selectionLabel.text = self.selectedChoice
        ? [NSString stringWithFormat:kLang(@"ProPickup_Chosen"), self.selectedChoice[@"name"]] : kLang(@"ProPickup_ChooseFirst");
    self.continueButton.enabled = self.selectedChoice != nil && !self.loading && !self.blocked && [self sessionCurrent];
    self.statusLabel.text = self.loading ? kLang(@"ProPickup_Loading") : self.loadError;
    if (self.loaded && !self.currentChoice && !self.stores.count && !self.loadError && !self.loading)
        self.statusLabel.text = kLang(self.nextCursor ? @"ProPickup_EmptyPage" : @"ProPickup_Empty");
    self.statusLabel.hidden = !self.statusLabel.text.length;
    self.spinner.hidden = !self.loading;
    if (self.loading) [self.spinner startAnimating]; else [self.spinner stopAnimating];
    self.pageButton.hidden = self.loading || self.blocked || ![self sessionCurrent] || (!self.loadError.length && !self.nextCursor.length);
    [self.pageButton setTitle:kLang(self.loadError.length ? @"ProPickup_Retry" : @"ProPickup_LoadMore") forState:UIControlStateNormal];
    [self.view setNeedsLayout];
}

- (void)retryOrLoadMore { [self loadPage:self.loadError.length ? self.failedCursor : self.nextCursor]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (self.currentChoice ? 1 : 0) : self.stores.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return self.stores.count ? kLang(@"ProPickup_OtherStores") : nil;
    if (!self.currentChoice) return nil;
    NSString *source = self.currentChoice[@"source"];
    return kLang([source isEqualToString:@"consumer_stock"] ? @"ProPickup_DefaultStore" :
        ([source isEqualToString:@"saved_pickup"] ? @"ProPickup_SavedLocation" : @"ProPickup_CurrentStore"));
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"pickup"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"pickup"];
    NSDictionary *choice = indexPath.section == 0 ? self.currentChoice : self.stores[indexPath.row];
    BOOL selected = self.selectedChoice == choice;
    UIListContentConfiguration *content = cell.defaultContentConfiguration;
    content.text = choice[@"name"];
    content.secondaryText = choice[@"address"];
    content.textProperties.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:[Styling fontBold:18]];
    content.secondaryTextProperties.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[Styling fontMedium:16]];
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.numberOfLines = 0;
    content.textProperties.adjustsFontForContentSizeCategory = YES;
    content.secondaryTextProperties.adjustsFontForContentSizeCategory = YES;
    content.textProperties.color = [UIColor ppTextPrimary];
    content.secondaryTextProperties.color = [UIColor ppTextSecondary];
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(18, 16, 18, 16);
    cell.contentConfiguration = content;
    cell.semanticContentAttribute = self.view.semanticContentAttribute;
    cell.backgroundColor = selected ? [[UIColor ppPrimary] colorWithAlphaComponent:0.08] : [UIColor ppSurface];
    cell.tintColor = [UIColor ppPrimary];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    cell.accessibilityLabel = [@[choice[@"name"], choice[@"address"]] componentsJoinedByString:@", "];
    cell.accessibilityIdentifier = indexPath.section == 0 ? @"fulfillment.pickup.current" : @"fulfillment.pickup.alternative";
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (self.loading || self.blocked || ![self sessionCurrent]) return;
    self.selectedChoice = indexPath.section == 0 ? self.currentChoice : self.stores[indexPath.row];
    [self render];
}
- (void)continueWithStore {
    if (self.closed || self.loading || self.blocked || !self.selectedChoice || ![self sessionCurrent]) return;
    NSString *branch = PPPickupText(self.selectedChoice[@"branchId"]);
    void (^completion)(NSString *) = self.completion;
    self.closed = YES;
    self.generation++;
    [self dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:^{ if (completion) completion(branch.length ? branch : nil); }];
}
- (void)cancel { self.closed = YES; self.generation++; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) { self.closed = YES; self.generation++; }
}
- (void)dealloc { if (self.authHandle) [FIRAuth.auth removeAuthStateDidChangeListener:self.authHandle]; }
@end
