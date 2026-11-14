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
#import "PPAlertHelper.h"
#import "PurePetsPro-Swift.h"
#import "PPProviderApplicationStatusViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPFirebaseCompat.h"
#import "UserManager.h"
#import "UserModel.h"
#import "SceneDelegate.h"

@interface PPProviderSubscriptionManagmetVC () <PPBecomeProviderBottomSheetViewControllerDelegate>
@property (nonatomic, strong) PPProviderSubscriptionStudioHostingController *hostingController;
@property (nonatomic, copy) NSString *actorUID;
@end

@implementation PPProviderSubscriptionManagmetVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.actorUID = [FIRAuth auth].currentUser.uid ?: @"";

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPProviderSubscriptionStudioHostingController alloc]
                              initOnUpgradePlan:^(PPProviderType type) {
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

    self.hostingController.selectedSubscriptionProfileID = self.selectedSubscriptionProfileID;
    UserModel *user = [UserManager shared].currentUser;
    self.hostingController.workforceOnly = [user.uid isEqualToString:self.actorUID] && [user.accountType isEqualToString:@"staff"];
    self.hostingController.onSelectSubscription = ^(NSString *profileID) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self.actorUID isEqualToString:[FIRAuth auth].currentUser.uid] || !profileID.length) return;
        PPProviderSubscriptionManagmetVC *detail = [[PPProviderSubscriptionManagmetVC alloc] init];
        detail.selectedSubscriptionProfileID = profileID;
        detail.suppressAutoDashboardTransition = YES;
        detail.prefersAutoPresentBecomeProvider = NO;
        [self.navigationController pushViewController:detail animated:YES];
    };
    self.hostingController.onApplications = ^(BOOL addFeature) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self.actorUID isEqualToString:[FIRAuth auth].currentUser.uid]) return;
        SceneDelegate *scene = (SceneDelegate *)self.view.window.windowScene.delegate;
        if ([scene isKindOfClass:SceneDelegate.class]) [scene cancelPendingProAccessRouting];
        PPProviderApplicationStatusViewController *controller = [[PPProviderApplicationStatusViewController alloc] init];
        controller.prefersAutoPresentBecomeProvider = addFeature;
        controller.suppressAutoDashboardTransition = YES;
        [self.navigationController pushViewController:controller animated:YES];
    };
    self.hostingController.onMessage = ^(NSString *title, NSString *body) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self.actorUID isEqualToString:[FIRAuth auth].currentUser.uid]) return;
        [PPAlertHelper showInfoIn:self title:title subtitle:body];
    };
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
    // The application endpoint creates new provider tracks; it cannot change
    // an existing paid term. Do not submit a duplicate application as an upgrade.
    [PPAlertHelper showInfoIn:self title:kLang(@"ProSubscription_ChangesTitle")
                    subtitle:kLang(@"ProSubscription_ChangesBody")];
}

#pragma mark - PPBecomeProviderBottomSheetViewControllerDelegate

- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller {
    // State updates automatically via Firestore snapshot listener
}

@end
