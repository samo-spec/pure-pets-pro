// AdminLoginViewController.h
// Pure Pets Pro — Modern login screen (Phone / Apple / Google)
// Replaces legacy XLForm email+password screen.
// Class name intentionally kept for SceneDelegate compatibility.

#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kBiometricDisabledUntilManualLogin = @"biometricDisabledUntilManualLogin";

@interface AdminLoginViewController : UIViewController
    <ASAuthorizationControllerDelegate,
     ASAuthorizationControllerPresentationContextProviding>
@end

NS_ASSUME_NONNULL_END
