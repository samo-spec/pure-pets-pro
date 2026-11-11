//
//  PPProviderMarketItemEditorViewController.m
//  PurePetsPro
//
//  Reinvented & Refactored from first principles (NextGen V9).
//  Hosts the category-defining SwiftUI Marketplace Product Studio (PPProviderMarketItemStudioScreen).
//

#import "PPProviderMarketItemEditorViewController.h"
#import "PPProviderMarketItem.h"
#import "PPDesignTokens.h"
#import "Language.h"
#import "PurePetsPro-Swift.h"

@interface PPProviderMarketItemEditorViewController ()
@property (nonatomic, strong) PPProviderMarketItem *item;
@property (nonatomic, assign) BOOL isCreate;
@property (nonatomic, strong) PPProviderMarketItemStudioHostingController *hostingController;
@end

@implementation PPProviderMarketItemEditorViewController

#pragma mark - Initialization

- (instancetype)initForCreate {
    self = [super init];
    if (self) {
        _isCreate = YES;
        _initialAccessKindType = 1;
    }
    return self;
}

- (instancetype)initWithItem:(PPProviderMarketItem *)item {
    self = [super init];
    if (self) {
        _isCreate = NO;
        _item = item;
        _initialAccessKindType = item.accessKindType > 0 ? item.accessKindType : 1;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPProviderMarketItemStudioHostingController alloc] initWithMarketItem:self.item
                                                                                initialAccessKindType:self.initialAccessKindType
                                                                                            onDismiss:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.navigationController && strongSelf.navigationController.viewControllers.count > 1) {
            [strongSelf.navigationController popViewControllerAnimated:YES];
        } else if (strongSelf.presentingViewController || strongSelf.navigationController.presentingViewController) {
            [strongSelf dismissViewControllerAnimated:YES completion:nil];
        }
    } onSaved:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.onSave) {
            strongSelf.onSave();
        }
    }];

    self.hostingController.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self addChildViewController:self.hostingController];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostingController.view];

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
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

#pragma mark - Compatibility Helpers

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor ppElevatedSurface];
}

- (UIColor *)pp_borderColor {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
}

- (void)pp_setupBackdropGlows {}
- (void)pp_updateGlowsForStyle {}
- (void)pp_configureNavigation {}
- (void)pp_buildUI {}
- (void)pp_applyValues {}
- (void)pp_setupFormSections {}

- (UIView *)pp_cardSurface {
    UIView *surface = [[UIView alloc] init];
    surface.backgroundColor = [self pp_surfaceColor];
    return surface;
}

- (UIView *)pp_variantStudioBlock {
    return [[UIView alloc] init];
}

- (void)pp_refreshVariantStudioBlock {}
- (void)pp_openVariantStudio {}
- (void)pp_stageProductForOptionsAndOpenStudio {}

- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    return [[UIView alloc] init];
}

- (void)pp_pickImage {}
- (void)saveTapped {}

@end
