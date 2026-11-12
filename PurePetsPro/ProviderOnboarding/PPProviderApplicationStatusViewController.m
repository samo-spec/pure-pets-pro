//
//  PPProviderApplicationStatusViewController.m
//  PurePetsPro
//
//  First-Principles Category-Defining Reinvention: SwiftyMax NextGen V9.
//  Hosts the sovereign SwiftUI Provider Onboarding Cockpit (PPProviderApplicationStatusStudioView).
//  Preserves 100% binary and API compatibility for existing UIKit callers.
//

#import "PPProviderApplicationStatusViewController.h"
#import "PPBecomeProviderBottomSheetViewController.h"
#import "AdminDashboardViewController.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"

@interface PPProviderApplicationStatusViewController () <PPBecomeProviderBottomSheetViewControllerDelegate>
@property (nonatomic, strong) PPProviderApplicationStatusStudioHostingController *hostingController;
@end

@implementation PPProviderApplicationStatusViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPProviderApplicationStatusStudioHostingController alloc]
                              initWithOnPresentApply:^(PPProviderType type) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_presentBecomeProviderWithType:type];
    } onTransitionToDashboard:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_transitionToDashboard];
    } onClose:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.navigationController && strongSelf.navigationController.viewControllers.firstObject != strongSelf) {
            [strongSelf.navigationController popViewControllerAnimated:YES];
        } else {
            [strongSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];

    self.hostingController.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self addChildViewController:self.hostingController];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostingController.view];

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self.hostingController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

#pragma mark - Transitions & Navigation

- (void)pp_presentBecomeProviderWithType:(PPProviderType)type {
    PPBecomeProviderBottomSheetViewController *sheet = [[PPBecomeProviderBottomSheetViewController alloc]
                                                        initWithState:nil
                                                        eligibleProviderTypes:@[]
                                                        preferredProviderType:type];
    sheet.delegate = self;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_transitionToDashboard {
    if (self.suppressAutoDashboardTransition) {
        return;
    }

    if (self.presentingViewController && !self.navigationController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    UIWindow *window = self.view.window ?: UIApplication.sharedApplication.windows.firstObject;
    if (!window) return;

    AdminDashboardViewController *dashboard = [[AdminDashboardViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dashboard];
    window.rootViewController = nav;
    [UIView transitionWithView:window
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:nil
                    completion:nil];
}

#pragma mark - PPBecomeProviderBottomSheetViewControllerDelegate

- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller {
    // Refresh state handled automatically via Firestore listener in hosting view
}

@end
