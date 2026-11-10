
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPAlertType) {
    PPAlertTypeSuccess,
    PPAlertTypeError,
    PPAlertTypeWarning,
    PPAlertTypeInfo,
    PPAlertTypeConfirmation,
    PPAlertTypeTextInput
};

typedef NS_ENUM(NSInteger, PPAlertActionStyle) {
    PPAlertActionStylePrimary = 0,
    PPAlertActionStyleSecondary,
    PPAlertActionStyleDestructive,
    PPAlertActionStyleCancel
};

typedef void (^AlertCompletionBlock)(NSString * _Nullable text, BOOL didConfirm);
typedef void (^PPAlertSimpleActionBlock)(void);
@interface PPAlert : UIView

- (instancetype)initWithType:(PPAlertType)type
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                       icon:(UIImage * _Nullable)icon
                confirmTitle:(NSString * _Nullable)confirmTitle
                  cancelTitle:(NSString * _Nullable)cancelTitle
                confirmAction:(AlertCompletionBlock _Nullable)confirmAction
                 cancelAction:(void(^ _Nullable)(void))cancelAction;

- (void)showInViewController:(UIViewController * _Nullable)vc;
 
@end

@interface PPAlertHelper : NSObject

+ (void)showSuccessIn:(UIViewController * _Nullable)vc
                title:(NSString *)title
             subtitle:(NSString *)subtitle
             OKAction:(AlertCompletionBlock _Nullable)okAction
    NS_SWIFT_NAME(showSuccess(in:title:subtitle:OKAction:));

+ (void)showFailIn:(UIViewController * _Nullable)vc
             title:(NSString *)title
          subtitle:(NSString * _Nullable)subtitle
        completion:(void (^ _Nullable)(void))completion
    NS_SWIFT_NAME(showFail(in:title:subtitle:completion:));

+ (void)showConfirmationIn:(UIViewController * _Nullable)vc
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
             confirmButton:(NSString *)confirmTitle
              cancelButton:(NSString *)cancelTitle
                      icon:(UIImage * _Nullable)icon
               confirmBlock:(AlertCompletionBlock _Nullable)confirmBlock
                cancelBlock:(void(^ _Nullable)(void))cancelBlock
    NS_SWIFT_NAME(showConfirmation(in:title:subtitle:confirmButton:cancelButton:icon:confirmBlock:cancelBlock:));

+ (void)showThreeActionConfirmationIn:(UIViewController * _Nullable)vc
                                title:(NSString *)title
                             subtitle:(NSString * _Nullable)subtitle
                        primaryButton:(NSString *)primaryTitle
                         primaryStyle:(UIAlertActionStyle)primaryStyle
                      secondaryButton:(NSString *)secondaryTitle
                       secondaryStyle:(UIAlertActionStyle)secondaryStyle
                       tertiaryButton:(NSString *)tertiaryTitle
                        tertiaryStyle:(UIAlertActionStyle)tertiaryStyle
                         primaryBlock:(PPAlertSimpleActionBlock _Nullable)primaryBlock
                       secondaryBlock:(PPAlertSimpleActionBlock _Nullable)secondaryBlock
                        tertiaryBlock:(PPAlertSimpleActionBlock _Nullable)tertiaryBlock;

+ (void)showTextFieldAlertIn:(UIViewController * _Nullable)vc
                    title:(NSString *)title
                 subtitle:(NSString * _Nullable)subtitle
              placeholder:(NSString * _Nullable)placeholder
              initialText:(NSString * _Nullable)initialText
              confirmText:(NSString * _Nullable)confirmText
               cancelText:(NSString * _Nullable)cancelText
              completion:(AlertCompletionBlock)completion
    NS_SWIFT_NAME(showTextField(in:title:subtitle:placeholder:initialText:confirmText:cancelText:completion:));

+ (void)showTextFieldAlertIn:(UIViewController * _Nullable)vc
                       title:(NSString *)title
                    subtitle:(NSString * _Nullable)subtitle
                 placeholder:(NSString * _Nullable)placeholder
                 initialText:(NSString * _Nullable)initialText
                 confirmText:(NSString * _Nullable)confirmText
                  cancelText:(NSString * _Nullable)cancelText
                 destructive:(BOOL)destructive
                  completion:(AlertCompletionBlock)completion
    NS_SWIFT_NAME(showTextField(in:title:subtitle:placeholder:initialText:confirmText:cancelText:destructive:completion:));

