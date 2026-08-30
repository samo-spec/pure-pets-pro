//
//  PPNavigationController.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 07/09/2025.
//


// In PPNavigationController.m
#import "PPNavigationController.h"
#import "Language.h"

@interface PPNavigationController () <UIGestureRecognizerDelegate>
@end

@implementation PPNavigationController

#pragma mark - Background Button Factory

+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style {
    if (@available(iOS 26.0, *)) {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationGlass];
    } else {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationFilled];
    }
}

+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style
                                       configType:(PPButtonConfigration)configType {
    UIButton *bgButton;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = configType == PPButtonConfigrationGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == PPButtonConfigrationClearGlass ? [UIButtonConfiguration clearGlassButtonConfiguration] :
        configType == PPButtonConfigrationFilled ? [UIButtonConfiguration filledButtonConfiguration] :
        configType == PPButtonConfigrationPromp ? [UIButtonConfiguration prominentGlassButtonConfiguration] :
        configType == PPButtonConfigrationClearPromp ? [UIButtonConfiguration prominentClearGlassButtonConfiguration] :
        configType == PPButtonConfigrationTintedBorderd ? [UIButtonConfiguration borderedTintedButtonConfiguration] :
        configType == PPButtonConfigrationTinted ? [UIButtonConfiguration tintedButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration];

        cfg.cornerStyle = style;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 0;
        cfg.background.backgroundColor = [UIColor clearColor];
        cfg.baseBackgroundColor = [UIColor clearColor];

        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.clipsToBounds = NO;
        bgButton.backgroundColor = [UIColor clearColor];
        bgButton.layer.masksToBounds = NO;
    } else {
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        bgButton.layer.shadowColor = AppShadowColor.CGColor;
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Enable the interactive pop gesture recognizer (swipe to pop) and set delegate
    self.interactivePopGestureRecognizer.enabled = YES;
    self.interactivePopGestureRecognizer.delegate = self;
    
    // Configure layout and transition direction based on current app direction
    UISemanticContentAttribute attribute = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = attribute;
    self.navigationBar.semanticContentAttribute = attribute;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // Only allow popping if there are view controllers to pop to
    return self.viewControllers.count > 1;
}

#pragma mark - Navigation Overrides

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Reset tint color to dynamic app standard or label color before transition
    self.navigationBar.tintColor = AppPrimaryTextClr;
    
    // Ensure correct directionality attributes are applied to the navigation hierarchy
    UISemanticContentAttribute attribute = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = attribute;
    self.navigationBar.semanticContentAttribute = attribute;
    
    // Always re-enable the gesture recognizer in case a nested controller disabled it
    self.interactivePopGestureRecognizer.enabled = YES;
    
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    // Always re-enable the gesture recognizer in case a nested controller disabled it
    self.interactivePopGestureRecognizer.enabled = YES;
    
    UIViewController *vc = [super popViewControllerAnimated:animated];
    
    // Restore styling after transition completes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.navigationBar.tintColor = AppPrimaryTextClr;
    });
    
    return vc;
}

@end
