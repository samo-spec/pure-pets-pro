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
#import "PPFirebaseCompat.h"
#import "PPAlertHelper.h"
#import "SceneDelegate.h"

@interface PPProviderApplicationStatusViewController () <PPBecomeProviderBottomSheetViewControllerDelegate>
@property (nonatomic, strong) PPProviderApplicationStatusStudioHostingController *hostingController;
@property (nonatomic, strong) id<FIRListenerRegistration> applicationIntentListener;
@property (nonatomic, assign) NSUInteger applicationIntentGeneration;
@property (nonatomic, assign) BOOL isResolvingApplicationIntent;
@end

@implementation PPProviderApplicationStatusViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPProviderApplicationStatusStudioHostingController alloc]
                              initOnPresentApply:^(PPProviderType type) {
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.prefersAutoPresentBecomeProvider) {
        self.prefersAutoPresentBecomeProvider = NO;
        [self pp_presentBecomeProviderWithType:PPProviderTypeUnspecified];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self pp_cancelApplicationIntent];
}

- (void)pp_cancelApplicationIntent {
    self.applicationIntentGeneration += 1;
    [self.applicationIntentListener remove];
    self.applicationIntentListener = nil;
    if (self.isResolvingApplicationIntent) [PPHUD dismiss];
    self.isResolvingApplicationIntent = NO;
}

- (void)dealloc {
    [self.applicationIntentListener remove];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

#pragma mark - Transitions & Navigation

- (void)pp_presentBecomeProviderWithType:(PPProviderType)type {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (!uid.length || self.isResolvingApplicationIntent || self.presentedViewController) return;
    SceneDelegate *sceneDelegate = (SceneDelegate *)self.view.window.windowScene.delegate;
    if ([sceneDelegate isKindOfClass:SceneDelegate.class]) [sceneDelegate cancelPendingProAccessRouting];
    self.isResolvingApplicationIntent = YES;
    NSUInteger generation = ++self.applicationIntentGeneration;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:kLang(@"ProSubscription_Loading")];
    __weak typeof(self) weakSelf = self;
    self.applicationIntentListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState *state, NSError *error) {
        // The asynchronous hop also lets the returned registration be assigned
        // before a synchronous/cached callback attempts to remove it.
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.applicationIntentGeneration) return;
            if (![[FIRAuth auth].currentUser.uid isEqualToString:uid] || !self.view.window ||
                (state && ![state.uid isEqualToString:uid])) {
                [self pp_cancelApplicationIntent];
                return;
            }
            if (!error && !state.initialDataAuthoritative) return;
            [self pp_cancelApplicationIntent];
            if (error) {
                [PPAlertHelper showErrorIn:self title:kLang(@"ProviderHeroErrorBadge") subtitle:kLang(@"ProSubscription_LoadFailed")];
                return;
            }
            if (state.isBlocked || state.eligibleProviderTypes.count == 0) {
                [PPAlertHelper showInfoIn:self title:kLang(@"ProSubscription_Title")
                                subtitle:kLang(state.isBlocked ? @"ProviderSubscriptionCardBlockedSubtitle" : @"ProSubscription_NoFeaturesAvailable")];
                return;
            }
            NSArray<NSNumber *> *eligibleTypes = state.eligibleProviderTypes;
            PPProviderType preferredType = [eligibleTypes containsObject:@(type)] ? type : eligibleTypes.firstObject.integerValue;
            PPBecomeProviderBottomSheetViewController *sheet = [[PPBecomeProviderBottomSheetViewController alloc]
                                                                initWithState:state
                                                                eligibleProviderTypes:eligibleTypes
                                                                preferredProviderType:preferredType];
            sheet.delegate = self;
            [self presentViewController:sheet animated:YES completion:nil];
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.applicationIntentGeneration || !self.isResolvingApplicationIntent ||
            ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
        [self pp_cancelApplicationIntent];
        [PPAlertHelper showErrorIn:self title:kLang(@"ProviderHeroErrorBadge") subtitle:kLang(@"ProSubscription_LoadFailed")];
    });
}

- (void)pp_transitionToDashboard {
    if (self.suppressAutoDashboardTransition || self.prefersAutoPresentBecomeProvider ||
        self.isResolvingApplicationIntent || self.presentedViewController) {
        return;
    }

    if (self.presentingViewController && !self.navigationController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    SceneDelegate *sceneDelegate = (SceneDelegate *)self.view.window.windowScene.delegate;
    if ([sceneDelegate isKindOfClass:SceneDelegate.class]) {
        [sceneDelegate updateRootForUser:[FIRAuth auth].currentUser animated:YES];
    }
}

#pragma mark - PPBecomeProviderBottomSheetViewControllerDelegate

- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller {
    // Refresh state handled automatically via Firestore listener in hosting view
}

@end
