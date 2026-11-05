//
//  PPMarketplaceBranchesViewController.m
//  PurePetsPro
//
//  NextGen V6 Sovereign Marketplace Pickup Network & Dispatch Studio Bridge.
//

#import "PPMarketplaceBranchesViewController.h"
#import "PPProviderMarketplaceManager.h"
#import "ThirdParty/PPStyles/PPDesignTokens.h"
#import "PurePetsPro-Swift.h"

#pragma mark - Branch Editor Host Controller

@interface PPMarketplaceBranchEditorViewController : UIViewController
@property (nonatomic, strong) PPMarketplaceBranch * _Nullable branch;
@property (nonatomic, copy) void (^savedHandler)(void);
@property (nonatomic, strong) UIViewController *hostingController;
- (instancetype)initWithBranch:(PPMarketplaceBranch * _Nullable)branch;
@end

@implementation PPMarketplaceBranchEditorViewController

- (instancetype)initWithBranch:(PPMarketplaceBranch * _Nullable)branch {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _branch = branch;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];

    __weak typeof(self) weakSelf = self;
    UIViewController *host = [PPMarketplaceBranchesHostingBridge makeEditorViewControllerWithBranch:self.branch
                                                                                          onDismiss:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self dismissViewControllerAnimated:YES completion:nil];
    }
                                                                                            onSaved:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.savedHandler) {
            self.savedHandler();
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [self addChildViewController:host];
    [self.view addSubview:host.view];
    host.view.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [host.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [host.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [host.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [host.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [host didMoveToParentViewController:self];
    self.hostingController = host;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
}

@end

#pragma mark - Marketplace Branches Studio View Controller

@interface PPMarketplaceBranchesViewController ()
@property (nonatomic, assign) BOOL selectionMode;
@property (nonatomic, copy) void (^ _Nullable selectionCompletion)(PPMarketplaceBranch *branch);
@property (nonatomic, strong) UIViewController *hostingController;
@end

@implementation PPMarketplaceBranchesViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _selectionMode = NO;
    }
    return self;
}

- (instancetype)initForSelectionWithCompletion:(void (^)(PPMarketplaceBranch *))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _selectionMode = YES;
        _selectionCompletion = [completion copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];

    __weak typeof(self) weakSelf = self;
    UIViewController *host = [PPMarketplaceBranchesHostingBridge makeViewControllerWithSelectionMode:self.selectionMode
                                                                                           onDismiss:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.navigationController && self.navigationController.viewControllers.count > 1) {
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
                                                                                  onConfirmSelection:^(PPMarketplaceBranch *branch) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.selectionCompletion) {
            self.selectionCompletion(branch);
        }
        if (self.navigationController && self.navigationController.viewControllers.count > 1) {
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];

    [self addChildViewController:host];
    [self.view addSubview:host.view];
    host.view.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [host.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [host.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [host.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [host.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [host didMoveToParentViewController:self];
    self.hostingController = host;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
}

@end
