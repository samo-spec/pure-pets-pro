#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPProviderCompaniesBottomSearchBar : UIView

@property (nonatomic, strong, readonly) UITextField *textField;
@property (nonatomic, copy, nullable) void (^textDidChangeHandler)(NSString *text);
@property (nonatomic, copy, nullable) void (^submitHandler)(NSString *text);
@property (nonatomic, copy, nullable) void (^keyboardEditingStateHandler)(BOOL editing);
@property (nonatomic, assign, readonly, getter=isKeyboardEditing) BOOL keyboardEditing;

- (instancetype)initWithPlaceholder:(NSString *)placeholder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setPlaceholder:(NSString *)placeholder;
- (void)setResultCount:(NSInteger)resultCount totalCount:(NSInteger)totalCount;
- (void)setSearchText:(NSString *)text notify:(BOOL)notify;
- (void)installKeyboardAvoidanceInView:(UIView *)view bottomConstraint:(NSLayoutConstraint *)bottomConstraint;
- (void)dismissKeyboard;
- (void)animateInIfNeeded;
- (void)applyCurrentTheme;

@end

NS_ASSUME_NONNULL_END
