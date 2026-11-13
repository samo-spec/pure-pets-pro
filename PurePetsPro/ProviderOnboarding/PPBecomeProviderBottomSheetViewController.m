//
//  PPBecomeProviderBottomSheetViewController.m
//  PurePetsPro
//
//  First-Principles Category-Defining Reinvention: SwiftyMax NextGen V9.
//  Hosts the sovereign SwiftUI Partner Onboarding Studio (PPBecomePartnerStudioSheet).
//  Preserves 100% binary and API compatibility for existing UIKit callers.
//

#import "PPBecomeProviderBottomSheetViewController.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"

@interface PPBecomeProviderBottomSheetViewController ()
@property (nonatomic, strong) PPProviderOnboardingState *state;
@property (nonatomic, copy) NSArray<NSNumber *> *eligibleProviderTypes;
@property (nonatomic, assign) PPProviderType preferredProviderType;
@property (nonatomic, strong) PPBecomePartnerStudioHostingController *hostingController;
@end

@implementation PPBecomeProviderBottomSheetViewController

#pragma mark - Initialization

- (instancetype)initWithState:(PPProviderOnboardingState *)state
          eligibleProviderTypes:(NSArray<NSNumber *> *)eligibleProviderTypes
            preferredProviderType:(PPProviderType)preferredProviderType {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _state = state;
        _eligibleProviderTypes = eligibleProviderTypes ?: @[];
        _preferredProviderType = preferredProviderType;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPBecomePartnerStudioHostingController alloc]
                              initWithState:self.state
                              eligibleTypes:self.eligibleProviderTypes
                              preferredType:self.preferredProviderType
                              onSubmitted:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if ([strongSelf.delegate respondsToSelector:@selector(becomeProviderBottomSheetDidSubmitApplication:)]) {
            [strongSelf.delegate becomeProviderBottomSheetDidSubmitApplication:strongSelf];
        }
    } onDismiss:^{
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
#if __has_include(<IQKeyboardManager/IQKeyboardManager.h>)
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
#endif
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
#if __has_include(<IQKeyboardManager/IQKeyboardManager.h>)
    [IQKeyboardManager sharedManager].enable = YES;
    [IQKeyboardManager sharedManager].enableAutoToolbar = YES;
#endif
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

@end
