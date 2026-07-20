#import <UIKit/UIKit.h>

@class PPProviderMarketItem;

@interface PPProviderMarketItemEditorViewController : UIViewController

- (instancetype)initWithItem:(PPProviderMarketItem *)item;
- (instancetype)initForCreate;

@property (nonatomic, copy) void (^onSave)(void);

// Private methods
- (UIColor *)pp_canvasColor;
- (UIColor *)pp_surfaceColor;
- (UIColor *)pp_borderColor;
- (void)pp_setupBackdropGlows;
- (void)pp_updateGlowsForStyle;
- (void)pp_configureNavigation;
- (void)pp_buildUI;
- (void)pp_applyValues;
- (void)pp_setupFormSections;
- (void)pp_pickImage;
- (void)saveTapped;

@end