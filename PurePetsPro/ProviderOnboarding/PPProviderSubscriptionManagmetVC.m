//
//  PPProviderSubscriptionManagmetVC.m
//  PurePetsPro
//
//  First-Principles Category-Defining Reinvention: SwiftyMax NextGen V9.
//  Hosts the sovereign SwiftUI Provider Subscription & Tier Management Studio (PPProviderSubscriptionStudioView).
//  Preserves 100% binary and API compatibility for existing UIKit callers.
//

#import "PPProviderSubscriptionManagmetVC.h"
#import "PPBecomeProviderBottomSheetViewController.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"

@interface PPProviderSubscriptionManagmetVC () <PPBecomeProviderBottomSheetViewControllerDelegate>
@property (nonatomic, strong) PPProviderSubscriptionStudioHostingController *hostingController;
@end

@implementation PPProviderSubscriptionManagmetVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPProviderSubscriptionStudioHostingController alloc]
                              initWithOnUpgradePlan:^(PPProviderType type) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_presentBecomeProviderForUpgradeWithType:type];
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

#pragma mark - Plan Upgrade Presentation

- (void)pp_presentBecomeProviderForUpgradeWithType:(PPProviderType)type {
    PPBecomeProviderBottomSheetViewController *sheet = [[PPBecomeProviderBottomSheetViewController alloc]
                                                        initWithState:nil
                                                        eligibleProviderTypes:@[]
                                                        preferredProviderType:type];
    sheet.delegate = self;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - PPBecomeProviderBottomSheetViewControllerDelegate

- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller {
    // State updates automatically via Firestore snapshot listener
}

@end