+ (void)showActionSheetIn:(UIViewController * _Nullable)vc
                    title:(NSString *)title
                 subtitle:(NSString * _Nullable)subtitle
                  actions:(NSArray<NSString *> *)actionTitles
             actionStyles:(NSArray<NSNumber *> * _Nullable)actionStyles
              cancelTitle:(NSString *)cancelTitle
               completion:(void(^ _Nullable)(NSInteger index))completion;

+ (void)showSuccessIn:(UIViewController * _Nullable)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle
    NS_SWIFT_NAME(showSuccess(in:title:subtitle:));
+ (void)showErrorIn:(UIViewController * _Nullable)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle
    NS_SWIFT_NAME(showError(in:title:subtitle:));
+ (void)showErrorIn:(UIViewController * _Nullable)vc
              title:(NSString *)title
           subtitle:(NSString * _Nullable)subtitle
         completion:(void (^ _Nullable)(void))completion;
+ (void)showWarningIn:(UIViewController * _Nullable)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle
    NS_SWIFT_NAME(showWarning(in:title:subtitle:));
+ (void)showInfoIn:(UIViewController * _Nullable)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle
    NS_SWIFT_NAME(showInfo(in:title:subtitle:));
+ (void)showSuccessIn:(UIViewController * _Nullable)vc
                title:(NSString *)title
             subtitle:(NSString *)subtitle
        confirmAction:(AlertCompletionBlock _Nullable)confirmAction
         cancelAction:(void (^)(void))cancelAction;
+ (void)showWarningIn:(UIViewController * _Nullable)vc
                title:(NSString *)title
             subtitle:(NSString * _Nullable)subtitle
           completion:(void (^ _Nullable)(void))completion;
+ (void)showInfoIn:(UIViewController * _Nullable)vc
              title:(NSString *)title
           subtitle:(NSString * _Nullable)subtitle
         completion:(void (^ _Nullable)(void))completion;

#pragma mark - Backward-compatible (old AlertHelper API)

+ (void)showConfirmationIn:(UIViewController * _Nullable)vc
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
               placeholder:(NSString * _Nullable)placeholder
             confirmButton:(NSString *)confirmTitle
              cancelButton:(NSString * _Nullable)cancelTitle
              confirmBlock:(void(^_Nullable)(void))confirmBlock
               cancelBlock:(void(^_Nullable)(void))cancelBlock;

+ (void)showConfirmationIn:(UIViewController * _Nullable)vc
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
               placeholder:(NSString * _Nullable)placeholder
             confirmButton:(NSString *)confirmTitle
              cancelButton:(NSString * _Nullable)cancelTitle
                      icon:(UIImage * _Nullable)icon
              confirmBlock:(void(^_Nullable)(void))confirmBlock
               cancelBlock:(void(^_Nullable)(void))cancelBlock;

+ (void)showTextPromptIn:(UIViewController * _Nullable)vc
                    title:(NSString *)title
                 subtitle:(NSString * _Nullable)subtitle
              placeholder:(NSString * _Nullable)placeholder
              initialText:(NSString * _Nullable)initialText
              confirmText:(NSString * _Nullable)confirmText
               cancelText:(NSString * _Nullable)cancelText
               completion:(void(^)(NSString * _Nullable text))completion;

+ (void)showTextPromptIn:(UIViewController * _Nullable)vc
                    title:(NSString *)title
                 subtitle:(NSString * _Nullable)subtitle
              placeholder:(NSString * _Nullable)placeholder
              initialText:(NSString * _Nullable)initialText
              confirmText:(NSString * _Nullable)confirmText
               cancelText:(NSString * _Nullable)cancelText
              secureEntry:(BOOL)secureEntry
             keyboardType:(UIKeyboardType)keyboardType
               completion:(void(^)(NSString * _Nullable text))completion;

@end

NS_ASSUME_NONNULL_END
